/**
 * Aggregation helpers — pure functions, no Firestore I/O.
 * Separated from index.js so they can be unit-tested without
 * Firebase emulator or admin SDK.
 */

'use strict';

function buildAggregations(visits) {
  const agg = emptyAggregation();
  for (const visit of visits) {
    applyVisit(agg, visit);
    agg.total_visits += 1;
  }
  return agg;
}

function applyVisit(agg, visit) {
  const level = visit.risk_level;
  if (level in agg.by_risk) agg.by_risk[level] += 1;

  if (visit.referral_needed === true) agg.referral_count += 1;

  const ab = visit.age_bracket;
  if (ab in agg.by_age_bracket) agg.by_age_bracket[ab] += 1;

  const vh = visit.village_hash;
  agg.village_activity[vh] = (agg.village_activity[vh] ?? 0) + 1;

  const date = visit.visit_date;
  agg.daily_counts[date] = (agg.daily_counts[date] ?? 0) + 1;
}

function emptyAggregation() {
  return {
    total_visits:    0,
    referral_count:  0,
    by_risk:         { low: 0, medium: 0, high: 0 },
    by_age_bracket:  { '0-5': 0, '6-18': 0, '19-60': 0, '60+': 0 },
    village_activity: {},
    daily_counts:    {},
  };
}

// Compute derived metrics from a finished aggregation.
function computeMetrics(agg) {
  const total = agg.total_visits;
  if (total === 0) return { referral_rate: 0, high_risk_rate: 0 };
  return {
    referral_rate:   +(agg.referral_count / total * 100).toFixed(1),
    high_risk_rate:  +(agg.by_risk.high   / total * 100).toFixed(1),
    medium_risk_rate:+(agg.by_risk.medium / total * 100).toFixed(1),
    low_risk_rate:   +(agg.by_risk.low    / total * 100).toFixed(1),
  };
}

module.exports = { buildAggregations, applyVisit, emptyAggregation, computeMetrics };
