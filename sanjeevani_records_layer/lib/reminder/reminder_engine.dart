/// Reminder engine — generates and manages scheduled care reminders.
///
/// All computation is on-device. No server call is ever needed to determine
/// what reminders to show. The engine reads from SQLite and writes back to
/// the reminders table. The UI only needs to call [getDueToday()].
///
/// Scheduling rules encoded here:
///   - Antenatal: every 4 weeks (monthly)
///   - Immunization: at fixed ages (6w, 10w, 14w, 9m, 12m, 15m, 18m)
///   - Hypertension: every 30 days
///   - TB follow-up: every 14 days during treatment
///   - Postnatal: day 1, day 3, day 7, day 42
///   - General: specified due date, no recurrence
///
/// Clinical review note: these schedules are illustrative defaults
/// matching standard IMNCI / NHM India schedules. Person C should
/// verify against current NHM guidelines and adjust constants if needed.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/repositories/reminder_repository.dart';

/// Fixed immunization milestones in weeks of age.
const _immunizationWeeks = [6, 10, 14, 36, 48, 60, 72];

class ReminderEngine {
  ReminderEngine(this._repo);

  final ReminderRepository _repo;
  final _log = Logger('sanjeevani.records.reminder_engine');

  // ── Query ──────────────────────────────────────────────────────────────────

  /// All reminders due today or overdue, ordered by urgency.
  Future<List<Reminder>> getDueToday() => _repo.getDueAndOverdue();

  /// Reminders coming up in the next [days] days (advance planning).
  Future<List<Reminder>> getUpcoming({int days = 3}) =>
      _repo.getUpcoming(days: days);

  /// All reminders for a specific patient.
  Future<List<Reminder>> getForPatient(int patientId) =>
      _repo.getForPatient(patientId);

  /// Mark a reminder as completed.
  Future<void> complete(int reminderId) =>
      _repo.markComplete(reminderId);

  // ── Schedule generators ───────────────────────────────────────────────────

  /// Generate antenatal visit reminders for a pregnant patient.
  ///
  /// Creates one reminder per remaining monthly visit until 40 weeks.
  Future<void> scheduleAntenatal(Patient patient) async {
    if (!patient.isPregnant) return;
    final currentWeek = patient.pregnancyWeeks ?? 0;
    final remainingMonths = ((40 - currentWeek) / 4).ceil().clamp(0, 10);

    final reminders = <Reminder>[];
    for (int i = 1; i <= remainingMonths; i++) {
      reminders.add(Reminder(
        patientId: patient.id!,
        type: ReminderType.antenatal,
        dueDate: DateTime.now().add(Duration(days: i * 28)),
      ));
    }

    for (final r in reminders) {
      await _repo.insert(r);
    }
    _log.info(
      'Scheduled ${reminders.length} antenatal reminders '
      'for patient_id=${patient.id}',
    );
  }

  /// Generate immunization reminders for a child patient.
  ///
  /// [dateOfBirth] must be provided for accurate scheduling.
  Future<void> scheduleImmunizations(
    Patient patient,
    DateTime dateOfBirth,
  ) async {
    final now = DateTime.now();
    int count = 0;

    for (final ageWeeks in _immunizationWeeks) {
      final dueDate = dateOfBirth.add(Duration(days: ageWeeks * 7));
      // Only create future reminders — skip already-passed milestones
      if (dueDate.isBefore(now)) continue;

      await _repo.insert(Reminder(
        patientId: patient.id!,
        type: ReminderType.immunization,
        dueDate: dueDate,
        notes: 'Age ${ageWeeks} weeks immunization',
      ));
      count++;
    }

    _log.info(
      'Scheduled $count immunization reminders for patient_id=${patient.id}',
    );
  }

  /// Schedule a hypertension follow-up 30 days from now.
  Future<void> scheduleHypertensionFollowUp(Patient patient) async {
    await _repo.insert(Reminder(
      patientId: patient.id!,
      type: ReminderType.hypertension,
      dueDate: DateTime.now().add(const Duration(days: 30)),
    ));
    _log.info(
      'Scheduled hypertension follow-up for patient_id=${patient.id}',
    );
  }

  /// Schedule TB follow-ups every 14 days for [durationDays] total.
  Future<void> scheduleTbFollowUp(
    Patient patient, {
    int durationDays = 180,
  }) async {
    int count = 0;
    for (int days = 14; days <= durationDays; days += 14) {
      await _repo.insert(Reminder(
        patientId: patient.id!,
        type: ReminderType.tuberculosis,
        dueDate: DateTime.now().add(Duration(days: days)),
      ));
      count++;
    }
    _log.info(
      'Scheduled $count TB follow-ups for patient_id=${patient.id}',
    );
  }

  /// Schedule postnatal visits on days 1, 3, 7, and 42.
  Future<void> schedulePostnatal(Patient patient) async {
    const postnatalDays = [1, 3, 7, 42];
    final base = DateTime.now();
    for (final day in postnatalDays) {
      await _repo.insert(Reminder(
        patientId: patient.id!,
        type: ReminderType.postnatal,
        dueDate: base.add(Duration(days: day)),
        notes: 'Day $day postnatal visit',
      ));
    }
    _log.info('Scheduled postnatal reminders for patient_id=${patient.id}');
  }

  /// Schedule a single general follow-up at a specific date.
  Future<void> scheduleFollowUp(
    Patient patient,
    DateTime dueDate, {
    String? notes,
  }) async {
    await _repo.insert(Reminder(
      patientId: patient.id!,
      type: ReminderType.generalFollowUp,
      dueDate: dueDate,
      notes: notes,
    ));
  }
}
