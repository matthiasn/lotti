// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';

/// Clock provider for timestamps — override in tests for determinism.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Record type for checklist item parameters.
typedef ChecklistItemParams = ({String id, String? taskId});

final checklistItemControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChecklistItemController, ChecklistItem?, ChecklistItemParams>(
      ChecklistItemController.new,
    );

/// Runtime controller for a single checklist item (keyed by item id).
///
/// Owns the item's checked/title/archive state. Note the side effect in
/// [updateTitle]: it fires a fire-and-forget correction capture (before→after
/// title + category) so user rewordings become category-scoped AI guidance.
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
    _updateSubscription = getIt<UpdateNotifications>().updateStream.listen((
      affectedIds,
    ) async {
      if (!affectedIds.contains(id)) return;
      developer.log(
        'notify received id=$id affected=$affectedIds',
        name: 'ChecklistItemController',
      );
      if (!ref.mounted) return;
      final latest = await _fetch();
      if (!ref.mounted) return;
      developer.log(
        'state updated id=$id isChecked=${latest?.data.isChecked}',
        name: 'ChecklistItemController',
      );
      state = AsyncData(latest);
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

  /// Marks the item archived — it is hidden from active checklist counts but
  /// not deleted. Reversed by [unarchive].
  void archive() => _setArchived(isArchived: true);

  /// Restores an archived item back into the active checklist.
  void unarchive() => _setArchived(isArchived: false);

  void _setArchived({required bool isArchived}) =>
      _update((data) => data.copyWith(isArchived: isArchived));

  /// Publishes [change] of this item at once, and writes it onto the item as
  /// stored ([ChecklistRepository.updateChecklistItem]) — not onto this
  /// controller's state, which may predate a move or an edit made elsewhere
  /// — then publishes what was stored. No-op while the item is unloaded.
  void _update(ChecklistItemData Function(ChecklistItemData data) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(data: change(current.data)));
    unawaited(
      ref
          .read(checklistRepositoryProvider)
          .updateChecklistItem(
            checklistItemId: id,
            change: change,
            taskId: taskId,
          )
          .then((written) {
            if (written != null && ref.mounted) state = AsyncData(written);
          }),
    );
  }

  /// Toggles the item's checked state, stamping [ChangeSource.user] and the
  /// current time (via [clockProvider]) as the audit trail, then persists and
  /// optimistically publishes the new state.
  void updateChecked({required bool checked}) {
    final checkedAt = ref.read(clockProvider)();
    _update(
      (data) => data.copyWith(
        isChecked: checked,
        checkedBy: ChangeSource.user,
        checkedAt: checkedAt,
      ),
    );
  }

  /// Renames the item and, as a side effect, fires a fire-and-forget
  /// correction capture (before→after title, scoped to the item's category) so
  /// user rewordings feed back into category-scoped AI suggestion guidance.
  /// No-op when the item is unloaded or [title] is null.
  void updateTitle(String? title) {
    final current = state.value;
    if (current == null || title == null) return;

    // Fire-and-forget capture. The service will handle notifications.
    unawaited(
      ref
          .read(correctionCaptureServiceProvider)
          .captureCorrection(
            categoryId: current.meta.categoryId,
            beforeText: current.data.title,
            afterText: title,
          ),
    );

    _update((data) => data.copyWith(title: title));
  }
}
