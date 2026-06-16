import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/image_generation_error.dart';
import 'package:lotti/features/ai/repository/gemini_image_generation.dart';
import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';

AiConfigInferenceProvider _provider() => AiConfigInferenceProvider(
  id: 'prov',
  baseUrl: 'https://generativelanguage.googleapis.com',
  apiKey: 'key',
  name: 'Gemini',
  createdAt: DateTime(2024),
  inferenceProviderType: InferenceProviderType.gemini,
);

String _imageResponse({
  String key = 'inlineData',
  String? mimeType = 'image/png',
  String data = 'aGVsbG8=', // base64 "hello"
}) {
  final inline = <String, dynamic>{'data': data};
  if (mimeType != null) inline['mimeType'] = mimeType;
  return jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {key: inline},
          ],
        },
      },
    ],
  });
}

/// Captures the last POST and replies with a scripted status/body.
class _CapturingClient extends http.BaseClient {
  _CapturingClient({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
  http.BaseRequest? lastRequest;
  String? lastRequestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request) {
      lastRequestBody = request.body;
    }
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([bytes]),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('extractGeminiImageFromResponse', () {
    test('decodes camelCase inlineData with explicit mime type', () {
      final result = extractGeminiImageFromResponse(
        jsonDecode(_imageResponse()) as Map<String, dynamic>,
      );
      expect(utf8.decode(result.bytes), 'hello');
      expect(result.mimeType, 'image/png');
    });

    test('decodes snake_case inline_data and mime_type', () {
      final json = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': 'aGVsbG8=',
                  },
                },
              ],
            },
          },
        ],
      });
      final result = extractGeminiImageFromResponse(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(result.mimeType, 'image/jpeg');
      expect(utf8.decode(result.bytes), 'hello');
    });

    test('defaults mime type to image/png when absent', () {
      final result = extractGeminiImageFromResponse(
        jsonDecode(_imageResponse(mimeType: null)) as Map<String, dynamic>,
      );
      expect(result.mimeType, 'image/png');
    });

    test('skips non-image parts and finds the inline data part', () {
      final json = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'here is your image'},
                {
                  'inlineData': {'mimeType': 'image/webp', 'data': 'aGVsbG8='},
                },
              ],
            },
          },
        ],
      });
      final result = extractGeminiImageFromResponse(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(result.mimeType, 'image/webp');
    });

    test('throws when there are no candidates', () {
      expect(
        () => extractGeminiImageFromResponse(const {'candidates': <dynamic>[]}),
        throwsA(isA<Exception>()),
      );
    });

    test('surfaces finishReason when parts are missing', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {
              'finishReason': 'IMAGE_SAFETY',
              'content': {'parts': <dynamic>[]},
            },
          ],
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('No parts'),
              contains('finishReason: IMAGE_SAFETY'),
            ),
          ),
        ),
      );
    });

    test(
      'surfaces promptFeedback blockReason when there are no candidates',
      () {
        expect(
          () => extractGeminiImageFromResponse(const {
            'candidates': <dynamic>[],
            'promptFeedback': {'blockReason': 'PROHIBITED_CONTENT'},
          }),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('blockReason: PROHIBITED_CONTENT'),
            ),
          ),
        );
      },
    );

    test('surfaces blocked safety categories when parts carry no image', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {
              'finishReason': 'SAFETY',
              'content': {
                'parts': [
                  {'text': 'cannot generate that'},
                ],
              },
              'safetyRatings': [
                {
                  'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                  'probability': 'HIGH',
                  'blocked': true,
                },
                {
                  'category': 'HARM_CATEGORY_HARASSMENT',
                  'probability': 'NEGLIGIBLE',
                },
              ],
            },
          ],
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('No image data'),
              contains('finishReason: SAFETY'),
              // Only the blocked/HIGH category is listed in blockedCategories;
              // the NEGLIGIBLE harassment rating is excluded from that field
              // (it may still appear in the raw payload backstop).
              contains('blockedCategories: HARM_CATEGORY_DANGEROUS_CONTENT;'),
            ),
          ),
        ),
      );
    });

    test('surfaces usage token counts to flag thinking-budget exhaustion', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {
              'finishReason': 'MAX_TOKENS',
              'content': {'parts': <dynamic>[]},
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 1200,
            'thoughtsTokenCount': 8000,
            'totalTokenCount': 9200,
          },
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('finishReason: MAX_TOKENS'),
              contains('thoughtsTokenCount=8000'),
            ),
          ),
        ),
      );
    });

    test('always attaches a raw payload backstop', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {
              'content': {'parts': <dynamic>[]},
            },
          ],
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('No parts'), contains('raw:')),
          ),
        ),
      );
    });

    test('throws when content is not a map', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {'content': 'oops'},
          ],
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when parts list is empty', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {
              'content': {'parts': <dynamic>[]},
            },
          ],
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when no part carries image data', () {
      expect(
        () => extractGeminiImageFromResponse(const {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'no image here'},
                ],
              },
            },
          ],
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when inline data is present but empty', () {
      final json = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'inlineData': {'mimeType': 'image/png', 'data': ''},
                },
              ],
            },
          },
        ],
      });
      expect(
        () => extractGeminiImageFromResponse(
          jsonDecode(json) as Map<String, dynamic>,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('provider reason (verbatim, for the UI)', () {
    ImageGenerationException reasonFor(Map<String, dynamic> response) {
      try {
        extractGeminiImageFromResponse(response);
      } on ImageGenerationException catch (e) {
        return e;
      }
      fail('expected ImageGenerationException');
    }

    test('carries the candidate finishReason verbatim', () {
      final e = reasonFor(const {
        'candidates': [
          {
            'finishReason': 'PROHIBITED_CONTENT',
            'content': {'parts': <dynamic>[]},
          },
        ],
      });
      expect(e.providerReason, 'PROHIBITED_CONTENT');
    });

    test(
      'carries the promptFeedback blockReason when there are no candidates',
      () {
        final e = reasonFor(const {
          'candidates': <dynamic>[],
          'promptFeedback': {'blockReason': 'BLOCKLIST'},
        });
        expect(e.providerReason, 'BLOCKLIST');
      },
    );

    test('appends a human finishMessage to the reason when present', () {
      final e = reasonFor(const {
        'candidates': [
          {
            'finishReason': 'IMAGE_SAFETY',
            'finishMessage': 'Generated image violates policy.',
            'content': {'parts': <dynamic>[]},
          },
        ],
      });
      expect(
        e.providerReason,
        'IMAGE_SAFETY: Generated image violates policy.',
      );
    });

    test('is null when the response carries no reason at all', () {
      final e = reasonFor(const {
        'candidates': [
          {
            'content': {'parts': <dynamic>[]},
          },
        ],
      });
      expect(e.providerReason, isNull);
    });

    test('is not classified or remapped — unknown reasons surface as-is', () {
      final e = reasonFor(const {
        'candidates': [
          {
            'finishReason': 'SOME_FUTURE_REASON',
            'content': {'parts': <dynamic>[]},
          },
        ],
      });
      expect(e.providerReason, 'SOME_FUTURE_REASON');
    });
  });

  group('generateGeminiImage', () {
    test(
      'posts to the generateContent endpoint and returns the image',
      () async {
        final client = _CapturingClient(
          statusCode: 200,
          body: _imageResponse(),
        );

        final result = await generateGeminiImage(
          httpClient: client,
          prompt: 'a cat',
          model: 'gemini-3-pro-image-preview',
          provider: _provider(),
        );

        expect(result, isA<GeneratedImage>());
        expect(utf8.decode(result.bytes), 'hello');
        expect(
          client.lastRequest!.url.path,
          endsWith(':generateContent'),
        );
        expect(client.lastRequest!.method, 'POST');
      },
    );

    test('throws on a non-2xx HTTP status', () async {
      final client = _CapturingClient(
        statusCode: 500,
        body: '{"error":"boom"}',
      );

      await expectLater(
        generateGeminiImage(
          httpClient: client,
          prompt: 'a cat',
          model: 'gemini-3-pro-image-preview',
          provider: _provider(),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test(
      'surfaces the provider error message verbatim on HTTP errors',
      () async {
        final client = _CapturingClient(
          statusCode: 400,
          body:
              '{"error":{"status":"INVALID_ARGUMENT","message":"Unsupported '
              'model"}}',
        );

        await expectLater(
          generateGeminiImage(
            httpClient: client,
            prompt: 'a cat',
            model: 'gemini-3-pro-image-preview',
            provider: _provider(),
          ),
          throwsA(
            isA<ImageGenerationException>().having(
              (e) => e.providerReason,
              'providerReason',
              'INVALID_ARGUMENT: Unsupported model',
            ),
          ),
        );
      },
    );

    test(
      'includes the system message in the request body when provided',
      () async {
        final client = _CapturingClient(
          statusCode: 200,
          body: _imageResponse(),
        );

        await generateGeminiImage(
          httpClient: client,
          prompt: 'a cat',
          model: 'gemini-3-pro-image-preview',
          provider: _provider(),
          systemMessage: 'be photorealistic',
        );

        expect(client.lastRequestBody, contains('be photorealistic'));
      },
    );
  });
}
