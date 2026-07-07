/// Session state provider.
///
/// Owns the [SessionState] for one consultation and exposes the
/// complete capture pipeline as a single [analyse()] method.
///
/// All state mutations happen through this provider — no widget
/// ever touches [AudioRecorder], [SttCoordinator], or
/// [IntelligenceClient] directly. This keeps the pipeline testable:
/// tests can construct a [SessionProvider] with mocked services
/// and verify the full flow without a running phone or model server.
library;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sanjeevani_capture/audio/audio_recorder.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart';
import 'package:sanjeevani_capture/intelligence/intelligence_client.dart';
import 'package:sanjeevani_capture/safety/transcript_sanitizer.dart';
import 'package:sanjeevani_capture/stt/stt_coordinator.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required AudioRecorder audioRecorder,
    required SttCoordinator sttCoordinator,
    required TranscriptSanitizer sanitizer,
    required IntelligenceClient intelligenceClient,
  })  : _recorder = audioRecorder,
        _stt = sttCoordinator,
        _sanitizer = sanitizer,
        _client = intelligenceClient;

  final AudioRecorder _recorder;
  final SttCoordinator _stt;
  final TranscriptSanitizer _sanitizer;
  final IntelligenceClient _client;
  final _log = Logger('sanjeevani.capture.session');

  SessionState _state = const SessionState();
  SessionState get state => _state;

  String? _currentAudioPath;

  // ── Language selection ────────────────────────────────────────────────────

  void setLanguage(AppLanguage language) {
    _setState(_state.copyWith(language: language));
  }

  // ── Vitals entry ──────────────────────────────────────────────────────────

  /// Validates and stores vitals.
  /// Throws [VitalBoundaryException] if any reading is implausible.
  void setVitals({
    required double heartRateBpm,
    required double spo2Pct,
    required double temperatureF,
  }) {
    // Validation throws before state is updated — invalid vitals are never stored.
    final vitals = PatientVitals.validated(
      heartRateBpm: heartRateBpm,
      spo2Pct: spo2Pct,
      temperatureF: temperatureF,
    );
    _setState(_state.copyWith(vitals: vitals));
  }

  // ── Recording pipeline ────────────────────────────────────────────────────

  /// Start microphone recording.
  Future<void> startRecording() async {
    if (_state.isRecording) return;

    _setState(_state.copyWith(recording: RecordingState.requesting));

    try {
      _currentAudioPath = await _recorder.startRecording();
      _setState(_state.copyWith(recording: RecordingState.recording));

      // Wire amplitude stream to state for the live waveform widget.
      _recorder.amplitudeStream.listen(
        (db) => _setState(_state.copyWith(amplitudeDb: db)),
      );

      _log.info('Recording started');
    } on SanjeevaniCaptureException catch (e) {
      _setError(e.message, RecordingState.error);
    } catch (e) {
      _setError('Unexpected error starting recording.', RecordingState.error);
      _log.severe('Unexpected error in startRecording: $e');
    }
  }

  /// Stop recording, transcribe, sanitize, and call the intelligence layer.
  Future<void> stopAndAnalyse() async {
    if (!_state.isRecording) return;

    _setState(_state.copyWith(recording: RecordingState.processing));

    try {
      // ── 1. Stop audio ──────────────────────────────────────────────────
      final audioPath = await _recorder.stopRecording();
      if (audioPath == null) {
        throw const AudioCaptureException(
          'Recording stopped but no audio file was produced.',
        );
      }

      // ── 2. Speech-to-text ──────────────────────────────────────────────
      final transcriptResult = await _stt.transcribe(audioPath, _state.language);
      _log.info('STT result: $transcriptResult');

      // ── 3. Delete audio — not persisted ───────────────────────────────
      await _recorder.deleteRecording(audioPath);
      _currentAudioPath = null;

      // ── 4. Sanitize transcript ────────────────────────────────────────
      final cleanTranscript = _sanitizer.sanitize(
        transcriptResult.isEmpty ? null : transcriptResult.text,
      );

      _setState(_state.copyWith(
        transcript: TranscriptResult(
          text: cleanTranscript,
          engine: transcriptResult.engine,
          durationMs: transcriptResult.durationMs,
          confidence: transcriptResult.confidence,
        ),
      ));

      // ── 5. Ensure vitals are present ──────────────────────────────────
      final vitals = _state.vitals;
      if (vitals == null) {
        throw const VitalBoundaryException(
          'Vitals have not been entered. '
          'Please fill in heart rate, SpO2, and temperature before recording.',
        );
      }

      // ── 6. Intelligence layer ─────────────────────────────────────────
      final recommendation = await _client.analyse(
        vitals: vitals,
        transcript: cleanTranscript,
      );

      _setState(_state.copyWith(
        recording: RecordingState.done,
        recommendation: recommendation,
      ));

      _log.info(
        'Analysis complete: risk=${recommendation.riskLevel.value} '
        'referral=${recommendation.referralNeeded} '
        'fallback=${recommendation.isFallback}',
      );

    } on TranscriptValidationException catch (e) {
      _setError(e.message, RecordingState.error);
    } on VitalBoundaryException catch (e) {
      _setError(e.message, RecordingState.error);
    } on SpeechRecognitionException catch (e) {
      _setError(e.message, RecordingState.error);
    } on IntelligenceLayerException catch (e) {
      _setError(e.message, RecordingState.error);
    } on AudioCaptureException catch (e) {
      _setError(e.message, RecordingState.error);
    } catch (e) {
      _setError('An unexpected error occurred.', RecordingState.error);
      _log.severe('Unexpected error in stopAndAnalyse: $e');
    }
  }

  /// Reset to a clean state, preserving language and vitals.
  void reset() {
    _setState(_state.reset());
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _setState(SessionState next) {
    _state = next;
    notifyListeners();
  }

  void _setError(String message, RecordingState recState) {
    _log.warning('Session error: $message');
    _setState(_state.copyWith(recording: recState, error: message));
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
    _client.dispose();
    super.dispose();
  }
}
