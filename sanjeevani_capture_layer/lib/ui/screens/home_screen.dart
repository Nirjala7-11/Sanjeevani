/// Home dashboard screen.
///
/// Primary action: "Start new check-up" → navigates to VitalsScreen.
/// Secondary: patient records, today's visits, overdue reminders.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/ui/screens/vitals_screen.dart';
import 'package:sanjeevani_capture/ui/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const _OfflineBadge(),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {}, // Settings navigation placeholder
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Greeting(),
              const SizedBox(height: 24),
              const _PrimaryActionCard(),
              const SizedBox(height: 16),
              const _SecondaryActions(),
              const SizedBox(height: 16),
              const _OverdueVisitsBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              color: SanjeevaniTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('Offline mode',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}

class _Greeting extends StatelessWidget {
  const _Greeting();
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, Asha Didi 👋',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('What would you like to do today?',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Navigator.of(context).pushNamed(VitalsScreen.routeName),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SanjeevaniTheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: SanjeevaniTheme.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.mic_rounded,
                  color: SanjeevaniTheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start new check-up',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Speak symptoms aloud',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Works without internet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryCard(
            icon: Icons.folder_shared_outlined,
            label: 'Patient records',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SecondaryCard(
            icon: Icons.calendar_today_outlined,
            label: "Today's visits",
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _SecondaryCard extends StatelessWidget {
  const _SecondaryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: SanjeevaniTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: SanjeevaniTheme.primary, size: 22),
                ),
                const SizedBox(height: 10),
                Text(label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: SanjeevaniTheme.textPrimary,
                        )),
              ],
            ),
          ),
        ),
      );
}

class _OverdueVisitsBanner extends StatelessWidget {
  const _OverdueVisitsBanner();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SanjeevaniTheme.riskHighBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SanjeevaniTheme.riskHigh.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                color: SanjeevaniTheme.riskHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.priority_high_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3 visits due today',
                    style: TextStyle(
                      color: SanjeevaniTheme.riskHigh,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Tap to view the list',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SanjeevaniTheme.riskHigh,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: SanjeevaniTheme.riskHigh, size: 16),
          ],
        ),
      );
}
