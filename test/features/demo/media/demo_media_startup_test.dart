import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/media/demo_media_startup.dart';
import 'package:lotti/features/demo/seed/demo_entity_factories.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late GetIt services;
  late Directory root;
  late MockDomainLogger logger;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    logger = MockDomainLogger();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    when(
      () => journalDb.allNonDeletedJournalEntityIds(),
    ).thenAnswer((_) async => <String>[]);
    when(
      () => journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);
    services = GetIt.asNewInstance()
      ..registerSingleton<DomainLogger>(logger)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications);
    root = Directory.systemTemp.createTempSync('demo_media_startup_');
  });

  tearDown(() async {
    await services.reset();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  ProfileContext context(ProfileType type) => ProfileContext.forProfile(
    profile: Profile(
      id: type.name,
      type: type,
      name: type.name,
      dirName: type == ProfileType.real ? '' : 'guest_profiles/demo',
      createdAt: DateTime(2026, 8, 5),
    ),
    root: root,
  );

  DemoMediaAsset asset(String id, List<int> bytes) => DemoMediaAsset(
    id: id,
    fileName: '$id.webp',
    sha256: sha256.convert(bytes).toString(),
    taskId: 'task-$id',
    categoryId: 'test-category',
    capturedDaysAgo: 0,
    capturedHour: 10,
    isCover: true,
  );

  /// A catalog object that has a ThumbHash: it borrows the digest of a real
  /// catalog entry, which is what the generated map is keyed by.
  DemoMediaAsset hashedAsset(String id) => DemoMediaAsset(
    id: id,
    fileName: '$id.webp',
    sha256: demoMediaAssets.first.sha256,
    taskId: 'task-$id',
    categoryId: 'test-category',
    capturedDaysAgo: 0,
    capturedHour: 10,
    isCover: true,
  );

  Future<int> backfill(List<DemoMediaAsset> assets) => backfillDemoThumbHashes(
    journalDb: journalDb,
    updateNotifications: updateNotifications,
    logger: logger,
    assets: assets,
  );

  test('real profiles never register the demo hydrator', () async {
    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.real),
      catalog: [
        asset('unused', [1]),
      ],
      download: (uri) async => Uint8List.fromList([1]),
    );

    expect(services.isRegistered<DemoMediaHydrator>(), isFalse);
  });

  test('a guest without a demo manifest is not treated as the demo', () async {
    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [
        asset('unused', [1]),
      ],
      download: (uri) async => Uint8List.fromList([1]),
    );

    expect(services.isRegistered<DemoMediaHydrator>(), isFalse);
  });

  test('hydrates only catalog images listed by this demo manifest', () async {
    final seededBytes = Uint8List.fromList([2, 3, 4]);
    final futureBytes = Uint8List.fromList([5, 6, 7]);
    final seeded = asset('seeded-image', seededBytes);
    final future = asset('future-image', futureBytes);
    await DemoSeedManifest(
      seedVersion: demoSeedVersion,
      seededAt: DateTime(2026, 8, 5),
      localeTag: 'en',
      seededJournalIds: [seeded.id],
      seededDefinitionIds: const [],
      seededAiConfigIds: const [],
    ).write(root);
    when(
      () => journalDb.allNonDeletedJournalEntityIds(),
    ).thenAnswer((_) async => [seeded.id]);
    final requested = <Uri>[];
    late Future<void> hydration;

    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [seeded, future],
      download: (uri) async {
        requested.add(uri);
        return seededBytes;
      },
      launch: (future) => hydration = future,
    );
    await hydration;

    expect(requested, [seeded.uri]);
    expect(
      File(
        p.joinAll([root.path, ...seeded.relativePath.split('/')]),
      ).readAsBytesSync(),
      seededBytes,
    );
    expect(services.isRegistered<DemoMediaHydrator>(), isTrue);
  });

  test('launches hydration without waiting for the network', () async {
    final bytes = Uint8List.fromList([8, 9, 10]);
    final seeded = asset('slow-image', bytes);
    await DemoSeedManifest(
      seedVersion: demoSeedVersion,
      seededAt: DateTime(2026, 8, 5),
      localeTag: 'en',
      seededJournalIds: [seeded.id],
      seededDefinitionIds: const [],
      seededAiConfigIds: const [],
    ).write(root);
    when(
      () => journalDb.allNonDeletedJournalEntityIds(),
    ).thenAnswer((_) async => [seeded.id]);
    final response = Completer<Uint8List>();
    late Future<void> hydration;

    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [seeded],
      download: (uri) => response.future,
      launch: (future) => hydration = future,
    );

    expect(
      File(
        p.joinAll([root.path, ...seeded.relativePath.split('/')]),
      ).existsSync(),
      isFalse,
    );

    response.complete(bytes);
    await hydration;
    expect(
      File(
        p.joinAll([root.path, ...seeded.relativePath.split('/')]),
      ).readAsBytesSync(),
      bytes,
    );
  });

  test('logs and skips a demo manifest that cannot be read', () async {
    await DemoSeedManifest.fileFor(root).writeAsString('{not-json');

    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [
        asset('unused', [11]),
      ],
      download: (uri) async => Uint8List.fromList([11]),
    );

    expect(services.isRegistered<DemoMediaHydrator>(), isFalse);
    verify(
      () => logger.error(
        LogDomain.general,
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'demoMediaManifest',
        message: 'Unable to read demo media manifest',
      ),
    ).called(1);
  });

  test('does not register when the manifest owns no catalog images', () async {
    await DemoSeedManifest(
      seedVersion: demoSeedVersion,
      seededAt: DateTime(2026, 8, 5),
      localeTag: 'en',
      seededJournalIds: const ['different-image'],
      seededDefinitionIds: const [],
      seededAiConfigIds: const [],
    ).write(root);

    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [
        asset('unused', [12]),
      ],
      download: (uri) async => Uint8List.fromList([12]),
    );

    expect(services.isRegistered<DemoMediaHydrator>(), isFalse);
  });

  test(
    'logs and skips hydration when journal rows cannot be inspected',
    () async {
      final seeded = asset('journal-read-failure', [12]);
      await DemoSeedManifest(
        seedVersion: demoSeedVersion,
        seededAt: DateTime(2026, 8, 5),
        localeTag: 'en',
        seededJournalIds: [seeded.id],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(root);

      await registerDemoMediaHydration(
        serviceLocator: services,
        profile: context(ProfileType.guest),
        catalog: [seeded],
        activeJournalIds: () async => throw StateError('journal unavailable'),
        download: (uri) async => Uint8List.fromList([12]),
      );

      expect(services.isRegistered<DemoMediaHydrator>(), isFalse);
      verify(
        () => logger.error(
          LogDomain.general,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'demoMediaJournal',
          message: 'Unable to inspect demo media entities',
        ),
      ).called(1);
    },
  );

  test('network failures are contained and logged per asset', () async {
    final bytes = Uint8List.fromList([13]);
    final seeded = asset('network-failure', bytes);
    await DemoSeedManifest(
      seedVersion: demoSeedVersion,
      seededAt: DateTime(2026, 8, 5),
      localeTag: 'en',
      seededJournalIds: [seeded.id],
      seededDefinitionIds: const [],
      seededAiConfigIds: const [],
    ).write(root);
    when(
      () => journalDb.allNonDeletedJournalEntityIds(),
    ).thenAnswer((_) async => [seeded.id]);
    late Future<void> hydration;

    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [seeded],
      client: MockClient(
        (request) async => http.Response('', HttpStatus.serviceUnavailable),
      ),
      launch: (future) => hydration = future,
    );
    await hydration;

    expect(
      File(
        p.joinAll([root.path, ...seeded.relativePath.split('/')]),
      ).existsSync(),
      isFalse,
    );
    verify(
      () => logger.error(
        LogDomain.general,
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'demoMediaHydration',
        message: 'Unable to hydrate ${seeded.fileName}',
      ),
    ).called(1);
  });

  test(
    'does not rehydrate a seeded image that was permanently purged',
    () async {
      final bytes = Uint8List.fromList([14]);
      final purged = asset('purged-image', bytes);
      await DemoSeedManifest(
        seedVersion: demoSeedVersion,
        seededAt: DateTime(2026, 8, 5),
        localeTag: 'en',
        seededJournalIds: [purged.id],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(root);
      var requests = 0;

      await registerDemoMediaHydration(
        serviceLocator: services,
        profile: context(ProfileType.guest),
        catalog: [purged],
        download: (uri) async {
          requests++;
          return bytes;
        },
      );

      expect(requests, 0);
      expect(services.isRegistered<DemoMediaHydrator>(), isFalse);
    },
  );

  group('backfillDemoThumbHashes', () {
    test('writes the catalog hash into a seeded image that has none, and '
        'announces it', () async {
      final asset = hashedAsset('image-1');
      final image = TestImageFactory.create(id: 'image-1');
      expect(image.data.thumbHash, isNull);
      when(
        () => journalDb.getJournalEntitiesForIds(any()),
      ).thenAnswer((_) async => [image]);
      when(
        () => journalDb.updateJournalEntity(any()),
      ).thenAnswer((_) async => JournalUpdateResult.applied());

      final written = await backfill([asset]);

      expect(written, 1);
      final rewritten =
          verify(
                () => journalDb.updateJournalEntity(captureAny()),
              ).captured.single
              as JournalImage;
      expect(rewritten.data.thumbHash, asset.thumbHash);
      expect(rewritten.data.copyWith(thumbHash: null), image.data);
      expect(rewritten.meta, image.meta);
      // The slot may already be on screen: the entry controller reloads on
      // this, the same set PersistenceLogic would announce.
      verify(
        () => updateNotifications.notify({'image-1', imageNotification}),
      ).called(1);
    });

    test('leaves an image that already carries its hash alone', () async {
      final image = TestImageFactory.create(id: 'image-1');
      when(() => journalDb.getJournalEntitiesForIds(any())).thenAnswer(
        (_) async => [
          image.copyWith(data: image.data.copyWith(thumbHash: 'kept')),
        ],
      );

      expect(await backfill([hashedAsset('image-1')]), 0);
      verifyNever(() => journalDb.updateJournalEntity(any()));
    });

    test('skips an object the catalog has no hash for', () async {
      when(
        () => journalDb.getJournalEntitiesForIds(any()),
      ).thenAnswer((_) async => [TestImageFactory.create(id: 'image-1')]);

      expect(
        await backfill([
          asset('image-1', [1]),
        ]),
        0,
      );
      verifyNever(() => journalDb.updateJournalEntity(any()));
    });

    test('skips an entity that is not an image', () async {
      when(() => journalDb.getJournalEntitiesForIds(any())).thenAnswer(
        (_) async => [
          JournalEntity.journalEntry(
            meta: TestMetadataFactory.create(id: 'image-1'),
          ),
        ],
      );

      expect(await backfill([hashedAsset('image-1')]), 0);
      verifyNever(() => journalDb.updateJournalEntity(any()));
    });

    test('does not announce a rewrite the database skipped', () async {
      when(
        () => journalDb.getJournalEntitiesForIds(any()),
      ).thenAnswer((_) async => [TestImageFactory.create(id: 'image-1')]);
      when(() => journalDb.updateJournalEntity(any())).thenAnswer(
        (_) async => JournalUpdateResult.skipped(
          reason: JournalUpdateSkipReason.conflict,
        ),
      );

      final written = await backfill([hashedAsset('image-1')]);

      expect(written, 0);
      verifyNever(() => updateNotifications.notify(any()));
    });

    test('logs a rewrite that throws and carries on with the rest', () async {
      final broken = TestImageFactory.create(id: 'image-1');
      final fine = TestImageFactory.create(id: 'image-2');
      when(
        () => journalDb.getJournalEntitiesForIds(any()),
      ).thenAnswer((_) async => [broken, fine]);
      when(() => journalDb.updateJournalEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity = invocation.positionalArguments.single as JournalEntity;
        if (entity.id == broken.id) throw StateError('disk full');
        return JournalUpdateResult.applied();
      });

      final written = await backfill([
        hashedAsset('image-1'),
        hashedAsset('image-2'),
      ]);

      expect(written, 1);
      verify(
        () => logger.error(
          LogDomain.general,
          any(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'demoMediaThumbHash',
          message: 'Unable to backfill the ThumbHash of image-1.jpg',
        ),
      ).called(1);
    });

    test('logs and gives up when the images cannot be read', () async {
      when(
        () => journalDb.getJournalEntitiesForIds(any()),
      ).thenThrow(StateError('journal unavailable'));

      expect(await backfill([hashedAsset('image-1')]), 0);
      verifyNever(() => journalDb.updateJournalEntity(any()));
      verify(
        () => logger.error(
          LogDomain.general,
          any(that: isA<StateError>()),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'demoMediaThumbHash',
          message: 'Unable to read demo images for the ThumbHash backfill',
        ),
      ).called(1);
    });

    test('runs ahead of hydration for the images the manifest owns', () async {
      final seeded = hashedAsset('seeded-image');
      await DemoSeedManifest(
        seedVersion: demoSeedVersion,
        seededAt: DateTime(2026, 8, 5),
        localeTag: 'en',
        seededJournalIds: [seeded.id],
        seededDefinitionIds: const [],
        seededAiConfigIds: const [],
      ).write(root);
      when(
        () => journalDb.allNonDeletedJournalEntityIds(),
      ).thenAnswer((_) async => [seeded.id]);
      when(
        () => journalDb.getJournalEntitiesForIds({seeded.id}),
      ).thenAnswer((_) async => [TestImageFactory.create(id: seeded.id)]);
      final order = <String>[];
      when(() => journalDb.updateJournalEntity(any())).thenAnswer((_) async {
        order.add('backfill');
        return JournalUpdateResult.applied();
      });
      late Future<void> hydration;

      await registerDemoMediaHydration(
        serviceLocator: services,
        profile: context(ProfileType.guest),
        catalog: [seeded],
        download: (uri) async {
          order.add('download');
          return Uint8List.fromList([1]);
        },
        launch: (future) => hydration = future,
      );
      await hydration;

      expect(order, ['backfill', 'download']);
    });
  });
}
