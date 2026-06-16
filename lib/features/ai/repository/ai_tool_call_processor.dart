import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/utils/checklist_validation.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Dispatches streamed assistant tool calls for the unified AI inference path:
/// checklist completion suggestions, checklist add/update, task language
/// detection, and `assign_task_labels`.
///
/// Extracted from `UnifiedAiInferenceRepository` as a standalone collaborator
/// (it needs only [ref], a clock, and the repository-owned
/// `AutoChecklistService`), keeping the repository focused on the inference run.
class AiToolCallProcessor {
  AiToolCallProcessor({
    required this.ref,
    required this.clock,
    required this.autoChecklistServiceResolver,
  });

  final Ref ref;
  final DateTime Function() clock;

  /// Resolves the repository-owned (test-injectable) auto-checklist service.
  final AutoChecklistService Function() autoChecklistServiceResolver;

  AutoChecklistService get autoChecklistService => autoChecklistServiceResolver();

  Future<bool> process({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Task task,
  }) async {
    var languageWasSet = false;
    var currentTask = task; // Create mutable copy for updates
    developer.log(
      'Starting to process ${toolCalls.length} tool calls for checklist operations',
      name: 'UnifiedAiInferenceRepository',
    );

    // Log all tool calls for debugging
    for (var i = 0; i < toolCalls.length; i++) {
      final tc = toolCalls[i];
      developer.log(
        'Tool call [$i]: name=${tc.function.name}, '
        'args=${tc.function.arguments.length > 200 ? '${tc.function.arguments.substring(0, 200)}...' : tc.function.arguments}',
        name: 'UnifiedAiInferenceRepository',
      );
    }

    final suggestions = <ChecklistCompletionSuggestion>[];

    for (final toolCall in toolCalls) {
      developer.log(
        'Processing tool call: ${toolCall.function.name}',
        name: 'UnifiedAiInferenceRepository',
      );

      if (toolCall.function.name ==
          ChecklistCompletionFunctions.suggestChecklistCompletion) {
        // Handle case where multiple JSON objects might be concatenated
        final jsonObjects = extractJsonObjects(toolCall.function.arguments);

        if (jsonObjects.isEmpty) {
          // Log metadata only — raw arguments can carry user content/PII
          // and can be arbitrarily large.
          developer.log(
            'No valid JSON found in arguments '
            '(toolCallId=${toolCall.id}, '
            'length=${toolCall.function.arguments.length})',
            name: 'UnifiedAiInferenceRepository',
          );
          continue;
        }

        developer.log(
          'Found ${jsonObjects.length} JSON objects in arguments',
          name: 'UnifiedAiInferenceRepository',
        );

        for (final jsonStr in jsonObjects) {
          try {
            developer.log(
              'Parsing individual JSON: $jsonStr',
              name: 'UnifiedAiInferenceRepository',
            );

            final arguments = jsonDecode(jsonStr) as Map<String, dynamic>;
            final suggestion = ChecklistCompletionSuggestion(
              checklistItemId: arguments['checklistItemId'] as String,
              reason: arguments['reason'] as String,
              confidence: ChecklistCompletionConfidence.values.firstWhere(
                (e) => e.name == arguments['confidence'],
                orElse: () => ChecklistCompletionConfidence.low,
              ),
            );
            suggestions.add(suggestion);

            developer.log(
              'Created suggestion for item ${suggestion.checklistItemId} with confidence ${suggestion.confidence.name}',
              name: 'UnifiedAiInferenceRepository',
            );
          } catch (e) {
            developer.log(
              'Error parsing individual checklist completion JSON: $e',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      } else if (toolCall.function.name ==
          ChecklistCompletionFunctions.addMultipleChecklistItems) {
        // Handle add checklist item(s)
        try {
          final arguments =
              jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;

          // Array-of-objects only
          final itemsField = arguments['items'];
          if (itemsField is! List) {
            developer.log(
              'Invalid or missing items for add_multiple_checklist_items',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          final sanitized = ChecklistValidation.validateItems(itemsField);

          if (!ChecklistValidation.isValidBatchSize(sanitized.length)) {
            developer.log(
              ChecklistValidation.getBatchSizeErrorMessage(sanitized.length),
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          developer.log(
            'Processing ${sanitized.length} checklist items (array-of-objects)',
            name: 'UnifiedAiInferenceRepository',
          );

          // Process each item
          for (final item in sanitized) {
            developer.log(
              'Adding checklist item: ${item.title} (isChecked=${item.isChecked})',
              name: 'UnifiedAiInferenceRepository',
            );

            // Check if task has existing checklists
            final checklistIds = currentTask.data.checklistIds ?? [];

            if (checklistIds.isEmpty) {
              // Create a new "to-do" checklist with the item
              developer.log(
                'No existing checklists found, creating new "to-do" checklist',
                name: 'UnifiedAiInferenceRepository',
              );

              final result = await autoChecklistService.autoCreateChecklist(
                taskId: currentTask.id,
                suggestions: [
                  ChecklistItemData(
                    title: item.title,
                    isChecked: item.isChecked,
                    linkedChecklists: [],
                    checkedBy: ChangeSource.agent,
                  ),
                ],
                title: 'Todos',
              );

              if (result.success) {
                developer.log(
                  'Created new checklist ${result.checklistId} with item',
                  name: 'UnifiedAiInferenceRepository',
                );

                // Refresh the task to get the updated checklistIds
                final journalDb = getIt<JournalDb>();
                final updatedEntity = await journalDb.journalEntityById(
                  currentTask.id,
                );
                if (updatedEntity is Task) {
                  currentTask = updatedEntity;
                  developer.log(
                    'Refreshed task, now has ${currentTask.data.checklistIds?.length ?? 0} checklists',
                    name: 'UnifiedAiInferenceRepository',
                  );
                } else {
                  // The task should exist since we just created a checklist for it.
                  // If not, it was likely deleted concurrently. Stop processing to avoid further errors.
                  developer.log(
                    'Failed to refresh task ${currentTask.id} after creating checklist. It might have been deleted concurrently.',
                    name: 'UnifiedAiInferenceRepository',
                    level: 1000, // SEVERE
                  );
                  break;
                }
              } else {
                developer.log(
                  'Failed to create checklist: ${result.error}',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            } else {
              // Add item to the first existing checklist using atomic operation
              final checklistId = checklistIds.first;
              developer.log(
                'Adding item to existing checklist: $checklistId',
                name: 'UnifiedAiInferenceRepository',
              );

              final checklistRepository = ref.read(checklistRepositoryProvider);
              final newItem = await checklistRepository.addItemToChecklist(
                checklistId: checklistId,
                title: item.title,
                isChecked: item.isChecked,
                categoryId: currentTask.meta.categoryId,
                checkedBy: ChangeSource.agent,
              );

              if (newItem != null) {
                developer.log(
                  'Successfully added item ${newItem.id} to checklist',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            }
          }

          // Force refresh of checklists UI
          ref.invalidate(checklistItemControllerProvider);
        } catch (e) {
          developer.log(
            'Error processing add checklist item(s): $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
          );
        }
      } else if (toolCall.function.name ==
          ChecklistCompletionFunctions.updateChecklistItems) {
        try {
          final updateHandler = LottiChecklistUpdateHandler(
            task: currentTask,
            checklistRepository: ref.read(checklistRepositoryProvider),
            onTaskUpdated: (Task updatedTask) {
              currentTask = updatedTask;
            },
          );

          final result = updateHandler.processFunctionCall(toolCall);

          if (!result.success) {
            developer.log(
              'Invalid update_checklist_items call: ${result.error}',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          final count = await updateHandler.executeUpdates(result);

          developer.log(
            'Updated $count checklist items, '
            'skipped ${updateHandler.skippedItems.length}',
            name: 'UnifiedAiInferenceRepository',
          );

          ref.invalidate(checklistItemControllerProvider);
        } catch (e, stackTrace) {
          developer.log(
            'Error processing update_checklist_items: $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
            stackTrace: stackTrace,
          );
        }
      } else if (toolCall.function.name == TaskFunctions.setTaskLanguage) {
        // Handle set task language
        try {
          final result = SetTaskLanguageResult.fromJson(
            jsonDecode(toolCall.function.arguments) as Map<String, dynamic>,
          );
          final languageCode = result.languageCode;
          final confidence = result.confidence.name;
          final reason = result.reason;

          developer.log(
            'Setting task language to: $languageCode (confidence: $confidence, reason: $reason)',
            name: 'UnifiedAiInferenceRepository',
          );

          // Re-fetch the task to get the latest state and avoid race conditions
          final journalRepo = ref.read(journalRepositoryProvider);
          final freshEntity = await journalRepo.getJournalEntityById(
            currentTask.id,
          );

          if (freshEntity is! Task) {
            developer.log(
              'Task ${currentTask.id} not found or is not a Task anymore, skipping language update',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          final freshTask = freshEntity;

          // Only set language if task doesn't already have one
          if (freshTask.data.languageCode == null) {
            final updated = freshTask.copyWith(
              data: freshTask.data.copyWith(
                languageCode: languageCode,
              ),
            );

            try {
              await journalRepo.updateJournalEntity(updated);
              developer.log(
                'Successfully set task language to $languageCode for task ${currentTask.id}',
                name: 'UnifiedAiInferenceRepository',
              );
              languageWasSet = true;
            } catch (e) {
              developer.log(
                'Failed to update task language for task ${currentTask.id}',
                name: 'UnifiedAiInferenceRepository',
                error: e,
              );
            }
          } else {
            developer.log(
              'Task ${currentTask.id} already has language set to ${freshTask.data.languageCode}, not overwriting',
              name: 'UnifiedAiInferenceRepository',
            );
          }
        } catch (e) {
          developer.log(
            'Error processing set task language: $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
          );
        }
      } else if (toolCall.function.name == LabelFunctions.assignTaskLabels) {
        // Handle assign task labels (add-only)
        try {
          final parsed = parseLabelCallArgs(toolCall.function.arguments);
          final requested = LinkedHashSet<String>.from(
            parsed.selectedIds,
          ).toList();

          // Defensive check: warn if AI called without valid labels
          if (requested.isEmpty) {
            developer.log(
              'assign_task_labels called without valid labels or labelIds - '
              'raw args: ${toolCall.function.arguments}',
              name: 'UnifiedAiInferenceRepository',
            );
            continue;
          }

          // Phase 3: filter suppressed IDs for this task (hard filter)
          final suppressedSet =
              currentTask.data.aiSuppressedLabelIds ?? const <String>{};
          final proposed = requested
              .where((id) => !suppressedSet.contains(id))
              .toList();

          final processor = LabelAssignmentProcessor(
            repository: ref.read(labelsRepositoryProvider),
          );

          // Short-circuit if everything was suppressed
          if (proposed.isEmpty && requested.isNotEmpty) {
            final skipped = requested
                .where(suppressedSet.contains)
                .map((id) => {'id': id, 'reason': 'suppressed'})
                .toList();
            final noop = LabelAssignmentResult(
              assigned: const [],
              invalid: const [],
              skipped: skipped,
            );
            try {
              final response = noop.toStructuredJson(requested);
              developer.log(
                'assign_task_labels suppressed-only: $response',
                name: 'UnifiedAiInferenceRepository',
              );
            } catch (_) {
              // best-effort logging
            }
            continue;
          }
          final result = await processor.processAssignment(
            taskId: currentTask.id,
            proposedIds: proposed,
            existingIds: currentTask.meta.labelIds ?? const <String>[],
            categoryId: currentTask.meta.categoryId,
            droppedLow: parsed.droppedLow,
            legacyUsed: parsed.legacyUsed,
            confidenceBreakdown: parsed.confidenceBreakdown,
            totalCandidates: parsed.totalCandidates,
          );
          // Log structured result for debugging
          try {
            developer.log(
              'assign_task_labels result: ${result.toStructuredJson(requested)}',
              name: 'UnifiedAiInferenceRepository',
            );
          } catch (_) {
            // best-effort logging
          }
        } catch (e) {
          developer.log(
            'Error processing assign_task_labels: $e',
            name: 'UnifiedAiInferenceRepository',
            error: e,
          );
        }
      } else {
        developer.log(
          'Skipping unknown tool call: ${toolCall.function.name}',
          name: 'UnifiedAiInferenceRepository',
        );
      }
    }

    if (suggestions.isNotEmpty) {
      developer.log(
        'About to store ${suggestions.length} suggestions:',
        name: 'UnifiedAiInferenceRepository',
      );

      for (final suggestion in suggestions) {
        developer.log(
          '  - Item ${suggestion.checklistItemId}: ${suggestion.reason} (${suggestion.confidence.name})',
          name: 'UnifiedAiInferenceRepository',
        );
      }

      // Store suggestions in the service
      ref
          .read(checklistCompletionServiceProvider.notifier)
          .addSuggestions(suggestions);

      // Auto-check items with high confidence
      final checklistRepository = ref.read(checklistRepositoryProvider);
      final journalRepository = ref.read(journalRepositoryProvider);

      for (final suggestion in suggestions) {
        if (suggestion.confidence == ChecklistCompletionConfidence.high) {
          developer.log(
            'Auto-checking item ${suggestion.checklistItemId} due to high confidence',
            name: 'UnifiedAiInferenceRepository',
          );

          try {
            // Get the current checklist item
            final checklistItem = await journalRepository.getJournalEntityById(
              suggestion.checklistItemId,
            );

            if (checklistItem is ChecklistItem) {
              if (checklistItem.data.isChecked) {
                developer.log(
                  'Skipping auto-check for item ${suggestion.checklistItemId} - already checked',
                  name: 'UnifiedAiInferenceRepository',
                );
              } else if (checklistItem.data.checkedBy == ChangeSource.user) {
                // User sovereignty: do not auto-check items the user
                // explicitly unchecked. The agent tool path requires a
                // reason; auto-check has no reason to provide, so skip.
                developer.log(
                  'Skipping auto-check for item ${suggestion.checklistItemId} '
                  '- user-owned (sovereignty guard)',
                  name: 'UnifiedAiInferenceRepository',
                );
              } else {
                // Safe to auto-check: item is unchecked and agent-owned
                await checklistRepository.updateChecklistItem(
                  checklistItemId: suggestion.checklistItemId,
                  data: checklistItem.data.copyWith(
                    isChecked: true,
                    checkedBy: ChangeSource.agent,
                    checkedAt: clock(),
                  ),
                  taskId: currentTask.id,
                );

                developer.log(
                  'Successfully auto-checked item ${suggestion.checklistItemId}',
                  name: 'UnifiedAiInferenceRepository',
                );
              }
            }
          } catch (e) {
            developer.log(
              'Error auto-checking item ${suggestion.checklistItemId}: $e',
              name: 'UnifiedAiInferenceRepository',
              error: e,
            );
          }
        }
      }

      // Force refresh of all checklist items in this task
      // This will cause the UI to re-check for suggestions
      ref.invalidate(checklistItemControllerProvider);

      developer.log(
        'Processed ${suggestions.length} checklist completion suggestions for task ${currentTask.id}',
        name: 'UnifiedAiInferenceRepository',
      );
    } else {
      developer.log(
        'No suggestions to process after parsing tool calls',
        name: 'UnifiedAiInferenceRepository',
      );
    }

    return languageWasSet;
  }
}

/// Extracts top-level JSON object substrings from [input] by brace-depth
/// scanning.
///
/// AI providers sometimes concatenate several JSON objects into one tool-call
/// argument string; this splits them back apart. Text outside braces is
/// ignored. Braces inside JSON string literals (including escaped quotes)
/// are ignored so a reason like `"The user selected {Item}"` does not skew
/// the depth count.
List<String> extractJsonObjects(String input) {
  final jsonObjects = <String>[];
  var depth = 0;
  var start = -1;
  var inString = false;
  var escaped = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];

    if (escaped) {
      escaped = false;
      continue;
    }
    if (inString) {
      if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    // Only treat quotes as string delimiters inside an object — stray
    // quotes in the surrounding prose must not flip the string state.
    if (char == '"' && depth > 0) {
      inString = true;
    } else if (char == '{') {
      if (depth == 0) {
        start = i;
      }
      depth++;
    } else if (char == '}') {
      if (depth > 0) {
        depth--;
        if (depth == 0 && start != -1) {
          jsonObjects.add(input.substring(start, i + 1));
          start = -1;
        }
      }
    }
  }

  return jsonObjects;
}
