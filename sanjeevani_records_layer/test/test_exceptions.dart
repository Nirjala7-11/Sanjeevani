/// Exception hierarchy tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_records/core/exceptions.dart';

void main() {
  group('Exception hierarchy', () {
    test('DatabaseException is RecordsException', () {
      expect(const DatabaseException('x'), isA<RecordsException>());
    });

    test('RecordNotFoundException is RecordsException', () {
      expect(
        const RecordNotFoundException('Patient', 1),
        isA<RecordsException>(),
      );
    });

    test('ValidationException is RecordsException', () {
      expect(const ValidationException('x'), isA<RecordsException>());
    });

    test('SyncException is RecordsException', () {
      expect(const SyncException('x'), isA<RecordsException>());
    });

    test('KnowledgeBaseException is RecordsException', () {
      expect(const KnowledgeBaseException('x'), isA<RecordsException>());
    });

    test('catch all via base type', () {
      final exceptions = [
        const DatabaseException('x'),
        const RecordNotFoundException('Patient', 1),
        const ValidationException('x'),
        const SyncException('x'),
        const KnowledgeBaseException('x'),
      ];
      for (final e in exceptions) {
        try {
          throw e;
        } on RecordsException {
          // expected
        }
      }
    });

    test('cause is included in toString', () {
      final e = DatabaseException('failed', cause: Exception('root cause'));
      expect(e.toString(), contains('root cause'));
    });

    test('RecordNotFoundException message contains entity and id', () {
      const e = RecordNotFoundException('Patient', 42);
      expect(e.message, contains('Patient'));
      expect(e.message, contains('42'));
    });
  });
}
