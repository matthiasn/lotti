import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
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

http.Response _voxtralChatResponse({
  Object? id = 'chatcmpl-voxtral',
  Object? model = 'voxtral-small-24b-2507',
  Object? created = 123,
}) => http.Response(
  jsonEncode({
    'id': ?id,
    'model': ?model,
    'created': ?created,
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': 'Lotti uses Voxtral.',
        },
        'finish_reason': 'stop',
      },
    ],
    'usage': {
      'prompt_tokens': 11,
      'completion_tokens': 4,
      'total_tokens': 15,
    },
  }),
  200,
);

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

    test(
      'listModels accepts top-level arrays and plain string model IDs',
      () async {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((request) async {
            expect(request.url.path, equals('/v1/models'));
            expect(request.url.queryParameters['include_meta'], equals('true'));

            return http.Response(
              jsonEncode([
                'deepseek-v4-pro',
                {
                  'id': 'gemma-4-26b-a4b',
                  'owned_by': 'google',
                  '_meta': {
                    'capabilities': {'vision': true, 'reasoning': true},
                  },
                },
              ]),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        final models = await repository.listModels(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(models, hasLength(2));
        expect(models.first.providerModelId, 'deepseek-v4-pro');
        expect(models.first.name, 'DeepSeek V4 Pro');
        expect(models.first.inputModalities, [Modality.text]);
        expect(models.first.outputModalities, [Modality.text]);
        expect(models.first.isReasoningModel, isTrue);
        expect(models.first.supportsFunctionCalling, isTrue);

        expect(models.last.providerModelId, 'gemma-4-26b-a4b');
        expect(models.last.inputModalities, contains(Modality.image));
        expect(models.last.isReasoningModel, isTrue);
      },
    );

    test(
      'listModels merges live Melious metadata with curated capabilities',
      () async {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((request) async {
            expect(request.url.queryParameters['include_meta'], equals('true'));

            return http.Response(
              jsonEncode({
                'object': 'list',
                'data': [
                  {
                    'id': 'deepseek-v4-pro',
                    'object': 'model',
                    'owned_by': 'melious',
                    '_meta': {
                      'type': 'chat',
                      'input_modalities': ['text'],
                      'output_modalities': ['text'],
                      'capabilities': {
                        'streaming': true,
                        'json_schema': true,
                        'function_calling': true,
                        'structured_output': true,
                      },
                      'context_length': 1000000,
                    },
                  },
                  {
                    'id': 'flux-2-klein-9b',
                    'object': 'model',
                    'owned_by': 'melious',
                    '_meta': {
                      'type': 'image',
                      'input_modalities': ['text', 'image'],
                      'output_modalities': ['image'],
                      'capabilities': {
                        'text_to_image': true,
                        'image_to_image': true,
                      },
                    },
                  },
                  {
                    'id': 'voxtral-small-24b-2507',
                    'object': 'model',
                    'owned_by': 'melious',
                    '_meta': {
                      'type': 'chat',
                      'input_modalities': ['text', 'audio'],
                      'output_modalities': ['text'],
                      'capabilities': {
                        'supports_audio': true,
                        'vision': true,
                      },
                    },
                  },
                  {
                    'id': 'whisper-large-v3-turbo',
                    'object': 'model',
                    'owned_by': 'melious',
                    '_meta': {
                      'type': 'audio',
                      'input_modalities': ['audio'],
                      'output_modalities': ['text'],
                      'capabilities': {
                        'transcription': true,
                        'translation': true,
                      },
                    },
                  },
                  {
                    'id': 'qwen3-next-80b-a3b-thinking',
                    'object': 'model',
                    'owned_by': 'melious',
                    '_meta': {
                      'type': 'chat',
                      'input_modalities': ['text'],
                      'output_modalities': ['text'],
                      'capabilities': {
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
          apiKey: apiKey,
        );

        final deepseek = models.singleWhere(
          (model) => model.providerModelId == 'deepseek-v4-pro',
        );
        expect(deepseek.name, 'DeepSeek V4 Pro');
        expect(
          deepseek.isReasoningModel,
          isTrue,
          reason:
              'The live catalog currently omits a reasoning flag for this '
              'known Melious default, so curated capabilities must be merged.',
        );
        expect(deepseek.supportsFunctionCalling, isTrue);
        expect(deepseek.description, contains('Context: 1000000 tokens'));

        final image = models.singleWhere(
          (model) => model.providerModelId == 'flux-2-klein-9b',
        );
        expect(
          image.inputModalities,
          containsAll([Modality.text, Modality.image]),
        );
        expect(image.outputModalities, contains(Modality.image));
        expect(image.description, contains('text to image'));
        expect(image.description, contains('image to image'));

        final audioChat = models.singleWhere(
          (model) => model.providerModelId == 'voxtral-small-24b-2507',
        );
        expect(
          audioChat.inputModalities,
          containsAll([Modality.text, Modality.audio, Modality.image]),
        );
        expect(audioChat.outputModalities, contains(Modality.text));

        final whisper = models.singleWhere(
          (model) => model.providerModelId == 'whisper-large-v3-turbo',
        );
        expect(whisper.name, 'Whisper Large v3 Turbo');
        expect(whisper.inputModalities, contains(Modality.audio));
        expect(whisper.outputModalities, contains(Modality.text));
        expect(whisper.description, contains('transcription'));
        expect(whisper.description, contains('translation'));

        final namedThinkingModel = models.singleWhere(
          (model) => model.providerModelId == 'qwen3-next-80b-a3b-thinking',
        );
        expect(namedThinkingModel.isReasoningModel, isTrue);
      },
    );

    test(
      'listModels falls back to plain /models when include_meta fails',
      () async {
        var call = 0;
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((request) async {
            call++;
            if (call == 1) {
              expect(
                request.url.queryParameters['include_meta'],
                equals('true'),
              );
              return http.Response(
                jsonEncode({
                  'error': {'message': 'include_meta is not supported'},
                }),
                400,
              );
            }

            expect(
              request.url.queryParameters,
              isNot(contains('include_meta')),
            );
            return http.Response(
              jsonEncode({
                'data': ['deepseek-v4-pro'],
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

        expect(call, 2);
        expect(models, hasLength(1));
        expect(models.single.providerModelId, 'deepseek-v4-pro');
        expect(models.single.isReasoningModel, isTrue);
      },
    );

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
            contains('Melious model list response was not valid JSON'),
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
              contains(message),
            ),
          ),
        );
      }

      await expectMessage(
        payload: 'not-a-list',
        message:
            'Melious model list response must be a JSON object with '
            'data[] or a JSON array',
      );
      await expectMessage(
        payload: const <String, Object?>{},
        message:
            'Melious model list response must be a JSON object with '
            'data[] or a JSON array',
      );
      await expectMessage(
        payload: const {
          'data': [42],
        },
        message: 'Melious model entry must be a JSON object or string id',
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

        expect(models.single.name, 'GPT 4.1 Mini');
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
              contains('top-level Melious failure'),
            ),
          ),
        );
      },
    );

    test('listModels wraps timeout and transport failures', () async {
      var timeoutCalls = 0;
      final timeoutRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) {
          timeoutCalls++;
          return Completer<http.Response>().future;
        }),
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
            contains('Melious model list request timed out'),
          ),
        ),
      );
      expect(timeoutCalls, 1);

      var failingCalls = 0;
      final failingRepository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          failingCalls++;
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
      expect(failingCalls, 1);
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
              .having(
                (e) => e.message,
                'message prefix',
                startsWith('include_meta failed:'),
              )
              .having(
                (e) => e.message,
                'raw body is clipped',
                contains('${'x' * 240}...'),
              )
              .having(
                (e) => e.message,
                'plain fallback failure',
                contains('plain /models failed:'),
              ),
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
        // No dictionary terms -> no bias prompt field at all.
        expect(request.fields.containsKey('prompt'), isFalse);
        expect(request.files.single.filename, 'audio.m4a');
      },
    );

    test(
      'transcribeChatAudio sends temporary WAV directly with context',
      () async {
        http.Request? captured;
        final wavBytes = base64Decode('UklGRgAAAABXQVZF');
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((request) async {
            captured = request;
            return _voxtralChatResponse(
              id: 42,
              model: 42,
              created: 'not-an-integer',
            );
          }),
          m4aToWavConverter: (_) async => wavBytes,
        );
        addTearDown(repository.close);

        final chunks = await repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe exactly. Required spelling: Lotti.',
              maxCompletionTokens: 321,
            )
            .toList();

        expect(chunks.single.id, startsWith('melious-audio-'));
        expect(chunks.single.created, 0);
        expect(chunks.single.model, 'voxtral-small-24b-2507');
        expect(captured?.url.toString(), '$baseUrl/chat/completions');
        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        final messages = body['messages']! as List<dynamic>;
        final content =
            (messages.single as Map<String, dynamic>)['content']!
                as List<dynamic>;
        expect(content.first, {
          'type': 'input_audio',
          'input_audio': {
            'data': base64Encode(wavBytes),
            'format': 'wav',
          },
        });
        expect(content.last, {
          'type': 'text',
          'text': 'Transcribe exactly. Required spelling: Lotti.',
        });
        expect(body['max_tokens'], 321);
      },
    );

    test('transcribeChatAudio reuses WAV input without conversion', () async {
      final wavBytes = base64Decode('UklGRgAAAABXQVZF');
      var conversionCalled = false;
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async => _voxtralChatResponse()),
        m4aToWavConverter: (_) async {
          conversionCalled = true;
          throw StateError('WAV input must bypass conversion');
        },
      );
      addTearDown(repository.close);

      final chunks = await repository
          .transcribeChatAudio(
            model: 'voxtral-small-24b-2507',
            audioBase64: base64Encode(wavBytes),
            baseUrl: baseUrl,
            apiKey: apiKey,
            prompt: 'Transcribe.',
          )
          .toList();

      expect(chunks.single.id, 'chatcmpl-voxtral');
      expect(conversionCalled, isFalse);
    });

    test('transcribeChatAudio surfaces native conversion failures', () async {
      var requestSent = false;
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          requestSent = true;
          return _voxtralChatResponse();
        }),
        m4aToWavConverter: (_) async =>
            throw Exception('GStreamer AAC decoder unavailable'),
      );
      addTearDown(repository.close);

      await expectLater(
        repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe exactly. Required spelling: Lotti.',
            )
            .toList(),
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('GStreamer AAC decoder unavailable'),
              contains('request melious-audio-'),
            ),
          ),
        ),
      );
      expect(requestSent, isFalse);
    });

    test(
      'transcribeChatAudio preserves structured provider error detail',
      () async {
        final wavBytes = base64Decode('UklGRgAAAABXQVZF');
        final repository = MeliousInferenceRepository(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'INFERENCE_3103',
                  'message': 'All Voxtral providers failed',
                },
              }),
              503,
            ),
          ),
          m4aToWavConverter: (_) async => wavBytes,
        );
        addTearDown(repository.close);

        await expectLater(
          repository
              .transcribeChatAudio(
                model: 'voxtral-small-24b-2507',
                audioBase64: base64Encode([1, 2, 3]),
                baseUrl: baseUrl,
                apiKey: apiKey,
                prompt: 'Transcribe.',
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>()
                .having((error) => error.statusCode, 'statusCode', 503)
                .having(
                  (error) => error.message,
                  'message',
                  contains('All Voxtral providers failed'),
                )
                .having(
                  (error) => error.message,
                  'HTTP detail',
                  contains('HTTP 503'),
                ),
          ),
        );
      },
    );

    test('transcribeChatAudio times out with a request id', () async {
      final wavBytes = base64Decode('UklGRgAAAABXQVZF');
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) => Completer<http.Response>().future),
        m4aToWavConverter: (_) async => wavBytes,
      );
      addTearDown(repository.close);

      await expectLater(
        repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe.',
              timeout: Duration.zero,
            )
            .toList(),
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(contains('timed out'), contains('request melious-audio-')),
          ),
        ),
      );
    });

    test('transcribeChatAudio bounds native conversion time', () async {
      final repository = MeliousInferenceRepository(
        m4aToWavConverter: (_) => Completer<Uint8List>().future,
      );
      addTearDown(repository.close);

      await expectLater(
        repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe.',
              timeout: Duration.zero,
            )
            .toList(),
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(contains('timed out'), contains('request melious-audio-')),
          ),
        ),
      );
    });

    test('transcribeChatAudio shares its timeout across both stages', () {
      fakeAsync((async) {
        final startedAt = DateTime(2024, 3, 15, 12);
        var currentTime = startedAt;
        final repository = MeliousInferenceRepository(
          clockSource: Clock(() => currentTime),
          httpClient: MockClient((_) => Completer<http.Response>().future),
          m4aToWavConverter: (_) async {
            currentTime = startedAt.add(const Duration(seconds: 40));
            return base64Decode('UklGRgAAAABXQVZF');
          },
        );
        Object? failure;
        var completed = false;

        repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe.',
            )
            .toList()
            .then<void>(
              (_) {
                completed = true;
              },
              onError: (Object error, StackTrace _) {
                failure = error;
                completed = true;
              },
            );
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 19));
        expect(completed, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(completed, isTrue);
        expect(
          failure,
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(contains('timed out'), contains('request melious-audio-')),
          ),
        );
        repository.close();
      });
    });

    test(
      'transcribeChatAudio skips HTTP after conversion exhausts timeout',
      () {
        fakeAsync((async) {
          final startedAt = DateTime(2024, 3, 15, 12);
          var currentTime = startedAt;
          var requestSent = false;
          final repository = MeliousInferenceRepository(
            clockSource: Clock(() => currentTime),
            httpClient: MockClient((_) async {
              requestSent = true;
              return _voxtralChatResponse();
            }),
            m4aToWavConverter: (_) async {
              currentTime = startedAt.add(const Duration(seconds: 60));
              return base64Decode('UklGRgAAAABXQVZF');
            },
          );
          Object? failure;

          repository
              .transcribeChatAudio(
                model: 'voxtral-small-24b-2507',
                audioBase64: base64Encode([1, 2, 3]),
                baseUrl: baseUrl,
                apiKey: apiKey,
                prompt: 'Transcribe.',
              )
              .toList()
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace _) {
                  failure = error;
                },
              );
          async.flushMicrotasks();

          expect(requestSent, isFalse);
          expect(
            failure,
            isA<TranscriptionException>().having(
              (error) => error.message,
              'message',
              allOf(contains('timed out'), contains('request melious-audio-')),
            ),
          );
          repository.close();
        });
      },
    );

    test('transcribeChatAudio prefixes conversion status detail', () {
      final repository = MeliousInferenceRepository(
        m4aToWavConverter: (_) async => throw TranscriptionException(
          'Native audio decoder rejected the recording',
          provider: 'audio_decoder',
          statusCode: 422,
        ),
      );
      addTearDown(repository.close);

      expect(
        repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe.',
            )
            .toList(),
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(
              startsWith('HTTP 422: Native audio decoder'),
              contains('request melious-audio-'),
            ),
          ),
        ),
      );
    });

    final malformedChatCases =
        <({String description, http.Response response, String message})>[
          (
            description: 'rejects non-JSON chat responses',
            response: http.Response('not-json', 200),
            message: 'not valid JSON',
          ),
          (
            description: 'rejects non-object chat responses',
            response: http.Response('[]', 200),
            message: 'invalid chat-audio response',
          ),
          (
            description: 'rejects chat responses without transcript text',
            response: http.Response(jsonEncode({'choices': <Object>[]}), 200),
            message: 'returned no transcript',
          ),
        ];
    for (final testCase in malformedChatCases) {
      test('transcribeChatAudio ${testCase.description}', () {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((_) async => testCase.response),
          m4aToWavConverter: (_) async => base64Decode('UklGRgAAAABXQVZF'),
        );
        addTearDown(repository.close);

        expect(
          repository
              .transcribeChatAudio(
                model: 'voxtral-small-24b-2507',
                audioBase64: base64Encode([1, 2, 3]),
                baseUrl: baseUrl,
                apiKey: apiKey,
                prompt: 'Transcribe.',
              )
              .toList(),
          throwsA(
            isA<TranscriptionException>().having(
              (error) => error.message,
              'message',
              contains(testCase.message),
            ),
          ),
        );
      });
    }

    test('transcribeChatAudio wraps transport failures', () {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async => throw Exception('network down')),
        m4aToWavConverter: (_) async => base64Decode('UklGRgAAAABXQVZF'),
      );
      addTearDown(repository.close);

      expect(
        repository
            .transcribeChatAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              prompt: 'Transcribe.',
            )
            .toList(),
        throwsA(
          isA<TranscriptionException>().having(
            (error) => error.message,
            'message',
            allOf(contains('request failed'), contains('network down')),
          ),
        ),
      );
    });

    final invalidChatArguments =
        <({String model, String audio, String baseUrl, String apiKey})>[
          (model: ' ', audio: 'audio', baseUrl: baseUrl, apiKey: apiKey),
          (model: 'voxtral', audio: '', baseUrl: baseUrl, apiKey: apiKey),
          (model: 'voxtral', audio: 'audio', baseUrl: ' ', apiKey: apiKey),
          (model: 'voxtral', audio: 'audio', baseUrl: baseUrl, apiKey: ' '),
        ];
    for (final arguments in invalidChatArguments) {
      test('transcribeChatAudio validates required arguments $arguments', () {
        final repository = MeliousInferenceRepository();
        addTearDown(repository.close);

        expect(
          repository
              .transcribeChatAudio(
                model: arguments.model,
                audioBase64: arguments.audio,
                baseUrl: arguments.baseUrl,
                apiKey: arguments.apiKey,
                prompt: 'Transcribe.',
              )
              .toList(),
          throwsArgumentError,
        );
      });
    }

    test(
      'transcribeAudio forwards speech-dictionary terms as the OpenAI '
      'prompt field, trimmed, de-blanked, and capped at 100 terms',
      () async {
        http.BaseRequest? captured;
        final repository = MeliousInferenceRepository(
          httpClient: MockClient.streaming((request, _) async {
            captured = request;
            return http.StreamedResponse(
              Stream.value(utf8.encode(jsonEncode({'text': 'hallo'}))),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        await repository
            .transcribeAudio(
              model: 'voxtral-small-24b-2507',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: baseUrl,
              apiKey: apiKey,
              contextBiasTerms: [
                '  Lotti ',
                '',
                'Voxtral',
                for (var i = 0; i < 120; i++) 'term-$i',
              ],
            )
            .toList();

        final request = captured! as http.MultipartRequest;
        final prompt = request.fields['prompt']!;
        final terms = prompt.split(', ');
        expect(terms.length, 100);
        expect(terms.first, 'Lotti');
        expect(terms[1], 'Voxtral');
        expect(terms, isNot(contains('')));
        expect(terms, contains('term-0'));
        // Terms beyond the 100-term cap are dropped from the tail.
        expect(terms, isNot(contains('term-99')));
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
          expect(body.containsKey('size'), isFalse);
          expect(body['width'], equals(1792));
          expect(body['height'], equals(1008));
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

    test(
      'generateImage records impact only when the response carries data',
      () async {
        const pngBytes = [137, 80, 78, 71];
        http.Response imageResponse({required bool withImpact}) {
          return http.Response(
            jsonEncode({
              'data': [
                {'b64_json': base64Encode(pngBytes)},
              ],
              if (withImpact) ...{
                'environment_impact': {
                  'energy_kwh': 0.004,
                  'carbon_g_co2': 1.5,
                  'location': 'SE',
                },
                'billing_cost': {'credits': 0.05},
              },
            }),
            200,
          );
        }

        final impactRepository = MeliousInferenceRepository(
          httpClient: MockClient(
            (_) async => imageResponse(withImpact: true),
          ),
        );
        addTearDown(impactRepository.close);

        final collectorWithImpact = InferenceImpactCollector();
        await impactRepository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
          impactCollector: collectorWithImpact,
        );

        expect(collectorWithImpact.impact, isNotNull);
        expect(collectorWithImpact.impact!.energyKwh, 0.004);
        expect(collectorWithImpact.impact!.carbonGCo2, 1.5);
        expect(collectorWithImpact.impact!.dataCenter, 'SE');
        expect(collectorWithImpact.impact!.costCredits, 0.05);

        final plainRepository = MeliousInferenceRepository(
          httpClient: MockClient(
            (_) async => imageResponse(withImpact: false),
          ),
        );
        addTearDown(plainRepository.close);

        final collectorWithoutImpact = InferenceImpactCollector();
        await plainRepository.generateImage(
          prompt: 'a quiet lake',
          model: 'flux-2-klein',
          provider: meliousProvider(),
          impactCollector: collectorWithoutImpact,
        );

        expect(
          collectorWithoutImpact.impact,
          isNull,
          reason:
              'a response without impact data must not touch the '
              'collector',
        );
      },
    );

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
        isFalse,
        reason:
            'Melious Voxtral catalog rows are chat models with audio input; '
            'the chat endpoint reports usage and impact metadata.',
      );
      expect(
        MeliousInferenceRepository.isMeliousTranscriptionModel(
          'mistral/voxtral-mini-transcribe',
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

    test('isMeliousChatAudioModel matches Voxtral model IDs', () {
      expect(
        MeliousInferenceRepository.isMeliousChatAudioModel(
          'voxtral-small-24b-2507',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousChatAudioModel(
          'MISTRAL/VOXTRAL-SMALL-LATEST',
        ),
        isTrue,
      );
      expect(
        MeliousInferenceRepository.isMeliousChatAudioModel(
          'openai/whisper-large-v3',
        ),
        isFalse,
      );
      expect(
        MeliousInferenceRepository.isMeliousChatAudioModel(
          'mistral/voxtral-mini-transcribe',
        ),
        isFalse,
      );
    });

    test(
      'listModels falls back to top-level capabilities and metadata key',
      () async {
        final repository = MeliousInferenceRepository(
          httpClient: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'custom-metadata-model',
                    'owned_by': 'custom',
                    // Top-level capabilities with no capabilities inside
                    // `metadata` forces the capability fallback path.
                    'capabilities': {
                      'function_calling': true,
                      'reasoning': true,
                    },
                    // `metadata` (not `_meta`) forces the alternate metadata key
                    // in both the model mapping and the description builder.
                    'metadata': {
                      'type': 'chat',
                      'input_modalities': ['text'],
                      'output_modalities': ['text'],
                      'context_length': 8192,
                    },
                  },
                ],
              }),
              200,
            );
          }),
        );
        addTearDown(repository.close);

        final model = (await repository.listModels(
          baseUrl: baseUrl,
          apiKey: apiKey,
        )).single;

        expect(model.providerModelId, 'custom-metadata-model');
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.isReasoningModel, isTrue);
        expect(model.description, contains('Context: 8192 tokens'));
      },
    );

    test('listModels logs rich, clipped summaries for malformed rows', () async {
      // A row that throws (no string id) but still carries `_meta.capabilities`
      // and a >800-character JSON body exercises the metaKeys/capabilityKeys
      // branches and the clip path of the catalog-row error summary logger.
      final repository = MeliousInferenceRepository(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'object': 'model',
                  '_meta': {
                    'capabilities': {
                      'padding': 'x' * 900,
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

      await expectLater(
        repository.listModels(baseUrl: baseUrl, apiKey: apiKey),
        throwsA(
          isA<MeliousInferenceException>().having(
            (e) => e.message,
            'message',
            contains('Melious model entry is missing a string id'),
          ),
        ),
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

  group('non-streaming impact path', () {
    const baseUrl = 'https://api.melious.ai/v1';
    const apiKey = 'key';

    MeliousInferenceRepository repositoryWith(MockClientHandler handler) {
      final repository = MeliousInferenceRepository(
        httpClient: MockClient(handler),
      );
      addTearDown(repository.close);
      return repository;
    }

    Future<List<CreateChatCompletionStreamResponse>> collectChat(
      MeliousInferenceRepository repository,
      InferenceImpactCollector collector, {
      String model = 'glm-5.2',
      ReasoningEffort? reasoningEffort,
    }) {
      return repository
          .generateTextWithMessages(
            messages: const [
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.string('hi'),
              ),
            ],
            model: model,
            baseUrl: baseUrl,
            apiKey: apiKey,
            reasoningEffort: reasoningEffort,
            impactCollector: collector,
          )
          .toList();
    }

    String contentOf(List<CreateChatCompletionStreamResponse> chunks) {
      return chunks
          .expand(
            (c) => c.choices ?? const <ChatCompletionStreamResponseChoice>[],
          )
          .map((ch) => ch.delta?.content ?? '')
          .join();
    }

    List<ChatCompletionStreamMessageToolCallChunk> toolCallsOf(
      List<CreateChatCompletionStreamResponse> chunks,
    ) {
      return chunks
          .expand(
            (c) => c.choices ?? const <ChatCompletionStreamResponseChoice>[],
          )
          .expand(
            (ch) =>
                ch.delta?.toolCalls ??
                const <ChatCompletionStreamMessageToolCallChunk>[],
          )
          .toList();
    }

    test(
      'generateTextWithMessages with a collector issues a non-streaming '
      'request, returns a synthetic chunk, and records impact',
      () async {
        late http.Request captured;
        final repo = repositoryWith((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Hello world'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 1000,
                'completion_tokens': 500,
                'total_tokens': 1500,
                'cached_tokens': 100,
                'completion_tokens_details': {'reasoning_tokens': 250},
              },
              'environment_impact': {
                'energy_kwh': 0.0003,
                'carbon_g_co2': 0.12,
                'water_liters': 0.01,
                'location': 'FI',
                'provider_id': 'nebius',
                'renewable_percent': 100,
                'pue': 1.1,
              },
              'billing_cost': {'credits': 0.002},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final collector = InferenceImpactCollector();
        final chunks = await collectChat(
          repo,
          collector,
          reasoningEffort: ReasoningEffort.high,
        );

        // A non-streaming POST to /chat/completions was issued.
        expect(captured.url.path, endsWith('/chat/completions'));
        final requestBody = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(requestBody['stream'], false);
        expect(requestBody['reasoning_effort'], 'high');

        // Content is assembled from the delta; usage rides the trailing chunk.
        expect(contentOf(chunks), 'Hello world');
        final usage = chunks.firstWhere((c) => c.usage != null).usage!;
        expect(usage.promptTokens, 1000);
        expect(usage.completionTokens, 500);
        expect(usage.promptTokensDetails?.cachedTokens, 100);
        expect(usage.completionTokensDetails?.reasoningTokens, 250);

        // Impact surfaced via the side-channel.
        expect(collector.impact, isNotNull);
        expect(collector.impact!.energyKwh, 0.0003);
        expect(collector.impact!.costCredits, 0.002);
        expect(collector.impact!.dataCenter, 'FI');
        expect(collector.impact!.renewablePercent, 100);
      },
    );

    test('parses tool calls into the synthetic chunk', () async {
      final repo = repositoryWith((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {
                        'name': 'do_thing',
                        'arguments': '{"x":1}',
                      },
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
          }),
          200,
        );
      });

      final collector = InferenceImpactCollector();
      final chunks = await collectChat(repo, collector, model: 'm');

      final toolCalls = toolCallsOf(chunks);
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.id, 'call_1');
      expect(toolCalls.first.function?.name, 'do_thing');
      expect(toolCalls.first.function?.arguments, '{"x":1}');
      // No impact block in the response → collector stays empty.
      expect(collector.impact, isNull);
    });

    test(
      'generateText with a collector routes through the non-streaming path',
      () async {
        late http.Request captured;
        final repo = repositoryWith((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'non-streaming reply'},
                },
              ],
            }),
            200,
          );
        });

        final chunks = await repo
            .generateText(
              prompt: 'Say hello',
              model: 'glm-5.2',
              baseUrl: baseUrl,
              apiKey: apiKey,
              systemMessage: 'Be concise.',
              impactCollector: InferenceImpactCollector(),
            )
            .toList();

        expect(captured.url.path, endsWith('/chat/completions'));
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['stream'], false);
        final messages = body['messages'] as List<dynamic>;
        expect(messages, hasLength(2));
        expect((messages.first as Map)['role'], 'system');
        expect((messages.last as Map)['role'], 'user');

        expect(contentOf(chunks), 'non-streaming reply');
        expect(chunks.single.id, startsWith('melious-chat-'));
        expect(
          chunks.single.usage,
          isNull,
          reason: 'no usage in the response → no trailing usage chunk',
        );
      },
    );

    test(
      'generateWithImages with a collector routes through the '
      'non-streaming path',
      () async {
        late http.Request captured;
        final repo = repositoryWith((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'vision reply'},
                },
              ],
            }),
            200,
          );
        });

        final chunks = await repo
            .generateWithImages(
              prompt: 'Describe this image',
              model: 'gemma-4-26b-a4b',
              baseUrl: baseUrl,
              apiKey: apiKey,
              images: const ['abc123'],
              impactCollector: InferenceImpactCollector(),
            )
            .toList();

        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['stream'], false);
        expect(captured.body, contains('data:image/jpeg;base64,abc123'));
        expect(contentOf(chunks), 'vision reply');
      },
    );

    test(
      'wraps an HTTP timeout in a MeliousInferenceException without '
      'real waiting',
      () async {
        var calls = 0;
        final repo = repositoryWith((_) async {
          calls++;
          throw TimeoutException('simulated hang');
        });

        await expectLater(
          collectChat(repo, InferenceImpactCollector()),
          throwsA(
            isA<MeliousInferenceException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Melious chat completion request timed out',
                )
                .having(
                  (e) => e.originalError,
                  'originalError',
                  isA<TimeoutException>(),
                )
                .having((e) => e.statusCode, 'statusCode', isNull),
          ),
        );
        expect(calls, 1);
      },
    );

    test(
      'surfaces provider error messages with the HTTP status code',
      () async {
        final repo = repositoryWith((_) async {
          return http.Response(
            jsonEncode({
              'error': {'message': 'model overloaded'},
            }),
            503,
          );
        });

        await expectLater(
          collectChat(repo, InferenceImpactCollector()),
          throwsA(
            isA<MeliousInferenceException>()
                .having((e) => e.message, 'message', 'model overloaded')
                .having((e) => e.statusCode, 'statusCode', 503),
          ),
        );
      },
    );

    test(
      'wraps malformed, non-object, and transport-failure responses',
      () async {
        final malformed = repositoryWith((_) async => http.Response('{', 200));
        await expectLater(
          collectChat(malformed, InferenceImpactCollector()),
          throwsA(
            isA<MeliousInferenceException>().having(
              (e) => e.message,
              'message',
              'Melious chat completion response was not valid JSON',
            ),
          ),
        );

        final nonObject = repositoryWith(
          (_) async => http.Response(jsonEncode([1, 2, 3]), 200),
        );
        await expectLater(
          collectChat(nonObject, InferenceImpactCollector()),
          throwsA(
            isA<MeliousInferenceException>().having(
              (e) => e.message,
              'message',
              'Melious chat completion response must be a JSON object',
            ),
          ),
        );

        final failing = repositoryWith(
          (_) async => throw Exception('connection reset'),
        );
        await expectLater(
          collectChat(failing, InferenceImpactCollector()),
          throwsA(
            isA<MeliousInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Failed to complete Melious chat'),
            ),
          ),
        );
      },
    );

    test('coerces malformed tool calls and string token counts', () async {
      final repo = repositoryWith((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'tool_calls': [
                    'not-a-map',
                    {'type': 'function'},
                    {
                      'id': 7,
                      'function': {'name': 99, 'arguments': 42},
                    },
                  ],
                },
              },
            ],
            'usage': {
              'prompt_tokens': '12',
              'completion_tokens': 8.9,
              'cached_tokens': 'not-a-number',
            },
          }),
          200,
        );
      });

      final chunks = await collectChat(repo, InferenceImpactCollector());

      final toolCalls = toolCallsOf(chunks);
      expect(
        toolCalls,
        hasLength(2),
        reason: 'the non-map entry is skipped',
      );
      expect(
        toolCalls.first.index,
        1,
        reason: 'skipped entries keep their slot in the index sequence',
      );
      expect(toolCalls.first.id, 'tool_1');
      expect(toolCalls.first.function?.name, isNull);
      expect(toolCalls.first.function?.arguments, '');
      expect(toolCalls.last.index, 2);
      expect(toolCalls.last.id, 'tool_2');
      expect(toolCalls.last.function?.name, isNull);
      expect(toolCalls.last.function?.arguments, '');

      final usage = chunks.firstWhere((c) => c.usage != null).usage!;
      expect(usage.promptTokens, 12, reason: 'string counts are coerced');
      expect(
        usage.completionTokens,
        8,
        reason: 'fractional counts are truncated',
      );
      expect(
        usage.totalTokens,
        20,
        reason: 'missing total falls back to prompt + completion',
      );
      expect(
        usage.promptTokensDetails,
        isNull,
        reason: 'unparseable cached_tokens yields no details block',
      );
    });

    test(
      'yields an empty synthetic chunk for responses without usable choices',
      () async {
        final payloads = <Map<String, Object?>>[
          <String, Object?>{},
          {'choices': <Object?>[]},
          {
            'choices': ['not-a-map'],
          },
          {
            'choices': [
              {'message': 'not-a-map'},
            ],
          },
          {
            'choices': [
              {
                'message': {'content': 42},
              },
            ],
          },
        ];

        for (final payload in payloads) {
          final repo = repositoryWith(
            (_) async => http.Response(jsonEncode(payload), 200),
          );
          final chunks = await collectChat(repo, InferenceImpactCollector());

          expect(
            chunks,
            hasLength(1),
            reason: 'no usage → no trailing chunk for $payload',
          );
          final delta = chunks.single.choices!.single.delta!;
          expect(delta.content, isNull, reason: 'payload: $payload');
          expect(delta.toolCalls, isNull, reason: 'payload: $payload');
        }
      },
    );
  });
}
