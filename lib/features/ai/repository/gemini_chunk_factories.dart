part of 'gemini_inference_repository.dart';

// ---------------------------------------------------------------------------
// OpenAI-compatible response-chunk factories shared by the chat, multiturn
// and image-generation paths of the Gemini repository.
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
