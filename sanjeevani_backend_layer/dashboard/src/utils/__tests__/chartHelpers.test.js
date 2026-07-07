/**
 * Tests for chart helper pure functions.
 * No React, no Chart.js, no Firebase required — pure logic.
 */

'use strict';

const {
  riskDonutData, dailyTrendData, ageBracketData,
  topVillageActivity, summaryKpis,
} = require('../chartHelpers');

const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

// ── Sample data ───────────────────────────────────────────────────────────────

const sampleStats = {
  total_visits:   100,
  referral_count: 25,
  by_risk:        { low: 50, medium: 30, high: 20 },
  by_age_bracket: { '0-5': 30, '6-18': 20, '19-60': 40, '60+': 10 },
  daily_counts: {
    '2026-07-01': 10, '2026-07-02': 15,
    '2026-07-03': 8,  '2026-07-04': 12,
  },
  village_activity: {
    'aabbccdd': 35, 'deadbeef': 25, 'cafe0001': 15,
    'f00dface': 10, 'badc0ded': 8,  'b00bface': 7,
  },
};

// ── riskDonutData ─────────────────────────────────────────────────────────────

describe('riskDonutData', () => {
  it('has three labels', () => {
    const d = riskDonutData(sampleStats.by_risk);
    assert.equal(d.labels.length, 3);
  });

  it('data array matches risk counts in order low/medium/high', () => {
    const d = riskDonutData({ low: 50, medium: 30, high: 20 });
    assert.deepEqual(d.datasets[0].data, [50, 30, 20]);
  });

  it('handles all-zero counts without error', () => {
    const d = riskDonutData({ low: 0, medium: 0, high: 0 });
    assert.deepEqual(d.datasets[0].data, [0, 0, 0]);
  });

  it('handles missing keys gracefully', () => {
    const d = riskDonutData({});
    assert.deepEqual(d.datasets[0].data, [0, 0, 0]);
  });

  it('backgroundColor array has 3 entries', () => {
    const d = riskDonutData(sampleStats.by_risk);
    assert.equal(d.datasets[0].backgroundColor.length, 3);
  });
});

// ── dailyTrendData ────────────────────────────────────────────────────────────

describe('dailyTrendData', () => {
  it('returns correct number of data points', () => {
    const d = dailyTrendData(sampleStats.daily_counts, 4);
    assert.equal(d.datasets[0].data.length, 4);
  });

  it('sorts dates chronologically', () => {
    const counts = { '2026-07-03': 8, '2026-07-01': 10, '2026-07-02': 15 };
    const d = dailyTrendData(counts, 3);
    assert.deepEqual(d.datasets[0].data, [10, 15, 8]);
  });

  it('limits to requested days', () => {
    const d = dailyTrendData(sampleStats.daily_counts, 2);
    assert.equal(d.datasets[0].data.length, 2);
  });

  it('handles empty daily_counts', () => {
    const d = dailyTrendData({});
    assert.equal(d.datasets[0].data.length, 0);
    assert.equal(d.labels.length, 0);
  });

  it('labels count matches data count', () => {
    const d = dailyTrendData(sampleStats.daily_counts);
    assert.equal(d.labels.length, d.datasets[0].data.length);
  });
});

// ── ageBracketData ────────────────────────────────────────────────────────────

describe('ageBracketData', () => {
  it('returns 4 age brackets', () => {
    const d = ageBracketData(sampleStats.by_age_bracket);
    assert.equal(d.datasets[0].data.length, 4);
    assert.equal(d.labels.length, 4);
  });

  it('data matches brackets in order 0-5, 6-18, 19-60, 60+', () => {
    const d = ageBracketData({ '0-5': 30, '6-18': 20, '19-60': 40, '60+': 10 });
    assert.deepEqual(d.datasets[0].data, [30, 20, 40, 10]);
  });

  it('handles missing brackets with 0', () => {
    const d = ageBracketData({ '0-5': 5 });
    assert.equal(d.datasets[0].data[0], 5);
    assert.equal(d.datasets[0].data[1], 0); // 6-18 missing → 0
  });
});

// ── topVillageActivity ────────────────────────────────────────────────────────

describe('topVillageActivity', () => {
  it('returns sorted by count descending', () => {
    const result = topVillageActivity(sampleStats.village_activity, 3);
    assert.equal(result[0].hash, 'aabbccdd'); // highest count
    assert.equal(result[1].hash, 'deadbeef');
    assert.equal(result[2].hash, 'cafe0001');
  });

  it('rank starts at 1', () => {
    const result = topVillageActivity(sampleStats.village_activity, 1);
    assert.equal(result[0].rank, 1);
  });

  it('limits to topN results', () => {
    const result = topVillageActivity(sampleStats.village_activity, 3);
    assert.equal(result.length, 3);
  });

  it('village hash is 8 hex chars (privacy check)', () => {
    const result = topVillageActivity(sampleStats.village_activity);
    for (const row of result) {
      assert.match(row.hash, /^[0-9a-f]{8}$/,
        `Hash ${row.hash} is not 8 lowercase hex chars`);
    }
  });

  it('no name or village field in results (privacy check)', () => {
    const result = topVillageActivity(sampleStats.village_activity);
    for (const row of result) {
      assert.ok(!('name' in row), 'name field should not exist');
      assert.ok(!('village' in row), 'village field should not exist');
    }
  });

  it('handles empty village_activity', () => {
    const result = topVillageActivity({});
    assert.equal(result.length, 0);
  });
});

// ── summaryKpis ───────────────────────────────────────────────────────────────

describe('summaryKpis', () => {
  it('computes totalVisits correctly', () => {
    const kpis = summaryKpis(sampleStats);
    assert.equal(kpis.totalVisits, 100);
  });

  it('computes referralRate as percentage', () => {
    const kpis = summaryKpis(sampleStats);
    assert.equal(kpis.referralRate, 25.0); // 25/100 * 100
  });

  it('computes highRiskRate as percentage', () => {
    const kpis = summaryKpis({ ...sampleStats, by_risk: { low: 70, medium: 20, high: 10 } });
    assert.equal(kpis.highRiskRate, 10.0); // 10/100 * 100
  });

  it('activeVillages is count of unique village hashes', () => {
    const kpis = summaryKpis(sampleStats);
    assert.equal(kpis.activeVillages, 6);
  });

  it('returns zero rates for zero total visits', () => {
    const kpis = summaryKpis({ ...sampleStats, total_visits: 0, referral_count: 0 });
    assert.equal(kpis.referralRate, 0);
    assert.equal(kpis.highRiskRate, 0);
  });

  it('handles missing optional fields gracefully', () => {
    const kpis = summaryKpis({ total_visits: 10 });
    assert.ok(kpis.referralRate >= 0);
    assert.ok(kpis.activeVillages >= 0);
  });
});
