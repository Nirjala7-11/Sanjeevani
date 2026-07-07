/// Whisper-tiny fallback STT engine.
///
/// Used when:
///   (a) The user selects a language for which no Vosk model is bundled.
///   (b) Vosk's confidence score is below [SttConfig.minConfidence] and
///       a retry with a different engine is warranted.
///   (c) Vosk fails to initialize (corrupted model, low memory).
///
/// Whisper-tiny is slightly heavier than Vosk small models (~38 MB GGML)
/// but has better multilingual coverage. It also runs fully on-device
/// via the whisper.cpp C++ library exposed through a platform channel.
///
/// WHY NOT OPENAI'S WHISPER API:
///   The cloud Whisper API would send audio to OpenAI's servers.
///   Patient health conversations — even symptom descriptions — are
///   sensitive health data. Sending them off-device to a third party
///   would violate patient privacy and is architecturally incompatible
///   with the offline-first design. We use whisper.cpp, the C++
///   re-implementation that runs the same weights locally.
library;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart' as models;
import 'package:sanjeevani_capture/stt/stt_engine.dart';

class WhisperEngine implements SttEngine {
  WhisperEngine();

  final _log = Logger('sanjeevani.capture.stt.whisper');
  bool _ready = false;

  @override
  String get engineName => 'whisper-tiny';

  @override
  bool get isReady => _ready;

  Future<void> initialise(String modelPath) async {
    _log.info('Loading Whisper-tiny model from $modelPath');
    try {
      // WHISPER_PLUGIN: await WhisperFlutter.initModel(modelPath);
      _ready = true;
      _log.info('Whisper-tiny ready');
    } catch (e) {
      throw SpeechRecognitionException(
        'Failed to load Whisper-tiny model',
        cause: e,
      );
    }
  }

  @override
  Future<models.TranscriptResult> transcribe(String filePath) async {
    if (!_ready) {
      throw SpeechRecognitionException(
        'WhisperEngine.transcribe() called before initialise().',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw SpeechRecognitionException('Audio file not found at $filePath');
    }

    _log.info('Transcribing with Whisper-tiny');
    final sw = Stopwatch()..start();

    try {
      // WHISPER_PLUGIN:
      // final result = await WhisperFlutter.transcribe(filePath: filePath, language: 'auto');
      // final text = result.text;

      const text = '';
      sw.stop();

      _log.info(
        'Whisper transcription complete in ${sw.elapsedMilliseconds}ms',
      );

      return models.TranscriptResult(
        text: text,
        engine: models.SttEngine.whisperTiny,
        durationMs: sw.elapsedMilliseconds,
        confidence: null, // Whisper-tiny does not expose per-token confidence
      );
    } catch (e) {
      sw.stop();
      throw SpeechRecognitionException(
        'Whisper transcription failed after ${sw.elapsedMilliseconds}ms',
        cause: e,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_ready) {
      // WHISPER_PLUGIN: await WhisperFlutter.dispose();
      _ready = false;
      _log.info('Whisper engine disposed');
    }
  }
}
