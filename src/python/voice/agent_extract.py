"""Build a structured prompt, call Ollama, and parse into a ChangeRequest."""

import json
import logging
from typing import Optional

from .ollama_client import query_ollama
from .schemas import ChangeRequest

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """\
You are an expert data-extraction assistant for a food-bank database.

Given a phone-call transcript between a verification agent and a food-bank \
representative, extract every factual update about the food bank and return \
**only** valid JSON matching this schema (no extra text):

{{
  "source_id": <int>,
  "changes": [
    {{
      "field": "<column_name>",
      "old_value": <previous or null>,
      "new_value": <new>,
      "confidence": <0.0-1.0>
    }}
  ],
  "summary": "<one-line summary>"
}}

Allowed fields: name, phone, address, city, state, zip, hours_json, \
types_json, availability, excess_food, is_accessible, duration.

Rules:
- Only include fields explicitly mentioned in the transcript.
- Confidence reflects how certain you are the change is accurate.
- Return an empty "changes" list if nothing actionable is found.
"""


def build_prompt(source_id: int, transcript: str) -> str:
    """Combine system instructions with the call transcript."""
    return (
        f"{SYSTEM_PROMPT}\n\n"
        f"source_id: {source_id}\n\n"
        f"--- TRANSCRIPT ---\n{transcript}\n--- END ---"
    )


def extract_changes(source_id: int, transcript: str) -> Optional[ChangeRequest]:
    """Call Ollama and return a validated ``ChangeRequest``, or ``None``."""
    prompt = build_prompt(source_id, transcript)
    raw = query_ollama(prompt)
    if raw is None:
        logger.error("No response from Ollama for source %s", source_id)
        return None

    try:
        data = json.loads(raw)
        # Ensure source_id matches what we sent
        data["source_id"] = source_id
        return ChangeRequest(**data)
    except (json.JSONDecodeError, ValueError, TypeError) as exc:
        logger.error("Failed to parse Ollama output: %s — raw: %s", exc, raw[:500])
        return None
