/// Request-side knobs the inference layer exposes to callers.
///
/// See `inference_message.dart` for why the AI layer owns these rather than
/// borrowing them from `openai_dart`.
library;

import 'package:lotti/features/ai/model/inference_message.dart';
import 'package:lotti/features/ai/model/inference_tool.dart';
import 'package:meta/meta.dart';

/// How much hidden reasoning a model should spend before answering.
///
/// Ordered from cheapest to most thorough. Lotti models only the four levels
/// it actually offers; providers that support more (`none`, `xhigh`) are
/// clamped by the adapter rather than exposed here.
enum LottiReasoningEffort {
  /// The smallest reasoning budget the model supports.
  minimal,

  /// A small reasoning budget. Lotti's app-wide default thinking level.
  low,

  /// A moderate reasoning budget.
  medium,

  /// The largest reasoning budget Lotti offers.
  high,
}

/// A chat-completion request, described in Lotti's own terms.
///
/// The adapter turns this into whatever the client library currently wants —
/// a typed request object for the OpenAI-compatible path, or raw wire JSON for
/// the providers Lotti posts to directly.
@immutable
class LottiInferenceRequest {
  /// Creates a chat-completion request.
  const LottiInferenceRequest({
    required this.messages,
    required this.model,
    this.temperature,
    this.maxCompletionTokens,
    this.maxTokens,
    this.tools,
    this.toolChoice,
    this.reasoningEffort,
  });

  /// The full conversation to send.
  final List<LottiMessage> messages;

  /// The model identifier, as the provider spells it.
  final String model;

  /// Sampling temperature.
  final double? temperature;

  /// Output token limit, in the newer `max_completion_tokens` form.
  final int? maxCompletionTokens;

  /// Output token limit, in the legacy `max_tokens` form some providers
  /// still require.
  final int? maxTokens;

  /// Functions the model may call.
  final List<LottiTool>? tools;

  /// How the model should choose between [tools].
  final LottiToolChoice? toolChoice;

  /// How much hidden reasoning to spend before answering.
  ///
  /// Whether the response streams is not modelled here: it is decided by
  /// which call the caller makes, so a request cannot disagree with it.
  final LottiReasoningEffort? reasoningEffort;

  /// Returns a copy with the given fields replaced.
  LottiInferenceRequest copyWith({
    List<LottiMessage>? messages,
    String? model,
    double? temperature,
    int? maxCompletionTokens,
    int? maxTokens,
    List<LottiTool>? tools,
    LottiToolChoice? toolChoice,
    LottiReasoningEffort? reasoningEffort,
  }) => LottiInferenceRequest(
    messages: messages ?? this.messages,
    model: model ?? this.model,
    temperature: temperature ?? this.temperature,
    maxCompletionTokens: maxCompletionTokens ?? this.maxCompletionTokens,
    maxTokens: maxTokens ?? this.maxTokens,
    tools: tools ?? this.tools,
    toolChoice: toolChoice ?? this.toolChoice,
    reasoningEffort: reasoningEffort ?? this.reasoningEffort,
  );

  @override
  String toString() =>
      'LottiInferenceRequest($model, ${messages.length} messages, '
      '${tools?.length ?? 0} tools)';
}
