import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';

void main() {
  group('extractThoughtSignature helper', () {
    test('extracts signature from part level (sibling of functionCall)', () {
      final part = <String, dynamic>{
        'functionCall': {'name': 'test_func', 'args': <String, dynamic>{}},
        'thoughtSignature': 'encrypted-sig-12345',
      };
      expect(extractThoughtSignature(part), 'encrypted-sig-12345');
    });

    test('returns null when no signature present', () {
      final part = <String, dynamic>{
        'functionCall': {'name': 'test_func', 'args': <String, dynamic>{}},
      };
      expect(extractThoughtSignature(part), isNull);
    });

    test(
      'returns null when signature is inside functionCall (wrong location)',
      () {
        // This tests that we correctly look at part level, not inside functionCall
        final part = <String, dynamic>{
          'functionCall': {
            'name': 'test_func',
            'args': <String, dynamic>{},
            'thoughtSignature': 'wrong-location-sig',
          },
        };
        expect(extractThoughtSignature(part), isNull);
      },
    );

    test('handles non-string signature values by converting to string', () {
      final part = <String, dynamic>{
        'functionCall': {'name': 'test_func', 'args': <String, dynamic>{}},
        'thoughtSignature': 12345, // numeric value
      };
      expect(extractThoughtSignature(part), '12345');
    });
  });

  group('GeneratedImage', () {
    test('maps known MIME types to extensions and defaults to png', () {
      const bytes = [1, 2, 3];
      expect(
        const GeneratedImage(bytes: bytes, mimeType: 'image/jpeg').extension,
        'jpg',
      );
      expect(
        const GeneratedImage(bytes: bytes, mimeType: 'image/gif').extension,
        'gif',
      );
      expect(
        const GeneratedImage(bytes: bytes, mimeType: 'image/webp').extension,
        'webp',
      );
      expect(
        const GeneratedImage(bytes: bytes, mimeType: 'image/png').extension,
        'png',
      );
      expect(
        const GeneratedImage(
          bytes: bytes,
          mimeType: 'application/pdf',
        ).extension,
        'png',
      );
    });
  });
}
