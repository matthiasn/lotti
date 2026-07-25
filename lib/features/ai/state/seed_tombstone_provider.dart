import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/util/seed_tombstone_store.dart';
import 'package:lotti/get_it.dart';

/// The ledger of seeded profiles and models the user has deleted.
///
/// Exposed as a provider so surfaces that need to *clear* a tombstone — the
/// onboarding key step, which revives the bundled profile for the provider
/// being set up — can reach it without touching `getIt` directly, and so tests
/// can substitute a store backed by an in-memory settings database.
///
/// The repository writes tombstones through its own instance during deletion;
/// that path has no `ref` and stays on `getIt`.
final Provider<SeedTombstoneStore> seedTombstoneStoreProvider =
    Provider<SeedTombstoneStore>(
      (ref) => SeedTombstoneStore(settingsDb: getIt<SettingsDb>()),
      name: 'seedTombstoneStoreProvider',
    );
