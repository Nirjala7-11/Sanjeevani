# Sanjeevani — Backend & Sync Layer v1.0

**Owner: Person D**

Firebase-based sync backend, PHC read-only dashboard, and connectivity-triggered sync client.

---

## What this package contains

```
firestore/
  firestore.rules          — Firestore security rules (PII rejection, append-only)
  firestore.indexes.json   — Composite indexes for dashboard queries

functions/
  src/
    index.js               — Three Cloud Functions: trigger, callable, scheduler
    aggregator.js          — Pure aggregation logic (testable without Firebase)
    validator.js           — Server-side schema + PII validation
  test/
    aggregator.test.js     — 15 tests
    validator.test.js      — 28 tests (including all 8 PII field rejections)

sync/
  lib/
    firebase_backend.dart  — Implements RemoteBackend (records layer interface)
    connectivity_watcher.dart — Triggers sync when network is detected

dashboard/
  src/
    components/
      App.jsx              — Root, Firebase auth state
      Dashboard.jsx        — Full PHC dashboard with 4 charts + KPI cards
    api/
      statsApi.js          — Fetches aggregated stats from getDashboardStats
    utils/
      chartHelpers.js      — Pure chart transform functions
      __tests__/
        chartHelpers.test.js — 25 tests

firebase.json              — Hosting, Functions, Firestore, Emulators config
docs/deployment.md         — Step-by-step deployment guide
```

---

## Privacy contract — what reaches the cloud

| Field | Sent to Firebase | Shown on Dashboard |
|---|---|---|
| Patient name | ❌ Never | ❌ Never |
| Phone number | ❌ Never | ❌ Never |
| Transcript text | ❌ Never | ❌ Never |
| Exact age | ❌ Never | ❌ Never |
| Village name | ❌ Never | ❌ Never |
| Visit date (day only) | ✅ | ✅ |
| Risk level | ✅ | ✅ (aggregated) |
| Referral needed (bool) | ✅ | ✅ (as %) |
| Age bracket | ✅ | ✅ (aggregated) |
| Village hash (8 hex) | ✅ | ✅ (opaque hash only) |

Privacy is enforced in three layers:
1. **Records layer** — anonymizes before queuing (Dart, `sync_service.dart`)
2. **Firebase backend** — `_assertNoPatientPii()` checks before every write (Dart)
3. **Cloud Functions validator** — rejects PII fields server-side (JS, tested)
4. **Firestore rules** — `isValidVisitSummary()` prevents PII at the DB level

---

## Running tests

```bash
# All 68 JS tests — no Firebase emulator, no Node modules to install
node --test \
  functions/test/validator.test.js \
  functions/test/aggregator.test.js \
  dashboard/src/utils/__tests__/chartHelpers.test.js
```

---

## Person D's integration tasks

1. **Wire `FirebaseBackend`** into the Flutter app's dependency injection in `main.dart`
   — replace `RemoteBackend` placeholder in `RecordsService` with `FirebaseBackend(projectId, token)`.

2. **Start `ConnectivityWatcher`** at app startup to auto-trigger sync when network returns.

3. **Deploy Firestore rules** — `firebase deploy --only firestore` — before the demo.
   Verify in Console that raw `visit_summaries` documents are not client-readable.

4. **Deploy Cloud Functions** — `firebase deploy --only functions`.

5. **Build and deploy dashboard** to Firebase Hosting for the judge demo.

6. **Prepare the pitch deck and demo video** — this layer's secondary but
   equally important responsibility. The demo should show the dashboard
   updating live as a test visit is synced from the app.

---

## Architecture decisions

**Why Firebase instead of a custom server:**
For a student project with a demo deadline, Firebase eliminates infra overhead
(no VM, no reverse proxy, no TLS setup). Firestore's offline SDK also means
the Flutter app can attempt writes that queue locally when the server is
unreachable — aligning naturally with the offline-first architecture.

**Why Firestore rules enforce PII rejection:**
The Dart-side checks (`_assertNoPatientPii`) are a programming safeguard.
The server-side `isValidVisitSummary()` in Firestore rules is the security
boundary — it cannot be bypassed by a compromised client.

**Why the dashboard is read-only:**
The PHC officer needs to see trends, not edit records. Making the dashboard
write-capable would require a more complex auth model and creates a
data-integrity risk. Read-only via Firestore rules means no dashboard
bug can corrupt patient-linked data.
