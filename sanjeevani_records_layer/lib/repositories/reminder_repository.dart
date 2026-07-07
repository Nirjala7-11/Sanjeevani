/// Reminder repository — scheduled care follow-ups.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/exceptions.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/db/database_provider.dart';

class ReminderRepository {
  ReminderRepository(this._provider);

  final DatabaseProvider _provider;
  final _log = Logger('sanjeevani.records.reminder_repo');

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<Reminder> insert(Reminder reminder) async {
    if (reminder.dueDate.isBefore(DateTime.now().subtract(
      const Duration(days: 365),
    ))) {
      throw const ValidationException(
        'Due date cannot be more than one year in the past.',
      );
    }
    final db = await _provider.db;
    final id = await db.insert('reminders', reminder.toMap());
    _log.info(
      'Reminder inserted: id=$id type=${reminder.type.name} '
      'patient_id=${reminder.patientId}',
    );
    return Reminder.fromMap({...reminder.toMap(), 'id': id});
  }

  Future<void> markComplete(int id) async {
    final db = await _provider.db;
    final now = DateTime.now().toIso8601String();
    final affected = await db.update(
      'reminders',
      {'is_completed': 1, 'completed_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (affected == 0) throw RecordNotFoundException('Reminder', id);
    _log.info('Reminder completed: id=$id');
  }

  Future<void> delete(int id) async {
    final db = await _provider.db;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Reminder>> getForPatient(int patientId) async {
    final db = await _provider.db;
    final rows = await db.query(
      'reminders',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'due_date ASC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  /// All pending (not completed) reminders due today or overdue.
  Future<List<Reminder>> getDueAndOverdue() async {
    final db = await _provider.db;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'reminders',
      where: 'is_completed = 0 AND due_date <= ?',
      whereArgs: [now],
      orderBy: 'due_date ASC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  /// Reminders due within the next [days] days (for advance notice).
  Future<List<Reminder>> getUpcoming({int days = 3}) async {
    final db = await _provider.db;
    final from = DateTime.now().toIso8601String();
    final to = DateTime.now()
        .add(Duration(days: days))
        .toIso8601String();
    final rows = await db.query(
      'reminders',
      where: 'is_completed = 0 AND due_date > ? AND due_date <= ?',
      whereArgs: [from, to],
      orderBy: 'due_date ASC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  /// Count of pending reminders by category (for the dashboard).
  Future<Map<String, int>> countPendingByType() async {
    final db = await _provider.db;
    final rows = await db.rawQuery(
      '''SELECT type, COUNT(*) AS c
         FROM reminders
         WHERE is_completed = 0
         GROUP BY type''',
    );
    return {
      for (final r in rows)
        ReminderType.values[r['type'] as int].name: r['c'] as int,
    };
  }
}
