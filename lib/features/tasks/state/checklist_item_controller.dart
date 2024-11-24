import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checklist_item_controller.g.dart';

@riverpod
class ChecklistItemController extends _$ChecklistItemController {
  ChecklistItemController() {
    listen();
  }
  late final String entryId;
  StreamSubscription<Set<String>>? _updateSubscription;

  void listen() {
    _updateSubscription =
        getIt<UpdateNotifications>().updateStream.listen((affectedIds) async {
      if (affectedIds.contains(entryId)) {
        final latest = await _fetch();
        if (latest != state.value && latest is ChecklistItem) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<ChecklistItem?> build({required String id}) async {
    entryId = id;
    ref.onDispose(() => _updateSubscription?.cancel());
    final entry = await _fetch();

    if (entry is ChecklistItem) {
      return entry;
    } else {
      return null;
    }
  }

  Future<JournalEntity?> _fetch() async {
    return getIt<JournalDb>().journalEntityById(entryId);
  }

  Future<bool> delete() async {
    final res = await getIt<PersistenceLogic>().deleteJournalEntity(entryId);
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
            checklistItemId: entryId,
            data: updated.data,
          );

      state = AsyncData(updated);
    }
  }

  void updateTitle(String? title) {
    debugPrint('updateTitle $title');
    final current = state.value;
    final data = current?.data;
    if (current != null && data != null && title != null) {
      final updated = current.copyWith(
        data: data.copyWith(title: title),
      );

      ref.read(checklistRepositoryProvider).updateChecklistItem(
            checklistItemId: entryId,
            data: updated.data,
          );

      state = AsyncData(updated);
    }
  }
}
