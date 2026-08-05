import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:lotti/features/demo/media/demo_media_startup.dart';
import 'package:lotti/features/demo/seed/demo_seed_manifest.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/startup_tasks.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';

void main() {
  late GetIt services;
  late Directory root;

  setUp(() {
    services = GetIt.asNewInstance()
      ..registerSingleton<DomainLogger>(MockDomainLogger())
      ..registerSingleton<StartupTasks>(StartupTasks());
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
    final requested = <Uri>[];

    await registerDemoMediaHydration(
      serviceLocator: services,
      profile: context(ProfileType.guest),
      catalog: [seeded, future],
      download: (uri) async {
        requested.add(uri);
        return seededBytes;
      },
    );
    await services<StartupTasks>().settle();

    expect(requested, [seeded.uri]);
    expect(
      File(
        p.joinAll([root.path, ...seeded.relativePath.split('/')]),
      ).readAsBytesSync(),
      seededBytes,
    );
    expect(services.isRegistered<DemoMediaHydrator>(), isTrue);
  });
}
