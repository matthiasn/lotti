import 'dart:async';

import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

/// How long one of her provider calls may go without a chunk before it
/// counts as stalled. A warm call's first chunk takes about a second and a
/// cold one up to five (live, Mistral, 2026-11-09); the same probe also saw
/// a call sit 19 s before its first chunk and take 44 s in all.
///
/// shortcut: one gap limit for every model — a model set up to think
/// silently for longer than this would time out; make it per model if one
/// ever routes her turns.
const Duration frontInferenceStallTimeout = Duration(seconds: 15);

/// Bounds a stalled provider call on the user's interactive turn: a call
/// that sends nothing for [stallTimeout] is dropped and sent once more —
/// safe, since nothing of it was read — and a second stall, or one after
/// the first chunk, fails the turn with a [TimeoutException], which the
/// chat names as such.
class FrontInferenceStallGuard extends InferenceRepositoryInterface {
  FrontInferenceStallGuard(
    this.delegate, {
    this.stallTimeout = frontInferenceStallTimeout,
    this.onRetry,
  });

  /// The provider call it guards.
  final InferenceRepositoryInterface delegate;
  final Duration stallTimeout;

  /// Told when a stalled call is sent again.
  final void Function()? onRetry;

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    InferenceImpactCollector? impactCollector,
  }) async* {
    for (var attempt = 0; ; attempt++) {
      final chunks = StreamIterator(
        delegate.generateTextWithMessages(
          messages: messages,
          model: model,
          temperature: temperature,
          provider: provider,
          maxCompletionTokens: maxCompletionTokens,
          tools: tools,
          toolChoice: toolChoice,
          thoughtSignatures: thoughtSignatures,
          signatureCollector: signatureCollector,
          turnIndex: turnIndex,
          impactCollector: impactCollector,
        ),
      );
      var received = false;
      var ended = false;
      try {
        while (await chunks.moveNext().timeout(stallTimeout)) {
          received = true;
          yield chunks.current;
        }
        ended = true;
        return;
      } on TimeoutException {
        if (received || attempt > 0) rethrow;
        onRetry?.call();
      } finally {
        // Drops a request that did not end on its own: the stalled one, or
        // one whose reader went away.
        if (!ended) await chunks.cancel();
      }
    }
  }
}
