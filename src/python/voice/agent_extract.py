"""Build a structured prompt, call Ollama, and parse into a ChangeRequest."""

import json
import logging
from typing import Optional

from .ollama_client import query_ollama
from .schemas import ChangeRequest

logger = logging.getLogger(__name__)

# ── Prompt template ─────────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are a strict JSON extraction engine for a food-bank verification system.

TASK:
Read the phone-call transcript below and extract every factual update about \
the food bank.  Return **ONLY** valid JSON — no markdown fences, no comments, \
no extra text.

SCHEMA (return exactly this structure):
{{
  "source_id": <int>,
  "changes": [
    {{
      "field": "<field_name>",
      "old_value": <previous or null>,
      "new_value": <new>,
      "confidence": <float 0.0-1.0>,
      "evidence": "<exact sentence(s) from the transcript>"
    }}
  ],
  "summary": "<one-line human-readable summary>"
}}

ALLOWED FIELDS (use only these names):
  hours          – operating hours (string or structured object)
  phone          – phone number
  address        – street address
  food_type      – types of food provided (string or list)
  isAccessibleViaPublicTransport – boolean, true/false
  notes          – any other relevant info mentioned
  wait_time      – typical wait time for clients

RULES:
1. Output MUST be valid JSON. No markdown, no ```json fences, no prose.
2. Only include a change when the transcript explicitly states new information.
3. "evidence" MUST be the verbatim sentence(s) from the transcript that support the change.
4. If nothing actionable is found, return "changes": [].
5. Confidence reflects certainty: 1.0 = directly stated, 0.5 = implied/ambiguous.
"""

# ── Few-shot examples (included in every prompt) ───────────────────────

FEW_SHOT_EXAMPLES = """
EXAMPLE 1:
--- TRANSCRIPT ---
Agent: Hi, can you confirm your current hours?
Rep: Sure, we are now open Monday through Friday 9 AM to 5 PM. We used to close at 3.
Agent: Great, and is your location accessible by public transit?
Rep: Yes, there's a bus stop right outside.
--- END ---

OUTPUT:
{"source_id": 1, "changes": [{"field": "hours", "old_value": null, "new_value": "Mon-Fri 9AM-5PM", "confidence": 0.95, "evidence": "we are now open Monday through Friday 9 AM to 5 PM"}, {"field": "isAccessibleViaPublicTransport", "old_value": null, "new_value": true, "confidence": 0.92, "evidence": "Yes, there's a bus stop right outside."}], "summary": "Updated hours to Mon-Fri 9AM-5PM; confirmed public-transit accessible."}

EXAMPLE 2:
--- TRANSCRIPT ---
Agent: Hello, I'm calling to verify your information. Has anything changed recently?
Rep: Actually yes, our phone number changed. It's now 408-555-9999.
Rep: Also, we started offering hot meals in addition to groceries.
Agent: What about wait times?
Rep: Usually about 20 minutes.
--- END ---

OUTPUT:
{"source_id": 1, "changes": [{"field": "phone", "old_value": null, "new_value": "408-555-9999", "confidence": 0.97, "evidence": "our phone number changed. It's now 408-555-9999."}, {"field": "food_type", "old_value": null, "new_value": "hot meals, groceries", "confidence": 0.90, "evidence": "we started offering hot meals in addition to groceries."}, {"field": "wait_time", "old_value": null, "new_value": "20 minutes", "confidence": 0.88, "evidence": "Usually about 20 minutes."}], "summary": "New phone 408-555-9999; added hot meals; ~20 min wait."}

EXAMPLE 3:
--- TRANSCRIPT ---
Agent: Good morning! Just checking in — any updates for us?
Rep: Nope, everything is the same as last time.
Agent: Okay, thanks for confirming.
--- END ---

OUTPUT:
{"source_id": 1, "changes": [], "summary": "No changes reported."}
"""


def build_prompt(source_id: int, transcript: str) -> str:
    """Combine system instructions, few-shot examples, and the call transcript."""
    return (
        f"{SYSTEM_PROMPT}\n"
        f"{FEW_SHOT_EXAMPLES}\n"
        f"NOW EXTRACT FROM THIS TRANSCRIPT:\n"
        f"source_id: {source_id}\n\n"
        f"--- TRANSCRIPT ---\n{transcript}\n--- END ---\n\n"
        f"OUTPUT:\n"
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
