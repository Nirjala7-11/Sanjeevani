"""
Privacy-conscious structured logging setup.

What this logs:   risk scores, levels, timing, backend names, error types.
What this NEVER logs: vitals values, transcript text, patient identifiers.

Logging patient health data — even in a debug log on-device — is a
privacy violation. The test suite's security tests verify this property.
"""
from __future__ import annotations

import logging
import logging.handlers
from pathlib import Path

_CONFIGURED = False
_LOG_FORMAT = (
    "%(asctime)s | %(levelname)-8s | %(name)-38s | %(message)s"
)
_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def setup(log_dir: Path, level: int = logging.INFO) -> None:
    """
    Idempotent: safe to call multiple times, only configures once.
    Sets up both a rotating file handler and a console handler.
    """
    global _CONFIGURED
    if _CONFIGURED:
        return

    log_dir.mkdir(parents=True, exist_ok=True)
    formatter = logging.Formatter(_LOG_FORMAT, datefmt=_DATE_FORMAT)

    # Rotating file — max 5 MB × 5 backups = 25 MB max on disk
    file_h = logging.handlers.RotatingFileHandler(
        log_dir / "sanjeevani.log",
        maxBytes=5_242_880,
        backupCount=5,
        encoding="utf-8",
    )
    file_h.setFormatter(formatter)
    file_h.setLevel(level)

    console_h = logging.StreamHandler()
    console_h.setFormatter(formatter)
    console_h.setLevel(level)

    root = logging.getLogger("sanjeevani")
    root.setLevel(level)
    root.addHandler(file_h)
    root.addHandler(console_h)
    root.propagate = False

    _CONFIGURED = True
