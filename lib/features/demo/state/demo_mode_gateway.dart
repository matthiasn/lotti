import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/app_root.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
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
import 'package:lotti/services/domain_logging.dart';

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
  final Future<DemoCopyPlan> Function(
    Set<String> selectedIds,
    Set<String> selectedAiConfigIds,
  )?
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
  /// manifest matches the current [demoSeedVersion]; a stale profile is
  /// wiped and recreated (seeding in [locale]) ONLY when it holds no
  /// demo-created work — a stale world with user work resumes as-is, so an
  /// app upgrade that bumps the seed version can never silently destroy
  /// something the user made. [resetDemo] remains the explicit, confirmed
  /// wipe. No-op while the demo is active.
  Future<void> enterDemo({required Locale locale}) async {
    if (isDemoActive) return;
    final existing = await findDemoProfile();
    if (existing != null) {
      if (await _hasCurrentSeed(existing) || await _hasUserWork(existing)) {
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
  ///
  /// A failure while APPLYING the plan happens after the switch, when the
  /// exit sheet (and everything else in the old generation) is already
  /// gone — so it is logged here and reported through
  /// [DemoCopyFailureNotices], which the new generation's chrome
  /// (`DemoModeScaffold`) turns into a visible error toast. The error still
  /// rethrows for callers/tests.
  Future<int> exitWithCopy({
    required Set<String> selectedIds,
    Set<String> selectedAiConfigIds = const {},
  }) async {
    if (!isDemoActive) {
      throw StateError('exitWithCopy requires the demo world to be active');
    }
    if (selectedIds.isEmpty && selectedAiConfigIds.isEmpty) {
      await exitDemo();
      return 0;
    }
    final plan = await (prepareCopyOverride ?? _defaultPrepareCopy)(
      selectedIds,
      selectedAiConfigIds,
    );
    await exitDemo();
    try {
      return await (applyCopyOverride ?? _defaultApplyCopy)(plan);
    } catch (exception, stackTrace) {
      // getIt already holds the REAL generation's services here.
      if (getIt.isRegistered<DomainLogger>()) {
        getIt<DomainLogger>().error(
          LogDomain.general,
          exception,
          stackTrace: stackTrace,
          subDomain: 'demoExitCopyApply',
        );
      }
      DemoCopyFailureNotices.instance.report();
      rethrow;
    }
  }

  /// Reads the copy plan from the ACTIVE (demo) generation's services.
  Future<DemoCopyPlan> _defaultPrepareCopy(
    Set<String> selectedIds,
    Set<String> selectedAiConfigIds,
  ) => DemoDataCopier().prepare(
    selectedIds: selectedIds,
    selectedAiProviderIds: selectedAiConfigIds,
    sourceDb: getIt<JournalDb>(),
    sourceAiConfigs: getIt<AiConfigRepository>(),
    sourceRoot: getIt<Directory>(),
  );

  /// Applies the plan against the ACTIVE (by now: real) generation.
  Future<int> _defaultApplyCopy(DemoCopyPlan plan) => DemoDataCopier().apply(
    plan,
    persistence: getIt<PersistenceLogic>(),
    targetJournalDb: getIt<JournalDb>(),
    targetRoot: getIt<Directory>(),
    targetAiConfigs: getIt<AiConfigRepository>(),
    targetFts: getIt.isRegistered<Fts5Db>() ? getIt<Fts5Db>() : null,
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

  /// Whether the (non-active) demo world at [profile]'s root contains
  /// demo-created work that a wipe would destroy. Opens the world's storage
  /// through a [WorldHandle] and scans RAW rows against the seed manifest —
  /// deliberately NOT the exit sheet's candidate scan, which drops
  /// non-seeded entries with inbound links (a recording or image the user
  /// attached to a seeded task) and would green-light wiping them:
  ///
  /// - journal: any non-deleted row whose id is not in the manifest;
  /// - AI: any inference provider whose id is not in the manifest (the
  ///   user's connected key). Other config types are not scanned — the app
  ///   auto-seeds prompts/backfilled models/bundled profiles inside the
  ///   demo generation without manifest entries, so a full-type scan would
  ///   read every demo world as user work and no stale world could ever
  ///   reseed.
  ///
  /// A missing/malformed manifest excludes nothing, and an unreadable world
  /// reports `true` — a scan failure can never green-light a deletion.
  Future<bool> _hasUserWork(Profile profile) async {
    WorldHandle? handle;
    try {
      final root = registry.rootFor(profile);
      DemoSeedManifest? manifest;
      try {
        manifest = await DemoSeedManifest.read(root);
      } catch (_) {
        manifest = null;
      }
      final seededJournalIds = {...?manifest?.seededJournalIds};
      final seededAiIds = {...?manifest?.seededAiConfigIds};

      handle = WorldHandle.open(root);
      final journalIds = await handle.journalDb.allNonDeletedJournalEntityIds();
      if (journalIds.any((id) => !seededJournalIds.contains(id))) {
        return true;
      }
      final providers = await AiConfigRepository(
        handle.aiConfigDb,
      ).getConfigsByType(AiConfigType.inferenceProvider);
      return providers.any((config) => !seededAiIds.contains(config.id));
    } catch (_) {
      return true;
    } finally {
      await handle?.close();
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

/// Cross-generation mailbox for demo copy-apply failures.
///
/// [DemoModeGateway.exitWithCopy] applies the plan AFTER the profile switch
/// has replaced the whole widget tree, so the exit sheet that started the
/// copy is gone by the time a failure can happen and no messenger from the
/// old generation survives. This notifier deliberately lives outside getIt
/// (which the switch resets) and outside the tree (which the switch
/// replaces): the gateway reports into it, and the new generation's chrome
/// (`DemoModeScaffold`) subscribes and toasts the failure — draining a
/// report that landed before it mounted via [consume].
class DemoCopyFailureNotices extends ChangeNotifier {
  DemoCopyFailureNotices._();

  static final DemoCopyFailureNotices instance = DemoCopyFailureNotices._();

  bool _pending = false;

  /// Records a copy-apply failure and notifies any mounted listener.
  void report() {
    _pending = true;
    notifyListeners();
  }

  /// One-shot read-and-clear: `true` exactly once per reported failure, so
  /// rebuilds and multiple listeners can never toast the same failure twice.
  bool consume() {
    final pending = _pending;
    _pending = false;
    return pending;
  }

  @visibleForTesting
  void reset() => _pending = false;
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
