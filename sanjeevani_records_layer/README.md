# Sanjeevani — Data & Records Layer v1.0

**Owner: Person C**

Manages all structured data for the Sanjeevani health assistant:
patient profiles, visit logs, clinical assessments, scheduled care
reminders, anonymized sync queue, and the medical knowledge base.

---

## Architecture

```
lib/
  records_service.dart        — single public API for the UI layer
  core/
    exceptions.dart           — typed exception hierarchy
    models.dart               — Patient, Visit, Assessment, Reminder,
                                SyncQueueEntry, PatientSummary, VisitWithAssessment
  db/
    schema.dart               — SQL table definitions + migration map
    database_provider.dart    — SQLite connection, WAL mode, FK enforcement
  repositories/
    patient_repository.dart   — CRUD + search + summaries
    visit_repository.dart     — visits + assessments (atomic transaction)
    reminder_repository.dart  — due/overdue queries
    sync_queue_repository.dart— pending/synced/failed queue management
  reminder/
    reminder_engine.dart      — antenatal, immunization, hypertension,
                                TB, postnatal schedule generators
  sync/
    sync_service.dart         — anonymized background sync (Person D wires this)
  knowledge/
    knowledge_store.dart      — loads & validates knowledge_base.json
  utils/
    logger.dart               — privacy-conscious logging setup
data/
  knowledge_base.json         — 12 IMNCI/ICMR protocol entries (Person C owns)
test/
  test_models.dart
  test_reminder_logic.dart
  test_sync_payload.dart
  test_exceptions.dart
  test_schema.dart
```

---

## Database schema (5 tables)

| Table | Purpose | Cascade |
|---|---|---|
| `patients` | Core patient registry | Parent — deletes cascade |
| `visits` | One row per home visit | → patients |
| `assessments` | AI result linked to a visit (1:1) | → visits |
| `reminders` | Scheduled care follow-ups | → patients |
| `sync_queue` | Anonymized records awaiting upload | No cascade needed |

WAL journal mode and foreign key enforcement are enabled on every connection open.

---

## Privacy contract

What **IS** synced to the backend: visit date (day only), risk level, referral flag, age bracket (not exact age), gender, village hash (not name).

What is **NEVER** synced: patient name, phone number, transcript text, exact age, exact village name.

This is enforced in `sync_service.dart._buildAnonymizedPayload()` and tested in `test/test_sync_payload.dart`.

---

## Person C's responsibilities

1. **Maintain `data/knowledge_base.json`** — add, correct, or update protocol entries. Each entry needs `id`, `text`, `source_ref`, and optional `tags`. The code never needs to change when content changes.

2. **Verify immunization schedule milestones** in `reminder/reminder_engine.dart` against current NHM India guidelines — the constants there are illustrative defaults.

3. **Verify antenatal visit cadence** (currently 4-weekly / 28 days) against current IMNCI / NHM guidance.

4. **Get protocol content reviewed** by a doctor or medical college contact before the demo — this is the single highest-credibility action for judges.

---

## Running tests

```bash
flutter test test/
```

All tests pass without a physical device or running database (pure logic and serialization tests).

---

## Connecting to other layers

**Capture layer (Person A):** After `engine.analyse()` returns a `ClinicalRecommendation`, Person A calls `RecordsService.instance.saveConsultation(...)` to persist the result.

**Intelligence layer (Person B):** The Python intelligence layer reads `data/knowledge_base.json` directly for its FAISS retrieval — it does not go through this Dart package. Keep the JSON file identical in both repositories.

**Sync layer (Person D):** Implement the `RemoteBackend` abstract class in `sync_service.dart` with the Firebase / Supabase SDK. Then call `SyncService.runPendingSync()` from a background connectivity listener.
