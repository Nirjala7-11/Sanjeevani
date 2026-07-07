/**
 * Visit summary schema validation.
 *
 * This runs server-side in Cloud Functions as a second line of defence
 * after Firestore Rules. Belt-and-suspenders approach — if a malformed
 * document somehow passes Rules, it is caught here before aggregation.
 *
 * Privacy enforcement:
 *   - The validator explicitly checks for forbidden PII fields and
 *     rejects any document that contains them.
 *   - This means even if the client app were compromised and tried to
 *     write patient names, the Cloud Function would reject the document
 *     before it touched any aggregation.
 */

'use strict';

const REQUIRED_FIELDS = [
  'visit_date', 'risk_level', 'referral_needed',
  'age_bracket', 'village_hash', 'gender', 'asha_id', 'synced_at',
];

const FORBIDDEN_PII_FIELDS = [
  'name', 'patient_name', 'phone', 'phone_number',
  'transcript', 'exact_age', 'village', 'address',
];

const VALID_RISK_LEVELS  = ['low', 'medium', 'high'];
const VALID_AGE_BRACKETS = ['0-5', '6-18', '19-60', '60+'];
const VALID_GENDERS      = ['male', 'female', 'other'];
const DATE_RE            = /^\d{4}-\d{2}-\d{2}$/;
const HEX8_RE            = /^[0-9a-f]{8}$/;

/**
 * Validate a visit summary document.
 * @param {Object} data — Firestore document data
 * @returns {{ valid: boolean, errors: string[] }}
 */
function validateVisitSummary(data) {
  const errors = [];

  // Required fields
  for (const field of REQUIRED_FIELDS) {
    if (data[field] === undefined || data[field] === null) {
      errors.push(`Missing required field: ${field}`);
    }
  }

  // Forbidden PII fields — hard reject
  for (const field of FORBIDDEN_PII_FIELDS) {
    if (data[field] !== undefined) {
      errors.push(`PRIVACY VIOLATION: forbidden field present: ${field}`);
    }
  }

  // Type and value checks (only if field present)
  if (data.risk_level && !VALID_RISK_LEVELS.includes(data.risk_level)) {
    errors.push(`Invalid risk_level: ${data.risk_level}`);
  }
  if (data.age_bracket && !VALID_AGE_BRACKETS.includes(data.age_bracket)) {
    errors.push(`Invalid age_bracket: ${data.age_bracket}`);
  }
  if (data.gender && !VALID_GENDERS.includes(data.gender)) {
    errors.push(`Invalid gender: ${data.gender}`);
  }
  if (data.referral_needed !== undefined && typeof data.referral_needed !== 'boolean') {
    errors.push('referral_needed must be a boolean');
  }
  if (data.visit_date && !DATE_RE.test(data.visit_date)) {
    errors.push(`visit_date must be YYYY-MM-DD, got: ${data.visit_date}`);
  }
  if (data.village_hash && !HEX8_RE.test(data.village_hash)) {
    errors.push(`village_hash must be 8 lowercase hex chars, got: ${data.village_hash}`);
  }

  return { valid: errors.length === 0, errors };
}

module.exports = { validateVisitSummary };
