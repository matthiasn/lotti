// PROPOSAL — internal AI inference types to replace openai_dart vocabulary.
//
// Design notes (open for review):
//
// 1. Sealed classes for the message and content-part hierarchies, so
//    consumers can `switch` exhaustively instead of doing `m.role == X`
//    runtime checks. This is the main ergonomic win vs. the freezed
//    union the codebase uses today.
//
// 2. Plain data classes (no freezed/json_serializable). JSON conversion
//    lives in a separate file (`ai_chat_message_json.dart`, not in this
//    proposal yet) so the data model stays readable.
//
// 3. `Ai` prefix to disambiguate from the UI-layer `ChatMessage` in
//    `lib/features/ai_chat/models/chat_message.dart`. Matches the
//    existing `AiConfig*` convention.
//
// 4. The OpenAI wire format is the de-facto shape we already translate
//    every provider into (Mistral, Voxtral, Ollama). Field names follow
//    Dart conventions; JSON keys get mapped at the boundary.

import 'package:meta/meta.dart';

// =============================================================================
// Roles
// =============================================================================

/// Wire-level role string. Kept as an enum for exhaustive switches when we
/// parse inbound messages from providers that don't fit our sealed hierarchy
/// (e.g. Mistral echoes `function` and `developer` roles we never construct).
enum AiMessageRole {
  system,
  user,
  assistant,
  tool,
  function,
  developer;

  String get wire => name;

  static AiMessageRole? tryParse(String value) {
    for (final role in AiMessageRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}

// =============================================================================
// Messages
// =============================================================================

/// Sealed hierarchy of chat messages. Use pattern matching:
///
/// ```dart
/// switch (msg) {
///   AiSystemMessage(:final content) => ...,
///   AiUserMessage(:final content) => ...,
///   AiAssistantMessage(:final content, :final toolCalls) => ...,
///   AiToolResultMessage(:final toolCallId, :final content) => ...,
/// }
/// ```
sealed class AiChatMessage {
  const AiChatMessage();

  AiMessageRole get role;
}

@immutable
final class AiSystemMessage extends AiChatMessage {
  const AiSystemMessage(this.content);

  final String content;

  @override
  AiMessageRole get role => AiMessageRole.system;
}

@immutable
final class AiUserMessage extends AiChatMessage {
  const AiUserMessage(this.content);

  /// Either a plain string or a list of multi-modal parts.
  final AiUserContent content;

  @override
  AiMessageRole get role => AiMessageRole.user;
}

/// Assistant turn. May carry plain text content, tool calls, or both.
/// `content` and `toolCalls` can both be null when the assistant emits an
/// empty placeholder turn (rare but observed).
@immutable
final class AiAssistantMessage extends AiChatMessage {
  const AiAssistantMessage({this.content, this.toolCalls});

  final String? content;
  final List<AiToolCall>? toolCalls;

  @override
  AiMessageRole get role => AiMessageRole.assistant;
}

/// Result of a tool invocation, sent back to the model.
@immutable
final class AiToolResultMessage extends AiChatMessage {
  const AiToolResultMessage({required this.toolCallId, required this.content});

  final String toolCallId;
  final String content;

  @override
  AiMessageRole get role => AiMessageRole.tool;
}

// =============================================================================
// User content (string vs. multi-part)
// =============================================================================

sealed class AiUserContent {
  const AiUserContent();
}

@immutable
final class AiUserTextContent extends AiUserContent {
  const AiUserTextContent(this.text);

  final String text;
}

@immutable
final class AiUserPartsContent extends AiUserContent {
  const AiUserPartsContent(this.parts);

  final List<AiContentPart> parts;
}

// =============================================================================
// Content parts (multi-modal)
// =============================================================================

sealed class AiContentPart {
  const AiContentPart();
}

@immutable
final class AiTextPart extends AiContentPart {
  const AiTextPart(this.text);

  final String text;
}

@immutable
final class AiImagePart extends AiContentPart {
  const AiImagePart(this.url);

  /// HTTP URL or `data:image/...;base64,...` data URI.
  final String url;
}

@immutable
final class AiAudioPart extends AiContentPart {
  const AiAudioPart({required this.data, required this.format});

  /// Base64-encoded audio data (no data-URI prefix).
  final String data;

  final AiAudioFormat format;
}

enum AiAudioFormat {
  mp3,
  wav;

  String get wire => name;
}

// =============================================================================
// Tools (function-calling)
// =============================================================================

/// Definition of a function the model is allowed to call.
@immutable
final class AiTool {
  const AiTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON-schema describing the function arguments.
  final Map<String, dynamic> parameters;
}

/// A concrete invocation of a tool emitted by the model.
@immutable
final class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;

  /// Raw JSON string emitted by the model — caller is responsible for
  /// parsing/validating it against the tool's parameter schema.
  final String arguments;
}

/// OpenAI-compatible `reasoning_effort` request value. Used to control the
/// reasoning/thinking depth of models served through the OpenAI-compatible
/// protocol (e.g. Gemini 3 via its OpenAI endpoint).
enum AiReasoningEffort {
  minimal,
  low,
  medium,
  high;

  String get wire => name;
}

/// Policy that controls whether/which tool the model calls.
sealed class AiToolChoice {
  const AiToolChoice();
}

final class AiToolChoiceAuto extends AiToolChoice {
  const AiToolChoiceAuto();
}

final class AiToolChoiceNone extends AiToolChoice {
  const AiToolChoiceNone();
}

final class AiToolChoiceRequired extends AiToolChoice {
  const AiToolChoiceRequired();
}

/// Force the model to call a specific named tool.
@immutable
final class AiToolChoiceFunction extends AiToolChoice {
  const AiToolChoiceFunction(this.name);

  final String name;
}

// =============================================================================
// Streaming response
// =============================================================================

/// One server-sent event from a streaming chat completion.
@immutable
final class AiStreamChunk {
  const AiStreamChunk({
    required this.id,
    required this.choices,
    this.model,
    this.created,
    this.usage,
  });

  final String id;
  final List<AiStreamChoice> choices;
  final String? model;
  final int? created;

  /// Only populated on the final chunk (OpenAI sends it once at end-of-stream
  /// when `stream_options.include_usage=true`; many providers omit it).
  final AiUsage? usage;
}

@immutable
final class AiStreamChoice {
  const AiStreamChoice({
    required this.index,
    required this.delta,
    this.finishReason,
  });

  final int index;
  final AiStreamDelta delta;

  /// `stop` / `length` / `tool_calls` / `content_filter` etc. Provider-specific
  /// values are kept as raw strings; we don't enumerate them.
  final String? finishReason;
}

/// Incremental update inside a stream choice. All fields nullable because the
/// model emits sparse deltas.
@immutable
final class AiStreamDelta {
  const AiStreamDelta({this.role, this.content, this.toolCalls});

  final AiMessageRole? role;
  final String? content;
  final List<AiToolCallChunk>? toolCalls;
}

/// One partial tool-call inside a stream delta. Many fields are nullable:
/// providers split a single tool call across many chunks, often sending only
/// the `arguments` delta after the initial `id`/`name` chunk.
@immutable
final class AiToolCallChunk {
  const AiToolCallChunk({
    this.index,
    this.id,
    this.name,
    this.arguments,
  });

  final int? index;
  final String? id;
  final String? name;
  final String? arguments;
}

@immutable
final class AiUsage {
  const AiUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.reasoningTokens,
    this.cachedInputTokens,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  /// Reasoning/"thinking" tokens billed separately by some providers (Gemini
  /// surfaces them as `thoughtsTokenCount`; OpenAI as
  /// `completion_tokens_details.reasoning_tokens`).
  final int? reasoningTokens;

  /// Prompt tokens served from the provider's cache (OpenAI exposes them as
  /// `prompt_tokens_details.cached_tokens`; Gemini as
  /// `cachedContentTokenCount`). Used for cost accounting.
  final int? cachedInputTokens;
}
