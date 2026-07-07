/// Abstract interface for speech-to-text engines.
///
/// All concrete STT implementations (Vosk, Whisper-tiny, device fallback)
/// implement [SttEngine]. The capture pipeline depends only on this interface,
/// never on a specific library. Swapping engines is a one-line change at the
/// construction site.
library;

import 'package:sanjeevani_capture/core/models.dart';

abstract class SttEngine {
  /// Human-readable name for logging and the UI fallback indicator.
  String get engineName;

  /// Returns true if this engine is ready to accept audio.
  bool get isReady;

  /// Transcribes an audio file at [filePath] and returns the result.
  ///
  /// Throws [SpeechRecognitionException] on failure.
  /// Never returns null — if nothing was recognized, returns an empty
  /// [TranscriptResult] with [TranscriptResult.isEmpty] == true.
  Future<TranscriptResult> transcribe(String filePath);

  /// Releases any resources held by the engine.
  Future<void> dispose();
}
