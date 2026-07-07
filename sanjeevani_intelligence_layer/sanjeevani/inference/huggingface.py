"""
Hugging Face Transformers backend — DEVELOPMENT AND TESTING ONLY.

Never used in the shipped Android application.
Never used on a device without a GPU.
Never used in a context where network access to Hugging Face is unavailable.

Security:
  - The HF token is read from the environment via get_secret().
  - It is never logged, stored, or printed — not even partially.
  - Construction raises InferenceError (not a plain ValueError) if the
    token is absent, so the caller always gets the same exception type.
"""
from __future__ import annotations

import logging
import time

from sanjeevani.config import CFG, get_secret
from sanjeevani.exceptions import InferenceError
from sanjeevani.inference.base import InferenceResult, LLMBackend

log = logging.getLogger("sanjeevani.inference.huggingface")


class HuggingFaceBackend(LLMBackend):
    """
    Inference via Hugging Face Transformers.

    Requirements:
      - pip install transformers accelerate torch
      - HF_TOKEN environment variable set to a valid Hugging Face token.
      - A CUDA-capable GPU is strongly recommended (CPU runs too slowly).

    Usage:
        import os; os.environ["HF_TOKEN"] = "your_token"
        from sanjeevani.inference.huggingface import HuggingFaceBackend
        backend = HuggingFaceBackend()
    """

    @property
    def name(self) -> str:
        return f"huggingface:{CFG.hf.model_id}"

    def __init__(self) -> None:
        try:
            import torch
            from transformers import AutoModelForCausalLM, AutoTokenizer
        except ImportError as exc:
            raise InferenceError(
                "HuggingFaceBackend requires transformers and torch. "
                "Install with: pip install transformers accelerate torch\n"
                "Note: this backend is for development only and is NOT "
                "used in the production on-device build."
            ) from exc

        token = get_secret("HF_TOKEN")
        if token is None:
            raise InferenceError(
                "HF_TOKEN environment variable is not set. "
                "Set it before constructing HuggingFaceBackend. "
                "Never hard-code the token in source. "
                "The on-device LlamaCppBackend requires no token."
            )

        self._torch = torch
        mid = CFG.hf.model_id

        log.info("Loading tokenizer and model for %s", mid)
        # token is used here but NEVER logged — do not change this
        self._tokenizer = AutoTokenizer.from_pretrained(mid, token=token)
        self._model     = AutoModelForCausalLM.from_pretrained(mid, token=token)

        self._device = "cuda" if torch.cuda.is_available() else "cpu"
        self._model  = self._model.to(self._device)
        log.info("HuggingFace backend ready | device=%s", self._device)

    def generate(self, prompt: str) -> InferenceResult:
        t0 = time.monotonic()
        try:
            inputs = self._tokenizer(prompt, return_tensors="pt").to(self._device)
            with self._torch.no_grad():
                out = self._model.generate(
                    **inputs,
                    max_new_tokens=CFG.hf.max_new_tokens,
                    do_sample=CFG.hf.do_sample,
                    temperature=CFG.hf.temperature,
                    pad_token_id=self._tokenizer.eos_token_id,
                )
            full = self._tokenizer.decode(out[0], skip_special_tokens=True)
            # Strip the echoed prompt prefix from the output
            generated = (
                full[len(prompt):].strip()
                if full.startswith(prompt)
                else full.strip()
            )
        except Exception as exc:
            # Re-raise as InferenceError so callers handle ONE type
            raise InferenceError(
                f"Hugging Face generation failed: {type(exc).__name__}: {exc}"
            ) from exc

        if not generated:
            raise InferenceError("Hugging Face model returned an empty response.")

        ms = (time.monotonic() - t0) * 1000
        log.info("HF generate | chars=%d latency_ms=%.0f", len(generated), ms)
        # SECURITY: do not log `generated` — it may reference patient vitals
        return InferenceResult(text=generated, backend=self.name, latency_ms=ms)
