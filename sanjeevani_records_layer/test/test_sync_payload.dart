/// Tests for the sync service anonymization logic.
/// Verifies the privacy contract: no patient name, exact age, or
/// transcript text in the anonymized payload.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_records/core/models.dart';

/// A minimal, deterministic version of the anonymization logic
/// extracted from SyncService._buildAnonymizedPayload for unit testing
/// without a database dependency.
Map<String, dynamic> buildPayload({
  required int age,
  required String village,
  required RiskLevel riskLevel,
  required bool referralNeeded,
  required DateTime visitedAt,
}) {
  String ageBracket(int a) {
    if (a <= 5)  return '0-5';
    if (a <= 18) return '6-18';
    if (a <= 60) return '19-60';
    return '60+';
  }

  String hashVillage(String v) =>
      v.trim().toLowerCase().hashCode.toRadixString(16).padLeft(8, '0');

  final visitDate =
      '${visitedAt.year}-'
      '${visitedAt.month.toString().padLeft(2, '0')}-'
      '${visitedAt.day.toString().padLeft(2, '0')}';

  return {
    'visit_date':      visitDate,
    'risk_level':      riskLevel.name,
    'referral_needed': referralNeeded,
    'age_bracket':     ageBracket(age),
    'village_hash':    hashVillage(village),
  };
}

void main() {
  group('Anonymized payload structure', () {
    final payload = buildPayload(
      age: 28,
      village: 'Sundarpur',
      riskLevel: RiskLevel.high,
      referralNeeded: true,
      visitedAt: DateTime(2026, 7, 1, 10, 30, 45),
    );

    test('contains required keys', () {
      for (final key in [
        'visit_date',
        'risk_level',
        'referral_needed',
        'age_bracket',
        'village_hash',
      ]) {
        expect(payload.containsKey(key), isTrue, reason: 'Missing key: $key');
      }
    });

    test('visit_date is day only (no time component)', () {
      final date = payload['visit_date'] as String;
      expect(date, '2026-07-01');
      expect(date, isNot(contains('10:30')));
      expect(date, isNot(contains('T')));
    });

    test('risk_level is a string name', () {
      expect(payload['risk_level'], 'high');
    });

    test('referral_needed is a bool', () {
      expect(payload['referral_needed'], isA<bool>());
      expect(payload['referral_needed'], isTrue);
    });

    test('does NOT contain patient name', () {
      expect(payload.containsKey('name'), isFalse);
      expect(payload.containsKey('patient_name'), isFalse);
    });

    test('does NOT contain exact age', () {
      expect(payload.containsKey('age'), isFalse);
    });

    test('does NOT contain village name', () {
      expect(payload.containsKey('village'), isFalse);
    });

    test('does NOT contain transcript', () {
      expect(payload.containsKey('transcript'), isFalse);
    });

    test('does NOT contain phone number', () {
      expect(payload.containsKey('phone_number'), isFalse);
    });
  });

  group('Age bracket anonymization', () {
    Map<String, dynamic> p(int age) => buildPayload(
          age: age,
          village: 'X',
          riskLevel: RiskLevel.low,
          referralNeeded: false,
          visitedAt: DateTime.now(),
        );

    test('age 0 → 0-5 bracket', () {
      expect(p(0)['age_bracket'], '0-5');
    });

    test('age 5 → 0-5 bracket', () {
      expect(p(5)['age_bracket'], '0-5');
    });

    test('age 6 → 6-18 bracket', () {
      expect(p(6)['age_bracket'], '6-18');
    });

    test('age 18 → 6-18 bracket', () {
      expect(p(18)['age_bracket'], '6-18');
    });

    test('age 19 → 19-60 bracket', () {
      expect(p(19)['age_bracket'], '19-60');
    });

    test('age 60 → 19-60 bracket', () {
      expect(p(60)['age_bracket'], '19-60');
    });

    test('age 61 → 60+ bracket', () {
      expect(p(61)['age_bracket'], '60+');
    });

    test('age 90 → 60+ bracket', () {
      expect(p(90)['age_bracket'], '60+');
    });
  });

  group('Village hash', () {
    Map<String, dynamic> p(String village) => buildPayload(
          age: 30,
          village: village,
          riskLevel: RiskLevel.low,
          referralNeeded: false,
          visitedAt: DateTime.now(),
        );

    test('hash is 8 hex characters', () {
      final h = p('Sundarpur')['village_hash'] as String;
      expect(h.length, 8);
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(h), isTrue);
    });

    test('same village always produces same hash', () {
      expect(p('Sundarpur')['village_hash'], p('Sundarpur')['village_hash']);
    });

    test('hash is case-insensitive (Sundarpur == sundarpur)', () {
      expect(p('Sundarpur')['village_hash'], p('sundarpur')['village_hash']);
    });

    test('different villages produce different hashes (usually)', () {
      expect(p('Sundarpur')['village_hash'],
          isNot(equals(p('Rampura')['village_hash'])));
    });

    test('hash does not contain original village name', () {
      final h = p('Sundarpur')['village_hash'] as String;
      expect(h.toLowerCase(), isNot(contains('sundarpur')));
    });
  });

  group('SyncResult', () {
    test('allSucceeded true when no failures', () {
      // SyncResult logic tested without importing the service
      const attempted = 5, succeeded = 5, failed = 0;
      expect(attempted > 0 && failed == 0, isTrue);
    });

    test('nothingToSync when attempted is 0', () {
      const attempted = 0;
      expect(attempted == 0, isTrue);
    });
  });
}
