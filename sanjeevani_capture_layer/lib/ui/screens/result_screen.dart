/// Clinical recommendation result screen.
///
/// Shows risk badge, vitals summary, AI recommendation, protocol sources,
/// referral action, and save-to-record button.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sanjeevani_capture/core/models.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/ui/theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  static const routeName = '/result';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final rec = session.state.recommendation;

    if (rec == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Check-up result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RiskBadge(rec),
              const SizedBox(height: 16),
              _VitalsSummary(session.state.vitals!),
              const SizedBox(height: 16),
              _RecommendationCard(rec),
              const SizedBox(height: 16),
              if (rec.sources.isNotEmpty) _SourcesCard(rec.sources),
              if (rec.isFallback)
                const _FallbackDisclaimer(),
              const SizedBox(height: 24),
              _ActionButtons(rec, session),
              const SizedBox(height: 12),
              const _Disclaimer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Risk badge ────────────────────────────────────────────────────────────────

class _RiskBadge extends StatelessWidget {
  const _RiskBadge(this.rec);
  final ClinicalRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (rec.riskLevel) {
      RiskLevel.high => (
          SanjeevaniTheme.riskHighBg,
          SanjeevaniTheme.riskHigh,
          Icons.error_outline_rounded,
          'High risk — see a doctor immediately',
        ),
      RiskLevel.medium => (
          SanjeevaniTheme.riskMedBg,
          SanjeevaniTheme.riskMedium,
          Icons.warning_amber_rounded,
          'Medium risk — monitor closely',
        ),
      RiskLevel.low => (
          SanjeevaniTheme.riskLowBg,
          SanjeevaniTheme.riskLow,
          Icons.check_circle_outline_rounded,
          'Low risk — continue routine care',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.riskLevel.displayName,
                  style: TextStyle(
                    color: fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(label,
                    style: TextStyle(color: fg, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: fg.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Score: ${rec.riskScore}',
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vitals summary ────────────────────────────────────────────────────────────

class _VitalsSummary extends StatelessWidget {
  const _VitalsSummary(this.vitals);
  final PatientVitals vitals;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VITALS RECORDED',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              _VitalChip(
                label: 'Heart rate',
                value: '${vitals.heartRateBpm.toStringAsFixed(0)} bpm',
                icon: Icons.favorite_border_rounded,
              ),
              const SizedBox(width: 10),
              _VitalChip(
                label: 'SpO2',
                value: '${vitals.spo2Pct.toStringAsFixed(0)}%',
                icon: Icons.water_drop_outlined,
              ),
              const SizedBox(width: 10),
              _VitalChip(
                label: 'Temp',
                value: '${vitals.temperatureF.toStringAsFixed(1)}°F',
                icon: Icons.thermostat_rounded,
              ),
            ],
          ),
        ],
      );
}

class _VitalChip extends StatelessWidget {
  const _VitalChip({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SanjeevaniTheme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: SanjeevaniTheme.border, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: SanjeevaniTheme.primary, size: 18),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SanjeevaniTheme.textPrimary,
                  )),
            ],
          ),
        ),
      );
}

// ── Recommendation card ───────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(this.rec);
  final ClinicalRecommendation rec;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI RECOMMENDATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: SanjeevaniTheme.primary,
                      )),
              const SizedBox(height: 12),
              Text('Possible condition:',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(rec.condition,
                  style: Theme.of(context).textTheme.titleMedium),
              const Divider(height: 24, thickness: 0.5),
              Text('Advice:',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(rec.advice,
                  style: Theme.of(context).textTheme.bodyLarge),
              if (rec.alerts.isNotEmpty) ...[
                const Divider(height: 24, thickness: 0.5),
                Text('Alerts detected:',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                ...rec.alerts.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 6, color: SanjeevaniTheme.riskHigh),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(a,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      );
}

// ── Protocol sources ──────────────────────────────────────────────────────────

class _SourcesCard extends StatelessWidget {
  const _SourcesCard(this.sources);
  final List<KnowledgePassage> sources;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BASED ON VERIFIED PROTOCOLS',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 10),
              ...sources.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SanjeevaniTheme.riskLowBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined,
                              size: 14, color: SanjeevaniTheme.riskLow),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.sourceRef,
                              style: const TextStyle(
                                color: SanjeevaniTheme.riskLow,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${(s.similarity * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: SanjeevaniTheme.riskLow,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      );
}

// ── Fallback disclaimer ───────────────────────────────────────────────────────

class _FallbackDisclaimer extends StatelessWidget {
  const _FallbackDisclaimer();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SanjeevaniTheme.riskMedBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: SanjeevaniTheme.riskMedium, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI analysis was unavailable — this recommendation '
                'was generated from the rule-based risk score only.',
                style: TextStyle(
                    color: SanjeevaniTheme.riskMedium, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons(this.rec, this.session);
  final ClinicalRecommendation rec;
  final SessionProvider session;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (rec.referralNeeded)
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: SanjeevaniTheme.riskHigh,
              ),
              icon: const Icon(Icons.local_hospital_rounded),
              label: const Text('Refer to health facility'),
            ),
          if (rec.referralNeeded) const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save to patient record'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              session.reset();
              Navigator.of(context).popUntil(
                  ModalRoute.withName('/home'));
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('New check-up'),
          ),
        ],
      );
}

// ── Bottom disclaimer ─────────────────────────────────────────────────────────

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) => Text(
        'This is clinical decision support, not a diagnosis. '
        'Always refer to a qualified health worker when in doubt.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      );
}
