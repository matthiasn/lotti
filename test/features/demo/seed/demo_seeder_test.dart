import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
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

/// Serves the repo's real asset files from disk, standing in for
/// `rootBundle` (tests run with the repository root as working directory).
class _FileSystemAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

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
    bundle: _FileSystemAssetBundle(),
    clock: () => seedTime,
  );

  const expectedJournalIds = {
    // Cover images.
    manualHabitatCoverImageId,
    manualRollCallCoverImageId,
    manualLaunchReviewCoverImageId,
    manualLunchCoverImageId,
    manualSardineFuturesCoverImageId,
    manualFishFeederCoverImageId,
    manualSardineCargoCoverImageId,
    manualPenguinPassengerCoverImageId,
    manualHeadsetWalkCoverImageId,
    // Habitat checklist graph.
    manualHabitatSealsItemId,
    manualHabitatRollCallItemId,
    manualHabitatCargoItemId,
    manualHabitatClearanceItemId,
    manualHabitatChecklistId,
    // Tasks.
    manualRollCallTaskId,
    manualOrbitalHabitatTaskId,
    manualLaunchReviewTaskId,
    manualLunchTaskId,
    manualSardineFuturesTaskId,
    manualFishFeederTaskId,
    manualSardineCargoTaskId,
    manualPenguinPassengerTaskId,
    manualHeadsetWalkTaskId,
    // Time record.
    manualHabitatTimeRecordId,
    // Tutorial content.
    demoTutorialCheckItemId,
    demoTutorialTimerItemId,
    demoTutorialAddItemItemId,
    demoTutorialCreateTaskItemId,
    demoTutorialVoiceNoteItemId,
    demoTutorialChecklistId,
    demoTutorialTaskId,
  };

  const expectedDefinitionIds = {
    manualDemoCategoryId,
    manualDemoProjectLabelId,
    manualDemoCriticalLabelId,
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
      expect(entities.whereType<JournalImage>(), hasLength(9));
      expect(entities.whereType<Task>(), hasLength(10));
      expect(entities.whereType<Checklist>(), hasLength(2));
      expect(entities.whereType<ChecklistItem>(), hasLength(9));
      expect(entities.whereType<JournalEntry>(), hasLength(1));

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
      expect(tutorialTask.data.checklistIds, const [demoTutorialChecklistId]);

      // Cover-art media bytes were installed from the bundle.
      for (final image in entities.whereType<JournalImage>()) {
        final mediaFile = File(
          getFullImagePath(image, documentsDirectory: worldRoot.path),
        );
        expect(
          mediaFile.existsSync() && mediaFile.lengthSync() > 0,
          isTrue,
          reason: 'media for ${image.meta.id} missing under the world root',
        );
      }

      // The hero task is linked to its time record.
      final links = await world.journalDb.linksForEntryIds({
        manualHabitatTimeRecordId,
      });
      expect(links, hasLength(1));
      expect(links.single.fromId, manualOrbitalHabitatTaskId);
      expect(links.single.toId, manualHabitatTimeRecordId);

      // Config flags: demo experience on top of the seeded defaults.
      expect(
        await world.journalDb.getConfigFlag(enableDailyOsPageFlag),
        isTrue,
      );
      expect(await world.journalDb.getConfigFlag(enableTooltipFlag), isTrue);
      for (final flag in [
        enableMatrixFlag,
        enableNotificationsFlag,
        recordLocationFlag,
        enableHabitsPageFlag,
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
          bundle: _FileSystemAssetBundle(),
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
