/**
 * PHC Dashboard — main component.
 *
 * Displays aggregated health statistics from the Sanjeevani sync backend.
 * Read-only — the dashboard never writes to any collection.
 *
 * What is shown:
 *   - Total visits in the current period
 *   - Referral rate (% of visits resulting in a referral)
 *   - High-risk rate
 *   - Active village count (by hash — names never shown)
 *   - Daily visit trend (line chart, last 14 days)
 *   - Risk level distribution (donut chart)
 *   - Age bracket distribution (bar chart)
 *   - Top active villages (opaque hash + count — no names)
 *
 * Privacy: no patient names, no transcripts, no exact ages are ever
 * fetched or displayed. This component only ever sees aggregated counts.
 */

import React, { useEffect, useState, useCallback } from 'react';
import {
  Chart as ChartJS,
  ArcElement, LineElement, BarElement,
  CategoryScale, LinearScale, PointElement,
  Title, Tooltip, Legend, Filler,
} from 'chart.js';
import { Doughnut, Line, Bar } from 'react-chartjs-2';
import {
  riskDonutData, dailyTrendData,
  ageBracketData, topVillageActivity, summaryKpis,
} from '../utils/chartHelpers';

ChartJS.register(
  ArcElement, LineElement, BarElement,
  CategoryScale, LinearScale, PointElement,
  Title, Tooltip, Legend, Filler,
);

// ── Theme constants ───────────────────────────────────────────────────────────
const PRIMARY   = '#085041';
const ACCENT    = '#5DCAA5';
const SURFACE   = '#F7F5EF';
const CARD_BG   = '#FFFFFF';
const BORDER    = '#D3D1C7';
const TEXT      = '#2C2C2A';
const TEXT_SEC  = '#5F5E5A';
const RISK_HIGH = '#791F1F';
const RISK_MED  = '#633806';

const styles = {
  page: {
    fontFamily: 'system-ui, -apple-system, sans-serif',
    background: SURFACE,
    minHeight: '100vh',
    padding: '24px',
    color: TEXT,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: '24px',
  },
  title: { fontSize: '22px', fontWeight: 600, color: PRIMARY, margin: 0 },
  subtitle: { fontSize: '13px', color: TEXT_SEC, marginTop: '4px' },
  refreshBtn: {
    background: PRIMARY,
    color: '#fff',
    border: 'none',
    borderRadius: '8px',
    padding: '8px 16px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: 500,
  },
  kpiGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
    gap: '14px',
    marginBottom: '24px',
  },
  kpiCard: {
    background: CARD_BG,
    border: `0.5px solid ${BORDER}`,
    borderRadius: '12px',
    padding: '16px',
    textAlign: 'center',
  },
  kpiValue: { fontSize: '28px', fontWeight: 700, color: PRIMARY, lineHeight: 1 },
  kpiLabel: { fontSize: '11px', color: TEXT_SEC, marginTop: '6px', textTransform: 'uppercase', letterSpacing: '0.05em' },
  chartGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
    gap: '16px',
    marginBottom: '24px',
  },
  chartCard: {
    background: CARD_BG,
    border: `0.5px solid ${BORDER}`,
    borderRadius: '12px',
    padding: '20px',
  },
  chartTitle: { fontSize: '13px', fontWeight: 600, color: TEXT, marginBottom: '16px' },
  table: { width: '100%', borderCollapse: 'collapse', fontSize: '13px' },
  th: { textAlign: 'left', padding: '8px 12px', borderBottom: `1px solid ${BORDER}`, color: TEXT_SEC, fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.04em' },
  td: { padding: '8px 12px', borderBottom: `0.5px solid ${BORDER}` },
  badge: { display: 'inline-block', padding: '2px 8px', borderRadius: '10px', fontSize: '11px', fontWeight: 500 },
  offlineBadge: { background: '#E1F5EE', color: PRIMARY, padding: '4px 12px', borderRadius: '20px', fontSize: '12px' },
  errorBox: { background: '#FCEBEB', border: `1px solid ${RISK_HIGH}`, borderRadius: '10px', padding: '16px', color: RISK_HIGH },
  loading: { textAlign: 'center', padding: '60px', color: TEXT_SEC },
  disclaimer: { fontSize: '11px', color: TEXT_SEC, textAlign: 'center', marginTop: '24px', fontStyle: 'italic' },
};

const CHART_OPTIONS = {
  responsive: true,
  maintainAspectRatio: true,
  plugins: { legend: { position: 'bottom' }, tooltip: { enabled: true } },
};

// ── Main component ────────────────────────────────────────────────────────────

export default function Dashboard({ idToken }) {
  const [stats, setStats]     = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState(null);
  const [lastRefresh, setLastRefresh] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      // In production: const data = await fetchDashboardStats(idToken);
      // For demo/development, use mock data that matches the real schema:
      const data = MOCK_STATS;
      setStats(data);
      setLastRefresh(new Date());
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [idToken]);

  useEffect(() => { load(); }, [load]);

  if (loading) return <div style={styles.loading}>Loading dashboard...</div>;
  if (error)   return <div style={styles.page}><ErrorBox message={error} onRetry={load} /></div>;
  if (!stats)  return null;

  const kpis    = summaryKpis(stats);
  const donut   = riskDonutData(stats.by_risk);
  const trend   = dailyTrendData(stats.daily_counts);
  const ageBars = ageBracketData(stats.by_age_bracket);
  const villages = topVillageActivity(stats.village_activity);

  return (
    <div style={styles.page}>
      <header style={styles.header}>
        <div>
          <h1 style={styles.title}>Sanjeevani — PHC Dashboard</h1>
          <p style={styles.subtitle}>
            Aggregated health data · No patient names shown ·{' '}
            {lastRefresh && `Last updated ${lastRefresh.toLocaleTimeString('en-IN')}`}
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <span style={styles.offlineBadge}>📊 Read-only view</span>
          <button style={styles.refreshBtn} onClick={load}>↻ Refresh</button>
        </div>
      </header>

      {/* KPI row */}
      <div style={styles.kpiGrid}>
        <KpiCard value={kpis.totalVisits}    label="Total visits"      />
        <KpiCard value={`${kpis.referralRate}%`}  label="Referral rate"  color={kpis.referralRate > 30 ? RISK_MED : PRIMARY} />
        <KpiCard value={`${kpis.highRiskRate}%`}  label="High-risk rate" color={kpis.highRiskRate > 20 ? RISK_HIGH : PRIMARY} />
        <KpiCard value={kpis.activeVillages}  label="Active villages"   />
        <KpiCard value={stats.referral_count} label="Total referrals"   />
      </div>

      {/* Charts row */}
      <div style={styles.chartGrid}>
        <div style={styles.chartCard}>
          <p style={styles.chartTitle}>Risk level distribution</p>
          <Doughnut data={donut} options={CHART_OPTIONS} />
        </div>
        <div style={styles.chartCard}>
          <p style={styles.chartTitle}>Daily visit trend (last 14 days)</p>
          <Line data={trend} options={CHART_OPTIONS} />
        </div>
        <div style={styles.chartCard}>
          <p style={styles.chartTitle}>Visits by age bracket</p>
          <Bar data={ageBars} options={CHART_OPTIONS} />
        </div>
      </div>

      {/* Village activity table */}
      <div style={styles.chartCard}>
        <p style={styles.chartTitle}>Top active villages (by anonymous hash)</p>
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Rank</th>
              <th style={styles.th}>Village ID (hashed)</th>
              <th style={styles.th}>Visits</th>
            </tr>
          </thead>
          <tbody>
            {villages.map(v => (
              <tr key={v.hash}>
                <td style={styles.td}>#{v.rank}</td>
                <td style={styles.td}>
                  <code style={{ fontFamily: 'monospace', color: TEXT_SEC }}>{v.hash}</code>
                </td>
                <td style={styles.td}>{v.count}</td>
              </tr>
            ))}
            {villages.length === 0 && (
              <tr>
                <td colSpan={3} style={{ ...styles.td, textAlign: 'center', color: TEXT_SEC }}>
                  No village data yet
                </td>
              </tr>
            )}
          </tbody>
        </table>
        <p style={{ fontSize: '11px', color: TEXT_SEC, marginTop: '10px' }}>
          Village names are hashed before leaving the device — this table
          shows activity patterns without identifying specific villages.
        </p>
      </div>

      <p style={styles.disclaimer}>
        This dashboard displays aggregated, anonymized data only.
        No patient names, ages, or identifying information are shown or stored.
        Data is collected from ASHA workers' Sanjeevani devices via background sync.
      </p>
    </div>
  );
}

// ── Sub-components ────────────────────────────────────────────────────────────

function KpiCard({ value, label, color = PRIMARY }) {
  return (
    <div style={styles.kpiCard}>
      <div style={{ ...styles.kpiValue, color }}>{value}</div>
      <div style={styles.kpiLabel}>{label}</div>
    </div>
  );
}

function ErrorBox({ message, onRetry }) {
  return (
    <div style={styles.errorBox}>
      <strong>Could not load dashboard</strong>
      <p style={{ marginTop: '8px', fontSize: '13px' }}>{message}</p>
      <button
        style={{ ...styles.refreshBtn, background: RISK_HIGH, marginTop: '12px' }}
        onClick={onRetry}
      >
        Try again
      </button>
    </div>
  );
}

// ── Mock data for development / demo ─────────────────────────────────────────
// Replace with real fetchDashboardStats() call for production.

const MOCK_STATS = {
  total_visits:   247,
  referral_count: 61,
  by_risk: { low: 142, medium: 68, high: 37 },
  by_age_bracket: { '0-5': 89, '6-18': 34, '19-60': 98, '60+': 26 },
  daily_counts: {
    '2026-06-24': 14, '2026-06-25': 18, '2026-06-26': 21,
    '2026-06-27': 16, '2026-06-28': 23, '2026-06-29': 19,
    '2026-06-30': 17, '2026-07-01': 22, '2026-07-02': 25,
    '2026-07-03': 20, '2026-07-04': 18, '2026-07-05': 24,
    '2026-07-06': 15, '2026-07-07': 12,
  },
  village_activity: {
    'a1b2c3d4': 34, 'deadbeef': 28, 'cafe0001': 22,
    'f00dface': 19, 'badc0ded': 17, 'b00bface': 14,
    'feedbabe': 13, '8badf00d': 11, 'deaddad0': 9, 'facefeed': 8,
  },
};
