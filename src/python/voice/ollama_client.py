"""Thin HTTP client for the local Ollama server (llama3.1:8b)."""

import json
import logging
import time
from typing import Optional

import requests

logger = logging.getLogger(__name__)

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "llama3.1:8b"
DEFAULT_TIMEOUT = 60  # seconds
MAX_RETRIES = 3
RETRY_BACKOFF = 2  # seconds multiplied by attempt number


def query_ollama(
    prompt: str,
    *,
    model: str = MODEL,
    timeout: int = DEFAULT_TIMEOUT,
    max_retries: int = MAX_RETRIES,
) -> Optional[str]:
    """Send *prompt* to Ollama and return the raw text response.

    Retries on transient failures with linear back-off.
    Returns ``None`` when all attempts are exhausted.
    """

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "format": "json",
    }

    last_error: Optional[Exception] = None
    for attempt in range(1, max_retries + 1):
        try:
            resp = requests.post(OLLAMA_URL, json=payload, timeout=timeout)
            resp.raise_for_status()
            data = resp.json()
            text = data.get("response", "")
            # Quick sanity check – the model must return parseable JSON.
            json.loads(text)
            return text
        except (requests.RequestException, json.JSONDecodeError, KeyError, ValueError) as exc:
            last_error = exc
            logger.warning(
                "Ollama attempt %d/%d failed: %s", attempt, max_retries, exc
            )
            if attempt < max_retries:
                time.sleep(RETRY_BACKOFF * attempt)

    logger.error("Ollama query failed after %d retries: %s", max_retries, last_error)
    return None
