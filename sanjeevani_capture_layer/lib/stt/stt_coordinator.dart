/// STT coordinator — manages primary and fallback engines.
///
/// Responsibilities:
///   - Select the correct primary engine for the chosen language.
///   - Automatically retry with Whisper-tiny if Vosk returns low
///     confidence or throws.
///   - Return the best [TranscriptResult] to the capture pipeline.
///
/// Design: the coordinator knows about both engines but the rest of
/// the pipeline only ever calls [SttCoordinator.transcribe()]. Engine
/// selection logic is centralised here and nowhere else.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart';
import 'package:sanjeevani_capture/stt/vosk_engine.dart';
import 'package:sanjeevani_capture/stt/whisper_engine.dart';

class SttCoordinator {
  SttCoordinator({
    required VoskEngine hindiEngine,
    required VoskEngine gujaratiEngine,
    required WhisperEngine fallbackEngine,
  })  : _hindi = hindiEngine,
        _gujarati = gujaratiEngine,
        _fallback = fallbackEngine;

  final VoskEngine _hindi;
  final VoskEngine _gujarati;
  final WhisperEngine _fallback;
  final _log = Logger('sanjeevani.capture.stt.coordinator');

  /// Transcribe [filePath] using the appropriate engine for [language].
  ///
  /// Falls back to Whisper-tiny if:
  ///   - The primary engine throws.
  ///   - The primary engine returns a result with confidence below threshold.
  ///
  /// Throws [SpeechRecognitionException] only if both primary and fallback fail.
  Future<TranscriptResult> transcribe(
    String filePath,
    AppLanguage language,
  ) async {
    final primary = _engineFor(language);

    if (primary == null || !primary.isReady) {
      _log.warning(
        'No ready primary engine for $language — using Whisper-tiny directly',
      );
      return _fallback.transcribe(filePath);
    }

    // ── Attempt primary engine ──────────────────────────────────────────────
    TranscriptResult result;
    try {
      result = await primary.transcribe(filePath);
      _log.info('Primary STT (${primary.engineName}): $result');
    } catch (e) {
      _log.warning(
        'Primary STT (${primary.engineName}) threw — trying Whisper fallback: $e',
      );
      return _withFallback(filePath);
    }

    // ── Check confidence — fallback if too low ──────────────────────────────
    final conf = result.confidence;
    if (conf != null && conf < SttConfig.minConfidence) {
      _log.info(
        'Vosk confidence ${conf.toStringAsFixed(2)} below threshold '
        '${SttConfig.minConfidence} — retrying with Whisper-tiny',
      );
      try {
        final fallbackResult = await _withFallback(filePath);
        // Use fallback only if it actually returned text.
        if (!fallbackResult.isEmpty) return fallbackResult;
      } catch (_) {
        _log.warning('Whisper fallback also failed — using Vosk result anyway');
      }
    }

    return result;
  }

  VoskEngine? _engineFor(AppLanguage language) {
    switch (language) {
      case AppLanguage.hindi:
        return _hindi;
      case AppLanguage.gujarati:
        return _gujarati;
      case AppLanguage.english:
        return null; // English goes straight to Whisper/device
    }
  }

  Future<TranscriptResult> _withFallback(String filePath) async {
    if (!_fallback.isReady) {
      throw SpeechRecognitionException(
        'Both primary Vosk engine and Whisper-tiny fallback are unavailable. '
        'Check that STT models were correctly bundled at build time.',
      );
    }
    return _fallback.transcribe(filePath);
  }
}
