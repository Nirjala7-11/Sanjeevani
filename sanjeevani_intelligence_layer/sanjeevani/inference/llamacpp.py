"""
llama.cpp local server backend — PRODUCTION (on-device, fully offline).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHY GRADIO CANNOT BE USED IN THE SANJEEVANI PRODUCTION APPLICATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This section is written once, clearly, so the team understands the
architectural decision and can explain it to judges.

WHAT GRADIO DOES:
  Gradio's `demo.launch()` starts an HTTP web server. That server IS the
  application. There is no Gradio app without it running and reachable.
  The user interface (sliders, text boxes, markdown output) is served as
  HTML from that server to a web browser.

WHY THAT ARCHITECTURE FAILS FOR SANJEEVANI:

  Problem 1 — Connectivity dependency.
    The server must be running and reachable for the app to work.
    Sanjeevani's entire value proposition is that it works with ZERO
    connectivity in rural villages where there is no network. A server
    dependency contradicts that at the architectural level, not just at
    the implementation level.

  Problem 2 — Two competing UIs.
    Sanjeevani's real UI is the Flutter app (Person A). It has voice input,
    regional language rendering, offline SQLite records, and visit tracking.
    Running Gradio alongside Flutter means two applications that:
      • Cannot share the same SQLite patient records database.
      • Cannot be packaged as a single APK the ASHA worker downloads once.
      • Cannot share the voice/STT pipeline.
      • Cannot be installed silently on a village health worker's phone.
    'Both work together' is not an option — they are architecturally separate.

  Problem 3 — share=True routes patient data through the internet.
    `share=True` (needed to reach the app from a mobile phone on a different
    device from the one running Gradio) creates a public tunnel through
    Gradio's own infrastructure at gradio.live. Patient symptom data — the
    most sensitive health data ASHA workers handle — would pass through a
    third-party public endpoint the project does not control. This violates
    patient privacy and would be disqualifying for any real deployment.

  Problem 4 — Wrong abstraction layer.
    Gradio conflates 'run the model' and 'show the user a UI' into one call.
    In a production system these must be separate:
      • The model runs as a service (this file).
      • The UI runs as the Flutter app (Person A's code).
      • They communicate over a well-defined interface.
    Gradio's design makes this separation impossible without removing Gradio
    entirely — which is exactly what this file does.

THE CORRECT PRODUCTION ARCHITECTURE:
  1. At app startup, the Flutter app starts a `llama-server` process locally.
  2. That process binds to 127.0.0.1:8080 ONLY — physically unreachable
     from any other device, even on the same Wi-Fi network.
  3. This LlamaCppBackend class calls that local server over HTTP/localhost.
  4. Patient data (the prompt) travels from Flutter → Python → localhost:8080
     and back. It never leaves the device.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HOW TO PRODUCE THE OFFLINE MODEL FILE (one-time, on a developer's machine)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  git clone https://github.com/ggerganov/llama.cpp
  cd llama.cpp
  pip install -r requirements.txt

  # Convert from Hugging Face format to GGUF (llama.cpp native format)
  python convert_hf_to_gguf.py /path/to/gemma-2b-it --outfile gemma.gguf

  # Quantize to 4-bit (shrinks ~5 GB → ~1.5 GB, runs on phone CPU)
  ./llama-quantize gemma.gguf gemma-q4_k_m.gguf q4_k_m

  # The resulting .gguf file is what ships inside or is downloaded by the app.
  # After quantization, verify structured output still parses correctly by
  # running: pytest tests/ -v -k test_integration

HOW TO START THE LOCAL SERVER (runs at Android app startup):
  ./llama-server -m gemma-q4_k_m.gguf --host 127.0.0.1 --port 8080

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SECURITY PROPERTIES ENFORCED IN CODE (not just documented)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • _assert_loopback() raises InferenceError (not just logs a warning) if
    the configured host is anything other than a loopback address.
    This cannot be silenced by a config flag. It is not a soft check.

  • No authentication token, API key, or credential of any kind is used.
    The loopback server is unreachable from outside the device — it needs
    no authentication because the threat model assumes physical device control.

  • No model output is logged. The InferenceResult.text field contains the
    model's response which may reference vitals or symptom content.
"""
from __future__ import annotations

import ipaddress
import logging
import time
from typing import Optional

import requests

from sanjeevani.config import CFG
from sanjeevani.exceptions import InferenceError
from sanjeevani.inference.base import InferenceResult, LLMBackend

log = logging.getLogger("sanjeevani.inference.llamacpp")

_LOOPBACK_NAMES = frozenset({"127.0.0.1", "localhost", "::1"})


def _assert_loopback(host: str) -> None:
    """
    Hard security check. Raises InferenceError for any non-loopback host.

    This is not a soft warning. It is not configurable. If you find yourself
    wanting to disable it, the architecture of the deployment is wrong —
    not this check.
    """
    if host in _LOOPBACK_NAMES:
        return
    try:
        if ipaddress.ip_address(host).is_loopback:
            return
    except ValueError:
        pass  # Not an IP address — hostname not on the loopback list = fail

    raise InferenceError(
        f"SECURITY VIOLATION: LlamaCppBackend refuses to connect to '{host}'.\n"
        "The on-device inference backend must ONLY communicate with 127.0.0.1 "
        "(loopback). Connecting to any other address would route patient health "
        "data off-device through a network that the system does not control.\n"
        "This restriction is not configurable. If you need a networked model "
        "for development, use HuggingFaceBackend instead."
    )


class LlamaCppBackend(LLMBackend):
    """
    Calls a llama-server process running locally on the device.

    The server must already be running when this backend is used.
    Call health_check() once at app startup to verify.

    Usage:
        backend = LlamaCppBackend()              # uses config defaults
        backend = LlamaCppBackend(port=8081)     # custom port
    """

    def __init__(
        self,
        host: Optional[str] = None,
        port: Optional[int] = None,
    ) -> None:
        self._host = host or CFG.llamacpp.host
        self._port = port or CFG.llamacpp.port

        # Security check — raises before any network call is even attempted
        _assert_loopback(self._host)

        self._base_url = f"http://{self._host}:{self._port}"
        log.info("LlamaCppBackend configured | endpoint=%s", self._base_url)

    @property
    def name(self) -> str:
        return f"llama-cpp:{self._host}:{self._port}"

    @property
    def base_url(self) -> str:
        return self._base_url

    def health_check(self) -> bool:
        """
        Ping the local server's /health endpoint.
        Returns True if the model is loaded and ready, False otherwise.
        Does not raise — used at startup to give a friendly error message
        before any patient consultation begins.
        """
        try:
            r = requests.get(
                f"{self._base_url}/health",
                timeout=CFG.llamacpp.health_timeout_s,
            )
            return r.status_code == 200
        except requests.RequestException:
            return False

    def generate(self, prompt: str) -> InferenceResult:
        t0 = time.monotonic()

        payload = {
            "prompt":      prompt,
            "n_predict":   CFG.llamacpp.max_tokens,
            "temperature": CFG.llamacpp.temperature,
            "stop":        list(CFG.llamacpp.stop_tokens),
        }

        try:
            resp = requests.post(
                f"{self._base_url}/completion",
                json=payload,
                timeout=CFG.llamacpp.timeout_s,
            )
            resp.raise_for_status()
            data = resp.json()
        except requests.Timeout as exc:
            raise InferenceError(
                "On-device model timed out. The device may be under heavy "
                "CPU load. The safety fallback will provide a safe response."
            ) from exc
        except requests.ConnectionError as exc:
            raise InferenceError(
                "Cannot reach the local llama-server at "
                f"{self._base_url}. Verify that the model server started "
                "successfully at app launch."
            ) from exc
        except requests.HTTPError as exc:
            raise InferenceError(
                f"llama-server returned HTTP {resp.status_code}: {exc}"
            ) from exc
        except (requests.RequestException, ValueError, KeyError) as exc:
            raise InferenceError(
                f"On-device inference call failed: {type(exc).__name__}: {exc}"
            ) from exc

        text = data.get("content", "").strip()
        if not text:
            raise InferenceError(
                "llama-server returned an empty 'content' field. "
                "The model may still be loading, or the prompt exceeded "
                "its context window."
            )

        ms = (time.monotonic() - t0) * 1000
        log.info(
            "LlamaCpp generate | chars=%d latency_ms=%.0f", len(text), ms
        )
        # SECURITY: do not log `text` — it references the model's output
        # which was derived from patient vitals and symptom description
        return InferenceResult(text=text, backend=self.name, latency_ms=ms)
