import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_wake_trace.dart';
import 'package:openai_dart/openai_dart.dart';

/// Reports every provider turn of a day-agent wake to a [DayAgentWakeTrace]:
/// when the stream was subscribed, when its first chunk arrived, the usage it
/// reported, and whether it ended in an error.
///
/// Sits outermost in the wake's repository chain, so a turn cut short by the
/// wake deadline or the output ceiling is recorded as failed with the time it
/// actually ran. It forwards every chunk and error unchanged.
class DayAgentTracingInferenceRepository
    implements InferenceRepositoryInterface {
  DayAgentTracingInferenceRepository({
    required this.delegate,
    required this.trace,
  });

  final InferenceRepositoryInterface delegate;
  final DayAgentWakeTrace trace;

  Stream<CreateChatCompletionStreamResponse> _traced(
    Stream<CreateChatCompletionStreamResponse> Function() open,
  ) async* {
    final index = trace.turnStarted();
    var awaitingFirst = true;
    var failed = false;
    try {
      await for (final response in open()) {
        if (awaitingFirst) {
          awaitingFirst = false;
          trace.turnFirstChunk(index);
        }
        final usage = response.usage;
        if (usage != null) {
          trace.turnUsage(
            index,
            inputTokens: usage.promptTokens,
            outputTokens: usage.completionTokens,
            reasoningTokens: usage.completionTokensDetails?.reasoningTokens,
          );
        }
        yield response;
      }
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      trace.turnFinished(index, failed: failed);
    }
  }

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
  }) => _traced(
    () => delegate.generateTextWithMessages(
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

  @override
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required double temperature,
    required String? systemMessage,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) => _traced(
    () => delegate.generateText(
      prompt: prompt,
      model: model,
      temperature: temperature,
      systemMessage: systemMessage,
      provider: provider,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
      toolChoice: toolChoice,
    ),
  );
}
