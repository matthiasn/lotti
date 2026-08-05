import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:lotti/services/startup_tasks.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/db_settle.dart';
import '../../../mocks/mocks.dart';

class _ThrowingStartupTasks extends StartupTasks {
  @override
  Future<void> settle({Duration timeout = const Duration(seconds: 5)}) =>
      throw StateError('settle boom');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test(
      'default teardown + bootstrap re-point the whole service generation '
      'at the target world',
      () async {
        // Real seams: only the frame settle is stubbed (no frames are
        // pumped in a plain test).
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async => realRoot.path,
          )
          ..setMockMethodCallHandler(
            const MethodChannel(
              'plugins.it_nomads.com/flutter_secure_storage',
            ),
            (MethodCall call) async => null,
          )
          ..setMockMethodCallHandler(
            const MethodChannel('window_manager'),
            (MethodCall call) async => null,
          );
        addTearDown(() async {
          await settlePendingDbWork();
          await ServiceDisposer(getIt, (e, s, n) {}).disposeAll();
          await getIt.reset();
          for (final channel in const [
            'plugins.flutter.io/path_provider',
            'plugins.it_nomads.com/flutter_secure_storage',
            'window_manager',
          ]) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(MethodChannel(channel), null);
          }
        });

        await getIt.reset();
        final guest1 = await registry.createGuestProfile(name: 'Demo 1');
        final guest2 = await registry.createGuestProfile(name: 'Demo 2');
        await registry.setActiveProfile(guest1.id);

        final holder = AppLifecycleHolder();
        // The real bootstrap attaches an AppLifecycleListener to the
        // binding; leaked, it would assert on lifecycle transitions
        // dispatched by unrelated tests later in the same runner.
        addTearDown(holder.dispose);
        registerProcessLogging();
        await bootstrapProfileServices(
          await resolveActiveProfile(),
          lifecycleHolder: holder,
          restoreWindow: false,
        );
        // Registration starts editor-state and onboarding database work in
        // background isolates. Finish that generation's startup requests
        // before the switch deliberately closes its database channels.
        await settlePendingDbWork();
        final journalDbGen1 = getIt<JournalDb>();
        expect(getIt<ProfileContext>().profile.id, guest1.id);

        final switcher = ProfileSwitcher(
          registry: registry,
          lifecycleHolder: holder,
          onSwitchStarted: () async => calls.add('splash'),
          onSwitchCompleted: () => calls.add('completed'),
          settleFrame: () async {},
        );

        await switcher.switchTo(guest2.id);

        expect(calls, ['splash', 'completed']);
        expect(getIt<ProfileContext>().profile.id, guest2.id);
        expect(
          getIt<Directory>().path,
          registry.rootFor(guest2).path,
        );
        // The generation really was rebuilt: fresh database instances.
        expect(identical(getIt<JournalDb>(), journalDbGen1), isFalse);
        expect((await registry.load()).activeProfileId, guest2.id);
      },
    );

    test(
      'quiesce failures are contained, logged, and do not abort the switch',
      () async {
        await getIt.reset();
        addTearDown(getIt.reset);
        final domainLogger = MockDomainLogger();
        when(
          () => domainLogger.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: any<String?>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});
        final timeService = MockTimeService();
        when(timeService.stop).thenThrow(StateError('timer boom'));
        final windowService = MockWindowService();
        when(
          windowService.detachForRestart,
        ).thenAnswer((_) async => throw StateError('detach boom'));
        getIt
          ..registerSingleton<DomainLogger>(domainLogger)
          ..registerSingleton<StartupTasks>(_ThrowingStartupTasks())
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<WindowService>(windowService);

        final guest = await registry.createGuestProfile(name: 'Demo');
        var bootstrapped = false;
        final switcher = ProfileSwitcher(
          registry: registry,
          lifecycleHolder: AppLifecycleHolder(),
          onSwitchStarted: () async {},
          onSwitchCompleted: () {},
          settleFrame: () async {},
          // Default teardown path: quiesce + dispose + getIt.reset.
          bootstrapOverride: () async => bootstrapped = true,
        );

        await switcher.switchTo(guest.id);

        expect(bootstrapped, isTrue);
        verify(timeService.stop).called(1);
        verify(windowService.detachForRestart).called(1);
        for (final failedStep in [
          'profileSwitch_StartupTasks.settle',
          'profileSwitch_TimeService.stop',
          'profileSwitch_WindowService.detachForRestart',
        ]) {
          verify(
            () => domainLogger.error(
              LogDomain.general,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: failedStep,
            ),
          ).called(1);
        }
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

      // The guard is released: a follow-up call is accepted and — because
      // the marker already points at the target — resolves as the
      // documented same-profile no-op instead of re-tearing a dead
      // generation.
      await expectLater(switcher.switchTo(guest.id), completes);
      expect(attempts, 1);
      expect(switcher.isSwitching, isFalse);
    });
  });
}
