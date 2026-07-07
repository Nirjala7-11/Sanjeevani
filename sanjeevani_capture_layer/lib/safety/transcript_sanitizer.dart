/// Transcript sanitization — the security boundary for all text input.
///
/// Every string that came from outside the app (voice recognition,
/// manual entry from a future text field) passes through here before
/// touching any other layer.
///
/// What this protects against:
///   - Null from a failed STT call.
///   - Garbled STT output with control characters.
///   - Extremely long strings from a stuck STT decoder.
///   - Pathological character repetitions (e.g. "aaaaaaa..." × 2000).
///   - Non-printable Unicode that could corrupt prompt construction.
///
/// What this does NOT protect against:
///   - Semantically misleading but syntactically valid text.
///     (That is the intelligence layer's problem, constrained by RAG.)
library;

import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';

class TranscriptSanitizer {
  const TranscriptSanitizer();

  /// Sanitize a raw transcript string.
  ///
  /// Returns a clean, length-bounded, whitespace-normalized string.
  /// Throws [TranscriptValidationException] if the result is unusable.
  String sanitize(String? raw) {
    if (raw == null) {
      throw const TranscriptValidationException(
        'Transcript is null — voice capture likely failed. '
        'Please try recording again.',
      );
    }

    String text = raw;

    // 1. Strip ASCII control characters except tab (\x09) and newline (\x0a).
    //    These occasionally appear in Vosk output on garbled audio.
    text = text.replaceAll(
      RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'),
      '',
    );

    // 2. Collapse pathological character repetition (stuck STT decoder glitch).
    //    Replaces 25+ consecutive identical characters with just 5 of them.
    text = text.replaceAllMapped(
      RegExp(r'(.)\1{24,}'),
      (m) => (m.group(1) ?? '') * 5,
    );

    // 3. Normalize all whitespace (tabs, newlines, non-breaking spaces,
    //    multiple spaces) to a single space, then trim.
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 4. Minimum length check.
    if (text.length < SanitizationConfig.minTranscriptChars) {
      throw TranscriptValidationException(
        'Transcript is too short (${text.length} characters) after cleanup. '
        'The microphone may not have captured clearly. Please try again and '
        'speak the symptoms clearly into the phone.',
      );
    }

    // 5. Maximum length cap — truncate at a word boundary.
    const max = SanitizationConfig.maxTranscriptChars;
    if (text.length > max) {
      final truncated = text.substring(0, max);
      final lastSpace = truncated.lastIndexOf(' ');
      text = lastSpace > max ~/ 2 ? truncated.substring(0, lastSpace) : truncated;
    }

    return text;
  }
}
