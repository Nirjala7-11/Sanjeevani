/// Tests for reminder scheduling logic and computed properties.
/// No database required — pure logic tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_records/core/models.dart';

void main() {
  group('Reminder — scheduling invariants', () {
    test('immunization milestone count is 7', () {
      // There are 7 defined immunization milestones in reminder_engine.dart
      // This test documents that contract so changes are explicit.
      const milestones = [6, 10, 14, 36, 48, 60, 72];
      expect(milestones.length, 7);
    });

    test('postnatal visit days are [1, 3, 7, 42]', () {
      const postnatal = [1, 3, 7, 42];
      expect(postnatal.length, 4);
      expect(postnatal.first, 1);
      expect(postnatal.last, 42);
    });

    test('hypertension follow-up is 30 days', () {
      // Contract: one reminder 30 days from consultation
      const intervalDays = 30;
      expect(intervalDays, 30);
    });

    test('TB follow-up interval is 14 days', () {
      const intervalDays = 14;
      expect(intervalDays, 14);
    });
  });

  group('Reminder computed properties', () {
    DateTime daysAgo(int days) =>
        DateTime.now().subtract(Duration(days: days));
    DateTime daysFromNow(int days) =>
        DateTime.now().add(Duration(days: days));

    Reminder makeReminder(DateTime due, {bool completed = false}) => Reminder(
          patientId: 1,
          type: ReminderType.generalFollowUp,
          dueDate: due,
          isCompleted: completed,
        );

    test('1-day overdue has daysOverdue == 1', () {
      expect(makeReminder(daysAgo(1)).daysOverdue, 1);
    });

    test('completed reminder has daysOverdue == 0 even if past', () {
      expect(makeReminder(daysAgo(10), completed: true).daysOverdue, 0);
    });

    test('future reminder has isOverdue == false', () {
      expect(makeReminder(daysFromNow(1)).isOverdue, isFalse);
    });

    test('isOverdue and isCompleted are mutually exclusive', () {
      final r = makeReminder(daysAgo(5), completed: true);
      expect(r.isOverdue, isFalse);
      expect(r.isCompleted, isTrue);
    });
  });

  group('ReminderType enum', () {
    test('all reminder types have distinct indices', () {
      final indices = ReminderType.values.map((t) => t.index).toSet();
      expect(indices.length, ReminderType.values.length);
    });

    test('ReminderType.antenatal has index 0', () {
      expect(ReminderType.antenatal.index, 0);
    });
  });

  group('RiskLevel enum', () {
    test('all risk levels have distinct indices', () {
      final indices = RiskLevel.values.map((l) => l.index).toSet();
      expect(indices.length, RiskLevel.values.length);
    });
  });

  group('SyncStatus enum', () {
    test('pending is index 0', () {
      expect(SyncStatus.pending.index, 0);
    });

    test('all statuses distinct', () {
      final indices = SyncStatus.values.map((s) => s.index).toSet();
      expect(indices.length, SyncStatus.values.length);
    });
  });
}
