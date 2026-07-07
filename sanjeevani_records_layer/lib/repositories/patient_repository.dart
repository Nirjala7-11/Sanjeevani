/// Patient repository — all CRUD operations for the patients table.
///
/// Design rules:
///   - No raw SQL in business logic — all queries live here.
///   - All methods are async and return typed objects, never raw maps.
///   - Validation runs before any write — invalid data never reaches SQLite.
///   - Soft-delete is not used; patients are hard-deleted with CASCADE
///     so visits, assessments, and reminders are cleaned up automatically.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/exceptions.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/db/database_provider.dart';
import 'package:sqflite/sqflite.dart';

class PatientRepository {
  PatientRepository(this._provider);

  final DatabaseProvider _provider;
  final _log = Logger('sanjeevani.records.patient_repo');

  // ── Validation ────────────────────────────────────────────────────────────

  void _validate(Patient p) {
    if (p.name.trim().isEmpty) {
      throw const ValidationException('Patient name cannot be empty.');
    }
    if (p.name.trim().length > 120) {
      throw const ValidationException('Patient name is too long (max 120 chars).');
    }
    if (p.village.trim().isEmpty) {
      throw const ValidationException('Village name cannot be empty.');
    }
    if (p.age < 0 || p.age > 120) {
      throw const ValidationException(
          'Patient age must be between 0 and 120.');
    }
    if (p.isPregnant &&
        p.pregnancyWeeks != null &&
        (p.pregnancyWeeks! < 1 || p.pregnancyWeeks! > 42)) {
      throw const ValidationException(
          'Pregnancy weeks must be between 1 and 42.');
    }
  }

  // ── Write operations ──────────────────────────────────────────────────────

  /// Insert a new patient. Returns the inserted patient with its new id.
  Future<Patient> insert(Patient patient) async {
    _validate(patient);
    final db = await _provider.db;
    final id = await db.insert(
      'patients',
      patient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    _log.info('Patient inserted: id=$id village=${patient.village}');
    // PRIVACY: do not log patient.name
    return patient.copyWith(id: id);
  }

  /// Update an existing patient record.
  Future<void> update(Patient patient) async {
    if (patient.id == null) {
      throw const ValidationException(
          'Cannot update a patient without an id. '
          'Use insert() for new patients.');
    }
    _validate(patient);
    final db = await _provider.db;
    final affected = await db.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
    if (affected == 0) {
      throw RecordNotFoundException('Patient', patient.id);
    }
    _log.info('Patient updated: id=${patient.id}');
  }

  /// Hard-delete a patient. Cascades to visits, assessments, reminders.
  Future<void> delete(int id) async {
    final db = await _provider.db;
    final affected = await db.delete(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (affected == 0) {
      throw RecordNotFoundException('Patient', id);
    }
    _log.info('Patient deleted: id=$id (cascade applied)');
  }

  // ── Read operations ───────────────────────────────────────────────────────

  /// Fetch a single patient by id.
  Future<Patient> getById(int id) async {
    final db = await _provider.db;
    final rows = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw RecordNotFoundException('Patient', id);
    return Patient.fromMap(rows.first);
  }

  /// Fetch all patients, ordered by name.
  Future<List<Patient>> getAll() async {
    final db = await _provider.db;
    final rows = await db.query('patients', orderBy: 'name ASC');
    return rows.map(Patient.fromMap).toList();
  }

  /// Search patients by name or village (case-insensitive).
  Future<List<Patient>> search(String query) async {
    if (query.trim().isEmpty) return getAll();
    final db = await _provider.db;
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'patients',
      where: 'name LIKE ? OR village LIKE ?',
      whereArgs: [q, q],
      orderBy: 'name ASC',
    );
    return rows.map(Patient.fromMap).toList();
  }

  /// Fetch all pregnant patients.
  Future<List<Patient>> getPregnant() async {
    final db = await _provider.db;
    final rows = await db.query(
      'patients',
      where: 'is_pregnant = 1',
      orderBy: 'pregnancy_weeks DESC',
    );
    return rows.map(Patient.fromMap).toList();
  }

  /// Get full summaries (patient + last visit + reminder counts).
  Future<List<PatientSummary>> getSummaries() async {
    final db = await _provider.db;
    final now = DateTime.now().toIso8601String();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

    // Single query joining patients with aggregated reminder counts
    final rows = await db.rawQuery('''
      SELECT
        p.*,
        (SELECT COUNT(*) FROM reminders r
         WHERE r.patient_id = p.id
           AND r.is_completed = 0
           AND r.due_date < ?
        ) AS overdue_count,
        (SELECT COUNT(*) FROM reminders r
         WHERE r.patient_id = p.id
           AND r.is_completed = 0
           AND date(r.due_date) = ?
        ) AS today_count
      FROM patients p
      ORDER BY p.name ASC
    ''', [now, todayStr]);

    final summaries = <PatientSummary>[];
    for (final row in rows) {
      final patient = Patient.fromMap(row);
      final lastVisitRows = await db.query(
        'visits',
        where: 'patient_id = ?',
        whereArgs: [patient.id],
        orderBy: 'visited_at DESC',
        limit: 1,
      );
      final lastVisit =
          lastVisitRows.isEmpty ? null : Visit.fromMap(lastVisitRows.first);
      summaries.add(PatientSummary(
        patient: patient,
        lastVisit: lastVisit,
        overdueReminderCount: row['overdue_count'] as int,
        dueTodayReminderCount: row['today_count'] as int,
      ));
    }
    return summaries;
  }

  /// Total patient count.
  Future<int> count() async {
    final db = await _provider.db;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM patients');
    return result.first['c'] as int;
  }
}
