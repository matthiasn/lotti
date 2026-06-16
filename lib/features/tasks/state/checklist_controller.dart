// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:meta/meta.dart';

/// Record type for checklist parameters.
typedef ChecklistParams = ({String id, String? taskId});

final checklistControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChecklistController, Checklist?, ChecklistParams>(
      ChecklistController.new,
    );

/// Runtime controller for a single checklist entity (keyed by checklist id).
///
/// Loads the checklist, subscribes to it and all linked checklist-item IDs, and
/// owns the structural mutations: title/order updates, dropping existing or new
/// items in, moving items across checklists, unlink/relink, and deleting the
/// checklist (removing its id from the parent task when possible).
class ChecklistController extends AsyncNotifier<Checklist?> {
  ChecklistController(this.params);

  final ChecklistParams params;
  final subscribedIds = <String>{};
  StreamSubscription<Set<String>>? _updateSubscription;

  String get id => params.id;
  String? get taskId => params.taskId;

  @override
  Future<Checklist?> build() async {
    subscribedIds.add(id);
    ref
      ..cacheFor(entryCacheDuration)
      ..onDispose(() {
        _updateSubscription?.cancel();
      });

    _listen();

    final checklist = await _fetch();
    if (checklist != null) {
      subscribedIds.addAll(checklist.data.linkedChecklistItems);
    }
    return checklist;
  }

  void _listen() {
    _updateSubscription = getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) async {
      final hit = affectedIds.intersection(subscribedIds);
      if (hit.isEmpty) return;
      developer.log(
        'notify received id=$id hit=$hit subscribed=$subscribedIds',
        name: 'ChecklistController',
      );
      if (!ref.mounted) return;
      final latest = await _fetch();
      if (!ref.mounted) return;
      subscribedIds
        ..clear()
        ..add(id);
      if (latest != null) {
        subscribedIds.addAll(latest.data.linkedChecklistItems);
      }
      developer.log(
        'state updated id=$id items=${latest?.data.linkedChecklistItems.length}',
        name: 'ChecklistController',
      );
      state = AsyncData(latest);
    });
  }

  Future<Checklist?> _fetch() async {
    final res = await getIt<JournalDb>().journalEntityById(id);

    if (res is Checklist && !res.isDeleted) {
      return res;
    } else {
      return null;
    }
  }

  Future<bool> delete() async {
    final res = await ref
        .read(journalRepositoryProvider)
        .deleteJournalEntity(id);
    if (!res) {
      return false;
    }

    state = const AsyncData(null);

    // Also remove this checklist from the parent task's checklistIds
    if (taskId != null) {
      try {
        final taskEntry = await getIt<JournalDb>().journalEntityById(taskId!);
        if (taskEntry is Task) {
          final currentIds = taskEntry.data.checklistIds ?? [];
          final updatedIds = currentIds.where((cid) => cid != id).toList();
          if (updatedIds.length != currentIds.length) {
            await getIt<PersistenceLogic>().updateTask(
              journalEntityId: taskId!,
              taskData: taskEntry.data.copyWith(checklistIds: updatedIds),
            );
          }
        }
      } catch (exception, stackTrace) {
        getIt<DomainLogger>().error(
          LogDomain.tasks,
          'Failed to remove checklist ID ($id) from task ($taskId): $exception',
          stackTrace: stackTrace,
          subDomain: 'delete',
        );
        // Design decision: We log but don't fail/rollback for these reasons:
        // 1. The checklist IS successfully deleted (soft-delete with deletedAt)
        // 2. Rolling back would require "undeleting" which risks sync conflicts
        // 3. The defensive UI filtering in ChecklistsWidget handles stale refs
        // 4. True atomicity would require transaction support in PersistenceLogic
        // The user experience is unaffected due to the UI-level filtering.
      }
    }

    return true;
  }

  Future<void> updateTitle(String? title) => updateChecklist(
    (checklist) => checklist.copyWith(
      data: checklist.data.copyWith(title: title ?? ''),
    ),
  );

  Future<void> updateItemOrder(List<String> linkedChecklistItems) =>
      updateChecklist(
        (checklist) => checklist.copyWith(
          data: checklist.data.copyWith(
            linkedChecklistItems: linkedChecklistItems,
          ),
        ),
      );

  /// Handles dropping a checklist item onto this checklist.
  ///
  /// If [targetIndex] is provided, the item will be inserted at that position.
  /// If [targetItemId] is provided, the item will be inserted after that item.
  /// For same-checklist drops, this enables reordering.
  Future<void> dropChecklistItem(
    Object? localData, {
    String? categoryId,
    int? targetIndex,
    String? targetItemId,
  }) async {
    if (localData != null && localData is Map && localData.isNotEmpty) {
      if (localData['checklistItemTitle'] != null) {
        return dropChecklistNewItem(
          localData,
          categoryId: categoryId,
        );
      }

      final droppedChecklistItemId = localData['checklistItemId'] as String;
      final fromChecklistId = localData['checklistId'] as String;

      // Same checklist: reorder
      if (fromChecklistId == id) {
        await _reorderItem(droppedChecklistItemId, targetIndex, targetItemId);
        return;
      }

      await ref
          .read(
            checklistItemControllerProvider((
              id: droppedChecklistItemId,
              taskId: taskId,
            )).notifier,
          )
          .moveToChecklist(
            linkedChecklistId: id,
            fromChecklistId: fromChecklistId,
          );

      await updateChecklist(
        (checklist) => checklist.copyWith(
          data: checklist.data.copyWith(
            linkedChecklistItems: _insertItemAt(
              checklist.data.linkedChecklistItems,
              droppedChecklistItemId,
              targetIndex: targetIndex,
              targetItemId: targetItemId,
            ),
          ),
        ),
      );

      await ref
          .read(
            checklistControllerProvider((
              id: fromChecklistId,
              taskId: taskId,
            )).notifier,
          )
          .unlinkItem(droppedChecklistItemId);
    }
  }

  /// Returns a new list with [itemId] inserted at the position implied by
  /// [targetIndex] / [targetItemId]. Drops on the empty area of a checklist
  /// (no target) append to the end. Drops on a row insert at that row's
  /// index when [targetIndex] is supplied, otherwise after [targetItemId].
  /// If [itemId] already exists in the list, it is moved (not duplicated).
  /// Test-only seam for [_insertItemAt] — the pure insertion/move logic.
  @visibleForTesting
  List<String> debugInsertItemAt(
    List<String> existing,
    String itemId, {
    int? targetIndex,
    String? targetItemId,
  }) => _insertItemAt(
    existing,
    itemId,
    targetIndex: targetIndex,
    targetItemId: targetItemId,
  );

  List<String> _insertItemAt(
    List<String> existing,
    String itemId, {
    int? targetIndex,
    String? targetItemId,
  }) {
    final items = existing.toList()..remove(itemId);

    int insertIndex;
    if (targetIndex != null) {
      insertIndex = targetIndex;
    } else if (targetItemId != null) {
      final targetIdx = items.indexOf(targetItemId);
      insertIndex = targetIdx != -1 ? targetIdx + 1 : items.length;
    } else {
      insertIndex = items.length;
    }

    insertIndex = insertIndex.clamp(0, items.length);
    items.insert(insertIndex, itemId);
    return items;
  }

  /// Reorders an item within this checklist.
  Future<void> _reorderItem(
    String itemId,
    int? targetIndex,
    String? targetItemId,
  ) async {
    final checklist = state.value;
    if (checklist == null) return;

    final items = checklist.data.linkedChecklistItems.toList();
    final oldIndex = items.indexOf(itemId);
    if (oldIndex == -1) return;

    // Remove from old position
    items.removeAt(oldIndex);

    // Determine new position
    int newIndex;
    if (targetIndex != null) {
      // Adjust for removal
      newIndex = targetIndex > oldIndex ? targetIndex - 1 : targetIndex;
    } else if (targetItemId != null) {
      final targetIdx = items.indexOf(targetItemId);
      // Insert after the target item
      newIndex = targetIdx != -1 ? targetIdx + 1 : items.length;
    } else {
      // No position specified, add to end
      newIndex = items.length;
    }

    // Clamp to valid range
    newIndex = newIndex.clamp(0, items.length);

    // Insert at new position
    items.insert(newIndex, itemId);

    await updateItemOrder(items);
  }

  Future<void> dropChecklistNewItem(
    Object? localData, {
    String? categoryId,
  }) async {
    if (localData != null && localData is Map && localData.isNotEmpty) {
      final checklistItemTitle = localData['checklistItemTitle'] as String?;
      final checklistItemStatus =
          localData['checklistItemStatus'] as bool? ?? false;

      if (checklistItemTitle == null) {
        return;
      }

      final createdItemId = await createChecklistItem(
        checklistItemTitle,
        isChecked: checklistItemStatus,
        categoryId: categoryId,
      );

      if (createdItemId == null) {
        return;
      }

      await updateChecklist(
        (checklist) => checklist.copyWith(
          data: checklist.data.copyWith(
            linkedChecklistItems: {
              ...checklist.data.linkedChecklistItems,
              createdItemId,
            }.toList(),
          ),
        ),
      );
    }
  }

  /// Re-adds an item to the checklist's linked items (undo for [unlinkItem]).
  ///
  /// Guards against duplicates so that calling this twice is harmless.
  Future<void> relinkItem(String checklistItemId) => updateChecklist(
    (checklist) {
      final items = checklist.data.linkedChecklistItems;
      if (items.contains(checklistItemId)) return checklist;
      return checklist.copyWith(
        data: checklist.data.copyWith(
          linkedChecklistItems: [...items, checklistItemId],
        ),
      );
    },
  );

  Future<void> unlinkItem(String checklistItemId) => updateChecklist(
    (checklist) => checklist.copyWith(
      data: checklist.data.copyWith(
        linkedChecklistItems: checklist.data.linkedChecklistItems
            .where((id) => id != checklistItemId)
            .toList(),
      ),
    ),
  );

  Future<void> updateChecklist(Checklist Function(Checklist) updateFn) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null) {
      final updated = updateFn(current);
      await ref
          .read(checklistRepositoryProvider)
          .updateChecklist(
            checklistId: id,
            data: updated.data,
          );
      state = AsyncData(updated);
    }
  }

  Future<String?> createChecklistItem(
    String? title, {
    required String? categoryId,
    required bool isChecked,
  }) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null && title != null) {
      final created = await ref
          .read(checklistRepositoryProvider)
          .createChecklistItem(
            title: title,
            isChecked: isChecked,
            checklistId: current.id,
            categoryId: categoryId,
          );

      if (created != null) {
        final updated = current.copyWith(
          data: current.data.copyWith(
            linkedChecklistItems: [
              ...data.linkedChecklistItems,
              created.id,
            ],
          ),
        );

        await ref
            .read(checklistRepositoryProvider)
            .updateChecklist(
              checklistId: current.id,
              data: updated.data.copyWith(
                linkedChecklistItems: [
                  ...data.linkedChecklistItems,
                  created.id,
                ],
              ),
            );

        state = AsyncData(updated);
        return created.id;
      }
    }
    return null;
  }
}
