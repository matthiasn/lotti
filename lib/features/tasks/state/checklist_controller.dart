import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
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
      await _persistenceLogic.updateChecklist(
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
      final created = await _persistenceLogic.createChecklistItem(
        title: title,
        checklist: current,
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

        await _persistenceLogic.updateChecklist(
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
