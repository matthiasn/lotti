// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Record type for checklist parameters.
typedef ChecklistParams = ({String id, String? taskId});

final checklistControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChecklistController, Checklist?, ChecklistParams>(
  ChecklistController.new,
);

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
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      if (affectedIds.intersection(subscribedIds).isNotEmpty) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
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
    final res =
        await ref.read(journalRepositoryProvider).deleteJournalEntity(id);
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
        getIt<LoggingService>().captureException(
          'Failed to remove checklist ID ($id) from task ($taskId): $exception',
          domain: 'ChecklistController',
          subDomain: 'delete',
          stackTrace: stackTrace,
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
          data: checklist.data
              .copyWith(linkedChecklistItems: linkedChecklistItems),
        ),
      );

  Future<void> dropChecklistItem(
    Object? localData, {
    String? categoryId,
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

      if (fromChecklistId == id) {
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
            linkedChecklistId: droppedChecklistItemId,
            fromChecklistId: fromChecklistId,
          );

      await updateChecklist(
        (checklist) => checklist.copyWith(
          data: checklist.data.copyWith(
            linkedChecklistItems: {
              ...checklist.data.linkedChecklistItems,
              droppedChecklistItemId,
            }.toList(),
          ),
        ),
      );

      await ref
          .read(
            checklistControllerProvider((id: fromChecklistId, taskId: taskId))
                .notifier,
          )
          .unlinkItem(droppedChecklistItemId);
    }
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
      await ref.read(checklistRepositoryProvider).updateChecklist(
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
      final created =
          await ref.read(checklistRepositoryProvider).createChecklistItem(
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

        await ref.read(checklistRepositoryProvider).updateChecklist(
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

/// Record type for completion controller parameters.
typedef ChecklistCompletionParams = ({String id, String? taskId});

typedef ChecklistCompletionState = ({int completedCount, int totalCount});

final checklistCompletionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChecklistCompletionController, ChecklistCompletionState,
        ChecklistCompletionParams>(
  ChecklistCompletionController.new,
);

class ChecklistCompletionController
    extends AsyncNotifier<ChecklistCompletionState> {
  ChecklistCompletionController(this.params);

  final ChecklistCompletionParams params;
  ProviderSubscription<AsyncValue<Checklist?>>? _checklistSubscription;
  final Map<String, ProviderSubscription<AsyncValue<ChecklistItem?>>>
      _itemSubscriptions = {};

  String get id => params.id;
  String? get taskId => params.taskId;

  @override
  Future<ChecklistCompletionState> build() async {
    ref.onDispose(() {
      _checklistSubscription?.close();
      for (final sub in _itemSubscriptions.values) {
        sub.close();
      }
    });

    _checklistSubscription = ref.listen<AsyncValue<Checklist?>>(
      checklistControllerProvider((id: id, taskId: taskId)),
      (_, __) => _updateState(),
    );

    return _computeState();
  }

  ChecklistCompletionState _computeState() {
    final checklistData = ref
        .read(checklistControllerProvider((id: id, taskId: taskId)))
        .value
        ?.data;

    final linkedIds = checklistData?.linkedChecklistItems ?? <String>[];

    // Subscribe to any new item providers
    for (final itemId in linkedIds) {
      if (!_itemSubscriptions.containsKey(itemId)) {
        _itemSubscriptions[itemId] = ref.listen<AsyncValue<ChecklistItem?>>(
          checklistItemControllerProvider((id: itemId, taskId: taskId)),
          (_, __) => _updateState(),
        );
      }
    }

    final linkedChecklistItems = linkedIds
        .map(
          (itemId) => ref
              .read(
                  checklistItemControllerProvider((id: itemId, taskId: taskId)))
              .value,
        )
        .nonNulls
        .where((item) => !item.isDeleted)
        .toList();
    final totalCount = linkedChecklistItems.length;
    final completedCount =
        linkedChecklistItems.where((item) => item.data.isChecked).length;

    return (completedCount: completedCount, totalCount: totalCount);
  }

  void _updateState() {
    state = AsyncData(_computeState());
  }
}

final checklistCompletionRateControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ChecklistCompletionRateController,
        double, ChecklistCompletionParams>(
  ChecklistCompletionRateController.new,
);

class ChecklistCompletionRateController extends AsyncNotifier<double> {
  ChecklistCompletionRateController(this.params);

  final ChecklistCompletionParams params;
  ProviderSubscription<AsyncValue<ChecklistCompletionState>>? _subscription;

  String get id => params.id;
  String? get taskId => params.taskId;

  @override
  Future<double> build() async {
    ref.onDispose(() {
      _subscription?.close();
    });

    _subscription = ref.listen<AsyncValue<ChecklistCompletionState>>(
      checklistCompletionControllerProvider((id: id, taskId: taskId)),
      (_, next) {
        final res = next.value;
        final totalCount = res?.totalCount ?? 0;
        final completedCount = res?.completedCount ?? 0;
        state = AsyncData(totalCount == 0 ? 0.0 : completedCount / totalCount);
      },
    );

    final res = ref
        .read(checklistCompletionControllerProvider((id: id, taskId: taskId)))
        .value;
    final totalCount = res?.totalCount ?? 0;
    final completedCount = res?.completedCount ?? 0;
    return totalCount == 0 ? 0.0 : completedCount / totalCount;
  }
}
