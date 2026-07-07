/// Immutable, centralized configuration for the capture layer.
///
/// All thresholds, limits, and default values live here.
/// Changing a behaviour means changing this file — not hunting
/// through business logic for a magic number.
library;

/// Physiological plausibility bounds for manual vitals entry.
/// Outside these → [VitalBoundaryException] before any processing.
class VitalBounds {
  const VitalBounds._();

  static const double hrMin = 20.0;
  static const double hrMax = 250.0;
  static const double spo2Min = 40.0;
  static const double spo2Max = 100.0;
  static const double tempMinF = 86.0;
  static const double tempMaxF = 115.0;
}

/// Audio recording parameters.
class AudioConfig {
  const AudioConfig._();

  static const int sampleRate = 16000; // Hz — Vosk default, DO NOT change
  static const int channels = 1;       // Mono — required for Vosk
  static const int bitDepth = 16;      // 16-bit PCM
  static const int maxRecordingSeconds = 120; // 2 minutes hard cap
  static const Duration amplitudePollInterval = Duration(milliseconds: 80);
}

/// STT engine configuration.
class SttConfig {
  const SttConfig._();

  /// Asset paths for bundled Vosk models.
  static const String voskModelHindi =
      'assets/models/vosk-model-small-hi-0.22';
  static const String voskModelGujarati =
      'assets/models/vosk-model-small-gu-0.42';

  /// Minimum confidence score [0–1] to accept a Vosk recognition result.
  static const double minConfidence = 0.45;
}

/// Input sanitization limits.
class SanitizationConfig {
  const SanitizationConfig._();

  static const int minTranscriptChars = 2;
  static const int maxTranscriptChars = 2500;

  /// Repeating the same character more than this many times → collapse to 5.
  static const int maxCharRepeat = 25;
}

/// Intelligence layer connection.
///
/// SECURITY: host MUST be loopback. This is validated at runtime in
/// [IntelligenceClient]. Changing host to a real IP address would route
/// patient data off-device — that is a security violation, not a
/// configuration option.
class IntelligenceConfig {
  const IntelligenceConfig._();

  static const String host = '127.0.0.1';
  static const int port = 8080;
  static const Duration timeout = Duration(seconds: 30);
  static const Duration healthCheckTimeout = Duration(seconds: 3);

  static Uri get completionUri =>
      Uri.parse('http://$host:$port/completion');
  static Uri get healthUri =>
      Uri.parse('http://$host:$port/health');
}

/// Supported app languages (user-selectable at first launch).
enum AppLanguage {
  hindi('हिंदी', 'hi', SttConfig.voskModelHindi),
  gujarati('ગુજરાતી', 'gu', SttConfig.voskModelGujarati),
  english('English', 'en', null); // English uses device STT fallback

  const AppLanguage(this.displayName, this.code, this.voskModelPath);

  final String displayName;
  final String code;
  final String? voskModelPath; // null → use device STT
}
