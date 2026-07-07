/// Vitals entry screen.
///
/// Health worker enters the three vital readings before recording.
/// Validation fires immediately on "Continue" — invalid readings
/// surface a clear message without crashing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sanjeevani_capture/core/config.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/ui/screens/recording_screen.dart';
import 'package:sanjeevani_capture/ui/theme.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  static const routeName = '/vitals';

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hrCtrl  = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _hrCtrl.dispose();
    _spo2Ctrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }

  void _onContinue() {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final hr   = double.tryParse(_hrCtrl.text.trim()) ?? 0;
    final spo2 = double.tryParse(_spo2Ctrl.text.trim()) ?? 0;
    final temp = double.tryParse(_tempCtrl.text.trim()) ?? 0;

    try {
      context.read<SessionProvider>().setVitals(
            heartRateBpm: hr,
            spo2Pct: spo2,
            temperatureF: temp,
          );
      Navigator.of(context).pushNamed(RecordingScreen.routeName);
    } on VitalBoundaryException catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter vitals')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Patient vitals',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Enter the three readings before recording symptoms.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),

                _VitalField(
                  controller: _hrCtrl,
                  label: 'Heart rate',
                  unit: 'bpm',
                  hint: 'e.g. 80',
                  min: VitalBounds.hrMin,
                  max: VitalBounds.hrMax,
                  icon: Icons.favorite_border_rounded,
                ),
                const SizedBox(height: 16),

                _VitalField(
                  controller: _spo2Ctrl,
                  label: 'SpO2',
                  unit: '%',
                  hint: 'e.g. 97',
                  min: VitalBounds.spo2Min,
                  max: VitalBounds.spo2Max,
                  icon: Icons.water_drop_outlined,
                ),
                const SizedBox(height: 16),

                _VitalField(
                  controller: _tempCtrl,
                  label: 'Temperature',
                  unit: '°F',
                  hint: 'e.g. 98.6',
                  min: VitalBounds.tempMinF,
                  max: VitalBounds.tempMaxF,
                  icon: Icons.thermostat_rounded,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _errorMessage!),
                ],

                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _onContinue,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Continue to recording'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Readings outside normal range will be flagged automatically.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VitalField extends StatelessWidget {
  const _VitalField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.hint,
    required this.min,
    required this.max,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final String hint;
  final double min;
  final double max;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        prefixIcon: Icon(icon, color: SanjeevaniTheme.primary, size: 22),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        final n = double.tryParse(val.trim());
        if (n == null) return 'Enter a valid number';
        if (n < min || n > max) {
          return 'Must be between $min and $max';
        }
        return null;
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SanjeevaniTheme.riskHighBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: SanjeevaniTheme.riskHigh.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: SanjeevaniTheme.riskHigh, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: SanjeevaniTheme.riskHigh,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}
