import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/ollama_api_client.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  group('OllamaApiClient.warmUpModel', () {
    late MockHttpClient httpClient;
    late OllamaApiClient client;

    setUpAll(registerAllFallbackValues);

    setUp(() {
      httpClient = MockHttpClient();
      client = OllamaApiClient(httpClient: httpClient);
    });

    void stubPost(Future<http.Response> Function() answer) {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) => answer());
    }

    test('sends a one-message, non-streaming chat for the model', () async {
      stubPost(() async => http.Response('{}', 200));

      await client.warmUpModel('gemma4:4b', 'http://localhost:11434');

      final captured = verify(
        () => httpClient.post(
          captureAny(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;
      expect(
        (captured[0] as Uri).toString(),
        'http://localhost:11434/api/chat',
      );
      final body = jsonDecode(captured[1] as String) as Map<String, dynamic>;
      expect(body['model'], 'gemma4:4b');
      expect(body['stream'], isFalse);
      expect(body['messages'], hasLength(1));
    });

    // Warm-up is a best-effort optimisation: a failure must never abort the
    // inference that follows it.
    for (final (label, answer) in <(String, Future<http.Response> Function())>[
      ('a non-200 response', () async => http.Response('boom', 500)),
      (
        'a transport error',
        () async => throw const SocketException('connection refused'),
      ),
    ]) {
      test('swallows $label instead of throwing', () async {
        stubPost(answer);

        await expectLater(
          client.warmUpModel('gemma4:4b', 'http://localhost:11434'),
          completes,
        );
      });
    }
  });
}
