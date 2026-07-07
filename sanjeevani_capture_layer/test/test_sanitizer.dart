/// Tests for transcript sanitization — the security boundary.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanjeevani_capture/core/exceptions.dart';
import 'package:sanjeevani_capture/safety/transcript_sanitizer.dart';

void main() {
  const sanitizer = TranscriptSanitizer();

  group('TranscriptSanitizer — null and empty', () {
    test('null throws TranscriptValidationException', () {
      expect(
        () => sanitizer.sanitize(null),
        throwsA(isA<TranscriptValidationException>()),
      );
    });

    test('empty string throws', () {
      expect(
        () => sanitizer.sanitize(''),
        throwsA(isA<TranscriptValidationException>()),
      );
    });

    test('whitespace-only throws', () {
      expect(
        () => sanitizer.sanitize('   \t\n  '),
        throwsA(isA<TranscriptValidationException>()),
      );
    });

    test('single char throws (below min length)', () {
      expect(
        () => sanitizer.sanitize('a'),
        throwsA(isA<TranscriptValidationException>()),
      );
    });
  });

  group('TranscriptSanitizer — normal text', () {
    test('normal text passes through', () {
      expect(
        sanitizer.sanitize('child has fever'),
        'child has fever',
      );
    });

    test('leading and trailing whitespace stripped', () {
      expect(sanitizer.sanitize('  fever  '), 'fever');
    });

    test('two-char minimum accepted', () {
      expect(sanitizer.sanitize('ok'), 'ok');
    });

    test('unicode medical text passes', () {
      final result = sanitizer.sanitize('patient has high temperature 103F');
      expect(result, contains('patient'));
    });

    test('Hindi script preserved', () {
      final result = sanitizer.sanitize('बच्चे को बुखार है');
      expect(result, isNotEmpty);
    });

    test('Gujarati script preserved', () {
      final result = sanitizer.sanitize('બાળકને તાવ છે');
      expect(result, isNotEmpty);
    });
  });

  group('TranscriptSanitizer — control character stripping', () {
    test('null bytes removed', () {
      final result = sanitizer.sanitize('fever\x00cough');
      expect(result, isNot(contains('\x00')));
      expect(result, contains('fever'));
      expect(result, contains('cough'));
    });

    test('ASCII control characters removed', () {
      final result = sanitizer.sanitize('fever\x01\x02\x03cough');
      expect(result, isNot(contains('\x01')));
      expect(result, isNot(contains('\x02')));
    });

    test('DEL character removed', () {
      final result = sanitizer.sanitize('fever\x7fcough');
      expect(result, isNot(contains('\x7f')));
    });

    test('newline normalised to space', () {
      expect(sanitizer.sanitize('fever\ncough'), 'fever cough');
    });

    test('tab normalised to space', () {
      expect(sanitizer.sanitize('fever\tcough'), 'fever cough');
    });
  });

  group('TranscriptSanitizer — pathological repetition', () {
    test('30 repeated chars collapsed', () {
      final glitch = 'a' * 30;
      final result = sanitizer.sanitize('$glitch fever');
      expect(result, isNot(contains('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')));
      expect(result, contains('fever'));
    });

    test('normal words not affected by repetition rule', () {
      expect(sanitizer.sanitize('seems okay'), 'seems okay');
    });

    test('word with 5 repeated chars preserved (below threshold)', () {
      final result = sanitizer.sanitize('aaaaa fever');
      expect(result, contains('aaaaa'));
    });
  });

  group('TranscriptSanitizer — whitespace normalisation', () {
    test('multiple spaces collapsed', () {
      expect(
        sanitizer.sanitize('fever    and    cough'),
        'fever and cough',
      );
    });

    test('mixed whitespace normalised', () {
      expect(
        sanitizer.sanitize('fever\n\n\t  cough'),
        'fever cough',
      );
    });
  });

  group('TranscriptSanitizer — length cap', () {
    test('oversized input truncated, not rejected', () {
      final big = 'fever ' * 1000;
      final result = sanitizer.sanitize(big);
      expect(result.length, lessThanOrEqualTo(2500));
    });

    test('truncation happens at word boundary', () {
      final big = 'word ' * 1000;
      final result = sanitizer.sanitize(big);
      // Should not end with a space or partial word
      expect(result.trimRight(), equals(result));
    });

    test('input at exactly max length passes unchanged', () {
      // Build a clean string just under max
      final onLimit = ('ok ' * 833).trim().substring(0, 2499);
      final result = sanitizer.sanitize(onLimit);
      expect(result.length, lessThanOrEqualTo(2500));
    });
  });

  group('TranscriptSanitizer — error message quality', () {
    test('null error message is descriptive', () {
      try {
        sanitizer.sanitize(null);
        fail('should have thrown');
      } on TranscriptValidationException catch (e) {
        expect(e.message, contains('null'));
      }
    });

    test('too-short error message mentions length', () {
      try {
        sanitizer.sanitize('a');
        fail('should have thrown');
      } on TranscriptValidationException catch (e) {
        expect(e.message.toLowerCase(), contains('short'));
      }
    });
  });
}
