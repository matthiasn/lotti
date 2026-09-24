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
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:openai_dart/openai_dart.dart';

/// Handler for batch checklist item creation in Lotti
class LottiBatchChecklistHandler extends FunctionHandler {
  LottiBatchChecklistHandler({
    required this.task,
    required this.autoChecklistService,
    required this.checklistRepository,
    this.onTaskUpdated,
    this.approval,
    this.derivedIds,
  });

  final ChecklistItemProvenance? approval;

  /// The `uuidV5Input`s of what a confirmed agent change creates: `checklist`
  /// for the checklist a task without one gets, `item(index)` for the item at
  /// that index of the batch. With them, applying the same change twice —
  /// confirmed on two devices before they sync — adds each item once (see
  /// [createBatchItems]). `null` outside a confirmed change: ids are random.
  final ({String checklist, String Function(int index) item})? derivedIds;

  Task task;
  final AutoChecklistService autoChecklistService;
  final ChecklistRepository checklistRepository;
  final void Function(Task)? onTaskUpdated;

  final List<Map<String, dynamic>> _createdDetails = [];
  final List<FailedItemDetail> _failedItems = [];

  @override
  String get functionName => 'add_multiple_checklist_items';

  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    // Early check: verify function name matches
    if (call.function.name != functionName) {
      return FunctionCallResult(
        success: false,
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
            data: {
              'toolCallId': call.id,
              'taskId': task.id,
            },
            error:
                error ??
                'Each item must be an object with a title. Example: {"items": [{"title": "Buy milk"}] }',
          );
        }
      }

      // Sanitize and validate array-of-objects
      final validatedItems = ChecklistValidation.validateItems(raw);

      // Convert validated items to the expected format
      final sanitized = validatedItems
          .map(
            (item) => {
              'title': item.title,
              'isChecked': item.isChecked,
            },
          )
          .toList();

      if (!ChecklistValidation.isValidBatchSize(sanitized.length)) {
        return FunctionCallResult(
          success: false,
          data: {
            'toolCallId': call.id,
            'taskId': task.id,
          },
          error: ChecklistValidation.getBatchSizeErrorMessage(sanitized.length),
        );
      }

      return FunctionCallResult(
        success: true,
        data: {
          'items': sanitized,
          'toolCallId': call.id,
          'taskId': task.id,
        },
      );
    } catch (e) {
      return FunctionCallResult(
        success: false,
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
  /// With [derivedIds] every item gets the id derived from its input, and an
  /// item whose id is already in the journal — added by an earlier
  /// application of the same change, here or on another device, or deleted
  /// since — is left alone and counted as added. A task without a checklist
  /// gets the derived one first — reused when another device's copy has
  /// arrived before the task update listing it
  /// ([ChecklistRepository.derivedChecklistFor]) — so that two devices adding
  /// to it end up with one checklist. If every derived item was deleted, a
  /// replay leaves a task without a checklist as it is, rather than creating
  /// an empty replacement.
  ///
  /// Returns the number of successfully created items.
  Future<int> createBatchItems(FunctionCallResult result) async {
    if (!result.success) return 0;

    final items = (result.data['items'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
    var successCount = 0;
    _createdDetails.clear();
    _failedItems.clear();

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

      final derivedIds = this.derivedIds;
      if (derivedIds != null) {
        // A replay of a fully deleted batch has no remaining items to house.
        // Check before creating the next checklist generation, otherwise a
        // late confirmation brings back an empty container the user removed.
        if (checklistIds.isEmpty) {
          final ids = [
            for (var index = 0; index < items.length; index++)
              MetadataService.deterministicId(derivedIds.item(index)),
          ];
          final existing = await journalDb
              .journalEntityMapForIdsIncludingDeleted(
                ids,
              );
          if (ids.every((id) => existing[id]?.meta.deletedAt != null)) {
            // A live container can hold unrelated items and arrive before
            // the task update listing it. Repair that link without creating.
            final liveChecklist = await checklistRepository.derivedChecklistFor(
              taskId: currentTask.id,
              uuidV5Input: derivedIds.checklist,
              createIfMissing: false,
            );
            if (liveChecklist != null) {
              return await _addItems(
                liveChecklist,
                items,
                currentTask,
                journalDb,
                idInput: derivedIds.item,
              );
            }
            for (final (index, item) in items.indexed) {
              _createdDetails.add({
                'id': ids[index],
                'title': item['title'],
                'isChecked': (item['isChecked'] as bool?) ?? false,
              });
            }
            return items.length;
          }
        }
        final checklistId = checklistIds.isNotEmpty
            ? checklistIds.first
            : await checklistRepository.derivedChecklistFor(
                taskId: currentTask.id,
                uuidV5Input: derivedIds.checklist,
              );
        if (checklistId == null) {
          _failAll(items, 'Checklist creation failed');
          return 0;
        }
        successCount = await _addItems(
          checklistId,
          items,
          currentTask,
          journalDb,
          idInput: derivedIds.item,
        );
      } else if (checklistIds.isEmpty) {
        // Create a new "Todos" checklist with all items (preserve order)
        final checklistItems = <ChecklistItemData>[
          for (final item in items)
            ChecklistItemData(
              title: item['title'] as String,
              isChecked: (item['isChecked'] as bool?) ?? false,
              linkedChecklists: [],
              checkedBy: approval == null
                  ? ChangeSource.agent
                  : ChangeSource.user,
              checkedAt: approval?.approvedAt,
              approvalHistory: [
                if (approval case final receipt?)
                  receipt.copyWith(
                    isChecked: (item['isChecked'] as bool?) ?? false,
                    title: item['title'] as String,
                  ),
              ],
            ),
        ];

        if (checklistItems.isNotEmpty) {
          final createResult = await autoChecklistService.autoCreateChecklist(
            taskId: currentTask.id,
            suggestions: checklistItems,
            title: 'Todos',
          );

          if (createResult.success && createResult.createdItems != null) {
            successCount = createResult.createdItems!.length;
            // Use the returned items directly - no need for fragile mapping
            for (final item in createResult.createdItems!) {
              _createdDetails.add({
                'id': item.id,
                'title': item.title,
                'isChecked': item.isChecked,
              });
            }

            // Refresh the task after creating checklist
            final refreshedEntity = await journalDb.journalEntityById(
              currentTask.id,
            );
            if (refreshedEntity is Task) {
              task = refreshedEntity;
              onTaskUpdated?.call(refreshedEntity);
            }
          } else {
            // Checklist creation failed — record all items as failed.
            _failAll(items, 'Checklist creation failed');
          }
        }
      } else {
        // Add items to the first existing checklist
        successCount = await _addItems(
          checklistIds.first,
          items,
          currentTask,
          journalDb,
        );
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

  /// Adds [items] to the checklist [checklistId] of [currentTask], each
  /// under the id derived from `idInput(index)` when given, and returns how
  /// many of them it holds afterwards.
  Future<int> _addItems(
    String checklistId,
    List<Map<String, dynamic>> items,
    Task currentTask,
    JournalDb journalDb, {
    String Function(int index)? idInput,
  }) async {
    var successCount = 0;
    for (final (index, item) in items.indexed) {
      final title = item['title'] as String;
      final isChecked = (item['isChecked'] as bool?) ?? false;
      final uuidV5Input = idInput?.call(index);

      if (uuidV5Input != null) {
        final id = MetadataService.deterministicId(uuidV5Input);
        final existing = await journalDb.journalEntityMapForIdsIncludingDeleted(
          [id],
        );
        if (existing.containsKey(id)) {
          successCount++;
          _createdDetails.add({
            'id': id,
            'title': title,
            'isChecked': isChecked,
          });
          continue;
        }
      }

      final newItem = await checklistRepository.addItemToChecklist(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: currentTask.meta.categoryId,
        checkedBy: approval == null ? ChangeSource.agent : ChangeSource.user,
        checkedAt: approval?.approvedAt,
        approvalHistory: [
          if (approval case final receipt?)
            receipt.copyWith(isChecked: isChecked, title: title),
        ],
        uuidV5Input: uuidV5Input,
      );

      if (newItem != null) {
        successCount++;
        _createdDetails.add({
          'id': newItem.id,
          'title': title,
          'isChecked': isChecked,
        });
      } else {
        _failedItems.add(
          FailedItemDetail(title: title, reason: 'Creation returned null'),
        );
      }
    }

    // Only refresh the task if items were actually added
    if (successCount > 0) {
      final refreshedEntity = await journalDb.journalEntityById(
        currentTask.id,
      );
      if (refreshedEntity is Task) {
        task = refreshedEntity;
        onTaskUpdated?.call(refreshedEntity);
      } else if (refreshedEntity == null) {
        // Task was deleted, stop processing
        developer.log(
          'Task ${currentTask.id} was deleted, stopping batch checklist processing',
          name: 'LottiBatchChecklistHandler',
        );
      }
    }
    return successCount;
  }

  /// Records every item of [items] as failed for [reason].
  void _failAll(List<Map<String, dynamic>> items, String reason) {
    for (final item in items) {
      _failedItems.add(
        FailedItemDetail(title: item['title'] as String, reason: reason),
      );
    }
  }

  /// Items that failed to be created during [createBatchItems].
  List<FailedItemDetail> get failedItems => List.unmodifiable(_failedItems);

  @override
  String createToolResponse(FunctionCallResult result) {
    if (!result.success) {
      return 'Error creating checklist items: ${result.error}';
    }

    if (_createdDetails.isEmpty) {
      if (_failedItems.isNotEmpty) {
        final failedTitles = _failedItems
            .map((f) => '"${f.title}" (${f.reason})')
            .join(', ');
        return 'No checklist items were created. '
            'Failed ${_failedItems.length}: $failedTitles.';
      }
      return 'No checklist items were created.';
    }

    final count = _createdDetails.length;
    final titles = _createdDetails.map((d) => '"${d['title']}"').join(', ');

    final checkedCount = _createdDetails
        .where((d) => d['isChecked'] == true)
        .length;
    final checkedNote = checkedCount > 0
        ? ' ($checkedCount already checked)'
        : '';

    final buffer = StringBuffer(
      'Created $count checklist item${count == 1 ? '' : 's'}$checkedNote: $titles.',
    );

    if (_failedItems.isNotEmpty) {
      final failedTitles = _failedItems
          .map((f) => '"${f.title}" (${f.reason})')
          .join(', ');
      buffer.write(
        ' Failed ${_failedItems.length}: $failedTitles.',
      );
    }

    return buffer.toString();
  }
}

/// Details of an item that failed to be created.
class FailedItemDetail {
  const FailedItemDetail({
    required this.title,
    required this.reason,
  });

  final String title;
  final String reason;
}
