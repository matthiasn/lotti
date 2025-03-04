import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_controller.g.dart';

@riverpod
class ChecklistController extends _$ChecklistController {
  final subscribedIds = <String>{};
  StreamSubscription<Set<String>>? _updateSubscription;

  void listen() {
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

  @override
  Future<Checklist?> build({required String id}) async {
    subscribedIds.add(id);
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final checklist = await _fetch();

    if (checklist != null) {
      subscribedIds.addAll(checklist.data.linkedChecklistItems);
    }

    listen();

    return checklist;
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
    state = const AsyncData(null);
    return res;
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
            checklistItemControllerProvider(id: droppedChecklistItemId)
                .notifier,
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
          .read(checklistControllerProvider(id: fromChecklistId).notifier)
          .unlinkItem(droppedChecklistItemId);
    }
  }

  Future<void> dropChecklistNewItem(
    Object? localData, {
    String? categoryId,
  }) async {
    if (localData != null && localData is Map && localData.isNotEmpty) {
      final checklistItemTitle = localData['checklistItemTitle'] as String?;

      final createdItemId = await createChecklistItem(
        checklistItemTitle,
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
  }) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null && title != null) {
      final created =
          await ref.read(checklistRepositoryProvider).createChecklistItem(
                title: title,
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

@riverpod
class ChecklistCompletionController extends _$ChecklistCompletionController {
  ChecklistCompletionController();

  @override
  Future<({int completedCount, int totalCount})> build({
    required String id,
  }) async {
    final checklistData =
        ref.watch(checklistControllerProvider(id: id)).value?.data;

    final linkedIds = checklistData?.linkedChecklistItems ?? <String>[];
    final linkedChecklistItems = linkedIds
        .map((id) => ref.watch(checklistItemControllerProvider(id: id)).value)
        .nonNulls
        .where((item) => item.isDeleted == false)
        .toList();
    final totalCount = linkedChecklistItems.length;
    final completedCount =
        linkedChecklistItems.where((item) => item.data.isChecked).length;

    return (
      completedCount: completedCount,
      totalCount: totalCount,
    );
  }
}

@riverpod
class ChecklistCompletionRateController
    extends _$ChecklistCompletionRateController {
  ChecklistCompletionRateController();

  @override
  Future<double> build({required String id}) async {
    final res = ref.watch(checklistCompletionControllerProvider(id: id)).value;
    final totalCount = res?.totalCount ?? 0;
    final completedCount = res?.completedCount ?? 0;

    return totalCount == 0 ? 0.0 : completedCount / totalCount;
  }
}
