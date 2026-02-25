import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late OllamaEmbeddingRepository repository;
  late MockHttpClient mockHttpClient;

  const baseUrl = 'http://localhost:11434';
  const model = 'mxbai-embed-large';

  setUpAll(() {
    registerFallbackValue(Uri.parse(baseUrl));
    OllamaEmbeddingRepository.retryBaseDelay = Duration.zero;
  });

  tearDownAll(() {
    OllamaEmbeddingRepository.retryBaseDelay = const Duration(seconds: 2);
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = OllamaEmbeddingRepository(httpClient: mockHttpClient);
  });

  /// Creates a valid embedding response body with [dims] float values.
  String makeEmbeddingResponse(int dims, {double value = 0.5}) {
    final vector = List<double>.filled(dims, value);
    return jsonEncode({
      'model': model,
      'embeddings': [vector],
    });
  }

  group('OllamaEmbeddingRepository', () {
    group('embed', () {
      test('returns Float32List on successful response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions, value: 0.42),
            200,
          ),
        );

        final result = await repository.embed(
          input: 'test text for embedding',
          baseUrl: baseUrl,
        );

        expect(result.length, kEmbeddingDimensions);
        expect(result[0], closeTo(0.42, 1e-5));
      });

      test('sends correct request body', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          ),
        );

        await repository.embed(
          input: 'hello world',
          baseUrl: baseUrl,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final uri = captured[0] as Uri;
        expect(uri.toString(), '$baseUrl/api/embed');

        final headers = captured[1] as Map<String, String>;
        expect(headers['Content-Type'], 'application/json');

        final body = jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(body['model'], model);
        expect(body['input'], 'hello world');
      });

      test('throws ModelNotInstalledException on 404 with model not found',
          () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            '{"error":"model \'$model\' not found"}',
            404,
          ),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(isA<ModelNotInstalledException>()),
        );
      });

      test('throws on non-200 non-404 status', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal Server Error', 500),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('HTTP 500'),
            ),
          ),
        );
      });

      test('throws on malformed JSON response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('not json at all', 200),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Malformed'),
            ),
          ),
        );
      });

      test('throws on empty embeddings array', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'embeddings': <List<double>>[]}),
            200,
          ),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('missing or empty'),
            ),
          ),
        );
      });

      test('throws on dimension mismatch in response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(512), // wrong dimensions
            200,
          ),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('dimension mismatch'),
            ),
          ),
        );
      });

      test('throws ArgumentError on empty input', () async {
        expect(
          () => repository.embed(
            input: '',
            baseUrl: baseUrl,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('uses default model when not specified', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          ),
        );

        await repository.embed(
          input: 'test',
          baseUrl: baseUrl,
        );

        final captured = verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final body = jsonDecode(captured[0] as String) as Map<String, dynamic>;
        expect(body['model'], 'mxbai-embed-large');
      });

      test('throws when first embedding is not a list', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'embeddings': ['not-a-list'],
            }),
            200,
          ),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('first embedding is not a list'),
            ),
          ),
        );
      });

      test('missing embeddings key throws', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'model': model}),
            200,
          ),
        );

        expect(
          () => repository.embed(
            input: 'test',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('missing or empty'),
            ),
          ),
        );
      });
    });

    group('retry logic', () {
      test('retries on TimeoutException and throws after max retries',
          () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(TimeoutException('timed out'));

        expect(
          () => repository.embed(
            input: 'test text',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('timed out'),
                contains('3 attempts'),
              ),
            ),
          ),
        );
      });

      test('retries on SocketException and throws after max retries', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(
          const SocketException('Connection refused'),
        );

        expect(
          () => repository.embed(
            input: 'test text',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('Network error'),
                contains('3 attempts'),
              ),
            ),
          ),
        );
      });

      test('succeeds after transient timeout then success', () async {
        var callCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw TimeoutException('timed out');
          }
          return http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          );
        });

        final result = await repository.embed(
          input: 'test text',
          baseUrl: baseUrl,
        );

        expect(result.length, kEmbeddingDimensions);
        expect(callCount, 2);
      });

      test('succeeds after transient SocketException then success', () async {
        var callCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const SocketException('Connection refused');
          }
          return http.Response(
            makeEmbeddingResponse(kEmbeddingDimensions),
            200,
          );
        });

        final result = await repository.embed(
          input: 'test text',
          baseUrl: baseUrl,
        );

        expect(result.length, kEmbeddingDimensions);
        expect(callCount, 2);
      });

      test('rethrows non-transient exceptions immediately', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('Something unexpected'));

        expect(
          () => repository.embed(
            input: 'test text',
            baseUrl: baseUrl,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Something unexpected'),
            ),
          ),
        );
      });
    });

    group('close', () {
      test('closes the underlying HTTP client', () {
        when(() => mockHttpClient.close()).thenReturn(null);

        repository.close();

        verify(() => mockHttpClient.close()).called(1);
      });
    });
  });
}
