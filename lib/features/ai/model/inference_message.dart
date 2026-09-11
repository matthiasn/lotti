import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Lotti-owned conversation types for the inference layer.
///
/// Every provider repository, agent workflow and conversation consumer speaks
/// these types. The `openai_dart` package is confined to
/// `openai_compat_adapter.dart`, so upgrading it touches the adapter rather
/// than every call site. Nothing here is persisted — conversations are rebuilt
/// in memory — so these models carry no JSON contract of their own.

const _listEquality = ListEquality<Object?>();

/// The role a [LottiMessage] plays in a conversation.
enum LottiMessageRole {
  /// Instructions that frame the whole conversation.
  system,

  /// Higher-priority instructions on models that separate them from [system].
  developer,

  /// Input from the person using the app.
  user,

  /// Output from the model, optionally requesting tool calls.
  assistant,

  /// The result of executing one tool call.
  tool,
}

/// The container format of a [LottiAudioPart] payload.
enum LottiAudioFormat {
  /// MPEG audio.
  mp3,

  /// Uncompressed WAV audio.
  wav,
}

/// One part of a multimodal user message.
@immutable
sealed class LottiContentPart {
  const LottiContentPart();

  /// Plain text.
  const factory LottiContentPart.text(String text) = LottiTextPart;

  /// An image addressed by URL or `data:` URI.
  const factory LottiContentPart.image(String url) = LottiImagePart;

  /// Base64-encoded audio in [format].
  const factory LottiContentPart.audio({
    required String base64Data,
    required LottiAudioFormat format,
  }) = LottiAudioPart;
}

/// A text part of a multimodal user message.
@immutable
final class LottiTextPart extends LottiContentPart {
  /// Creates a text part carrying [text].
  const LottiTextPart(this.text);

  /// The literal text.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LottiTextPart && other.text == text;

  @override
  int get hashCode => Object.hash(LottiTextPart, text);

  @override
  String toString() => 'LottiTextPart(${text.length} chars)';
}

/// An image part of a multimodal user message.
@immutable
final class LottiImagePart extends LottiContentPart {
  /// Creates an image part pointing at [url].
  ///
  /// [url] is either an `https://` URL or a `data:image/...;base64,...` URI.
  const LottiImagePart(this.url);

  /// Where the image lives.
  final String url;

  @override
  bool operator ==(Object other) => other is LottiImagePart && other.url == url;

  @override
  int get hashCode => Object.hash(LottiImagePart, url);

  @override
  String toString() => 'LottiImagePart(${url.length} chars)';
}

/// An audio part of a multimodal user message.
@immutable
final class LottiAudioPart extends LottiContentPart {
  /// Creates an audio part carrying [base64Data] in [format].
  const LottiAudioPart({required this.base64Data, required this.format});

  /// Base64-encoded audio bytes, without a `data:` prefix.
  final String base64Data;

  /// The container format of [base64Data].
  final LottiAudioFormat format;

  @override
  bool operator ==(Object other) =>
      other is LottiAudioPart &&
      other.base64Data == base64Data &&
      other.format == format;

  @override
  int get hashCode => Object.hash(LottiAudioPart, base64Data, format);

  @override
  String toString() =>
      'LottiAudioPart(${format.name}, ${base64Data.length} chars)';
}

/// The content of a user message.
///
/// The distinction between [LottiUserText] and [LottiUserParts] is preserved
/// on the wire: some OpenAI-compatible providers reject a single-element parts
/// array where they accept a bare string, so a text-only message must stay a
/// string rather than being normalized into parts.
@immutable
sealed class LottiUserContent {
  const LottiUserContent();

  /// A plain string message.
  const factory LottiUserContent.text(String text) = LottiUserText;

  /// A multimodal message built from [parts].
  const factory LottiUserContent.parts(List<LottiContentPart> parts) =
      LottiUserParts;

  /// The text carried by this content, concatenating any text parts.
  String get text;
}

/// User content sent as a bare string.
@immutable
final class LottiUserText extends LottiUserContent {
  /// Creates string content holding [text].
  const LottiUserText(this.text);

  @override
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LottiUserText && other.text == text;

  @override
  int get hashCode => Object.hash(LottiUserText, text);

  @override
  String toString() => 'LottiUserText(${text.length} chars)';
}

/// User content sent as an array of parts.
@immutable
final class LottiUserParts extends LottiUserContent {
  /// Creates multimodal content from [parts].
  const LottiUserParts(this.parts);

  /// The ordered parts of the message.
  final List<LottiContentPart> parts;

  @override
  String get text =>
      parts.whereType<LottiTextPart>().map((p) => p.text).join('\n');

  @override
  bool operator ==(Object other) =>
      other is LottiUserParts && _listEquality.equals(other.parts, parts);

  @override
  int get hashCode => Object.hash(LottiUserParts, _listEquality.hash(parts));

  @override
  String toString() => 'LottiUserParts(${parts.length} parts)';
}

/// A request from the model to execute one tool.
///
/// Flattened deliberately: the OpenAI wire format nests name and arguments
/// under a `function` object, but that nesting is a transport detail the
/// adapter owns, not something every call site should restate.
@immutable
class LottiToolCall {
  /// Creates a tool call.
  const LottiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  /// Identifier correlating this call with its [LottiToolMessage] result.
  final String id;

  /// The name of the tool to invoke.
  final String name;

  /// The call arguments as a raw JSON string, exactly as the model emitted it.
  ///
  /// Kept as a string rather than a decoded map because models stream it in
  /// fragments and sometimes emit malformed JSON, which callers must be able
  /// to inspect and repair.
  final String arguments;

  /// Returns a copy with the given fields replaced.
  LottiToolCall copyWith({String? id, String? name, String? arguments}) =>
      LottiToolCall(
        id: id ?? this.id,
        name: name ?? this.name,
        arguments: arguments ?? this.arguments,
      );

  @override
  bool operator ==(Object other) =>
      other is LottiToolCall &&
      other.id == id &&
      other.name == name &&
      other.arguments == arguments;

  @override
  int get hashCode => Object.hash(id, name, arguments);

  @override
  String toString() => 'LottiToolCall($id, $name, $arguments)';
}

/// A single message in an inference conversation.
@immutable
sealed class LottiMessage {
  const LottiMessage();

  /// Instructions that frame the conversation.
  const factory LottiMessage.system(String content, {String? name}) =
      LottiSystemMessage;

  /// Higher-priority instructions, for models that separate them from system.
  const factory LottiMessage.developer(String content, {String? name}) =
      LottiDeveloperMessage;

  /// A user turn carrying [content].
  const factory LottiMessage.user(LottiUserContent content, {String? name}) =
      LottiUserMessage;

  /// A user turn carrying plain [text].
  ///
  /// Not const: Dart forbids a const constructor from building the nested
  /// content object. Use `LottiMessage.user(LottiUserText(...))` where a
  /// compile-time constant is required.
  factory LottiMessage.userText(String text, {String? name}) =>
      LottiUserMessage(LottiUserContent.text(text), name: name);

  /// A user turn carrying multimodal [parts].
  ///
  /// Not const, for the same reason as [LottiMessage.userText].
  factory LottiMessage.userParts(
    List<LottiContentPart> parts, {
    String? name,
  }) => LottiUserMessage(LottiUserContent.parts(parts), name: name);

  /// A model turn, carrying text, tool calls, or both.
  const factory LottiMessage.assistant({
    String? content,
    List<LottiToolCall>? toolCalls,
    String? name,
  }) = LottiAssistantMessage;

  /// The result of executing the tool call identified by [toolCallId].
  const factory LottiMessage.tool({
    required String toolCallId,
    required String content,
  }) = LottiToolMessage;

  /// The role this message plays.
  LottiMessageRole get role;
}

/// A system-role message.
@immutable
final class LottiSystemMessage extends LottiMessage {
  /// Creates a system message holding [content].
  const LottiSystemMessage(this.content, {this.name});

  /// The instruction text.
  final String content;

  /// Optional participant name.
  final String? name;

  @override
  LottiMessageRole get role => LottiMessageRole.system;

  @override
  bool operator ==(Object other) =>
      other is LottiSystemMessage &&
      other.content == content &&
      other.name == name;

  @override
  int get hashCode => Object.hash(LottiSystemMessage, content, name);

  @override
  String toString() => 'LottiSystemMessage(${content.length} chars)';
}

/// A developer-role message.
@immutable
final class LottiDeveloperMessage extends LottiMessage {
  /// Creates a developer message holding [content].
  const LottiDeveloperMessage(this.content, {this.name});

  /// The instruction text.
  final String content;

  /// Optional participant name.
  final String? name;

  @override
  LottiMessageRole get role => LottiMessageRole.developer;

  @override
  bool operator ==(Object other) =>
      other is LottiDeveloperMessage &&
      other.content == content &&
      other.name == name;

  @override
  int get hashCode => Object.hash(LottiDeveloperMessage, content, name);

  @override
  String toString() => 'LottiDeveloperMessage(${content.length} chars)';
}

/// A user-role message.
@immutable
final class LottiUserMessage extends LottiMessage {
  /// Creates a user message holding [content].
  const LottiUserMessage(this.content, {this.name});

  /// The message content, either a bare string or multimodal parts.
  final LottiUserContent content;

  /// Optional participant name.
  final String? name;

  @override
  LottiMessageRole get role => LottiMessageRole.user;

  @override
  bool operator ==(Object other) =>
      other is LottiUserMessage &&
      other.content == content &&
      other.name == name;

  @override
  int get hashCode => Object.hash(LottiUserMessage, content, name);

  @override
  String toString() => 'LottiUserMessage($content)';
}

/// An assistant-role message.
@immutable
final class LottiAssistantMessage extends LottiMessage {
  /// Creates an assistant message.
  const LottiAssistantMessage({this.content, this.toolCalls, this.name});

  /// The visible text of the turn, if any.
  final String? content;

  /// Tool calls requested by the model, if any.
  final List<LottiToolCall>? toolCalls;

  /// Optional participant name.
  final String? name;

  /// Whether this turn requested at least one tool call.
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  @override
  LottiMessageRole get role => LottiMessageRole.assistant;

  @override
  bool operator ==(Object other) =>
      other is LottiAssistantMessage &&
      other.content == content &&
      other.name == name &&
      _listEquality.equals(other.toolCalls, toolCalls);

  @override
  int get hashCode => Object.hash(
    LottiAssistantMessage,
    content,
    name,
    toolCalls == null ? null : _listEquality.hash(toolCalls),
  );

  @override
  String toString() =>
      'LottiAssistantMessage(${content?.length ?? 0} chars, '
      '${toolCalls?.length ?? 0} tool calls)';
}

/// A tool-role message carrying the result of one tool call.
@immutable
final class LottiToolMessage extends LottiMessage {
  /// Creates a tool result for [toolCallId].
  const LottiToolMessage({required this.toolCallId, required this.content});

  /// The id of the [LottiToolCall] this message answers.
  final String toolCallId;

  /// The tool's result, serialized for the model.
  final String content;

  @override
  LottiMessageRole get role => LottiMessageRole.tool;

  @override
  bool operator ==(Object other) =>
      other is LottiToolMessage &&
      other.toolCallId == toolCallId &&
      other.content == content;

  @override
  int get hashCode => Object.hash(LottiToolMessage, toolCallId, content);

  @override
  String toString() => 'LottiToolMessage($toolCallId)';
}

/// Convenience accessors over the [LottiMessage] union.
extension LottiMessageAccessors on LottiMessage {
  /// The assistant text of this message, or `null` when it is not an
  /// assistant turn.
  ///
  /// An assistant turn that requested tool calls without narrating carries a
  /// null [LottiAssistantMessage.content], so this returns `null` for it too —
  /// callers looking for "the model's last words" want to skip those.
  String? get assistantContent => switch (this) {
    LottiAssistantMessage(:final content) => content,
    _ => null,
  };

  /// The result text of this message when it is a tool turn, or `null`
  /// otherwise.
  String? get toolContent => switch (this) {
    LottiToolMessage(:final content) => content,
    _ => null,
  };

  /// The text of this message when it is a user turn, or `null` otherwise.
  String? get userContent => switch (this) {
    LottiUserMessage(:final content) => content.text,
    _ => null,
  };

  /// The tool calls this message requested, or `null` when it is not an
  /// assistant turn.
  List<LottiToolCall>? get assistantToolCalls => switch (this) {
    LottiAssistantMessage(:final toolCalls) => toolCalls,
    _ => null,
  };

  /// The text this message carries, regardless of role.
  ///
  /// Returns `null` for an assistant turn that carried only tool calls.
  String? get textContent => switch (this) {
    LottiSystemMessage(:final content) => content,
    LottiDeveloperMessage(:final content) => content,
    LottiUserMessage(:final content) => content.text,
    LottiAssistantMessage(:final content) => content,
    LottiToolMessage(:final content) => content,
  };
}
