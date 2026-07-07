/// Tests for configuration — bounds ordering and limit sanity.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_capture/core/config.dart';

void main() {
  group('VitalBounds — ordering', () {
    test('HR min < HR max', () {
      expect(VitalBounds.hrMin, lessThan(VitalBounds.hrMax));
    });

    test('SpO2 min < SpO2 max', () {
      expect(VitalBounds.spo2Min, lessThan(VitalBounds.spo2Max));
    });

    test('SpO2 max is 100', () {
      expect(VitalBounds.spo2Max, 100.0);
    });

    test('temp min < temp max', () {
      expect(VitalBounds.tempMinF, lessThan(VitalBounds.tempMaxF));
    });

    test('normal body temp within bounds', () {
      const normal = 98.6;
      expect(normal, greaterThan(VitalBounds.tempMinF));
      expect(normal, lessThan(VitalBounds.tempMaxF));
    });
  });

  group('AudioConfig', () {
    test('sample rate is 16000 (Vosk requirement)', () {
      expect(AudioConfig.sampleRate, 16000);
    });

    test('channels is mono (Vosk requirement)', () {
      expect(AudioConfig.channels, 1);
    });

    test('max recording duration is positive', () {
      expect(AudioConfig.maxRecordingSeconds, greaterThan(0));
    });
  });

  group('SanitizationConfig', () {
    test('min < max transcript chars', () {
      expect(
        SanitizationConfig.minTranscriptChars,
        lessThan(SanitizationConfig.maxTranscriptChars),
      );
    });

    test('max transcript chars is reasonable (not too small)', () {
      expect(SanitizationConfig.maxTranscriptChars, greaterThan(100));
    });

    test('max char repeat threshold is positive', () {
      expect(SanitizationConfig.maxCharRepeat, greaterThan(0));
    });
  });

  group('IntelligenceConfig', () {
    test('default host is loopback', () {
      expect(IntelligenceConfig.host, '127.0.0.1');
    });

    test('timeout is positive', () {
      expect(IntelligenceConfig.timeout.inSeconds, greaterThan(0));
    });

    test('completion URI uses configured host and port', () {
      final uri = IntelligenceConfig.completionUri;
      expect(uri.host, IntelligenceConfig.host);
      expect(uri.port, IntelligenceConfig.port);
      expect(uri.path, '/completion');
    });

    test('health URI uses configured host and port', () {
      final uri = IntelligenceConfig.healthUri;
      expect(uri.path, '/health');
    });
  });

  group('AppLanguage', () {
    test('all languages have non-empty display name', () {
      for (final lang in AppLanguage.values) {
        expect(lang.displayName, isNotEmpty);
      }
    });

    test('all languages have non-empty code', () {
      for (final lang in AppLanguage.values) {
        expect(lang.code, isNotEmpty);
      }
    });

    test('Hindi has vosk model path', () {
      expect(AppLanguage.hindi.voskModelPath, isNotNull);
      expect(AppLanguage.hindi.voskModelPath, contains('vosk'));
    });

    test('Gujarati has vosk model path', () {
      expect(AppLanguage.gujarati.voskModelPath, isNotNull);
    });

    test('English has null vosk path — uses device STT', () {
      expect(AppLanguage.english.voskModelPath, isNull);
    });
  });

  group('SttConfig', () {
    test('confidence threshold is between 0 and 1', () {
      expect(SttConfig.minConfidence, greaterThan(0));
      expect(SttConfig.minConfidence, lessThan(1));
    });
  });
}
