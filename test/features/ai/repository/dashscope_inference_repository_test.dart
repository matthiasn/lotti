import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/dashscope_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart'
    show GeneratedImage;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBaseRequest());
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  late MockHttpClient mockHttpClient;
  late DashScopeInferenceRepository repository;

  setUp(() {
    mockHttpClient = MockHttpClient();
    repository = DashScopeInferenceRepository(httpClient: mockHttpClient);
  });

  AiConfigInferenceProvider createProvider({
    String baseUrl = 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    String apiKey = 'test-api-key',
  }) {
    return AiConfigInferenceProvider(
      id: 'alibaba-provider',
      name: 'Alibaba',
      baseUrl: baseUrl,
      apiKey: apiKey,
      createdAt: DateTime(2024),
      inferenceProviderType: InferenceProviderType.alibaba,
    );
  }

  /// Builds a DashScope SSE response string from a list of content events.
  String buildSseResponse(List<Map<String, dynamic>> events) {
    final buffer = StringBuffer();
    for (var i = 0; i < events.length; i++) {
      buffer
        ..writeln('id:${i + 1}')
        ..writeln('event:result')
        ..writeln(':HTTP_STATUS/200')
        ..writeln('data:${jsonEncode(events[i])}')
        ..writeln();
    }
    return buffer.toString();
  }

  Map<String, dynamic> textEvent(String text, {bool finished = false}) => {
        'output': {
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'text', 'text': text},
                ],
                'role': 'assistant',
              },
              'finish_reason': finished ? 'stop' : 'null',
            },
          ],
          'finished': finished,
        },
      };

  Map<String, dynamic> imageEvent(String imageUrl) => {
        'output': {
          'choices': [
            {
              'message': {
                'content': [
                  {'type': 'image', 'image': imageUrl},
                ],
                'role': 'assistant',
              },
              'finish_reason': 'stop',
            },
          ],
          'finished': true,
        },
      };

  http.StreamedResponse createStreamedResponse(
    String body, {
    int statusCode = 200,
  }) {
    final stream = http.ByteStream.fromBytes(utf8.encode(body));
    return http.StreamedResponse(stream, statusCode);
  }

  group('DashScopeInferenceRepository', () {
    group('generateImage', () {
      group('success', () {
        test('happy path: sends request, parses SSE, downloads image',
            () async {
          final provider = createProvider();
          const imageUrl = 'https://dashscope-result.oss.aliyuncs.com/img.png';
          final sseBody = buildSseResponse([
            textEvent('A'),
            textEvent(' cat'),
            imageEvent(imageUrl),
          ]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          final imageBytes = Uint8List.fromList([137, 80, 78, 71]);
          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes(
              imageBytes,
              200,
              headers: {'content-type': 'image/png'},
            ),
          );

          final result = await repository.generateImage(
            prompt: 'A cute cat',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(result, isA<GeneratedImage>());
          expect(result.bytes, imageBytes);
          expect(result.mimeType, 'image/png');
        });

        test('sends correct headers including Authorization and SSE', () async {
          final provider = createProvider(apiKey: 'my-secret-key');
          const imageUrl =
              'https://dashscope-result.oss.aliyuncs.com/image.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          http.BaseRequest? capturedRequest;
          when(() => mockHttpClient.send(any())).thenAnswer((invocation) async {
            capturedRequest =
                invocation.positionalArguments[0] as http.BaseRequest;
            return createStreamedResponse(sseBody);
          });

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes([1, 2, 3], 200),
          );

          await repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(capturedRequest, isNotNull);
          expect(
            capturedRequest!.headers['Authorization'],
            'Bearer my-secret-key',
          );
          expect(
            capturedRequest!.headers['X-DashScope-Sse'],
            'enable',
          );
          expect(
            capturedRequest!.headers['Content-Type'],
            'application/json',
          );
        });

        test('sends request to correct endpoint URL', () async {
          final provider = createProvider();
          const imageUrl =
              'https://dashscope-result.oss.aliyuncs.com/image.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          http.BaseRequest? capturedRequest;
          when(() => mockHttpClient.send(any())).thenAnswer((invocation) async {
            capturedRequest =
                invocation.positionalArguments[0] as http.BaseRequest;
            return createStreamedResponse(sseBody);
          });

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes([1], 200),
          );

          await repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(
            capturedRequest!.url.toString(),
            'https://dashscope-intl.aliyuncs.com'
            '/api/v1/services/aigc/multimodal-generation/generation',
          );
        });

        test('sends correct request body with model and prompt', () async {
          final provider = createProvider();
          const imageUrl =
              'https://dashscope-result.oss.aliyuncs.com/image.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          http.Request? capturedRequest;
          when(() => mockHttpClient.send(any())).thenAnswer((invocation) async {
            capturedRequest = invocation.positionalArguments[0] as http.Request;
            return createStreamedResponse(sseBody);
          });

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes([1], 200),
          );

          await repository.generateImage(
            prompt: 'A sunset over mountains',
            model: 'wan2.6-image',
            provider: provider,
          );

          final body =
              jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
          expect(body['model'], 'wan2.6-image');

          final input = body['input'] as Map<String, dynamic>;
          final messages = input['messages'] as List<dynamic>;
          final firstMessage = messages[0] as Map<String, dynamic>;
          expect(firstMessage['role'], 'user');

          final content = firstMessage['content'] as List<dynamic>;
          final textPart = content[0] as Map<String, dynamic>;
          expect(textPart['text'], 'A sunset over mountains');

          final params = body['parameters'] as Map<String, dynamic>;
          expect(params['max_images'], 1);
          expect(params['size'], '1280*720');
          expect(params['stream'], true);
          expect(params['enable_interleave'], true);
        });

        test('parses MIME type from content-type header', () async {
          final provider = createProvider();
          const imageUrl =
              'https://dashscope-result.oss.aliyuncs.com/image.jpg';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes(
              [1, 2, 3],
              200,
              headers: {'content-type': 'image/jpeg; charset=utf-8'},
            ),
          );

          final result = await repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(result.mimeType, 'image/jpeg');
        });

        test('defaults MIME type to image/png when header missing', () async {
          final provider = createProvider();
          const imageUrl = 'https://dashscope-result.oss.aliyuncs.com/image';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes([1, 2, 3], 200),
          );

          final result = await repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(result.mimeType, 'image/png');
        });
      });

      group('initial request errors', () {
        test('throws on non-200 status code with error body', () async {
          final provider = createProvider();
          const errorBody = '{"code":"InvalidParameter","message":"Bad size"}';

          when(() => mockHttpClient.send(any())).thenAnswer(
            (_) async => createStreamedResponse(errorBody, statusCode: 400),
          );

          expect(
            () => repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('400'),
                  contains('InvalidParameter'),
                ),
              ),
            ),
          );
        });

        test('throws on 401 unauthorized', () async {
          final provider = createProvider();

          when(() => mockHttpClient.send(any())).thenAnswer(
            (_) async =>
                createStreamedResponse('Unauthorized', statusCode: 401),
          );

          expect(
            () => repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('401'),
              ),
            ),
          );
        });
      });

      group('SSE parsing failures', () {
        test('throws when SSE contains no image URL', () async {
          final provider = createProvider();
          final sseBody = buildSseResponse([
            textEvent('Hello'),
            textEvent(' world', finished: true),
          ]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          expect(
            () => repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('did not return an image URL'),
              ),
            ),
          );
        });

        test('truncates response preview to 500 chars in error', () async {
          final provider = createProvider();
          final longText = 'x' * 600;
          // Create raw SSE with no image
          final sseBody = 'data:$longText\n';

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          try {
            await repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            );
            fail('Should have thrown');
          } on Exception catch (e) {
            // The response substring is clamped to 500 chars
            expect(e.toString(), contains('did not return an image URL'));
            // Response preview should not exceed 500 + the prefix
            expect(e.toString().length, lessThan(700));
          }
        });
      });

      group('image download errors', () {
        test('throws when image download returns non-200', () async {
          final provider = createProvider();
          const imageUrl =
              'https://dashscope-result.oss.aliyuncs.com/expired.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response('Not Found', 404),
          );

          expect(
            () => repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(
                  contains('Failed to download'),
                  contains('404'),
                ),
              ),
            ),
          );
        });
      });

      group('URL validation (SSRF prevention)', () {
        test('rejects non-HTTPS image URLs', () async {
          final provider = createProvider();
          const imageUrl = 'http://internal-server.local/image.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          expect(
            () => repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('invalid scheme'),
              ),
            ),
          );
        });

        test('rejects image URLs from untrusted hosts', () async {
          final provider = createProvider();
          const imageUrl = 'https://evil-server.com/stolen.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          expect(
            () => repository.generateImage(
              prompt: 'test',
              model: 'wan2.6-image',
              provider: provider,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('untrusted host'),
              ),
            ),
          );
        });

        test('accepts image URLs from *.aliyuncs.com', () async {
          final provider = createProvider();
          const imageUrl =
              'https://dashscope-result.oss.aliyuncs.com/image.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes([1, 2, 3], 200),
          );

          final result = await repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(result.bytes, [1, 2, 3]);
        });

        test('accepts image URLs from *.alicdn.com', () async {
          final provider = createProvider();
          const imageUrl = 'https://img.alicdn.com/image.png';
          final sseBody = buildSseResponse([imageEvent(imageUrl)]);

          when(() => mockHttpClient.send(any()))
              .thenAnswer((_) async => createStreamedResponse(sseBody));

          when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
            (_) async => http.Response.bytes([4, 5, 6], 200),
          );

          final result = await repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          );

          expect(result.bytes, [4, 5, 6]);
        });
      });
    });

    group('_extractImageUrlFromSse (tested via generateImage)', () {
      test('extracts image URL from final event among text events', () async {
        final provider = createProvider();
        const imageUrl = 'https://oss.aliyuncs.com/final-image.png';
        final sseBody = buildSseResponse([
          textEvent('The'),
          textEvent(' day'),
          textEvent(' was'),
          textEvent(' ending.'),
          imageEvent(imageUrl),
        ]);

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(sseBody));

        when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
          (_) async => http.Response.bytes([1, 2, 3], 200),
        );

        final result = await repository.generateImage(
          prompt: 'test',
          model: 'wan2.6-image',
          provider: provider,
        );

        // Verifies the image URL was correctly extracted and downloaded
        verify(() => mockHttpClient.get(Uri.parse(imageUrl))).called(1);
        expect(result.bytes, [1, 2, 3]);
      });

      test('skips malformed JSON lines gracefully', () async {
        final provider = createProvider();
        const imageUrl = 'https://oss.aliyuncs.com/image.png';

        // Build SSE with a malformed JSON line followed by a valid image event
        final sseBody = 'id:1\nevent:result\ndata:not-valid-json\n\n'
            'id:2\nevent:result\n'
            'data:${jsonEncode(imageEvent(imageUrl))}\n\n';

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(sseBody));

        when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
          (_) async => http.Response.bytes([10, 20], 200),
        );

        final result = await repository.generateImage(
          prompt: 'test',
          model: 'wan2.6-image',
          provider: provider,
        );

        expect(result.bytes, [10, 20]);
      });

      test('skips SSE events with unexpected structure (TypeError)', () async {
        final provider = createProvider();
        const imageUrl = 'https://oss.aliyuncs.com/image.png';

        // First event has choices as a string instead of a list (triggers
        // TypeError), followed by a valid image event
        final badEvent = jsonEncode({
          'output': {
            'choices': 'not-a-list',
          },
        });
        final sseBody = 'id:1\nevent:result\ndata:$badEvent\n\n'
            'id:2\nevent:result\n'
            'data:${jsonEncode(imageEvent(imageUrl))}\n\n';

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(sseBody));

        when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
          (_) async => http.Response.bytes([42], 200),
        );

        final result = await repository.generateImage(
          prompt: 'test',
          model: 'wan2.6-image',
          provider: provider,
        );

        expect(result.bytes, [42]);
      });

      test('returns null (throws) when choices is empty', () async {
        final provider = createProvider();
        final sseBody = buildSseResponse([
          {
            'output': {
              'choices': <dynamic>[],
              'finished': true,
            },
          },
        ]);

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(sseBody));

        expect(
          () => repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('did not return an image URL'),
            ),
          ),
        );
      });

      test('returns null (throws) when output field is missing', () async {
        final provider = createProvider();
        final sseBody = buildSseResponse([
          <String, dynamic>{'usage': <String, dynamic>{}},
        ]);

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(sseBody));

        expect(
          () => repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('did not return an image URL'),
            ),
          ),
        );
      });

      test('returns null (throws) when content is null', () async {
        final provider = createProvider();
        final sseBody = buildSseResponse([
          {
            'output': {
              'choices': [
                {
                  'message': {'role': 'assistant'},
                },
              ],
            },
          },
        ]);

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(sseBody));

        expect(
          () => repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('did not return an image URL'),
            ),
          ),
        );
      });

      test('returns null (throws) for empty SSE response', () async {
        final provider = createProvider();

        when(() => mockHttpClient.send(any()))
            .thenAnswer((_) async => createStreamedResponse(''));

        expect(
          () => repository.generateImage(
            prompt: 'test',
            model: 'wan2.6-image',
            provider: provider,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('did not return an image URL'),
            ),
          ),
        );
      });
    });

    group('_extractBaseHost (tested via generateImage)', () {
      test('strips path from provider base URL', () async {
        final provider = createProvider();
        const imageUrl = 'https://dashscope-result.oss.aliyuncs.com/image.png';
        final sseBody = buildSseResponse([imageEvent(imageUrl)]);

        http.BaseRequest? capturedRequest;
        when(() => mockHttpClient.send(any())).thenAnswer((invocation) async {
          capturedRequest =
              invocation.positionalArguments[0] as http.BaseRequest;
          return createStreamedResponse(sseBody);
        });

        when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
          (_) async => http.Response.bytes([1], 200),
        );

        await repository.generateImage(
          prompt: 'test',
          model: 'wan2.6-image',
          provider: provider,
        );

        expect(
          capturedRequest!.url.host,
          'dashscope-intl.aliyuncs.com',
        );
        expect(
          capturedRequest!.url.scheme,
          'https',
        );
      });

      test('works with base URL that has no path', () async {
        final provider = createProvider(
          baseUrl: 'https://dashscope-intl.aliyuncs.com',
        );
        const imageUrl = 'https://dashscope-result.oss.aliyuncs.com/image.png';
        final sseBody = buildSseResponse([imageEvent(imageUrl)]);

        http.BaseRequest? capturedRequest;
        when(() => mockHttpClient.send(any())).thenAnswer((invocation) async {
          capturedRequest =
              invocation.positionalArguments[0] as http.BaseRequest;
          return createStreamedResponse(sseBody);
        });

        when(() => mockHttpClient.get(Uri.parse(imageUrl))).thenAnswer(
          (_) async => http.Response.bytes([1], 200),
        );

        await repository.generateImage(
          prompt: 'test',
          model: 'wan2.6-image',
          provider: provider,
        );

        expect(
          capturedRequest!.url.toString(),
          startsWith('https://dashscope-intl.aliyuncs.com/api/v1/'),
        );
      });
    });
  });
}
