/// Package-wide exception hierarchy for the capture layer.
///
/// Design rules:
///   - Every exception the public API can throw inherits from [SanjeevaniCaptureException].
///   - Callers handle ONE base type; specific subtypes for fine-grained handling.
///   - Error messages must be actionable — they tell the health worker
///     what went wrong and what to do, not just what the code did.
library;

/// Base class for all exceptions from the capture layer.
class SanjeevaniCaptureException implements Exception {
  const SanjeevaniCaptureException(this.message, {this.cause});

  final String message;

  /// The underlying platform or library error, if any.
  final Object? cause;

  @override
  String toString() =>
      cause != null ? '$message (caused by: $cause)' : message;
}

/// Thrown when microphone permission is denied by the OS or the user.
class MicrophonePermissionException extends SanjeevaniCaptureException {
  const MicrophonePermissionException({Object? cause})
      : super(
          'Microphone permission was denied. '
          'Please grant microphone access in device Settings, '
          'then try again.',
          cause: cause,
        );
}

/// Thrown when audio recording starts, stops, or initializes incorrectly.
class AudioCaptureException extends SanjeevaniCaptureException {
  const AudioCaptureException(super.message, {super.cause});
}

/// Thrown when the STT engine fails to initialize or process audio.
class SpeechRecognitionException extends SanjeevaniCaptureException {
  const SpeechRecognitionException(super.message, {super.cause});
}

/// Thrown when a transcript is empty, too short, or unsanitizable.
class TranscriptValidationException extends SanjeevaniCaptureException {
  const TranscriptValidationException(super.message, {super.cause});
}

/// Thrown when a vital reading is outside physiological plausibility bounds.
///
/// This is almost always a data-entry error and should be shown to the
/// health worker as "please re-check this reading" rather than as an
/// application crash.
class VitalBoundaryException extends SanjeevaniCaptureException {
  const VitalBoundaryException(super.message, {super.cause});
}

/// Thrown when the call to the intelligence layer (local llama-server) fails.
class IntelligenceLayerException extends SanjeevaniCaptureException {
  const IntelligenceLayerException(super.message, {super.cause});
}
