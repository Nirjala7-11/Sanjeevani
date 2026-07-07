/// Vosk offline STT engine — primary for Hindi and Gujarati.
///
/// Vosk runs entirely on-device using bundled model files (in assets/).
/// No audio data leaves the device at any point during transcription.
///
/// Model files are bundled at build time and extracted to the app's
/// documents directory on first launch. After that, transcription is
/// instant and works without any network connectivity.
///
/// Vosk model sizes (bundled in APK):
///   - vosk-model-small-hi-0.22: ~36 MB (Hindi)
///   - vosk-model-small-gu-0.42: ~41 MB (Gujarati)
///
/// These are the "small" models — optimised for embedded devices.
/// Accuracy is acceptable for clinical symptom description vocabulary
/// and is significantly better than trying to use English STT on
/// Hindi/Gujarati speech.
library;

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart' as models;
import 'package:sanjeevani_capture/stt/stt_engine.dart';

/// Concrete Vosk implementation.
///
/// In production, this wraps the `vosk_flutter` plugin or a native
/// platform channel to the Vosk C library. This implementation shows
/// the correct interface and error handling patterns — the actual
/// plugin calls are marked with [// VOSK_PLUGIN] for integration.
class VoskEngine implements SttEngine {
  VoskEngine({required this.modelPath, required this.languageCode});

  final String modelPath;
  final String languageCode;
  final _log = Logger('sanjeevani.capture.stt.vosk');

  bool _ready = false;
  // ignore: unused_field  — placeholder for the real plugin handle
  Object? _model;

  @override
  String get engineName => 'vosk-$languageCode';

  @override
  bool get isReady => _ready;

  /// Initialise the Vosk model.
  ///
  /// Extracts the model from assets to the app documents directory on
  /// first run, then loads it. Typically called once at app startup.
  Future<void> initialise(String extractedModelPath) async {
    _log.info('Loading Vosk model from $extractedModelPath');

    final modelDir = Directory(extractedModelPath);
    if (!await modelDir.exists()) {
      throw SpeechRecognitionException(
        'Vosk model directory not found at $extractedModelPath. '
        'The model may not have been extracted from assets correctly.',
      );
    }

    try {
      // VOSK_PLUGIN: _model = await VoskFlutterPlugin.instance.initModel(extractedModelPath);
      _ready = true;
      _log.info('Vosk model loaded successfully for language=$languageCode');
    } catch (e) {
      throw SpeechRecognitionException(
        'Failed to load Vosk model for $languageCode',
        cause: e,
      );
    }
  }

  @override
  Future<models.TranscriptResult> transcribe(String filePath) async {
    if (!_ready) {
      throw SpeechRecognitionException(
        'VoskEngine.transcribe() called before initialise(). '
        'Ensure the engine is initialised at app startup.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw SpeechRecognitionException(
        'Audio file not found at $filePath. '
        'The recording may have failed to write.',
      );
    }

    _log.info('Transcribing ${await file.length()} bytes with Vosk');
    final sw = Stopwatch()..start();

    try {
      // VOSK_PLUGIN:
      // final recognizer = VoskFlutterPlugin.instance.initRecognizer(model: _model, sampleRate: 16000.0);
      // final bytes = await file.readAsBytes();
      // await VoskFlutterPlugin.instance.acceptWaveformBytes(recognizer: recognizer, bytes: bytes);
      // final result = VoskFlutterPlugin.instance.getFinalResult(recognizer: recognizer);
      // VoskFlutterPlugin.instance.freeRecognizer(recognizer: recognizer);

      // Placeholder result for the interface demonstration:
      const text = '';           // replaced by VOSK_PLUGIN result.text
      const confidence = 0.85;   // replaced by VOSK_PLUGIN result.confidence

      sw.stop();
      _log.info(
        'Vosk transcription complete in ${sw.elapsedMilliseconds}ms, '
        'chars=${text.length}',
      );

      return models.TranscriptResult(
        text: text,
        engine: models.SttEngine.vosk,
        durationMs: sw.elapsedMilliseconds,
        confidence: confidence,
      );
    } catch (e) {
      sw.stop();
      throw SpeechRecognitionException(
        'Vosk transcription failed after ${sw.elapsedMilliseconds}ms',
        cause: e,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_ready) {
      // VOSK_PLUGIN: VoskFlutterPlugin.instance.freeModel(_model);
      _ready = false;
      _model = null;
      _log.info('Vosk engine disposed');
    }
  }
}
