/// Voice recording screen.
///
/// Large mic button, live waveform, live transcript preview.
/// Designed for one-handed use, bright outdoor light.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sanjeevani_capture/core/models.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/ui/screens/result_screen.dart';
import 'package:sanjeevani_capture/ui/theme.dart';

class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  static const routeName = '/recording';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF082E26), // dark green for recording mode
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Recording', style: TextStyle(color: Colors.white70)),
      ),
      body: SafeArea(
        child: Consumer<SessionProvider>(
          builder: (context, session, _) {
            // Auto-navigate to result when done
            if (session.state.recording == RecordingState.done &&
                session.state.recommendation != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacementNamed(
                  ResultScreen.routeName,
                );
              });
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _StatusLabel(session.state),
                  const SizedBox(height: 40),
                  _MicButton(session),
                  const SizedBox(height: 40),
                  _Waveform(amplitudeDb: session.state.amplitudeDb),
                  const SizedBox(height: 28),
                  if (session.state.transcript != null)
                    _TranscriptPreview(session.state.transcript!),
                  if (session.state.recording == RecordingState.error)
                    _RecordingErrorBanner(session.state.error ?? 'Unknown error'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Status label ──────────────────────────────────────────────────────────────

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.state);
  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final (label, sublabel) = switch (state.recording) {
      RecordingState.idle      => ('Ready', 'Tap the mic to start'),
      RecordingState.requesting => ('Requesting permission...', ''),
      RecordingState.recording => ('Listening...', 'Speak now in your language'),
      RecordingState.processing => ('Processing...', 'Please wait'),
      RecordingState.done      => ('Done', ''),
      RecordingState.error     => ('Error', state.error ?? ''),
    };
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600,
            )),
        if (sublabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sublabel,
              style: const TextStyle(color: Colors.white60, fontSize: 14)),
        ],
      ],
    );
  }
}

// ── Mic button with pulse animation ──────────────────────────────────────────

class _MicButton extends StatefulWidget {
  const _MicButton(this.session);
  final SessionProvider session;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.session.state;
    final isRecording = state.isRecording;
    final isProcessing = state.recording == RecordingState.processing;

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () {
              if (isRecording) {
                widget.session.stopAndAnalyse();
              } else {
                widget.session.startRecording();
              }
            },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final scale = isRecording
              ? 1.0 + _pulse.value * 0.08
              : 1.0;
          final outerOpacity = isRecording ? 0.15 + _pulse.value * 0.15 : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Transform.scale(
                scale: scale * 1.55,
                child: Opacity(
                  opacity: outerOpacity,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: SanjeevaniTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // Inner pulse ring
              Transform.scale(
                scale: scale * 1.25,
                child: Opacity(
                  opacity: isRecording ? 0.25 : 0.0,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: SanjeevaniTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // Main button
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: isRecording
                      ? const Color(0xFFD85A30)
                      : SanjeevaniTheme.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording
                              ? const Color(0xFFD85A30)
                              : SanjeevaniTheme.accent)
                          .withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: isProcessing
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3)
                    : Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: SanjeevaniTheme.primary,
                        size: 52,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Live waveform ─────────────────────────────────────────────────────────────

class _Waveform extends StatelessWidget {
  const _Waveform({required this.amplitudeDb});
  final double amplitudeDb;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: CustomPaint(
          painter: _WaveformPainter(amplitudeDb),
          size: const Size(double.infinity, 48),
        ),
      );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.amplitude);
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SanjeevaniTheme.accent.withOpacity(0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const barCount = 12;
    final barWidth = size.width / (barCount * 2);

    for (int i = 0; i < barCount; i++) {
      final x = (i * 2 + 1) * barWidth;
      final normalized = (math.sin(i * 0.8) * 0.5 + 0.5) * amplitude;
      final barHeight = 8.0 + normalized * (size.height - 16);
      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.amplitude != amplitude;
}

// ── Live transcript preview ───────────────────────────────────────────────────

class _TranscriptPreview extends StatelessWidget {
  const _TranscriptPreview(this.transcript);
  final TranscriptResult transcript;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A3F33),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live transcript (${transcript.engine.name}):',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              transcript.text.isEmpty ? '...' : transcript.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _RecordingErrorBanner extends StatelessWidget {
  const _RecordingErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SanjeevaniTheme.riskHighBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: SanjeevaniTheme.riskHigh, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: SanjeevaniTheme.riskHigh, fontSize: 13)),
            ),
          ],
        ),
      );
}
