import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Lotti-owned streaming-response types for the inference layer.
///
/// Every provider — including the ones that are not OpenAI-compatible at all,
/// such as Gemini, Ollama and DashScope — emits [LottiInferenceChunk]s, so
/// downstream consumers collect text, tool calls and usage identically
/// regardless of which backend produced them.

const _listEquality = ListEquality<Object?>();

/// Why the model stopped generating.
enum LottiFinishReason {
  /// The model finished its turn normally.
  stop,

  /// Generation hit the output token limit.
  length,

  /// The model requested one or more tool calls.
  toolCalls,

  /// The provider filtered the content.
  contentFilter,

  /// The provider reported a reason Lotti does not model.
  unknown,
}

/// Token accounting for one inference call.
///
/// Flattened from the OpenAI wire shape, which nests cached and reasoning
/// counts under separate `*_tokens_details` objects. Consumers only ever read
/// those two leaves, and they read them under these names.
@immutable
class LottiUsage {
  /// Creates a usage record.
  const LottiUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.cachedInputTokens,
    this.reasoningTokens,
    this.promptAudioTokens,
    this.completionAudioTokens,
  });

  /// Tokens consumed by the request.
  final int? promptTokens;

  /// Tokens produced in the response.
  final int? completionTokens;

  /// Total tokens billed for the call.
  final int? totalTokens;

  /// Prompt tokens served from the provider's cache.
  final int? cachedInputTokens;

  /// Completion tokens spent on hidden reasoning.
  final int? reasoningTokens;

  /// Prompt tokens attributable to audio input.
  final int? promptAudioTokens;

  /// Completion tokens attributable to audio output.
  final int? completionAudioTokens;

  /// Whether this record carries any token counts at all.
  ///
  /// Duration-only audio usage parses to a record with no counts, which
  /// callers treat as "no usage reported" rather than as zero consumption.
  bool get hasTokenData =>
      promptTokens != null ||
      completionTokens != null ||
      totalTokens != null ||
      cachedInputTokens != null ||
      reasoningTokens != null ||
      promptAudioTokens != null ||
      completionAudioTokens != null;

  /// Returns a copy with the given fields replaced.
  LottiUsage copyWith({
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    int? cachedInputTokens,
    int? reasoningTokens,
    int? promptAudioTokens,
    int? completionAudioTokens,
  }) => LottiUsage(
    promptTokens: promptTokens ?? this.promptTokens,
    completionTokens: completionTokens ?? this.completionTokens,
    totalTokens: totalTokens ?? this.totalTokens,
    cachedInputTokens: cachedInputTokens ?? this.cachedInputTokens,
    reasoningTokens: reasoningTokens ?? this.reasoningTokens,
    promptAudioTokens: promptAudioTokens ?? this.promptAudioTokens,
    completionAudioTokens: completionAudioTokens ?? this.completionAudioTokens,
  );

  @override
  bool operator ==(Object other) =>
      other is LottiUsage &&
      other.promptTokens == promptTokens &&
      other.completionTokens == completionTokens &&
      other.totalTokens == totalTokens &&
      other.cachedInputTokens == cachedInputTokens &&
      other.reasoningTokens == reasoningTokens &&
      other.promptAudioTokens == promptAudioTokens &&
      other.completionAudioTokens == completionAudioTokens;

  @override
  int get hashCode => Object.hash(
    promptTokens,
    completionTokens,
    totalTokens,
    cachedInputTokens,
    reasoningTokens,
    promptAudioTokens,
    completionAudioTokens,
  );

  @override
  String toString() =>
      'LottiUsage(prompt: $promptTokens, completion: $completionTokens, '
      'total: $totalTokens)';
}

/// A partial tool call arriving across one or more streamed chunks.
///
/// [name] and [arguments] are both optional and both arrive in fragments:
/// providers typically send the name once in the opening chunk and then stream
/// the arguments as a sequence of JSON fragments that must be concatenated.
@immutable
class LottiToolCallChunk {
  /// Creates a streamed tool-call fragment.
  const LottiToolCallChunk({
    this.id,
    this.index,
    this.name,
    this.arguments,
  });

  /// The provider's id for this tool call, when it sends one.
  final String? id;

  /// Position of this call within the turn, used to correlate fragments
  /// when the provider omits [id] on continuation chunks.
  final int? index;

  /// The tool name, usually present only on the opening fragment.
  final String? name;

  /// A fragment of the JSON argument string.
  final String? arguments;

  @override
  bool operator ==(Object other) =>
      other is LottiToolCallChunk &&
      other.id == id &&
      other.index == index &&
      other.name == name &&
      other.arguments == arguments;

  @override
  int get hashCode => Object.hash(id, index, name, arguments);

  @override
  String toString() =>
      'LottiToolCallChunk(id: $id, index: $index, name: $name)';
}

/// The incremental payload of one streamed choice.
@immutable
class LottiDelta {
  /// Creates a streamed delta.
  const LottiDelta({this.content, this.toolCalls});

  /// Newly generated text, if this chunk carried any.
  final String? content;

  /// Tool-call fragments carried by this chunk, if any.
  final List<LottiToolCallChunk>? toolCalls;

  @override
  bool operator ==(Object other) =>
      other is LottiDelta &&
      other.content == content &&
      _listEquality.equals(other.toolCalls, toolCalls);

  @override
  int get hashCode => Object.hash(
    content,
    toolCalls == null ? null : _listEquality.hash(toolCalls),
  );

  @override
  String toString() =>
      'LottiDelta(${content?.length ?? 0} chars, '
      '${toolCalls?.length ?? 0} tool calls)';
}

/// One choice within a streamed chunk.
@immutable
class LottiChunkChoice {
  /// Creates a streamed choice.
  const LottiChunkChoice({required this.index, this.delta, this.finishReason});

  /// The index of this choice within the response.
  final int index;

  /// The incremental payload, absent on chunks that carry only a finish
  /// reason or usage.
  final LottiDelta? delta;

  /// Why generation stopped, present on the final chunk of the choice.
  final LottiFinishReason? finishReason;

  @override
  bool operator ==(Object other) =>
      other is LottiChunkChoice &&
      other.index == index &&
      other.delta == delta &&
      other.finishReason == finishReason;

  @override
  int get hashCode => Object.hash(index, delta, finishReason);

  @override
  String toString() =>
      'LottiChunkChoice($index, finish: ${finishReason?.name})';
}

/// One chunk of a streamed inference response.
///
/// Providers that are not OpenAI-compatible synthesize these directly rather
/// than round-tripping through an OpenAI-shaped payload.
@immutable
class LottiInferenceChunk {
  /// Creates a response chunk.
  const LottiInferenceChunk({
    this.id,
    this.created,
    this.model,
    this.choices,
    this.usage,
  });

  /// The provider's id for the completion, when it sends one.
  final String? id;

  /// Unix timestamp of creation, when the provider sends one.
  final int? created;

  /// The model that produced the chunk.
  final String? model;

  /// The choices carried by this chunk; empty on usage-only final frames.
  final List<LottiChunkChoice>? choices;

  /// Token accounting, usually present only on the final chunk.
  final LottiUsage? usage;

  /// The text carried by the first choice of this chunk, if any.
  String? get textDelta => choices?.firstOrNull?.delta?.content;

  /// Returns a copy with the given fields replaced.
  LottiInferenceChunk copyWith({
    String? id,
    int? created,
    String? model,
    List<LottiChunkChoice>? choices,
    LottiUsage? usage,
  }) => LottiInferenceChunk(
    id: id ?? this.id,
    created: created ?? this.created,
    model: model ?? this.model,
    choices: choices ?? this.choices,
    usage: usage ?? this.usage,
  );

  @override
  bool operator ==(Object other) =>
      other is LottiInferenceChunk &&
      other.id == id &&
      other.created == created &&
      other.model == model &&
      other.usage == usage &&
      _listEquality.equals(other.choices, choices);

  @override
  int get hashCode => Object.hash(
    id,
    created,
    model,
    usage,
    choices == null ? null : _listEquality.hash(choices),
  );

  @override
  String toString() =>
      'LottiInferenceChunk($id, ${choices?.length ?? 0} choices)';
}
