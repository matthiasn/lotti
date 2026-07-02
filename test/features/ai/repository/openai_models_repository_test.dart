import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/openai_models_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';

void main() {
  const baseUrl = 'https://api.openai.com/v1';
  const apiKey = 'sk-test';

  // Builds a repository whose `/models` GET is served by [handler].
  OpenAiModelsRepository repoWithHandler(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final repo = OpenAiModelsRepository(httpClient: MockClient(handler));
    addTearDown(repo.close);
    return repo;
  }

  // Builds a repository that returns [body] with [status] for `/models`.
  OpenAiModelsRepository repoReturning(Object? body, {int status = 200}) {
    return repoWithHandler(
      (_) async => http.Response(
        body is String ? body : jsonEncode(body),
        status,
      ),
    );
  }

  // Fetches all mapped models for a `data[]` payload of raw rows.
  Future<List<KnownModel>> mapRows(List<Object?> rows) {
    return repoReturning({'data': rows}).listModels(
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
  }

  // Fetches the single mapped model for a one-row catalog payload.
  Future<KnownModel> mapSingle(Object row) async {
    final models = await mapRows([row]);
    return models.single;
  }

  group('OpenAiModelsRepository.listModels', () {
    group('argument validation', () {
      test('rejects a blank base URL', () {
        expect(
          repoReturning(const {'data': <Object>[]}).listModels(
            baseUrl: '   ',
            apiKey: apiKey,
          ),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              'Base URL cannot be empty',
            ),
          ),
        );
      });

      test('rejects a blank API key', () {
        expect(
          repoReturning(const {'data': <Object>[]}).listModels(
            baseUrl: baseUrl,
            apiKey: '  ',
          ),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              'API key cannot be empty',
            ),
          ),
        );
      });

      test('rejects a malformed base URL without echoing it back', () {
        expect(
          repoReturning(const {'data': <Object>[]}).listModels(
            baseUrl: 'http://[invalid',
            apiKey: apiKey,
          ),
          throwsA(
            isA<OpenAiModelsException>()
                .having((e) => e.message, 'message', 'Invalid OpenAI base URL')
                .having((e) => e.message, 'no url leak', isNot(contains('['))),
          ),
        );
      });

      test('rejects a scheme-less base URL before requesting', () {
        expect(
          repoReturning(const {'data': <Object>[]}).listModels(
            baseUrl: 'api.openai.com/v1',
            apiKey: apiKey,
          ),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              'Invalid OpenAI base URL',
            ),
          ),
        );
      });
    });

    group('request shape', () {
      test('sends bearer auth to the normalised /models endpoint', () async {
        late http.Request captured;
        final repo = repoWithHandler((request) async {
          captured = request;
          return http.Response(jsonEncode(const {'data': <Object>[]}), 200);
        });

        final models = await repo.listModels(
          baseUrl: '$baseUrl/',
          apiKey: apiKey,
        );

        expect(models, isEmpty);
        expect(captured.method, 'GET');
        // Trailing slash on the base URL is normalised away.
        expect(captured.url.toString(), '$baseUrl/models');
        expect(captured.headers['authorization'], 'Bearer $apiKey');
        expect(captured.headers['accept'], 'application/json');
      });

      test('accepts a bare JSON array catalog shape', () async {
        final models = await mapRows([
          {'id': 'gpt-6-turbo'},
        ]);
        expect(models.single.providerModelId, 'gpt-6-turbo');
      });

      test('accepts string-only rows', () async {
        final model = await mapSingle('gpt-6-turbo');
        expect(model.providerModelId, 'gpt-6-turbo');
        expect(model.inputModalities, contains(Modality.image));
      });
    });

    group('curated merge', () {
      test('returns a curated model verbatim', () async {
        final curated = openaiModels.firstWhere(
          (m) => m.providerModelId == 'gpt-5-nano',
        );
        final model = await mapSingle({'id': 'gpt-5-nano'});
        expect(model.name, curated.name);
        expect(model.description, curated.description);
        expect(model.isReasoningModel, curated.isReasoningModel);
      });
    });

    group('heuristic mapping of unknown ids', () {
      test('a modern chat model gets vision + tools', () async {
        final model = await mapSingle({
          'id': 'gpt-6',
          'owned_by': 'openai',
        });
        expect(model.name, 'GPT 6');
        expect(model.inputModalities, [Modality.text, Modality.image]);
        expect(model.outputModalities, [Modality.text]);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.isReasoningModel, isFalse);
        expect(model.description, contains('Owned by openai.'));
      });

      test('an o-series id is treated as a reasoning model', () async {
        final model = await mapSingle({'id': 'o5-mini'});
        expect(model.isReasoningModel, isTrue);
        expect(model.description, contains('reasoning'));
      });

      test('a fine-tuned o-series id (ft:o…) is a reasoning model', () async {
        final model = await mapSingle({'id': 'ft:o1-mini:acme::abc123'});
        expect(model.isReasoningModel, isTrue);
      });

      test(
        'a gpt-4o id is NOT mistaken for an o-series reasoning model',
        () async {
          // The trailing `o` in `gpt-4o` must not match the o-series pattern.
          final model = await mapSingle({'id': 'gpt-4o-2030'});
          expect(model.isReasoningModel, isFalse);
          expect(model.inputModalities, [Modality.text, Modality.image]);
        },
      );

      test(
        'a router-recognized transcription id maps to audio in / text out',
        () async {
          // gpt-4o-transcribe* is what OpenAiTranscriptionRepository routes to
          // /v1/audio/transcriptions.
          final model = await mapSingle({'id': 'gpt-4o-transcribe-2025'});
          expect(model.inputModalities, [Modality.audio]);
          expect(model.outputModalities, [Modality.text]);
          expect(model.supportsFunctionCalling, isFalse);
          expect(model.description, contains('audio transcription'));
        },
      );

      test(
        'a text-only legacy completions model claims no vision or tools',
        () async {
          final model = await mapSingle({'id': 'davinci-002'});
          expect(model.inputModalities, [Modality.text]);
          expect(model.outputModalities, [Modality.text]);
          expect(model.supportsFunctionCalling, isFalse);
          expect(model.isReasoningModel, isFalse);
        },
      );

      test(
        'a gpt-image id maps to image in+out with reference editing',
        () async {
          final model = await mapSingle({'id': 'gpt-image-2'});
          expect(model.inputModalities, [Modality.text, Modality.image]);
          expect(model.outputModalities, [Modality.text, Modality.image]);
          expect(model.description, contains('image generation'));
        },
      );

      test('a dall-e id maps to text in / image out', () async {
        final model = await mapSingle({'id': 'dall-e-4'});
        expect(model.inputModalities, [Modality.text]);
        expect(model.outputModalities, [Modality.image]);
      });
    });

    group('non-installable rows are dropped', () {
      test(
        'embeddings, moderation, tts and realtime are filtered out',
        () async {
          final models = await mapRows([
            {'id': 'text-embedding-4-large'},
            {'id': 'omni-moderation-latest'},
            {'id': 'gpt-6o-mini-tts'},
            {'id': 'gpt-realtime-6'},
            {'id': 'gpt-6'},
          ]);
          expect(
            models.map((m) => m.providerModelId),
            ['gpt-6'],
          );
        },
      );

      test(
        'whisper and other unrouted transcription models are dropped',
        () async {
          // The transcription router only knows the gpt-4o-transcribe family, so
          // offering whisper-1 would route to chat completions and fail.
          final models = await mapRows([
            {'id': 'whisper-1'},
            {'id': 'canary-transcribe-2'},
            {'id': 'gpt-6'},
          ]);
          expect(models.map((m) => m.providerModelId), ['gpt-6']);
        },
      );
    });

    group('malformed payloads', () {
      test('skips a row that is neither an object nor a string', () async {
        final models = await mapRows([
          42,
          {'id': 'gpt-6'},
        ]);
        expect(models.map((m) => m.providerModelId), ['gpt-6']);
      });

      test('skips a row with no string id but keeps valid ones', () async {
        final models = await mapRows([
          {'object': 'model'},
          {'id': 'gpt-6'},
        ]);
        expect(models.map((m) => m.providerModelId), ['gpt-6']);
      });

      test('throws when the top-level shape is neither object nor array', () {
        expect(
          repoReturning(42).listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              contains('must be a JSON object with data[]'),
            ),
          ),
        );
      });

      test('throws on invalid JSON', () {
        expect(
          repoReturning('not json').listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              'OpenAI model list response was not valid JSON',
            ),
          ),
        );
      });
    });

    group('transport failures', () {
      test('maps an error body to its message and status code', () {
        expect(
          repoReturning(
            const {
              'error': {'message': 'Invalid API key'},
            },
            status: 401,
          ).listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<OpenAiModelsException>()
                .having((e) => e.message, 'message', 'Invalid API key')
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('falls back to a clipped raw body on an unparsable error', () {
        expect(
          repoReturning('boom', status: 500).listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              'boom',
            ),
          ),
        );
      });

      test('wraps a timeout', () {
        final repo = repoWithHandler(
          (_) async => throw TimeoutException('slow'),
        );
        expect(
          repo.listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              'OpenAI model list request timed out',
            ),
          ),
        );
      });

      test('wraps an unexpected transport exception', () {
        final repo = repoWithHandler((_) => throw const SocketishError());
        expect(
          repo.listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<OpenAiModelsException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch OpenAI models'),
            ),
          ),
        );
      });
    });

    group('OpenAiModelsException.toString', () {
      test('includes status code and cause when present', () {
        const exception = OpenAiModelsException(
          'nope',
          statusCode: 503,
          originalError: 'root cause',
        );
        expect(
          exception.toString(),
          'OpenAiModelsException (HTTP 503): nope: root cause',
        );
      });

      test('omits status and cause when absent', () {
        const exception = OpenAiModelsException('nope');
        expect(exception.toString(), 'OpenAiModelsException: nope');
      });
    });
  });
}

/// A stand-in transport error for the "unexpected exception" path.
class SocketishError implements Exception {
  const SocketishError();
  @override
  String toString() => 'SocketishError';
}
