/**
 * Pure helper functions for transforming aggregation data
 * into Chart.js-compatible datasets.
 *
 * All functions are pure (no side effects, no API calls) so they
 * can be unit-tested without a browser or a running Firebase project.
 *
 * Privacy note: these functions never receive or process raw visit
 * documents — only the already-aggregated counts from Firestore's
 * aggregations collection. Village hashes appear as opaque keys in
 * charts and are never reverse-mapped to village names here.
 */

'use strict';

// ── Risk level donut chart ────────────────────────────────────────────────────

/**
 * Transform by_risk counts into a Chart.js donut dataset.
 * @param {{ low: number, medium: number, high: number }} byRisk
 * @returns {object} Chart.js data config
 */
function riskDonutData(byRisk) {
  return {
    labels: ['Low risk', 'Medium risk', 'High risk'],
    datasets: [{
      data: [byRisk.low ?? 0, byRisk.medium ?? 0, byRisk.high ?? 0],
      backgroundColor: ['#27500A', '#BA7517', '#791F1F'],
      borderColor:     ['#EAF3DE', '#FAEEDA', '#FCEBEB'],
      borderWidth: 2,
    }],
  };
}

// ── Daily visit trend line ────────────────────────────────────────────────────

/**
 * Transform daily_counts into a Chart.js line chart dataset.
 * Returns the last [days] days sorted chronologically.
 * @param {Object.<string, number>} dailyCounts — { 'YYYY-MM-DD': count }
 * @param {number} days — how many days to show (default 14)
 * @returns {object} Chart.js data config
 */
function dailyTrendData(dailyCounts, days = 14) {
  const sorted = Object.entries(dailyCounts)
    .sort(([a], [b]) => a.localeCompare(b))
    .slice(-days);

  return {
    labels: sorted.map(([date]) => _formatDate(date)),
    datasets: [{
      label:           'Visits per day',
      data:            sorted.map(([, count]) => count),
      borderColor:     '#085041',
      backgroundColor: 'rgba(8, 80, 65, 0.08)',
      tension:         0.4,
      fill:            true,
      pointRadius:     4,
      pointBackgroundColor: '#085041',
    }],
  };
}

// ── Age bracket bar chart ─────────────────────────────────────────────────────

/**
 * Transform by_age_bracket into a Chart.js bar dataset.
 * @param {{ '0-5': number, '6-18': number, '19-60': number, '60+': number }} byAge
 * @returns {object} Chart.js data config
 */
function ageBracketData(byAge) {
  const brackets = ['0-5', '6-18', '19-60', '60+'];
  return {
    labels: brackets.map(b => `Age ${b}`),
    datasets: [{
      label:           'Visits by age bracket',
      data:            brackets.map(b => byAge[b] ?? 0),
      backgroundColor: '#5DCAA5',
      borderColor:     '#085041',
      borderWidth:     1,
      borderRadius:    6,
    }],
  };
}

// ── Village activity table ────────────────────────────────────────────────────

/**
 * Transform village_activity into a sorted table-friendly array.
 * Villages are identified by hash — names are never shown.
 * @param {Object.<string, number>} villageActivity
 * @param {number} topN — return top N most active villages
 * @returns {{ hash: string, count: number, rank: number }[]}
 */
function topVillageActivity(villageActivity, topN = 10) {
  return Object.entries(villageActivity)
    .sort(([, a], [, b]) => b - a)
    .slice(0, topN)
    .map(([hash, count], i) => ({
      rank:  i + 1,
      hash:  hash,   // opaque — intentionally not the village name
      count: count,
    }));
}

// ── Summary KPI cards ─────────────────────────────────────────────────────────

/**
 * Compute the four headline KPI values for the top-of-dashboard cards.
 * @param {import('../api/statsApi').DashboardStats} stats
 * @returns {{ totalVisits, referralRate, highRiskRate, activeVillages }}
 */
function summaryKpis(stats) {
  const total = stats.total_visits ?? 0;
  const safe  = n => total > 0 ? +(n / total * 100).toFixed(1) : 0;

  return {
    totalVisits:    total,
    referralRate:   safe(stats.referral_count ?? 0),
    highRiskRate:   safe(stats.by_risk?.high ?? 0),
    activeVillages: Object.keys(stats.village_activity ?? {}).length,
  };
}

// ── Date formatting ───────────────────────────────────────────────────────────

function _formatDate(iso) {
  // 'YYYY-MM-DD' → 'Jul 1'
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
}

module.exports = {
  riskDonutData,
  dailyTrendData,
  ageBracketData,
  topVillageActivity,
  summaryKpis,
};
