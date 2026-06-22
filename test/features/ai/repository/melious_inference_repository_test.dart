import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:openai_dart/openai_dart.dart';

class _ChatStreamProbe {
  _ChatStreamProbe({required this.content});

  final String content;
  final requests = <CreateChatCompletionRequest>[];
  final baseUrls = <String>[];
  final apiKeys = <String>[];

  Stream<CreateChatCompletionStreamResponse> call({
    required String baseUrl,
    required String apiKey,
    required CreateChatCompletionRequest request,
  }) {
    baseUrls.add(baseUrl);
    apiKeys.add(apiKey);
    requests.add(request);

    return Stream.value(
      CreateChatCompletionStreamResponse(
        id: 'chatcmpl-melious-test',
        choices: [
          ChatCompletionStreamResponseChoice(
            delta: ChatCompletionStreamResponseDelta(content: content),
            index: 0,
          ),
        ],
        object: 'chat.completion.chunk',
        created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }
}

void main() {
  group('MeliousInferenceRepository', () {
    const baseUrl = 'https://api.melious.ai/v1';
    const apiKey = 'sk-mel-test';

    AiConfigInferenceProvider meliousProvider() {
      return AiConfig.inferenceProvider(
            id: 'provider-melious',
            name: 'Melious.ai',
            baseUrl: baseUrl,
            apiKey: apiKey,
            createdAt: DateTime(2024, 3, 15),
            inferenceProviderType: InferenceProviderType.melious,
          )
          as AiConfigInferenceProvider;
    }

    test('listModels fetches include_meta and maps capabilities', () async {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((request) async {
          expect(request.method, equals('GET'));
          expect(request.url.path, equals('/v1/models'));
          expect(request.url.queryParameters['include_meta'], equals('true'));
          expect(
            request.headers['authorization'],
            equals('Bearer $apiKey'),
          );

          return http.Response(
            jsonEncode({
              'object': 'list',
              'data': [
                {
                  'id': 'qwen/qwen3-vl-plus',
                  'object': 'model',
                  'created': 1710460800,
                  'owned_by': 'qwen',
                  '_meta': {
                    'type': 'chat',
                    'input_modalities': ['text'],
                    'output_modalities': ['text'],
                    'context_length': 131072,
                    'capabilities': {
                      'streaming': true,
                      'function_calling': true,
                      'vision': true,
                      'reasoning': true,
                    },
                  },
                },
                {
                  'id': 'openai/whisper-large-v3',
                  'object': 'model',
                  'created': 1710460800,
                  'owned_by': 'openai',
                  '_meta': {
                    'type': 'audio',
                    'input_modalities': ['audio'],
                    'output_modalities': ['text'],
                    'capabilities': {'streaming': false},
                  },
                },
                {
                  'id': 'black-forest-labs/flux-2-klein',
                  'object': 'model',
                  'created': 1710460800,
                  'owned_by': 'black-forest-labs',
                  '_meta': {
                    'type': 'image',
                    'input_modalities': ['text'],
                    'output_modalities': ['image'],
                    'capabilities': {'streaming': false},
                  },
                },
                {
                  'id': 'baai/bge-m3',
                  'object': 'model',
                  'created': 1710460800,
                  'owned_by': 'baai',
                  '_meta': {
                    'type': 'embeddings',
                    'input_modalities': ['text'],
                    'output_modalities': <String>[],
                    'capabilities': <String, Object?>{},
                  },
                },
                {
                  'id': 'bge-reranker-v2-m3',
                  'object': 'model',
                  'created': 1710460800,
                  'owned_by': 'baai',
                  '_meta': {
                    'type': 'rerank',
                    'input_modalities': ['text'],
                    'output_modalities': <String>[],
                    'capabilities': <String, Object?>{},
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
        apiKey: apiKey,
      );

      expect(models, hasLength(5));

      final vision = models[0];
      expect(vision.providerModelId, equals('qwen/qwen3-vl-plus'));
      expect(vision.name, equals('Qwen3 VL Plus'));
      expect(
        vision.inputModalities,
        containsAll([Modality.text, Modality.image]),
      );
      expect(vision.outputModalities, contains(Modality.text));
      expect(vision.isReasoningModel, isTrue);
      expect(vision.supportsFunctionCalling, isTrue);
      expect(vision.description, contains('Context: 131072 tokens'));
      expect(vision.description, contains('vision'));
      expect(vision.description, contains('tools'));

      final audio = models[1];
      expect(audio.inputModalities, contains(Modality.audio));
      expect(audio.outputModalities, contains(Modality.text));

      final image = models[2];
      expect(image.inputModalities, contains(Modality.text));
      expect(image.outputModalities, contains(Modality.image));

      for (final nonChat in models.skip(3)) {
        expect(nonChat.inputModalities, contains(Modality.text));
        expect(nonChat.outputModalities, contains(Modality.text));
      }
      expect(models[3].description, contains('embeddings model'));
      expect(models[4].description, contains('rerank model'));
    });

    test('generateText streams text and sends prompt request body', () async {
      final probe = _ChatStreamProbe(content: 'melious response');
      final repository = MeliousInferenceRepository(
        chatCompletionStreamFactory: probe.call,
      );
      addTearDown(repository.close);

      final chunks = await repository
          .generateText(
            prompt: 'Say hello',
            model: 'minimax-m2.7',
            baseUrl: baseUrl,
            apiKey: apiKey,
            systemMessage: 'Be concise.',
            temperature: 0.2,
            maxCompletionTokens: 128,
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'melious response');

      expect(probe.baseUrls.single, baseUrl);
      expect(probe.apiKeys.single, apiKey);
      final request = probe.requests.single;
      expect(request.model.toString(), contains('minimax-m2.7'));
      expect(request.stream, isTrue);
      expect(request.temperature, 0.2);
      expect(request.maxCompletionTokens, 128);
      expect(request.messages, hasLength(2));
      expect(request.messages.first.role, ChatCompletionMessageRole.system);
      expect(request.messages.last.role, ChatCompletionMessageRole.user);
      expect(request.toString(), contains('Say hello'));
      expect(request.toString(), contains('Be concise.'));
    });

    test(
      'generateTextWithMessages forwards conversation history to Melious',
      () async {
        final probe = _ChatStreamProbe(content: 'history response');
        final repository = MeliousInferenceRepository(
          chatCompletionStreamFactory: probe.call,
        );
        addTearDown(repository.close);

        final chunks = await repository
            .generateTextWithMessages(
              messages: [
                const ChatCompletionMessage.system(content: 'System context.'),
                const ChatCompletionMessage.user(
                  content: ChatCompletionUserMessageContent.string(
                    'Previous user turn',
                  ),
                ),
              ],
              model: 'deepseek-v4-pro',
              baseUrl: baseUrl,
              apiKey: apiKey,
              maxCompletionTokens: 256,
            )
            .toList();

        expect(
          chunks.single.choices?.single.delta?.content,
          'history response',
        );

        expect(probe.baseUrls.single, baseUrl);
        expect(probe.apiKeys.single, apiKey);
        final request = probe.requests.single;
        expect(request.model.toString(), contains('deepseek-v4-pro'));
        expect(request.maxCompletionTokens, 256);
        expect(request.messages, hasLength(2));
        expect(request.messages.first.role, ChatCompletionMessageRole.system);
        expect(request.messages.last.role, ChatCompletionMessageRole.user);
        expect(request.toString(), contains('Previous user turn'));
      },
    );

    test('generateWithImages sends multimodal message parts', () async {
      final probe = _ChatStreamProbe(content: 'vision response');
      final repository = MeliousInferenceRepository(
        chatCompletionStreamFactory: probe.call,
      );
      addTearDown(repository.close);

      final chunks = await repository
          .generateWithImages(
            prompt: 'Describe this image',
            model: 'gemma-4-26b-a4b',
            baseUrl: baseUrl,
            apiKey: apiKey,
            images: const ['abc123'],
            systemMessage: 'Use visual evidence only.',
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'vision response');

      expect(probe.baseUrls.single, baseUrl);
      expect(probe.apiKeys.single, apiKey);
      final request = probe.requests.single;
      expect(request.model.toString(), contains('gemma-4-26b-a4b'));
      expect(request.messages, hasLength(2));
      expect(request.messages.first.role, ChatCompletionMessageRole.system);
      expect(request.messages.last.role, ChatCompletionMessageRole.user);
      final requestString = request.toString();
      expect(requestString, contains('Describe this image'));
      expect(requestString, contains('Use visual evidence only.'));
      expect(requestString, contains('data:image/jpeg;base64,abc123'));
    });

    test('generateText uses default OpenAI-compatible stream factory', () {
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      final stream = repository.generateText(
        prompt: 'Say hello',
        model: 'minimax-m2.7',
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      expect(stream.isBroadcast, isTrue);
    });

    test('listModels surfaces provider error messages', () async {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {'message': 'Invalid Melious API key'},
            }),
            401,
          );
        }),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl, apiKey: apiKey),
        throwsA(
          isA<MeliousInferenceException>()
              .having((e) => e.message, 'message', 'Invalid Melious API key')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('listModels validates required request parameters', () {
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      expect(
        () => repository.listModels(baseUrl: '', apiKey: apiKey),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.listModels(baseUrl: baseUrl, apiKey: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('listModels wraps malformed JSON responses', () async {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async => http.Response('{', 200)),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl, apiKey: apiKey),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            'Melious model list response was not valid JSON',
          ),
        ),
      );
    });

    test('listModels rejects malformed catalog payloads', () async {
      Future<void> expectMessage({
        required Object payload,
        required String message,
      }) async {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((_) async {
            return http.Response(jsonEncode(payload), 200);
          }),
        );
        addTearDown(repository.close);

        await expectLater(
          repository.listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<MeliousInferenceException>().having(
              (e) => e.message,
              'message',
              message,
            ),
          ),
        );
      }

      await expectMessage(
        payload: const [],
        message: 'Melious model list response must be a JSON object',
      );
      await expectMessage(
        payload: const <String, Object?>{},
        message: 'Melious model list response is missing the data array',
      );
      await expectMessage(
        payload: const {
          'data': ['not-a-model-object'],
        },
        message: 'Melious model entry must be a JSON object',
      );
      await expectMessage(
        payload: const {
          'data': [
            {'object': 'model'},
          ],
        },
        message: 'Melious model entry is missing a string id',
      );
    });

    test(
      'listModels coerces modality aliases and truthy metadata values',
      () async {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'custom/speech-json-model',
                    'owned_by': 'custom',
                    '_meta': {
                      'type': 'unexpected-kind',
                      'input_modalities': ['speech', 'vision'],
                      'output_modalities': ['text'],
                      'context_length': '4096',
                      'capabilities': {
                        'audio_input': 'true',
                        'function_calling': 1,
                        'reasoning': 'true',
                        'structured_output': true,
                        'json_schema': true,
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
          baseUrl: '$baseUrl?existing=1',
          apiKey: apiKey,
        );

        expect(models, hasLength(1));
        final model = models.single;
        expect(model.name, 'Speech JSON Model');
        expect(
          model.inputModalities,
          containsAll([Modality.audio, Modality.image, Modality.text]),
        );
        expect(model.outputModalities, equals([Modality.text]));
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.description, contains('Context: 4096 tokens'));
        expect(model.description, contains('structured output'));
        expect(model.description, contains('JSON schema'));
      },
    );

    test(
      'listModels handles sparse metadata and direct error messages',
      () async {
        var call = 0;
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((_) async {
            call++;
            if (call == 1) {
              return http.Response(
                jsonEncode({
                  'data': [
                    {
                      'id': 'openai/gpt-4.1-mini',
                      'owned_by': '   ',
                      '_meta': {
                        'type': 'embedding',
                        'input_modalities': 'text',
                        'output_modalities': null,
                        'context_length': 2048.5,
                        'capabilities': {
                          'streaming': 0,
                          'function_calling': false,
                          'reasoning': 'false',
                        },
                      },
                    },
                  ],
                }),
                200,
              );
            }

            return http.Response(
              jsonEncode({'message': 'top-level Melious failure'}),
              429,
            );
          }),
        );
        addTearDown(repository.close);

        final models = await repository.listModels(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(models.single.name, 'GPT 4 1 Mini');
        expect(models.single.description, contains('embeddings model'));
        expect(models.single.description, contains('Context: 2048 tokens'));
        expect(models.single.isReasoningModel, isFalse);
        expect(models.single.supportsFunctionCalling, isFalse);

        await expectLater(
          repository.listModels(baseUrl: baseUrl, apiKey: apiKey),
          throwsA(
            isA<MeliousInferenceException>().having(
              (e) => e.message,
              'message',
              'top-level Melious failure',
            ),
          ),
        );
      },
    );

    test('listModels wraps timeout and transport failures', () async {
      final timeoutRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );
      addTearDown(timeoutRepository.close);

      await expectLater(
        timeoutRepository.listModels(
          baseUrl: baseUrl,
          apiKey: apiKey,
          timeout: Duration.zero,
        ),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            'Melious model list request timed out',
          ),
        ),
      );

      final failingRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          throw Exception('socket closed');
        }),
      );
      addTearDown(failingRepository.close);

      await expectLater(
        failingRepository.listModels(baseUrl: baseUrl, apiKey: apiKey),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            contains('Failed to fetch Melious models'),
          ),
        ),
      );
    });

    test('listModels clips raw non-JSON error bodies', () async {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          return http.Response('x' * 260, 500);
        }),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.listModels(baseUrl: baseUrl, apiKey: apiKey),
        throwsA(
          isA<MeliousInferenceException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message.length, 'message length', 243)
              .having((e) => e.message, 'message suffix', endsWith('...')),
        ),
      );
    });

    test(
      'transcribeAudio sends multipart request and returns transcript',
      () async {
        http.BaseRequest? captured;
        final repository = MeliousInferenceRepository(
          httpClient: MockClient.streaming((request, _) async {
            captured = request;
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'text': 'bonjour'}))),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        final chunks = await repository
            .transcribeAudio(
              model: 'openai/whisper-large-v3',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
            )
            .toList();

        expect(chunks.single.id, startsWith('melious-transcription-'));
        expect(chunks.single.choices?.single.delta?.content, 'bonjour');
        expect(captured, isA<http.MultipartRequest>());
        final request = captured! as http.MultipartRequest;
        expect(request.url.toString(), '$baseUrl/audio/transcriptions');
        expect(request.headers['Authorization'], 'Bearer $apiKey');
        expect(request.fields['model'], 'openai/whisper-large-v3');
        expect(request.fields['response_format'], 'json');
        expect(request.files.single.filename, 'audio.m4a');
      },
    );

    test(
      'transcribeAudio supports custom response format and timeout',
      () async {
        http.BaseRequest? captured;
        final repository = MeliousInferenceRepository(
          httpClient: MockClient.streaming((request, _) async {
            captured = request;
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'text': 'ciao'}))),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        await repository
            .transcribeAudio(
              model: 'openai/whisper-large-v3',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              responseFormat: 'verbose_json',
            )
            .toList();

        final request = captured! as http.MultipartRequest;
        expect(request.fields['response_format'], 'verbose_json');

        final timeoutRepository = MeliousInferenceRepository(
          httpClient: MockClient.streaming((_, _) {
            return Completer<http.StreamedResponse>().future;
          }),
        );
        addTearDown(timeoutRepository.close);

        await expectLater(
          timeoutRepository
              .transcribeAudio(
                model: 'openai/whisper-large-v3',
                audioBase64: base64Encode([1, 2, 3]),
                baseUrl: baseUrl,
                apiKey: apiKey,
                timeout: Duration.zero,
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having(
                  (e) => e.provider,
                  'provider',
                  'MeliousInferenceRepository',
                )
                .having((e) => e.statusCode, 'statusCode', 408),
          ),
        );
      },
    );

    test('transcribeAudio validates required request parameters', () {
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      expect(
        () => repository.transcribeAudio(
          model: '',
          audioBase64: 'abc',
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.transcribeAudio(
          model: 'openai/whisper-large-v3',
          audioBase64: '',
          baseUrl: baseUrl,
          apiKey: apiKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.transcribeAudio(
          model: 'openai/whisper-large-v3',
          audioBase64: 'abc',
          baseUrl: '',
          apiKey: apiKey,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.transcribeAudio(
          model: 'openai/whisper-large-v3',
          audioBase64: 'abc',
          baseUrl: baseUrl,
          apiKey: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('generateImage decodes base64 image responses', () async {
      const pngBytes = [137, 80, 78, 71];
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.path, equals('/v1/images/generations'));
          expect(
            request.headers['authorization'],
            equals('Bearer $apiKey'),
          );

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], equals('flux-2-klein'));
          expect(body['prompt'], equals('a quiet lake'));
          expect(body['response_format'], equals('b64_json'));

          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': base64Encode(pngBytes)},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(repository.close);

      final image = await repository.generateImage(
        prompt: 'a quiet lake',
        model: 'flux-2-klein',
        provider: meliousProvider(),
      );

      expect(image.bytes, equals(pngBytes));
      expect(image.mimeType, equals('image/png'));
    });

    test('generateImage decodes data-uri MIME types', () async {
      const webpBytes = [82, 73, 70, 70];
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'b64_json':
                      'data:image/webp;base64,${base64Encode(webpBytes)}',
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(repository.close);

      final image = await repository.generateImage(
        prompt: 'a quiet lake',
        model: 'flux-2-klein',
        provider: meliousProvider(),
      );

      expect(image.bytes, equals(webpBytes));
      expect(image.mimeType, equals('image/webp'));
    });

    test('generateImage rejects reference images explicitly', () async {
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      await expectLater(
        repository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
          referenceImages: const [
            ProcessedReferenceImage(
              base64Data: 'abc',
              mimeType: 'image/jpeg',
              originalId: 'reference',
            ),
          ],
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('generateImage surfaces provider error messages', () async {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({'error': 'image model unavailable'}),
            503,
          );
        }),
      );
      addTearDown(repository.close);

      await expectLater(
        repository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
        ),
        throwsA(
          isA<MeliousInferenceException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', 'image model unavailable'),
        ),
      );
    });

    test('generateImage wraps malformed JSON and transport failures', () async {
      final malformedRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) async => http.Response('{', 200)),
      );
      addTearDown(malformedRepository.close);

      await expectLater(
        malformedRepository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
        ),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            'Melious image generation response was not valid JSON',
          ),
        ),
      );

      final timeoutRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );
      addTearDown(timeoutRepository.close);

      await expectLater(
        timeoutRepository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
          timeout: Duration.zero,
        ),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            'Melious image generation request timed out',
          ),
        ),
      );

      final failingRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          throw Exception('connection reset');
        }),
      );
      addTearDown(failingRepository.close);

      await expectLater(
        failingRepository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
        ),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            contains('Failed to generate Melious image'),
          ),
        ),
      );
    });

    test('generateImage rejects malformed image payloads', () async {
      final cases = <Object>[
        const [],
        const <String, Object?>{'data': []},
        const {
          'data': ['not-an-object'],
        },
        const {
          'data': [
            {'url': 'https://example.com/image.png'},
          ],
        },
      ];

      for (final payload in cases) {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((_) async {
            return http.Response(jsonEncode(payload), 200);
          }),
        );
        addTearDown(repository.close);

        await expectLater(
          repository.generateImage(
            prompt: 'a quiet lake',
            model: 'flux-2-klein',
            provider: meliousProvider(),
          ),
          throwsA(isA<MeliousInferenceException>()),
        );
      }
    });

    test('generateImage validates required parameters', () async {
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      await expectLater(
        repository.generateImage(
          prompt: '',
          model: 'flux-2-klein',
          provider: meliousProvider(),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.generateImage(
          prompt: 'a quiet lake',
          model: '',
          provider: meliousProvider(),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider().copyWith(baseUrl: ''),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        repository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider().copyWith(apiKey: ''),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('isMeliousTranscriptionModel matches speech-to-text model IDs', () {
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'openai/whisper-large-v3',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'mistral/voxtral-small-latest',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel('qwen3-asr'),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'custom/transcription-fast',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'custom-transcribe-model',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'custom-stt-model',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'qwen/qwen3-vl-plus',
        ),
        isFalse,
      );
    });

    test('MeliousInferenceException includes status and cause in toString', () {
      expect(
        const MeliousInferenceException(
          'failed',
          statusCode: 429,
          originalError: 'rate limit',
        ).toString(),
        'MeliousInferenceException (HTTP 429): failed: rate limit',
      );
      expect(
        const MeliousInferenceException('failed').toString(),
        'MeliousInferenceException: failed',
      );
    });
  });
}
