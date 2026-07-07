/// SQLite database connection management.
///
/// Responsibilities:
///   - Open the database exactly once (singleton pattern).
///   - Enable WAL journal mode for better concurrent read performance.
///   - Enable foreign key enforcement (SQLite disables this by default).
///   - Run migrations in order from current version to target version.
///   - Expose a tested close() for integration tests.
///
/// Security decisions:
///   - Database lives in the app's private documents directory.
///     It is never written to external storage or a shared path.
///   - WAL mode means the database file can be safely read while being
///     written (no file-level locks that could corrupt data during a
///     background sync write).
library;

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sanjeevani_records/db/schema.dart';
import 'package:sanjeevani_records/core/exceptions.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseProvider {
  DatabaseProvider._();

  static final DatabaseProvider instance = DatabaseProvider._();
  static final _log = Logger('sanjeevani.records.db');

  Database? _db;

  /// Returns the open database, opening it on first call.
  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = path.join(await getDatabasesPath(), 'sanjeevani.db');
    _log.info('Opening database at $dbPath');

    try {
      return await openDatabase(
        dbPath,
        version: kSchemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      throw DatabaseException(
        'Failed to open the Sanjeevani database. '
        'The device storage may be full or the database file may be corrupt.',
        cause: e,
      );
    }
  }

  /// Called when the database is created for the first time.
  Future<void> _onCreate(Database db, int version) async {
    _log.info('Creating schema at version $version');
    final batch = db.batch();
    for (final sql in kCreateTablesV1) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
    _log.info('Schema created successfully');
  }

  /// Called when version < kSchemaVersion.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log.info('Migrating database from v$oldVersion to v$newVersion');
    final batch = db.batch();
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      final stmts = kMigrations[v];
      if (stmts == null) {
        throw DatabaseException(
          'No migration defined for schema version $v. '
          'Add the migration to kMigrations in schema.dart.',
        );
      }
      for (final sql in stmts) {
        batch.execute(sql);
      }
      _log.info('Applied migration for version $v');
    }
    await batch.commit(noResult: true);
    _log.info('Migration complete');
  }

  /// Called every time the database is opened.
  Future<void> _onOpen(Database db) async {
    // SQLite disables foreign keys by default — enable them explicitly.
    await db.execute('PRAGMA foreign_keys = ON');
    // WAL mode for better concurrent read/write performance.
    await db.execute('PRAGMA journal_mode = WAL');
    _log.fine('Database opened with FK=ON, WAL mode');
  }

  /// Close the database. Used in tests and app shutdown.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _log.info('Database closed');
  }
}
