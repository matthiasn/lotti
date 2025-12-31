// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Record type for checklist item parameters.
typedef ChecklistItemParams = ({String id, String? taskId});

final checklistItemControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChecklistItemController, ChecklistItem?, ChecklistItemParams>(
  ChecklistItemController.new,
);

class ChecklistItemController extends AsyncNotifier<ChecklistItem?> {
  ChecklistItemController(this.params);

  final ChecklistItemParams params;
  StreamSubscription<Set<String>>? _updateSubscription;

  String get id => params.id;
  String? get taskId => params.taskId;

  @override
  Future<ChecklistItem?> build() async {
    ref
      ..cacheFor(entryCacheDuration)
      ..onDispose(() {
        _updateSubscription?.cancel();
      });

    _listen();
    return _fetch();
  }

  void _listen() {
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
      final oldTitle = data.title;
      final categoryId = current.meta.categoryId;

      // Fire-and-forget capture. The service will handle notifications.
      unawaited(
        ref.read(correctionCaptureServiceProvider).captureCorrection(
              categoryId: categoryId,
              beforeText: oldTitle,
              afterText: title,
            ),
      );

      // Existing update logic continues synchronously
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
