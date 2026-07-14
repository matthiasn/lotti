// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import 'sse_test_utils.dart';

void main() {
  late MistralInferenceRepository repository;
  late MockHttpClient mockHttpClient;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(FakeRequest());
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(Uri.parse('https://api.mistral.ai/v1'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = MistralInferenceRepository(httpClient: mockHttpClient);
  });

  group('MistralInferenceRepository', () {
    group('chat audio', () {
      final modelCases = <String, bool>{
        'voxtral-mini-latest': true,
        'voxtral-small-latest': true,
        'voxtral-mini-2507': true,
        'voxtral-small-2507': true,
        'voxtral-small-24b-2507': true,
        'voxtral-mini-transcribe-2602': false,
        'voxtral-mini-transcribe-realtime-2602': false,
        'voxtral-mini-tts-2603': false,
        'voxtral-mini-2602': false,
        'mistral-small-latest': false,
      };
      for (final MapEntry(key: model, value: expected) in modelCases.entries) {
        test('classifies $model as chatAudio=$expected', () {
          expect(
            MistralInferenceRepository.isMistralChatAudioModel(model),
            expected,
          );
        });
      }

      test('sends Mistral base64 MP3 shape and removes the file', () async {
        late http.Request capturedRequest;
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'lotti_mistral_chat_audio_test_',
        );
        addTearDown(() => temporaryDirectory.delete(recursive: true));
        final mp3File = File('${temporaryDirectory.path}/request.mp3')
          ..writeAsBytesSync([0x49, 0x44, 0x33, 7]);
        final client = MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Mistral transcript'},
                },
              ],
            }),
            200,
          );
        });
        final chatRepository = MistralInferenceRepository(
          httpClient: client,
          audioToTemporaryMp3Encoder: (_) async => mp3File,
        );
        addTearDown(chatRepository.close);

        final chunks = await chatRepository
            .transcribeChatAudio(
              model: 'voxtral-mini-latest',
              audioBase64: base64Encode([1, 2, 3]),
              baseUrl: 'https://api.mistral.ai/v1',
              apiKey: 'mistral-key',
              prompt: 'Transcribe with context.',
              maxCompletionTokens: 1024,
            )
            .toList();

        expect(mp3File.existsSync(), isFalse);
        expect(capturedRequest.url.path, '/v1/chat/completions');
        final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
        expect(body.containsKey('request_id'), isFalse);
        expect(body['stream'], isFalse);
        expect(body['max_tokens'], 1024);
        final messages = body['messages']! as List<dynamic>;
        final message = messages.single as Map<String, dynamic>;
        final content = message['content']! as List<dynamic>;
        expect(content, [
          {
            'type': 'input_audio',
            'input_audio': base64Encode([0x49, 0x44, 0x33, 7]),
          },
          {'type': 'text', 'text': 'Transcribe with context.'},
        ]);
        expect(
          chunks.single.choices?.single.delta?.content,
          'Mistral transcript',
        );
      });
    });

    group('listModels', () {
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'mistral-key';

      // Builds a repository whose `/models` GET is served by [handler].
      MistralInferenceRepository repoWithHandler(
        Future<http.Response> Function(http.Request request) handler,
      ) {
        final repo = MistralInferenceRepository(
          httpClient: MockClient(handler),
        );
        addTearDown(repo.close);
        return repo;
      }

      // Builds a repository that returns [body] with [status] for `/models`.
      MistralInferenceRepository repoReturning(
        Object? body, {
        int status = 200,
      }) {
        return repoWithHandler(
          (_) async => http.Response(
            body is String ? body : jsonEncode(body),
            status,
          ),
        );
      }

      // Fetches the single mapped model for a one-row catalog payload.
      Future<KnownModel> mapSingle(Map<String, dynamic> row) async {
        final models = await repoReturning({
          'data': [row],
        }).listModels(baseUrl: baseUrl, apiKey: apiKey);
        return models.single;
      }

      group('argument validation', () {
        test('rejects a blank base URL', () async {
          await expectLater(
            repoReturning(const {'data': <Map<String, dynamic>>[]}).listModels(
              baseUrl: '   ',
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'Base URL cannot be empty',
              ),
            ),
          );
        });

        test('rejects a blank API key', () async {
          await expectLater(
            repoReturning(const {'data': <Map<String, dynamic>>[]}).listModels(
              baseUrl: baseUrl,
              apiKey: '  ',
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'API key cannot be empty',
              ),
            ),
          );
        });

        test('rejects a malformed base URL before requesting', () async {
          await expectLater(
            repoReturning(const {'data': <Map<String, dynamic>>[]}).listModels(
              baseUrl: 'http://[invalid',
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>()
                  // The raw base URL must NOT be echoed back (it can carry
                  // userinfo/query secrets).
                  .having(
                    (e) => e.message,
                    'message',
                    'Invalid Mistral base URL',
                  )
                  .having(
                    (e) => e.message,
                    'no url leak',
                    isNot(contains('[')),
                  ),
            ),
          );
        });
      });

      group('request shape', () {
        test('sends bearer auth to the /models endpoint', () async {
          late http.Request captured;
          final repo = repoWithHandler((request) async {
            captured = request;
            return http.Response(
              jsonEncode(const {'data': <Map<String, dynamic>>[]}),
              200,
            );
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
          final models = await repoReturning([
            {'id': 'mistral-medium-latest'},
          ]).listModels(baseUrl: baseUrl, apiKey: apiKey);

          expect(models.single.providerModelId, 'mistral-medium-latest');
        });
      });

      group('capability mapping', () {
        test('maps a live chat+vision row with rich metadata', () async {
          final model = await mapSingle({
            'id': 'mistral-medium-2999',
            'owned_by': 'mistralai',
            'max_context_length': 131072,
            'capabilities': {
              'completion_chat': true,
              'vision': true,
              'function_calling': true,
            },
          });

          expect(model.name, 'Mistral Medium 2999');
          expect(model.inputModalities, [Modality.text, Modality.image]);
          expect(model.outputModalities, [Modality.text]);
          expect(model.supportsFunctionCalling, isTrue);
          expect(model.isReasoningModel, isFalse);
          expect(model.description, contains('Context: 131072 tokens'));
          // Capabilities that render as chips (vision) are NOT duplicated in
          // the description; only chip-less extras (tools) are listed.
          expect(model.description, contains('Features: tools'));
          expect(model.description, isNot(contains('vision')));
          expect(model.description, isNot(contains('Owned by')));
        });

        test('treats Voxtral ids as audio transcription models', () async {
          final model = await mapSingle({
            'id': 'voxtral-small-2999',
            'capabilities': {'completion_chat': true, 'vision': true},
          });

          // The transcription branch wins and short-circuits vision.
          expect(model.inputModalities, [Modality.audio]);
          expect(model.outputModalities, [Modality.text]);
        });

        test('honours an explicit audio capability flag', () async {
          final model = await mapSingle({
            'id': 'some-speech-model',
            'capabilities': {'audio': true},
          });

          expect(model.inputModalities, [Modality.audio]);
          expect(model.outputModalities, [Modality.text]);
        });

        test('honours an audio_transcription capability flag', () async {
          final model = await mapSingle({
            'id': 'another-speech-model',
            'capabilities': {'audio_transcription': true},
          });

          expect(model.inputModalities, [Modality.audio]);
        });

        test('adds image input for OCR-capable models', () async {
          final model = await mapSingle({
            'id': 'pixtral-ocr-2999',
            'capabilities': {'ocr': true},
          });

          expect(model.inputModalities, [Modality.text, Modality.image]);
          expect(model.description, contains('OCR'));
        });

        test('adds image input from the document_ocr flag', () async {
          final model = await mapSingle({
            'id': 'doc-reader-2999',
            'capabilities': {'document_ocr': true},
          });

          expect(model.inputModalities, contains(Modality.image));
          expect(model.description, contains('OCR'));
        });

        test('infers OCR from the model id when no flag is present', () async {
          final model = await mapSingle({
            'id': 'mistral-ocr-latest',
            'capabilities': {'completion_chat': true},
          });

          expect(model.name, 'Mistral OCR Latest');
          expect(model.inputModalities, contains(Modality.image));
        });

        test('flags reasoning models by id heuristic', () async {
          final model = await mapSingle({
            'id': 'magistral-small-2999',
            'capabilities': {'completion_chat': true},
          });

          expect(model.name, 'Magistral Small 2999');
          expect(model.isReasoningModel, isTrue);
        });

        test('flags reasoning models from the capability flag', () async {
          final model = await mapSingle({
            'id': 'thinker-2999',
            'capabilities': {'reasoning': true},
          });

          expect(model.isReasoningModel, isTrue);
          // 'reasoning' is shown as the Thinking chip, not duplicated in prose.
          expect(model.description, isNot(contains('reasoning')));
        });

        test(
          'lists only chip-less features and parses string context',
          () async {
            final model = await mapSingle({
              'id': 'kitchen-sink-2999',
              'max_context_length': '256000',
              'capabilities': {
                'vision': true,
                'ocr': true,
                'audio_transcription': false,
                'reasoning': true,
                'function_calling': true,
                'completion_fim': true,
                'classification': true,
                'fine_tuning': true,
              },
            });

            expect(model.description, contains('Context: 256000 tokens'));
            // vision + reasoning are chips and must NOT appear in the prose;
            // only the chip-less extras remain.
            expect(
              model.description,
              contains(
                'Features: OCR, tools, fill-in-the-middle, '
                'classification, fine-tuning',
              ),
            );
            expect(model.description, isNot(contains('vision')));
            expect(model.description, isNot(contains('reasoning')));
          },
        );

        test(
          'description is empty when only chip capabilities are present',
          () async {
            final model = await mapSingle({'id': 'plain-2999'});

            expect(model.name, 'Plain 2999');
            expect(model.inputModalities, [Modality.text]);
            expect(model.outputModalities, [Modality.text]);
            expect(model.supportsFunctionCalling, isFalse);
            expect(model.description, isEmpty);
          },
        );
      });

      group('non-chat row filtering', () {
        Future<List<String>> idsFor(List<Map<String, dynamic>> rows) async {
          final models = await repoReturning({
            'data': rows,
          }).listModels(baseUrl: baseUrl, apiKey: apiKey);
          return models.map((m) => m.providerModelId).toList();
        }

        test(
          'drops chat-disabled rows with no other supported flow '
          '(embeddings/classification/moderation)',
          () async {
            final ids = await idsFor([
              {
                'id': 'mistral-embed',
                'capabilities': {'completion_chat': false},
              },
              {
                'id': 'mistral-moderation-latest',
                'capabilities': {
                  'completion_chat': false,
                  'classification': true,
                },
              },
              {
                'id': 'mistral-medium-2999',
                'capabilities': {'completion_chat': true},
              },
            ]);

            // Only the chat-capable row survives.
            expect(ids, ['mistral-medium-2999']);
          },
        );

        test(
          'keeps a chat-disabled row that still offers vision/OCR',
          () async {
            final ids = await idsFor([
              {
                'id': 'pixtral-vision-only-2999',
                'capabilities': {'completion_chat': false, 'vision': true},
              },
            ]);

            expect(ids, ['pixtral-vision-only-2999']);
          },
        );

        test('keeps rows that do not declare completion_chat at all', () async {
          final ids = await idsFor([
            {'id': 'legacy-model-2999'},
          ]);

          expect(ids, ['legacy-model-2999']);
        });

        test('never drops a curated model even if chat is disabled', () async {
          final ids = await idsFor([
            {
              'id': 'mistral-small-2501',
              'capabilities': {'completion_chat': false},
            },
          ]);

          expect(ids, ['mistral-small-2501']);
        });
      });

      group('truthy coercion', () {
        test('treats numeric and string flags as booleans', () async {
          // function_calling=1 (num), vision="true" (string) are both truthy;
          // ocr=0 and reasoning="nope" are both falsey.
          final model = await mapSingle({
            'id': 'coercion-2999',
            'capabilities': {
              'function_calling': 1,
              'vision': 'true',
              'ocr': 0,
              'reasoning': 'nope',
            },
          });

          expect(model.supportsFunctionCalling, isTrue);
          expect(model.inputModalities, contains(Modality.image));
          expect(model.isReasoningModel, isFalse);
        });
      });

      group('curated fallback', () {
        test('returns a curated entry verbatim when no live caps', () async {
          final curated = mistralModels.firstWhere(
            (m) => m.providerModelId == 'voxtral-mini-latest',
          );
          final model = await mapSingle({'id': 'voxtral-mini-latest'});

          expect(model.name, curated.name);
          expect(model.inputModalities, curated.inputModalities);
          expect(model.description, curated.description);
        });

        test('refines a curated entry when live caps are present', () async {
          // mistral-small-2501 ships as [text, image]; a live reasoning flag
          // upgrades it without dropping the curated modalities or the
          // hand-tuned name/description carried downstream by toAiConfigModel.
          final curated = mistralModels.firstWhere(
            (m) => m.providerModelId == 'mistral-small-2501',
          );
          final model = await mapSingle({
            'id': 'mistral-small-2501',
            'capabilities': {'reasoning': true},
          });

          expect(model.name, curated.name);
          expect(model.inputModalities, contains(Modality.image));
          expect(model.isReasoningModel, isTrue);
          // Curated metadata survives the live-capability refinement.
          expect(model.description, curated.description);
          expect(model.maxCompletionTokens, curated.maxCompletionTokens);
        });
      });

      group('display name derivation', () {
        test(
          'title-cases ids, preserves acronyms and numeric tokens',
          () async {
            expect(
              (await mapSingle({'id': 'ministral-3b-latest'})).name,
              'Ministral 3B Latest',
            );
            expect(
              (await mapSingle({'id': 'provider/codestral-vl'})).name,
              'Codestral VL',
            );
          },
        );

        test('falls back to the raw id when no word survives', () async {
          final model = await mapSingle({'id': '___'});
          expect(model.name, '___');
        });
      });

      group('error handling', () {
        test('surfaces a structured error message with status', () async {
          await expectLater(
            repoReturning(
              const {
                'message': 'Unauthorized',
              },
              status: 401,
            ).listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>()
                  .having((e) => e.message, 'message', 'Unauthorized')
                  .having((e) => e.statusCode, 'statusCode', 401),
            ),
          );
        });

        test('reads a nested error.message object', () async {
          await expectLater(
            repoReturning(
              const {
                'error': {'message': 'Rate limited'},
              },
              status: 429,
            ).listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'Rate limited',
              ),
            ),
          );
        });

        test('reads a string error field', () async {
          await expectLater(
            repoReturning(
              const {'error': 'boom'},
              status: 500,
            ).listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'boom',
              ),
            ),
          );
        });

        test('falls back to the HTTP status for an empty body', () async {
          await expectLater(
            repoReturning('', status: 503).listModels(
              baseUrl: baseUrl,
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'Mistral API error (HTTP 503)',
              ),
            ),
          );
        });

        test('clips an overlong non-JSON error body', () async {
          final body = 'x' * 200;
          await expectLater(
            repoReturning(body, status: 500).listModels(
              baseUrl: baseUrl,
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                allOf(endsWith('…'), hasLength(161)),
              ),
            ),
          );
        });

        test('returns a short JSON body without a usable message', () async {
          await expectLater(
            repoReturning(const {'foo': 'bar'}, status: 500).listModels(
              baseUrl: baseUrl,
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                '{"foo":"bar"}',
              ),
            ),
          );
        });

        test('rejects a non-object, non-array payload', () async {
          await expectLater(
            repoReturning('"nope"').listModels(
              baseUrl: baseUrl,
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                contains('JSON object with data[]'),
              ),
            ),
          );
        });

        test('rejects a non-object catalog row', () async {
          await expectLater(
            repoReturning(const {
              'data': ['just-an-id'],
            }).listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'Mistral model entry must be a JSON object',
              ),
            ),
          );
        });

        test('rejects a row missing a string id', () async {
          await expectLater(
            repoReturning(const {
              'data': [
                {'id': 42},
              ],
            }).listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                'Mistral model entry is missing a string id',
              ),
            ),
          );
        });

        test('wraps invalid JSON responses', () async {
          await expectLater(
            repoReturning('not json {').listModels(
              baseUrl: baseUrl,
              apiKey: apiKey,
            ),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                contains('was not valid JSON'),
              ),
            ),
          );
        });

        test('wraps request timeouts', () async {
          final repo = repoWithHandler(
            (_) async => throw TimeoutException('slow'),
          );
          await expectLater(
            repo.listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                contains('timed out'),
              ),
            ),
          );
        });

        test('wraps unexpected transport errors', () async {
          final repo = repoWithHandler(
            (_) async => throw const _TransportFailure(),
          );
          await expectLater(
            repo.listModels(baseUrl: baseUrl, apiKey: apiKey),
            throwsA(
              isA<MistralInferenceException>().having(
                (e) => e.message,
                'message',
                contains('Failed to fetch Mistral models'),
              ),
            ),
          );
        });
      });
    });

    group('generateText', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';
      const prompt = 'Hello, how are you?';

      test('should generate text with streaming', () async {
        // Arrange
        const chunk1 = 'Hello!';
        const chunk2 = ' I am doing great.';
        final events = [
          createSseChunkEvent(content: chunk1, role: 'assistant'),
          createSseChunkEvent(content: chunk2),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(3));
        expect(results[0].choices?.first.delta?.content, equals(chunk1));
        expect(
          results[0].choices?.first.delta?.role,
          equals(ChatCompletionMessageRole.assistant),
        );
        expect(results[1].choices?.first.delta?.content, equals(chunk2));

        // Verify the request
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        expect(request.url.toString(), equals('$baseUrl/chat/completions'));
        expect(request.headers['Content-Type'], equals('application/json'));
        expect(request.headers['Accept'], equals('text/event-stream'));
        expect(request.headers['Authorization'], equals('Bearer $apiKey'));

        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['model'], equals(model));
        expect(requestBody['stream'], isTrue);

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(1));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('user'));
        expect(
          (messages[0] as Map<String, dynamic>)['content'],
          equals(prompt),
        );
      });

      test('should include system message when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          systemMessage: 'You are a helpful assistant.',
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final messages = requestBody['messages'] as List<dynamic>;
        expect(messages.length, equals(2));
        expect((messages[0] as Map<String, dynamic>)['role'], equals('system'));
        expect(
          (messages[0] as Map<String, dynamic>)['content'],
          equals('You are a helpful assistant.'),
        );
        expect((messages[1] as Map<String, dynamic>)['role'], equals('user'));
        expect(
          (messages[1] as Map<String, dynamic>)['content'],
          equals(prompt),
        );
      });

      test('should include temperature when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          temperature: 0.7,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['temperature'], equals(0.7));
      });

      test('should include maxCompletionTokens when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          maxCompletionTokens: 1000,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['max_tokens'], equals(1000));
      });

      test('should include tools when provided', () async {
        // Arrange
        final events = [
          createSseChunkEvent(
            toolCalls: [
              {
                'id': 'call_123',
                'index': 0,
                'function': {
                  'name': 'get_weather',
                  'arguments': '{"location": "Paris"}',
                },
              },
            ],
          ),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final tools = [
          const ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: 'get_weather',
              description: 'Get the weather for a location',
              parameters: {
                'type': 'object',
                'properties': {
                  'location': {'type': 'string'},
                },
                'required': ['location'],
              },
            ),
          ),
        ];

        // Act
        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          tools: tools,
        );

        final results = await stream.toList();

        // Assert - verify tool calls are parsed
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.toolCalls, isNotNull);
        expect(results[0].choices?.first.delta?.toolCalls?.length, equals(1));
        expect(
          results[0].choices?.first.delta?.toolCalls?.first.id,
          equals('call_123'),
        );
        expect(
          results[0].choices?.first.delta?.toolCalls?.first.function?.name,
          equals('get_weather'),
        );

        // Verify request body includes tools
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['tools'], isNotNull);
        expect(requestBody['tool_choice'], equals('auto'));
      });

      test('should serialize forced named tool choice when provided', () async {
        final events = [
          createSseChunkEvent(content: 'Planned'),
          createSseFinalEvent(),
        ];
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        const tools = [
          ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(name: 'draft_day_plan'),
          ),
        ];
        const toolChoice = ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(name: 'draft_day_plan'),
          ),
        );

        final stream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          tools: tools,
          toolChoice: toolChoice,
        );

        await stream.toList();

        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['tool_choice'], {
          'type': 'function',
          'function': {'name': 'draft_day_plan'},
        });
      });

      test(
        'serializes each tool-choice mode to its Mistral spelling',
        () async {
          const expected = {
            ChatCompletionToolChoiceMode.none: 'none',
            ChatCompletionToolChoiceMode.auto: 'auto',
            // Mistral forces a tool call with `any`, not OpenAI's `required`.
            ChatCompletionToolChoiceMode.required: 'any',
          };

          for (final mode in expected.keys) {
            when(() => mockHttpClient.send(any())).thenAnswer(
              (_) async => createSseStreamedResponse(
                events: [
                  createSseChunkEvent(content: 'ok'),
                  createSseFinalEvent(),
                ],
              ),
            );

            await repository
                .generateText(
                  prompt: prompt,
                  model: model,
                  baseUrl: baseUrl,
                  apiKey: apiKey,
                  tools: const [
                    ChatCompletionTool(
                      type: ChatCompletionToolType.function,
                      function: FunctionObject(name: 'draft_day_plan'),
                    ),
                  ],
                  toolChoice: ChatCompletionToolChoiceOption.mode(mode),
                )
                .toList();
          }

          final sent = verify(() => mockHttpClient.send(captureAny())).captured
              .cast<http.Request>()
              .map(
                (r) =>
                    (jsonDecode(r.body) as Map<String, dynamic>)['tool_choice'],
              )
              .toList();
          expect(sent, expected.values.toList());
        },
      );

      test('should handle HTTP error responses', () async {
        // Arrange
        final stream = Stream.fromIterable([
          utf8.encode('{"error": "Invalid API key"}'),
        ]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 401),
        );

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(
          responseStream.toList(),
          throwsA(
            isA<MistralInferenceException>()
                .having((e) => e.message, 'message', contains('HTTP 401'))
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('should handle 404 error', () async {
        // Arrange
        final stream = Stream.fromIterable([
          utf8.encode('{"message": "no Route matched with those values"}'),
        ]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 404),
        );

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: prompt,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(
          responseStream.toList(),
          throwsA(
            isA<MistralInferenceException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      });
    });

    group('generateTextWithMessages', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should convert system messages correctly', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(2));
        expect((reqMessages[0] as Map)['role'], equals('system'));
        expect(
          (reqMessages[0] as Map)['content'],
          equals('You are a helpful assistant.'),
        );
        expect((reqMessages[1] as Map)['role'], equals('user'));
        expect((reqMessages[1] as Map)['content'], equals('Hello'));
      });

      test('serializes reasoning effort for supported models', () async {
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final stream = repository.generateTextWithMessages(
          messages: const [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('Hello'),
            ),
          ],
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
          reasoningEffort: ReasoningEffort.high,
        );

        await stream.toList();

        final request =
            verify(
                  () => mockHttpClient.send(captureAny()),
                ).captured.single
                as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody, isNot(contains('reasoning_effort')));
      });

      test('should convert assistant messages with tool calls', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('What is 2+2?'),
          ),
          const ChatCompletionMessage.assistant(
            content: 'Let me calculate that.',
            toolCalls: [
              ChatCompletionMessageToolCall(
                id: 'call_123',
                type: ChatCompletionMessageToolCallType.function,
                function: ChatCompletionMessageFunctionCall(
                  name: 'calculate',
                  arguments: '{"expression": "2+2"}',
                ),
              ),
            ],
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(2));

        final assistantMsg = reqMessages[1] as Map<String, dynamic>;
        expect(assistantMsg['role'], equals('assistant'));
        expect(assistantMsg['content'], equals('Let me calculate that.'));
        expect(assistantMsg['tool_calls'], isNotNull);
        expect((assistantMsg['tool_calls'] as List).length, equals(1));

        final toolCall =
            (assistantMsg['tool_calls'] as List).first as Map<String, dynamic>;
        expect(toolCall['id'], equals('call_123'));
        final function = toolCall['function'] as Map<String, dynamic>;
        expect(function['name'], equals('calculate'));
      });

      test('should convert tool messages correctly', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'The answer is 4'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.tool(
            toolCallId: 'call_123',
            content: '4',
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(1));

        final toolMsg = reqMessages[0] as Map<String, dynamic>;
        expect(toolMsg['role'], equals('tool'));
        expect(toolMsg['tool_call_id'], equals('call_123'));
        expect(toolMsg['content'], equals('4'));
      });

      test(
        'should convert user message with text/image/audio content parts',
        () async {
          // Arrange
          final events = [
            createSseChunkEvent(content: 'Response'),
            createSseFinalEvent(),
          ];

          when(() => mockHttpClient.send(any())).thenAnswer(
            (_) async => createSseStreamedResponse(events: events),
          );

          final messages = [
            const ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.parts([
                ChatCompletionMessageContentPart.text(text: 'Describe this'),
                ChatCompletionMessageContentPart.image(
                  imageUrl: ChatCompletionMessageImageUrl(
                    url: 'https://example.com/cat.png',
                  ),
                ),
                ChatCompletionMessageContentPart.audio(
                  inputAudio: ChatCompletionMessageInputAudio(
                    data: 'AAAA',
                    format: ChatCompletionMessageInputAudioFormat.wav,
                  ),
                ),
              ]),
            ),
          ];

          // Act
          final stream = repository.generateTextWithMessages(
            messages: messages,
            model: model,
            baseUrl: baseUrl,
            apiKey: apiKey,
          );

          await stream.toList();

          // Assert - each content part is serialized to the expected map shape
          final captured = verify(
            () => mockHttpClient.send(captureAny()),
          ).captured;
          final request = captured.first as http.Request;
          final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

          final reqMessages = requestBody['messages'] as List<dynamic>;
          expect(reqMessages.length, equals(1));

          final userMsg = reqMessages[0] as Map<String, dynamic>;
          expect(userMsg['role'], equals('user'));

          final content = userMsg['content'] as List<dynamic>;
          expect(content.length, equals(3));

          final textPart = content[0] as Map<String, dynamic>;
          expect(textPart['type'], equals('text'));
          expect(textPart['text'], equals('Describe this'));

          final imagePart = content[1] as Map<String, dynamic>;
          expect(imagePart['type'], equals('image_url'));
          expect(
            (imagePart['image_url'] as Map<String, dynamic>)['url'],
            equals('https://example.com/cat.png'),
          );

          final audioPart = content[2] as Map<String, dynamic>;
          expect(audioPart['type'], equals('input_audio'));
          final inputAudio = audioPart['input_audio'] as Map<String, dynamic>;
          expect(inputAudio['data'], equals('AAAA'));
          expect(inputAudio['format'], equals('wav'));
        },
      );

      test('should convert function messages correctly', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.function(
            name: 'get_weather',
            content: '{"temp": 21}',
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(1));

        final functionMsg = reqMessages[0] as Map<String, dynamic>;
        expect(functionMsg['role'], equals('function'));
        expect(functionMsg['name'], equals('get_weather'));
        expect(functionMsg['content'], equals('{"temp": 21}'));
      });

      test('should convert developer messages correctly', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Response'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        final messages = [
          const ChatCompletionMessage.developer(
            content: ChatCompletionDeveloperMessageContent.text(
              'Follow these rules',
            ),
          ),
        ];

        // Act
        final stream = repository.generateTextWithMessages(
          messages: messages,
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert - developer role and content are carried through
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final reqMessages = requestBody['messages'] as List<dynamic>;
        expect(reqMessages.length, equals(1));

        final developerMsg = reqMessages[0] as Map<String, dynamic>;
        expect(developerMsg['role'], equals('developer'));
        // The developer content is carried through as the freezed union map,
        // which serializes to a value/runtimeType pair.
        final developerContent =
            developerMsg['content'] as Map<String, dynamic>;
        expect(developerContent['value'], equals('Follow these rules'));
        expect(developerContent['runtimeType'], equals('text'));
      });
    });

    group('content extraction', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should handle content as string', () async {
        // Arrange
        final events = [
          createSseChunkEvent(content: 'Hello world'),
          createSseFinalEvent(),
        ];

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, equals('Hello world'));
      });

      test('should handle content as array of text parts', () async {
        // Arrange - content as array (Mistral's format for some responses)
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': [
                  {'type': 'text', 'text': 'Hello '},
                  {'type': 'text', 'text': 'world'},
                ],
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should concatenate text parts
        expect(results[0].choices?.first.delta?.content, equals('Hello world'));
      });

      test('should handle content as array of strings', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': ['Hello ', 'world'],
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, equals('Hello world'));
      });

      test('should handle null content', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'role': 'assistant',
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, isNull);
        expect(
          results[0].choices?.first.delta?.role,
          equals(ChatCompletionMessageRole.assistant),
        );
      });

      test('should handle empty array content', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': <dynamic>[],
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.content, isNull);
      });

      test('should stringify non-string, non-list content', () async {
        // Arrange - content arrives as a JSON number, hitting the
        // toString() fallback branch in _extractContent.
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'content': 42,
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - the numeric content is rendered via toString()
        expect(results[0].choices?.first.delta?.content, equals('42'));
      });

      test(
        'converts tool-response messages with tool_call_id and content',
        () async {
          final events = [
            createSseChunkEvent(content: 'Done'),
            createSseFinalEvent(),
          ];
          when(() => mockHttpClient.send(any())).thenAnswer(
            (_) async => createSseStreamedResponse(events: events),
          );

          final messages = [
            const ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('run tool'),
            ),
            const ChatCompletionMessage.tool(
              toolCallId: 'call-42',
              content: 'tool says hi',
            ),
          ];

          await repository
              .generateTextWithMessages(
                messages: messages,
                model: model,
                baseUrl: baseUrl,
                apiKey: apiKey,
              )
              .toList();

          final request =
              verify(() => mockHttpClient.send(captureAny())).captured.first
                  as http.Request;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final sent = (body['messages'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          final toolMsg = sent.singleWhere((m) => m['role'] == 'tool');
          expect(toolMsg['tool_call_id'], 'call-42');
          expect(toolMsg['content'], 'tool says hi');
        },
      );

      test('should handle multiple events in single chunk', () async {
        // Arrange
        final event1 = createSseChunkEvent(content: 'Chunk 1');
        final event2 = createSseChunkEvent(content: 'Chunk 2');
        final event3 = createSseChunkEvent(content: 'Chunk 3');

        final allInOne =
            'data: ${jsonEncode(event1)}\n\ndata: ${jsonEncode(event2)}\n\ndata: ${jsonEncode(event3)}\n\ndata: [DONE]\n\n';

        final stream = Stream.fromIterable([utf8.encode(allInOne)]);

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert
        expect(results.length, equals(3));
        expect(results[0].choices?.first.delta?.content, equals('Chunk 1'));
        expect(results[1].choices?.first.delta?.content, equals('Chunk 2'));
        expect(results[2].choices?.first.delta?.content, equals('Chunk 3'));
      });

      test('buffers an SSE event split across transport chunks', () async {
        final event =
            'data: ${jsonEncode(createSseChunkEvent(content: 'Split chunk'))}\n\n';
        final splitAt = event.length ~/ 2;
        final stream = Stream.fromIterable([
          utf8.encode(event.substring(0, splitAt)),
          utf8.encode(event.substring(splitAt)),
          utf8.encode('data: [DONE]\n\n'),
        ]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        final results = await repository
            .generateText(
              prompt: 'Hi',
              model: model,
              baseUrl: baseUrl,
              apiKey: apiKey,
            )
            .toList();

        expect(results, hasLength(1));
        expect(results.single.choices?.single.delta?.content, 'Split chunk');
      });

      test('should handle malformed SSE data gracefully', () async {
        // Arrange - mix valid and invalid SSE events
        const sseData = '''
data: {"id": "test", "choices": [{"delta": {"content": "Valid chunk"}, "index": 0}], "object": "chat.completion.chunk", "created": 1234}

data: invalid json here

data: {"id": "test", "choices": [{"delta": {"content": "Another valid"}, "index": 0}], "object": "chat.completion.chunk", "created": 1234}

data: [DONE]

''';

        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert - should skip invalid JSON and continue
        expect(results.length, equals(2));
        expect(results[0].choices?.first.delta?.content, equals('Valid chunk'));
        expect(
          results[1].choices?.first.delta?.content,
          equals('Another valid'),
        );
      });

      test('should handle empty stream', () async {
        // Arrange
        const sseData = 'data: [DONE]\n\n';
        final stream = Stream.fromIterable([utf8.encode(sseData)]);

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await responseStream.toList();

        // Assert
        expect(results, isEmpty);
      });

      test('should throw after exceeding the parse error threshold', () async {
        // Arrange - register a logger so the threshold branch also logs.
        final mockDomainLogger = MockDomainLogger();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..unregister<DomainLogger>()
              ..registerSingleton<DomainLogger>(mockDomainLogger);
          },
        );
        addTearDown(tearDownTestGetIt);
        when(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: any<String?>(named: 'subDomain'),
          ),
        ).thenReturn(null);

        // Five malformed data lines push parseErrorCount to the
        // maxParseErrors (5) threshold and trigger the throw.
        const sseData = '''
data: not valid json 1

data: not valid json 2

data: not valid json 3

data: not valid json 4

data: not valid json 5

''';
        final stream = Stream.fromIterable([utf8.encode(sseData)]);
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(stream, 200),
        );

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await expectLater(
          responseStream.toList(),
          throwsA(
            isA<MistralInferenceException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Too many parse errors'),
                )
                .having((e) => e.originalError, 'originalError', isNotNull),
          ),
        );

        // The threshold branch logs with the dedicated subDomain.
        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: isA<FormatException>()),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'parse_threshold_exceeded',
          ),
        ).called(1);
      });
    });

    group('URL construction', () {
      const model = 'magistral-medium-2509';
      const apiKey = 'test-api-key';

      test('should construct URL correctly without trailing slash', () async {
        // Arrange
        final events = [createSseChunkEvent(content: 'Test')];
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        expect(
          request.url.toString(),
          equals('https://api.mistral.ai/v1/chat/completions'),
        );
      });

      test('should construct URL correctly with trailing slash', () async {
        // Arrange
        final events = [createSseChunkEvent(content: 'Test')];
        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: events),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: 'https://api.mistral.ai/v1/',
          apiKey: apiKey,
        );

        await stream.toList();

        // Assert
        final captured = verify(
          () => mockHttpClient.send(captureAny()),
        ).captured;
        final request = captured.first as http.Request;
        expect(
          request.url.toString(),
          equals('https://api.mistral.ai/v1/chat/completions'),
        );
      });
    });

    group('tool call parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should parse single tool call', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'id': 'call_abc123',
                    'index': 0,
                    'function': {
                      'name': 'get_weather',
                      'arguments': '{"location": "Paris"}',
                    },
                  },
                ],
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'What is the weather?',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results.length, equals(1));
        final toolCalls = results[0].choices?.first.delta?.toolCalls;
        expect(toolCalls, isNotNull);
        expect(toolCalls?.length, equals(1));
        expect(toolCalls?.first.id, equals('call_abc123'));
        expect(toolCalls?.first.index, equals(0));
        expect(toolCalls?.first.function?.name, equals('get_weather'));
        expect(
          toolCalls?.first.function?.arguments,
          equals('{"location": "Paris"}'),
        );
      });

      test('should parse multiple tool calls', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {
                'tool_calls': [
                  {
                    'id': 'call_1',
                    'index': 0,
                    'function': {'name': 'tool_a', 'arguments': '{}'},
                  },
                  {
                    'id': 'call_2',
                    'index': 1,
                    'function': {'name': 'tool_b', 'arguments': '{}'},
                  },
                ],
              },
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Use both tools',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        final toolCalls = results[0].choices?.first.delta?.toolCalls;
        expect(toolCalls?.length, equals(2));
        expect(toolCalls?[0].function?.name, equals('tool_a'));
        expect(toolCalls?[1].function?.name, equals('tool_b'));
      });

      test('should handle null tool_calls', () async {
        // Arrange
        final event = createSseChunkEvent(content: 'Just text, no tools');

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].choices?.first.delta?.toolCalls, isNull);
      });
    });

    group('usage parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should parse usage from response', () async {
        // Arrange
        final event = createSseChunkEvent(
          content: 'Hello',
          usage: {
            'prompt_tokens': 10,
            'completion_tokens': 5,
            'total_tokens': 15,
          },
        );

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(results[0].usage, isNotNull);
        expect(results[0].usage?.promptTokens, equals(10));
        expect(results[0].usage?.completionTokens, equals(5));
        expect(results[0].usage?.totalTokens, equals(15));
      });
    });

    group('finish reason parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should parse stop finish reason', () async {
        // Arrange
        final event = createSseChunkEvent(
          content: 'Done',
          finishReason: 'stop',
        );

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(
          results[0].choices?.first.finishReason,
          equals(ChatCompletionFinishReason.stop),
        );
      });

      test('should parse tool_calls finish reason', () async {
        // Arrange
        final event = createSseChunkEvent(
          content: null,
          finishReason: 'tool_calls',
        );

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(
          results[0].choices?.first.finishReason,
          equals(ChatCompletionFinishReason.toolCalls),
        );
      });

      test('should fallback to stop for unknown finish reason', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'test'},
              'finish_reason': 'unknown_reason',
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should fallback to stop
        expect(
          results[0].choices?.first.finishReason,
          equals(ChatCompletionFinishReason.stop),
        );
      });
    });

    group('role parsing', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should fallback to assistant for unknown role', () async {
        // Arrange - an unrecognized role string should resolve to assistant
        // via the orElse branch.
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'role': 'totally_unknown_role', 'content': 'hi'},
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert
        expect(
          results[0].choices?.first.delta?.role,
          equals(ChatCompletionMessageRole.assistant),
        );
        expect(results[0].choices?.first.delta?.content, equals('hi'));
      });
    });

    group('edge cases', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';

      test('should handle null choices', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': null,
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should skip event with null choices
        expect(results, isEmpty);
      });

      test('should handle empty choices array', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': <dynamic>[],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should skip event with empty choices
        expect(results, isEmpty);
      });

      test('should handle null delta', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': null,
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should skip choice with null delta
        expect(results, isEmpty);
      });

      test('should generate fallback id when missing', () async {
        // Arrange
        final event = {
          'object': 'chat.completion.chunk',
          'created': 1234567890,
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'test'},
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should generate fallback id
        expect(results[0].id, startsWith('mistral-'));
      });

      test('should generate fallback created when missing', () async {
        // Arrange
        final event = {
          'id': 'chatcmpl-test',
          'object': 'chat.completion.chunk',
          'model': model,
          'choices': [
            {
              'index': 0,
              'delta': {'content': 'test'},
              'finish_reason': null,
            },
          ],
        };

        when(() => mockHttpClient.send(any())).thenAnswer(
          (_) async => createSseStreamedResponse(events: [event]),
        );

        // Act
        final stream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final results = await stream.toList();

        // Assert - should have a valid created timestamp
        expect(results[0].created, isPositive);
      });
    });

    group('MistralInferenceException', () {
      test('should format toString correctly', () {
        final exception = MistralInferenceException(
          'Test error',
          statusCode: 404,
          originalError: Exception('Original'),
        );

        expect(
          exception.toString(),
          equals('MistralInferenceException: Test error'),
        );
        expect(exception.message, equals('Test error'));
        expect(exception.statusCode, equals(404));
        expect(exception.originalError, isA<Exception>());
      });

      test('should work without optional parameters', () {
        final exception = MistralInferenceException('Simple error');

        expect(exception.message, equals('Simple error'));
        expect(exception.statusCode, isNull);
        expect(exception.originalError, isNull);
      });
    });

    group('exception logging with LoggingService', () {
      const model = 'magistral-medium-2509';
      const baseUrl = 'https://api.mistral.ai/v1';
      const apiKey = 'test-api-key';
      late MockDomainLogger mockDomainLogger;

      setUp(() async {
        mockDomainLogger = MockDomainLogger();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..unregister<DomainLogger>()
              ..registerSingleton<DomainLogger>(mockDomainLogger);
          },
        );
      });

      tearDown(tearDownTestGetIt);

      test('should log exception on unexpected error', () async {
        // Arrange
        when(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: any<String?>(named: 'subDomain'),
          ),
        ).thenReturn(null);

        when(
          () => mockHttpClient.send(any()),
        ).thenThrow(StateError('Unexpected error'));

        // Act & Assert
        final responseStream = repository.generateText(
          prompt: 'Hi',
          model: model,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        await expectLater(
          responseStream.toList(),
          throwsA(
            isA<MistralInferenceException>().having(
              (e) => e.message,
              'message',
              contains('Unexpected'),
            ),
          ),
        );

        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any<Object>(that: isA<StateError>()),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'unexpected',
          ),
        ).called(1);
      });
    });

    group('convertMessages', () {
      glados.Glados(
        glados.any.mistralMessagesScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'role and content survive conversion for every message kind',
        (scenario) {
          final repository = MistralInferenceRepository();
          final converted = repository.convertMessages(scenario.messages);

          expect(converted.length, scenario.messages.length);
          for (var i = 0; i < converted.length; i++) {
            scenario.verify(i, converted[i]);
          }
        },
        tags: 'glados',
      );
    });
  });
}

/// A generated list of [ChatCompletionMessage]s covering every supported
/// role variant, paired with per-message expectations for the converted map.
class _MistralMessagesScenario {
  _MistralMessagesScenario({required int count, required int seed})
    : _kinds = List.generate(count, (i) => (seed + i) % 5);

  final List<int> _kinds;

  List<ChatCompletionMessage> get messages => [
    for (var i = 0; i < _kinds.length; i++)
      switch (_kinds[i]) {
        0 => ChatCompletionMessage.system(content: 'sys $i'),
        1 => ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('hello $i'),
        ),
        2 => ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(text: 'part $i'),
            ChatCompletionMessageContentPart.image(
              imageUrl: ChatCompletionMessageImageUrl(url: 'http://img/$i'),
            ),
          ]),
        ),
        3 => ChatCompletionMessage.assistant(
          content: 'answer $i',
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'tc-$i',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'fn$i',
                arguments: '{"x":$i}',
              ),
            ),
          ],
        ),
        _ => ChatCompletionMessage.tool(
          toolCallId: 'call-$i',
          content: 'result $i',
        ),
      },
  ];

  /// Asserts the converted map for message [i] preserves role and content.
  void verify(int i, Map<String, dynamic> map) {
    switch (_kinds[i]) {
      case 0:
        expect(map, {'role': 'system', 'content': 'sys $i'});
      case 1:
        expect(map, {'role': 'user', 'content': 'hello $i'});
      case 2:
        expect(map['role'], 'user');
        expect(map['content'], [
          {'type': 'text', 'text': 'part $i'},
          {
            'type': 'image_url',
            'image_url': {'url': 'http://img/$i'},
          },
        ]);
      case 3:
        expect(map['role'], 'assistant');
        expect(map['content'], 'answer $i');
        expect(map['tool_calls'], [
          {
            'id': 'tc-$i',
            'type': 'function',
            'function': {'name': 'fn$i', 'arguments': '{"x":$i}'},
          },
        ]);
      default:
        expect(map, {
          'role': 'tool',
          'tool_call_id': 'call-$i',
          'content': 'result $i',
        });
    }
  }

  @override
  String toString() => '_MistralMessagesScenario(kinds: $_kinds)';
}

extension _AnyMistralMessagesScenario on glados.Any {
  glados.Generator<_MistralMessagesScenario> get mistralMessagesScenario =>
      combine2(
        intInRange(0, 8),
        intInRange(0, 1000),
        (int count, int seed) =>
            _MistralMessagesScenario(count: count, seed: seed),
      );
}

/// A non-timeout, non-format transport error used to exercise the generic
/// `Exception` branch of `listModels`.
class _TransportFailure implements Exception {
  const _TransportFailure();

  @override
  String toString() => 'transport failure';
}
