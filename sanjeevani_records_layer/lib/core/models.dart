/// Typed, immutable domain models for the records layer.
///
/// Design rules:
///   - All models are immutable (final fields).
///   - No Map<String, dynamic> in business logic — typed objects only.
///   - fromMap() / toMap() live on the model, not in repository code.
///   - Every model has a copyWith() for state updates without mutation.
library;

/// Gender options used in patient profiles.
enum Gender { male, female, other }

/// Categories of scheduled care that generate reminders.
enum ReminderType {
  antenatal,       // monthly antenatal visits
  immunization,    // child immunization schedule
  hypertension,    // hypertension follow-up
  tuberculosis,    // TB treatment follow-up
  postnatal,       // postnatal check-ups
  generalFollowUp, // catch-all for other scheduled visits
}

/// Risk level — mirrors the intelligence layer's RiskLevel enum.
enum RiskLevel { low, medium, high }

/// Sync state for the sync queue.
enum SyncStatus { pending, inProgress, synced, failed }

// ── Patient ───────────────────────────────────────────────────────────────────

/// A patient registered under an ASHA worker's care.
class Patient {
  const Patient({
    this.id,
    required this.name,
    required this.village,
    required this.age,
    required this.gender,
    this.phoneNumber,
    this.isPregnant = false,
    this.pregnancyWeeks,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String village;
  final int age;
  final Gender gender;
  final String? phoneNumber;
  final bool isPregnant;
  final int? pregnancyWeeks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Patient copyWith({
    int? id,
    String? name,
    String? village,
    int? age,
    Gender? gender,
    String? phoneNumber,
    bool? isPregnant,
    int? pregnancyWeeks,
  }) =>
      Patient(
        id: id ?? this.id,
        name: name ?? this.name,
        village: village ?? this.village,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        isPregnant: isPregnant ?? this.isPregnant,
        pregnancyWeeks: pregnancyWeeks ?? this.pregnancyWeeks,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'village': village,
        'age': age,
        'gender': gender.index,
        'phone_number': phoneNumber,
        'is_pregnant': isPregnant ? 1 : 0,
        'pregnancy_weeks': pregnancyWeeks,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory Patient.fromMap(Map<String, dynamic> m) => Patient(
        id: m['id'] as int?,
        name: m['name'] as String,
        village: m['village'] as String,
        age: m['age'] as int,
        gender: Gender.values[m['gender'] as int],
        phoneNumber: m['phone_number'] as String?,
        isPregnant: (m['is_pregnant'] as int?) == 1,
        pregnancyWeeks: m['pregnancy_weeks'] as int?,
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : null,
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
      );

  @override
  String toString() => 'Patient(id=$id, name=$name, village=$village)';
}

// ── Visit ─────────────────────────────────────────────────────────────────────

/// A single home visit made by the ASHA worker.
class Visit {
  const Visit({
    this.id,
    required this.patientId,
    required this.visitedAt,
    required this.riskLevel,
    required this.referralNeeded,
    this.notes,
    this.syncStatus = SyncStatus.pending,
    this.createdAt,
  });

  final int? id;
  final int patientId;
  final DateTime visitedAt;
  final RiskLevel riskLevel;
  final bool referralNeeded;
  final String? notes;
  final SyncStatus syncStatus;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'patient_id': patientId,
        'visited_at': visitedAt.toIso8601String(),
        'risk_level': riskLevel.index,
        'referral_needed': referralNeeded ? 1 : 0,
        'notes': notes,
        'sync_status': syncStatus.index,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
        id: m['id'] as int?,
        patientId: m['patient_id'] as int,
        visitedAt: DateTime.parse(m['visited_at'] as String),
        riskLevel: RiskLevel.values[m['risk_level'] as int],
        referralNeeded: (m['referral_needed'] as int) == 1,
        notes: m['notes'] as String?,
        syncStatus: SyncStatus.values[m['sync_status'] as int],
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : null,
      );
}

// ── Assessment ────────────────────────────────────────────────────────────────

/// The full AI assessment result linked to a visit.
/// Stored separately from Visit so visits can be logged without assessment.
class Assessment {
  const Assessment({
    this.id,
    required this.visitId,
    required this.heartRateBpm,
    required this.spo2Pct,
    required this.temperatureF,
    required this.riskScore,
    required this.condition,
    required this.advice,
    required this.transcript,
    required this.isFallback,
    this.backendUsed,
    this.latencyMs,
    this.createdAt,
  });

  final int? id;
  final int visitId;
  final double heartRateBpm;
  final double spo2Pct;
  final double temperatureF;
  final int riskScore;
  final String condition;
  final String advice;
  final String transcript;
  final bool isFallback;
  final String? backendUsed;
  final double? latencyMs;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'visit_id': visitId,
        'heart_rate_bpm': heartRateBpm,
        'spo2_pct': spo2Pct,
        'temperature_f': temperatureF,
        'risk_score': riskScore,
        'condition': condition,
        'advice': advice,
        'transcript': transcript,
        'is_fallback': isFallback ? 1 : 0,
        'backend_used': backendUsed,
        'latency_ms': latencyMs,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory Assessment.fromMap(Map<String, dynamic> m) => Assessment(
        id: m['id'] as int?,
        visitId: m['visit_id'] as int,
        heartRateBpm: (m['heart_rate_bpm'] as num).toDouble(),
        spo2Pct: (m['spo2_pct'] as num).toDouble(),
        temperatureF: (m['temperature_f'] as num).toDouble(),
        riskScore: m['risk_score'] as int,
        condition: m['condition'] as String,
        advice: m['advice'] as String,
        transcript: m['transcript'] as String,
        isFallback: (m['is_fallback'] as int) == 1,
        backendUsed: m['backend_used'] as String?,
        latencyMs: (m['latency_ms'] as num?)?.toDouble(),
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : null,
      );
}

// ── Reminder ──────────────────────────────────────────────────────────────────

/// A scheduled follow-up care reminder for a patient.
class Reminder {
  const Reminder({
    this.id,
    required this.patientId,
    required this.type,
    required this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
    this.createdAt,
  });

  final int? id;
  final int patientId;
  final ReminderType type;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;
  final DateTime? createdAt;

  bool get isOverdue =>
      !isCompleted && dueDate.isBefore(DateTime.now());

  bool get isDueToday {
    final now = DateTime.now();
    return !isCompleted &&
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(dueDate).inDays;
  }

  Reminder copyWith({
    bool? isCompleted,
    DateTime? completedAt,
    String? notes,
  }) =>
      Reminder(
        id: id,
        patientId: patientId,
        type: type,
        dueDate: dueDate,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: completedAt ?? this.completedAt,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'patient_id': patientId,
        'type': type.index,
        'due_date': dueDate.toIso8601String(),
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'notes': notes,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
        id: m['id'] as int?,
        patientId: m['patient_id'] as int,
        type: ReminderType.values[m['type'] as int],
        dueDate: DateTime.parse(m['due_date'] as String),
        isCompleted: (m['is_completed'] as int) == 1,
        completedAt: m['completed_at'] != null
            ? DateTime.parse(m['completed_at'] as String)
            : null,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : null,
      );
}

// ── Sync queue entry ──────────────────────────────────────────────────────────

/// A record queued for sync to the backend when connectivity resumes.
/// Only anonymized data (no patient names) is ever placed here.
class SyncQueueEntry {
  const SyncQueueEntry({
    this.id,
    required this.tableName,
    required this.rowId,
    this.status = SyncStatus.pending,
    this.retries = 0,
    this.createdAt,
    this.lastAttemptAt,
  });

  final int? id;
  final String tableName;
  final int rowId;
  final SyncStatus status;
  final int retries;
  final DateTime? createdAt;
  final DateTime? lastAttemptAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'table_name': tableName,
        'row_id': rowId,
        'status': status.index,
        'retries': retries,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
      };

  factory SyncQueueEntry.fromMap(Map<String, dynamic> m) => SyncQueueEntry(
        id: m['id'] as int?,
        tableName: m['table_name'] as String,
        rowId: m['row_id'] as int,
        status: SyncStatus.values[m['status'] as int],
        retries: m['retries'] as int,
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'] as String)
            : null,
        lastAttemptAt: m['last_attempt_at'] != null
            ? DateTime.parse(m['last_attempt_at'] as String)
            : null,
      );
}

// ── Composite views ───────────────────────────────────────────────────────────

/// A patient with their most recent visit and overdue reminders.
/// Used by the home dashboard and patient list screen.
class PatientSummary {
  const PatientSummary({
    required this.patient,
    this.lastVisit,
    required this.overdueReminderCount,
    required this.dueTodayReminderCount,
  });

  final Patient patient;
  final Visit? lastVisit;
  final int overdueReminderCount;
  final int dueTodayReminderCount;

  bool get needsAttention =>
      overdueReminderCount > 0 || dueTodayReminderCount > 0;
}

/// A visit with its full assessment attached.
/// Used by the visit history and result detail screens.
class VisitWithAssessment {
  const VisitWithAssessment({
    required this.visit,
    this.assessment,
    required this.patient,
  });

  final Visit visit;
  final Assessment? assessment;
  final Patient patient;
}
