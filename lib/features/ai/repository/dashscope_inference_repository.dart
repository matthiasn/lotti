import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashscope_inference_repository.g.dart';

/// DashScope image generation endpoint path (native API, not OpenAI-compatible).
const _imageGenerationPath =
    '/api/v1/services/aigc/multimodal-generation/generation';

/// Timeout for image generation requests (image gen takes ~20-40s typically).
const _imageGenerationTimeout = Duration(seconds: 180);

/// Allowed host suffixes for image URLs returned by DashScope.
///
/// Only URLs whose host ends with one of these suffixes will be fetched.
/// This prevents SSRF if a malicious SSE response contains an internal or
/// unexpected URL.
const _allowedImageHostSuffixes = [
  '.aliyuncs.com',
  '.alicdn.com',
];

/// Repository for DashScope-specific API calls (Alibaba Cloud).
///
/// Currently handles image generation via the Wan model family, which uses
/// DashScope's native SSE streaming API rather than the OpenAI-compatible
/// endpoint used for text/audio/vision models.
class DashScopeInferenceRepository {
  DashScopeInferenceRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Generates an image using DashScope's native SSE streaming API.
  ///
  /// The flow:
  /// 1. POST to the multimodal generation endpoint with SSE enabled
  /// 2. Stream SSE events (text tokens followed by an image URL)
  /// 3. Extract the image URL from the final event
  /// 4. Download the image bytes from the URL
  /// 5. Return [GeneratedImage] with bytes and MIME type
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
  }) async {
    final baseUrl = _extractBaseHost(provider.baseUrl);
    final uri = Uri.parse('$baseUrl$_imageGenerationPath');

    developer.log(
      'DashScope generateImage:\n'
      '  uri: $uri\n'
      '  model: $model\n'
      '  promptLength: ${prompt.length}',
      name: 'DashScopeInferenceRepository',
    );

    final body = _buildRequestBody(
      prompt: prompt,
      model: model,
    );

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${provider.apiKey}',
        'X-DashScope-Sse': 'enable',
      })
      ..body = jsonEncode(body);

    final streamedResponse =
        await _httpClient.send(request).timeout(_imageGenerationTimeout);

    if (streamedResponse.statusCode != 200) {
      final responseBody = await streamedResponse.stream.bytesToString();
      throw Exception(
        'DashScope image generation failed with status '
        '${streamedResponse.statusCode}: $responseBody',
      );
    }

    // Collect the full SSE response
    final responseBody = await streamedResponse.stream.bytesToString();

    // Extract image URL from SSE events
    final imageUrl = _extractImageUrlFromSse(responseBody);
    if (imageUrl == null) {
      throw Exception(
        'DashScope image generation did not return an image URL. '
        'Response: ${responseBody.substring(0, responseBody.length.clamp(0, 500))}',
      );
    }

    // Validate the image URL to prevent SSRF
    _validateImageUrl(imageUrl);

    developer.log(
      'DashScope image URL received, downloading...',
      name: 'DashScopeInferenceRepository',
    );

    // Download the image from the temporary URL
    final imageResponse = await _httpClient
        .get(Uri.parse(imageUrl))
        .timeout(const Duration(seconds: 60));

    if (imageResponse.statusCode != 200) {
      throw Exception(
        'Failed to download DashScope image: ${imageResponse.statusCode}',
      );
    }

    // Determine MIME type from response headers or default to PNG
    final contentType = imageResponse.headers['content-type'] ?? 'image/png';
    final mimeType = contentType.split(';').first.trim();

    return GeneratedImage(
      bytes: imageResponse.bodyBytes,
      mimeType: mimeType,
    );
  }

  /// Extracts the base host URL from the provider's configured base URL.
  ///
  /// The provider base URL is the OpenAI-compatible endpoint:
  ///   `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
  /// We need just the host part for the native DashScope API:
  ///   `https://dashscope-intl.aliyuncs.com`
  String _extractBaseHost(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.host}';
  }

  /// Builds the DashScope native API request body for image generation.
  Map<String, dynamic> _buildRequestBody({
    required String prompt,
    required String model,
  }) {
    return {
      'model': model,
      'input': {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'text': prompt},
            ],
          },
        ],
      },
      'parameters': {
        'max_images': 1,
        'size': '1280*720',
        'stream': true,
        'enable_interleave': true,
      },
    };
  }

  /// Extracts the image URL from SSE response data.
  ///
  /// DashScope SSE format:
  /// ```text
  /// id:1
  /// event:result
  /// :HTTP_STATUS/200
  /// data:{"output":{"choices":[{"message":{"content":[{"type":"text","text":"..."}]}}]}}
  /// ...
  /// id:N
  /// event:result
  /// :HTTP_STATUS/200
  /// data:{"output":{"choices":[{"message":{"content":[{"type":"image","image":"https://..."}]}}],"finished":true}}
  /// ```
  String? _extractImageUrlFromSse(String sseResponse) {
    // Parse SSE events - look for data: lines
    final dataLines = sseResponse
        .split('\n')
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5));

    // Search from the end since the image URL is in the final event
    for (final dataLine in dataLines.toList().reversed) {
      try {
        final json = jsonDecode(dataLine) as Map<String, dynamic>;
        final output = json['output'] as Map<String, dynamic>?;
        final choices = output?['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;

        final message = (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
        final content = message?['content'] as List<dynamic>?;
        if (content == null) continue;

        for (final part in content) {
          final partMap = part as Map<String, dynamic>;
          if (partMap['type'] == 'image' && partMap['image'] != null) {
            return partMap['image'] as String;
          }
        }
      } on Object {
        // Skip malformed JSON lines or unexpected structure (FormatException,
        // TypeError from bad casts, etc.)
        continue;
      }
    }

    return null;
  }

  /// Validates that an image URL is HTTPS and from an allowed Alibaba domain.
  ///
  /// Throws [Exception] if the URL fails validation, preventing SSRF attacks
  /// where a malicious SSE response could redirect to internal network addresses.
  void _validateImageUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null || uri.scheme != 'https') {
      throw Exception(
        'DashScope returned an image URL with invalid scheme: $imageUrl',
      );
    }

    final host = uri.host.toLowerCase();
    final isAllowed = _allowedImageHostSuffixes.any(host.endsWith);
    if (!isAllowed) {
      throw Exception(
        'DashScope returned an image URL from an untrusted host: $host',
      );
    }
  }
}

@riverpod
DashScopeInferenceRepository dashScopeInferenceRepository(Ref ref) {
  return DashScopeInferenceRepository();
}
