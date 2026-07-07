/// Sync queue repository.
///
/// Manages the queue of records waiting to be synced to the backend.
///
/// Privacy contract enforced here:
///   - Only table name and row id are stored in this table.
///   - No patient names, vitals, or transcript text ever enter the queue.
///   - The sync layer reads from this queue and fetches only anonymized
///     aggregate data (risk level, referral flag, village code) when it
///     actually transmits — never raw patient records.
library;

import 'package:logging/logging.dart';
import 'package:sanjeevani_records/core/models.dart';
import 'package:sanjeevani_records/db/database_provider.dart';

class SyncQueueRepository {
  SyncQueueRepository(this._provider);

  final DatabaseProvider _provider;
  final _log = Logger('sanjeevani.records.sync_queue_repo');

  static const int _maxRetries = 3;

  Future<void> enqueue(String tableName, int rowId) async {
    final db = await _provider.db;
    await db.insert('sync_queue', SyncQueueEntry(
      tableName: tableName,
      rowId: rowId,
    ).toMap());
    _log.fine('Enqueued: table=$tableName row_id=$rowId');
  }

  /// Fetch all pending entries (not yet synced, retries remaining).
  Future<List<SyncQueueEntry>> getPending() async {
    final db = await _provider.db;
    final rows = await db.query(
      'sync_queue',
      where: 'status = ? AND retries < ?',
      whereArgs: [SyncStatus.pending.index, _maxRetries],
      orderBy: 'created_at ASC',
    );
    return rows.map(SyncQueueEntry.fromMap).toList();
  }

  Future<void> markInProgress(int id) async {
    final db = await _provider.db;
    await db.update(
      'sync_queue',
      {
        'status': SyncStatus.inProgress.index,
        'last_attempt_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(int id) async {
    final db = await _provider.db;
    await db.update(
      'sync_queue',
      {'status': SyncStatus.synced.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id) async {
    final db = await _provider.db;
    await db.rawUpdate(
      '''UPDATE sync_queue
         SET status = ?, retries = retries + 1,
             last_attempt_at = ?
         WHERE id = ?''',
      [SyncStatus.failed.index, DateTime.now().toIso8601String(), id],
    );
  }

  /// Remove all synced entries older than [days] days (housekeeping).
  Future<int> pruneOldSynced({int days = 30}) async {
    final db = await _provider.db;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String();
    final affected = await db.delete(
      'sync_queue',
      where: 'status = ? AND created_at < ?',
      whereArgs: [SyncStatus.synced.index, cutoff],
    );
    if (affected > 0) _log.info('Pruned $affected old sync entries');
    return affected;
  }

  Future<int> pendingCount() async {
    final db = await _provider.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sync_queue WHERE status = ?',
      [SyncStatus.pending.index],
    );
    return rows.first['c'] as int;
  }
}
