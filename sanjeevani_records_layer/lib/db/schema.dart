/// SQLite schema definitions and migration engine.
///
/// Design decisions:
///   - Schema version is the single source of truth — bump it for every
///     structural change. Migrations are additive only; dropping columns
///     requires a new table + data migration, never ALTER TABLE DROP.
///   - Every table has created_at. Mutable tables also have updated_at.
///   - Foreign keys are enabled at connection open time.
///   - Indexes are created for every column used in WHERE or JOIN.
///   - The sync_queue table stores only table name + row_id — no patient
///     data lives in the queue itself.
library;

/// Current schema version. Increment whenever the schema changes.
const int kSchemaVersion = 1;

/// All CREATE TABLE statements for version 1.
const List<String> kCreateTablesV1 = [
  '''
  CREATE TABLE IF NOT EXISTS patients (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT    NOT NULL,
    village         TEXT    NOT NULL,
    age             INTEGER NOT NULL CHECK(age > 0 AND age < 130),
    gender          INTEGER NOT NULL,
    phone_number    TEXT,
    is_pregnant     INTEGER NOT NULL DEFAULT 0 CHECK(is_pregnant IN (0,1)),
    pregnancy_weeks INTEGER CHECK(pregnancy_weeks IS NULL OR
                                  (pregnancy_weeks >= 1 AND pregnancy_weeks <= 42)),
    created_at      TEXT    NOT NULL,
    updated_at      TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS visits (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id      INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    visited_at      TEXT    NOT NULL,
    risk_level      INTEGER NOT NULL,
    referral_needed INTEGER NOT NULL DEFAULT 0 CHECK(referral_needed IN (0,1)),
    notes           TEXT,
    sync_status     INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS assessments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id        INTEGER NOT NULL UNIQUE REFERENCES visits(id) ON DELETE CASCADE,
    heart_rate_bpm  REAL    NOT NULL,
    spo2_pct        REAL    NOT NULL,
    temperature_f   REAL    NOT NULL,
    risk_score      INTEGER NOT NULL,
    condition       TEXT    NOT NULL,
    advice          TEXT    NOT NULL,
    transcript      TEXT    NOT NULL DEFAULT '',
    is_fallback     INTEGER NOT NULL DEFAULT 0 CHECK(is_fallback IN (0,1)),
    backend_used    TEXT,
    latency_ms      REAL,
    created_at      TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reminders (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id      INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    type            INTEGER NOT NULL,
    due_date        TEXT    NOT NULL,
    is_completed    INTEGER NOT NULL DEFAULT 0 CHECK(is_completed IN (0,1)),
    completed_at    TEXT,
    notes           TEXT,
    created_at      TEXT    NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS sync_queue (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name      TEXT    NOT NULL,
    row_id          INTEGER NOT NULL,
    status          INTEGER NOT NULL DEFAULT 0,
    retries         INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT    NOT NULL,
    last_attempt_at TEXT
  )
  ''',
  // ── Indexes ─────────────────────────────────────────────────────────────
  'CREATE INDEX IF NOT EXISTS idx_visits_patient_id    ON visits(patient_id)',
  'CREATE INDEX IF NOT EXISTS idx_visits_visited_at    ON visits(visited_at)',
  'CREATE INDEX IF NOT EXISTS idx_visits_risk_level    ON visits(risk_level)',
  'CREATE INDEX IF NOT EXISTS idx_assessments_visit_id ON assessments(visit_id)',
  'CREATE INDEX IF NOT EXISTS idx_reminders_patient_id ON reminders(patient_id)',
  'CREATE INDEX IF NOT EXISTS idx_reminders_due_date   ON reminders(due_date)',
  'CREATE INDEX IF NOT EXISTS idx_reminders_completed  ON reminders(is_completed)',
  'CREATE INDEX IF NOT EXISTS idx_sync_queue_status    ON sync_queue(status)',
];

/// Migrations map: version N → list of SQL statements to reach version N.
/// Add a new entry here whenever kSchemaVersion is incremented.
const Map<int, List<String>> kMigrations = {
  1: kCreateTablesV1,
  // 2: ['ALTER TABLE patients ADD COLUMN asha_id TEXT'],
};
