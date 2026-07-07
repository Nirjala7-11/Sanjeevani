/// Tests for domain models — serialization, validation, computed properties.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_records/core/models.dart';

void main() {
  group('Patient', () {
    Patient makePatient({
      int? id,
      String name = 'Seema Devi',
      String village = 'Sundarpur',
      int age = 28,
      Gender gender = Gender.female,
      bool isPregnant = false,
    }) =>
        Patient(
          id: id,
          name: name,
          village: village,
          age: age,
          gender: gender,
          isPregnant: isPregnant,
        );

    test('toMap/fromMap round-trip preserves all fields', () {
      final p = makePatient(id: 1, isPregnant: true, pregnancyWeeks: 20);
      final restored = Patient.fromMap(p.toMap()..['id'] = 1);
      expect(restored.name, p.name);
      expect(restored.village, p.village);
      expect(restored.age, p.age);
      expect(restored.isPregnant, true);
      expect(restored.pregnancyWeeks, 20);
    });

    test('copyWith updates fields correctly', () {
      final p = makePatient(id: 1);
      final updated = p.copyWith(age: 30, isPregnant: true);
      expect(updated.age, 30);
      expect(updated.isPregnant, true);
      expect(updated.name, p.name); // unchanged
    });

    test('gender serializes to int index', () {
      final p = makePatient(gender: Gender.female);
      expect(p.toMap()['gender'], Gender.female.index);
    });

    test('isPregnant serializes to 0/1', () {
      expect(makePatient(isPregnant: true).toMap()['is_pregnant'], 1);
      expect(makePatient(isPregnant: false).toMap()['is_pregnant'], 0);
    });

    test('fromMap parses gender correctly', () {
      final p = makePatient(id: 1, gender: Gender.male);
      final restored = Patient.fromMap(p.toMap()..['id'] = 1);
      expect(restored.gender, Gender.male);
    });
  });

  group('Visit', () {
    Visit makeVisit({
      int? id,
      int patientId = 1,
      RiskLevel riskLevel = RiskLevel.high,
      bool referralNeeded = true,
    }) =>
        Visit(
          id: id,
          patientId: patientId,
          visitedAt: DateTime(2026, 7, 1, 10, 30),
          riskLevel: riskLevel,
          referralNeeded: referralNeeded,
        );

    test('toMap/fromMap round-trip', () {
      final v = makeVisit(id: 1);
      final restored = Visit.fromMap(v.toMap()..['id'] = 1);
      expect(restored.patientId, 1);
      expect(restored.riskLevel, RiskLevel.high);
      expect(restored.referralNeeded, true);
    });

    test('referralNeeded serializes as 0/1', () {
      expect(makeVisit(referralNeeded: true).toMap()['referral_needed'], 1);
      expect(makeVisit(referralNeeded: false).toMap()['referral_needed'], 0);
    });

    test('riskLevel serializes as enum index', () {
      expect(makeVisit(riskLevel: RiskLevel.low).toMap()['risk_level'],
          RiskLevel.low.index);
    });

    test('visitedAt is ISO8601 string in map', () {
      final v = makeVisit();
      final ts = v.toMap()['visited_at'] as String;
      expect(DateTime.tryParse(ts), isNotNull);
    });
  });

  group('Reminder', () {
    final past = DateTime.now().subtract(const Duration(days: 5));
    final future = DateTime.now().add(const Duration(days: 5));
    final today = DateTime.now();

    Reminder make(DateTime due, {bool completed = false}) => Reminder(
          patientId: 1,
          type: ReminderType.antenatal,
          dueDate: due,
          isCompleted: completed,
        );

    test('isOverdue true for past incomplete reminder', () {
      expect(make(past).isOverdue, isTrue);
    });

    test('isOverdue false for completed reminder', () {
      expect(make(past, completed: true).isOverdue, isFalse);
    });

    test('isOverdue false for future reminder', () {
      expect(make(future).isOverdue, isFalse);
    });

    test('isDueToday true for today', () {
      expect(make(today).isDueToday, isTrue);
    });

    test('isDueToday false for tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(make(tomorrow).isDueToday, isFalse);
    });

    test('daysOverdue correct for 5-day overdue', () {
      final r = make(DateTime.now().subtract(const Duration(days: 5)));
      expect(r.daysOverdue, 5);
    });

    test('daysOverdue is 0 for future reminders', () {
      expect(make(future).daysOverdue, 0);
    });

    test('toMap/fromMap round-trip', () {
      final r = Reminder(
        id: 1,
        patientId: 2,
        type: ReminderType.immunization,
        dueDate: future,
        notes: 'Test note',
      );
      final restored = Reminder.fromMap(r.toMap()..['id'] = 1);
      expect(restored.type, ReminderType.immunization);
      expect(restored.notes, 'Test note');
      expect(restored.isCompleted, false);
    });

    test('copyWith updates isCompleted', () {
      final r = make(future);
      final now = DateTime.now();
      final completed = r.copyWith(isCompleted: true, completedAt: now);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, now);
      expect(completed.patientId, r.patientId); // unchanged
    });
  });

  group('Assessment', () {
    Assessment make() => Assessment(
          id: 1,
          visitId: 1,
          heartRateBpm: 120.0,
          spo2Pct: 88.0,
          temperatureF: 102.0,
          riskScore: 8,
          condition: 'Respiratory infection',
          advice: 'Refer to PHC',
          transcript: 'child has fever',
          isFallback: false,
          backendUsed: 'llama-cpp',
          latencyMs: 1200.0,
        );

    test('toMap/fromMap round-trip', () {
      final a = make();
      final restored = Assessment.fromMap(a.toMap());
      expect(restored.heartRateBpm, 120.0);
      expect(restored.spo2Pct, 88.0);
      expect(restored.riskScore, 8);
      expect(restored.isFallback, false);
      expect(restored.transcript, 'child has fever');
    });

    test('isFallback serializes as 0/1', () {
      expect(make().toMap()['is_fallback'], 0);
    });

    test('latencyMs round-trips as double', () {
      final restored = Assessment.fromMap(make().toMap());
      expect(restored.latencyMs, closeTo(1200.0, 0.01));
    });
  });

  group('SyncQueueEntry', () {
    test('toMap/fromMap round-trip', () {
      final e = SyncQueueEntry(
        id: 1,
        tableName: 'visits',
        rowId: 42,
        status: SyncStatus.pending,
        retries: 0,
      );
      final restored = SyncQueueEntry.fromMap(e.toMap()..['id'] = 1);
      expect(restored.tableName, 'visits');
      expect(restored.rowId, 42);
      expect(restored.status, SyncStatus.pending);
      expect(restored.retries, 0);
    });
  });

  group('PatientSummary', () {
    test('needsAttention true when overdue > 0', () {
      final s = PatientSummary(
        patient: Patient(
          name: 'X', village: 'Y', age: 30, gender: Gender.female),
        overdueReminderCount: 2,
        dueTodayReminderCount: 0,
      );
      expect(s.needsAttention, isTrue);
    });

    test('needsAttention false when all zero', () {
      final s = PatientSummary(
        patient: Patient(
          name: 'X', village: 'Y', age: 30, gender: Gender.female),
        overdueReminderCount: 0,
        dueTodayReminderCount: 0,
      );
      expect(s.needsAttention, isFalse);
    });
  });
}
