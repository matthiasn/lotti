import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
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
        // A live audio player whose native dispose fails: the switch must
        // log it and carry on tearing down the rest of the generation.
        final player = MockPlayer();
        final playerStream = MockPlayerStream();
        when(() => player.stream).thenReturn(playerStream);
        when(
          () => playerStream.position,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(
          () => playerStream.buffer,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(
          () => playerStream.completed,
        ).thenAnswer((_) => const Stream<bool>.empty());
        var playerDisposals = 0;
        when(player.dispose).thenAnswer((_) async {
          // Only the switch's dispose fails; the container teardown below
          // disposes the already-detached player a second time.
          if (++playerDisposals == 1) throw StateError('mpv boom');
        });
        final audioContainer = ProviderContainer(
          overrides: [playerFactoryProvider.overrideWithValue(() => player)],
        );
        addTearDown(audioContainer.dispose);
        audioContainer
            .read(audioPlayerControllerProvider.notifier)
            .ensurePlayerForTest();

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
        expect(playerDisposals, 1);
        for (final failedStep in [
          'profileSwitch_StartupTasks.settle',
          'profileSwitch_TimeService.stop',
          'profileSwitch_AudioPlayerController.disposeActivePlayer',
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

  group('ProfileSwitcher.runWithGenerationClosed', () {
    late Profile activeProfile;

    /// Registers the running generation's context, which the switcher reads
    /// before closing it.
    Future<void> registerActiveContext() async {
      await getIt.reset();
      addTearDown(getIt.reset);
      final state = await registry.load();
      activeProfile = state.profileById(state.activeProfileId)!;
      getIt.registerSingleton<ProfileContext>(
        ProfileContext.forProfile(
          profile: activeProfile,
          root: registry.rootFor(activeProfile),
        ),
      );
    }

    /// Default teardown (strict close of whatever is registered) with a
    /// recorded bootstrap.
    ProfileSwitcher strictSwitcher({Future<void> Function()? bootstrap}) =>
        ProfileSwitcher(
          registry: registry,
          lifecycleHolder: AppLifecycleHolder(),
          onSwitchStarted: () async => calls.add('splash'),
          onSwitchCompleted: () => calls.add('completed'),
          settleFrame: () async => calls.add('settle'),
          bootstrapOverride: bootstrap ?? () async => calls.add('bootstrap'),
        );

    test('closes, runs the work against the closed root, and restarts the '
        'same profile', () async {
      await registerActiveContext();
      final markerBefore = (await registry.load()).activeProfileId;
      ClosedProfileGeneration? seen;
      final switcher = buildSwitcher();

      final result = await switcher.runWithGenerationClosed((closed) async {
        calls.add('work');
        seen = closed;
        return 42;
      });

      expect(result, 42);
      expect(calls, [
        'splash',
        'settle',
        'teardown',
        'work',
        'bootstrap',
        'completed',
      ]);
      expect(seen!.profile.id, activeProfile.id);
      expect(seen!.root.path, registry.rootFor(activeProfile).path);
      // Closing for work is not a switch: the marker never moves.
      expect((await registry.load()).activeProfileId, markerBefore);
      expect(switcher.isSwitching, isFalse);
    });

    test('a step that fails to stop skips the work, restarts the profile, and '
        'names the step', () async {
      await registerActiveContext();
      final timeService = MockTimeService();
      when(timeService.stop).thenThrow(StateError('timer still running'));
      getIt.registerSingleton<TimeService>(timeService);
      var workRan = false;

      await expectLater(
        strictSwitcher().runWithGenerationClosed((_) async => workRan = true),
        throwsA(
          isA<ProfileQuiescenceException>().having(
            (e) => e.failures.map((f) => f.service),
            'failed steps',
            ['TimeService.stop'],
          ),
        ),
      );

      expect(workRan, isFalse);
      // The profile is usable again even though the close was not clean.
      expect(calls, ['splash', 'settle', 'bootstrap', 'completed']);
    });

    test('a service that fails to dispose also blocks the work', () async {
      await registerActiveContext();
      final outbox = MockOutboxService();
      when(outbox.dispose).thenAnswer(
        (_) async => throw StateError('outbox still sending'),
      );
      getIt.registerSingleton<OutboxService>(outbox);
      var workRan = false;

      await expectLater(
        strictSwitcher().runWithGenerationClosed((_) async => workRan = true),
        throwsA(
          isA<ProfileQuiescenceException>()
              .having(
                (e) => e.failures.single.service,
                'failed service',
                'OutboxService',
              )
              .having(
                (e) => e.toString(),
                'description',
                contains('outbox still sending'),
              ),
        ),
      );

      expect(workRan, isFalse);
      expect(calls, ['splash', 'settle', 'bootstrap', 'completed']);
    });

    test('a clean strict close runs the work', () async {
      await registerActiveContext();
      final timeService = MockTimeService();
      when(timeService.stop).thenAnswer((_) async {});
      getIt.registerSingleton<TimeService>(timeService);

      final result = await strictSwitcher().runWithGenerationClosed(
        (_) async => 'captured',
      );

      expect(result, 'captured');
      verify(timeService.stop).called(1);
      // getIt was reset by the close, so nothing of the old generation is
      // left registered for the work to write through.
      expect(getIt.isRegistered<TimeService>(), isFalse);
    });

    test(
      'work that throws still restarts the profile, then rethrows',
      () async {
        await registerActiveContext();
        final switcher = buildSwitcher();

        await expectLater(
          switcher.runWithGenerationClosed<void>(
            (_) async => throw const FileSystemException('disk full'),
          ),
          throwsA(isA<FileSystemException>()),
        );

        expect(calls, [
          'splash',
          'settle',
          'teardown',
          'bootstrap',
          'completed',
        ]);
        expect(switcher.isSwitching, isFalse);
      },
    );

    test('a failed restart leaves the splash up and reports it', () async {
      await registerActiveContext();
      final switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: AppLifecycleHolder(),
        onSwitchStarted: () async => calls.add('splash'),
        onSwitchCompleted: () => calls.add('completed'),
        settleFrame: () async {},
        teardownOverride: () async => calls.add('teardown'),
        bootstrapOverride: () async => throw StateError('boot failed'),
      );

      await expectLater(
        switcher.runWithGenerationClosed((_) async => calls.add('work')),
        throwsA(
          isA<ProfileRestartException>().having(
            (e) => e.cause,
            'cause',
            isStateError,
          ),
        ),
      );

      // Never rebuilt: the app stays on the splash until relaunched.
      expect(calls, ['splash', 'teardown', 'work']);
      expect(switcher.isSwitching, isFalse);
    });

    test('a teardown that throws neither runs the work nor bootstraps onto '
        'the half-reset container', () async {
      await registerActiveContext();
      final switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: AppLifecycleHolder(),
        onSwitchStarted: () async => calls.add('splash'),
        onSwitchCompleted: () => calls.add('completed'),
        settleFrame: () async {},
        teardownOverride: () async => throw StateError('reset failed'),
        bootstrapOverride: () async => calls.add('bootstrap'),
      );

      await expectLater(
        switcher.runWithGenerationClosed((_) async => calls.add('work')),
        throwsA(isA<ProfileRestartException>()),
      );

      expect(calls, ['splash']);
      expect(switcher.isSwitching, isFalse);
    });

    group('with a rollback', () {
      /// Records the whole bracket, with a bootstrap that fails [bootFailures]
      /// times before it succeeds.
      ProfileSwitcher rollbackSwitcher({int bootFailures = 0}) {
        var failuresLeft = bootFailures;
        return ProfileSwitcher(
          registry: registry,
          lifecycleHolder: AppLifecycleHolder(),
          onSwitchStarted: () async => calls.add('splash'),
          onSwitchCompleted: () => calls.add('completed'),
          settleFrame: () async {},
          teardownOverride: () async => calls.add('teardown'),
          bootstrapOverride: () async {
            calls.add('bootstrap');
            if (failuresLeft-- > 0) throw StateError('boot failed');
          },
        );
      }

      test('a restarted profile that fails its check is rolled back and '
          'started again', () async {
        await registerActiveContext();

        await expectLater(
          rollbackSwitcher().runWithGenerationClosed(
            (_) async => calls.add('change'),
            verifyRestarted: () async {
              calls.add('verify');
              if (calls.where((c) => c == 'verify').length == 1) {
                throw StateError('database would not open');
              }
            },
            rollBack: () async => calls.add('rollBack'),
          ),
          throwsA(
            isA<ProfileRolledBackException>().having(
              (e) => e.cause,
              'cause',
              isStateError,
            ),
          ),
        );

        // The original is not verified again: it is what was running before.
        expect(calls, [
          'splash',
          'teardown',
          'change',
          'bootstrap',
          'verify',
          'teardown',
          'rollBack',
          'bootstrap',
          'completed',
        ]);
      });

      test('a changed profile that fails to boot is rolled back too', () async {
        await registerActiveContext();

        await expectLater(
          rollbackSwitcher(bootFailures: 1).runWithGenerationClosed(
            (_) async => calls.add('change'),
            verifyRestarted: () async => calls.add('verify'),
            rollBack: () async => calls.add('rollBack'),
          ),
          throwsA(isA<ProfileRolledBackException>()),
        );

        expect(calls, [
          'splash',
          'teardown',
          'change',
          'bootstrap',
          'teardown',
          'rollBack',
          'bootstrap',
          'completed',
        ]);
      });

      test('a healthy change is kept', () async {
        await registerActiveContext();

        await rollbackSwitcher().runWithGenerationClosed(
          (_) async => calls.add('change'),
          verifyRestarted: () async => calls.add('verify'),
          rollBack: () async => calls.add('rollBack'),
        );

        expect(calls, [
          'splash',
          'teardown',
          'change',
          'bootstrap',
          'verify',
          'completed',
        ]);
      });

      test(
        'a rollback that fails leaves the splash up for a relaunch',
        () async {
          await registerActiveContext();

          await expectLater(
            rollbackSwitcher(bootFailures: 1).runWithGenerationClosed(
              (_) async => calls.add('change'),
              rollBack: () async => throw const FileSystemException('busy'),
            ),
            throwsA(
              isA<ProfileRestartException>().having(
                (e) => e.cause,
                'cause',
                isA<FileSystemException>(),
              ),
            ),
          );

          // Never booted onto files the rollback could not put back.
          expect(calls, [
            'splash',
            'teardown',
            'change',
            'bootstrap',
            'teardown',
          ]);
        },
      );

      test('the original failing to boot after the rollback is a restart '
          'failure', () async {
        await registerActiveContext();

        await expectLater(
          rollbackSwitcher(bootFailures: 2).runWithGenerationClosed(
            (_) async => calls.add('change'),
            rollBack: () async => calls.add('rollBack'),
          ),
          throwsA(isA<ProfileRestartException>()),
        );
        expect(calls.last, 'bootstrap');
        expect(calls, isNot(contains('completed')));
      });

      test('a rejected generation that will not close is never rolled back '
          'under it', () async {
        await registerActiveContext();
        final timeService = MockTimeService();
        when(timeService.stop).thenThrow(StateError('timer still writing'));
        var boots = 0;
        var rolledBack = false;
        final switcher = ProfileSwitcher(
          registry: registry,
          lifecycleHolder: AppLifecycleHolder(),
          onSwitchStarted: () async {},
          onSwitchCompleted: () {},
          settleFrame: () async {},
          // Default (strict) teardown. The restarted generation registers a
          // service that refuses to stop.
          bootstrapOverride: () async {
            boots++;
            getIt.registerSingleton<TimeService>(timeService);
          },
        );

        await expectLater(
          switcher.runWithGenerationClosed(
            (_) async {},
            verifyRestarted: () async => throw StateError('check failed'),
            rollBack: () async => rolledBack = true,
          ),
          throwsA(
            isA<ProfileRestartException>().having(
              (e) => e.cause,
              'cause',
              isA<ProfileQuiescenceException>(),
            ),
          ),
        );

        expect(rolledBack, isFalse);
        expect(boots, 1);
      });

      test('work that failed on its own changed nothing: no check, no '
          'rollback', () async {
        await registerActiveContext();

        await expectLater(
          rollbackSwitcher().runWithGenerationClosed<void>(
            (_) async => throw const FileSystemException('disk full'),
            verifyRestarted: () async => calls.add('verify'),
            rollBack: () async => calls.add('rollBack'),
          ),
          throwsA(isA<FileSystemException>()),
        );

        expect(calls, ['splash', 'teardown', 'bootstrap', 'completed']);
      });

      test('work that reports its files unstartable is never booted', () async {
        await registerActiveContext();
        final switcher = rollbackSwitcher();

        await expectLater(
          switcher.runWithGenerationClosed<void>(
            (_) async => throw const ProfileRestartException(
              FileSystemException('half moved'),
              StackTrace.empty,
            ),
            rollBack: () async => calls.add('rollBack'),
          ),
          throwsA(isA<ProfileRestartException>()),
        );

        expect(calls, ['splash', 'teardown']);
        expect(switcher.isSwitching, isFalse);
      });
    });

    test('describes a busy lifecycle and a failed restart', () {
      expect(
        const ProfileLifecycleBusyException().toString(),
        contains('a profile switch or backup is running'),
      );
      expect(
        const ProfileRestartException(
          'boot failed',
          StackTrace.empty,
        ).toString(),
        'ProfileRestartException: boot failed',
      );
    });

    test('describes a rollback', () {
      expect(
        const ProfileRolledBackException('no', StackTrace.empty).toString(),
        contains('ProfileRolledBackException'),
      );
    });

    test('refuses to start while a switch is running, and a switch requested '
        'while closed is ignored', () async {
      await registerActiveContext();
      final guest = await registry.createGuestProfile(name: 'Demo');
      Object? closedDuringSwitch;
      late ProfileSwitcher switcher;
      switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: AppLifecycleHolder(),
        onSwitchStarted: () async {},
        onSwitchCompleted: () {},
        settleFrame: () async {},
        teardownOverride: () async {
          if (!switcher.isSwitching) return;
          try {
            await switcher.runWithGenerationClosed((_) async {});
          } catch (e) {
            closedDuringSwitch = e;
          }
        },
        bootstrapOverride: () async {},
      );

      await switcher.switchTo(guest.id);
      expect(closedDuringSwitch, isA<ProfileLifecycleBusyException>());

      // And the other way round: a switch fired mid-backup is dropped by the
      // shared guard, so the marker stays on the profile being captured.
      await registerActiveContext();
      await switcher.runWithGenerationClosed(
        (_) => switcher.switchTo(Profile.realProfileId),
      );
      expect((await registry.load()).activeProfileId, guest.id);
    });
  });
}
