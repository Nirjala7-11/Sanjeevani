/// Visit and Assessment repository.
///
/// Visits and assessments are always written together in a single
/// transaction — there is no half-saved consultation.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/exceptions.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/db/database_provider.dart';
import 'package:sqflite/sqflite.dart';

class VisitRepository {
  VisitRepository(this._provider);

  final DatabaseProvider _provider;
  final _log = Logger('sanjeevani.records.visit_repo');

  /// Save a visit and its assessment in a single atomic transaction.
  ///
  /// Either both are written or neither is — there is no partial save.
  /// The saved visit and assessment (with their new ids) are returned.
  Future<VisitWithAssessment> saveVisitWithAssessment({
    required Visit visit,
    required Assessment assessment,
    required Patient patient,
  }) async {
    final db = await _provider.db;

    late int visitId;
    late int assessmentId;

    await db.transaction((txn) async {
      visitId = await txn.insert(
        'visits',
        visit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      assessmentId = await txn.insert(
        'assessments',
        assessment.copyWithVisitId(visitId).toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // Queue for background sync (anonymized — no patient name)
      await txn.insert('sync_queue', SyncQueueEntry(
        tableName: 'visits',
        rowId: visitId,
      ).toMap());
    });

    _log.info(
      'Consultation saved: visit_id=$visitId '
      'assessment_id=$assessmentId '
      'risk=${visit.riskLevel.name} '
      'referral=${visit.referralNeeded}',
    );
    // PRIVACY: patient name not logged

    final savedVisit = Visit.fromMap({
      ...visit.toMap(),
      'id': visitId,
    });
    final savedAssessment = Assessment.fromMap({
      ...assessment.toMap(),
      'id': assessmentId,
      'visit_id': visitId,
    });

    return VisitWithAssessment(
      visit: savedVisit,
      assessment: savedAssessment,
      patient: patient,
    );
  }

  /// Get all visits for a patient, most recent first.
  Future<List<Visit>> getForPatient(int patientId) async {
    final db = await _provider.db;
    final rows = await db.query(
      'visits',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'visited_at DESC',
    );
    return rows.map(Visit.fromMap).toList();
  }

  /// Get a single visit with its assessment.
  Future<VisitWithAssessment> getVisitWithAssessment(
      int visitId, Patient patient) async {
    final db = await _provider.db;

    final visitRows = await db.query(
      'visits',
      where: 'id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    if (visitRows.isEmpty) throw RecordNotFoundException('Visit', visitId);

    final assessmentRows = await db.query(
      'assessments',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      limit: 1,
    );

    return VisitWithAssessment(
      visit: Visit.fromMap(visitRows.first),
      assessment: assessmentRows.isEmpty
          ? null
          : Assessment.fromMap(assessmentRows.first),
      patient: patient,
    );
  }

  /// Count visits by risk level for dashboard statistics.
  Future<Map<RiskLevel, int>> countByRiskLevel() async {
    final db = await _provider.db;
    final rows = await db.rawQuery(
      'SELECT risk_level, COUNT(*) AS c FROM visits GROUP BY risk_level',
    );
    final result = <RiskLevel, int>{
      RiskLevel.low: 0,
      RiskLevel.medium: 0,
      RiskLevel.high: 0,
    };
    for (final row in rows) {
      final level = RiskLevel.values[row['risk_level'] as int];
      result[level] = row['c'] as int;
    }
    return result;
  }

  /// Count visits that resulted in a referral.
  Future<int> countReferrals() async {
    final db = await _provider.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM visits WHERE referral_needed = 1',
    );
    return rows.first['c'] as int;
  }

  /// Recent visits across all patients (for the home feed).
  Future<List<Visit>> getRecent({int limit = 20}) async {
    final db = await _provider.db;
    final rows = await db.query(
      'visits',
      orderBy: 'visited_at DESC',
      limit: limit,
    );
    return rows.map(Visit.fromMap).toList();
  }
}

// ── Extension on Assessment for visitId update ────────────────────────────────

extension _AssessmentExt on Assessment {
  Assessment copyWithVisitId(int visitId) => Assessment(
        id: id,
        visitId: visitId,
        heartRateBpm: heartRateBpm,
        spo2Pct: spo2Pct,
        temperatureF: temperatureF,
        riskScore: riskScore,
        condition: condition,
        advice: advice,
        transcript: transcript,
        isFallback: isFallback,
        backendUsed: backendUsed,
        latencyMs: latencyMs,
        createdAt: createdAt,
      );
}
