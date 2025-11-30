import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/string_utils.dart' as string_utils;
import 'package:openai_dart/openai_dart.dart';

/// Handler for updating existing checklist items in Lotti.
///
/// Supports:
/// - Marking items as checked/unchecked
/// - Updating item titles (e.g., fixing transcription errors)
/// - Combined updates (both status and title in one call)
class LottiChecklistUpdateHandler extends FunctionHandler {
  LottiChecklistUpdateHandler({
    required this.task,
    required this.checklistRepository,
    this.onTaskUpdated,
  });

  /// The task whose checklist items are being updated.
  ///
  /// This field is intentionally mutable (not `final`) because it is refreshed
  /// after successful updates to reflect the latest database state. This ensures
  /// subsequent operations see any changes made by the update (e.g., modified
  /// checklistIds). The [onTaskUpdated] callback is invoked when refreshed.
  Task task;
  final ChecklistRepository checklistRepository;
  final void Function(Task)? onTaskUpdated;

  final List<UpdatedItemDetail> _updatedItems = [];
  final List<SkippedItemDetail> _skippedItems = [];

  /// Helper to record a skipped item with a reason.
  void _skip(String id, String reason) {
    _skippedItems.add(SkippedItemDetail(id: id, reason: reason));
  }

  static const int maxBatchSize = 20;
  static const int maxTitleLength = 400;

  @override
  String get functionName => 'update_checklist_items';

  /// Creates a standardized error result for validation failures.
  FunctionCallResult _createErrorResult(
    ChatCompletionMessageToolCall call,
    String error, {
    bool includeTaskId = true,
  }) {
    return FunctionCallResult(
      success: false,
      functionName: functionName,
      arguments: call.function.arguments,
      data: {
        'toolCallId': call.id,
        if (includeTaskId) 'taskId': task.id,
      },
      error: error,
    );
  }

  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    // Early check: verify function name matches
    if (call.function.name != functionName) {
      return _createErrorResult(
        call,
        'Function name mismatch: expected "$functionName", got "${call.function.name}"',
        includeTaskId: false,
      );
    }

    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final raw = args['items'];

      if (raw is! List) {
        return _createErrorResult(
          call,
          'Invalid or missing "items". Provide a JSON array of update objects: '
          '{"items": [{"id": "...", "isChecked": true}]}',
        );
      }

      if (raw.isEmpty) {
        return _createErrorResult(
          call,
          'Empty items array. Provide at least one update.',
        );
      }

      if (raw.length > maxBatchSize) {
        return _createErrorResult(
          call,
          'Too many items. Maximum batch size is $maxBatchSize.',
        );
      }

      final validatedItems = <Map<String, dynamic>>[];

      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];

        if (item is! Map<String, dynamic>) {
          return _createErrorResult(
            call,
            'Item at index $i is not an object. Each item must be an object '
            'with id and at least one of isChecked or title.',
          );
        }

        final id = item['id'];
        if (id is! String || id.trim().isEmpty) {
          return _createErrorResult(
            call,
            'Item at index $i is missing required "id" field.',
          );
        }

        final isChecked = item['isChecked'];
        final title = item['title'];

        // Must have at least one update field
        if (isChecked == null && title == null) {
          return _createErrorResult(
            call,
            'Item at index $i (id: $id) has no update fields. '
            'Provide at least one of isChecked or title.',
          );
        }

        // Validate isChecked type if present
        if (isChecked != null && isChecked is! bool) {
          return _createErrorResult(
            call,
            'Item at index $i has invalid isChecked value. Must be a boolean.',
          );
        }

        // Validate and normalize title if present
        String? normalizedTitle;
        if (title != null) {
          if (title is! String) {
            return _createErrorResult(
              call,
              'Item at index $i has invalid title value. Must be a string.',
            );
          }

          normalizedTitle = normalizeWhitespace(title);

          if (normalizedTitle.isEmpty) {
            return _createErrorResult(
              call,
              'Item at index $i has empty title after normalization. '
              'Title must not be blank.',
            );
          }

          if (normalizedTitle.length > maxTitleLength) {
            return _createErrorResult(
              call,
              'Item at index $i has title exceeding $maxTitleLength characters.',
            );
          }
        }

        validatedItems.add({
          'id': id.trim(),
          if (isChecked != null) 'isChecked': isChecked,
          if (normalizedTitle != null) 'title': normalizedTitle,
        });
      }

      return FunctionCallResult(
        success: true,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {
          'items': validatedItems,
          'toolCallId': call.id,
          'taskId': task.id,
        },
      );
    } catch (e) {
      return _createErrorResult(call, 'Invalid JSON: $e');
    }
  }

  /// Normalize whitespace: trim edges and collapse internal spaces.
  /// Delegates to the shared utility for consistent behavior across features.
  static String normalizeWhitespace(String input) =>
      string_utils.normalizeWhitespace(input);

  /// Execute the validated updates.
  ///
  /// Returns the number of successfully updated items.
  Future<int> executeUpdates(FunctionCallResult result) async {
    if (!result.success) return 0;

    final items = (result.data['items'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    _updatedItems.clear();
    _skippedItems.clear();

    final allowedChecklistIds = task.data.checklistIds ?? const <String>[];

    if (allowedChecklistIds.isEmpty) {
      for (final item in items) {
        _skip(item['id'] as String, 'Task has no checklists');
      }
      return 0;
    }

    final journalDb = getIt<JournalDb>();

    // Fetch all items in one query for efficiency
    final itemIds = items.map((e) => e['id'] as String).toList();
    final entityMap = <String, JournalEntity>{};
    for (final dbEntity in await journalDb.entriesForIds(itemIds).get()) {
      entityMap[dbEntity.id] = fromDbEntity(dbEntity);
    }

    var successCount = 0;

    for (final item in items) {
      final id = item['id'] as String;
      final newIsChecked = item['isChecked'] as bool?;
      final newTitle = item['title'] as String?;

      final entity = entityMap[id];

      // Check entity exists and is a ChecklistItem
      if (entity is! ChecklistItem) {
        _skip(id, entity == null ? 'Item not found' : 'Not a checklist item');
        continue;
      }

      // Check item belongs to task's checklists
      final belongsToTask =
          entity.data.linkedChecklists.any(allowedChecklistIds.contains);
      if (!belongsToTask) {
        _skip(id, 'Item does not belong to this task');
        continue;
      }

      // Check if there are actual changes
      final currentIsChecked = entity.data.isChecked;
      final currentTitle = entity.data.title;

      final isCheckedChanged =
          newIsChecked != null && newIsChecked != currentIsChecked;
      final titleChanged = newTitle != null && newTitle != currentTitle;

      if (!isCheckedChanged && !titleChanged) {
        _skip(id, 'No changes detected');
        continue;
      }

      // Apply updates
      final updatedData = entity.data.copyWith(
        isChecked: newIsChecked ?? currentIsChecked,
        title: newTitle ?? currentTitle,
      );

      final success = await checklistRepository.updateChecklistItem(
        checklistItemId: id,
        data: updatedData,
        taskId: task.id,
      );

      if (success) {
        successCount++;
        final changes = <String>[
          if (isCheckedChanged) 'isChecked',
          if (titleChanged) 'title',
        ];
        _updatedItems.add(UpdatedItemDetail(
          id: id,
          title: updatedData.title,
          isChecked: updatedData.isChecked,
          changes: changes,
        ));

        developer.log(
          'Updated checklist item $id: changes=$changes',
          name: 'LottiChecklistUpdateHandler',
        );
      } else {
        _skip(id, 'Update failed');
      }
    }

    // Refresh task reference if any updates succeeded
    if (successCount > 0) {
      final refreshedEntity = await journalDb.journalEntityById(task.id);
      if (refreshedEntity is Task) {
        task = refreshedEntity;
        onTaskUpdated?.call(refreshedEntity);
      }
    }

    return successCount;
  }

  List<UpdatedItemDetail> get updatedItems => List.unmodifiable(_updatedItems);
  List<SkippedItemDetail> get skippedItems => List.unmodifiable(_skippedItems);

  @override
  bool isDuplicate(FunctionCallResult result) {
    // Updates are idempotent - no duplicate tracking needed
    return false;
  }

  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      final items = result.data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;
      return '${items.length} item(s) to update';
    }
    return null;
  }

  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    final errorSummary = failedItems.map((item) {
      return '- ${item.error}';
    }).join('\n');

    return '''
I noticed errors in your checklist update call:
$errorSummary

Required format:
{"items": [{"id": "item-uuid", "isChecked": true}, {"id": "other-uuid", "title": "Fixed title"}]}

Each item must have:
- "id" (required): The checklist item ID
- At least one of "isChecked" (boolean) or "title" (string)

Please retry with the correct format.''';
  }

  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      return jsonEncode({
        'updatedItems': _updatedItems
            .map((item) => {
                  'id': item.id,
                  'title': item.title,
                  'isChecked': item.isChecked,
                  'changes': item.changes,
                })
            .toList(),
        'skippedItems': _skippedItems
            .map((item) => {
                  'id': item.id,
                  'reason': item.reason,
                })
            .toList(),
      });
    }
    return 'Error updating checklist items: ${result.error}';
  }

  void reset() {
    _updatedItems.clear();
    _skippedItems.clear();
  }
}

/// Details of a successfully updated item.
class UpdatedItemDetail {
  const UpdatedItemDetail({
    required this.id,
    required this.title,
    required this.isChecked,
    required this.changes,
  });

  final String id;
  final String title;
  final bool isChecked;
  final List<String> changes;
}

/// Details of a skipped item.
class SkippedItemDetail {
  const SkippedItemDetail({
    required this.id,
    required this.reason,
  });

  final String id;
  final String reason;
}
