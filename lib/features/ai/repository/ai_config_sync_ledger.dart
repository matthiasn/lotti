import 'dart:convert';

import 'package:lotti/database/settings_db.dart';

/// The ids of AI configurations whose latest write this device still owes
/// its peers.
///
/// A config write commits before its message reaches the outbox, and the
/// outbox's ordinary `enqueueMessage` swallows its own failures, so without a
/// record the write is already durable here while no peer will ever hear of
/// it. A hard deletion is the worst case: its row is gone, so not even
/// "Send settings", which re-sends every stored row, could repair it. The
/// ledger closes that gap the way saved task filters close theirs: an id is
/// owed *before* its message is staged and settled only once the outbox has
/// accepted the row, so a failed enqueue, or a crash in between, leaves the
/// id owed for the next flush. What is sent for an owed id is derived from
/// the repository's current state at flush time — the stored row with its
/// stamp, or the hard deletion the stamp alone records — never from the
/// message that failed, so a later write supersedes an older owed one.
///
/// Stored as one `SettingsDb` key holding a JSON list of ids. An unreadable
/// value reads as empty: the cost is a change that is not resent until its
/// next write, which "Send settings" repairs.
class AiConfigSyncLedger {
  AiConfigSyncLedger(this._settingsDb);

  /// Storage key of the owed ids.
  static const storageKey = 'AI_CONFIG_SYNC_LEDGER';

  final SettingsDb _settingsDb;

  /// The ids still owed, in no particular order.
  Future<Set<String>> load() async {
    final raw = await _settingsDb.itemByKey(storageKey);
    if (raw == null) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().toSet();
    } on FormatException {
      return <String>{};
    }
  }

  /// Records that [id]'s latest write has not reached the outbox yet.
  Future<void> owe(String id) async {
    final pending = await load();
    if (pending.add(id)) await _save(pending);
  }

  /// Records that the outbox accepted [id]'s latest write.
  Future<void> settle(String id) async {
    final pending = await load();
    if (pending.remove(id)) await _save(pending);
  }

  Future<void> _save(Set<String> pending) => _settingsDb.saveSettingsItem(
    storageKey,
    jsonEncode(pending.toList()..sort()),
  );
}
