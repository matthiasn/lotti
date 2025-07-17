import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_completion_service.g.dart';

@riverpod
class ChecklistCompletionService extends _$ChecklistCompletionService {
  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async {
    return [];
  }

  /// Analyze context and suggest checklist completions
  Future<void> analyzeForCompletions({
    required String taskId,
    required String contextText,
    required List<ChecklistItem> checklistItems,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only proceed if model supports function calling
    if (!model.supportsFunctionCalling) {
      return;
    }

    // Filter out already completed items
    final incompleteItems =
        checklistItems.where((item) => item.data.isChecked == false).toList();

    if (incompleteItems.isEmpty) {
      return;
    }

    // Build context for AI
    final itemsContext = incompleteItems
        .map((item) => '- ${item.data.title} (ID: ${item.id})')
        .join('\n');

    const systemMessage = '''
You are an assistant that analyzes text context to determine if any checklist items have been completed.
Look for evidence that suggests tasks have been done, such as:
- Past tense verbs indicating completion
- Explicit statements about finishing tasks
- Results or outcomes that imply task completion
Only suggest completion if there's clear evidence in the provided context.
''';

    final userMessage = '''
Context:
$contextText

Checklist items to analyze:
$itemsContext

Based on the context, identify which checklist items appear to be completed.
''';

    try {
      final client = OpenAIClient(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
      );

      final response = await client.createChatCompletion(
        request: CreateChatCompletionRequest(
          messages: [
            const ChatCompletionMessage.system(content: systemMessage),
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(userMessage),
            ),
          ],
          model: ChatCompletionModel.modelId(model.providerModelId),
          temperature: 0.3,
          tools: ChecklistCompletionFunctions.getTools(),
          toolChoice: const ChatCompletionToolChoiceOption.mode(
            ChatCompletionToolChoiceMode.auto,
          ),
        ),
      );

      final suggestions = <ChecklistCompletionSuggestion>[];

      // Process tool calls
      for (final choice in response.choices) {
        final toolCalls = choice.message.toolCalls ?? [];
        for (final toolCall in toolCalls) {
          if (toolCall.function.name ==
              ChecklistCompletionFunctions.suggestChecklistCompletion) {
            try {
              final arguments = jsonDecode(toolCall.function.arguments)
                  as Map<String, dynamic>;
              final suggestion = ChecklistCompletionSuggestion(
                checklistItemId: arguments['checklistItemId'] as String,
                reason: arguments['reason'] as String,
                confidence: ChecklistCompletionConfidence.values.firstWhere(
                  (e) => e.name == arguments['confidence'],
                  orElse: () => ChecklistCompletionConfidence.low,
                ),
              );
              suggestions.add(suggestion);
            } catch (e) {
              // Log error parsing function arguments
              developer.log(
                'Error parsing checklist completion suggestion: $e',
                name: 'ChecklistCompletionService',
              );
            }
          }
        }
      }

      if (suggestions.isNotEmpty) {
        state = AsyncData(suggestions);

        // Notify the UI about available suggestions
        for (final suggestion in suggestions) {
          _notifyChecklistItem(suggestion.checklistItemId, taskId);
        }
      }
    } catch (e) {
      // Log error but don't fail the whole operation
      developer.log(
        'Error analyzing checklist completions: $e',
        name: 'ChecklistCompletionService',
        error: e,
      );
    }
  }

  /// Notify a specific checklist item controller about a suggestion
  void _notifyChecklistItem(String checklistItemId, String taskId) {
    // This will be picked up by the UI to show visual indication
    ref.invalidate(checklistItemControllerProvider(
      id: checklistItemId,
      taskId: taskId,
    ));
  }

  /// Add multiple suggestions at once
  void addSuggestions(List<ChecklistCompletionSuggestion> suggestions) {
    developer.log(
      'ChecklistCompletionService.addSuggestions called with ${suggestions.length} suggestions',
      name: 'ChecklistCompletionService',
    );

    for (final suggestion in suggestions) {
      developer.log(
        '  - ${suggestion.checklistItemId}: ${suggestion.confidence.name}',
        name: 'ChecklistCompletionService',
      );
    }

    state = AsyncData(suggestions);
  }

  /// Clear suggestion for a specific checklist item
  void clearSuggestion(String checklistItemId) {
    final currentSuggestions = state.value ?? [];
    final updatedSuggestions = currentSuggestions
        .where((s) => s.checklistItemId != checklistItemId)
        .toList();
    state = AsyncData(updatedSuggestions);
  }

  /// Get suggestion for a specific checklist item
  ChecklistCompletionSuggestion? getSuggestionForItem(String checklistItemId) {
    final suggestions = state.value ?? [];
    try {
      return suggestions
          .firstWhere((s) => s.checklistItemId == checklistItemId);
    } catch (_) {
      return null;
    }
  }
}
