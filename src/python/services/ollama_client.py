"""Call the local Ollama llama3.1:8b model and return a proposed-change dict."""

import json
import logging

import requests

logger = logging.getLogger(__name__)

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "llama3.1:8b"
TIMEOUT = 60

PROMPT_TEMPLATE = """\
You are a strict JSON extraction engine for a food-bank verification system.

Read the phone-call transcript below and extract every factual update about \
the food bank with source_id "{source_id}".

Return **ONLY** valid JSON — no markdown fences, no comments, no extra text.

SCHEMA (return exactly this structure):
{{
  "source_id": "{source_id}",
  "confidence": <float 0.0-1.0>,
  "changes": [
    {{
      "field": "<field_name>",
      "op": "set",
      "value": <new_value>
    }}
  ],
  "evidence": ["<exact sentence(s) from transcript>"]
}}

ALLOWED FIELDS (use only these names):
  hours, phone, address, food_type, isAccessibleViaPublicTransport, notes, wait_time

RULES:
1. Output MUST be valid JSON. No markdown, no ```json fences, no prose.
2. Only include a change when the transcript explicitly states new information.
3. "evidence" MUST contain verbatim sentence(s) from the transcript.
4. If nothing actionable is found, return "changes": [] and "evidence": [].
5. Confidence reflects certainty: 1.0 = directly stated, 0.5 = implied/ambiguous.
6. "op" must always be "set".

--- TRANSCRIPT ---
{transcript}
--- END ---

OUTPUT:
"""


def extract_proposed_change(source_id: str, transcript: str) -> dict:
    """Call Ollama and return a parsed proposed-change dict.

    Raises ``ValueError`` when the model response cannot be parsed as JSON.
    Raises ``RuntimeError`` on network / server errors.
    """
    prompt = PROMPT_TEMPLATE.format(source_id=source_id, transcript=transcript)

    payload = {
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
        "format": "json",
    }

    try:
        resp = requests.post(OLLAMA_URL, json=payload, timeout=TIMEOUT)
        resp.raise_for_status()
    except requests.RequestException as exc:
        raise RuntimeError(f"Ollama request failed: {exc}") from exc

    try:
        data = resp.json()
        raw_text = data.get("response", "")
        parsed = json.loads(raw_text)
    except (json.JSONDecodeError, KeyError, TypeError) as exc:
        raise ValueError(f"Failed to parse Ollama JSON response: {exc}") from exc

    # Ensure source_id matches what was requested
    parsed["source_id"] = source_id
    return parsed
