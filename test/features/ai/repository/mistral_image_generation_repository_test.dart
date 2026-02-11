import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/repository/mistral_image_generation_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MistralImageGenerationRepository repository;
  late MockHttpClient mockHttpClient;
  late MockLoggingService mockLoggingService;

  const baseUrl = 'https://api.mistral.ai/v1';
  const apiKey = 'test-api-key';
  const prompt = 'A beautiful landscape painting';
  const agentId = 'agent-123';
  const fileId = 'file-456';

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.mistral.ai/v1'));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockLoggingService = MockLoggingService();
    repository = MistralImageGenerationRepository(httpClient: mockHttpClient);

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  // ---------------------------------------------------------------------------
  // Helper: mock the three-step happy path (create agent, conversation, download)
  // ---------------------------------------------------------------------------
  void mockHappyPath({
    Map<String, dynamic>? agentResponse,
    Map<String, dynamic>? conversationResponse,
    List<int>? fileBytes,
    String? contentType,
  }) {
    final agentResp = agentResponse ?? {'id': agentId};
    final convResp = conversationResponse ??
        {
          'outputs': [
            {
              'content': [
                {'type': 'tool_file', 'file_id': fileId},
              ],
            },
          ],
        };
    final bytes = fileBytes ?? [0x89, 0x50, 0x4E, 0x47]; // PNG header stub

    // POST calls: first for agent creation, second for conversation
    var postCallCount = 0;
    when(
      () => mockHttpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {
      postCallCount++;
      if (postCallCount == 1) {
        return http.Response(jsonEncode(agentResp), 200);
      }
      return http.Response(jsonEncode(convResp), 200);
    });

    // GET for file download
    when(
      () => mockHttpClient.get(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer(
      (_) async => http.Response.bytes(
        Uint8List.fromList(bytes),
        200,
        headers: {
          if (contentType != null) 'content-type': contentType,
        },
      ),
    );

    // DELETE for agent cleanup
    when(
      () => mockHttpClient.delete(
        any(),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => http.Response('{}', 200));
  }

  group('MistralImageGenerationRepository', () {
    group('input validation', () {
      test('throws ArgumentError for empty prompt', () {
        expect(
          () => repository.generateImage(
            prompt: '',
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              'prompt',
            ),
          ),
        );
      });

      test('throws ArgumentError for empty baseUrl', () {
        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: '',
            apiKey: apiKey,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              'baseUrl',
            ),
          ),
        );
      });

      test('throws ArgumentError for empty apiKey', () {
        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: '',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              'apiKey',
            ),
          ),
        );
      });
    });

    group('successful generation', () {
      test('returns GeneratedImage with correct bytes and mimeType', () async {
        final imageBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A];
        mockHappyPath(fileBytes: imageBytes);

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.bytes, equals(imageBytes));
        expect(result.mimeType, equals('image/png'));
      });

      test('uses Content-Type header from download response', () async {
        mockHappyPath(contentType: 'image/webp');

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.mimeType, equals('image/webp'));
      });

      test('falls back to image/png when Content-Type header is absent',
          () async {
        // mockHappyPath without contentType → no content-type header
        mockHappyPath();

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.mimeType, equals('image/png'));
      });

      test('sends correct agent creation request', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        // First POST call is agent creation
        final agentUri = captured[0] as Uri;
        expect(agentUri.toString(), equals('$baseUrl/agents'));

        final agentHeaders = captured[1] as Map<String, String>;
        expect(agentHeaders['Authorization'], equals('Bearer $apiKey'));
        expect(agentHeaders['Content-Type'], equals('application/json'));

        final agentBody =
            jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(
          agentBody['model'],
          equals(MistralImageGenerationRepository.defaultAgentModel),
        );
        expect(agentBody['tools'], isA<List<dynamic>>());
        final tools = agentBody['tools'] as List;
        expect(tools.length, equals(1));
        expect(
          (tools.first as Map<String, dynamic>)['type'],
          equals('image_generation'),
        );
        expect(agentBody['name'], startsWith('lotti_cover_art_'));
      });

      test('sends correct conversation request with agent_id', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        // Second POST call (index 3, 4, 5) is conversation
        final convUri = captured[3] as Uri;
        expect(convUri.toString(), equals('$baseUrl/conversations'));

        final convBody =
            jsonDecode(captured[5] as String) as Map<String, dynamic>;
        expect(convBody['agent_id'], equals(agentId));
        expect(convBody['inputs'], equals(prompt));
        expect(convBody['stream'], isFalse);
      });

      test('sends correct file download request', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;

        final downloadUri = captured[0] as Uri;
        expect(
          downloadUri.toString(),
          equals('$baseUrl/files/$fileId/content'),
        );

        final downloadHeaders = captured[1] as Map<String, String>;
        expect(downloadHeaders['Authorization'], equals('Bearer $apiKey'));
      });

      test('uses custom model when provided', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
          model: 'custom-model',
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final agentBody =
            jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(agentBody['model'], equals('custom-model'));
      });

      test('includes system message as instructions when provided', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
          systemMessage: 'Generate art in oil painting style',
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final agentBody =
            jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(
          agentBody['instructions'],
          equals('Generate art in oil painting style'),
        );
      });

      test(
          'does not include instructions field when systemMessage '
          'is null', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: captureAny(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;

        final agentBody =
            jsonDecode(captured[2] as String) as Map<String, dynamic>;
        expect(agentBody.containsKey('instructions'), isFalse);
      });

      test('extracts file_id from outputs with tool_file content', () async {
        mockHappyPath(
          conversationResponse: {
            'outputs': [
              {
                'content': [
                  {'type': 'text', 'text': 'Here is your image'},
                  {'type': 'tool_file', 'file_id': 'custom-file-id'},
                ],
              },
            ],
          },
        );

        // Adjust GET mock to use the custom file ID
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response.bytes(
            Uint8List.fromList([1, 2, 3]),
            200,
          ),
        );

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.bytes, equals([1, 2, 3]));

        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          ),
        ).captured;

        final downloadUri = captured[0] as Uri;
        expect(downloadUri.toString(), contains('custom-file-id'));
      });

      test(
          'extracts file_id from entries when outputs is not '
          'present', () async {
        mockHappyPath(
          conversationResponse: {
            'entries': [
              {
                'content': [
                  {'type': 'tool_file', 'file_id': 'entry-file-id'},
                ],
              },
            ],
          },
        );

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response.bytes(
            Uint8List.fromList([4, 5, 6]),
            200,
          ),
        );

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.bytes, equals([4, 5, 6]));
      });

      test('extracts file_id from nested message content', () async {
        mockHappyPath(
          conversationResponse: {
            'outputs': [
              {
                'message': {
                  'content': [
                    {'type': 'tool_file', 'file_id': 'nested-file-id'},
                  ],
                },
              },
            ],
          },
        );

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response.bytes(
            Uint8List.fromList([7, 8, 9]),
            200,
          ),
        );

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.bytes, equals([7, 8, 9]));
      });
    });

    group('agent creation errors', () {
      test('throws on HTTP 400 during agent creation', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'message': 'Bad request'}),
            400,
          ),
        );

        // DELETE stub for cleanup (agentId will be null, so this won't
        // actually be called, but register it defensively)
        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('HTTP 400'),
                )
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  400,
                ),
          ),
        );
      });

      test('throws on HTTP 500 during agent creation', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal Server Error', 500),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>()
                .having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      });

      test('throws when agent creation response is missing id field', () async {
        // Return valid JSON but without 'id'
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'name': 'test-agent', 'model': 'test'}),
            200,
          ),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('missing "id" field'),
            ),
          ),
        );
      });

      test('throws when agent creation response has empty id', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'id': ''}), 200),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('missing "id" field'),
            ),
          ),
        );
      });

      test('throws on malformed JSON in agent creation response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('not valid json {{{', 200),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('Invalid JSON'),
            ),
          ),
        );
      });
    });

    group('conversation errors', () {
      test('throws on HTTP error during conversation', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            // Agent creation succeeds
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          // Conversation fails
          return http.Response(
            jsonEncode({'message': 'Rate limit exceeded'}),
            429,
          );
        });

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>()
                .having((e) => e.statusCode, 'statusCode', 429)
                .having(
                  (e) => e.message,
                  'message',
                  contains('HTTP 429'),
                ),
          ),
        );
      });

      test('throws when conversation response has no file_id', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          // Conversation response with no tool_file entries
          return http.Response(
            jsonEncode({
              'outputs': [
                {
                  'content': [
                    {'type': 'text', 'text': 'Here is your description'},
                  ],
                },
              ],
            }),
            200,
          );
        });

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('No generated image file found'),
            ),
          ),
        );
      });

      test('throws when conversation response has empty outputs and entries',
          () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response(
            jsonEncode({
              'outputs': <dynamic>[],
              'entries': <dynamic>[],
            }),
            200,
          );
        });

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('No generated image file found'),
            ),
          ),
        );
      });

      test('throws on malformed JSON in conversation response', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response('{{invalid json', 200);
        });

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('Invalid JSON'),
            ),
          ),
        );
      });

      test('skips non-map entries in outputs', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response(
            jsonEncode({
              'outputs': [
                'not a map',
                42,
                {
                  'content': [
                    {'type': 'tool_file', 'file_id': fileId},
                  ],
                },
              ],
            }),
            200,
          );
        });

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.bytes, equals([1, 2, 3]));
      });

      test('skips tool_file chunks with empty file_id', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response(
            jsonEncode({
              'outputs': [
                {
                  'content': [
                    {'type': 'tool_file', 'file_id': ''},
                    {'type': 'tool_file', 'file_id': 'valid-id'},
                  ],
                },
              ],
            }),
            200,
          );
        });

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        // Verify it downloaded using 'valid-id', not the empty one
        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          ),
        ).captured;
        final downloadUri = captured[0] as Uri;
        expect(downloadUri.toString(), contains('valid-id'));
        expect(result.bytes, equals([1, 2, 3]));
      });
    });

    group('file download errors', () {
      test('throws on HTTP error during file download', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response(
            jsonEncode({
              'outputs': [
                {
                  'content': [
                    {'type': 'tool_file', 'file_id': fileId},
                  ],
                },
              ],
            }),
            200,
          );
        });

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Not Found', 404),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e.message,
                  'message',
                  contains('File download failed'),
                ),
          ),
        );
      });

      test('throws when downloaded file is empty', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response(
            jsonEncode({
              'outputs': [
                {
                  'content': [
                    {'type': 'tool_file', 'file_id': fileId},
                  ],
                },
              ],
            }),
            200,
          );
        });

        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response.bytes(Uint8List(0), 200),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('Downloaded file is empty'),
            ),
          ),
        );
      });
    });

    group('agent cleanup', () {
      test('deletes agent after successful generation', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.delete(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;

        final deleteUri = captured[0] as Uri;
        expect(
          deleteUri.toString(),
          equals('$baseUrl/agents/$agentId'),
        );

        final deleteHeaders = captured[1] as Map<String, String>;
        expect(deleteHeaders['Authorization'], equals('Bearer $apiKey'));
      });

      test('deletes agent after failed conversation', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response(
            jsonEncode({'message': 'Server error'}),
            500,
          );
        });

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        try {
          await repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          );
        } on MistralImageGenerationException {
          // Expected
        }

        // Verify DELETE was called for cleanup
        verify(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      });

      test('does not attempt cleanup when agent creation fails', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Server Error', 500),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        try {
          await repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          );
        } on MistralImageGenerationException {
          // Expected
        }

        // DELETE should not be called because agentId is null
        verifyNever(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        );
      });

      test('cleanup failure does not propagate to caller', () async {
        mockHappyPath();

        // Override DELETE to throw
        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenThrow(Exception('Network error during cleanup'));

        // Should still succeed despite cleanup failure
        final result = await repository.generateImage(
          prompt: prompt,
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

        expect(result.bytes, isNotEmpty);
        expect(result.mimeType, equals('image/png'));
      });

      test(
          'cleanup failure does not mask the original error on '
          'generation failure', () async {
        var postCallCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response(jsonEncode({'id': agentId}), 200);
          }
          return http.Response('Server Error', 500);
        });

        // DELETE throws
        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenThrow(Exception('Cleanup failed'));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });
    });

    group('URL construction', () {
      test('constructs URL correctly without trailing slash', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;

        final agentUri = captured[0] as Uri;
        expect(
          agentUri.toString(),
          equals('https://api.mistral.ai/v1/agents'),
        );
      });

      test('constructs URL correctly with trailing slash', () async {
        mockHappyPath();

        await repository.generateImage(
          prompt: prompt,
          baseUrl: 'https://api.mistral.ai/v1/',
          apiKey: apiKey,
        );

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;

        final agentUri = captured[0] as Uri;
        expect(
          agentUri.toString(),
          equals('https://api.mistral.ai/v1/agents'),
        );
      });
    });

    group('error handling and exception wrapping', () {
      test('wraps unexpected exceptions in MistralImageGenerationException',
          () async {
        when(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(StateError('Connection reset'));

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Image generation failed'),
                )
                .having(
                  (e) => e.originalError,
                  'originalError',
                  isA<StateError>(),
                ),
          ),
        );
      });

      test('logs unexpected exceptions via LoggingService', () async {
        when(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(StateError('Unexpected failure'));

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        try {
          await repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          );
        } on MistralImageGenerationException {
          // Expected
        }

        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(that: isA<StateError>()),
            domain: 'MISTRAL_IMAGE',
            subDomain: 'generateImage',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('rethrows MistralImageGenerationException without wrapping',
          () async {
        // When agent creation returns HTTP error, it throws
        // MistralImageGenerationException directly; the outer catch
        // should rethrow it, not wrap it in another exception.
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'message': 'Unauthorized'}),
            401,
          ),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having(
                  (e) => e.message,
                  'message',
                  contains('HTTP 401'),
                ),
          ),
        );

        // LoggingService should NOT be called for
        // MistralImageGenerationException (it's rethrown, not caught by
        // the generic catch block)
        verifyNever(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        );
      });

      test('parses error message from JSON response body', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'message': 'Custom error message'}),
            422,
          ),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('Custom error message'),
            ),
          ),
        );
      });

      test('parses error from detail field', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'detail': 'Detailed error info'}),
            400,
          ),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('Detailed error info'),
            ),
          ),
        );
      });

      test('uses raw body when error JSON parsing fails', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Plain text error', 502),
        );

        when(
          () => mockHttpClient.delete(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => http.Response('{}', 200));

        expect(
          () => repository.generateImage(
            prompt: prompt,
            baseUrl: baseUrl,
            apiKey: apiKey,
          ),
          throwsA(
            isA<MistralImageGenerationException>().having(
              (e) => e.message,
              'message',
              contains('Plain text error'),
            ),
          ),
        );
      });
    });

    group('MistralImageGenerationException', () {
      test('toString formats correctly', () {
        final exception = MistralImageGenerationException(
          'Test error',
          statusCode: 404,
          originalError: Exception('Original'),
        );

        expect(
          exception.toString(),
          equals('MistralImageGenerationException: Test error'),
        );
      });

      test('exposes message, statusCode, and originalError', () {
        final original = Exception('Root cause');
        final exception = MistralImageGenerationException(
          'Something went wrong',
          statusCode: 500,
          originalError: original,
        );

        expect(exception.message, equals('Something went wrong'));
        expect(exception.statusCode, equals(500));
        expect(exception.originalError, same(original));
      });

      test('works without optional parameters', () {
        final exception = MistralImageGenerationException('Simple error');

        expect(exception.message, equals('Simple error'));
        expect(exception.statusCode, isNull);
        expect(exception.originalError, isNull);
      });
    });

    group('static constants', () {
      test('defaultAgentModel is set correctly', () {
        expect(
          MistralImageGenerationRepository.defaultAgentModel,
          equals('mistral-medium-latest'),
        );
      });

      test('timeouts have expected values', () {
        expect(
          MistralImageGenerationRepository.agentCreationTimeout,
          equals(const Duration(seconds: 30)),
        );
        expect(
          MistralImageGenerationRepository.conversationTimeout,
          equals(const Duration(seconds: 180)),
        );
        expect(
          MistralImageGenerationRepository.fileDownloadTimeout,
          equals(const Duration(seconds: 60)),
        );
      });
    });

    group('constructor', () {
      test('accepts custom httpClient', () {
        final client = MockHttpClient();
        final repo = MistralImageGenerationRepository(httpClient: client);
        // Verify the repo was created without error
        expect(repo, isA<MistralImageGenerationRepository>());
      });

      test('creates default client when none provided', () {
        final repo = MistralImageGenerationRepository();
        expect(repo, isA<MistralImageGenerationRepository>());
      });
    });
  });
}
