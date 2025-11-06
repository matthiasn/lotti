import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:openai_dart/openai_dart.dart';

/// Returns checklist-related tools appropriate for the given provider and model.
///
/// Unified rules:
/// - Always include suggest_checklist_completion
/// - Always include add_multiple_checklist_items (array-of-objects only)
List<ChatCompletionTool> getChecklistToolsForProvider({
  required AiConfigInferenceProvider provider,
  required AiConfigModel model,
}) {
  final all = ChecklistCompletionFunctions.getTools();
  // Resolve by name for safety against ordering changes
  ChatCompletionTool? toolByName(String name) =>
      all.firstWhere((t) => t.function.name == name);

  return <ChatCompletionTool>[
    toolByName(ChecklistCompletionFunctions.suggestChecklistCompletion)!,
    toolByName(ChecklistCompletionFunctions.addMultipleChecklistItems)!,
  ];
}
