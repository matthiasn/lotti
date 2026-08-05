import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/app_root.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/demo/copy/demo_data_copier.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/demo/seed/demo_seeder.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/demo_world_creator.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// Seeds a freshly created demo world. Injectable so gateway tests can
/// exercise the enter/reset decision logic without running the full seeder.
typedef DemoSeedRunner =
    Future<void> Function(WorldHandle world, Locale locale);

/// The UI-facing entry/exit surface for demo mode.
///
/// Deliberately NOT registered in getIt: getIt is reset on every profile
/// switch while the gateway spans the switch (it drives it). It is built on
/// demand in the UI layer from the [ProfileSwitcherScope] — see
/// [demoModeGatewayOf] — because the `ProfileSwitcher` lives above the
/// ProviderScope and survives generation rebuilds.
class DemoModeGateway {
  DemoModeGateway({
    required this.registry,
    required this.activate,
    AssetBundle? bundle,
    DateTime Function()? clock,
    @visibleForTesting ProfileContext? Function()? profileContext,
    @visibleForTesting DemoSeedRunner? seedRunner,
    @visibleForTesting this.prepareCopyOverride,
    @visibleForTesting this.applyCopyOverride,
  }) : _bundle = bundle ?? rootBundle,
       _clock = clock ?? DateTime.now,
       _profileContext = profileContext ?? _activeProfileContext {
    _seedRunner = seedRunner ?? _defaultSeedRunner;
  }

  /// Display name identifying THE demo profile among guest profiles
  /// (single-demo v1; the registry itself supports N guests).
  static const String demoProfileName = 'Demo';

  /// Registry at the real root; survives profile switches.
  final ProfileRegistry registry;

  /// Switches the running app to a profile id — in production this is
  /// `ProfileSwitcher.switchTo`.
  final Future<void> Function(String profileId) activate;

  final AssetBundle _bundle;
  final DateTime Function() _clock;
  final ProfileContext? Function() _profileContext;
  late final DemoSeedRunner _seedRunner;

  /// Test seam replacing the read of the demo side in [exitWithCopy].
  @visibleForTesting
  final Future<DemoCopyPlan> Function(Set<String> selectedIds)?
  prepareCopyOverride;

  /// Test seam replacing the write into the real side in [exitWithCopy].
  @visibleForTesting
  final Future<int> Function(DemoCopyPlan plan)? applyCopyOverride;

  static ProfileContext? _activeProfileContext() =>
      getIt.isRegistered<ProfileContext>() ? getIt<ProfileContext>() : null;

  Future<void> _defaultSeedRunner(WorldHandle world, Locale locale) =>
      DemoSeeder(
        world: world,
        bundle: _bundle,
        clock: _clock,
      ).seed(locale: locale);

  /// Whether the running generation is the demo (guest) world.
  bool get isDemoActive => _profileContext()?.isGuest ?? false;

  /// The demo profile's registry entry, or null when none exists.
  Future<Profile?> findDemoProfile() async {
    final state = await registry.load();
    for (final profile in state.profiles) {
      if (profile.isGuest && profile.name == demoProfileName) {
        return profile;
      }
    }
    return null;
  }

  Future<bool> demoProfileExists() async => await findDemoProfile() != null;

  /// Enters the demo world: resumes the existing profile when its seed
  /// manifest matches the current [demoSeedVersion], otherwise wipes and
  /// recreates it, seeding in [locale]. No-op while the demo is active.
  Future<void> enterDemo({required Locale locale}) async {
    if (isDemoActive) return;
    final existing = await findDemoProfile();
    if (existing != null) {
      if (await _hasCurrentSeed(existing)) {
        await activate(existing.id);
        return;
      }
      await registry.deleteGuestProfile(existing.id);
    }
    await _createAndEnter(locale);
  }

  /// Switches back to the real world. The demo profile is KEPT (resumable);
  /// deletion is a separate, explicit action.
  Future<void> exitDemo() => activate(Profile.realProfileId);

  /// Wipes and reseeds the demo world, then enters it. When called while the
  /// demo is active it exits to the real world first so the demo databases
  /// are closed before their directory is deleted.
  Future<void> resetDemo({required Locale locale}) async {
    if (isDemoActive) {
      await exitDemo();
    }
    final existing = await findDemoProfile();
    if (existing != null) {
      await registry.deleteGuestProfile(existing.id);
    }
    await _createAndEnter(locale);
  }

  /// Deletes the demo profile and its directory tree. Only legal while the
  /// real world is active — the registry refuses to delete the active
  /// profile, and the demo's databases must not be open during deletion.
  Future<void> deleteDemo() async {
    if (isDemoActive) {
      throw StateError('cannot delete the demo world while it is active');
    }
    final existing = await findDemoProfile();
    if (existing != null) {
      await registry.deleteGuestProfile(existing.id);
    }
  }

  /// Exits the demo, carrying the selected demo-created work over into the
  /// real world.
  ///
  /// Three phases, in this order:
  /// 1. While the DEMO generation is still active, the copier reads the full
  ///    closure into memory (ids remapped, media staged to a temp dir).
  /// 2. [exitDemo] switches the app to the real world.
  /// 3. In the REAL generation the plan is applied through the production
  ///    persistence path (`PersistenceLogic.createDbEntity`/`createLink`), so
  ///    the copies get fresh real-world vector clocks and sync enqueueing —
  ///    a direct WorldHandle write could not enqueue sync, and entities with
  ///    a null vector clock would never replicate.
  ///
  /// Returns the number of copied entities. Note this count cannot be
  /// toasted to the user: the generation switch replaces the whole widget
  /// tree mid-flow, so the exit sheet surfaces progress before the switch
  /// and the count is returned for logging/tests only.
  Future<int> exitWithCopy({required Set<String> selectedIds}) async {
    if (!isDemoActive) {
      throw StateError('exitWithCopy requires the demo world to be active');
    }
    if (selectedIds.isEmpty) {
      await exitDemo();
      return 0;
    }
    final plan = await (prepareCopyOverride ?? _defaultPrepareCopy)(
      selectedIds,
    );
    await exitDemo();
    return (applyCopyOverride ?? _defaultApplyCopy)(plan);
  }

  /// Reads the copy plan from the ACTIVE (demo) generation's services.
  Future<DemoCopyPlan> _defaultPrepareCopy(Set<String> selectedIds) =>
      DemoDataCopier().prepare(
        selectedIds: selectedIds,
        sourceDb: getIt<JournalDb>(),
        sourceRoot: getIt<Directory>(),
      );

  /// Applies the plan against the ACTIVE (by now: real) generation.
  Future<int> _defaultApplyCopy(DemoCopyPlan plan) => DemoDataCopier().apply(
    plan,
    persistence: getIt<PersistenceLogic>(),
    targetJournalDb: getIt<JournalDb>(),
    targetRoot: getIt<Directory>(),
  );

  /// Whether [profile]'s world was seeded by the current seed content. A
  /// missing or malformed manifest reads as stale (wipe and reseed).
  Future<bool> _hasCurrentSeed(Profile profile) async {
    try {
      final manifest = await DemoSeedManifest.read(registry.rootFor(profile));
      return manifest?.isCurrentVersion ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _createAndEnter(Locale locale) async {
    await DemoWorldCreator(
      registry: registry,
      activate: activate,
    ).createAndActivate(
      name: demoProfileName,
      seed: (world) => _seedRunner(world, locale),
    );
  }
}

/// Builds a gateway from the ambient [ProfileSwitcherScope]. Throws (via the
/// scope's assert) outside a scope; use [maybeDemoModeGatewayOf] where a
/// missing scope is a legal state (bare widget tests).
DemoModeGateway demoModeGatewayOf(BuildContext context) {
  final switcher = ProfileSwitcherScope.of(context);
  return DemoModeGateway(
    registry: switcher.registry,
    activate: switcher.switchTo,
  );
}

/// Like [demoModeGatewayOf], but null when no [ProfileSwitcherScope] is
/// mounted above [context].
DemoModeGateway? maybeDemoModeGatewayOf(BuildContext context) {
  final switcher = ProfileSwitcherScope.maybeOf(context);
  if (switcher == null) return null;
  return DemoModeGateway(
    registry: switcher.registry,
    activate: switcher.switchTo,
  );
}

/// Whether the journal is truly empty (zero rows, including deleted) — the
/// gate that distinguishes "nothing exists yet" from a filter with no
/// matches for the tasks empty-state demo CTA.
final demoJournalEmptyProvider = FutureProvider<bool>((ref) async {
  if (!getIt.isRegistered<JournalDb>()) return false;
  final count = await getIt<JournalDb>().countAllJournalEntries();
  return count == 0;
});
