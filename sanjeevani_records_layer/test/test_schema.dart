/// Schema integrity tests — verify SQL structure without a real DB.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_records/db/schema.dart';

void main() {
  group('Schema definitions', () {
    test('kSchemaVersion is positive', () {
      expect(kSchemaVersion, greaterThan(0));
    });

    test('kCreateTablesV1 is non-empty', () {
      expect(kCreateTablesV1, isNotEmpty);
    });

    test('contains patients table', () {
      expect(
        kCreateTablesV1.any((s) => s.contains('patients')),
        isTrue,
      );
    });

    test('contains visits table', () {
      expect(
        kCreateTablesV1.any((s) => s.contains('visits')),
        isTrue,
      );
    });

    test('contains assessments table', () {
      expect(
        kCreateTablesV1.any((s) => s.contains('assessments')),
        isTrue,
      );
    });

    test('contains reminders table', () {
      expect(
        kCreateTablesV1.any((s) => s.contains('reminders')),
        isTrue,
      );
    });

    test('contains sync_queue table', () {
      expect(
        kCreateTablesV1.any((s) => s.contains('sync_queue')),
        isTrue,
      );
    });

    test('all five tables present (5 CREATE TABLE + indexes)', () {
      final creates = kCreateTablesV1
          .where((s) => s.trimLeft().toUpperCase().startsWith('CREATE TABLE'))
          .length;
      expect(creates, 5);
    });

    test('kMigrations has entry for version 1', () {
      expect(kMigrations.containsKey(1), isTrue);
    });

    test('kMigrations[1] matches kCreateTablesV1', () {
      expect(kMigrations[1], equals(kCreateTablesV1));
    });

    test('patients table has AUTOINCREMENT primary key', () {
      final pTable = kCreateTablesV1
          .firstWhere((s) => s.contains('CREATE TABLE IF NOT EXISTS patients'));
      expect(pTable.toLowerCase(), contains('autoincrement'));
    });

    test('visits references patients with CASCADE', () {
      final vTable = kCreateTablesV1
          .firstWhere((s) => s.contains('CREATE TABLE IF NOT EXISTS visits'));
      expect(vTable, contains('ON DELETE CASCADE'));
    });

    test('assessments has UNIQUE visit_id (one assessment per visit)', () {
      final aTable = kCreateTablesV1.firstWhere(
        (s) => s.contains('CREATE TABLE IF NOT EXISTS assessments'));
      expect(aTable, contains('UNIQUE'));
    });

    test('indexes are defined for patient_id, visited_at, due_date', () {
      final indexSqls = kCreateTablesV1
          .where((s) => s.trimLeft().toUpperCase().startsWith('CREATE INDEX'))
          .join('\n');
      expect(indexSqls, contains('patient_id'));
      expect(indexSqls, contains('visited_at'));
      expect(indexSqls, contains('due_date'));
    });

    test('all SQL statements are non-empty strings', () {
      for (final sql in kCreateTablesV1) {
        expect(sql.trim(), isNotEmpty,
            reason: 'Found an empty SQL statement in kCreateTablesV1');
      }
    });
  });
}
