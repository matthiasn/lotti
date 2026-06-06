import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';

void main() {
  group('TranscriptionException', () {
    test('carries all diagnostic fields', () {
      final original = StateError('socket closed');
      final exception = TranscriptionException(
        'transcription failed',
        provider: 'Mistral',
        statusCode: 503,
        originalError: original,
      );

      expect(exception, isA<Exception>());
      expect(exception.message, 'transcription failed');
      expect(exception.provider, 'Mistral');
      expect(exception.statusCode, 503);
      expect(exception.originalError, same(original));
    });

    test('optional fields default to null', () {
      final exception = TranscriptionException('boom');

      expect(exception.provider, isNull);
      expect(exception.statusCode, isNull);
      expect(exception.originalError, isNull);
    });

    test('toString names the provider and message', () {
      expect(
        TranscriptionException('rate limited', provider: 'OpenAI').toString(),
        'TranscriptionException(OpenAI): rate limited',
      );
      // Null provider is rendered verbatim — diagnostics only.
      expect(
        TranscriptionException('boom').toString(),
        'TranscriptionException(null): boom',
      );
    });
  });
}
