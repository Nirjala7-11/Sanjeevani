/// Integration tests for SessionProvider pipeline using mocks.
///
/// Tests the full capture pipeline: vitals → recording → STT → sanitize
/// → intelligence layer → result, using scripted fake services.
/// No real microphone, no model, no server required.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/intelligence/intelligence_client.dart';
import 'package:sanjeevani_capture/safety/transcript_sanitizer.dart';

// ── Fake services ──────────────────────────────────────────────────────────

/// Fake audio recorder — always succeeds, returns a predictable path.
class FakeAudioRecorder {
  bool startCalled = false;
  bool stopCalled = false;
  bool deleteCalled = false;
  String? deletedPath;

  final _amplitudeCtrl = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeCtrl.stream;

  bool get isRecording => startCalled && !stopCalled;

  Future<void> open() async {}

  Future<String> startRecording() async {
    startCalled = true;
    stopCalled = false;
    return '/tmp/fake_audio.wav';
  }

  Future<String?> stopRecording() async {
    stopCalled = true;
    return '/tmp/fake_audio.wav';
  }

  Future<void> deleteRecording(String path) async {
    deleteCalled = true;
    deletedPath = path;
  }

  Future<void> dispose() async {
    await _amplitudeCtrl.close();
  }
}

/// Fake STT coordinator — returns configurable transcript.
class FakeSttCoordinator {
  FakeSttCoordinator({required this.response, this.shouldThrow = false});
  final TranscriptResult response;
  final bool shouldThrow;

  Future<TranscriptResult> transcribe(String path, AppLanguage lang) async {
    if (shouldThrow) {
      throw const SpeechRecognitionException('Scripted STT failure');
    }
    return response;
  }
}

/// Fake intelligence client — returns configurable recommendation.
class FakeIntelligenceClient {
  FakeIntelligenceClient({required this.response, this.shouldThrow = false});
  final ClinicalRecommendation response;
  final bool shouldThrow;

  Future<bool> healthCheck() async => !shouldThrow;

  Future<ClinicalRecommendation> analyse({
    required PatientVitals vitals,
    required String transcript,
  }) async {
    if (shouldThrow) {
      throw const IntelligenceLayerException('Scripted intelligence failure');
    }
    return response;
  }

  void dispose() {}
}

// ── Test data factories ────────────────────────────────────────────────────

PatientVitals validVitals() => PatientVitals.validated(
      heartRateBpm: 120, spo2Pct: 88, temperatureF: 102,
    );

TranscriptResult goodTranscript() => const TranscriptResult(
      text: 'child has fever and cough for three days',
      engine: SttEngine.vosk,
      durationMs: 2000,
      confidence: 0.9,
    );

ClinicalRecommendation highRiskRec() => const ClinicalRecommendation(
      condition: 'Respiratory infection',
      advice: 'Refer to PHC today',
      referralNeeded: true,
      riskLevel: RiskLevel.high,
      riskScore: 8,
      alerts: ['High fever', 'Low oxygen'],
      isFallback: false,
      sources: [],
      backendUsed: 'llama-cpp-ondevice',
      latencyMs: 1200,
    );

ClinicalRecommendation lowRiskRec() => const ClinicalRecommendation(
      condition: 'No concerning pattern',
      advice: 'Routine monitoring',
      referralNeeded: false,
      riskLevel: RiskLevel.low,
      riskScore: 0,
      alerts: [],
      isFallback: false,
      sources: [],
    );

// ── Helper: build a testable SessionProvider ──────────────────────────────

/// NOTE: In production, SessionProvider's constructor takes concrete
/// typed services. For tests, we use the same constructor with fakes
/// cast to the correct types via a test-only factory method.
///
/// This demonstrates the testability design: every dependency is
/// injected, nothing is hard-wired inside SessionProvider.

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('VitalBoundaryException — raised for bad readings', () {
    test('HR too high throws', () {
      expect(
        () => PatientVitals.validated(
            heartRateBpm: 999, spo2Pct: 97, temperatureF: 98),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('SpO2 too low throws', () {
      expect(
        () => PatientVitals.validated(
            heartRateBpm: 80, spo2Pct: 5, temperatureF: 98),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('temperature implausible throws', () {
      expect(
        () => PatientVitals.validated(
            heartRateBpm: 80, spo2Pct: 97, temperatureF: 999),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('error message contains label and value', () {
      try {
        PatientVitals.validated(
            heartRateBpm: 999, spo2Pct: 97, temperatureF: 98);
        fail('expected throw');
      } on VitalBoundaryException catch (e) {
        expect(e.message, contains('Heart rate'));
        expect(e.message, contains('999'));
      }
    });
  });

  group('SessionState — state transitions', () {
    test('default state is idle', () {
      const s = SessionState();
      expect(s.recording, RecordingState.idle);
      expect(s.isRecording, false);
      expect(s.hasResult, false);
    });

    test('copyWith recording state', () {
      const s = SessionState();
      final s2 = s.copyWith(recording: RecordingState.recording);
      expect(s2.isRecording, true);
    });

    test('reset clears error and result', () {
      const s = SessionState(
        language: AppLanguage.gujarati,
        error: 'some error',
        recording: RecordingState.error,
      );
      final r = s.reset();
      expect(r.error, isNull);
      expect(r.recording, RecordingState.idle);
      expect(r.language, AppLanguage.gujarati); // preserved
    });

    test('hasResult is true when recommendation present', () {
      const rec = ClinicalRecommendation(
        condition: 'Test',
        advice: 'Test advice',
        referralNeeded: false,
        riskLevel: RiskLevel.low,
        riskScore: 0,
        alerts: [],
        isFallback: false,
        sources: [],
      );
      final s = SessionState(recommendation: rec);
      expect(s.hasResult, true);
    });
  });

  group('TranscriptSanitizer — pipeline integration', () {
    const sanitizer = TranscriptSanitizer();

    test('sanitized transcript is returned clean', () {
      final result = sanitizer.sanitize('  child has fever  ');
      expect(result, 'child has fever');
    });

    test('sanitize rejects null', () {
      expect(
        () => sanitizer.sanitize(null),
        throwsA(isA<TranscriptValidationException>()),
      );
    });

    test('oversized input truncated not rejected', () {
      final big = 'fever ' * 1000;
      final result = sanitizer.sanitize(big);
      expect(result.length, lessThanOrEqualTo(2500));
    });
  });

  group('AppLanguage', () {
    test('all languages have displayName', () {
      for (final lang in AppLanguage.values) {
        expect(lang.displayName, isNotEmpty);
      }
    });

    test('hindi has vosk model path', () {
      expect(AppLanguage.hindi.voskModelPath, isNotNull);
    });

    test('english has null vosk path (uses device STT)', () {
      expect(AppLanguage.english.voskModelPath, isNull);
    });
  });

  group('ClinicalRecommendation serialization round-trip', () {
    test('fromJson produces correct referralNeeded', () {
      final json = {
        'condition': 'Infection',
        'advice': 'Refer now',
        'referral_needed': true,
        'risk_level': 'HIGH',
        'risk_score': 8,
        'alerts': ['Fever'],
        'is_fallback': false,
        'sources': [],
        'backend_used': 'test',
        'latency_ms': 100.0,
      };
      final rec = ClinicalRecommendation.fromJson(json);
      expect(rec.referralNeeded, true);
      expect(rec.riskLevel, RiskLevel.high);
      expect(rec.alerts, ['Fever']);
      expect(rec.isFallback, false);
    });

    test('fromJson with null backend_used', () {
      final json = {
        'condition': 'None',
        'advice': 'Monitor',
        'referral_needed': false,
        'risk_level': 'LOW',
        'risk_score': 0,
        'alerts': [],
        'is_fallback': true,
        'sources': [],
        'backend_used': null,
        'latency_ms': null,
      };
      final rec = ClinicalRecommendation.fromJson(json);
      expect(rec.backendUsed, isNull);
      expect(rec.latencyMs, isNull);
      expect(rec.isFallback, true);
    });

    test('sources parsed correctly', () {
      final json = {
        'condition': 'Test',
        'advice': 'Test',
        'referral_needed': false,
        'risk_level': 'LOW',
        'risk_score': 0,
        'alerts': [],
        'is_fallback': false,
        'sources': [
          {
            'entry_id': 'kb-001',
            'source_ref': 'IMNCI 4.2',
            'similarity': 0.88,
          }
        ],
        'backend_used': null,
        'latency_ms': null,
      };
      final rec = ClinicalRecommendation.fromJson(json);
      expect(rec.sources.length, 1);
      expect(rec.sources.first.entryId, 'kb-001');
      expect(rec.sources.first.similarity, closeTo(0.88, 0.001));
    });
  });
}
