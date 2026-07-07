/// App entry point.
///
/// Wires all services together and builds the Provider tree.
/// Nothing in this file contains business logic — it is pure
/// dependency injection and routing.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sanjeevani_capture/audio/audio_recorder.dart';
import 'package:sanjeevani_capture/audio/permission_service.dart';
import 'package:sanjeevani_capture/core/session_provider.dart';
import 'package:sanjeevani_capture/intelligence/intelligence_client.dart';
import 'package:sanjeevani_capture/safety/transcript_sanitizer.dart';
import 'package:sanjeevani_capture/stt/stt_coordinator.dart';
import 'package:sanjeevani_capture/stt/vosk_engine.dart';
import 'package:sanjeevani_capture/stt/whisper_engine.dart';
import 'package:sanjeevani_capture/ui/screens/home_screen.dart';
import 'package:sanjeevani_capture/ui/screens/language_screen.dart';
import 'package:sanjeevani_capture/ui/screens/recording_screen.dart';
import 'package:sanjeevani_capture/ui/screens/result_screen.dart';
import 'package:sanjeevani_capture/ui/screens/vitals_screen.dart';
import 'package:sanjeevani_capture/ui/theme.dart';
import 'package:sanjeevani_capture/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();
  runApp(const SanjeevaniApp());
}

class SanjeevaniApp extends StatelessWidget {
  const SanjeevaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionProvider>(
      create: (_) => _buildSessionProvider(),
      child: MaterialApp(
        title: 'Sanjeevani',
        theme: SanjeevaniTheme.theme,
        debugShowCheckedModeBanner: false,
        initialRoute: LanguageScreen.routeName,
        routes: {
          LanguageScreen.routeName:  (_) => const LanguageScreen(),
          HomeScreen.routeName:      (_) => const HomeScreen(),
          VitalsScreen.routeName:    (_) => const VitalsScreen(),
          RecordingScreen.routeName: (_) => const RecordingScreen(),
          ResultScreen.routeName:    (_) => const ResultScreen(),
        },
      ),
    );
  }

  /// Construct all services and inject into [SessionProvider].
  ///
  /// This is the only place in the app where concrete implementations
  /// are instantiated. Tests replace these with mocks via the
  /// [SessionProvider] constructor — nothing needs to be changed in
  /// business logic to switch implementations.
  SessionProvider _buildSessionProvider() {
    final permissions   = PermissionService();
    final recorder      = AudioRecorder(permissions);

    final hindiEngine    = VoskEngine(
      modelPath: 'assets/models/vosk-model-small-hi-0.22',
      languageCode: 'hi',
    );
    final gujaratiEngine = VoskEngine(
      modelPath: 'assets/models/vosk-model-small-gu-0.42',
      languageCode: 'gu',
    );
    final whisperEngine  = WhisperEngine();

    final coordinator   = SttCoordinator(
      hindiEngine: hindiEngine,
      gujaratiEngine: gujaratiEngine,
      fallbackEngine: whisperEngine,
    );

    final sanitizer     = const TranscriptSanitizer();
    final client        = IntelligenceClient(); // defaults to 127.0.0.1:8080

    return SessionProvider(
      audioRecorder:      recorder,
      sttCoordinator:     coordinator,
      sanitizer:          sanitizer,
      intelligenceClient: client,
    );
  }
}
