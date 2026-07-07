# Sanjeevani — Intelligence Layer v1.0

**Offline-first, RAG-grounded clinical decision-support for rural ASHA workers.**

---

## What this package does

Takes a set of patient vitals and an optional voice transcript, and returns
a `ClinicalRecommendation` — always, safely, regardless of whether the AI
model is available. It has no UI. It has no server of its own. It is called
by the Flutter app (Person A's layer).

---

## Quickstart

```python
# Step 1 — Create vitals (raises BoundaryError if readings are implausible)
from sanjeevani.core.models import PatientVitals
vitals = PatientVitals(heart_rate_bpm=120, spo2_pct=88, temperature_f=102.0)

# Step 2 — Choose a backend and build the engine
from sanjeevani.engine import IntelligenceEngine

# Development (Kaggle / Colab / GPU machine):
from sanjeevani.inference.huggingface import HuggingFaceBackend
engine = IntelligenceEngine(backend=HuggingFaceBackend())

# Production (Android app, fully offline):
from sanjeevani.inference.llamacpp import LlamaCppBackend
engine = IntelligenceEngine(backend=LlamaCppBackend())

# Step 3 — Analyse (identical for both backends)
rec = engine.analyse(vitals, transcript="child has fever and cough for three days")

# Step 4 — Use the result
print(rec.condition)          # "Respiratory infection"
print(rec.advice)             # "Refer to PHC today"
print(rec.referral_needed)    # True
print(rec.is_fallback)        # False (model responded correctly)
print(rec.risk.level.value)   # "HIGH"
print(rec.to_dict())          # JSON-serializable dict for the Flutter HTTP layer
```

---

## Why not Gradio

**Gradio is architecturally incompatible with Sanjeevani.** Three concrete reasons:

**1. Gradio is a server, not a library.**
`demo.launch()` starts an HTTP server. Without it running and reachable, the
application does not exist. Sanjeevani must work with zero connectivity in rural
villages. A server dependency contradicts that at the foundation, not at the edges.

**2. Gradio is a competing UI.**
Sanjeevani's UI is the Flutter app — voice input, regional-language rendering,
offline SQLite patient records, visit tracking. Running Gradio alongside Flutter
means two applications that cannot share a database, cannot share an APK, and
cannot share the voice/STT pipeline.

**3. Gradio's `share=True` routes patient data through the public internet.**
The flag creates a tunnel through Gradio's own infrastructure (`gradio.live`).
Patient symptom data — ASHA workers' most sensitive data — would leave the
device through a third-party public endpoint. This is a direct privacy violation.

**The correct architecture:** Flutter (UI) calls this Python package, which in
production calls a `llama-server` process bound to `127.0.0.1:8080` only.
Patient data never leaves the device.

---

## How to produce the offline model file

Do this once on a developer's machine with internet access:

```bash
git clone https://github.com/ggerganov/llama.cpp && cd llama.cpp
pip install -r requirements.txt

# Convert Hugging Face weights to GGUF
python convert_hf_to_gguf.py /path/to/gemma-2b-it --outfile gemma.gguf

# Quantize to 4-bit (~1.5 GB, runs on phone CPU, no GPU required)
./llama-quantize gemma.gguf gemma-q4_k_m.gguf q4_k_m

# Start the local server (what the Android app runs at startup)
./llama-server -m gemma-q4_k_m.gguf --host 127.0.0.1 --port 8080
```

After quantization, re-run `pytest tests/ -v` to confirm the safety tests
still pass against the quantized model via the LlamaCppBackend.

---

## Running the tests

```bash
pip install -r requirements.txt
pytest tests/ -v
```

All tests pass with no GPU, no model download, and no internet access.
Test coverage targets 85%+ (enforced in `pyproject.toml`).

---

## Security properties

| Property | Enforcement |
|---|---|
| No patient data in logs | Every `log.*()` call logs scores, timing, and types only — never vitals or transcript text |
| No secrets in source | `get_secret()` reads env vars only and never logs the value |
| Loopback-only production backend | `_assert_loopback()` raises `InferenceError` — not a warning — for any non-loopback address |
| Vitals validated at construction | `PatientVitals.__post_init__` raises `BoundaryError` on implausible readings |
| HIGH risk always forces referral | `output_guard.validate()` enforces this unconditionally; the model cannot de-escalate |
| Model failure always has a safe answer | `validate()` never raises and never returns `None` |
| All exceptions are typed | One base type (`SanjeevaniError`) to catch; specific subtypes for fine-grained handling |

---

## Package structure

```
sanjeevani/
  __init__.py           — public API surface (version, __all__)
  config.py             — ALL thresholds and settings in one immutable place
  exceptions.py         — typed exception hierarchy
  engine.py             — IntelligenceEngine (the only import callers need)
  core/
    models.py           — PatientVitals, RiskResult, ClinicalRecommendation
    risk_engine.py      — deterministic scoring, zero LLM dependency
    prompt_builder.py   — grounded, structured prompt construction
  knowledge/
    store.py            — KnowledgeStore: load, validate, FAISS retrieval
  inference/
    base.py             — abstract LLMBackend interface
    huggingface.py      — dev backend (GPU + HF token required)
    llamacpp.py         — production backend (loopback-only, offline)
  safety/
    input_guard.py      — transcript sanitization (security boundary)
    output_guard.py     — output parsing, override rule, safe fallback
  utils/
    logging_setup.py    — privacy-conscious rotating log setup
data/
  knowledge_base.json   — medical protocol entries (Person C owns this)
tests/
  test_exceptions.py
  test_config.py
  test_models.py
  test_risk_engine.py
  test_input_guard.py
  test_output_guard.py
  test_prompt_builder.py
  test_security.py
  test_integration.py
```

---

## Knowledge base

`data/knowledge_base.json` is owned by **Person C**. Each entry must have:
- `id` — unique string identifier
- `text` — the protocol text (what gets retrieved and shown to the LLM)
- `source_ref` — citation string shown in the UI (e.g. `"IMNCI Guidelines, Section 4.2"`)
- `tags` — optional list of strings for future filtering

The retrieval code never needs to change when entries are added or updated.
