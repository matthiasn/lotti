import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/demo_world_creator.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory realRoot;
  late ProfileRegistry registry;
  late List<String> activated;

  setUp(() {
    realRoot = Directory.systemTemp.createTempSync('lotti_creator_');
    registry = ProfileRegistry(realRoot: realRoot);
    activated = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'forbidden');
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (realRoot.existsSync()) {
      await realRoot.delete(recursive: true);
    }
  });

  DemoWorldCreator buildCreator() => DemoWorldCreator(
    registry: registry,
    activate: (id) async => activated.add(id),
  );

  group('DemoWorldCreator.createAndActivate', () {
    test('seeds the world BEFORE activating it', () async {
      var worldPopulatedAtActivation = false;
      final creator = DemoWorldCreator(
        registry: registry,
        activate: (id) async {
          activated.add(id);
          final profile = (await registry.load()).profileById(id)!;
          worldPopulatedAtActivation = File(
            p.join(registry.rootFor(profile).path, 'settings.sqlite'),
          ).existsSync();
        },
      );

      final created = await creator.createAndActivate(
        seed: (world) => world.writeSetting('demo_seed_version', '1'),
        name: 'Demo',
      );

      expect(activated, [created.id]);
      // The requirement's ordering: populate first, then re-point the
      // documents layer. Activation must observe a populated world.
      expect(worldPopulatedAtActivation, isTrue);
      expect((await registry.load()).profileById(created.id), isNotNull);
    });

    test('a failed seed removes the half-built world and never '
        'activates', () async {
      final creator = buildCreator();

      await expectLater(
        creator.createAndActivate(
          seed: (world) async {
            await world.writeSetting('partial', 'x');
            throw StateError('seed boom');
          },
          name: 'Demo',
        ),
        throwsStateError,
      );

      expect(activated, isEmpty);
      final state = await registry.load();
      expect(state.profiles.where((profile) => profile.isGuest), isEmpty);
      final guestContainer = Directory(
        p.join(realRoot.path, 'guest_profiles'),
      );
      if (guestContainer.existsSync()) {
        expect(guestContainer.listSync(), isEmpty);
      }
    });
  });
}
