/// Security tests — loopback enforcement, exception hierarchy.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/intelligence/intelligence_client.dart';

void main() {
  group('IntelligenceClient — loopback enforcement', () {
    test('127.0.0.1 accepted', () {
      expect(
        () => IntelligenceClient(host: '127.0.0.1'),
        returnsNormally,
      );
    });

    test('localhost accepted', () {
      expect(
        () => IntelligenceClient(host: 'localhost'),
        returnsNormally,
      );
    });

    test('::1 (IPv6 loopback) accepted', () {
      expect(
        () => IntelligenceClient(host: '::1'),
        returnsNormally,
      );
    });

    test('public IP rejected with IntelligenceLayerException', () {
      expect(
        () => IntelligenceClient(host: '8.8.8.8'),
        throwsA(isA<IntelligenceLayerException>()),
      );
    });

    test('private LAN IP rejected', () {
      expect(
        () => IntelligenceClient(host: '192.168.1.100'),
        throwsA(isA<IntelligenceLayerException>()),
      );
    });

    test('10.x.x.x range rejected', () {
      expect(
        () => IntelligenceClient(host: '10.0.0.1'),
        throwsA(isA<IntelligenceLayerException>()),
      );
    });

    test('0.0.0.0 rejected', () {
      expect(
        () => IntelligenceClient(host: '0.0.0.0'),
        throwsA(isA<IntelligenceLayerException>()),
      );
    });

    test('arbitrary hostname rejected', () {
      expect(
        () => IntelligenceClient(host: 'model-server.example.com'),
        throwsA(isA<IntelligenceLayerException>()),
      );
    });

    test('Gradio live endpoint rejected', () {
      expect(
        () => IntelligenceClient(host: 'gradio.live'),
        throwsA(isA<IntelligenceLayerException>()),
      );
    });

    test('rejection error message mentions SECURITY VIOLATION', () {
      try {
        IntelligenceClient(host: '1.2.3.4');
        fail('should have thrown');
      } on IntelligenceLayerException catch (e) {
        expect(e.message, contains('SECURITY VIOLATION'));
      }
    });

    test('rejection error message contains the bad host', () {
      try {
        IntelligenceClient(host: '1.2.3.4');
        fail('should have thrown');
      } on IntelligenceLayerException catch (e) {
        expect(e.message, contains('1.2.3.4'));
      }
    });
  });

  group('Exception hierarchy', () {
    test('MicrophonePermissionException is SanjeevaniCaptureException', () {
      expect(
        const MicrophonePermissionException(),
        isA<SanjeevaniCaptureException>(),
      );
    });

    test('AudioCaptureException is SanjeevaniCaptureException', () {
      expect(
        const AudioCaptureException('test'),
        isA<SanjeevaniCaptureException>(),
      );
    });

    test('SpeechRecognitionException is SanjeevaniCaptureException', () {
      expect(
        const SpeechRecognitionException('test'),
        isA<SanjeevaniCaptureException>(),
      );
    });

    test('TranscriptValidationException is SanjeevaniCaptureException', () {
      expect(
        const TranscriptValidationException('test'),
        isA<SanjeevaniCaptureException>(),
      );
    });

    test('VitalBoundaryException is SanjeevaniCaptureException', () {
      expect(
        const VitalBoundaryException('test'),
        isA<SanjeevaniCaptureException>(),
      );
    });

    test('IntelligenceLayerException is SanjeevaniCaptureException', () {
      expect(
        const IntelligenceLayerException('test'),
        isA<SanjeevaniCaptureException>(),
      );
    });

    test('catch all exceptions via base type', () {
      final exceptions = [
        const MicrophonePermissionException(),
        const AudioCaptureException('x'),
        const SpeechRecognitionException('x'),
        const TranscriptValidationException('x'),
        const VitalBoundaryException('x'),
        const IntelligenceLayerException('x'),
      ];
      for (final e in exceptions) {
        try {
          throw e;
        } on SanjeevaniCaptureException {
          // expected
        }
      }
    });

    test('cause is preserved in toString', () {
      final e = AudioCaptureException('failed', cause: Exception('root'));
      expect(e.toString(), contains('root'));
    });
  });
}
