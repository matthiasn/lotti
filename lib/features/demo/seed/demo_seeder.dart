import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show AssetBundle;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_tutorial_content.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/demo/seed/demo_world_ai.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/utils/consts.dart';

/// Id of the link that attaches the habitat time record to the hero task.
const demoHabitatTimeLinkId = 'manual-habitat-time-link';

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
    required this.bundle,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// Storage handles of the (not yet active) demo world.
  final WorldHandle world;

  /// Asset bundle carrying the nine cover-art webp files (production passes
  /// `rootBundle`).
  final AssetBundle bundle;

  /// Source of "now" for anchor-relative date rebasing and the manifest
  /// timestamp. Injected so tests stay deterministic.
  final DateTime Function() clock;

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

    // Category and labels first: every journal entity references them.
    await world.writeEntityDefinition(penguinWorld.category);
    for (final label in penguinWorld.labels) {
      await world.writeEntityDefinition(label);
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
    await penguinWorld.installMediaFromBundle(bundle, world.root);

    // Journal entities in reference order: images, checklist items, the
    // checklist that lists them, the tasks that own the checklist, then the
    // time record and its link to the hero task. The fixture's checklist and
    // task wiring is already complete in the entity data.
    final journalEntities = [
      ...penguinWorld.coverImages,
      ...penguinWorld.checklistItems,
      ...penguinWorld.checklists,
      ...penguinWorld.tasks,
      ...penguinWorld.timeRecords,
      ...tutorial.journalEntities,
    ];
    for (final entity in journalEntities) {
      await world.writeJournalEntity(entity);
    }

    await world.writeEntryLink(
      EntryLink.basic(
        id: demoHabitatTimeLinkId,
        fromId: manualOrbitalHabitatTaskId,
        toId: manualHabitatTimeRecordId,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );

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
        penguinWorld.category.id,
        for (final label in penguinWorld.labels) label.id,
      ]),
      seededAiConfigIds: List.unmodifiable([
        for (final config in aiConfigs) config.id,
      ]),
    );
    await manifest.write(world.root);
    return manifest;
  }

  /// Seeds the default flag rows, then adjusts the demo experience: Daily OS
  /// and tooltips on; sync, notifications, geolocation, and the legacy
  /// habits/dashboards pages off.
  Future<void> _configureFlags() async {
    await initConfigFlags(world.journalDb, inMemoryDatabase: false);
    const statuses = <String, bool>{
      enableDailyOsPageFlag: true,
      enableTooltipFlag: true,
      enableMatrixFlag: false,
      enableNotificationsFlag: false,
      recordLocationFlag: false,
      enableHabitsPageFlag: false,
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
