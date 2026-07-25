import 'dart:convert';

import 'package:lotti/database/settings_db.dart';

/// Settings key holding the JSON list of seed identities the user has deleted.
const seedTombstonesSettingsKey = 'ai_deleted_seed_identities';

/// Remembers which seeded defaults the user deleted, so the seeding passes
/// stop recreating them.
///
/// Seeding is idempotent by construction — `seedDefaults()` writes a template
/// whenever its row is missing, and `backfillNewModels()` recreates any known
/// model a configured provider lacks. Both run at startup and again after
/// provider writes, so before this store a deleted default came back within
/// the same session. Deletion had no memory; only presence was state.
///
/// **Model identity is provider-scoped, not row-scoped.** Backfill matches on
/// `providerModelId` under a provider, and the row id may be deterministic or
/// a UUID depending on whether it came from FTUE, manual setup, or sync — so a
/// tombstone keyed by row id would miss the recreated row. [modelKey] builds
/// the identity backfill actually compares.
///
/// **Only user-initiated deletions are recorded.** `removeOrphanedDefaultSeeds`
/// prunes untouched seeds whose provider became unusable and *wants* them back
/// when the provider returns, so that path must not write tombstones.
///
/// Tombstones are local rather than synced, but a peer applying a synced
/// delete records its own (deletes arrive through the same repository path).
/// The residual gap is a device that never observes the delete event at all —
/// it may re-seed and sync the row back.
class SeedTombstoneStore {
  const SeedTombstoneStore({required this._settingsDb});

  final SettingsDb _settingsDb;

  /// Identity for a model row, matching how backfill decides a known model is
  /// already configured: provider-native id scoped to its provider.
  static String modelKey({
    required String inferenceProviderId,
    required String providerModelId,
  }) => 'model:$inferenceProviderId:$providerModelId';

  /// Identity for a seeded default profile — its well-known template id.
  static String profileKey(String profileId) => 'profile:$profileId';

  /// Every recorded tombstone. Returns empty when unset or unreadable: a
  /// corrupt value must not block seeding entirely.
  Future<Set<String>> deletedIdentities() async {
    final raw = await _settingsDb.itemByKey(seedTombstonesSettingsKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.whereType<String>().toSet();
    } on FormatException {
      return <String>{};
    }
  }

  /// Serializes the read-modify-write mutations below, per settings database.
  ///
  /// The repository builds a fresh store per deletion and a synced delete can
  /// land while a user delete is in flight, so two mutations would otherwise
  /// read the same prior set and the second write would drop the first's
  /// identity — silently reviving that seed. Every store sharing a database
  /// shares its queue, so each mutation reads a set that already includes its
  /// predecessor.
  ///
  /// Keyed by database rather than held in one static: stores over *different*
  /// databases have nothing to serialize against, and a single global chain
  /// would also leak across tests, where one stalled mutation against a
  /// discarded database would wedge every later write in the isolate.
  static final Expando<Future<void>> _mutationQueues = Expando<Future<void>>();

  /// Runs [mutation] after every mutation already queued for this database.
  Future<void> _serialized(Future<void> Function() mutation) {
    final previous = _mutationQueues[_settingsDb] ?? Future<void>.value();
    final next = previous.then((_) => mutation());
    // The queue must survive a failed mutation, or one error would wedge every
    // later write. Callers still see their own error through [next].
    _mutationQueues[_settingsDb] = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  /// Records [identity] so the seeding passes skip it from now on.
  Future<void> remember(String identity) {
    return _serialized(() async {
      final current = await deletedIdentities();
      if (!current.add(identity)) return;
      await _write(current);
    });
  }

  /// Drops [identity], so the next seeding pass may recreate it. Used when the
  /// user deliberately re-creates something they had deleted.
  Future<void> forget(String identity) {
    return _serialized(() async {
      final current = await deletedIdentities();
      if (!current.remove(identity)) return;
      await _write(current);
    });
  }

  Future<void> _write(Set<String> identities) {
    // Sorted so the persisted value is stable across writes, which keeps the
    // settings row from churning on set-order alone.
    final ordered = identities.toList()..sort();
    return _settingsDb.saveSettingsItem(
      seedTombstonesSettingsKey,
      jsonEncode(ordered),
    );
  }
}
