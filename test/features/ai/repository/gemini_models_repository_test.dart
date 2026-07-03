import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_models_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';

void main() {
  const baseUrl = 'https://generativelanguage.googleapis.com/v1beta/openai';
  const apiKey = 'gemini-key';

  // Builds a repository whose `/v1beta/models` GET is served by [handler].
  GeminiModelsRepository repoWithHandler(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    final repo = GeminiModelsRepository(httpClient: MockClient(handler));
    addTearDown(repo.close);
    return repo;
  }

  // Builds a repository that returns [body] with [status] for the listing.
  GeminiModelsRepository repoReturning(Object? body, {int status = 200}) {
    return repoWithHandler(
      (_) async => http.Response(
        body is String ? body : jsonEncode(body),
        status,
      ),
    );
  }

  // Fetches all mapped models for a `models[]` payload of raw rows.
  Future<List<KnownModel>> mapRows(List<Object?> rows) {
    return repoReturning({'models': rows}).listModels(
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
  }

  // Fetches the single mapped model for a one-row catalog payload.
  Future<KnownModel> mapSingle(Map<String, dynamic> row) async {
    final models = await mapRows([row]);
    return models.single;
  }

  group('GeminiModelsRepository.listModels', () {
    group('argument validation', () {
      test('rejects a blank base URL', () {
        expect(
          repoReturning(const {'models': <Object>[]}).listModels(
            baseUrl: '   ',
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'Base URL cannot be empty',
            ),
          ),
        );
      });

      test('rejects a blank API key', () {
        expect(
          repoReturning(const {'models': <Object>[]}).listModels(
            baseUrl: baseUrl,
            apiKey: '  ',
          ),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'API key cannot be empty',
            ),
          ),
        );
      });
    });

    group('request shape', () {
      test(
        'authenticates via the x-goog-api-key header, not the URL',
        () async {
          late http.Request captured;
          final repo = repoWithHandler((request) async {
            captured = request;
            return http.Response(jsonEncode(const {'models': <Object>[]}), 200);
          });

          final models = await repo.listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          );

          expect(models, isEmpty);
          expect(captured.method, 'GET');
          expect(captured.url.host, 'generativelanguage.googleapis.com');
          expect(captured.url.path, '/v1beta/models');
          // The key must never appear in the request URL — only in the header.
          expect(captured.url.queryParameters.containsKey('key'), isFalse);
          expect(captured.url.toString(), isNot(contains(apiKey)));
          expect(captured.headers['x-goog-api-key'], apiKey);
          expect(captured.headers['accept'], 'application/json');
        },
      );

      test('rejects a scheme-less base URL before requesting', () {
        // Would otherwise reach dart:io's HttpClient and throw an ArgumentError
        // whose message embeds the request URI.
        expect(
          repoReturning(const {'models': <Object>[]}).listModels(
            baseUrl: 'generativelanguage.googleapis.com/v1beta/openai',
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>()
                .having((e) => e.message, 'message', 'Invalid Gemini base URL')
                .having(
                  (e) => e.toString(),
                  'no key leak',
                  isNot(contains(apiKey)),
                ),
          ),
        );
      });

      test('rejects a malformed base URL without echoing it back', () {
        // Uri.parse throws a FormatException whose message embeds a slice of
        // the raw input; it must be wrapped in a sanitized exception.
        expect(
          repoReturning(const {'models': <Object>[]}).listModels(
            baseUrl: 'http://[invalid',
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>()
                .having((e) => e.message, 'message', 'Invalid Gemini base URL')
                .having((e) => e.message, 'no url leak', isNot(contains('['))),
          ),
        );
      });

      test('treats a missing models field as an empty listing', () async {
        final models = await repoReturning(const {}).listModels(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );
        expect(models, isEmpty);
      });
    });

    group('curated merge', () {
      test('returns a curated model verbatim', () async {
        final curated = geminiModels.first;
        final model = await mapSingle({
          'name': curated.providerModelId,
          'displayName': 'Should Be Ignored',
          'description': 'ignored',
        });
        expect(model.name, curated.name);
        expect(model.description, curated.description);
        expect(model.inputModalities, curated.inputModalities);
      });
    });

    group('heuristic mapping of unknown ids', () {
      test('a chat model is multimodal-in / text-out with tools', () async {
        final model = await mapSingle({
          'name': 'models/gemini-4-pro',
          'displayName': 'Gemini 4 Pro',
          'description': 'The next big thing.',
          'inputTokenLimit': 2000000,
          'outputTokenLimit': 65536,
          'supportedGenerationMethods': ['generateContent', 'countTokens'],
        });
        expect(model.providerModelId, 'models/gemini-4-pro');
        expect(model.name, 'Gemini 4 Pro');
        expect(
          model.inputModalities,
          [Modality.text, Modality.image, Modality.audio],
        );
        expect(model.outputModalities, [Modality.text]);
        expect(model.supportsFunctionCalling, isTrue);
        expect(
          model.description,
          'The next big thing. Input limit: 2000000 tokens. '
          'Output limit: 65536 tokens.',
        );
      });

      test('honours the live thinking flag for reasoning', () async {
        final model = await mapSingle({
          'name': 'models/gemini-4-flash',
          'thinking': true,
          'supportedGenerationMethods': ['generateContent'],
        });
        expect(model.isReasoningModel, isTrue);
      });

      test(
        'infers reasoning from the id when no thinking flag exists',
        () async {
          final model = await mapSingle({
            'name': 'models/gemini-2.5-flash',
            'supportedGenerationMethods': ['generateContent'],
          });
          expect(model.isReasoningModel, isTrue);
        },
      );

      test(
        'falls back to a humanised name when displayName is missing',
        () async {
          final model = await mapSingle({
            'name': 'models/gemini-4-flash-lite',
            'supportedGenerationMethods': ['generateContent'],
          });
          expect(model.name, 'Gemini 4 Flash Lite');
        },
      );

      test('maps an image model to image in+out, no tools/reasoning', () async {
        final model = await mapSingle({
          'name': 'models/gemini-4-pro-image-preview',
          'thinking': true,
          'supportedGenerationMethods': ['generateContent'],
        });
        expect(model.inputModalities, [Modality.text, Modality.image]);
        expect(model.outputModalities, [Modality.text, Modality.image]);
        expect(model.supportsFunctionCalling, isFalse);
        expect(model.isReasoningModel, isFalse);
      });

      test('maps a tts model to text in / audio out', () async {
        final model = await mapSingle({
          'name': 'models/gemini-4-flash-tts',
          'supportedGenerationMethods': ['generateContent'],
        });
        expect(model.inputModalities, [Modality.text]);
        expect(model.outputModalities, [Modality.audio]);
        expect(model.supportsFunctionCalling, isFalse);
      });

      test(
        'keeps a non-Gemini family (Gemma) as a text-only chat model',
        () async {
          // Gemma is served through the Gemini API but rejects audio input and
          // varies in vision/tool support, so it must not be over-claimed.
          final model = await mapSingle({
            'name': 'models/gemma-3-27b-it',
            'displayName': 'Gemma 3 27B',
            'supportedGenerationMethods': ['generateContent'],
          });
          expect(model.inputModalities, [Modality.text]);
          expect(model.outputModalities, [Modality.text]);
          expect(model.inputModalities, isNot(contains(Modality.audio)));
          expect(model.supportsFunctionCalling, isFalse);
          expect(model.isReasoningModel, isFalse);
        },
      );
    });

    group('non-installable rows are dropped', () {
      test('a model without generateContent support is skipped', () async {
        final models = await mapRows([
          {
            'name': 'models/text-embedding-005',
            'supportedGenerationMethods': ['embedContent'],
          },
          {
            'name': 'models/gemini-4-flash',
            'supportedGenerationMethods': ['generateContent'],
          },
        ]);
        expect(models.map((m) => m.providerModelId), ['models/gemini-4-flash']);
      });

      test(
        'a row with no generation methods is kept as a chat model',
        () async {
          final model = await mapSingle({'name': 'models/gemini-4-preview'});
          expect(model.inputModalities, contains(Modality.text));
        },
      );
    });

    group('pagination', () {
      test('follows nextPageToken and de-duplicates across pages', () async {
        final repo = repoWithHandler((request) async {
          final token = request.url.queryParameters['pageToken'];
          if (token == null) {
            return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/gemini-4-flash',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
                'nextPageToken': 'page-2',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'models': [
                // Duplicate of page 1 — must be dropped.
                {
                  'name': 'models/gemini-4-flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
                {
                  'name': 'models/gemini-4-pro',
                  'supportedGenerationMethods': ['generateContent'],
                },
              ],
            }),
            200,
          );
        });

        final models = await repo.listModels(baseUrl: baseUrl, apiKey: apiKey);
        expect(
          models.map((m) => m.providerModelId),
          ['models/gemini-4-flash', 'models/gemini-4-pro'],
        );
      });

      test('stops after the page cap even if a token keeps coming', () async {
        var requests = 0;
        final repo = repoWithHandler((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-4-flash-$requests',
                  'supportedGenerationMethods': ['generateContent'],
                },
              ],
              'nextPageToken': 'always-more',
            }),
            200,
          );
        });

        final models = await repo.listModels(baseUrl: baseUrl, apiKey: apiKey);
        expect(requests, GeminiModelsRepository.maxCatalogPages);
        expect(models, hasLength(GeminiModelsRepository.maxCatalogPages));
      });
    });

    group('malformed payloads', () {
      test('throws when the top-level shape is not an object', () {
        expect(
          repoReturning([<String, dynamic>{}]).listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'Gemini model list response must be a JSON object',
            ),
          ),
        );
      });

      test('throws when models is not an array', () {
        expect(
          repoReturning(const {'models': 42}).listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'Gemini model list "models" field must be an array',
            ),
          ),
        );
      });

      test('skips a non-object model entry but keeps valid ones', () async {
        final models = await mapRows([
          'nope',
          {
            'name': 'models/gemini-4-flash',
            'supportedGenerationMethods': ['generateContent'],
          },
        ]);
        expect(models.map((m) => m.providerModelId), ['models/gemini-4-flash']);
      });

      test(
        'skips a model entry with no string name but keeps valid ones',
        () async {
          final models = await mapRows([
            {'displayName': 'Nameless'},
            {
              'name': 'models/gemini-4-pro',
              'supportedGenerationMethods': ['generateContent'],
            },
          ]);
          expect(models.map((m) => m.providerModelId), ['models/gemini-4-pro']);
        },
      );

      test('throws on invalid JSON', () {
        expect(
          repoReturning('not json').listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'Gemini model list response was not valid JSON',
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
              'error': {'message': 'API key not valid'},
            },
            status: 400,
          ).listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<GeminiModelsException>()
                .having((e) => e.message, 'message', 'API key not valid')
                .having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });

      test('falls back to a status-only message on an empty error body', () {
        expect(
          repoReturning('', status: 500).listModels(
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'Gemini API error (HTTP 500)',
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
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              'Gemini model list request timed out',
            ),
          ),
        );
      });

      test('wraps an unexpected transport exception', () {
        final repo = repoWithHandler((_) => throw const _TransportFailure());
        expect(
          repo.listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<GeminiModelsException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch Gemini models'),
            ),
          ),
        );
      });
    });

    group('GeminiModelsException.toString', () {
      test('includes status code and cause when present', () {
        const exception = GeminiModelsException(
          'nope',
          statusCode: 503,
          originalError: 'root cause',
        );
        expect(
          exception.toString(),
          'GeminiModelsException (HTTP 503): nope: root cause',
        );
      });

      test('omits status and cause when absent', () {
        const exception = GeminiModelsException('nope');
        expect(exception.toString(), 'GeminiModelsException: nope');
      });
    });
  });
}

/// A non-timeout, non-format transport error for the generic failure path.
class _TransportFailure implements Exception {
  const _TransportFailure();
  @override
  String toString() => '_TransportFailure';
}
