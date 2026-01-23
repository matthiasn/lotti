import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/utils/checklist_validation.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

/// Handler for batch checklist item creation in Lotti
class LottiBatchChecklistHandler extends FunctionHandler {
  LottiBatchChecklistHandler({
    required this.task,
    required this.autoChecklistService,
    required this.checklistRepository,
    this.onTaskUpdated,
  });

  Task task;
  final AutoChecklistService autoChecklistService;
  final ChecklistRepository checklistRepository;
  final void Function(Task)? onTaskUpdated;

  final Set<String> _createdDescriptions = {};
  final List<String> _successfulItems = [];
  final List<Map<String, dynamic>> _createdDetails = [];

  @override
  String get functionName => 'add_multiple_checklist_items';

  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    // Early check: verify function name matches
    if (call.function.name != functionName) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {'toolCallId': call.id},
        error:
            'Function name mismatch: expected "$functionName", got "${call.function.name}"',
      );
    }

    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final raw = args['items'];

      if (raw is! List) {
        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'toolCallId': call.id,
            'taskId': task.id,
          },
          error:
              'Invalid or missing "items". Provide a JSON array of objects: {"items": [{"title": "...", "isChecked": false}] }',
        );
      }

      // Check for string entries to provide helpful error
      for (final entry in raw) {
        final error = ChecklistValidation.validateItemEntry(entry);
        if (entry is String) {
          // Special case: reject arrays of strings with helpful message
          return FunctionCallResult(
            success: false,
            functionName: functionName,
            arguments: call.function.arguments,
            data: {
              'toolCallId': call.id,
              'taskId': task.id,
            },
            error: error ??
                'Each item must be an object with a title. Example: {"items": [{"title": "Buy milk"}] }',
          );
        }
      }

      // Sanitize and validate array-of-objects
      final validatedItems = ChecklistValidation.validateItems(raw);

      // Convert validated items to the expected format
      final sanitized = validatedItems
          .map((item) => {
                'title': item.title,
                'isChecked': item.isChecked,
              })
          .toList();

      if (!ChecklistValidation.isValidBatchSize(sanitized.length)) {
        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'toolCallId': call.id,
            'taskId': task.id,
          },
          error: ChecklistValidation.getBatchSizeErrorMessage(sanitized.length),
        );
      }

      return FunctionCallResult(
        success: true,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {
          'items': sanitized,
          'toolCallId': call.id,
          'taskId': task.id,
        },
      );
    } catch (e) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {
          'toolCallId': call.id,
          'taskId': task.id,
        },
        error: 'Invalid JSON: $e',
      );
    }
  }

  @override
  bool isDuplicate(FunctionCallResult result) {
    // For batch operations, we'll check duplicates at the individual item level
    return false;
  }

  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      final items = result.data['items'] as List<dynamic>?;
      if (items == null) return null;
      final titles = items
          .map((e) => e is Map<String, dynamic> ? e['title']?.toString() : null)
          .whereType<String>()
          .toList();
      return titles.join(', ');
    }
    return null;
  }

  // Tool response is provided after creation at the end of processing

  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    return '''
I noticed an error in your function call.

Required format for multiple items (array of objects):
{"items": [{"title": "item1"}, {"title": "item2"}, {"title": "item3", "isChecked": true}]}
 - Always use objects with a title (max 400 chars); optional isChecked true if explicitly done.
 - Do NOT send a comma-separated string or an array of strings.

You already successfully created these checklist items: ${successfulDescriptions.join(', ')}

Do NOT recreate the items that were already successful.''';
  }

  /// Creates all items from the batch.
  ///
  /// Uses the improved repository API that returns created items with their IDs,
  /// eliminating the need for fragile index-based mapping.
  ///
  /// Returns the number of successfully created items.
  Future<int> createBatchItems(FunctionCallResult result) async {
    if (!result.success) return 0;

    final items = (result.data['items'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    var successCount = 0;
    _createdDetails.clear();

    try {
      // Get current task state
      var currentTask = task;
      final journalDb = getIt<JournalDb>();
      final updatedEntity = await journalDb.journalEntityById(task.id);
      if (updatedEntity is Task) {
        currentTask = updatedEntity;
      }

      // Check if task has existing checklists
      final checklistIds = currentTask.data.checklistIds ?? [];

      if (checklistIds.isEmpty) {
        // Create a new "TODOs" checklist with all items (preserve order)
        final checklistItems = <ChecklistItemData>[
          for (final item in items)
            ChecklistItemData(
              title: item['title'] as String,
              isChecked: (item['isChecked'] as bool?) ?? false,
              linkedChecklists: [],
            )
        ];

        if (checklistItems.isNotEmpty) {
          final createResult = await autoChecklistService.autoCreateChecklist(
            taskId: currentTask.id,
            suggestions: checklistItems,
            title: 'TODOs',
          );

          if (createResult.success && createResult.createdItems != null) {
            successCount = createResult.createdItems!.length;
            // Use the returned items directly - no need for fragile mapping
            for (final item in createResult.createdItems!) {
              _successfulItems.add(item.title);
              _createdDescriptions.add(item.title.toLowerCase().trim());
              _createdDetails.add({
                'id': item.id,
                'title': item.title,
                'isChecked': item.isChecked,
              });
            }

            // Refresh the task after creating checklist
            final refreshedEntity =
                await journalDb.journalEntityById(currentTask.id);
            if (refreshedEntity is Task) {
              task = refreshedEntity;
              onTaskUpdated?.call(refreshedEntity);
            }
          }
        }
      } else {
        // Add items to the first existing checklist
        final checklistId = checklistIds.first;

        for (final item in items) {
          final title = item['title'] as String;
          final isChecked = (item['isChecked'] as bool?) ?? false;

          final newItem = await checklistRepository.addItemToChecklist(
            checklistId: checklistId,
            title: title,
            isChecked: isChecked,
            categoryId: currentTask.meta.categoryId,
          );

          if (newItem != null) {
            successCount++;
            _successfulItems.add(title);
            _createdDescriptions.add(title.toLowerCase().trim());
            _createdDetails.add({
              'id': newItem.id,
              'title': title,
              'isChecked': isChecked,
            });
          }
        }

        // Only refresh the task if items were actually added
        if (successCount > 0) {
          final refreshedEntity =
              await journalDb.journalEntityById(currentTask.id);
          if (refreshedEntity is Task) {
            task = refreshedEntity;
            onTaskUpdated?.call(refreshedEntity);
          } else if (refreshedEntity == null) {
            // Task was deleted, stop processing
            developer.log(
              'Task ${currentTask.id} was deleted, stopping batch checklist processing',
              name: 'LottiBatchChecklistHandler',
            );
            return successCount;
          }
        }
      }
    } catch (e, s) {
      developer.log(
        'Error creating batch checklist items for task ${task.id}',
        name: 'LottiBatchChecklistHandler',
        error: e,
        stackTrace: s,
      );
      // Return partial success count
    }

    return successCount;
  }

  List<String> get successfulItems => List.unmodifiable(_successfulItems);

  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      return jsonEncode({'createdItems': _createdDetails});
    }
    return 'Error creating checklist items: ${result.error}';
  }
}
