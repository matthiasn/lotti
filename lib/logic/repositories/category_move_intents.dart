import 'dart:convert';

import 'package:lotti/database/settings_db.dart';

/// A category move as recorded: the category the entry is being moved to,
/// `null` for none.
typedef CategoryMove = ({String? categoryId});

/// The device-local record of category moves in flight
/// (`EntryCategoryMove.move`).
///
/// Moving an entry to another category is several writes — the entry, every
/// entry linked from it, a task's checklists and their items, and last the
/// project links the move left across categories. A move is recorded here
/// before its first write and removed once the last one is done, so one the
/// app died in is finished at the next start (`EntryCategoryMove.replay`;
/// `specs/tla/TaskCategoryMove.tla`, `MoveIntent`).
///
/// Records never sync: each device finishes the moves it began, and their
/// writes reach the others as usual.
class CategoryMoveIntents {
  CategoryMoveIntents({required this._settingsDb});

  final SettingsDb _settingsDb;

  /// The settings key prefix of every recorded move.
  static const keyPrefix = 'categoryMoveIntent:';

  /// Records that [entryId] is being moved to [categoryId]. A later move of
  /// the same entry replaces the record: only the latest one is finished.
  Future<void> record(String entryId, String? categoryId) =>
      _settingsDb.saveSettingsItem(
        '$keyPrefix$entryId',
        jsonEncode({'categoryId': categoryId}),
      );

  /// Removes the record of [entryId]'s move: every write of it is done.
  Future<void> clear(String entryId) =>
      _settingsDb.removeSettingsItem('$keyPrefix$entryId');

  /// Every recorded move, by entry id; `null` for a record this build cannot
  /// read, which the caller drops.
  Future<Map<String, CategoryMove?>> pending() async {
    final rows = await _settingsDb.itemsWithKeyPrefix(keyPrefix);
    return {
      for (final MapEntry(:key, :value) in rows.entries)
        key.substring(keyPrefix.length): _decode(value),
    };
  }

  static CategoryMove? _decode(String value) {
    try {
      final json = jsonDecode(value);
      if (json is Map<String, dynamic> &&
          json.containsKey('categoryId') &&
          json['categoryId'] is String?) {
        return (categoryId: json['categoryId'] as String?);
      }
    } on FormatException {
      // Unreadable: dropped by the caller.
    }
    return null;
  }
}
