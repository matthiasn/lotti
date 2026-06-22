import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/melious_inference_repository.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:openai_dart/openai_dart.dart';

class _StreamingChatServer {
  _StreamingChatServer({
    required this.baseUrl,
    required this.body,
    required this.dispose,
  });

  final String baseUrl;
  final Future<Map<String, dynamic>> body;
  final Future<void> Function() dispose;
}

Future<_StreamingChatServer> _startStreamingChatServer({
  String content = 'melious response',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final bodyCompleter = Completer<Map<String, dynamic>>();

  final subscription = server.listen((request) async {
    expect(request.method, equals('POST'));
    expect(request.uri.path, equals('/v1/chat/completions'));
    expect(
      request.headers.value('authorization'),
      equals('Bearer sk-mel-test'),
    );

    final rawBody = await utf8.decoder.bind(request).join();
    bodyCompleter.complete(jsonDecode(rawBody) as Map<String, dynamic>);

    final chunk = {
      'id': 'chatcmpl-melious-test',
      'object': 'chat.completion.chunk',
      'created': 1710460800,
      'model': 'test-model',
      'choices': [
        {
          'index': 0,
          'delta': {'content': content},
          'finish_reason': null,
        },
      ],
    };

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType('text', 'event-stream')
      ..write('data: ${jsonEncode(chunk)}\n\n')
      ..write('data: [DONE]\n\n');
    await request.response.close();
  });

  return _StreamingChatServer(
    baseUrl: 'http://${server.address.host}:${server.port}/v1',
    body: bodyCompleter.future,
    dispose: () async {
      await subscription.cancel();
      await server.close(force: true);
    },
  );
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
      final server = await _startStreamingChatServer();
      addTearDown(server.dispose);
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      final chunks = await repository
          .generateText(
            prompt: 'Say hello',
            model: 'minimax-m2.7',
            baseUrl: server.baseUrl,
            apiKey: apiKey,
            systemMessage: 'Be concise.',
            temperature: 0.2,
            maxCompletionTokens: 128,
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'melious response');

      final body = await server.body;
      expect(body['model'], equals('minimax-m2.7'));
      expect(body['stream'], isTrue);
      expect(body['temperature'], equals(0.2));
      expect(body['max_completion_tokens'], equals(128));
      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      expect(messages.first, containsPair('role', 'system'));
      expect(messages.last, containsPair('role', 'user'));
      expect(messages.last, containsPair('content', 'Say hello'));
    });

    test(
      'generateTextWithMessages forwards conversation history to Melious',
      () async {
        final server = await _startStreamingChatServer(
          content: 'history response',
        );
        addTearDown(server.dispose);
        final repository = MeliousInferenceRepository();
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
              baseUrl: server.baseUrl,
              apiKey: apiKey,
              maxCompletionTokens: 256,
            )
            .toList();

        expect(
          chunks.single.choices?.single.delta?.content,
          'history response',
        );

        final body = await server.body;
        expect(body['model'], equals('deepseek-v4-pro'));
        expect(body['max_completion_tokens'], equals(256));
        final messages = body['messages'] as List<dynamic>;
        expect(messages, hasLength(2));
        expect(messages.first, containsPair('role', 'system'));
        expect(messages.last, containsPair('content', 'Previous user turn'));
      },
    );

    test('generateWithImages sends multimodal message parts', () async {
      final server = await _startStreamingChatServer(
        content: 'vision response',
      );
      addTearDown(server.dispose);
      final repository = MeliousInferenceRepository();
      addTearDown(repository.close);

      final chunks = await repository
          .generateWithImages(
            prompt: 'Describe this image',
            model: 'gemma-4-26b-a4b',
            baseUrl: server.baseUrl,
            apiKey: apiKey,
            images: const ['abc123'],
            systemMessage: 'Use visual evidence only.',
          )
          .toList();

      expect(chunks.single.choices?.single.delta?.content, 'vision response');

      final body = await server.body;
      expect(body['model'], equals('gemma-4-26b-a4b'));
      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      final userMessage = messages.last as Map<String, dynamic>;
      final content = userMessage['content'] as List<dynamic>;
      expect(content.first, containsPair('type', 'text'));
      expect(content.first, containsPair('text', 'Describe this image'));
      final imagePart = content.last as Map<String, dynamic>;
      expect(imagePart, containsPair('type', 'image_url'));
      expect(
        imagePart['image_url'],
        containsPair('url', 'data:image/jpeg;base64,abc123'),
      );
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
    });
  });
}
