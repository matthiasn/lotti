part of 'gemini_inference_repository.dart';

/// Image-generation path of [GeminiInferenceRepository].
extension GeminiImageGeneration on GeminiInferenceRepository {
  Future<GeneratedImage> generateImageImpl({
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

    final response = await _httpClient
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
        'Gemini image generation error ${response.statusCode} for model "$model": ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _extractImageFromResponse(decoded);
  }

  /// Extracts image data from a Gemini image generation response.
  ///
  /// The response contains candidates with parts that include inline_data
  /// containing the base64-encoded image and its MIME type.
  GeneratedImage _extractImageFromResponse(Map<String, dynamic> response) {
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

  // -------------------------------------------------------------------------
  // Private payload processing
  // -------------------------------------------------------------------------
}

// ---------------------------------------------------------------------------
// Helper methods for creating OpenAI-compatible response chunks
// ---------------------------------------------------------------------------

/// Creates a response chunk containing a thinking block.
CreateChatCompletionStreamResponse _createThinkingChunk({
  required String id,
  required int created,
  required String model,
  required String thinking,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          content: '<think>\n$thinking\n</think>\n',
        ),
      ),
    ],
  );
}

/// Creates a response chunk containing visible text content.
CreateChatCompletionStreamResponse _createTextChunk({
  required String id,
  required int created,
  required String model,
  required String text,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: text),
      ),
    ],
  );
}

/// Creates a response chunk containing a tool call.
CreateChatCompletionStreamResponse _createToolCallChunk({
  required String id,
  required int created,
  required String model,
  required int index,
  required String toolCallId,
  required String name,
  required String arguments,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: index,
              id: toolCallId,
              function: ChatCompletionStreamMessageFunctionCall(
                name: name,
                arguments: arguments,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Creates a response chunk containing usage statistics.
CreateChatCompletionStreamResponse _createUsageChunk({
  required String id,
  required int created,
  required String model,
  int? promptTokens,
  int? completionTokens,
  int? thoughtsTokens,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    created: created,
    model: model,
    choices: const [],
    usage: CompletionUsage(
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: (promptTokens ?? 0) + (completionTokens ?? 0),
      completionTokensDetails: thoughtsTokens != null
          ? CompletionTokensDetails(reasoningTokens: thoughtsTokens)
          : null,
    ),
  );
}

/// Captures a thought signature from a Gemini response part if present.
///
/// Logs when a signature is captured or when the first function call lacks one.
/// Uses [extractThoughtSignature] to extract the signature from the part.
void _captureSignatureIfPresent({
  required Map<String, dynamic> part,
  required String toolCallId,
  required String functionName,
  required int toolCallIndex,
  ThoughtSignatureCollector? signatureCollector,
}) {
  final thoughtSignature = extractThoughtSignature(part);
  if (thoughtSignature != null) {
    signatureCollector?.addSignature(toolCallId, thoughtSignature);
    developer.log(
      'Captured thought signature for $functionName ($toolCallId), '
      'length=${thoughtSignature.length}',
      name: 'GeminiInferenceRepository',
    );
  } else if (toolCallIndex == 0) {
    // First function call without signature - unexpected for Gemini 3
    // but may be normal for Gemini 2.x or non-thinking mode
    developer.log(
      'First function call $functionName has no thought signature',
      name: 'GeminiInferenceRepository',
    );
  }
}
