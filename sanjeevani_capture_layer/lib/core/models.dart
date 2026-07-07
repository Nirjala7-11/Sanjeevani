/// Typed, immutable data models for the capture layer.
///
/// Design decisions:
///   - All models are immutable (final fields, const constructors where possible).
///   - Validation happens at construction via [PatientVitals.validated].
///   - No Map<String, dynamic> in the call path — typed objects everywhere.
///   - [ClinicalRecommendation] is the intelligence layer's response model,
///     mirroring the Python package's ClinicalRecommendation.to_dict() output.
library;

import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';

// ── Enumerations ─────────────────────────────────────────────────────────────

enum RiskLevel {
  low('LOW', 'Low risk'),
  medium('MEDIUM', 'Medium risk'),
  high('HIGH', 'High risk');

  const RiskLevel(this.value, this.displayName);

  final String value;
  final String displayName;

  static RiskLevel fromString(String s) {
    return RiskLevel.values.firstWhere(
      (e) => e.value == s.toUpperCase(),
      orElse: () => throw ArgumentError('Unknown risk level: $s'),
    );
  }
}

enum RecordingState { idle, requesting, recording, processing, done, error }

enum SttEngine { vosk, whisperTiny, deviceFallback }

// ── Input models ──────────────────────────────────────────────────────────────

/// Validated, immutable vital signs.
///
/// Never construct directly — use [PatientVitals.validated] which runs
/// physiological plausibility checks before returning an instance.
class PatientVitals {
  const PatientVitals._({
    required this.heartRateBpm,
    required this.spo2Pct,
    required this.temperatureF,
  });

  final double heartRateBpm;
  final double spo2Pct;
  final double temperatureF;

  /// Factory that validates before constructing.
  /// Throws [VitalBoundaryException] for implausible readings.
  factory PatientVitals.validated({
    required double heartRateBpm,
    required double spo2Pct,
    required double temperatureF,
  }) {
    _check('Heart rate (bpm)', heartRateBpm, VitalBounds.hrMin, VitalBounds.hrMax);
    _check('SpO2 (%)', spo2Pct, VitalBounds.spo2Min, VitalBounds.spo2Max);
    _check('Temperature (°F)', temperatureF, VitalBounds.tempMinF, VitalBounds.tempMaxF);
    return PatientVitals._(
      heartRateBpm: heartRateBpm,
      spo2Pct: spo2Pct,
      temperatureF: temperatureF,
    );
  }

  static void _check(String label, double val, double lo, double hi) {
    if (val < lo || val > hi) {
      throw VitalBoundaryException(
        '$label reading of $val is outside the plausible physiological '
        'range [$lo, $hi]. This is likely a sensor or data-entry error. '
        'Please re-check the reading before proceeding.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'heart_rate_bpm': heartRateBpm,
        'spo2_pct': spo2Pct,
        'temperature_f': temperatureF,
      };

  @override
  String toString() =>
      'PatientVitals(hr=${heartRateBpm.toStringAsFixed(0)}bpm, '
      'spo2=${spo2Pct.toStringAsFixed(0)}%, '
      'temp=${temperatureF.toStringAsFixed(1)}°F)';
}

// ── STT result ────────────────────────────────────────────────────────────────

/// The clean output of the speech-to-text pipeline.
class TranscriptResult {
  const TranscriptResult({
    required this.text,
    required this.engine,
    required this.durationMs,
    this.confidence,
  });

  final String text;
  final SttEngine engine;
  final int durationMs;

  /// Confidence score [0–1], if the engine provides one. Null = unavailable.
  final double? confidence;

  bool get isEmpty => text.isEmpty;

  @override
  String toString() =>
      'TranscriptResult(engine=$engine, chars=${text.length}, '
      'confidence=${confidence?.toStringAsFixed(2) ?? "n/a"})';
}

// ── Intelligence layer response ───────────────────────────────────────────────

/// A knowledge base passage retrieved by the Python intelligence layer.
class KnowledgePassage {
  const KnowledgePassage({
    required this.entryId,
    required this.sourceRef,
    required this.similarity,
  });

  final String entryId;
  final String sourceRef;
  final double similarity;

  factory KnowledgePassage.fromJson(Map<String, dynamic> json) =>
      KnowledgePassage(
        entryId: json['entry_id'] as String,
        sourceRef: json['source_ref'] as String,
        similarity: (json['similarity'] as num).toDouble(),
      );
}

/// The complete response from the intelligence layer.
/// Mirrors the Python ClinicalRecommendation.to_dict() output exactly.
class ClinicalRecommendation {
  const ClinicalRecommendation({
    required this.condition,
    required this.advice,
    required this.referralNeeded,
    required this.riskLevel,
    required this.riskScore,
    required this.alerts,
    required this.isFallback,
    required this.sources,
    this.backendUsed,
    this.latencyMs,
  });

  final String condition;
  final String advice;
  final bool referralNeeded;
  final RiskLevel riskLevel;
  final int riskScore;
  final List<String> alerts;
  final bool isFallback;
  final List<KnowledgePassage> sources;
  final String? backendUsed;
  final double? latencyMs;

  factory ClinicalRecommendation.fromJson(Map<String, dynamic> json) =>
      ClinicalRecommendation(
        condition: json['condition'] as String,
        advice: json['advice'] as String,
        referralNeeded: json['referral_needed'] as bool,
        riskLevel: RiskLevel.fromString(json['risk_level'] as String),
        riskScore: json['risk_score'] as int,
        alerts: List<String>.from(json['alerts'] as List),
        isFallback: json['is_fallback'] as bool,
        sources: (json['sources'] as List)
            .map((s) => KnowledgePassage.fromJson(s as Map<String, dynamic>))
            .toList(),
        backendUsed: json['backend_used'] as String?,
        latencyMs: (json['latency_ms'] as num?)?.toDouble(),
      );
}

// ── Session state ─────────────────────────────────────────────────────────────

/// The full state of a single consultation session.
/// Held in [SessionProvider] and never mutated in place —
/// always replaced with a new instance via copyWith.
class SessionState {
  const SessionState({
    this.recording = RecordingState.idle,
    this.language = AppLanguage.hindi,
    this.transcript,
    this.vitals,
    this.recommendation,
    this.amplitudeDb = 0.0,
    this.error,
  });

  final RecordingState recording;
  final AppLanguage language;
  final TranscriptResult? transcript;
  final PatientVitals? vitals;
  final ClinicalRecommendation? recommendation;
  final double amplitudeDb;
  final String? error;

  bool get hasResult => recommendation != null;
  bool get isRecording => recording == RecordingState.recording;

  SessionState copyWith({
    RecordingState? recording,
    AppLanguage? language,
    TranscriptResult? transcript,
    PatientVitals? vitals,
    ClinicalRecommendation? recommendation,
    double? amplitudeDb,
    String? error,
  }) =>
      SessionState(
        recording: recording ?? this.recording,
        language: language ?? this.language,
        transcript: transcript ?? this.transcript,
        vitals: vitals ?? this.vitals,
        recommendation: recommendation ?? this.recommendation,
        amplitudeDb: amplitudeDb ?? this.amplitudeDb,
        error: error ?? this.error,
      );

  /// Clear error and result, keeping language and vitals.
  SessionState reset() => SessionState(language: language, vitals: vitals);
}
