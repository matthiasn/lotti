import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/inference_http_exception.dart';

void main() {
  group('toString', () {
    test('names the provider, then status, message and cause', () {
      expect(
        const InferenceHttpException(
          'boom',
          provider: 'oMLX',
          statusCode: 503,
          originalError: 'socket closed',
        ).toString(),
        'InferenceHttpException(oMLX) (HTTP 503): boom: socket closed',
      );
    });

    test('leaves out a status or cause it does not have', () {
      expect(
        const InferenceHttpException('nope', provider: 'Gemini').toString(),
        'InferenceHttpException(Gemini): nope',
      );
      expect(
        const InferenceHttpException(
          'refused',
          provider: 'OpenAI',
          statusCode: 401,
        ).toString(),
        'InferenceHttpException(OpenAI) (HTTP 401): refused',
      );
    });
  });
}
