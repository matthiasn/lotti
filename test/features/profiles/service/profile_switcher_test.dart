import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';

void main() {
  late Directory realRoot;
  late ProfileRegistry registry;
  late List<String> calls;

  setUp(() {
    realRoot = Directory.systemTemp.createTempSync('lotti_switcher_');
    registry = ProfileRegistry(realRoot: realRoot);
    calls = [];
  });

  tearDown(() async {
    if (realRoot.existsSync()) {
      await realRoot.delete(recursive: true);
    }
  });

  ProfileSwitcher buildSwitcher() => ProfileSwitcher(
    registry: registry,
    lifecycleHolder: AppLifecycleHolder(),
    onSwitchStarted: () async => calls.add('splash'),
    onSwitchCompleted: () => calls.add('completed'),
    settleFrame: () async => calls.add('settle'),
    teardownOverride: () async => calls.add('teardown'),
    bootstrapOverride: () async => calls.add('bootstrap'),
  );

  group('ProfileSwitcher.switchTo', () {
    test('persists the marker BEFORE teardown, then runs the sequence in '
        'order', () async {
      final guest = await registry.createGuestProfile(name: 'Demo');
      String? markerAtTeardown;
      final switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: AppLifecycleHolder(),
        onSwitchStarted: () async => calls.add('splash'),
        onSwitchCompleted: () => calls.add('completed'),
        settleFrame: () async => calls.add('settle'),
        teardownOverride: () async {
          calls.add('teardown');
          markerAtTeardown = (await registry.load()).activeProfileId;
        },
        bootstrapOverride: () async => calls.add('bootstrap'),
      );

      await switcher.switchTo(guest.id);

      // A crash after teardown must reopen the DEMO world on next launch:
      // the marker has to be durable before anything is torn down.
      expect(markerAtTeardown, guest.id);
      expect(calls, ['splash', 'settle', 'teardown', 'bootstrap', 'completed']);
      expect(switcher.isSwitching, isFalse);
    });

    test('switching to the already-active profile is a no-op', () async {
      final switcher = buildSwitcher();

      await switcher.switchTo(Profile.realProfileId);

      expect(calls, isEmpty);
    });

    test('unknown profile throws without touching the marker', () async {
      final switcher = buildSwitcher();

      await expectLater(
        switcher.switchTo('nope'),
        throwsArgumentError,
      );
      expect((await registry.load()).activeProfileId, Profile.realProfileId);
      expect(calls, isEmpty);
      expect(switcher.isSwitching, isFalse);
    });

    test(
      'reentrant switch requests are ignored while one is running',
      () async {
        final guest = await registry.createGuestProfile(name: 'Demo');
        late ProfileSwitcher switcher;
        switcher = ProfileSwitcher(
          registry: registry,
          lifecycleHolder: AppLifecycleHolder(),
          onSwitchStarted: () async => calls.add('splash'),
          onSwitchCompleted: () => calls.add('completed'),
          settleFrame: () async {},
          teardownOverride: () async {
            calls.add('teardown');
            // A second switch fired mid-flight must be dropped by the guard.
            await switcher.switchTo(Profile.realProfileId);
          },
          bootstrapOverride: () async => calls.add('bootstrap'),
        );

        await switcher.switchTo(guest.id);

        expect(calls, ['splash', 'teardown', 'bootstrap', 'completed']);
        expect((await registry.load()).activeProfileId, guest.id);
      },
    );

    test('guard resets after a failed switch so a retry is possible', () async {
      final guest = await registry.createGuestProfile(name: 'Demo');
      var attempts = 0;
      final switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: AppLifecycleHolder(),
        onSwitchStarted: () async {},
        onSwitchCompleted: () => calls.add('completed'),
        settleFrame: () async {},
        teardownOverride: () async {
          attempts++;
          if (attempts == 1) throw StateError('teardown boom');
        },
        bootstrapOverride: () async {},
      );

      await expectLater(switcher.switchTo(guest.id), throwsStateError);
      expect(switcher.isSwitching, isFalse);

      // The durable marker already points at the guest world: a mid-switch
      // failure is recovered by an app restart, which boots straight into
      // the intended world from a clean process.
      expect((await registry.load()).activeProfileId, guest.id);
    });
  });
}
