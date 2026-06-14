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
    throw Exception(
      'No candidates in image generation response'
      '${_responseDiagnostics(response, null)}',
    );
  }

  final first = candidates.first;
  final candidate = first is Map<String, dynamic> ? first : null;
  final content = candidate != null ? candidate['content'] : null;
  if (content is! Map<String, dynamic>) {
    throw Exception(
      'No content in image generation response'
      '${_responseDiagnostics(response, candidate)}',
    );
  }

  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) {
    throw Exception(
      'No parts in image generation response'
      '${_responseDiagnostics(response, candidate)}',
    );
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

  throw Exception(
    'No image data found in response'
    '${_responseDiagnostics(response, candidate)}',
  );
}

/// Builds a human-readable diagnostics suffix explaining *why* a Gemini image
/// response carried no usable image part.
///
/// Gemini returns HTTP 200 with a candidate that has empty/missing `parts`
/// whenever generation is terminated by the model rather than failing at the
/// transport layer — typically a `finishReason` such as `IMAGE_SAFETY`,
/// `PROHIBITED_CONTENT`, `RECITATION` or `MAX_TOKENS`, or a prompt blocked
/// outright via `promptFeedback.blockReason`. The bare "No parts" message hides
/// all of this, which makes failures (e.g. a prod profile whose thinking budget
/// reliably eats the output, or content tripping a safety filter) impossible to
/// diagnose from logs.
///
/// This suffix is appended to the thrown exception's message, which the skill
/// runner persists via `LoggingService` (the repository's own `developer.log`
/// calls are *not* captured in release/TestFlight builds), so it is the only
/// reliable place to surface the cause for later log searches. It reports the
/// terminal reason, any blocked safety categories, and token-usage counts
/// (which distinguish a thinking-budget exhaustion from an outright refusal),
/// and always attaches a truncated raw payload as a backstop.
String _responseDiagnostics(
  Map<String, dynamic> response,
  Map<String, dynamic>? candidate,
) {
  final details = <String>[];

  final finishReason = candidate?['finishReason'];
  if (finishReason != null) {
    details.add('finishReason: $finishReason');
  }

  final finishMessage = candidate?['finishMessage'];
  if (finishMessage is String && finishMessage.isNotEmpty) {
    details.add('finishMessage: $finishMessage');
  }

  final promptFeedback = response['promptFeedback'];
  final blockReason = promptFeedback is Map<String, dynamic>
      ? promptFeedback['blockReason']
      : null;
  if (blockReason != null) {
    details.add('blockReason: $blockReason');
  }

  // Surface only safety categories that actually contributed to the block to
  // keep the message focused.
  final safetyRatings =
      candidate?['safetyRatings'] ??
      (promptFeedback is Map<String, dynamic>
          ? promptFeedback['safetyRatings']
          : null);
  if (safetyRatings is List) {
    final blocked = safetyRatings
        .whereType<Map<String, dynamic>>()
        .where((r) => r['blocked'] == true || r['probability'] == 'HIGH')
        .map((r) => r['category'])
        .whereType<String>()
        .toList();
    if (blocked.isNotEmpty) {
      details.add('blockedCategories: ${blocked.join(', ')}');
    }
  }

  // Token usage distinguishes a thinking-budget exhaustion (high
  // thoughtsTokenCount with finishReason MAX_TOKENS and no image) from an
  // immediate refusal (near-zero counts).
  final usage = response['usageMetadata'];
  if (usage is Map<String, dynamic>) {
    final usageBits = <String>[];
    for (final key in const [
      'promptTokenCount',
      'thoughtsTokenCount',
      'candidatesTokenCount',
      'totalTokenCount',
    ]) {
      final value = usage[key];
      if (value != null) usageBits.add('$key=$value');
    }
    if (usageBits.isNotEmpty) {
      details.add('usage: ${usageBits.join(', ')}');
    }
  }

  // Always attach a truncated raw payload as a backstop so a single prod run
  // yields everything we need, even when the structured fields above are
  // absent or the response shape is unexpected. Failure responses carry no
  // image bytes, so this stays small.
  final raw = jsonEncode(response);
  const maxLen = 800;
  final truncated = raw.length > maxLen ? '${raw.substring(0, maxLen)}…' : raw;
  details.add('raw: $truncated');

  return ' (${details.join('; ')})';
}
