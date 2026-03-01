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
from typing import Optional

import httpx
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import Response

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


def _twiml_stream_response() -> str:
    """Return TwiML that starts a bi-directional media stream."""
    ws_url = PUBLIC_URL.replace("https://", "wss://").replace("http://", "ws://")
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        "<Response>"
        "  <Connect>"
        f'    <Stream url="{ws_url}/twilio/media-stream" />'
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
    """
    return Response(content=_twiml_stream_response(), media_type="application/xml")


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

from pydantic import BaseModel


class OutboundCallRequest(BaseModel):
    """Request body to initiate an outbound verification call."""
    to: str  # destination phone number (E.164)
    source_id: int  # food-bank source ID to verify


@router.post("/call/outbound")
async def initiate_outbound_call(body: OutboundCallRequest):
    """Initiate an outbound call via Twilio to the given number.

    Twilio will call the destination, then POST to our ``/twilio/voice/outbound``
    webhook which responds with TwiML to start the media stream.
    """
    if not all([TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER]):
        return {"error": "Twilio credentials not configured"}, 500

    try:
        from twilio.rest import Client  # type: ignore

        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        webhook_url = f"{PUBLIC_URL}/twilio/voice/outbound"

        call = client.calls.create(
            to=body.to,
            from_=TWILIO_PHONE_NUMBER,
            url=webhook_url,
            status_callback=f"{PUBLIC_URL}/twilio/call-status",
            # Pass source_id so the media stream handler knows which source
            # this call is for
        )
        logger.info("Outbound call initiated: %s → %s (SID: %s)", TWILIO_PHONE_NUMBER, body.to, call.sid)
        return {"call_sid": call.sid, "status": call.status}
    except ImportError:
        logger.error("twilio package not installed")
        return {"error": "twilio package not installed"}
    except Exception as exc:
        logger.error("Failed to initiate call: %s", exc)
        return {"error": str(exc)}


@router.post("/call-status")
async def call_status_callback(request: Request):
    """Receive Twilio call status updates (ringing, in-progress, completed, etc.)."""
    form = await request.form()
    call_sid = form.get("CallSid", "")
    call_status = form.get("CallStatus", "")
    logger.info("Call status update: SID=%s Status=%s", call_sid, call_status)
    return Response(status_code=204)
