/**
 * Unit tests for the visit summary validator.
 * No Firebase emulator or admin SDK required — pure JS logic.
 */

'use strict';

const { validateVisitSummary } = require('../src/validator');
const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

function validDoc(overrides = {}) {
  return {
    visit_date:      '2026-07-01',
    risk_level:      'high',
    referral_needed: true,
    age_bracket:     '19-60',
    village_hash:    'a1b2c3d4',
    gender:          'female',
    asha_id:         'asha_123',
    synced_at:       '2026-07-01T12:00:00Z',
    ...overrides,
  };
}

describe('validateVisitSummary', () => {

  describe('valid documents', () => {
    it('accepts a fully valid document', () => {
      const { valid } = validateVisitSummary(validDoc());
      assert.equal(valid, true);
    });

    it('accepts all risk levels', () => {
      for (const level of ['low', 'medium', 'high']) {
        const { valid } = validateVisitSummary(validDoc({ risk_level: level }));
        assert.equal(valid, true, `Failed for risk_level=${level}`);
      }
    });

    it('accepts all age brackets', () => {
      for (const ab of ['0-5', '6-18', '19-60', '60+']) {
        const { valid } = validateVisitSummary(validDoc({ age_bracket: ab }));
        assert.equal(valid, true, `Failed for age_bracket=${ab}`);
      }
    });

    it('accepts referral_needed=false', () => {
      const { valid } = validateVisitSummary(validDoc({ referral_needed: false }));
      assert.equal(valid, true);
    });
  });

  describe('missing required fields', () => {
    for (const field of [
      'visit_date', 'risk_level', 'referral_needed',
      'age_bracket', 'village_hash', 'gender', 'asha_id', 'synced_at',
    ]) {
      it(`rejects document missing ${field}`, () => {
        const doc = validDoc();
        delete doc[field];
        const { valid, errors } = validateVisitSummary(doc);
        assert.equal(valid, false);
        assert.ok(errors.some(e => e.includes(field)));
      });
    }
  });

  describe('PII field rejection — privacy contract', () => {
    const piiFields = [
      ['name',         'Seema Devi'],
      ['patient_name', 'Seema Devi'],
      ['phone',        '9876543210'],
      ['phone_number', '9876543210'],
      ['transcript',   'child has fever'],
      ['exact_age',    28],
      ['village',      'Sundarpur'],
      ['address',      '123 Main St'],
    ];

    for (const [field, value] of piiFields) {
      it(`rejects document containing PII field: ${field}`, () => {
        const { valid, errors } = validateVisitSummary(validDoc({ [field]: value }));
        assert.equal(valid, false, `PII field ${field} should have been rejected`);
        assert.ok(
          errors.some(e => e.includes('PRIVACY VIOLATION') && e.includes(field)),
          `Expected PRIVACY VIOLATION error for field ${field}`,
        );
      });
    }
  });

  describe('invalid field values', () => {
    it('rejects unknown risk_level', () => {
      const { valid } = validateVisitSummary(validDoc({ risk_level: 'CRITICAL' }));
      assert.equal(valid, false);
    });

    it('rejects unknown age_bracket', () => {
      const { valid } = validateVisitSummary(validDoc({ age_bracket: '21-25' }));
      assert.equal(valid, false);
    });

    it('rejects referral_needed as string', () => {
      const { valid } = validateVisitSummary(validDoc({ referral_needed: 'yes' }));
      assert.equal(valid, false);
    });

    it('rejects visit_date with time component', () => {
      const { valid } = validateVisitSummary(
        validDoc({ visit_date: '2026-07-01T10:30:00' }),
      );
      assert.equal(valid, false);
    });

    it('rejects visit_date wrong format', () => {
      const { valid } = validateVisitSummary(
        validDoc({ visit_date: '01/07/2026' }),
      );
      assert.equal(valid, false);
    });

    it('rejects village_hash not 8 chars', () => {
      const { valid } = validateVisitSummary(
        validDoc({ village_hash: 'short' }),
      );
      assert.equal(valid, false);
    });

    it('rejects village_hash with uppercase hex', () => {
      const { valid } = validateVisitSummary(
        validDoc({ village_hash: 'A1B2C3D4' }),
      );
      assert.equal(valid, false);
    });

    it('rejects village_hash with non-hex chars', () => {
      const { valid } = validateVisitSummary(
        validDoc({ village_hash: 'zzzzzzzz' }),
      );
      assert.equal(valid, false);
    });
  });
});
