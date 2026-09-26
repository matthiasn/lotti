// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/model/membership_list.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
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

  /// Soft-deletes the checklist and detaches it from its parent task
  /// ([ChecklistRepository.deleteChecklist], which records the operation so
  /// the next start finishes it should the app die in between). Returns
  /// `false` only when the underlying entity delete itself fails.
  Future<bool> delete() async {
    final deleted = taskId == null
        ? await ref.read(journalRepositoryProvider).deleteJournalEntity(id)
        : await ref
              .read(checklistRepositoryProvider)
              .deleteChecklist(checklistId: id, taskId: taskId!);
    if (!deleted) return false;
    if (ref.mounted) state = const AsyncData(null);
    return true;
  }

  /// Renames the checklist; a null title is persisted as the empty string.
  Future<void> updateTitle(String? title) =>
      updateChecklist((data) => data.copyWith(title: title ?? ''));

  /// Persists the order [visibleOrder] shows the checklist's items in
  /// (drag-reorder), applied to the stored list ([inVisibleOrder]): an item
  /// stored after this screen last read the checklist keeps its place.
  Future<void> updateItemOrder(List<String> visibleOrder) => updateChecklist(
    (data) => data.copyWith(
      linkedChecklistItems: inVisibleOrder(
        data.linkedChecklistItems,
        visibleOrder,
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

      // Across checklists: the item's back-link, this list and the source's
      // are written as one recorded move; the source's controller and the
      // item's pick theirs up from their update notifications.
      final target = await ref
          .read(checklistRepositoryProvider)
          .moveItem(
            itemId: droppedChecklistItemId,
            fromId: fromChecklistId,
            toId: id,
            taskId: taskId,
            place: (stored) => _insertItemAt(
              stored,
              droppedChecklistItemId,
              targetIndex: targetIndex,
              targetItemId: targetItemId,
            ),
          );
      if (target != null && ref.mounted) state = AsyncData(target);
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

  /// Handles dropping a *new* (not yet persisted) item onto this checklist.
  ///
  /// [localData] carries the dragged title/status; the item is created and
  /// listed by [createChecklistItem]. A no-op when the payload is empty or
  /// has no title.
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

      await createChecklistItem(
        checklistItemTitle,
        isChecked: checklistItemStatus,
        categoryId: categoryId,
      );
    }
  }

  /// Starts deleting an item the user swiped away: it leaves this list at
  /// once and is deleted when [undoWindow] has passed, unless the user undoes
  /// first ([undoItemDeletion]). The repository times the window and records
  /// the deletion, so it completes after the row has left the screen, and
  /// even if the app dies meanwhile ([ChecklistRepository.beginItemDeletion]).
  /// Returns the deletion's key for [undoItemDeletion], or `null` when it
  /// could not be recorded.
  Future<String?> beginItemDeletion(
    String checklistItemId, {
    required Duration undoWindow,
  }) async {
    final key = await ref
        .read(checklistRepositoryProvider)
        .beginItemDeletion(
          itemId: checklistItemId,
          checklistId: id,
          undoWindow: undoWindow,
        );
    await _refresh();
    return key;
  }

  /// Lists the item again — the user undid its deletion. Harmless if it is
  /// listed already.
  Future<void> undoItemDeletion({
    required String key,
    required String checklistItemId,
  }) async {
    final written = await ref
        .read(checklistRepositoryProvider)
        .undoItemDeletion(
          key: key,
          itemId: checklistItemId,
          checklistId: id,
        );
    if (written != null && ref.mounted) state = AsyncData(written);
  }

  /// Publishes the checklist as stored.
  Future<void> _refresh() async {
    final latest = await _fetch();
    if (ref.mounted) state = AsyncData(latest);
  }

  /// Applies [change] to the checklist's data as stored — not to this
  /// controller's state, which an update notification refreshes only some
  /// time after the row changes — and publishes what was stored as the new
  /// state ([ChecklistRepository.updateChecklist]). No-op when the checklist
  /// has not loaded yet. The single mutation funnel used by the helpers above.
  Future<void> updateChecklist(
    ChecklistData Function(ChecklistData stored) change,
  ) async {
    if (state.value == null) return;
    final written = await ref
        .read(checklistRepositoryProvider)
        .updateChecklist(checklistId: id, change: change);
    if (written != null && ref.mounted) {
      state = AsyncData(written);
    }
  }

  /// Creates a new item under this checklist and lists it
  /// ([ChecklistRepository.addItemToChecklist], which records the operation
  /// so an item created just before the app died is listed at the next
  /// start). Returns the created item's id, or `null` when the checklist is
  /// not loaded, [title] is null, or the item could not be created.
  Future<String?> createChecklistItem(
    String? title, {
    required String? categoryId,
    required bool isChecked,
  }) async {
    final current = state.value;
    if (current == null || title == null) return null;
    final created = await ref
        .read(checklistRepositoryProvider)
        .addItemToChecklist(
          title: title,
          isChecked: isChecked,
          checklistId: current.id,
          categoryId: categoryId,
        );
    if (created == null) return null;
    await _refresh();
    return created.id;
  }
}
