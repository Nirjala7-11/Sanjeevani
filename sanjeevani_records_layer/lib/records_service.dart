/// RecordsService — the single public API of this package.
///
/// Every caller (the Flutter UI, tests) imports only this class.
/// Nothing else in the package needs to be imported directly.
///
/// Responsibilities:
///   - Construct all repositories with the shared DatabaseProvider.
///   - Expose typed, higher-level operations to the UI.
///   - Ensure the database is ready before any operation runs.
///
/// Usage:
///   final svc = RecordsService.instance;
///   await svc.init();
///   final patients = await svc.patients.getSummaries();
library;

import 'package:sanjeevani_records/core/exceptions.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/db/database_provider.dart';
import 'package:sanjeevani_records/knowledge/knowledge_store.dart';
import 'package:sanjeevani_records/reminder/reminder_engine.dart';
import 'package:sanjeevani_records/repositories/patient_repository.dart';
import 'package:sanjeevani_records/repositories/reminder_repository.dart';
import 'package:sanjeevani_records/repositories/sync_queue_repository.dart';
import 'package:sanjeevani_records/repositories/visit_repository.dart';
import 'package:sanjeevani_records/utils/logger.dart';

class RecordsService {
  RecordsService._();

  static final RecordsService instance = RecordsService._();

  bool _ready = false;

  late final PatientRepository patients;
  late final VisitRepository visits;
  late final ReminderRepository reminders;
  late final SyncQueueRepository syncQueue;
  late final ReminderEngine reminderEngine;

  /// Must be called once at app startup before any operation.
  Future<void> init() async {
    if (_ready) return;

    setupRecordsLogging();

    final db = DatabaseProvider.instance;

    patients       = PatientRepository(db);
    reminders      = ReminderRepository(db);
    visits         = VisitRepository(db);
    syncQueue      = SyncQueueRepository(db);
    reminderEngine = ReminderEngine(reminders);

    // Trigger database open (and migration if needed).
    await db.db;

    // Load and validate the knowledge base.
    await KnowledgeStore.instance.load();

    _ready = true;
  }

  // ── High-level operations used directly by the UI ─────────────────────────

  /// Save a complete consultation (visit + assessment) and schedule
  /// a follow-up reminder if the risk level warrants it.
  Future<VisitWithAssessment> saveConsultation({
    required Patient patient,
    required Visit visit,
    required Assessment assessment,
  }) async {
    _assertReady();

    final result = await visits.saveVisitWithAssessment(
      visit: visit,
      assessment: assessment,
      patient: patient,
    );

    // Auto-schedule a follow-up for high and medium risk.
    if (visit.riskLevel == RiskLevel.high ||
        visit.riskLevel == RiskLevel.medium) {
      final dueDate = DateTime.now().add(
        visit.riskLevel == RiskLevel.high
            ? const Duration(days: 3)
            : const Duration(days: 7),
      );
      await reminderEngine.scheduleFollowUp(
        patient,
        dueDate,
        notes: 'Follow-up after ${visit.riskLevel.name} risk consultation',
      );
    }

    return result;
  }

  /// Register a new patient and schedule appropriate reminders.
  Future<Patient> registerPatient(Patient patient) async {
    _assertReady();
    final saved = await patients.insert(patient);

    if (saved.isPregnant) {
      await reminderEngine.scheduleAntenatal(saved);
    }

    return saved;
  }

  /// Get today's worklist: all overdue and due-today reminders
  /// with the associated patient record.
  Future<List<_ReminderWithPatient>> getTodaysWorklist() async {
    _assertReady();
    final dueReminders = await reminderEngine.getDueToday();
    final result = <_ReminderWithPatient>[];

    for (final reminder in dueReminders) {
      try {
        final patient = await patients.getById(reminder.patientId);
        result.add(_ReminderWithPatient(reminder: reminder, patient: patient));
      } on RecordNotFoundException {
        // Patient was deleted — skip this reminder.
      }
    }

    // Sort: overdue first (most days overdue at top), then due today.
    result.sort((a, b) =>
        b.reminder.daysOverdue.compareTo(a.reminder.daysOverdue));
    return result;
  }

  void _assertReady() {
    if (!_ready) {
      throw const DatabaseException(
        'RecordsService.init() must be called before any operation. '
        'Call it once at app startup in main().',
      );
    }
  }
}

/// Reminder bundled with its patient — used for the today worklist.
class _ReminderWithPatient {
  const _ReminderWithPatient({
    required this.reminder,
    required this.patient,
  });
  final Reminder reminder;
  final Patient patient;
}
