import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show AssetBundle;
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/demo/seed/demo_seed_media.dart';
import 'package:lotti/features/demo/seed/demo_seed_progress.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_tutorial_content.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/demo/seed/demo_world_ai.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/utils/consts.dart';

/// Populates a freshly created demo world with the Intergalactic Penguin
/// Logistics content plus the tutorial "first mission".
///
/// Writes exclusively through [world] — never through getIt-resolved
/// services or `PersistenceLogic` — so it is safe to run against a
/// NON-ACTIVE world before the app switches into it. Entities arrive from
/// the fixture with fully formed metadata and `vectorClock: null` (guest
/// worlds have no sync stack).
///
/// FTUE suppression covers everything scoped to the demo world's own
/// `settings.sqlite` (the onboarding welcome gate). The What's New "seen"
/// markers live in SharedPreferences, which is device-global and shared with
/// the real profile, so they are deliberately NOT touched here; the modal
/// stays absent in the demo because the `enable_whats_new` config flag
/// defaults to off in the freshly seeded world.
class DemoSeeder {
  DemoSeeder({
    required this.world,
    required AssetBundle bundle,
    DateTime Function()? clock,
    this.onProgress,
    DemoSeedMediaInstaller? mediaInstaller,
  }) : clock = clock ?? DateTime.now,
       _mediaInstaller =
           mediaInstaller ?? DemoSeedMediaInstaller(bundle: bundle);

  /// Storage handles of the (not yet active) demo world.
  final WorldHandle world;

  /// Source of "now" for the world's semantic dates (due today, overdue by
  /// two days, logged last Tuesday) and for the manifest timestamp. Injected
  /// so tests stay deterministic.
  final DateTime Function() clock;

  final DemoSeedProgressCallback? onProgress;

  final DemoSeedMediaInstaller _mediaInstaller;

  /// Seeds the world in dependency order and returns the manifest that was
  /// written to `<root>/demo_seed_manifest.json`.
  Future<DemoSeedManifest> seed({required Locale locale}) async {
    final now = clock();
    final t = demoSeedTextForLocale(locale);
    final penguinWorld = ManualDemoWorld.penguinLogistics(
      translate: t,
      now: now,
    );
    final tutorial = DemoTutorialContent.build(translate: t, now: now);

    // Categories and labels first: every journal entity references them.
    for (final category in penguinWorld.categories) {
      await world.writeEntityDefinition(category);
    }
    for (final label in penguinWorld.labels) {
      await world.writeEntityDefinition(label);
    }
    // Habits before their completion entries, which are journal entities
    // written in the block below and reference these ids.
    for (final habit in penguinWorld.habits) {
      await world.writeEntityDefinition(habit);
    }

    // AI configs in dependency order: providers → models → profiles →
    // skills.
    final aiConfigs = [
      ...demoAiProviders(t, now),
      ...demoAiModels(t, now),
      ...demoAiProfiles(t, now),
      ...demoAiSkills(t, now),
    ];
    for (final config in aiConfigs) {
      await world.writeAiConfig(config);
    }

    // Media bytes before the image entities that reference them.
    await _mediaInstaller.install(
      documentsDirectory: world.root,
      images: penguinWorld.coverImages,
      sources: manualDemoCoverMedia,
      onProgress: ({required completed, required total}) {
        onProgress?.call(
          DemoSeedProgress.downloadingMedia(
            completed: completed,
            total: total,
          ),
        );
      },
    );
    onProgress?.call(const DemoSeedProgress.writingContent());

    // Journal entities in reference order: images, checklist items, the
    // checklists that list them, the tasks that own those checklists, then
    // the time records and notes. The fixture's checklist and task wiring is
    // already complete in the entity data.
    final journalEntities = [
      ...penguinWorld.journalEntities,
      ...tutorial.journalEntities,
    ];
    for (final entity in journalEntities) {
      await world.writeJournalEntity(entity);
    }

    // Links last: both endpoints must exist before a `linked_entries` row
    // referencing them is written.
    for (final entryLink in penguinWorld.links) {
      await world.writeEntryLink(entryLink);
    }

    await _configureFlags();

    // FTUE suppression: the demo world must open straight onto the seeded
    // content, so the onboarding welcome gate is retired in the demo's own
    // SettingsDb. See the class doc for why What's New is not handled here.
    await world.writeSetting(onboardingWelcomeCompletedKey, 'true');

    final manifest = DemoSeedManifest(
      seedVersion: demoSeedVersion,
      seededAt: now.toUtc(),
      localeTag: locale.toLanguageTag(),
      seededJournalIds: List.unmodifiable([
        for (final entity in journalEntities) entity.meta.id,
      ]),
      seededDefinitionIds: List.unmodifiable([
        for (final category in penguinWorld.categories) category.id,
        for (final label in penguinWorld.labels) label.id,
        for (final habit in penguinWorld.habits) habit.id,
      ]),
      seededAiConfigIds: List.unmodifiable([
        for (final config in aiConfigs) config.id,
      ]),
    );
    await manifest.write(world.root);
    return manifest;
  }

  /// Seeds the default flag rows, then adjusts the demo experience: Daily OS,
  /// tooltips and the habits page on; sync, notifications, geolocation and the
  /// dashboards page off.
  ///
  /// Habits are on because the world seeds three of them with three weeks of
  /// completion history — the page has something to show, and hiding it would
  /// leave that data unreachable.
  Future<void> _configureFlags() async {
    await initConfigFlags(world.journalDb, inMemoryDatabase: false);
    const statuses = <String, bool>{
      enableDailyOsPageFlag: true,
      enableTooltipFlag: true,
      enableMatrixFlag: false,
      enableNotificationsFlag: false,
      recordLocationFlag: false,
      enableHabitsPageFlag: true,
      enableDashboardsPageFlag: false,
    };
    for (final entry in statuses.entries) {
      final existing = await world.journalDb.getConfigFlagByName(entry.key);
      if (existing == null) {
        throw StateError(
          'Config flag ${entry.key} missing after initConfigFlags',
        );
      }
      await world.journalDb.upsertConfigFlag(
        existing.copyWith(status: entry.value),
      );
    }
  }
}
