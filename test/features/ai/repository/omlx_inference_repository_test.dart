import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/omlx_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';

void main() {
  group('OmlxInferenceRepository', () {
    const baseUrl = 'http://127.0.0.1:8003/v1';

    test(
      'listModels fetches OpenAI-compatible catalog with bearer key',
      () async {
        final repository = OmlxInferenceRepository(
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.toString(), '$baseUrl/models');
            expect(request.headers['authorization'], 'Bearer local-key');

            return http.Response(
              jsonEncode({
                'object': 'list',
                'data': [
                  {'id': omlxQwen36A35bA3b4BitModelId},
                  {'id': omlxWhisperLargeV3TurboModelId},
                  {
                    'id': 'custom-local-vl-model',
                    'owned_by': 'local',
                    'metadata': {
                      'capabilities': {
                        'vision': true,
                        'function_calling': true,
                      },
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        final models = await repository.listModels(
          baseUrl: baseUrl,
          apiKey: 'local-key',
        );

        expect(models, hasLength(3));
        expect(models[0].providerModelId, omlxQwen36A35bA3b4BitModelId);
        expect(models[0].inputModalities, contains(Modality.image));
        expect(models[0].isReasoningModel, isTrue);
        expect(models[1].providerModelId, omlxWhisperLargeV3TurboModelId);
        expect(models[1].inputModalities, [Modality.audio]);
        expect(models[1].outputModalities, [Modality.text]);
        expect(models[2].providerModelId, 'custom-local-vl-model');
        expect(models[2].name, 'Custom Local VL Model');
        expect(models[2].inputModalities, contains(Modality.image));
        expect(models[2].supportsFunctionCalling, isTrue);
        expect(models[2].description, contains('Owned by local'));
      },
    );

    test(
      'listModels omits Authorization header when API key is empty',
      () async {
        final repository = OmlxInferenceRepository(
          httpClient: MockClient((request) async {
            expect(request.headers.containsKey('authorization'), isFalse);
            return http.Response(
              jsonEncode([
                {'id': 'llama-local'},
              ]),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        final models = await repository.listModels(baseUrl: '$baseUrl/');

        expect(models.single.providerModelId, 'llama-local');
        expect(models.single.inputModalities, [Modality.text]);
        expect(models.single.outputModalities, [Modality.text]);
      },
    );

    test('listModels rejects invalid response shapes', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient((_) async => http.Response('"bad"', 200)),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            contains('JSON object with data[]'),
          ),
        ),
      );
    });

    test('listModels surfaces structured provider errors', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'oMLX server unavailable'},
            }),
            503,
          ),
        ),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', 'oMLX server unavailable'),
        ),
      );
    });

    test('listModels wraps timeouts', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl, timeout: Duration.zero),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            'oMLX model list request timed out',
          ),
        ),
      );
    });

    test('listModels rejects an empty base URL before any request', () async {
      var requested = false;
      final repository = OmlxInferenceRepository(
        httpClient: MockClient((_) async {
          requested = true;
          return http.Response('[]', 200);
        }),
      );
      addTearDown(repository.close);

      expect(
        () => repository.listModels(baseUrl: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(requested, isFalse);
    });

    test('listModels wraps malformed base URLs as inference errors', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: 'http://[oops]'),
        throwsA(
          isA<OmlxInferenceException>()
              .having(
                (e) => e.message,
                'message',
                'Invalid base URL: http://[oops]',
              )
              .having(
                (e) => e.originalError,
                'originalError',
                isA<FormatException>(),
              ),
        ),
      );
    });

    test('listModels wraps non-JSON response bodies', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient(
          (_) async => http.Response('definitely-not-json', 200),
        ),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            'oMLX model list response was not valid JSON',
          ),
        ),
      );
    });

    test('listModels wraps transport-level failures', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient((_) async {
          throw http.ClientException('connection refused');
        }),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            contains('Failed to fetch oMLX models'),
          ),
        ),
      );
    });

    test('listModels merges metadata and top-level modality lists', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'custom-multimodal-local',
                  'input_modalities': ['text'],
                  'metadata': {
                    'input_modalities': ['audio', 'speech', 'image', 'vision'],
                    'output_modalities': ['text', 'audio'],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(repository.close);

      final models = await repository.listModels(baseUrl: baseUrl);

      final model = models.single;
      expect(
        model.inputModalities,
        containsAll([Modality.text, Modality.audio, Modality.image]),
      );
      expect(
        model.outputModalities,
        containsAll([Modality.text, Modality.audio]),
      );
    });

    test(
      'listModels infers audio modality for unknown transcription models',
      () async {
        final repository = OmlxInferenceRepository(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode([
                {'id': 'local-whisper-tiny'},
              ]),
              200,
            ),
          ),
        );
        addTearDown(repository.close);

        final model = (await repository.listModels(baseUrl: baseUrl)).single;
        expect(model.inputModalities, [Modality.audio]);
        expect(model.outputModalities, [Modality.text]);
        expect(model.description, contains('audio transcription'));
      },
    );

    test('listModels labels unknown reasoning models', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {'id': 'custom-deepseek-chat'},
            ]),
            200,
          ),
        ),
      );
      addTearDown(repository.close);

      final model = (await repository.listModels(baseUrl: baseUrl)).single;
      expect(model.isReasoningModel, isTrue);
      expect(model.description, contains('reasoning'));
    });

    test('listModels surfaces string error payloads', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'plain error text'}),
            500,
          ),
        ),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            'plain error text',
          ),
        ),
      );
    });

    test('listModels surfaces top-level message error payloads', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'top level failure'}),
            502,
          ),
        ),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            'top level failure',
          ),
        ),
      );
    });

    test('listModels clips long non-JSON error bodies', () async {
      final repository = OmlxInferenceRepository(
        httpClient: MockClient((_) async => http.Response('E' * 200, 500)),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl),
        throwsA(
          isA<OmlxInferenceException>().having(
            (e) => e.message,
            'message',
            allOf(startsWith('E' * 160), endsWith('…')),
          ),
        ),
      );
    });

    test(
      'listModels returns raw short error bodies that are not objects',
      () async {
        final repository = OmlxInferenceRepository(
          httpClient: MockClient((_) async => http.Response('["a","b"]', 500)),
        );
        addTearDown(repository.close);

        await expectLater(
          repository.listModels(baseUrl: baseUrl),
          throwsA(
            isA<OmlxInferenceException>().having(
              (e) => e.message,
              'message',
              '["a","b"]',
            ),
          ),
        );
      },
    );

    test('OmlxInferenceException renders status and cause in toString', () {
      expect(
        const OmlxInferenceException(
          'boom',
          statusCode: 503,
          originalError: 'socket closed',
        ).toString(),
        'OmlxInferenceException (HTTP 503): boom: socket closed',
      );
      expect(
        const OmlxInferenceException('boom').toString(),
        'OmlxInferenceException: boom',
      );
    });
  });
}
