/**
 * Dashboard API client.
 *
 * Fetches aggregated statistics from the getDashboardStats
 * Cloud Function. Never fetches raw visit documents — those
 * are inaccessible to the dashboard by Firestore rules.
 *
 * Authentication: the PHC officer logs in with Firebase Auth
 * (email/password). The token is attached to every request.
 */

'use strict';

const BASE_URL = process.env.REACT_APP_FUNCTIONS_URL ||
  'https://us-central1-sanjeevani-prod.cloudfunctions.net';

/**
 * Fetch current aggregated dashboard statistics.
 * @param {string} idToken — Firebase ID token from the logged-in user
 * @returns {Promise<DashboardStats>}
 */
async function fetchDashboardStats(idToken) {
  const res = await fetch(`${BASE_URL}/getDashboardStats`, {
    method: 'POST',
    headers: {
      'Content-Type':  'application/json',
      'Authorization': `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data: {} }),
  });

  if (!res.ok) {
    throw new Error(`Stats fetch failed: HTTP ${res.status}`);
  }

  const json = await res.json();
  return json.result ?? json;
}

/**
 * @typedef {Object} DashboardStats
 * @property {number}  total_visits
 * @property {number}  referral_count
 * @property {{ low: number, medium: number, high: number }} by_risk
 * @property {{ '0-5': number, '6-18': number, '19-60': number, '60+': number }} by_age_bracket
 * @property {Object.<string, number>} daily_counts
 * @property {Object.<string, number>} village_activity
 */

module.exports = { fetchDashboardStats };
