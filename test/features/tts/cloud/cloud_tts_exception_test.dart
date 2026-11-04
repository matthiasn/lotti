import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/cloud/cloud_tts_exception.dart';

void main() {
  group('toString', () {
    test('names the failure and the status, and no secrets', () {
      const error = CloudTtsException(
        CloudTtsFailure.rejected,
        'Request rejected by the Mistral API',
        statusCode: 422,
      );
      expect(
        error.toString(),
        'CloudTtsException(rejected, HTTP 422): '
        'Request rejected by the Mistral API',
      );
    });

    test('leaves out a status it does not have', () {
      expect(
        const CloudTtsException(CloudTtsFailure.timeout, 'x').toString(),
        'CloudTtsException(timeout): x',
      );
    });

    test("appends the server's reason and its request id", () {
      expect(
        const CloudTtsException(
          CloudTtsFailure.unauthorized,
          'The ElevenLabs API key was rejected',
          statusCode: 401,
          apiError: 'quota exceeded',
          requestId: 'r1',
        ).toString(),
        'CloudTtsException(unauthorized, HTTP 401): The ElevenLabs API key '
        'was rejected — server: quota exceeded (request r1)',
      );
    });
  });

  test('only transient failures are retryable', () {
    expect(
      {
        for (final failure in CloudTtsFailure.values)
          failure: CloudTtsException(failure, '').isRetryable,
      },
      {
        CloudTtsFailure.network: true,
        CloudTtsFailure.timeout: true,
        CloudTtsFailure.unauthorized: false,
        CloudTtsFailure.rateLimited: true,
        CloudTtsFailure.rejected: false,
        CloudTtsFailure.server: true,
        CloudTtsFailure.invalidResponse: false,
        CloudTtsFailure.noVoice: false,
      },
    );
  });
}
