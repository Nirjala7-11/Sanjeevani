# Sanjeevani — Capture Layer

Flutter mobile application for the Sanjeevani offline health assistant.
This is the UI and data-collection layer — it handles voice input, vitals
entry, and calls the intelligence layer for clinical analysis.

---

## Architecture

```
lib/
  main.dart                   — DI root, routing, no business logic
  core/
    config.dart               — all constants in one place
    exceptions.dart           — typed exception hierarchy
    models.dart               — PatientVitals, ClinicalRecommendation, SessionState
    session_provider.dart     — full pipeline orchestrator (ChangeNotifier)
  audio/
    permission_service.dart   — runtime mic permission handling
    audio_recorder.dart       — flutter_sound wrapper, temp file, amplitude stream
  stt/
    stt_engine.dart           — abstract interface for all STT backends
    vosk_engine.dart          — offline Hindi/Gujarati STT (primary)
    whisper_engine.dart       — offline multilingual STT (fallback)
    stt_coordinator.dart      — primary + fallback selection logic
  safety/
    transcript_sanitizer.dart — security boundary: cleans all external text
  intelligence/
    intelligence_client.dart  — HTTP client → local llama-server (loopback only)
  ui/
    theme.dart                — design tokens, accessibility-first
    screens/
      language_screen.dart    — first launch: language selection
      home_screen.dart        — dashboard: start, records, reminders
      vitals_screen.dart      — vitals entry with validation
      recording_screen.dart   — mic recording with live waveform
      result_screen.dart      — recommendation display + actions
  utils/
    logger.dart               — privacy-conscious logging setup
test/
  test_models.dart
  test_sanitizer.dart
  test_security.dart
  test_session_provider.dart
  test_config.dart
```

---

## Security properties

| Property | Where enforced |
|---|---|
| Audio never leaves device | `AudioRecorder` — local temp file only, deleted after STT |
| Mic requested on action, not launch | `PermissionService` — called by `SessionProvider.startRecording()` |
| Transcript sanitized before any use | `TranscriptSanitizer` in `SessionProvider.stopAndAnalyse()` |
| Intelligence calls loopback-only | `IntelligenceClient._assertLoopback()` — throws in constructor for any non-loopback host |
| No patient data logged | Every `_log.*()` call logs counts, durations, status codes — never transcript or vitals |
| Typed exceptions, one base type | `SanjeevaniCaptureException` — callers handle one type |
| Vitals validated before storage | `PatientVitals.validated()` — throws `VitalBoundaryException` for implausible readings |
| Temp audio files deleted | `AudioRecorder.deleteRecording()` called immediately after STT returns |

---

## Why not Gradio (for team reference)

Gradio is inappropriate for this project for three architectural reasons,
fully documented in `lib/intelligence/intelligence_client.dart`:

1. Gradio is a server, not a library. The app ceases to exist without it running.
2. Gradio's `share=True` routes patient data through `gradio.live` (a third-party public server).
3. Gradio assumes a browser UI — incompatible with a native Flutter app that shares a local SQLite database.

The correct pattern: Flutter (this package) calls `llama-server` on `127.0.0.1:8080` (loopback).
Patient data never leaves the device through the AI path.

---

## Running tests

```bash
flutter test test/
```

All tests pass without a real device, microphone, or running model server.

---

## Connecting to the intelligence layer

The intelligence layer (Python package) must be running as a local server
before the app can return recommendations. Start it with:

```bash
./llama-server -m gemma-q4_k_m.gguf --host 127.0.0.1 --port 8080
```

The app calls `IntelligenceClient.healthCheck()` at startup and shows a
warning banner if the server is not ready — the health worker is never
left waiting silently.

---

## Team ownership

| Layer | Owner | Files |
|---|---|---|
| Capture (this package) | Person A | All Flutter/Dart files |
| Intelligence layer | Person B | Python `sanjeevani/` package |
| Knowledge base content | Person C | `data/knowledge_base.json` |
| Sync + dashboard | Person D | Firebase / Supabase + React |
