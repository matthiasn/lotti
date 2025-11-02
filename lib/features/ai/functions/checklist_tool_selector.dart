import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Returns checklist-related tools appropriate for the given provider and model.
///
/// Rules (kept intentionally small and explicit):
/// - Always include suggest_checklist_completion and add_checklist_item.
/// - Include add_multiple_checklist_items only for the precise combination
///   of Ollama provider AND GPT‑OSS model identifiers.
///   We use the exact prefix `gpt-oss:` for model ids to avoid accidentally
///   matching future variants that should not receive the multi-item tool.
List<ChatCompletionTool> getChecklistToolsForProvider({
  required AiConfigInferenceProvider provider,
  required AiConfigModel model,
}) {
  final all = ChecklistCompletionFunctions.getTools();
  // Resolve by name for safety against ordering changes
  ChatCompletionTool? toolByName(String name) =>
      all.firstWhere((t) => t.function.name == name);

  final tools = <ChatCompletionTool>[
    toolByName(ChecklistCompletionFunctions.suggestChecklistCompletion)!,
    toolByName(ChecklistCompletionFunctions.addChecklistItem)!,
  ];

  // Provider gate: only Ollama
  final isOllama =
      provider.inferenceProviderType == InferenceProviderType.ollama;
  // Model gate: only GPT‑OSS variants exposed by Ollama (e.g. gpt-oss:20b)
  final isGptOss = model.providerModelId.startsWith('gpt-oss:');

  if (isOllama && isGptOss) {
    tools.add(
        toolByName(ChecklistCompletionFunctions.addMultipleChecklistItems)!);
  }

  return tools;
}
