import 'dart:convert';

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:uuid/uuid.dart';

/// What a checklist-membership operation that writes more than one row is
/// about to do, recorded before its first write
/// ([ChecklistMembershipIntents.record]).
///
/// Every operation is a set of idempotent changes to stored rows — list
/// these ids, move this item, delete that one — so an operation the app died
/// in the middle of is finished at the next start by applying it again
/// (`ChecklistRepository.replayMembershipIntents`;
/// `specs/tla/ChecklistMembership.tla`, `IntentLog`).
///
/// A move and the two deletions also carry a `mark`: this device's counter
/// on the clock of the row whose write decides them — the item, or the
/// checklist — when they were recorded. Once that counter has moved on, the
/// operation's own write there landed, and a replay does not repeat it: a
/// later version of the row is another device's choice, a checklist or item
/// the user kept when resolving a conflict, which repeating the write would
/// undo (`specs/tla/ChecklistReplication.tla`, `ReplayGuard`).
sealed class MembershipIntent {
  const MembershipIntent();

  /// Reads an intent [toJson] wrote; `null` for one this build cannot read.
  static MembershipIntent? fromJson(Map<String, dynamic> json) =>
      switch (json['op']) {
        'listItems' => ListItemsIntent(
          checklistId: json['checklistId'] as String,
          itemIds: (json['itemIds'] as List<dynamic>).cast<String>(),
        ),
        'moveItem' => MoveItemIntent(
          itemId: json['itemId'] as String,
          fromId: json['fromId'] as String,
          toId: json['toId'] as String,
          mark: json['mark'] as int?,
        ),
        'deleteItem' => DeleteItemIntent(
          itemId: json['itemId'] as String,
          checklistId: json['checklistId'] as String,
          mark: json['mark'] as int?,
        ),
        'listChecklist' => ListChecklistIntent(
          checklistId: json['checklistId'] as String,
          taskId: json['taskId'] as String,
          restate: json['restate'] as bool? ?? false,
        ),
        'deleteChecklist' => DeleteChecklistIntent(
          checklistId: json['checklistId'] as String,
          taskId: json['taskId'] as String?,
          mark: json['mark'] as int?,
        ),
        'sweepChecklist' => SweepChecklistIntent(
          checklistId: json['checklistId'] as String,
        ),
        _ => null,
      };

  Map<String, dynamic> toJson();
}

/// Items being created in a checklist: each one that exists is listed.
final class ListItemsIntent extends MembershipIntent {
  const ListItemsIntent({required this.checklistId, required this.itemIds});

  final String checklistId;
  final List<String> itemIds;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'listItems',
    'checklistId': checklistId,
    'itemIds': itemIds,
  };
}

/// An item moving between checklists: its back-link, the target's list and
/// the source's. [mark] is on the item.
final class MoveItemIntent extends MembershipIntent {
  const MoveItemIntent({
    required this.itemId,
    required this.fromId,
    required this.toId,
    this.mark,
  });

  final String itemId;
  final String fromId;
  final String toId;
  final int? mark;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'moveItem',
    'itemId': itemId,
    'fromId': fromId,
    'toId': toId,
    'mark': ?mark,
  };
}

/// An item the user deleted: unlisted and its back-link cleared at once,
/// deleted when its undo window closes, and relisted (the intent dropped) if
/// the user undoes. [mark] is on the item, and taken only once the delete
/// itself starts (`ChecklistRepository.completeItemDeletion`): a `null` mark
/// is a deletion still in its undo window, which a replay completes — an
/// edit to the item inside the window must not read as the deletion having
/// landed.
final class DeleteItemIntent extends MembershipIntent {
  const DeleteItemIntent({
    required this.itemId,
    required this.checklistId,
    this.mark,
  });

  final String itemId;
  final String checklistId;
  final int? mark;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'deleteItem',
    'itemId': itemId,
    'checklistId': checklistId,
    'mark': ?mark,
  };
}

/// A checklist being created for a task, or kept by a conflict's
/// resolution: listed on it once it exists. With [restate], written onto the
/// task in a new version even when it is listed already
/// (`ChecklistRepository.resolveConflict`).
final class ListChecklistIntent extends MembershipIntent {
  const ListChecklistIntent({
    required this.checklistId,
    required this.taskId,
    this.restate = false,
  });

  final String checklistId;
  final String taskId;
  final bool restate;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'listChecklist',
    'checklistId': checklistId,
    'taskId': taskId,
    if (restate) 'restate': true,
  };
}

/// A deleted checklist whose items are being deleted with it — received
/// from another device, or kept by a conflict's resolution.
final class SweepChecklistIntent extends MembershipIntent {
  const SweepChecklistIntent({required this.checklistId});

  final String checklistId;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'sweepChecklist',
    'checklistId': checklistId,
  };
}

/// A checklist being deleted: removed from its task's list, deleted, and
/// its items deleted with it. [mark] is on the checklist.
final class DeleteChecklistIntent extends MembershipIntent {
  const DeleteChecklistIntent({
    required this.checklistId,
    required this.taskId,
    this.mark,
  });

  final String checklistId;

  /// `null` for a checklist naming no task.
  final String? taskId;
  final int? mark;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'deleteChecklist',
    'checklistId': checklistId,
    'taskId': ?taskId,
    'mark': ?mark,
  };
}

/// The durable record of membership operations in flight, one settings row
/// per operation. Settings rows of this kind never sync: the log is this
/// device's own.
class ChecklistMembershipIntents {
  ChecklistMembershipIntents({SettingsDb? settingsDb})
    : _settingsDbOverride = settingsDb;

  final SettingsDb? _settingsDbOverride;

  /// The settings key prefix of a recorded intent.
  static const keyPrefix = 'checklistMembershipIntent:';

  SettingsDb get _settingsDb => _settingsDbOverride ?? getIt<SettingsDb>();

  /// Records [intent] and returns the key that [clear] removes it by.
  Future<String> record(MembershipIntent intent) async {
    final key = '$keyPrefix${const Uuid().v4()}';
    await _settingsDb.saveSettingsItem(key, jsonEncode(intent.toJson()));
    return key;
  }

  /// Runs [operation] with [intent] recorded around it: recorded before its
  /// first write and removed once [done] says its result is complete. An
  /// operation that throws, or whose writes were refused or failed, leaves
  /// its intent for the next start to finish.
  Future<T> run<T>(
    MembershipIntent intent,
    Future<T> Function() operation, {
    required bool Function(T result) done,
  }) async {
    final key = await record(intent);
    final result = await operation();
    if (done(result)) await clear(key);
    return result;
  }

  /// Records [intent] in place of the one under [key] — the same operation,
  /// further along.
  Future<void> replace(String key, MembershipIntent intent) =>
      _settingsDb.saveSettingsItem(key, jsonEncode(intent.toJson()));

  /// Removes the intent recorded under [key]: its operation is complete.
  Future<void> clear(String key) => _settingsDb.removeSettingsItem(key);

  /// Every recorded intent, by key. An intent this build cannot read is
  /// returned as `null`, so the caller can drop it.
  Future<Map<String, MembershipIntent?>> pending() async {
    final rows = await _settingsDb.itemsWithKeyPrefix(keyPrefix);
    return {
      for (final MapEntry(:key, :value) in rows.entries) key: _decode(value),
    };
  }

  static MembershipIntent? _decode(String value) {
    try {
      return MembershipIntent.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } on Object {
      return null;
    }
  }
}
