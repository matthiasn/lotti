import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_root.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/copy/demo_data_copier.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/world_handle.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerAllFallbackValues);
  late Directory realRoot;
  late ProfileRegistry registry;
  late List<String> activated;
  late List<String> seededLocales;
  ProfileContext? activeContext;

  DemoModeGateway buildGateway({
    Future<DemoCopyPlan> Function(Set<String>, Set<String>)? prepareCopy,
    Future<int> Function(DemoCopyPlan)? applyCopy,
  }) {
    return DemoModeGateway(
      registry: registry,
      activate: (id) async => activated.add(id),
      profileContext: () => activeContext,
      seedRunner: (world, locale) async {
        seededLocales.add(locale.toLanguageTag());
        // Minimal marker write proving the seed ran against THIS world; the
        // manifest is what enterDemo consults on the next entry.
        await DemoSeedManifest(
          seedVersion: demoSeedVersion,
          seededAt: DateTime.utc(2026, 8, 5),
          localeTag: locale.toLanguageTag(),
          seededJournalIds: const [],
          seededDefinitionIds: const [],
          seededAiConfigIds: const [],
        ).write(world.root);
      },
      prepareCopyOverride: prepareCopy,
      applyCopyOverride: applyCopy,
    );
  }

  ProfileContext guestContext(Profile profile) => ProfileContext.forProfile(
    profile: profile,
    root: registry.rootFor(profile),
  );

  setUp(() {
    realRoot = Directory.systemTemp.createTempSync('lotti_gateway_');
    registry = ProfileRegistry(realRoot: realRoot);
    activated = [];
    seededLocales = [];
    activeContext = null;
  });

  tearDown(() async {
    if (realRoot.existsSync()) {
      await realRoot.delete(recursive: true);
    }
  });

  group('enterDemo', () {
    test('first entry creates the Demo guest profile, seeds it in the given '
        'locale, and activates it', () async {
      final gateway = buildGateway();
      expect(await gateway.demoProfileExists(), isFalse);

      await gateway.enterDemo(locale: const Locale('de'));

      final profile = await gateway.findDemoProfile();
      expect(profile, isNotNull);
      expect(profile!.name, DemoModeGateway.demoProfileName);
      expect(profile.isGuest, isTrue);
      expect(seededLocales, ['de']);
      expect(activated, [profile.id]);
      // The seed ran against the new profile's own root.
      final manifest = await DemoSeedManifest.read(registry.rootFor(profile));
      expect(manifest?.localeTag, 'de');
    });

    test(
      're-entry with a current manifest resumes WITHOUT reseeding',
      () async {
        final gateway = buildGateway();
        await gateway.enterDemo(locale: const Locale('en'));
        final first = (await gateway.findDemoProfile())!;
        activated.clear();
        seededLocales.clear();

        await gateway.enterDemo(locale: const Locale('en'));

        expect(seededLocales, isEmpty, reason: 'must resume, not reseed');
        expect(activated, [first.id]);
        expect((await gateway.findDemoProfile())!.id, first.id);
      },
    );

    test('a stale manifest wipes and recreates the demo profile', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      final first = (await gateway.findDemoProfile())!;
      // Rewrite the manifest as if seeded by an older app version.
      await DemoSeedManifest(
        seedVersion: demoSeedVersion - 1,
        seededAt: DateTime.utc(2026),
        localeTag: 'en',
        seededJournalIds: const [],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(registry.rootFor(first));
      activated.clear();
      seededLocales.clear();

      await gateway.enterDemo(locale: const Locale('fr'));

      final second = (await gateway.findDemoProfile())!;
      expect(second.id, isNot(first.id));
      expect(seededLocales, ['fr']);
      expect(activated, [second.id]);
      expect(registry.rootFor(first).existsSync(), isFalse);
    });

    test('a stale manifest with demo-created work resumes instead of wiping '
        '— an app upgrade must never silently destroy user work', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      final first = (await gateway.findDemoProfile())!;
      final root = registry.rootFor(first);
      // Seeded by an older app version...
      await DemoSeedManifest(
        seedVersion: demoSeedVersion - 1,
        seededAt: DateTime.utc(2026),
        localeTag: 'en',
        seededJournalIds: const ['seeded-task'],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(root);
      // ...and holding work the user created there since.
      final work = WorldHandle.open(root);
      await work.writeJournalEntity(
        TestTaskFactory.create(id: 'user-task', title: 'My own mission'),
      );
      await work.close();
      activated.clear();
      seededLocales.clear();

      await gateway.enterDemo(locale: const Locale('fr'));

      expect(seededLocales, isEmpty, reason: 'must resume, never reseed');
      expect(activated, [first.id]);
      expect((await gateway.findDemoProfile())!.id, first.id);
      expect(root.existsSync(), isTrue);
    });

    test('a stale manifest whose only user work is ATTACHED to a seeded task '
        '(inbound link) still resumes — the reseed guard must scan raw rows, '
        'not copy-offer roots', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      final first = (await gateway.findDemoProfile())!;
      final root = registry.rootFor(first);
      await DemoSeedManifest(
        seedVersion: demoSeedVersion - 1,
        seededAt: DateTime.utc(2026),
        localeTag: 'en',
        seededJournalIds: const ['seeded-task'],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(root);
      final work = WorldHandle.open(root);
      await work.writeJournalEntity(
        TestTaskFactory.create(id: 'seeded-task', title: 'Seeded mission'),
      );
      // The user's only creation: a note linked UNDER the seeded task. The
      // exit sheet's candidate scan drops it (inbound link), so a guard
      // built on that scan would wipe it.
      await work.writeJournalEntity(
        JournalEntry(
          meta: TestMetadataFactory.create(id: 'attached-note'),
          entryText: const EntryText(plainText: 'My recording notes'),
        ),
      );
      await work.writeEntryLink(
        EntryLink.basic(
          id: 'link-attached',
          fromId: 'seeded-task',
          toId: 'attached-note',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          vectorClock: null,
        ),
      );
      await work.close();
      activated.clear();
      seededLocales.clear();

      await gateway.enterDemo(locale: const Locale('en'));

      expect(
        seededLocales,
        isEmpty,
        reason: 'the attached note is user work — never reseed over it',
      );
      expect(activated, [first.id]);
      expect(root.existsSync(), isTrue);
    });

    test('a stale manifest with only a user-connected AI provider (their '
        'API key) also resumes instead of wiping', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      final first = (await gateway.findDemoProfile())!;
      final root = registry.rootFor(first);
      await DemoSeedManifest(
        seedVersion: demoSeedVersion - 1,
        seededAt: DateTime.utc(2026),
        localeTag: 'en',
        seededJournalIds: const [],
        seededDefinitionIds: const [],
        seededAiConfigIds: const ['fixture-provider'],
      ).write(root);
      final work = WorldHandle.open(root);
      await work.writeAiConfig(
        AiConfig.inferenceProvider(
          id: 'user-provider',
          baseUrl: 'https://example.test',
          apiKey: 'real-key',
          name: 'My real provider',
          createdAt: DateTime.utc(2026),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
      );
      await work.close();
      activated.clear();
      seededLocales.clear();

      await gateway.enterDemo(locale: const Locale('en'));

      expect(seededLocales, isEmpty);
      expect(activated, [first.id]);
    });

    test(
      'a missing manifest (never seeded) also wipes and recreates',
      () async {
        final orphan = await registry.createGuestProfile(name: 'Demo');
        final gateway = buildGateway();

        await gateway.enterDemo(locale: const Locale('en'));

        final current = (await gateway.findDemoProfile())!;
        expect(current.id, isNot(orphan.id));
        expect(seededLocales, ['en']);
      },
    );

    test('is a no-op while the demo is already active', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      activeContext = guestContext((await gateway.findDemoProfile())!);
      activated.clear();
      seededLocales.clear();

      await gateway.enterDemo(locale: const Locale('en'));

      expect(activated, isEmpty);
      expect(seededLocales, isEmpty);
    });

    test('ignores guest profiles with other names (registry supports N '
        'guests; v1 owns only the one named Demo)', () async {
      await registry.createGuestProfile(name: 'Scratch');
      final gateway = buildGateway();
      expect(await gateway.demoProfileExists(), isFalse);
    });
  });

  test('exitDemo activates the real profile and keeps the demo', () async {
    final gateway = buildGateway();
    await gateway.enterDemo(locale: const Locale('en'));
    final demo = (await gateway.findDemoProfile())!;
    activeContext = guestContext(demo);
    activated.clear();

    await gateway.exitDemo();

    expect(activated, [Profile.realProfileId]);
    expect(await gateway.demoProfileExists(), isTrue);
    expect(registry.rootFor(demo).existsSync(), isTrue);
  });

  group('resetDemo', () {
    test('while active: exits to real first, then deletes, recreates and '
        're-enters', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      final first = (await gateway.findDemoProfile())!;
      activeContext = guestContext(first);
      activated.clear();
      seededLocales.clear();

      // The registry refuses to delete the active profile, so resetDemo
      // must persist the real marker before deleting. Mirror the real
      // switcher: activation updates the registry's active marker.
      final gatewayWithMarker = DemoModeGateway(
        registry: registry,
        activate: (id) async {
          activated.add(id);
          await registry.setActiveProfile(id);
          if (id == Profile.realProfileId) activeContext = null;
        },
        profileContext: () => activeContext,
        seedRunner: (world, locale) async =>
            seededLocales.add(locale.toLanguageTag()),
      );
      await registry.setActiveProfile(first.id);

      await gatewayWithMarker.resetDemo(locale: const Locale('en'));

      final second = (await gatewayWithMarker.findDemoProfile())!;
      expect(second.id, isNot(first.id));
      expect(registry.rootFor(first).existsSync(), isFalse);
      expect(seededLocales, ['en']);
      expect(activated.first, Profile.realProfileId);
      expect(activated.last, second.id);
    });

    test(
      'from the real world: deletes and recreates without an exit hop',
      () async {
        final gateway = buildGateway();
        await gateway.enterDemo(locale: const Locale('en'));
        final first = (await gateway.findDemoProfile())!;
        activated.clear();
        seededLocales.clear();

        await gateway.resetDemo(locale: const Locale('de'));

        final second = (await gateway.findDemoProfile())!;
        expect(second.id, isNot(first.id));
        expect(activated, [second.id]);
        expect(seededLocales, ['de']);
      },
    );
  });

  group('deleteDemo', () {
    test('removes the profile and its directory tree', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      final demo = (await gateway.findDemoProfile())!;

      await gateway.deleteDemo();

      expect(await gateway.demoProfileExists(), isFalse);
      expect(registry.rootFor(demo).existsSync(), isFalse);
    });

    test('throws while the demo is active', () async {
      final gateway = buildGateway();
      await gateway.enterDemo(locale: const Locale('en'));
      activeContext = guestContext((await gateway.findDemoProfile())!);

      await expectLater(gateway.deleteDemo, throwsStateError);
      expect(await gateway.demoProfileExists(), isTrue);
    });

    test('is a no-op when no demo profile exists', () async {
      final gateway = buildGateway();
      await gateway.deleteDemo();
      expect(await gateway.demoProfileExists(), isFalse);
    });
  });

  group('exitWithCopy', () {
    const plan = DemoCopyPlan(
      entities: [],
      links: [],
      definitions: [],
      media: [],
    );

    test(
      'prepares from the demo side BEFORE the switch and applies AFTER',
      () async {
        final order = <String>[];
        final gateway = DemoModeGateway(
          registry: registry,
          activate: (id) async => order.add('activate:$id'),
          profileContext: () => activeContext,
          seedRunner: (_, _) async {},
          prepareCopyOverride: (ids, aiIds) async {
            order.add('prepare:${ids.single}+${aiIds.single}');
            return plan;
          },
          applyCopyOverride: (received) async {
            order.add('apply');
            expect(identical(received, plan), isTrue);
            return 4;
          },
        );
        final demo = await registry.createGuestProfile(name: 'Demo');
        activeContext = guestContext(demo);

        final copied = await gateway.exitWithCopy(
          selectedIds: {'task-1'},
          selectedAiConfigIds: {'provider-1'},
        );

        expect(copied, 4);
        expect(order, ['prepare:task-1+provider-1', 'activate:real', 'apply']);
      },
    );

    test('empty selection just exits', () async {
      var prepared = false;
      final gateway = buildGateway(
        prepareCopy: (_, _) async {
          prepared = true;
          return plan;
        },
        applyCopy: (_) async => 0,
      );
      final demo = await registry.createGuestProfile(name: 'Demo');
      activeContext = guestContext(demo);

      final copied = await gateway.exitWithCopy(selectedIds: {});

      expect(copied, 0);
      expect(prepared, isFalse);
      expect(activated, [Profile.realProfileId]);
    });

    test('an AI-only selection still runs the copy crossing', () async {
      Set<String>? journalIds;
      Set<String>? aiIds;
      final gateway = buildGateway(
        prepareCopy: (ids, selectedAiIds) async {
          journalIds = ids;
          aiIds = selectedAiIds;
          return plan;
        },
        applyCopy: (_) async => 1,
      );
      final demo = await registry.createGuestProfile(name: 'Demo');
      activeContext = guestContext(demo);

      final copied = await gateway.exitWithCopy(
        selectedIds: {},
        selectedAiConfigIds: {'provider-1'},
      );

      expect(copied, 1);
      expect(journalIds, isEmpty);
      expect(aiIds, {'provider-1'});
      expect(activated, [Profile.realProfileId]);
    });

    test('throws outside the demo world', () async {
      final gateway = buildGateway();
      await expectLater(
        () => gateway.exitWithCopy(selectedIds: {'x'}),
        throwsStateError,
      );
    });

    test('an apply failure AFTER the switch is logged, reported through the '
        'cross-generation notice, and still rethrown', () async {
      DemoCopyFailureNotices.instance.reset();
      addTearDown(DemoCopyFailureNotices.instance.reset);
      final logger = MockDomainLogger();
      getIt.registerSingleton<DomainLogger>(logger);
      addTearDown(getIt.reset);
      var notified = 0;
      void onNotice() => notified++;
      DemoCopyFailureNotices.instance.addListener(onNotice);
      addTearDown(
        () => DemoCopyFailureNotices.instance.removeListener(onNotice),
      );
      final gateway = buildGateway(
        prepareCopy: (_, _) async => plan,
        applyCopy: (_) async => throw StateError('media move failed'),
      );
      final demo = await registry.createGuestProfile(name: 'Demo');
      activeContext = guestContext(demo);

      await expectLater(
        () => gateway.exitWithCopy(selectedIds: {'task-1'}),
        throwsStateError,
      );

      expect(
        activated,
        [Profile.realProfileId],
        reason: 'the failure happened after the switch back',
      );
      expect(notified, 1, reason: 'a mounted survivor must be poked');
      expect(
        DemoCopyFailureNotices.instance.consume(),
        isTrue,
        reason: 'a survivor mounting later must still find the pending notice',
      );
      verify(
        () => logger.error(
          LogDomain.general,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'demoExitCopyApply',
        ),
      ).called(1);
    });

    test('a prepare failure BEFORE the switch never trips the copy-failure '
        'notice — the exit sheet is still mounted to surface it', () async {
      DemoCopyFailureNotices.instance.reset();
      addTearDown(DemoCopyFailureNotices.instance.reset);
      final gateway = buildGateway(
        prepareCopy: (_, _) async => throw StateError('demo read failed'),
        applyCopy: (_) async => 0,
      );
      final demo = await registry.createGuestProfile(name: 'Demo');
      activeContext = guestContext(demo);

      await expectLater(
        () => gateway.exitWithCopy(selectedIds: {'task-1'}),
        throwsStateError,
      );

      expect(activated, isEmpty, reason: 'no switch happened');
      expect(DemoCopyFailureNotices.instance.consume(), isFalse);
    });
  });

  group('default seams (no test overrides)', () {
    tearDown(() async {
      await getIt.reset();
    });

    test('the default profile-context read resolves the active generation '
        'from getIt', () async {
      final gateway = DemoModeGateway(
        registry: registry,
        activate: (id) async => activated.add(id),
      );
      expect(
        gateway.isDemoActive,
        isFalse,
        reason: 'no ProfileContext registered means the real world',
      );

      final demo = await registry.createGuestProfile(name: 'Demo');
      getIt.registerSingleton<ProfileContext>(guestContext(demo));

      expect(
        gateway.isDemoActive,
        isTrue,
        reason: 'a registered guest ProfileContext IS the demo generation',
      );
    });

    test('the default seed runner runs the real DemoSeeder against the '
        'freshly created world, in the requested locale', () async {
      getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
      final gateway = DemoModeGateway(
        registry: registry,
        activate: (id) async => activated.add(id),
        profileContext: () => activeContext,
        bundle: _FileSystemAssetBundle(),
        clock: () => DateTime(2026, 8, 5, 10),
      );

      await gateway.enterDemo(locale: const Locale('fr'));

      final profile = (await gateway.findDemoProfile())!;
      final manifest = await DemoSeedManifest.read(registry.rootFor(profile));
      expect(manifest, isNotNull);
      expect(manifest!.isCurrentVersion, isTrue);
      expect(manifest.localeTag, 'fr');
      expect(manifest.seededJournalIds, isNotEmpty);

      // The seeded content really landed in THIS world's journal database,
      // localized through the French catalog.
      final world = WorldHandle.open(registry.rootFor(profile));
      addTearDown(world.close);
      final hero = await world.journalDb.journalEntityById(
        manualOrbitalHabitatTaskId,
      );
      final expectedTitle = demoSeedTextForLocale(const Locale('fr'))(
        'Inspect orbital penguin habitat',
        'unused-de',
      );
      expect((hero! as Task).data.title, expectedTitle);
    });

    test('exitWithCopy without overrides reads the demo generation and '
        'applies through the real generation services', () async {
      getIt.registerSingleton<EntitiesCacheService>(MockEntitiesCacheService());
      final demoProfile = await registry.createGuestProfile(name: 'Demo');
      final demoRoot = registry.rootFor(demoProfile);
      final demoHandle = WorldHandle.open(demoRoot);
      addTearDown(demoHandle.close);
      await demoHandle.writeJournalEntity(
        TestTaskFactory.create(id: 'user-task', title: 'Cross the worlds'),
      );

      final persistence = MockPersistenceLogic();
      final fts = MockFts5Db();
      when(() => persistence.updateMetadata(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata,
      );
      when(
        () => persistence.createDbEntity(
          any(),
          shouldAddGeolocation: any(named: 'shouldAddGeolocation'),
        ),
      ).thenAnswer((_) async => true);
      when(() => fts.insertText(any())).thenAnswer((_) async {});

      // The DEMO generation's services are the active getIt bindings.
      getIt
        ..registerSingleton<JournalDb>(demoHandle.journalDb)
        ..registerSingleton<AiConfigRepository>(
          AiConfigRepository(demoHandle.aiConfigDb),
        )
        ..registerSingleton<Directory>(demoRoot);
      activeContext = guestContext(demoProfile);

      final gateway = DemoModeGateway(
        registry: registry,
        activate: (id) async {
          activated.add(id);
          activeContext = null;
          // The profile switch: rebind getIt to the REAL generation.
          getIt
            ..unregister<JournalDb>()
            ..unregister<AiConfigRepository>()
            ..unregister<Directory>()
            ..registerSingleton<JournalDb>(MockJournalDb())
            ..registerSingleton<AiConfigRepository>(MockAiConfigRepository())
            ..registerSingleton<Directory>(realRoot)
            ..registerSingleton<PersistenceLogic>(persistence)
            ..registerSingleton<Fts5Db>(fts);
        },
        profileContext: () => activeContext,
        seedRunner: (_, _) async {},
      );

      final copied = await gateway.exitWithCopy(selectedIds: {'user-task'});

      expect(copied, 1);
      expect(activated, [Profile.realProfileId]);
      final written =
          verify(
                () => persistence.createDbEntity(
                  captureAny(),
                  shouldAddGeolocation: false,
                ),
              ).captured.single
              as Task;
      expect(written.data.title, 'Cross the worlds');
      expect(
        written.meta.id,
        isNot('user-task'),
        reason: 'copies must arrive under fresh real-world ids',
      );
      verify(() => fts.insertText(any())).called(1);
    });
  });

  group('scope resolution', () {
    testWidgets('demoModeGatewayOf and maybeDemoModeGatewayOf build a '
        'gateway wired to the ambient switcher', (tester) async {
      final switcher = MockProfileSwitcher();
      when(() => switcher.registry).thenReturn(registry);
      when(() => switcher.switchTo(any())).thenAnswer((_) async {});

      DemoModeGateway? viaOf;
      DemoModeGateway? viaMaybe;
      await tester.pumpWidget(
        ProfileSwitcherScope(
          switcher: switcher,
          child: Builder(
            builder: (context) {
              viaOf = demoModeGatewayOf(context);
              viaMaybe = maybeDemoModeGatewayOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(viaOf!.registry, same(registry));
      expect(viaMaybe!.registry, same(registry));

      // The built gateway's activate hook IS the ambient switcher.
      await viaOf!.exitDemo();
      verify(() => switcher.switchTo(Profile.realProfileId)).called(1);
    });
  });

  group('demoJournalEmptyProvider', () {
    tearDown(() async {
      await getIt.reset();
    });

    test('true only when the journal holds zero rows', () async {
      final db = MockJournalDb();
      when(db.countAllJournalEntries).thenAnswer((_) async => 0);
      getIt.registerSingleton<JournalDb>(db);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(demoJournalEmptyProvider.future), isTrue);
    });

    test('false when entries exist', () async {
      final db = MockJournalDb();
      when(db.countAllJournalEntries).thenAnswer((_) async => 7);
      getIt.registerSingleton<JournalDb>(db);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(demoJournalEmptyProvider.future), isFalse);
    });

    test('false when no JournalDb is registered', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(demoJournalEmptyProvider.future), isFalse);
    });
  });
}
