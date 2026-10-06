import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/ai/utils/checklist_validation.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/task_field_write.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

/// Dispatches streamed assistant tool calls for the unified AI inference path:
/// checklist completion suggestions, checklist add/update, task language
/// detection, and `assign_task_labels`.
///
/// Extracted from `UnifiedAiInferenceRepository` as a standalone collaborator
/// (it needs only [ref], a clock, the repository-owned
/// `AutoChecklistService` and the repository's logger), keeping the
/// repository focused on the inference run.
///
/// Its log lines carry tool names, ids, counts and lengths only — never
/// argument values, checklist item titles or task titles.
class AiToolCallProcessor {
  AiToolCallProcessor({
    required this.ref,
    required this.clock,
    required this.autoChecklistServiceResolver,
    required this._domainLogger,
  });

  final Ref ref;
  final DateTime Function() clock;
  final DomainLogger _domainLogger;

  /// Kept from the repository this was extracted from, so existing log
  /// filters still match.
  static const _logTag = 'UnifiedAiInferenceRepository';

  void _log(String message, {InsightLevel level = InsightLevel.info}) =>
      _domainLogger.log(
        LogDomain.ai,
        message,
        subDomain: _logTag,
        level: level,
      );

  void _error(Object error, String message, [StackTrace? stackTrace]) =>
      _domainLogger.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: _logTag,
        message: message,
      );

  /// Resolves the repository-owned (test-injectable) auto-checklist service.
  final AutoChecklistService Function() autoChecklistServiceResolver;

  AutoChecklistService get autoChecklistService =>
      autoChecklistServiceResolver();

  Future<bool> process({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Task task,
  }) async {
    var languageWasSet = false;
    var currentTask = task; // Create mutable copy for updates
    // Names and sizes only: the arguments carry journal content, which
    // diagnostics must never contain.
    _log(
      'Starting to process ${toolCalls.length} tool calls for checklist '
      'operations: ${toolCalls.map((tc) => '${tc.function.name} '
          '(${tc.function.arguments.length} chars)').join(', ')}',
    );

    final suggestions = <ChecklistCompletionSuggestion>[];

    for (final toolCall in toolCalls) {
      _log('Processing tool call: ${toolCall.function.name}');

      if (toolCall.function.name ==
          ChecklistCompletionFunctions.suggestChecklistCompletion) {
        // Handle case where multiple JSON objects might be concatenated
        final jsonObjects = extractJsonObjects(toolCall.function.arguments);

        if (jsonObjects.isEmpty) {
          // Log metadata only — raw arguments can carry user content/PII
          // and can be arbitrarily large.
          _log(
            'No valid JSON found in arguments '
            '(toolCallId=${toolCall.id}, '
            'length=${toolCall.function.arguments.length})',
            level: InsightLevel.warn,
          );
          continue;
        }

        _log('Found ${jsonObjects.length} JSON objects in arguments');

        for (final jsonStr in jsonObjects) {
          try {
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

            _log(
              'Created suggestion for item ${suggestion.checklistItemId} '
              'with confidence ${suggestion.confidence.name} '
              '(${jsonStr.length} chars)',
            );
          } catch (e, stackTrace) {
            _error(
              e,
              'Error parsing individual checklist completion JSON',
              stackTrace,
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
            _log(
              'Invalid or missing items for add_multiple_checklist_items',
              level: InsightLevel.warn,
            );
            continue;
          }

          final sanitized = ChecklistValidation.validateItems(itemsField);

          if (!ChecklistValidation.isValidBatchSize(sanitized.length)) {
            _log(
              ChecklistValidation.getBatchSizeErrorMessage(sanitized.length),
              level: InsightLevel.warn,
            );
            continue;
          }

          _log(
            'Processing ${sanitized.length} checklist items (array-of-objects)',
          );

          // Process each item
          for (final item in sanitized) {
            _log('Adding checklist item (isChecked=${item.isChecked})');

            // Check if task has existing checklists
            final checklistIds = currentTask.data.checklistIds ?? [];

            if (checklistIds.isEmpty) {
              // Create a new "to-do" checklist with the item
              _log(
                'No existing checklists found, creating new "to-do" checklist',
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
                _log('Created new checklist ${result.checklistId} with item');

                // Refresh the task to get the updated checklistIds
                final journalDb = ref.read(journalDbProvider);
                final updatedEntity = await journalDb.journalEntityById(
                  currentTask.id,
                );
                if (updatedEntity is Task) {
                  currentTask = updatedEntity;
                  _log(
                    'Refreshed task, now has '
                    '${currentTask.data.checklistIds?.length ?? 0} checklists',
                  );
                } else {
                  // The task should exist since we just created a checklist for it.
                  // If not, it was likely deleted concurrently. Stop processing to avoid further errors.
                  _domainLogger.error(
                    LogDomain.ai,
                    'Failed to refresh task ${currentTask.id} after creating '
                    'checklist. It might have been deleted concurrently.',
                    subDomain: _logTag,
                  );
                  break;
                }
              } else {
                _error(
                  result.error ?? 'unknown error',
                  'Failed to create checklist',
                );
              }
            } else {
              // Add item to the first existing checklist using atomic operation
              final checklistId = checklistIds.first;
              _log('Adding item to existing checklist: $checklistId');

              final checklistRepository = ref.read(checklistRepositoryProvider);
              final newItem = await checklistRepository.addItemToChecklist(
                checklistId: checklistId,
                title: item.title,
                isChecked: item.isChecked,
                categoryId: currentTask.meta.categoryId,
                checkedBy: ChangeSource.agent,
              );

              if (newItem != null) {
                _log('Successfully added item ${newItem.id} to checklist');
              }
            }
          }
        } catch (e, stackTrace) {
          _error(e, 'Error processing add checklist item(s)', stackTrace);
        }
      } else if (toolCall.function.name ==
          ChecklistCompletionFunctions.updateChecklistItems) {
        try {
          final updateHandler = LottiChecklistUpdateHandler(
            task: currentTask,
            checklistRepository: ref.read(checklistRepositoryProvider),
            domainLogger: _domainLogger,
            onTaskUpdated: (Task updatedTask) {
              currentTask = updatedTask;
            },
          );

          final result = updateHandler.processFunctionCall(toolCall);

          if (!result.success) {
            _error(
              result.error ?? 'unknown error',
              'Invalid update_checklist_items call',
            );
            continue;
          }

          final count = await updateHandler.executeUpdates(result);

          _log(
            'Updated $count checklist items, '
            'skipped ${updateHandler.skippedItems.length}',
          );
        } catch (e, stackTrace) {
          _error(e, 'Error processing update_checklist_items', stackTrace);
        }
      } else if (toolCall.function.name == TaskFunctions.setTaskLanguage) {
        // Handle set task language
        try {
          final result = SetTaskLanguageResult.fromJson(
            jsonDecode(toolCall.function.arguments) as Map<String, dynamic>,
          );
          final languageCode = result.languageCode;

          // The language code is an argument value: never logged.
          _log(
            'Setting task language (confidence: ${result.confidence.name})',
          );

          // Re-fetch the task to get the latest state and avoid race conditions
          final journalRepo = ref.read(journalRepositoryProvider);
          final freshEntity = await journalRepo.getJournalEntityById(
            currentTask.id,
          );

          if (freshEntity is! Task) {
            _log(
              'Task ${currentTask.id} not found or is not a Task anymore, '
              'skipping language update',
              level: InsightLevel.warn,
            );
            continue;
          }

          final freshTask = freshEntity;

          // Only set language if task doesn't already have one — checked
          // again on the stored task inside the write, so a language set
          // meanwhile is never overwritten (writeTaskField).
          final write = freshTask.data.languageCode == null
              ? await writeTaskField(
                  journalRepository: journalRepo,
                  task: freshTask,
                  field: (data) => data.languageCode,
                  set: (stored) => stored.copyWith(languageCode: languageCode),
                )
              : TaskFieldMoved(freshTask);
          switch (write) {
            case TaskFieldWritten():
              _log('Successfully set task language for task ${currentTask.id}');
              languageWasSet = true;
            case TaskFieldMoved():
              _log(
                'Task ${currentTask.id} already has a language set, '
                'not overwriting',
              );
            case TaskFieldWriteFailed():
              _log(
                'Failed to update task language for task ${currentTask.id}',
                level: InsightLevel.warn,
              );
          }
        } catch (e, stackTrace) {
          _error(e, 'Error processing set task language', stackTrace);
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
            _log(
              'assign_task_labels called without valid labels or labelIds '
              '(${toolCall.function.arguments.length} chars of arguments)',
              level: InsightLevel.warn,
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
            _log(
              'assign_task_labels suppressed-only: all ${requested.length} '
              'requested labels are suppressed for task ${currentTask.id}',
            );
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
          // Counts only: requested ids come from the model's arguments.
          _log(
            'assign_task_labels result: requested=${requested.length}, '
            'assigned=${result.assigned.length}, '
            'invalid=${result.invalid.length}, '
            'skipped=${result.skipped.length}',
          );
        } catch (e, stackTrace) {
          _error(e, 'Error processing assign_task_labels', stackTrace);
        }
      } else {
        _log(
          'Skipping unknown tool call: ${toolCall.function.name}',
          level: InsightLevel.warn,
        );
      }
    }

    if (suggestions.isNotEmpty) {
      _log(
        'About to store ${suggestions.length} suggestions: '
        '${suggestions.map((s) => '${s.checklistItemId} '
            '(${s.confidence.name})').join(', ')}',
      );

      // Store suggestions in the service
      ref
          .read(checklistCompletionServiceProvider.notifier)
          .addSuggestions(suggestions);

      // Auto-check items with high confidence
      final checklistRepository = ref.read(checklistRepositoryProvider);
      final journalRepository = ref.read(journalRepositoryProvider);

      for (final suggestion in suggestions) {
        if (suggestion.confidence == ChecklistCompletionConfidence.high) {
          _log(
            'Auto-checking item ${suggestion.checklistItemId} '
            'due to high confidence',
          );

          try {
            // Get the current checklist item
            final checklistItem = await journalRepository.getJournalEntityById(
              suggestion.checklistItemId,
            );

            if (checklistItem is ChecklistItem) {
              if (checklistItem.data.isChecked) {
                _log(
                  'Skipping auto-check for item '
                  '${suggestion.checklistItemId} - already checked',
                );
              } else if (checklistItem.data.checkedBy == ChangeSource.user) {
                // User sovereignty: do not auto-check items the user
                // explicitly unchecked. The agent tool path requires a
                // reason; auto-check has no reason to provide, so skip.
                _log(
                  'Skipping auto-check for item ${suggestion.checklistItemId} '
                  '- user-owned (sovereignty guard)',
                );
              } else {
                // Safe to auto-check: item is unchecked and agent-owned. The
                // guards run again on the item as stored, so a check or an
                // uncheck the user made since the read above stands.
                await checklistRepository.updateChecklistItem(
                  checklistItemId: suggestion.checklistItemId,
                  change: (stored) =>
                      stored.isChecked || stored.checkedBy == ChangeSource.user
                      ? stored
                      : stored.copyWith(
                          isChecked: true,
                          checkedBy: ChangeSource.agent,
                          checkedAt: clock(),
                        ),
                  taskId: currentTask.id,
                );

                _log(
                  'Successfully auto-checked item ${suggestion.checklistItemId}',
                );
              }
            }
          } catch (e, stackTrace) {
            _error(
              e,
              'Error auto-checking item ${suggestion.checklistItemId}',
              stackTrace,
            );
          }
        }
      }

      _log(
        'Processed ${suggestions.length} checklist completion suggestions '
        'for task ${currentTask.id}',
      );
    } else {
      _log('No suggestions to process after parsing tool calls');
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
