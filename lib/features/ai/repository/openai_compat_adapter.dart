import 'package:lotti/features/ai/model/inference_chunk.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/model/inference_message.dart';
import 'package:lotti/features/ai/model/inference_request.dart';
import 'package:lotti/features/ai/model/inference_tool.dart';
import 'package:lotti/features/ai/repository/inference_client.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';

/// The boundary between Lotti's inference domain and the `openai_dart` client.
///
/// This is the **only** file in the app that is allowed to import
/// `package:openai_dart`. Everything upstream — providers, workflows, agents,
/// conversation management — speaks the Lotti types in
/// `lib/features/ai/model/inference_*.dart`. Upgrading the client library
/// therefore means rewriting the mappings here rather than every call site.
///
/// The mapping is deliberately total in one direction only: Lotti types are
/// fully expressible as OpenAI requests, while OpenAI responses carry fields
/// Lotti does not model (log probabilities, refusals, provider-specific
/// reasoning payloads) which are dropped on the way in.

/// Converts a Lotti message to its OpenAI-compatible wire form.
ChatMessage toOpenAiMessage(LottiMessage message) => switch (message) {
  LottiSystemMessage(:final content, :final name) => SystemMessage(
    content: content,
    name: name,
  ),
  LottiDeveloperMessage(:final content, :final name) => DeveloperMessage(
    content: content,
    name: name,
  ),
  LottiUserMessage(:final content, :final name) => UserMessage(
    content: _toOpenAiUserContent(content),
    name: name,
  ),
  LottiAssistantMessage(:final content, :final toolCalls, :final name) =>
    AssistantMessage(
      content: content,
      name: name,
      toolCalls: toolCalls?.map(_toOpenAiToolCall).toList(),
    ),
  LottiToolMessage(:final toolCallId, :final content) => ToolMessage(
    toolCallId: toolCallId,
    content: content,
  ),
};

/// Converts a conversation to its OpenAI-compatible wire form.
List<ChatMessage> toOpenAiMessages(List<LottiMessage> messages) =>
    messages.map(toOpenAiMessage).toList();

UserMessageContent _toOpenAiUserContent(LottiUserContent content) =>
    switch (content) {
      // Preserved as a bare string rather than a one-element parts array:
      // some compatible providers reject the array form for plain text.
      LottiUserText(:final text) => UserTextContent(text),
      LottiUserParts(:final parts) => UserPartsContent(
        parts.map(_toOpenAiContentPart).toList(),
      ),
    };

ContentPart _toOpenAiContentPart(LottiContentPart part) => switch (part) {
  LottiTextPart(:final text) => ContentPart.text(text),
  LottiImagePart(:final url) => ContentPart.imageUrl(url),
  LottiAudioPart(:final base64Data, :final format) => ContentPart.inputAudio(
    data: base64Data,
    format: switch (format) {
      LottiAudioFormat.mp3 => AudioFormat.mp3,
      LottiAudioFormat.wav => AudioFormat.wav,
    },
  ),
};

ToolCall _toOpenAiToolCall(LottiToolCall call) => ToolCall.functionCall(
  id: call.id,
  call: FunctionCall(name: call.name, arguments: call.arguments),
);

/// Converts a Lotti tool definition to its OpenAI-compatible wire form.
Tool toOpenAiTool(LottiTool tool) => Tool.function(
  name: tool.name,
  description: tool.description,
  parameters: tool.parameters,
);

/// Converts Lotti tool definitions to their OpenAI-compatible wire form.
List<Tool>? toOpenAiTools(List<LottiTool>? tools) =>
    tools?.map(toOpenAiTool).toList();

/// Converts a Lotti tool-choice policy to its OpenAI-compatible wire form.
ToolChoice? toOpenAiToolChoice(LottiToolChoice? choice) => switch (choice) {
  null => null,
  LottiToolChoiceAuto() => ToolChoice.auto(),
  LottiToolChoiceNone() => ToolChoice.none(),
  LottiToolChoiceRequired() => ToolChoice.required(),
  LottiToolChoiceSpecific(:final name) => ToolChoice.function(name),
};

/// Converts an OpenAI-compatible streamed chunk into the Lotti domain.
LottiInferenceChunk fromOpenAiStreamEvent(ChatStreamEvent event) =>
    LottiInferenceChunk(
      id: event.id,
      created: event.created,
      model: event.model,
      choices: event.choices?.map(_fromOpenAiStreamChoice).toList(),
      usage: fromOpenAiUsage(event.usage),
    );

LottiChunkChoice _fromOpenAiStreamChoice(ChatStreamChoice choice) =>
    LottiChunkChoice(
      // The spec makes `index` optional and some compatible providers omit
      // it; a single-choice stream is the overwhelmingly common case, so
      // falling back to 0 keeps those providers working.
      index: choice.index ?? 0,
      delta: _fromOpenAiDelta(choice.delta),
      finishReason: fromOpenAiFinishReason(choice.finishReason),
    );

LottiDelta _fromOpenAiDelta(ChatDelta delta) => LottiDelta(
  content: delta.content,
  toolCalls: delta.toolCalls?.map(_fromOpenAiToolCallDelta).toList(),
);

LottiToolCallChunk _fromOpenAiToolCallDelta(ToolCallDelta delta) =>
    LottiToolCallChunk(
      id: delta.id,
      index: delta.index,
      name: delta.function?.name,
      arguments: delta.function?.arguments,
    );

/// Converts an OpenAI-compatible usage record into the Lotti domain.
///
/// Flattens the two `*_tokens_details` objects, which are the only nested
/// usage fields Lotti consumes.
LottiUsage? fromOpenAiUsage(Usage? usage) {
  if (usage == null) return null;
  return LottiUsage(
    promptTokens: usage.promptTokens,
    completionTokens: usage.completionTokens,
    totalTokens: usage.totalTokens,
    cachedInputTokens: usage.promptTokensDetails?.cachedTokens,
    reasoningTokens: usage.completionTokensDetails?.reasoningTokens,
    promptAudioTokens: usage.promptTokensDetails?.audioTokens,
    completionAudioTokens: usage.completionTokensDetails?.audioTokens,
  );
}

/// Converts an OpenAI-compatible finish reason into the Lotti domain.
LottiFinishReason? fromOpenAiFinishReason(FinishReason? reason) =>
    switch (reason) {
      null => null,
      FinishReason.stop => LottiFinishReason.stop,
      FinishReason.length => LottiFinishReason.length,
      // The legacy `function_call` reason means the same thing to every
      // consumer Lotti has, so it collapses into `toolCalls`.
      FinishReason.toolCalls ||
      FinishReason.functionCall => LottiFinishReason.toolCalls,
      FinishReason.contentFilter => LottiFinishReason.contentFilter,
      FinishReason.unknown => LottiFinishReason.unknown,
    };

/// Converts a Lotti request to its OpenAI-compatible wire form.
ChatCompletionCreateRequest toOpenAiRequest(LottiInferenceRequest request) =>
    ChatCompletionCreateRequest(
      model: request.model,
      messages: toOpenAiMessages(request.messages),
      temperature: request.temperature,
      maxCompletionTokens: request.maxCompletionTokens,
      maxTokens: request.maxTokens,
      tools: toOpenAiTools(request.tools),
      toolChoice: toOpenAiToolChoice(request.toolChoice),
      reasoningEffort: toOpenAiReasoningEffort(request.reasoningEffort),
    );

/// Serializes messages to OpenAI-compatible wire JSON.
///
/// Returns plain maps rather than client-library objects, so callers that only
/// need to inspect or transmit the wire form — including tests asserting on a
/// rendered prompt — do not have to depend on the library themselves.
List<Map<String, dynamic>> openAiMessagesJson(List<LottiMessage> messages) =>
    toOpenAiMessages(messages).map((m) => m.toJson()).toList();

/// Serializes tool definitions to OpenAI-compatible wire JSON.
///
/// Plain maps, for the same reason as [openAiMessagesJson].
List<Map<String, dynamic>> openAiToolsJson(List<LottiTool> tools) =>
    tools.map((t) => toOpenAiTool(t).toJson()).toList();

/// Serializes a Lotti request to OpenAI-compatible request JSON.
///
/// Used by the providers Lotti posts to directly rather than through the
/// client, which still need the body in the OpenAI shape. [stream] is passed
/// explicitly because the client selects streaming by which method is called,
/// so the request itself does not carry the flag.
Map<String, dynamic> openAiRequestJson(
  LottiInferenceRequest request, {
  bool stream = true,
}) => {...toOpenAiRequest(request).toJson(), 'stream': stream};

/// Converts a Lotti reasoning effort to its OpenAI-compatible wire form.
ReasoningEffort? toOpenAiReasoningEffort(LottiReasoningEffort? effort) =>
    switch (effort) {
      null => null,
      LottiReasoningEffort.minimal => ReasoningEffort.minimal,
      LottiReasoningEffort.low => ReasoningEffort.low,
      LottiReasoningEffort.medium => ReasoningEffort.medium,
      LottiReasoningEffort.high => ReasoningEffort.high,
    };

/// Classifies a client-library exception, or returns null when [error] did
/// not come from the client.
///
/// The library exposes a typed exception hierarchy, so this replaces the
/// runtime-type string matching callers used to need. Keeping it here means
/// `ai_error_utils.dart` classifies provider failures without naming the
/// library.
InferenceErrorType? openAiErrorType(Object error) => switch (error) {
  AuthenticationException() ||
  PermissionDeniedException() => InferenceErrorType.authentication,
  RateLimitException() => InferenceErrorType.rateLimit,
  RequestTimeoutException() => InferenceErrorType.timeout,
  ConnectionException() => InferenceErrorType.networkConnection,
  NotFoundException() ||
  BadRequestException() ||
  UnprocessableEntityException() ||
  ConflictException() => InferenceErrorType.invalidRequest,
  InternalServerException() => InferenceErrorType.serverError,
  // `ApiException` is the base of the status-coded ones above, so it is
  // matched last and only catches statuses the library does not specialize.
  ApiException() => InferenceErrorType.unknown,
  _ => null,
};

/// Whether [error] is the client failing to parse a single streamed frame
/// rather than the call itself failing.
///
/// Providers interleave keep-alive frames that are not chat chunks; one of
/// those must not tear down the stream.
bool isUnparseableStreamFrame(Object error) => error is ParseException;

/// A [LottiInferenceClient] backed by `openai_dart`.
///
/// Owns its transport and serves **one** request: the stream it returns
/// closes the underlying client when it completes, fails or is cancelled, so
/// callers that build a client per call do not leak a connection pool.
/// [close] is idempotent, so disposing explicitly as well is safe.
class OpenAiCompatInferenceClient implements LottiInferenceClient {
  /// Connects to an OpenAI-compatible endpoint at [baseUrl] using [apiKey].
  OpenAiCompatInferenceClient({required String baseUrl, required String apiKey})
    : _client = OpenAIClient.withApiKey(apiKey, baseUrl: baseUrl);

  /// Wraps a client configured by the caller, so a test can supply its own
  /// transport and observe disposal.
  @visibleForTesting
  OpenAiCompatInferenceClient.wrapping(this._client);

  final OpenAIClient _client;

  @override
  Stream<LottiInferenceChunk> createChatCompletionStream(
    LottiInferenceRequest request,
  ) async* {
    try {
      yield* _client.chat.completions
          .createStream(toOpenAiRequest(request))
          .map(fromOpenAiStreamEvent);
    } finally {
      close();
    }
  }

  @override
  void close() => _client.close();
}
