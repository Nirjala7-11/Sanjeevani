"""
Abstract inference backend interface.

All concrete backends implement exactly this interface.
Every other module depends on LLMBackend, never on transformers or requests.
Swapping dev for production is a one-line change at the construction site.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class InferenceResult:
    text:       str
    backend:    str
    latency_ms: float


class LLMBackend(ABC):
    """
    Abstract base for all inference backends.

    Contract:
      - generate() returns InferenceResult on success.
      - generate() raises InferenceError (from sanjeevani.exceptions) on failure.
      - All backend-specific exceptions must be caught internally and
        re-raised as InferenceError. The caller handles ONE exception type.
      - Implementations must never log prompt text (contains patient data).
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable backend identifier for logging and audit."""

    @abstractmethod
    def generate(self, prompt: str) -> InferenceResult:
        """
        Run inference on the given prompt.

        Args:
            prompt: The complete, grounded prompt from prompt_builder.build().

        Returns:
            InferenceResult with the model's text output and timing.

        Raises:
            InferenceError: For any failure — timeout, connection error,
                            empty output, model error. Never a raw library
                            exception type.
        """
        raise NotImplementedError
