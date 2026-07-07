# Sanjeevani Backend — Deployment Guide

## Prerequisites

- Node.js 20+
- Firebase CLI: `npm install -g firebase-tools`
- A Firebase project created at console.firebase.google.com

## Step 1 — Firebase project setup

```bash
firebase login
firebase use --add           # select your project
firebase projects:list       # verify
```

## Step 2 — Enable Firestore

In Firebase Console → Firestore → Create database → Start in production mode.

## Step 3 — Deploy Firestore rules and indexes

```bash
firebase deploy --only firestore
```

Verify in Console → Firestore → Rules that the PII-rejection validator is active.

## Step 4 — Deploy Cloud Functions

```bash
cd functions && npm install
firebase deploy --only functions
```

Three functions will be deployed:
- `onVisitSummaryCreated` — Firestore trigger
- `getDashboardStats` — callable for the dashboard
- `scheduledAggregation` — daily cron at 01:00 IST

## Step 5 — Build and deploy the dashboard

```bash
cd dashboard
npm install
REACT_APP_FUNCTIONS_URL=https://us-central1-YOUR_PROJECT.cloudfunctions.net npm run build
firebase deploy --only hosting
```

## Step 6 — Wire the Flutter app

In `sync/lib/firebase_backend.dart`, set:
```dart
FirebaseBackend(
  projectId: 'YOUR_PROJECT_ID',
  authToken: await _getAppToken(),
)
```

## Local development with emulators

```bash
firebase emulators:start
# Functions: http://localhost:5001
# Firestore: http://localhost:8080
# Dashboard: http://localhost:5000
# Emulator UI: http://localhost:4000
```

## Running tests

```bash
# Cloud Functions tests (no emulator needed)
cd functions && node --test test/

# Dashboard tests
cd dashboard && node --test src/utils/__tests__/
```

## Security checklist before demo

- [ ] Firestore rules deployed and verified
- [ ] No PII visible in Firestore Console (check a sample document)
- [ ] Cloud Function logs show no patient names or transcript text
- [ ] Dashboard displays only aggregated counts
- [ ] Security headers present on hosting (check Network tab in browser)
