/**
 * Unit tests for the aggregation logic.
 * No Firebase required — pure function testing.
 */

'use strict';

const {
  buildAggregations, applyVisit, emptyAggregation, computeMetrics,
} = require('../src/aggregator');
const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

function visit(overrides = {}) {
  return {
    visit_date:      '2026-07-01',
    risk_level:      'high',
    referral_needed: true,
    age_bracket:     '19-60',
    village_hash:    'a1b2c3d4',
    gender:          'female',
    ...overrides,
  };
}

describe('emptyAggregation', () => {
  it('starts with all zeros', () => {
    const agg = emptyAggregation();
    assert.equal(agg.total_visits, 0);
    assert.equal(agg.referral_count, 0);
    assert.equal(agg.by_risk.low, 0);
    assert.equal(agg.by_risk.medium, 0);
    assert.equal(agg.by_risk.high, 0);
    assert.deepEqual(agg.village_activity, {});
    assert.deepEqual(agg.daily_counts, {});
  });
});

describe('applyVisit', () => {
  it('increments high risk count', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ risk_level: 'high' }));
    assert.equal(agg.by_risk.high, 1);
    assert.equal(agg.by_risk.medium, 0);
    assert.equal(agg.by_risk.low, 0);
  });

  it('increments referral count when referral_needed=true', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ referral_needed: true }));
    assert.equal(agg.referral_count, 1);
  });

  it('does not increment referral count when referral_needed=false', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ referral_needed: false }));
    assert.equal(agg.referral_count, 0);
  });

  it('increments age bracket count', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ age_bracket: '0-5' }));
    assert.equal(agg.by_age_bracket['0-5'], 1);
    assert.equal(agg.by_age_bracket['6-18'], 0);
  });

  it('accumulates village activity by hash', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ village_hash: 'aabbccdd' }));
    applyVisit(agg, visit({ village_hash: 'aabbccdd' }));
    applyVisit(agg, visit({ village_hash: 'deadbeef' }));
    assert.equal(agg.village_activity['aabbccdd'], 2);
    assert.equal(agg.village_activity['deadbeef'], 1);
  });

  it('accumulates daily counts', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ visit_date: '2026-07-01' }));
    applyVisit(agg, visit({ visit_date: '2026-07-01' }));
    applyVisit(agg, visit({ visit_date: '2026-07-02' }));
    assert.equal(agg.daily_counts['2026-07-01'], 2);
    assert.equal(agg.daily_counts['2026-07-02'], 1);
  });

  it('ignores unknown risk levels gracefully', () => {
    const agg = emptyAggregation();
    applyVisit(agg, visit({ risk_level: 'UNKNOWN' }));
    // Should not throw or corrupt existing counts
    assert.equal(agg.by_risk.low, 0);
    assert.equal(agg.by_risk.high, 0);
  });
});

describe('buildAggregations', () => {
  it('counts total_visits correctly', () => {
    const visits = [
      visit({ risk_level: 'high' }),
      visit({ risk_level: 'medium' }),
      visit({ risk_level: 'low' }),
    ];
    const agg = buildAggregations(visits);
    assert.equal(agg.total_visits, 3);
  });

  it('returns empty aggregation for empty input', () => {
    const agg = buildAggregations([]);
    assert.equal(agg.total_visits, 0);
    assert.equal(agg.referral_count, 0);
  });

  it('correctly counts mixed risk levels across many visits', () => {
    const visits = [
      ...Array(5).fill(null).map(() => visit({ risk_level: 'high', referral_needed: true })),
      ...Array(3).fill(null).map(() => visit({ risk_level: 'medium', referral_needed: false })),
      ...Array(2).fill(null).map(() => visit({ risk_level: 'low', referral_needed: false })),
    ];
    const agg = buildAggregations(visits);
    assert.equal(agg.total_visits, 10);
    assert.equal(agg.by_risk.high, 5);
    assert.equal(agg.by_risk.medium, 3);
    assert.equal(agg.by_risk.low, 2);
    assert.equal(agg.referral_count, 5);
  });
});

describe('computeMetrics', () => {
  it('returns zero rates for empty aggregation', () => {
    const metrics = computeMetrics(emptyAggregation());
    assert.equal(metrics.referral_rate, 0);
    assert.equal(metrics.high_risk_rate, 0);
  });

  it('computes referral rate as percentage', () => {
    const agg = buildAggregations([
      visit({ referral_needed: true }),
      visit({ referral_needed: false }),
      visit({ referral_needed: false }),
      visit({ referral_needed: false }),
    ]);
    agg.total_visits = 4;
    const metrics = computeMetrics(agg);
    assert.equal(metrics.referral_rate, 25.0);
  });

  it('computes high risk rate correctly', () => {
    const visits = [
      ...Array(2).fill(null).map(() => visit({ risk_level: 'high' })),
      ...Array(8).fill(null).map(() => visit({ risk_level: 'low' })),
    ];
    const agg = buildAggregations(visits);
    const metrics = computeMetrics(agg);
    assert.equal(metrics.high_risk_rate, 20.0);
  });

  it('rates sum to approximately 100', () => {
    const visits = [
      ...Array(3).fill(null).map(() => visit({ risk_level: 'high' })),
      ...Array(3).fill(null).map(() => visit({ risk_level: 'medium' })),
      ...Array(4).fill(null).map(() => visit({ risk_level: 'low' })),
    ];
    const agg = buildAggregations(visits);
    const m = computeMetrics(agg);
    const sum = m.high_risk_rate + m.medium_risk_rate + m.low_risk_rate;
    assert.ok(Math.abs(sum - 100) < 0.1, `Rates sum to ${sum}, expected ~100`);
  });
});
