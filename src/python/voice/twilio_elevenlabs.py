"""Twilio ↔ ElevenLabs Conversational-AI bridge.

Connects Twilio outbound/inbound voice calls to an ElevenLabs
Conversational AI agent via WebSocket, then forwards the final
transcript to the ``/ingest_call`` endpoint for data extraction.

Environment variables required:
    TWILIO_ACCOUNT_SID   – Twilio account SID
    TWILIO_AUTH_TOKEN     – Twilio auth token
    TWILIO_PHONE_NUMBER   – Your Twilio phone number (E.164)
    ELEVENLABS_API_KEY   – ElevenLabs API key
    ELEVENLABS_AGENT_ID  – ElevenLabs Conversational AI agent ID
    PUBLIC_URL           – Public base URL (e.g. ngrok https URL)
"""

import asyncio
import json
import logging
import os
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request, HTTPException, Depends
from fastapi.responses import Response, JSONResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/twilio", tags=["twilio"])

# ── Configuration ───────────────────────────────────────────────────────

TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", "")
ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY", "")
ELEVENLABS_AGENT_ID = os.getenv("ELEVENLABS_AGENT_ID", "")
PUBLIC_URL = os.getenv("PUBLIC_URL", "http://localhost:3000")

ELEVENLABS_WS_URL = "wss://api.elevenlabs.io/v1/convai/conversation"
INGEST_CALL_URL = f"{PUBLIC_URL}/ingest_call"


# ── Helpers ─────────────────────────────────────────────────────────────


def _get_elevenlabs_signed_url() -> Optional[str]:
    """Request a signed WebSocket URL from ElevenLabs for the agent."""
    if not ELEVENLABS_API_KEY or not ELEVENLABS_AGENT_ID:
        logger.error("ELEVENLABS_API_KEY or ELEVENLABS_AGENT_ID not set")
        return None
    url = (
        f"https://api.elevenlabs.io/v1/convai/conversation/get_signed_url"
        f"?agent_id={ELEVENLABS_AGENT_ID}"
    )
    headers = {"xi-api-key": ELEVENLABS_API_KEY}
    try:
        resp = httpx.get(url, headers=headers, timeout=10)
        resp.raise_for_status()
        return resp.json().get("signed_url")
    except Exception as exc:
        logger.error("Failed to get ElevenLabs signed URL: %s", exc)
        return None


def _twiml_stream_response(source_id: Optional[int] = None) -> str:
    """Return TwiML that starts a bi-directional media stream.

    When *source_id* is provided it is passed as a custom ``<Parameter>``
    so the WebSocket handler can associate the stream with a food-bank record.
    """
    ws_url = PUBLIC_URL.replace("https://", "wss://").replace("http://", "ws://")
    param_tag = ""
    if source_id is not None:
        param_tag = f'      <Parameter name="source_id" value="{source_id}" />'
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        "<Response>"
        "  <Connect>"
        f'    <Stream url="{ws_url}/twilio/media-stream">'
        f"{param_tag}"
        "    </Stream>"
        "  </Connect>"
        "</Response>"
    )


# ── Twilio Voice Webhooks ──────────────────────────────────────────────


@router.post("/voice/outbound")
async def twilio_voice_outbound(request: Request):
    """Twilio Voice webhook for outbound calls.

    When Twilio connects the outbound call, it POSTs here.
    We respond with TwiML that opens a bi-directional media stream
    back to our ``/twilio/media-stream`` WebSocket endpoint.
    The ``source_id`` query parameter (set when the call was created)
    is forwarded as a ``<Parameter>`` inside the ``<Stream>`` tag so
    the WebSocket handler can associate the call with a food-bank record.
    """
    source_id = request.query_params.get("source_id")
    sid = int(source_id) if source_id else None
    return Response(content=_twiml_stream_response(sid), media_type="application/xml")


@router.post("/voice/inbound")
async def twilio_voice_inbound(request: Request):
    """Twilio Voice webhook for inbound calls.

    Same TwiML response — opens a media stream for the AI agent.
    """
    return Response(content=_twiml_stream_response(), media_type="application/xml")


# ── Twilio ↔ ElevenLabs Media-Stream Bridge ────────────────────────────


@router.websocket("/media-stream")
async def media_stream(ws: WebSocket):
    """Bridge between Twilio media stream and ElevenLabs Conversational AI.

    Flow:
        Twilio ──audio──▶ this server ──audio──▶ ElevenLabs agent
        Twilio ◀──audio── this server ◀──audio── ElevenLabs agent

    After the call ends the accumulated transcript is POSTed to /ingest_call.
    """
    await ws.accept()

    signed_url = _get_elevenlabs_signed_url()
    if not signed_url:
        logger.error("Cannot connect to ElevenLabs — missing signed URL")
        await ws.close(code=1011, reason="ElevenLabs config error")
        return

    try:
        import websockets  # type: ignore
    except ImportError:
        logger.error("websockets package not installed")
        await ws.close(code=1011, reason="Server dependency missing")
        return

    stream_sid: Optional[str] = None
    source_id: Optional[int] = None
    transcript_parts: list[str] = []

    try:
        async with websockets.connect(signed_url) as el_ws:

            # ── Forward Twilio → ElevenLabs ─────────────────────────
            async def twilio_to_elevenlabs():
                nonlocal stream_sid
                try:
                    while True:
                        msg = await ws.receive_text()
                        data = json.loads(msg)
                        event = data.get("event")

                        if event == "start":
                            stream_sid = data.get("start", {}).get("streamSid")
                            # Extract custom parameters (source_id)
                            params = data.get("start", {}).get("customParameters", {})
                            nonlocal source_id
                            source_id = int(params.get("source_id", 0)) or None
                            logger.info("Twilio stream started: %s", stream_sid)

                            # Send audio config to ElevenLabs
                            await el_ws.send(json.dumps({
                                "type": "audio_input_config",
                                "audio_encoding": "mulaw",
                                "sample_rate": 8000,
                            }))

                        elif event == "media":
                            payload = data.get("media", {}).get("payload", "")
                            if payload:
                                await el_ws.send(json.dumps({
                                    "type": "audio_input",
                                    "data": payload,
                                }))

                        elif event == "stop":
                            logger.info("Twilio stream stopped")
                            break
                except WebSocketDisconnect:
                    logger.info("Twilio WebSocket disconnected")

            # ── Forward ElevenLabs → Twilio ─────────────────────────
            async def elevenlabs_to_twilio():
                try:
                    async for raw in el_ws:
                        data = json.loads(raw)
                        msg_type = data.get("type")

                        if msg_type == "audio":
                            audio_data = data.get("data", "")
                            if audio_data and stream_sid:
                                await ws.send_json({
                                    "event": "media",
                                    "streamSid": stream_sid,
                                    "media": {"payload": audio_data},
                                })

                        elif msg_type == "transcript":
                            # Collect transcript segments
                            text = data.get("text", "")
                            if text:
                                role = data.get("role", "agent")
                                transcript_parts.append(f"{role}: {text}")

                        elif msg_type == "end_of_conversation":
                            logger.info("ElevenLabs conversation ended")
                            break
                except Exception as exc:
                    logger.warning("ElevenLabs WS error: %s", exc)

            # Run both directions concurrently
            await asyncio.gather(
                twilio_to_elevenlabs(),
                elevenlabs_to_twilio(),
            )

    except Exception as exc:
        logger.exception("Media stream bridge error: %s", exc)
    finally:
        # Forward transcript to /ingest_call
        if transcript_parts and source_id:
            full_transcript = "\n".join(transcript_parts)
            await _forward_transcript(source_id, full_transcript)

        try:
            await ws.close()
        except Exception:
            pass


async def _forward_transcript(source_id: int, transcript: str):
    """POST the captured transcript to the /ingest_call endpoint."""
    logger.info(
        "Forwarding transcript for source %s (%d chars)",
        source_id,
        len(transcript),
    )
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                INGEST_CALL_URL,
                json={
                    "source_id": source_id,
                    "transcript": transcript,
                },
                timeout=30,
            )
            logger.info("/ingest_call response: %s %s", resp.status_code, resp.text[:200])
    except Exception as exc:
        logger.error("Failed to forward transcript: %s", exc)


# ── Outbound Call Trigger ──────────────────────────────────────────────

from get_db import get_db
from models.models import Sources

MAX_CALL_RETRIES = int(os.getenv("MAX_CALL_RETRIES", "3"))
CALL_RETRY_DELAY = int(os.getenv("CALL_RETRY_DELAY", "5"))  # seconds


class OutboundCallRequest(BaseModel):
    """Request body to initiate an outbound verification call."""
    to: str  # destination phone number (E.164)
    source_id: int  # food-bank source ID to verify


def _mark_verification_failed(db: Session, source_id: int) -> None:
    """Set verification_status='verification_failed' with a timestamp."""
    source = db.query(Sources).filter(Sources.id == source_id).first()
    if source:
        source.verification_status = "verification_failed"
        source.verification_failed_at = datetime.now(timezone.utc)
        db.commit()
        logger.info("Marked source %s as verification_failed", source_id)


@router.post("/call/outbound")
async def initiate_outbound_call(
    body: OutboundCallRequest,
    db: Session = Depends(get_db),
):
    """Initiate an outbound call via Twilio to the given number.

    Retries up to ``MAX_CALL_RETRIES`` times if the call fails.
    On exhaustion the food-bank record is marked *verification_failed*.
    The source_id is passed as a query parameter on the webhook URL so the
    media-stream handler can associate the call with the correct source.
    """
    if not all([TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER]):
        raise HTTPException(status_code=500, detail="Twilio credentials not configured")

    try:
        from twilio.rest import Client  # type: ignore
    except ImportError:
        logger.error("twilio package not installed")
        raise HTTPException(status_code=500, detail="twilio package not installed")

    client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
    webhook_url = f"{PUBLIC_URL}/twilio/voice/outbound?source_id={body.source_id}"

    last_error: Optional[Exception] = None
    for attempt in range(1, MAX_CALL_RETRIES + 1):
        try:
            call = client.calls.create(
                to=body.to,
                from_=TWILIO_PHONE_NUMBER,
                url=webhook_url,
                status_callback=f"{PUBLIC_URL}/twilio/call-status?source_id={body.source_id}",
                status_callback_method="POST",
            )
            logger.info(
                "Outbound call initiated (attempt %d): %s → %s (SID: %s)",
                attempt, TWILIO_PHONE_NUMBER, body.to, call.sid,
            )
            return {"call_sid": call.sid, "status": call.status}
        except Exception as exc:
            last_error = exc
            logger.warning("Call attempt %d/%d failed: %s", attempt, MAX_CALL_RETRIES, exc)
            if attempt < MAX_CALL_RETRIES:
                await asyncio.sleep(CALL_RETRY_DELAY * attempt)

    # All retries exhausted — mark the food-bank record as failed.
    _mark_verification_failed(db, body.source_id)
    logger.error("Call failed after %d attempts: %s", MAX_CALL_RETRIES, last_error)
    raise HTTPException(status_code=502, detail=f"Call failed after {MAX_CALL_RETRIES} attempts")


@router.post("/call-status")
async def call_status_callback(request: Request, db: Session = Depends(get_db)):
    """Receive Twilio call status updates (ringing, in-progress, completed, etc.).

    If the terminal status indicates failure (busy, no-answer, failed, canceled)
    the food-bank record is marked as *verification_failed*.
    """
    form = await request.form()
    call_sid = form.get("CallSid", "")
    call_status = form.get("CallStatus", "")
    source_id_raw = request.query_params.get("source_id")
    logger.info("Call status update: SID=%s Status=%s source_id=%s", call_sid, call_status, source_id_raw)

    failed_statuses = {"busy", "no-answer", "failed", "canceled"}
    if call_status in failed_statuses and source_id_raw:
        try:
            _mark_verification_failed(db, int(source_id_raw))
        except (ValueError, TypeError):
            logger.warning("Invalid source_id in call-status callback: %s", source_id_raw)

    return Response(status_code=204)


# ── Demo Mode ──────────────────────────────────────────────────────────


class DemoIngestRequest(BaseModel):
    """Request body for demo mode — paste a transcript instead of calling."""
    source_id: int
    transcript: str


@router.post("/demo/ingest")
async def demo_ingest(body: DemoIngestRequest):
    """Demo mode: accept a pasted transcript and forward it to /ingest_call.

    This bypasses Twilio entirely — useful for testing the extraction
    pipeline without making a real phone call.
    """
    logger.info("Demo ingest for source %s (%d chars)", body.source_id, len(body.transcript))
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                INGEST_CALL_URL,
                json={
                    "source_id": body.source_id,
                    "transcript": body.transcript,
                },
                timeout=30,
            )
            return JSONResponse(content=resp.json(), status_code=resp.status_code)
    except Exception as exc:
        logger.error("Demo ingest failed: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc))
