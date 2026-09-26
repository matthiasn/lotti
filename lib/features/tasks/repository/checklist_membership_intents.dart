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
        ),
        'deleteItem' => DeleteItemIntent(
          itemId: json['itemId'] as String,
          checklistId: json['checklistId'] as String,
        ),
        'listChecklist' => ListChecklistIntent(
          checklistId: json['checklistId'] as String,
          taskId: json['taskId'] as String,
        ),
        'deleteChecklist' => DeleteChecklistIntent(
          checklistId: json['checklistId'] as String,
          taskId: json['taskId'] as String,
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
/// the source's.
final class MoveItemIntent extends MembershipIntent {
  const MoveItemIntent({
    required this.itemId,
    required this.fromId,
    required this.toId,
  });

  final String itemId;
  final String fromId;
  final String toId;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'moveItem',
    'itemId': itemId,
    'fromId': fromId,
    'toId': toId,
  };
}

/// An item the user deleted: unlisted at once, deleted when its undo window
/// closes, and relisted (the intent dropped) if the user undoes.
final class DeleteItemIntent extends MembershipIntent {
  const DeleteItemIntent({required this.itemId, required this.checklistId});

  final String itemId;
  final String checklistId;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'deleteItem',
    'itemId': itemId,
    'checklistId': checklistId,
  };
}

/// A checklist being created for a task: listed on it once it exists.
final class ListChecklistIntent extends MembershipIntent {
  const ListChecklistIntent({required this.checklistId, required this.taskId});

  final String checklistId;
  final String taskId;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'listChecklist',
    'checklistId': checklistId,
    'taskId': taskId,
  };
}

/// A checklist being deleted: deleted, and removed from its task's list.
final class DeleteChecklistIntent extends MembershipIntent {
  const DeleteChecklistIntent({
    required this.checklistId,
    required this.taskId,
  });

  final String checklistId;
  final String taskId;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'deleteChecklist',
    'checklistId': checklistId,
    'taskId': taskId,
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
