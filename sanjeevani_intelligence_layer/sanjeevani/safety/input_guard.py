"""
Input sanitization and validation — the security boundary.

Every external string entering the pipeline passes through here before
any processing. This is not paranoia — speech-to-text engines produce
malformed output regularly on noisy audio, and clean input makes every
downstream step simpler and safer.

What this defends against:
  • Null / missing input from a failed voice capture
  • Garbled STT output with control characters
  • Pathologically long strings from a stuck STT decoder
  • Repeated-character glitches (e.g. "aaaaaaaaa..." for 2000 chars)
  • Non-printable Unicode that could corrupt prompt construction

What this does NOT defend against:
  • Semantically misleading but syntactically valid text
    (that's the model's problem, bounded by RAG grounding)
"""
from __future__ import annotations

import re
import unicodedata

from sanjeevani.config import CFG
from sanjeevani.exceptions import InputError

# Matches ASCII and Latin-1 control characters except tab (\x09) and newline (\x0a)
_CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]")

# Matches 25+ consecutive identical characters — almost always an STT glitch
_REPEAT_RE = re.compile(r"(.)\1{24,}")


def sanitize_transcript(raw: str | None) -> str:
    """
    Sanitize a raw speech-to-text transcript.

    Args:
        raw: The raw string from the STT engine. May be None if capture failed.

    Returns:
        A clean, length-bounded, whitespace-normalized string.

    Raises:
        InputError: If input is None, empty, or becomes empty after cleaning.
    """
    if raw is None:
        raise InputError(
            "Transcript is None. Voice capture likely failed — check that the "
            "microphone recorded audio before calling analyse()."
        )

    # Normalize unicode (NFC → NFKC collapses compatibility forms,
    # converts non-breaking spaces to regular spaces, etc.)
    text: str = unicodedata.normalize("NFKC", raw)

    # Strip control characters (but keep \t and \n for now)
    text = _CONTROL_RE.sub("", text)

    # Collapse long character repetitions to at most 5 of the same char
    text = _REPEAT_RE.sub(lambda m: m.group(1) * 5, text)

    # Normalize all whitespace (tabs, newlines, multiple spaces) to single spaces
    text = " ".join(text.split())

    min_len = CFG.safety.min_transcript_chars
    if len(text) < min_len:
        raise InputError(
            f"Transcript is too short ({len(text)} chars) after sanitization. "
            f"Minimum is {min_len} characters. Check that the health worker "
            f"spoke clearly before the recording stopped."
        )

    max_len = CFG.safety.max_transcript_chars
    if len(text) > max_len:
        # Truncate at the last word boundary within the limit
        text = text[:max_len].rsplit(" ", 1)[0]

    return text
