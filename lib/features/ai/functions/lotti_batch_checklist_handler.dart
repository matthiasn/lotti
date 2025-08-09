import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
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
      final itemsString = args['items'] as String?;

      if (itemsString != null && itemsString.trim().isNotEmpty) {
        // Parse comma-separated items
        final items = itemsString
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();

        if (items.isNotEmpty) {
          return FunctionCallResult(
            success: true,
            functionName: functionName,
            arguments: call.function.arguments,
            data: {
              'items': items,
              'toolCallId': call.id,
              'taskId': task.id,
            },
          );
        } else {
          return FunctionCallResult(
            success: false,
            functionName: functionName,
            arguments: call.function.arguments,
            data: {
              'toolCallId': call.id,
              'taskId': task.id,
            },
            error: 'No valid items found in the comma-separated list',
          );
        }
      } else {
        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'toolCallId': call.id,
            'taskId': task.id,
          },
          error: 'Missing required field "items" or empty list',
        );
      }
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
      final items = result.data['items'] as List<String>?;
      return items?.join(', ');
    }
    return null;
  }

  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      final items = result.data['items'] as List<String>;
      return 'Ready to create ${items.length} checklist items: ${items.join(', ')}';
    } else {
      return 'Error processing checklist items: ${result.error}';
    }
  }

  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    return '''
I noticed an error in your function call. Please use the correct format:
{"items": "item1, item2, item3"}

You already successfully created these checklist items: ${successfulDescriptions.join(', ')}

Do NOT recreate the items that were already successful.''';
  }

  /// Create all items from the batch
  Future<int> createBatchItems(FunctionCallResult result,
      {Set<String>? existingDescriptions}) async {
    if (!result.success) return 0;

    final items = result.data['items'] as List<String>;
    var successCount = 0;

    // Merge with any existing descriptions to prevent duplicates
    if (existingDescriptions != null) {
      _createdDescriptions
          .addAll(existingDescriptions.map((d) => d.toLowerCase().trim()));
    }

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
        // Create a new "TODOs" checklist with all items
        final seenInBatch = <String>{};
        final checklistItems = <ChecklistItemData>[];

        for (final desc in items) {
          final normalized = desc.toLowerCase().trim();
          if (!_createdDescriptions.contains(normalized) &&
              !seenInBatch.contains(normalized)) {
            seenInBatch.add(normalized);
            checklistItems.add(ChecklistItemData(
              title: desc,
              isChecked: false,
              linkedChecklists: [],
            ));
          }
        }

        if (checklistItems.isNotEmpty) {
          final createResult = await autoChecklistService.autoCreateChecklist(
            taskId: currentTask.id,
            suggestions: checklistItems,
            title: 'TODOs',
          );

          if (createResult.success) {
            successCount = checklistItems.length;
            for (final item in checklistItems) {
              _successfulItems.add(item.title);
              _createdDescriptions.add(item.title.toLowerCase().trim());
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
        final seenInBatch = <String>{};

        for (final desc in items) {
          final normalized = desc.toLowerCase().trim();
          if (!_createdDescriptions.contains(normalized) &&
              !seenInBatch.contains(normalized)) {
            seenInBatch.add(normalized);

            final newItem = await checklistRepository.addItemToChecklist(
              checklistId: checklistId,
              title: desc,
              isChecked: false,
              categoryId: currentTask.meta.categoryId,
            );

            if (newItem != null) {
              successCount++;
              _successfulItems.add(desc);
              _createdDescriptions.add(normalized);
            }
          }
        }

        // Only refresh the task if items were actually added
        if (successCount > 0) {
          final refreshedEntity =
              await journalDb.journalEntityById(currentTask.id);
          if (refreshedEntity is Task) {
            task = refreshedEntity;
            onTaskUpdated?.call(refreshedEntity);
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

  void reset() {
    _createdDescriptions.clear();
    _successfulItems.clear();
  }
}
