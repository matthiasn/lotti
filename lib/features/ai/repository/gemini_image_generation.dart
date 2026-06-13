import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';

/// Generates an image using Gemini's image generation capabilities.
///
/// This uses the Gemini image generation API (Nano Banana Pro) to generate
/// images from text prompts. The model must support image output
/// (outputModalities includes Modality.image).
///
/// Parameters:
/// - [httpClient]: HTTP client used for the request.
/// - [prompt]: The text prompt describing the image to generate.
/// - [model]: The Gemini model ID (e.g., 'models/gemini-3-pro-image-preview').
/// - [provider]: Contains base URL and API key.
/// - [systemMessage]: Optional system instruction for guiding generation.
/// - [referenceImages]: Optional list of reference images for visual context.
///
/// Returns a [GeneratedImage] containing the image bytes and MIME type, or
/// throws an exception if generation fails.
Future<GeneratedImage> generateGeminiImage({
  required http.Client httpClient,
  required String prompt,
  required String model,
  required AiConfigInferenceProvider provider,
  String? systemMessage,
  List<ProcessedReferenceImage>? referenceImages,
}) async {
  final uri = GeminiUtils.buildGenerateContentUri(
    baseUrl: provider.baseUrl,
    model: model,
    apiKey: provider.apiKey,
  );

  final body = GeminiUtils.buildImageGenerationRequestBody(
    prompt: prompt,
    systemMessage: systemMessage,
    referenceImages: referenceImages,
  );

  developer.log(
    'Gemini generateImage request to: $uri',
    name: 'GeminiInferenceRepository',
  );

  final response = await httpClient
      .post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Gemini image generation error ${response.statusCode} for model '
      '"$model": ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return extractGeminiImageFromResponse(decoded);
}

/// Extracts image data from a Gemini image generation response.
///
/// The response contains candidates with parts that include inline_data
/// containing the base64-encoded image and its MIME type.
GeneratedImage extractGeminiImageFromResponse(Map<String, dynamic> response) {
  final candidates = response['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    throw Exception('No candidates in image generation response');
  }

  final first = candidates.first;
  final content = first is Map<String, dynamic> ? first['content'] : null;
  if (content is! Map<String, dynamic>) {
    throw Exception('No content in image generation response');
  }

  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) {
    throw Exception('No parts in image generation response');
  }

  // Look for inline_data containing the generated image
  for (final part in parts) {
    if (part is! Map<String, dynamic>) continue;

    final inlineData = part['inlineData'] ?? part['inline_data'];
    if (inlineData is Map<String, dynamic>) {
      final mimeType =
          inlineData['mimeType'] as String? ??
          inlineData['mime_type'] as String? ??
          'image/png';
      final data = inlineData['data'] as String?;

      if (data != null && data.isNotEmpty) {
        final bytes = base64Decode(data);
        return GeneratedImage(
          bytes: bytes,
          mimeType: mimeType,
        );
      }
    }
  }

  throw Exception('No image data found in response');
}
