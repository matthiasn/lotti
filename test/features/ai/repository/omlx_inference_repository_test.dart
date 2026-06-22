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
  });
}
