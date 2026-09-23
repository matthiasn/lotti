import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/backup_restore/service/closed_sqlite_file.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_coordinator.dart';
import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../helpers/db_settle.dart';
import '../../../helpers/package_info.dart';

/// Stands in for [ProfileSwitcher.runWithGenerationClosed]: records the
/// close/restart bracket and can fail the close or cancel while closed.
class _FakeRunner {
  _FakeRunner(this.closed);

  final ClosedProfileGeneration closed;
  final calls = <String>[];

  /// Thrown instead of running the work, as a failed strict close does.
  Exception? closeFailure;

  /// Runs after the profile is "closed" and before the work.
  FutureOr<void> Function()? whileClosing;

  Future<T> run<T>(
    Future<T> Function(ClosedProfileGeneration closed) whileClosed,
  ) async {
    calls.add('close');
    try {
      await whileClosing?.call();
      final failure = closeFailure;
      if (failure != null) throw failure;
      return await whileClosed(closed);
    } finally {
      calls.add('restart');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testRoot;
  late Directory stagingParent;
  late ProfileRegistry registry;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('lotti_backup_coord_');
    stagingParent = Directory(p.join(testRoot.path, 'staging'))..createSync();
    registry = ProfileRegistry(
      realRoot: Directory(p.join(testRoot.path, 'documents'))..createSync(),
    );
  });

  tearDown(() {
    if (testRoot.existsSync()) testRoot.deleteSync(recursive: true);
  });

  /// Writes one committed row into a WAL-mode database and closes it, as a
  /// cleanly shut down Drift database leaves it.
  void writeClosedDatabase(Directory root, String name, String value) {
    final database = sqlite3.open(p.join(root.path, name));
    try {
      database
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('CREATE TABLE probe (value TEXT NOT NULL)')
        ..execute('INSERT INTO probe VALUES (?)', [value]);
    } finally {
      database.close();
    }
  }

  Future<ClosedProfileGeneration> closedProfile({bool guest = false}) async {
    final profile = guest
        ? await registry.createGuestProfile(name: 'Demo')
        : (await registry.load()).profileById(Profile.realProfileId)!;
    final root = registry.rootFor(profile)..createSync(recursive: true);
    writeClosedDatabase(root, 'db.sqlite', 'journal row');
    writeClosedDatabase(root, 'settings.sqlite', 'setting row');
    return ClosedProfileGeneration(profile: profile, root: root);
  }

  String stagedValue(StagedProfileSnapshot snapshot, String name) {
    final database = sqlite3.open(
      p.join(snapshot.payloadDirectory.path, name),
      mode: OpenMode.readOnly,
    );
    try {
      return database.select('SELECT value FROM probe').single['value']
          as String;
    } finally {
      database.close();
    }
  }

  ProfileBackupCoordinator coordinator(
    _FakeRunner runner, {
    ProfileSnapshotTestHooks? hooks,
    Future<String> Function()? appVersion,
  }) => ProfileBackupCoordinator(
    runClosed: runner.run,
    // The real settle step, without real pauses between its attempts.
    settleDatabases: (root) =>
        settleProfileDatabases(root, attempts: 3, pause: () async {}),
    snapshots: QuiescedProfileSnapshotService(
      snapshotIdGenerator: () => 'snapshot-1',
      now: () => DateTime.utc(2026, 9, 22, 12),
      testHooks: hooks,
    ),
    appVersion: appVersion ?? () async => '1.1.23+4404',
  );

  group('ProfileBackupCoordinator', () {
    test(
      'captures the closed profile inside the close/restart bracket',
      () async {
        final runner = _FakeRunner(await closedProfile());

        final snapshot = await coordinator(runner).capture(
          stagingParent: stagingParent,
        );

        expect(runner.calls, ['close', 'restart']);
        expect(snapshot.manifest.profileType, 'real');
        expect(snapshot.manifest.appVersion, '1.1.23+4404');
        expect(p.isWithin(stagingParent.path, snapshot.directory.path), isTrue);
        expect(stagedValue(snapshot, 'db.sqlite'), 'journal row');
        expect(stagedValue(snapshot, 'settings.sqlite'), 'setting row');
      },
    );

    test('stamps the installed app version by default', () async {
      mockPackageInfo(version: '1.1.24', buildNumber: '4410');
      final runner = _FakeRunner(await closedProfile());

      final snapshot = await ProfileBackupCoordinator(
        runClosed: runner.run,
      ).capture(stagingParent: stagingParent);

      expect(snapshot.manifest.appVersion, '1.1.24+4410');
    });

    test('exceptions describe themselves', () {
      expect(
        const ProfileBackupBusyException().toString(),
        contains('a backup or profile switch is running'),
      );
      expect(
        const ProfileBackupCancelledException().toString(),
        'ProfileBackupCancelledException',
      );
    });

    test('records a guest world as a guest backup', () async {
      final runner = _FakeRunner(await closedProfile(guest: true));

      final snapshot = await coordinator(runner).capture(
        stagingParent: stagingParent,
      );

      expect(snapshot.manifest.profileType, 'guest');
    });

    test('refuses a second capture while one is running, then accepts the '
        'next', () async {
      final runner = _FakeRunner(await closedProfile());
      final release = Completer<void>();
      runner.whileClosing = () => release.future;
      final subject = coordinator(runner);

      final first = subject.capture(stagingParent: stagingParent);
      await pumpEventQueue();
      expect(subject.isRunning, isTrue);

      await expectLater(
        subject.capture(stagingParent: stagingParent),
        throwsA(isA<ProfileBackupBusyException>()),
      );
      // The refused request closed nothing of its own.
      expect(runner.calls, ['close']);

      release.complete();
      final snapshot = await first;
      expect(subject.isRunning, isFalse);
      expect(snapshot.directory.existsSync(), isTrue);

      runner.whileClosing = null;
      snapshot.directory.deleteSync(recursive: true);
      await expectLater(
        subject.capture(stagingParent: stagingParent),
        completes,
      );
    });

    test('reports a running profile switch as busy', () async {
      final runner = _FakeRunner(await closedProfile())
        ..closeFailure = const ProfileLifecycleBusyException();
      final subject = coordinator(runner);

      await expectLater(
        subject.capture(stagingParent: stagingParent),
        throwsA(isA<ProfileBackupBusyException>()),
      );
      expect(subject.isRunning, isFalse);
      expect(stagingParent.listSync(), isEmpty);
    });

    test('a request cancelled before it starts closes nothing', () async {
      final runner = _FakeRunner(await closedProfile());
      var versionRead = false;
      final cancellation = ProfileBackupCancellation()..cancel();

      await expectLater(
        coordinator(
          runner,
          appVersion: () async {
            versionRead = true;
            return '1';
          },
        ).capture(stagingParent: stagingParent, cancellation: cancellation),
        throwsA(isA<ProfileBackupCancelledException>()),
      );

      expect(runner.calls, isEmpty);
      expect(versionRead, isFalse);
    });

    test('cancelling while the version is read still closes nothing', () async {
      final runner = _FakeRunner(await closedProfile());
      final cancellation = ProfileBackupCancellation();

      await expectLater(
        coordinator(
          runner,
          appVersion: () async {
            cancellation.cancel();
            return '1';
          },
        ).capture(stagingParent: stagingParent, cancellation: cancellation),
        throwsA(isA<ProfileBackupCancelledException>()),
      );

      expect(runner.calls, isEmpty);
    });

    test(
      'cancelling while the profile closes copies nothing and restarts it',
      () async {
        final runner = _FakeRunner(await closedProfile());
        final cancellation = ProfileBackupCancellation();
        runner.whileClosing = cancellation.cancel;
        final copied = <String>[];

        await expectLater(
          coordinator(
            runner,
            hooks: ProfileSnapshotTestHooks(
              afterFileCopied:
                  ({
                    required sourceFile,
                    required targetFile,
                    required relativePath,
                  }) async => copied.add(relativePath),
            ),
          ).capture(stagingParent: stagingParent, cancellation: cancellation),
          throwsA(isA<ProfileBackupCancelledException>()),
        );

        // Not merely cleaned up afterwards: staging never began.
        expect(copied, isEmpty);
        expect(stagingParent.listSync(), isEmpty);
        expect(runner.calls, ['close', 'restart']);
      },
    );

    test('cancelling during staging deletes the published snapshot', () async {
      final runner = _FakeRunner(await closedProfile());
      final cancellation = ProfileBackupCancellation();
      var staged = false;

      await expectLater(
        coordinator(
          runner,
          hooks: ProfileSnapshotTestHooks(
            beforePublish: (_) async {
              staged = true;
              cancellation.cancel();
            },
          ),
        ).capture(stagingParent: stagingParent, cancellation: cancellation),
        throwsA(isA<ProfileBackupCancelledException>()),
      );

      // Staging really completed before the cancellation was honoured.
      expect(staged, isTrue);
      expect(stagingParent.listSync(), isEmpty);
      expect(runner.calls, ['close', 'restart']);
    });

    test('a profile that could not be closed is never copied', () async {
      final runner = _FakeRunner(await closedProfile())
        ..closeFailure = ProfileQuiescenceException([
          ServiceDisposalFailure(
            service: 'JournalDb',
            error: TimeoutException('close'),
            stackTrace: StackTrace.empty,
          ),
        ]);

      await expectLater(
        coordinator(runner).capture(stagingParent: stagingParent),
        throwsA(isA<ProfileQuiescenceException>()),
      );

      expect(stagingParent.listSync(), isEmpty);
      expect(runner.calls, ['close', 'restart']);
    });

    test('a database still open underneath aborts before copying', () async {
      // The second proof: even if every close reported success, a live
      // connection keeps its -wal, and the capture refuses to go on.
      // (Staging refuses companions on its own too; the snapshot service's
      // tests cover that.)
      final closed = await closedProfile();
      final stillOpen = sqlite3.open(p.join(closed.root.path, 'db.sqlite'))
        ..execute('INSERT INTO probe VALUES (?)', ['uncheckpointed']);
      addTearDown(stillOpen.close);
      expect(
        File(p.join(closed.root.path, 'db.sqlite-wal')).existsSync(),
        isTrue,
      );
      final runner = _FakeRunner(closed);

      await expectLater(
        coordinator(runner).capture(stagingParent: stagingParent),
        throwsA(
          isA<ProfileQuiescenceException>().having(
            (e) => e.failures.single.service,
            'database',
            'db.sqlite',
          ),
        ),
      );

      expect(stagingParent.listSync(), isEmpty);
      expect(runner.calls, ['close', 'restart']);
    });
  });

  group('with a real profile generation', () {
    const channels = [
      'plugins.flutter.io/path_provider',
      'plugins.it_nomads.com/flutter_secure_storage',
      'window_manager',
    ];

    test('a write committed while the app runs is in the snapshot, and the '
        'profile comes back', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (MethodCall call) async =>
              channel == channels.first ? registry.realRoot.path : null,
        );
      }
      addTearDown(() async {
        await settlePendingDbWork();
        await ServiceDisposer(getIt, (e, s, n) {}).disposeAll();
        await getIt.reset();
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), null);
        }
      });

      await getIt.reset();
      // A guest world: the full service generation, without the sync stack
      // that would need Matrix credentials.
      final guest = await registry.createGuestProfile(name: 'Demo');
      await registry.setActiveProfile(guest.id);
      final holder = AppLifecycleHolder();
      addTearDown(holder.dispose);
      registerProcessLogging();
      await bootstrapProfileServices(
        await resolveActiveProfile(),
        lifecycleHolder: holder,
        restoreWindow: false,
      );
      await settlePendingDbWork();

      final settingsBefore = getIt<SettingsDb>();
      await settingsBefore.saveSettingsItem('backup_probe', 'committed');
      final settingsFile = p.join(
        registry.rootFor(guest).path,
        'settings.sqlite',
      );
      // The commit is still only in the WAL when the backup starts.
      expect(File('$settingsFile-wal').existsSync(), isTrue);

      final calls = <String>[];
      final switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: holder,
        onSwitchStarted: () async => calls.add('splash'),
        onSwitchCompleted: () => calls.add('completed'),
        settleFrame: () async {},
      );
      final snapshot = await ProfileBackupCoordinator(
        runClosed: switcher.runWithGenerationClosed,
        appVersion: () async => '1.1.23+4404',
      ).capture(stagingParent: stagingParent);

      final staged = sqlite3.open(
        p.join(snapshot.payloadDirectory.path, 'settings.sqlite'),
        mode: OpenMode.readOnly,
      );
      addTearDown(staged.close);
      expect(
        staged.select(
          'SELECT value FROM settings WHERE config_key = ?',
          ['backup_probe'],
        ).single['value'],
        'committed',
      );
      expect(snapshot.manifest.profileType, 'guest');

      // The same profile runs again, on a fresh generation that still sees
      // the write.
      expect(calls, ['splash', 'completed']);
      expect(identical(getIt<SettingsDb>(), settingsBefore), isFalse);
      expect(
        await getIt<SettingsDb>().itemByKey('backup_probe'),
        'committed',
      );
      expect((await registry.load()).activeProfileId, guest.id);
    });
  });
}
