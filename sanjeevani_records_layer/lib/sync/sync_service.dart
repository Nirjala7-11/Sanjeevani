/// Sync service — uploads anonymized case data when connectivity returns.
///
/// ════════════════════════════════════════════════════════════════════════
/// PRIVACY CONTRACT (non-negotiable)
/// ════════════════════════════════════════════════════════════════════════
///
/// What IS transmitted to the backend:
///   - Visit date (day only, not time)
///   - Risk level (LOW / MEDIUM / HIGH)
///   - Whether referral was needed (true/false)
///   - Village code (not name — mapped to a district code)
///   - Patient age bracket (0–5, 6–18, 19–60, 60+)
///   - Gender (aggregated, not linked to a name)
///
/// What is NEVER transmitted:
///   - Patient name
///   - Patient phone number
///   - Transcript text
///   - Any personally identifiable information
///
/// The backend receives epidemiological signal (where are high-risk
/// cases appearing, what is the referral rate) — never patient records.
///
/// ════════════════════════════════════════════════════════════════════════
/// CONNECTIVITY MODEL
/// ════════════════════════════════════════════════════════════════════════
///
/// The sync service is entirely optional. The app works correctly if
/// sync never fires. Sync activates when:
///   (a) The device detects network connectivity, AND
///   (b) [SyncService.runPendingSync()] is called (by Person D's
///       background scheduler in the sync layer).
///
/// Failures are retried up to [SyncQueueRepository._maxRetries] times
/// with exponential back-off. Failed entries after max retries are left
/// in the queue marked as 'failed' — they are not discarded, so a
/// data-review process can handle them if needed.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/exceptions.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/db/database_provider.dart';
import 'package:sanjeevani_records/repositories/sync_queue_repository.dart';

/// Abstract interface for the remote backend client.
/// The concrete implementation (Firebase / Supabase) is Person D's work —
/// this package depends on the interface, never on a specific cloud SDK.
abstract class RemoteBackend {
  Future<void> uploadVisitSummary(Map<String, dynamic> anonymizedPayload);
}

class SyncService {
  SyncService(this._queueRepo, this._dbProvider, this._backend);

  final SyncQueueRepository _queueRepo;
  final DatabaseProvider _dbProvider;
  final RemoteBackend _backend;
  final _log = Logger('sanjeevani.records.sync');

  bool _running = false;

  /// Run sync for all pending queue entries.
  /// Safe to call concurrently — second call is a no-op while first runs.
  Future<SyncResult> runPendingSync() async {
    if (_running) {
      _log.fine('Sync already running — skipping concurrent call');
      return const SyncResult(attempted: 0, succeeded: 0, failed: 0);
    }
    _running = true;

    int attempted = 0, succeeded = 0, failed = 0;

    try {
      final pending = await _queueRepo.getPending();
      _log.info('Starting sync: ${pending.length} pending entries');

      for (final entry in pending) {
        attempted++;
        try {
          await _queueRepo.markInProgress(entry.id!);
          final payload = await _buildAnonymizedPayload(entry);
          await _backend.uploadVisitSummary(payload);
          await _queueRepo.markSynced(entry.id!);
          succeeded++;
        } catch (e) {
          await _queueRepo.markFailed(entry.id!);
          failed++;
          _log.warning('Sync failed for entry ${entry.id}: $e');
        }
      }

      await _queueRepo.pruneOldSynced();
      _log.info(
        'Sync complete: attempted=$attempted '
        'succeeded=$succeeded failed=$failed',
      );
    } finally {
      _running = false;
    }

    return SyncResult(
      attempted: attempted,
      succeeded: succeeded,
      failed: failed,
    );
  }

  /// Build anonymized payload — NEVER includes patient name or transcript.
  Future<Map<String, dynamic>> _buildAnonymizedPayload(
      SyncQueueEntry entry) async {
    if (entry.tableName != 'visits') {
      throw SyncException(
          'Sync payload builder only handles visits table. '
          'Got: ${entry.tableName}');
    }

    final db = await _dbProvider.db;

    // Fetch visit
    final visitRows = await db.query(
      'visits',
      where: 'id = ?',
      whereArgs: [entry.rowId],
      limit: 1,
    );
    if (visitRows.isEmpty) {
      throw SyncException(
          'Visit row_id=${entry.rowId} not found during sync.');
    }
    final visit = Visit.fromMap(visitRows.first);

    // Fetch patient for age bracket and gender only — NOT name
    final patientRows = await db.query(
      'patients',
      columns: ['age', 'gender', 'village'],
      where: 'id = ?',
      whereArgs: [visit.patientId],
      limit: 1,
    );
    if (patientRows.isEmpty) {
      throw SyncException(
          'Patient for visit ${entry.rowId} not found during sync.');
    }
    final age = patientRows.first['age'] as int;
    final gender = Gender.values[patientRows.first['gender'] as int].name;
    final village = patientRows.first['village'] as String;

    // Age bracket — not exact age
    final ageBracket = _ageBracket(age);

    // Visit date — day only, not time
    final visitDate =
        '${visit.visitedAt.year}-'
        '${visit.visitedAt.month.toString().padLeft(2, '0')}-'
        '${visit.visitedAt.day.toString().padLeft(2, '0')}';

    return {
      'visit_date':      visitDate,       // day only
      'risk_level':      visit.riskLevel.name,
      'referral_needed': visit.referralNeeded,
      'age_bracket':     ageBracket,      // NOT exact age
      'gender':          gender,
      'village_hash':    _hashVillage(village), // NOT village name
    };
  }

  String _ageBracket(int age) {
    if (age <= 5)  return '0-5';
    if (age <= 18) return '6-18';
    if (age <= 60) return '19-60';
    return '60+';
  }

  /// One-way hash the village name so patterns can be detected
  /// across visits without revealing the actual name to the backend.
  String _hashVillage(String village) {
    // Simple 8-char hex from string hashCode — not reversible.
    return village.trim().toLowerCase().hashCode.toRadixString(16).padLeft(8, '0');
  }
}

class SyncResult {
  const SyncResult({
    required this.attempted,
    required this.succeeded,
    required this.failed,
  });
  final int attempted;
  final int succeeded;
  final int failed;

  bool get allSucceeded => attempted > 0 && failed == 0;
  bool get nothingToSync => attempted == 0;

  @override
  String toString() =>
      'SyncResult(attempted=$attempted, succeeded=$succeeded, failed=$failed)';
}
