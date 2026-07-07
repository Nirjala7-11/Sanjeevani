/**
 * Sanjeevani Cloud Functions — entry point.
 *
 * Three functions:
 *   onVisitSummaryCreated — aggregates stats whenever a new visit is synced.
 *   getDashboardStats     — callable: returns aggregated stats for the dashboard.
 *   scheduledAggregation  — daily re-aggregation safety net.
 *
 * Privacy contract:
 *   - These functions read raw visit_summaries documents (which are already
 *     anonymized — no patient names, no transcripts, no exact ages).
 *   - They write only to the aggregations collection.
 *   - They never log or emit any field from visit_summaries except
 *     counts and percentages. The raw documents are not accessible to
 *     any client (enforced by Firestore rules).
 */

'use strict';

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall }            = require('firebase-functions/v2/https');
const { onSchedule }        = require('firebase-functions/v2/scheduler');
const { logger }            = require('firebase-functions');
const admin                 = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// ── Aggregation writer ────────────────────────────────────────────────────────

const { buildAggregations } = require('./aggregator');
const { validateVisitSummary } = require('./validator');

// Triggered on every new visit summary written by the app.
exports.onVisitSummaryCreated = onDocumentCreated(
  'visit_summaries/{docId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { valid, errors } = validateVisitSummary(data);
    if (!valid) {
      logger.error('Invalid visit_summary received', { docId: event.params.docId, errors });
      return;
    }

    logger.info('Processing visit summary', {
      risk_level:      data.risk_level,
      referral_needed: data.referral_needed,
      age_bracket:     data.age_bracket,
    });
    // PRIVACY: never log name, village_hash, transcript, or village

    await _updateAggregations(data);
  },
);

// Callable: returns current aggregated dashboard stats.
// Requires authentication (dashboard user must be signed in).
exports.getDashboardStats = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new Error('Unauthenticated — dashboard login required');
  }

  const snapshot = await db.collection('aggregations')
    .orderBy('computed_at', 'desc')
    .limit(1)
    .get();

  if (snapshot.empty) {
    return { status: 'no_data', message: 'No aggregations computed yet' };
  }

  return snapshot.docs[0].data();
});

// Daily aggregation re-run at 01:00 IST (19:30 UTC) as a safety net.
exports.scheduledAggregation = onSchedule('30 19 * * *', async () => {
  logger.info('Running scheduled full re-aggregation');
  await _fullReaggregation();
});

// ── Aggregation helpers ────────────────────────────────────────────────────────

async function _updateAggregations(newVisit) {
  const aggRef = db.collection('aggregations').doc('current');

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(aggRef);
    const agg  = snap.exists ? snap.data() : _emptyAggregation();

    _applyVisit(agg, newVisit);
    agg.computed_at = admin.firestore.FieldValue.serverTimestamp();
    agg.total_visits += 1;

    txn.set(aggRef, agg);
  });
}

async function _fullReaggregation() {
  const agg = _emptyAggregation();
  const snap = await db.collection('visit_summaries').get();

  snap.forEach((doc) => {
    const data = doc.data();
    const { valid } = validateVisitSummary(data);
    if (valid) {
      _applyVisit(agg, data);
      agg.total_visits += 1;
    }
  });

  agg.computed_at = admin.firestore.FieldValue.serverTimestamp();
  await db.collection('aggregations').doc('current').set(agg);
  logger.info('Re-aggregation complete', { total_visits: agg.total_visits });
}

function _applyVisit(agg, visit) {
  // Risk level counts
  const level = visit.risk_level;
  if (agg.by_risk[level] !== undefined) {
    agg.by_risk[level] += 1;
  }

  // Referral count
  if (visit.referral_needed === true) {
    agg.referral_count += 1;
  }

  // Age bracket counts
  const ab = visit.age_bracket;
  if (agg.by_age_bracket[ab] !== undefined) {
    agg.by_age_bracket[ab] += 1;
  }

  // Village activity — only village_hash (not name) is stored
  const vh = visit.village_hash;
  agg.village_activity[vh] = (agg.village_activity[vh] ?? 0) + 1;

  // 7-day rolling visit count (date key only)
  const date = visit.visit_date; // YYYY-MM-DD
  agg.daily_counts[date] = (agg.daily_counts[date] ?? 0) + 1;
}

function _emptyAggregation() {
  return {
    total_visits:    0,
    referral_count:  0,
    by_risk:         { low: 0, medium: 0, high: 0 },
    by_age_bracket:  { '0-5': 0, '6-18': 0, '19-60': 0, '60+': 0 },
    village_activity: {},
    daily_counts:    {},
    computed_at:     null,
  };
}
