import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_log.dart';
import 'package:openai_dart/openai_dart.dart';

/// Handler for checklist item creation in Lotti
class LottiChecklistItemHandler extends FunctionHandler {
  LottiChecklistItemHandler({
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
  String get functionName => 'add_checklist_item';

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
      final description = args['actionItemDescription'] as String?;

      if (description != null && description.trim().isNotEmpty) {
        final trimmed = description.trim();

        // Heuristic 1: square-bracketed list with commas
        if (trimmed.startsWith('[') &&
            trimmed.endsWith(']') &&
            trimmed.contains(',')) {
          lottiDevLog(
            name: 'LottiChecklistItemHandler',
            message:
                'Rejected multi-item bracketed list in single-item handler: '
                '${trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed}',
            level: 900,
          );
          return FunctionCallResult(
            success: false,
            functionName: functionName,
            arguments: call.function.arguments,
            data: {
              'attemptedItem': description,
              'toolCallId': call.id,
              'taskId': task.id,
            },
            error:
                'Multiple items detected in a single-item call. Provide items separately or use the appropriate multi-item tool if available.',
          );
        }

        // Heuristic 2: two or more top-level commas (outside quotes/grouping)
        var commaCount = 0;
        var escape = false;
        var inQuotes = false;
        String? quoteChar;
        var paren = 0;
        var bracket = 0;
        var brace = 0;
        for (var i = 0; i < trimmed.length; i++) {
          final ch = trimmed[i];
          if (escape) {
            escape = false;
            continue;
          }
          if (ch == r'\\') {
            escape = true;
            continue;
          }
          if (inQuotes) {
            if (ch == quoteChar) {
              inQuotes = false;
              quoteChar = null;
            }
            continue;
          }
          final cu = ch.codeUnitAt(0);
          if (cu == 34 || cu == 39) {
            inQuotes = true;
            quoteChar = ch;
            continue;
          }
          if (ch == '(') {
            paren++;
            continue;
          }
          if (ch == ')') {
            if (paren > 0) paren--;
            continue;
          }
          if (ch == '[') {
            bracket++;
            continue;
          }
          if (ch == ']') {
            if (bracket > 0) bracket--;
            continue;
          }
          if (ch == '{') {
            brace++;
            continue;
          }
          if (ch == '}') {
            if (brace > 0) brace--;
            continue;
          }
          if (ch == ',' && paren == 0 && bracket == 0 && brace == 0) {
            commaCount++;
            if (commaCount >= 2) {
              lottiDevLog(
                name: 'LottiChecklistItemHandler',
                message:
                    'Rejected comma-separated multi-item pattern in single-item handler: '
                    '${trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed}',
                level: 900,
              );
              return FunctionCallResult(
                success: false,
                functionName: functionName,
                arguments: call.function.arguments,
                data: {
                  'attemptedItem': description,
                  'toolCallId': call.id,
                  'taskId': task.id,
                },
                error:
                    'Multiple items detected in a single-item call. Provide items separately or use the appropriate multi-item tool if available.',
              );
            }
          }
        }

        return FunctionCallResult(
          success: true,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'description': description,
            'toolCallId': call.id,
            'taskId': task.id,
          },
        );
      } else {
        // Try to extract attempted item
        String? attemptedItem;
        String? wrongFieldName;

        for (final entry in args.entries) {
          if (entry.value is String && entry.value.toString().isNotEmpty) {
            attemptedItem = entry.value.toString();
            wrongFieldName = entry.key;
            break;
          }
        }

        final errorMsg = attemptedItem?.trim().isEmpty ?? false
            ? 'Empty description provided. Please provide a meaningful description.'
            : wrongFieldName != null
                ? 'Found "$wrongFieldName" instead of "actionItemDescription"'
                : 'Missing required field "actionItemDescription"';

        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'attemptedItem': attemptedItem ?? '',
            'wrongFieldName': wrongFieldName,
            'toolCallId': call.id,
            'taskId': task.id,
          },
          error: errorMsg,
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
    if (!result.success) return false;

    final description = result.data['description'] as String?;
    if (description == null) return false;

    final normalized = description.toLowerCase().trim();
    if (_createdDescriptions.contains(normalized)) {
      return true;
    }

    _createdDescriptions.add(normalized);
    return false;
  }

  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      return result.data['description'] as String?;
    } else {
      return result.data['attemptedItem'] as String?;
    }
  }

  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      final description = result.data['description'] as String;
      return 'Created checklist item: $description';
    } else {
      return 'Error creating checklist item: ${result.error}';
    }
  }

  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    final errorSummary = failedItems.map((item) {
      final attempted = getDescription(item);
      final attemptedStr = attempted != null ? ' for "$attempted"' : '';
      return '- ${item.error}$attemptedStr';
    }).join('\n');

    final itemsToRetry = failedItems
        .map(getDescription)
        .where((desc) => desc != null && desc.isNotEmpty)
        .toList();

    return '''
I noticed ${failedItems.length == 1 ? 'an error' : 'errors'} in your function call${failedItems.length > 1 ? 's' : ''}:
$errorSummary

You already successfully created these checklist items: ${successfulDescriptions.join(', ')}

Please create ONLY the failed item${itemsToRetry.length > 1 ? 's' : ''}: ${itemsToRetry.join(', ')}

Use the correct format:
{"actionItemDescription": "item description"}

Do NOT recreate the items that were already successful.''';
  }

  /// Actually create the checklist item in Lotti's database
  Future<bool> createItem(FunctionCallResult result) async {
    if (!result.success) return false;

    final description = result.data['description'] as String;

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
        // Create a new "TODOs" checklist with the item
        final createResult = await autoChecklistService.autoCreateChecklist(
          taskId: currentTask.id,
          suggestions: [
            ChecklistItemData(
              title: description,
              isChecked: false,
              linkedChecklists: [],
            ),
          ],
          title: 'TODOs',
        );

        if (createResult.success) {
          // Add to successful items after DB write succeeds
          _successfulItems.add(description);
          _createdDescriptions.add(description.toLowerCase().trim());

          // Refresh the task
          final refreshedEntity =
              await journalDb.journalEntityById(currentTask.id);
          if (refreshedEntity is Task) {
            task = refreshedEntity;
            onTaskUpdated?.call(refreshedEntity);
          }
          return true;
        } else {
          return false;
        }
      } else {
        // Add item to the first existing checklist
        final checklistId = checklistIds.first;
        final newItem = await checklistRepository.addItemToChecklist(
          checklistId: checklistId,
          title: description,
          isChecked: false,
          categoryId: currentTask.meta.categoryId,
        );

        if (newItem != null) {
          // Add to successful items after DB write succeeds
          _successfulItems.add(description);
          _createdDescriptions.add(description.toLowerCase().trim());

          // Refresh the task
          final refreshedEntity =
              await journalDb.journalEntityById(currentTask.id);
          if (refreshedEntity is Task) {
            task = refreshedEntity;
            onTaskUpdated?.call(refreshedEntity);
          }
          return true;
        }
        return false;
      }
    } catch (e, s) {
      developer.log(
        'Error creating checklist item for task ${task.id}',
        name: 'LottiChecklistItemHandler',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  List<String> get successfulItems => List.unmodifiable(_successfulItems);

  void addSuccessfulItems(List<String> items) {
    for (final item in items) {
      if (!_successfulItems.contains(item)) {
        _successfulItems.add(item);
        _createdDescriptions.add(item.toLowerCase().trim());
      }
    }
  }

  void reset() {
    _createdDescriptions.clear();
    _successfulItems.clear();
  }
}
