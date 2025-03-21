import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_item_controller.g.dart';

@riverpod
class ChecklistItemController extends _$ChecklistItemController {
  StreamSubscription<Set<String>>? _updateSubscription;

  void listen() {
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      if (affectedIds.contains(id)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<ChecklistItem?> build({
    required String id,
    required String? taskId,
  }) async {
    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final item = await _fetch();
    listen();
    return item;
  }

  Future<ChecklistItem?> _fetch() async {
    final res = await getIt<JournalDb>().journalEntityById(id);
    if (res is ChecklistItem && !res.isDeleted) {
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

  void updateChecked({required bool checked}) {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null) {
      final updated = current.copyWith(
        data: data.copyWith(
          isChecked: checked,
        ),
      );
      ref.read(checklistRepositoryProvider).updateChecklistItem(
            checklistItemId: id,
            data: updated.data,
            taskId: taskId,
          );

      state = AsyncData(updated);
    }
  }

  void updateTitle(String? title) {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null && title != null) {
      final updated = current.copyWith(
        data: data.copyWith(title: title),
      );

      ref.read(checklistRepositoryProvider).updateChecklistItem(
            checklistItemId: id,
            data: updated.data,
            taskId: taskId,
          );

      state = AsyncData(updated);
    }
  }

  Future<void> moveToChecklist({
    required String linkedChecklistId,
    required String fromChecklistId,
  }) async {
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null) {
      final linkedChecklists = {
        ...data.linkedChecklists,
        linkedChecklistId,
      }..remove(fromChecklistId);

      final updated = current.copyWith(
        data: data.copyWith(
          linkedChecklists: linkedChecklists.toList(),
        ),
      );

      await ref.read(checklistRepositoryProvider).updateChecklistItem(
            checklistItemId: id,
            data: updated.data,
            taskId: taskId,
          );

      state = AsyncData(updated);
    }
  }
}
