import 'package:lotti/database/settings_db.dart';

/// A confirmed change item whose tool is being dispatched: recorded before
/// its claim, cleared once the dispatch's outcome is written
/// ([ChangeDispatchIntents]).
typedef ChangeDispatch = ({String changeSetId, int itemIndex});

/// The device-local record of change-item dispatches in flight, per
/// confirmation service ([scope]).
///
/// A confirmation claims its item — pending to confirmed — and then runs the
/// tool, whose writes can be several: a follow-up task, its link, its
/// project, its agent. An app that dies in between leaves the item
/// confirmed without its whole effect, and nothing else would apply it
/// again. Recorded here before the claim, such a dispatch is resumed at the
/// next start while its item is still confirmed
/// (`ChangeSetConfirmationService.resumeInterrupted`;
/// `specs/tla/ChangeDispatchRecovery.tla`, `DispatchIntent`). The tools are
/// idempotent per item, so resuming one that did finish is harmless.
///
/// Intents never sync: the dispatch is this device's, and another device
/// that dispatches the same item does so under its own claim.
class ChangeDispatchIntents {
  ChangeDispatchIntents({required this.scope, required this._settingsDb});

  /// The confirmation service the dispatches belong to: only it can run
  /// them again.
  final String scope;

  /// The settings database the dispatches are recorded in, read when first
  /// used.
  final SettingsDb Function() _settingsDb;

  /// The settings key prefix of every recorded dispatch.
  static const keyPrefix = 'changeDispatchIntent:';

  String get _scopePrefix => '$keyPrefix$scope:';

  /// Records [dispatch] and returns the key [clear] removes it by. The key
  /// names the item, so recording it again is the same record.
  Future<String> record(ChangeDispatch dispatch) async {
    final key = '$_scopePrefix${dispatch.itemIndex}:${dispatch.changeSetId}';
    await _settingsDb().saveSettingsItem(key, '');
    return key;
  }

  /// Removes the dispatch recorded under [key]: its outcome is written.
  Future<void> clear(String key) => _settingsDb().removeSettingsItem(key);

  /// Every dispatch of this [scope] still recorded, by key; `null` for a key
  /// this build cannot read, which the caller drops.
  Future<Map<String, ChangeDispatch?>> pending() async {
    final rows = await _settingsDb().itemsWithKeyPrefix(_scopePrefix);
    return {for (final key in rows.keys) key: _decode(key)};
  }

  ChangeDispatch? _decode(String key) {
    final rest = key.substring(_scopePrefix.length);
    final separator = rest.indexOf(':');
    if (separator <= 0) return null;
    final itemIndex = int.tryParse(rest.substring(0, separator));
    final changeSetId = rest.substring(separator + 1);
    if (itemIndex == null || changeSetId.isEmpty) return null;
    return (changeSetId: changeSetId, itemIndex: itemIndex);
  }
}
