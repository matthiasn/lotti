import 'dart:convert';
import 'dart:developer' as developer;

import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';

/// Settings key written by the 0.9.1067/0.9.1068 seed-tombstone ledger.
const legacySeedTombstonesSettingsKey = 'ai_deleted_seed_identities';

const _logTag = 'SeedTombstoneMigration';

const _profilePrefix = 'profile:';
const _modelPrefix = 'model:';

/// One-shot conversion of the old settings-row tombstone ledger into
/// soft-deleted config rows.
///
/// Those releases recorded a deleted bundled profile or model as an identity
/// string in a settings row and **hard-deleted** the config, so on upgrade the
/// row is simply absent — indistinguishable from "never seeded". Without this
/// pass the first startup after upgrading recreates every seed the user had
/// deleted, which is the exact bug the ledger existed to prevent.
///
/// Each legacy identity becomes a row stamped with `deletedAt`, reconstructed
/// from the bundled template (profiles) or the known-models catalog (models),
/// so the seeding passes see "deleted" rather than "missing". The identity is
/// then durable and syncs like any other config.
///
/// Runs before seeding, and clears the settings key once converted so it never
/// runs twice. An identity that cannot be reconstructed — a catalog entry that
/// no longer exists — is dropped rather than blocking the rest.
class SeedTombstoneMigration {
  const SeedTombstoneMigration({
    required AiConfigRepository aiConfigRepository,
    required this._settingsDb,
  }) : _repo = aiConfigRepository;

  final AiConfigRepository _repo;
  final SettingsDb _settingsDb;

  Future<void> migrate() async {
    final identities = await _legacyIdentities();
    if (identities.isEmpty) return;

    var converted = 0;
    for (final identity in identities) {
      if (await _convert(identity)) converted++;
    }

    // Clear unconditionally: identities that could not be reconstructed will
    // not become reconstructible later, and leaving the key set would re-run
    // this pass on every launch.
    await _settingsDb.removeSettingsItem(legacySeedTombstonesSettingsKey);
    developer.log(
      'Converted $converted of ${identities.length} legacy seed tombstones',
      name: _logTag,
    );
  }

  Future<Set<String>> _legacyIdentities() async {
    final raw = await _settingsDb.itemByKey(legacySeedTombstonesSettingsKey);
    if (raw == null || raw.isEmpty) return const <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>{};
      return decoded.whereType<String>().toSet();
    } on FormatException {
      return const <String>{};
    }
  }

  /// Returns whether [identity] produced a tombstone row.
  Future<bool> _convert(String identity) async {
    if (identity.startsWith(_profilePrefix)) {
      return _convertProfile(identity.substring(_profilePrefix.length));
    }
    if (identity.startsWith(_modelPrefix)) {
      final rest = identity.substring(_modelPrefix.length);
      final separator = rest.indexOf(':');
      if (separator <= 0) return false;
      return _convertModel(
        inferenceProviderId: rest.substring(0, separator),
        providerModelId: rest.substring(separator + 1),
      );
    }
    return false;
  }

  Future<bool> _convertProfile(String profileId) async {
    final existing = await _repo.getConfigById(profileId, includeDeleted: true);
    if (existing != null) {
      // The row came back (a re-seed the ledger failed to prevent, or a sync
      // from a peer). Stamp it rather than writing a second one.
      if (existing.deletedAt != null) return false;
      await _repo.deleteConfig(existing.id);
      return true;
    }

    final template = ProfileSeedingService.defaultProfiles
        .where((profile) => profile.id == profileId)
        .firstOrNull;
    if (template == null) return false;

    await _repo.saveConfig(template.copyWith(deletedAt: DateTime.now()));
    return true;
  }

  Future<bool> _convertModel({
    required String inferenceProviderId,
    required String providerModelId,
  }) async {
    final existing = await _repo.getConfigsByType(
      AiConfigType.model,
      includeDeleted: true,
    );
    // Every match, not just the first: FTUE writes UUID row ids while backfill
    // writes deterministic ones, so sync can leave two live rows for the same
    // provider and provider-native model. Tombstoning one and clearing the
    // ledger entry would leave the duplicate visible and syncing, losing the
    // user's deletion.
    final rows = existing
        .whereType<AiConfigModel>()
        .where(
          (model) =>
              model.inferenceProviderId == inferenceProviderId &&
              model.providerModelId == providerModelId,
        )
        .toList(growable: false);
    if (rows.isNotEmpty) {
      var stamped = false;
      for (final row in rows.where((row) => row.deletedAt == null)) {
        await _repo.deleteConfig(row.id);
        stamped = true;
      }
      return stamped;
    }

    final provider = await _repo.getConfigById(inferenceProviderId);
    if (provider is! AiConfigInferenceProvider) return false;
    final known = knownModelsByProvider[provider.inferenceProviderType]
        ?.where((model) => model.providerModelId == providerModelId)
        .firstOrNull;
    if (known == null) return false;

    await _repo.saveConfig(
      known
          .toAiConfigModel(
            id: generateModelId(inferenceProviderId, providerModelId),
            inferenceProviderId: inferenceProviderId,
          )
          .copyWith(deletedAt: DateTime.now()),
    );
    return true;
  }
}
