/// Tests for data models — validation, immutability, serialization.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/models.dart';

void main() {
  group('PatientVitals', () {
    test('accepts valid readings', () {
      final v = PatientVitals.validated(
        heartRateBpm: 80, spo2Pct: 97, temperatureF: 98.6,
      );
      expect(v.heartRateBpm, 80);
      expect(v.spo2Pct, 97);
      expect(v.temperatureF, 98.6);
    });

    test('rejects heart rate below minimum', () {
      expect(
        () => PatientVitals.validated(
          heartRateBpm: 5, spo2Pct: 97, temperatureF: 98.6),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('rejects heart rate above maximum', () {
      expect(
        () => PatientVitals.validated(
          heartRateBpm: 999, spo2Pct: 97, temperatureF: 98.6),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('rejects SpO2 above 100', () {
      expect(
        () => PatientVitals.validated(
          heartRateBpm: 80, spo2Pct: 105, temperatureF: 98.6),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('rejects SpO2 below minimum', () {
      expect(
        () => PatientVitals.validated(
          heartRateBpm: 80, spo2Pct: 10, temperatureF: 98.6),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('rejects implausible temperature', () {
      expect(
        () => PatientVitals.validated(
          heartRateBpm: 80, spo2Pct: 97, temperatureF: 200),
        throwsA(isA<VitalBoundaryException>()),
      );
    });

    test('error message contains the bad value', () {
      try {
        PatientVitals.validated(
          heartRateBpm: 999, spo2Pct: 97, temperatureF: 98.6);
        fail('should have thrown');
      } on VitalBoundaryException catch (e) {
        expect(e.message, contains('999'));
        expect(e.message, contains('Heart rate'));
      }
    });

    test('toJson contains all three fields', () {
      final v = PatientVitals.validated(
        heartRateBpm: 80, spo2Pct: 97, temperatureF: 98.6);
      final j = v.toJson();
      expect(j['heart_rate_bpm'], 80);
      expect(j['spo2_pct'], 97);
      expect(j['temperature_f'], 98.6);
    });

    test('accepts boundary values', () {
      // Exact min values must pass
      expect(
        () => PatientVitals.validated(
          heartRateBpm: 20, spo2Pct: 40, temperatureF: 86),
        returnsNormally,
      );
    });
  });

  group('RiskLevel', () {
    test('fromString parses HIGH correctly', () {
      expect(RiskLevel.fromString('HIGH'), RiskLevel.high);
    });

    test('fromString is case-insensitive', () {
      expect(RiskLevel.fromString('high'), RiskLevel.high);
      expect(RiskLevel.fromString('Low'), RiskLevel.low);
    });

    test('fromString throws on unknown value', () {
      expect(
        () => RiskLevel.fromString('CRITICAL'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ClinicalRecommendation.fromJson', () {
    final sampleJson = {
      'condition': 'Respiratory infection',
      'advice': 'Refer to PHC today',
      'referral_needed': true,
      'risk_level': 'HIGH',
      'risk_score': 8,
      'alerts': ['High fever', 'Low oxygen'],
      'is_fallback': false,
      'sources': [
        {
          'entry_id': 'kb-001',
          'source_ref': 'IMNCI 4.2',
          'similarity': 0.92,
        }
      ],
      'backend_used': 'llama-cpp-ondevice',
      'latency_ms': 1420.0,
    };

    test('parses correctly', () {
      final rec = ClinicalRecommendation.fromJson(sampleJson);
      expect(rec.condition, 'Respiratory infection');
      expect(rec.referralNeeded, true);
      expect(rec.riskLevel, RiskLevel.high);
      expect(rec.riskScore, 8);
      expect(rec.alerts, ['High fever', 'Low oxygen']);
      expect(rec.isFallback, false);
      expect(rec.sources.length, 1);
      expect(rec.sources.first.sourceRef, 'IMNCI 4.2');
      expect(rec.latencyMs, 1420.0);
    });

    test('handles null backend_used', () {
      final j = Map<String, dynamic>.from(sampleJson)
        ..['backend_used'] = null;
      final rec = ClinicalRecommendation.fromJson(j);
      expect(rec.backendUsed, isNull);
    });
  });

  group('SessionState', () {
    test('default state is idle', () {
      const s = SessionState();
      expect(s.recording, RecordingState.idle);
      expect(s.hasResult, false);
      expect(s.isRecording, false);
    });

    test('copyWith preserves unchanged fields', () {
      const s = SessionState(language: AppLanguage.gujarati);
      final s2 = s.copyWith(amplitudeDb: 0.5);
      expect(s2.language, AppLanguage.gujarati);
      expect(s2.amplitudeDb, 0.5);
    });

    test('reset clears result and error but keeps language', () {
      const s = SessionState(
        language: AppLanguage.gujarati,
        error: 'some error',
      );
      final r = s.reset();
      expect(r.language, AppLanguage.gujarati);
      expect(r.error, isNull);
      expect(r.recording, RecordingState.idle);
    });
  });
}
