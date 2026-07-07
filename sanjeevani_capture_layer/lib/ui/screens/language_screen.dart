/// Language selection screen — first launch.
///
/// Shows three large, accessible language buttons.
/// Stores the selection and navigates to the home screen.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/ui/screens/home_screen.dart';
import 'package:sanjeevani_capture/ui/theme.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  static const routeName = '/language';

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: SanjeevaniTheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Sanjeevani',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text('Health support, anywhere',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 48),

              Text('Choose your language',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),

              // Language buttons
              ...AppLanguage.values.map((lang) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LanguageButton(
                      language: lang,
                      onTap: () {
                        session.setLanguage(lang);
                        Navigator.of(context).pushReplacementNamed(
                          HomeScreen.routeName,
                        );
                      },
                    ),
                  )),

              const Spacer(),

              // Offline badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: SanjeevaniTheme.riskLowBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 16, color: SanjeevaniTheme.riskLow),
                    const SizedBox(width: 6),
                    Text(
                      'Works fully offline — no internet needed',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SanjeevaniTheme.riskLow,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.language, required this.onTap});
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFirst = language == AppLanguage.hindi;
    return SizedBox(
      width: double.infinity,
      height: SanjeevaniTheme.minTapTarget,
      child: isFirst
          ? ElevatedButton(
              onPressed: onTap,
              child: Text(language.displayName),
            )
          : OutlinedButton(
              onPressed: onTap,
              child: Text(language.displayName),
            ),
    );
  }
}
