import 'package:openai_dart/openai_dart.dart';

/// Model families that answer a pinned `tool_choice` with a tool call written
/// as prose instead of a structured one.
///
/// DeepSeek emits its own `<｜DSML｜ invoke name="...">{...}` text and returns
/// an empty `tool_calls` array, so the call is invisible to every strategy —
/// the wake looks like a model that declined to act. The same request without
/// `tool_choice` returns a proper structured call, and the single-tool `tools`
/// list already leaves nothing else to call.
///
/// Measured on 2026-09-16 against Melious with `deepseek-v4.1-flash`,
/// `deepseek-v4.1-flash:speed`, `glm-5.3-flash:speed` and `glm-5.3:speed`,
/// with `tool_choice` both named and `required`: only the DeepSeek models
/// break, and only when it is pinned.
const _toolChoiceProseModelFragments = ['deepseek'];

/// The `tool_choice` a forced single-tool retry should send to [modelId].
///
/// Returns null when pinning the tool would lose the call: the caller still
/// restricts `tools` to the one tool it wants, which is what steers the model
/// in practice. Returns the named choice otherwise, so models that honour it
/// keep the stronger guarantee.
ChatCompletionToolChoiceOption? forcedToolChoiceFor({
  required String modelId,
  required String toolName,
}) {
  final normalized = modelId.toLowerCase();
  if (_toolChoiceProseModelFragments.any(normalized.contains)) return null;
  return ChatCompletionToolChoiceOption.tool(
    ChatCompletionNamedToolChoice(
      type: ChatCompletionNamedToolChoiceType.function,
      function: ChatCompletionFunctionCallOption(name: toolName),
    ),
  );
}
