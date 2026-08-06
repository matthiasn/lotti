import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/demo/seed/demo_seeder.dart';
import 'package:lotti/features/demo/seed/demo_tutorial_content.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

/// Recursive snapshot of a directory: relative path -> file length.
Map<String, int> snapshotTree(Directory dir) {
  final result = <String, int>{};
  if (!dir.existsSync()) return result;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File) {
      result[p.relative(entity.path, from: dir.path)] = entity.lengthSync();
    }
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final seedTime = DateTime(2026, 8, 1, 9, 15);

  late Directory worldRoot;
  late Directory canaryRealRoot;
  late WorldHandle world;

  setUp(() {
    worldRoot = Directory.systemTemp.createTempSync('lotti_demo_seed_');
    canaryRealRoot = Directory.systemTemp.createTempSync('lotti_canary_');
    // Plant canary content so "untouched" is a meaningful assertion.
    File(p.join(canaryRealRoot.path, 'db.sqlite')).writeAsStringSync('real');
    Directory(
      p.join(canaryRealRoot.path, 'text_entries'),
    ).createSync(recursive: true);

    // The ACTIVE generation points at the canary; any seeder write that
    // falls back to the active root or the OS path is an isolation breach.
    getIt
      ..registerSingleton<Directory>(canaryRealRoot)
      ..registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'forbidden');
          },
        );
    world = WorldHandle.open(worldRoot);
  });

  tearDown(() async {
    await world.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await getIt.reset();
    for (final dir in [worldRoot, canaryRealRoot]) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  DemoSeeder seeder() => DemoSeeder(
    world: world,
    clock: () => seedTime,
  );

  // The tutorial's own entities — the only demo-only content, deliberately
  // spelled out so a change there is visible in the diff. Everything else is
  // derived from the shared penguin world.
  final expectedTutorialIds = {
    demoTutorialCheckItemId,
    demoTutorialTimerItemId,
    demoTutorialAddItemItemId,
    demoTutorialCreateTaskItemId,
    demoTutorialVoiceNoteItemId,
    demoTutorialChecklistId,
    demoTutorialTaskId,
    for (final asset in demoMediaForTask(demoTutorialTaskId)) asset.id,
  };

  const expectedDefinitionIds = {
    manualDemoCategoryId,
    demoHabitatCategoryId,
    demoLogisticsCategoryId,
    manualDemoProjectLabelId,
    manualDemoCriticalLabelId,
    demoBlockedLabelId,
    demoWaitingLabelId,
    demoResearchLabelId,
    manualRollCallHabitId,
    manualHabitatSealsHabitId,
    manualSardineForecastHabitId,
    demoColdChainTelemetryHabitId,
    demoOutboundManifestHabitId,
    demoShiftHandoffHabitId,
    demoFlipperMobilityHabitId,
  };

  const expectedAiConfigIds = {
    manualMissionControlProviderId,
    manualHabitatLabProviderId,
    manualOrbitalVisionProviderId,
    manualAudioBayProviderId,
    manualWaddleCommandModelId,
    manualEmperorReasoningModelId,
    manualSardineLogisticsModelId,
    manualHabitatVisionModelId,
    manualPenguinBriefingsModelId,
    manualCoverArtistModelId,
    manualProjectWaddleProfileId,
    manualHabitatLocalProfileId,
    manualFishDiplomacyProfileId,
    manualHabitatBriefingSkillId,
    manualHabitatPhotoSkillId,
    manualWaddleCoverArtSkillId,
    manualLaunchPromptSkillId,
  };

  group('DemoSeeder', () {
    test('seeds the complete penguin world into the demo databases and '
        'leaves the active world untouched', () async {
      final before = snapshotTree(canaryRealRoot);

      final manifest = await seeder().seed(locale: const Locale('en'));

      // Category and labels.
      final category = await world.journalDb.getCategoryById(
        manualDemoCategoryId,
      );
      expect(category?.name, 'Penguin Operations');
      expect(
        (await world.journalDb.getLabelDefinitionById(
          manualDemoProjectLabelId,
        ))?.name,
        'Project Waddle',
      );
      expect(
        (await world.journalDb.getLabelDefinitionById(
          manualDemoCriticalLabelId,
        ))?.name,
        'Habitat critical',
      );

      // Every AI config is retrievable from the demo AiConfigDb.
      for (final id in expectedAiConfigIds) {
        expect(
          await world.aiConfigDb.getConfigById(id),
          isNotNull,
          reason: 'AI config $id missing',
        );
      }

      // The full journal graph landed, with the right entity kinds.
      final entities = <JournalEntity>[];
      for (final id in manifest.seededJournalIds) {
        final entity = await world.journalDb.journalEntityById(id);
        expect(entity, isNotNull, reason: 'journal entity $id missing');
        entities.add(entity!);
      }
      expect(entities.whereType<JournalImage>(), hasLength(91));
      // 28 penguin-world tasks + the tutorial's "Your first mission".
      expect(entities.whereType<Task>(), hasLength(29));
      expect(entities.whereType<Checklist>(), hasLength(8));
      expect(entities.whereType<ChecklistItem>(), hasLength(33));
      // 11 logged-time records + 21 observations.
      expect(entities.whereType<JournalEntry>(), hasLength(32));

      // The three categories all landed, so tasks in the new areas resolve
      // a category (and a colour) rather than rendering uncategorized.
      for (final id in [demoHabitatCategoryId, demoLogisticsCategoryId]) {
        expect(
          await world.journalDb.getCategoryById(id),
          isNotNull,
          reason: 'category $id missing',
        );
      }

      // Dates were rebased onto the seed clock.
      final heroTask = entities.whereType<Task>().singleWhere(
        (task) => task.meta.id == manualOrbitalHabitatTaskId,
      );
      expect(heroTask.meta.dateFrom, seedTime);
      expect(heroTask.data.title, 'Inspect orbital penguin habitat');

      final tutorialTask = entities.whereType<Task>().singleWhere(
        (task) => task.meta.id == demoTutorialTaskId,
      );
      expect(tutorialTask.data.title, 'Your first mission');
      expect(tutorialTask.data.checklistIds, [demoTutorialChecklistId]);

      // Seeding writes only local image metadata. Missing R2 bytes are
      // reconciled after bootstrap and can never delay or fail this seed.
      for (final image in entities.whereType<JournalImage>()) {
        final mediaFile = File(
          getFullImagePath(image, documentsDirectory: worldRoot.path),
        );
        expect(
          mediaFile.existsSync(),
          isFalse,
          reason: 'seeding unexpectedly installed media for ${image.meta.id}',
        );
      }

      // The hero task is linked to its time record.
      final links = await world.journalDb.linksForEntryIds({
        manualHabitatTimeRecordId,
      });
      expect(links, hasLength(1));
      expect(links.single.fromId, manualOrbitalHabitatTaskId);
      expect(links.single.toId, manualHabitatTimeRecordId);

      // The whole link web landed, and every stored link resolves to two
      // entities that are actually in the database — the graph explorer
      // walks these rows, so a dangling endpoint would be a hole in it.
      final fixture = ManualDemoWorld.penguinLogistics(now: seedTime);
      final storedLinks = await world.journalDb.linksForEntryIdsBidirectional(
        {for (final link in fixture.links) link.fromId},
      );
      expect(storedLinks.length, greaterThanOrEqualTo(fixture.links.length));
      final seededIds = manifest.seededJournalIds.toSet();
      for (final link in fixture.links) {
        expect(
          seededIds,
          containsAll([link.fromId, link.toId]),
          reason: '${link.id} points outside the seeded world',
        );
      }
      // The hero task's own neighbourhood is worth opening the graph for.
      final heroLinks = await world.journalDb.linksForEntryIdsBidirectional({
        manualOrbitalHabitatTaskId,
      });
      expect(heroLinks.length, greaterThanOrEqualTo(8));
      final tutorialLinks = await world.journalDb.linksForEntryIdsBidirectional(
        {demoTutorialTaskId},
      );
      expect(tutorialLinks, hasLength(3));
      expect(
        tutorialLinks.map((link) => link.toId).toSet(),
        demoMediaForTask(demoTutorialTaskId).map((asset) => asset.id).toSet(),
      );
      expect(
        manifest.seededLinkIds,
        containsAll([
          ...fixture.links.map((link) => link.id),
          ...tutorialLinks.map((link) => link.id),
        ]),
      );

      // Config flags: demo experience on top of the seeded defaults.
      expect(
        await world.journalDb.getConfigFlag(enableDailyOsPageFlag),
        isTrue,
      );
      expect(await world.journalDb.getConfigFlag(enableTooltipFlag), isTrue);
      // On, because the world seeds habits with completion history — the
      // page would otherwise hide data the seed just wrote.
      expect(
        await world.journalDb.getConfigFlag(enableHabitsPageFlag),
        isTrue,
      );
      for (final flag in [
        enableMatrixFlag,
        enableNotificationsFlag,
        recordLocationFlag,
        enableDashboardsPageFlag,
      ]) {
        expect(
          await world.journalDb.getConfigFlag(flag),
          isFalse,
          reason: '$flag must be off in the demo world',
        );
        expect(
          await world.journalDb.getConfigFlagByName(flag),
          isNotNull,
          reason: '$flag row must exist so the settings UI can list it',
        );
      }

      // FTUE suppression in the demo world's own settings.
      expect(
        await world.settingsDb.itemByKey(onboardingWelcomeCompletedKey),
        'true',
      );

      // Manifest: written to disk, and lists exactly the seeded ids.
      //
      // The manifest is the boundary the exit sheet uses to tell fixture
      // content from the user's own work, so it must list EVERY row the
      // seeder wrote — checked here against the database itself, not
      // against the fixture the manifest was built from.
      final stored = await world.journalDb.getJournalEntities(
        types: const [
          'Task',
          'JournalEntry',
          'JournalImage',
          'JournalAudio',
          'Checklist',
          'ChecklistItem',
          'AiResponseEntry',
          'MeasurementEntry',
          'SurveyEntry',
          'QuantitativeEntry',
          'WorkoutEntry',
          'HabitCompletionEntry',
          'ProjectEntry',
          'RatingEntry',
        ],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: [for (final flag in EntryFlag.values) flag.index],
        ids: null,
        limit: 1000,
      );
      final expectedJournalIds = {
        for (final entity in stored) entity.meta.id,
      };
      expect(
        expectedJournalIds,
        containsAll(expectedTutorialIds),
        reason: 'the tutorial first mission must be part of the seeded world',
      );

      final persisted = await DemoSeedManifest.read(worldRoot);
      expect(persisted, isNotNull);
      expect(persisted!.seedVersion, demoSeedVersion);
      expect(persisted.isCurrentVersion, isTrue);
      expect(persisted.localeTag, 'en');
      expect(persisted.seededAt, seedTime.toUtc());
      expect(persisted.seededJournalIds.toSet(), expectedJournalIds);
      expect(persisted.seededJournalIds, hasLength(expectedJournalIds.length));
      expect(persisted.seededDefinitionIds.toSet(), expectedDefinitionIds);
      expect(
        persisted.seededDefinitionIds,
        hasLength(expectedDefinitionIds.length),
      );
      expect(persisted.seededAiConfigIds.toSet(), expectedAiConfigIds);
      expect(
        persisted.seededAiConfigIds,
        hasLength(expectedAiConfigIds.length),
      );
      expect(manifest.seededJournalIds, persisted.seededJournalIds);
      expect(persisted.seededLinkIds, manifest.seededLinkIds);

      // Isolation: the canary (active) world is byte-identical.
      expect(snapshotTree(canaryRealRoot), before);
    });

    test('seeds localized content for a non-English locale', () async {
      final manifest = await seeder().seed(locale: const Locale('de'));

      expect(manifest.localeTag, 'de');
      final heroTask = await world.journalDb.journalEntityById(
        manualOrbitalHabitatTaskId,
      );
      expect(
        heroTask!.maybeMap(
          task: (Task task) => task.data.title,
          orElse: () => '',
        ),
        'Pinguin-Habitat im Orbit inspizieren',
      );
      final category = await world.journalDb.getCategoryById(
        manualDemoCategoryId,
      );
      expect(category?.name, 'Pinguinbetrieb');
    });

    test('a flag substrate that loses a default fails the seed loudly '
        'instead of shipping a world with wrong flags', () async {
      registerAllFallbackValues();
      final brokenDb = MockJournalDb();
      // initConfigFlags appears to run, but the read-back finds nothing —
      // the shape of a broken settings substrate.
      when(
        () => brokenDb.insertFlagIfNotExists(any()),
      ).thenAnswer((_) async {});
      when(
        () => brokenDb.deleteConfigFlag(any()),
      ).thenAnswer((_) async => true);
      when(
        () => brokenDb.getConfigFlagByName(any()),
      ).thenAnswer((_) async => null);
      final brokenWorld = MockWorldHandle();
      when(() => brokenWorld.root).thenReturn(worldRoot);
      when(() => brokenWorld.journalDb).thenReturn(brokenDb);
      when(
        () => brokenWorld.writeEntityDefinition(any()),
      ).thenAnswer((_) async {});
      when(() => brokenWorld.writeAiConfig(any())).thenAnswer((_) async {});
      when(
        () => brokenWorld.writeJournalEntity(any()),
      ).thenAnswer((_) async {});
      when(() => brokenWorld.writeEntryLink(any())).thenAnswer((_) async {});

      await expectLater(
        DemoSeeder(
          world: brokenWorld,
          clock: () => seedTime,
        ).seed(locale: const Locale('en')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing after initConfigFlags'),
          ),
        ),
      );
    });
  });
}
