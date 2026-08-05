import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/media/demo_media_startup.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';

void main() {
  late GetIt services;
  late Directory root;
  late MockDomainLogger logger;
  late MockJournalDb journalDb;

  setUp(() {
    logger = MockDomainLogger();
    journalDb = MockJournalDb();
    when(
      () => journalDb.allNonDeletedJournalEntityIds(),
    ).thenAnswer((_) async => <String>[]);
    services = GetIt.asNewInstance()
      ..registerSingleton<DomainLogger>(logger)
      ..registerSingleton<JournalDb>(journalDb);
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
}
