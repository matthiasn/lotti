import 'dart:async';

import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_controller.g.dart';

@riverpod
class ChecklistController extends _$ChecklistController {
  ChecklistController() {
    listen();
  }
  late final String entryId;
  StreamSubscription<Set<String>>? _updateSubscription;
  final _persistenceLogic = getIt<PersistenceLogic>();

  void listen() {
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      if (affectedIds.contains(entryId)) {
        final latest = await _fetch();
        if (latest != state.value && latest is Checklist) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<Checklist?> build({required String id}) async {
    entryId = id;
    ref.onDispose(() => _updateSubscription?.cancel());
    final entry = await _fetch();

    if (entry is Checklist) {
      return entry;
    } else {
      return null;
    }
  }

  Future<JournalEntity?> _fetch() async {
    return getIt<JournalDb>().journalEntityById(entryId);
  }

  Future<bool> delete() async {
    final res = await _persistenceLogic.deleteJournalEntity(entryId);
    state = const AsyncData(null);
    return res;
  }

  Future<void> updateTitle(String? title) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null) {
      final updated = current.copyWith(
        data: data.copyWith(title: title ?? ''),
      );
      await ref.read(checklistRepositoryProvider).updateChecklist(
            checklistId: entryId,
            data: updated.data,
          );
      state = AsyncData(updated);
    }
  }

  Future<void> updateItemOrder(List<String> linkedChecklistItems) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null) {
      final updated = current.copyWith(
        data: data.copyWith(linkedChecklistItems: linkedChecklistItems),
      );
      await ref.read(checklistRepositoryProvider).updateChecklist(
            checklistId: entryId,
            data: updated.data,
          );
      state = AsyncData(updated);
    }
  }

  Future<void> createChecklistItem(String? title) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null && title != null) {
      final created =
          await ref.read(checklistRepositoryProvider).createChecklistItem(
                title: title,
                checklistId: current.id,
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
      }
    }
  }
}

@riverpod
class ChecklistCompletionController extends _$ChecklistCompletionController {
  ChecklistCompletionController();

  @override
  Future<double> build({required String id}) async {
    final checklistData =
        ref.watch(checklistControllerProvider(id: id)).value?.data;

    final linkedIds = checklistData?.linkedChecklistItems ?? <String>[];
    final linkedChecklistItems = linkedIds
        .map((id) => ref.watch(checklistItemControllerProvider(id: id)).value)
        .whereNotNull()
        .where((item) => item.isDeleted == false)
        .toList();
    final totalCount = linkedChecklistItems.length;
    final completedCount =
        linkedChecklistItems.where((item) => item.data.isChecked).length;

    return totalCount == 0 ? 0.0 : completedCount / totalCount;
  }
}
