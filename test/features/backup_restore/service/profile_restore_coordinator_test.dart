import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_bundle_header.dart';
import 'package:lotti/features/backup_restore/domain/profile_backup_catalog.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_bundle_codec.dart';
import 'package:lotti/features/backup_restore/service/profile_backup_coordinator.dart';
import 'package:lotti/features/backup_restore/service/profile_restore_coordinator.dart';
import 'package:lotti/features/backup_restore/service/profile_restore_preflight.dart';
import 'package:lotti/features/backup_restore/service/profile_root_swap.dart';
import 'package:lotti/features/backup_restore/service/quiesced_profile_snapshot_service.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/service_disposer.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../helpers/db_settle.dart';

const _kdf = BackupKdfParameters(memoryKiB: 64, iterations: 1, parallelism: 1);
const _passphrase = 'correct horse battery staple';

/// Follows [ProfileSwitcher.runWithGenerationClosed]'s contract without a
/// service generation: work, then a check, then a rollback if the check
/// fails. Hooks let a test fail the close or reach into the closed window.
class _FakeRunner {
  _FakeRunner(this.closed);

  ClosedProfileGeneration closed;
  final calls = <String>[];
  Exception? closeFailure;
  FutureOr<void> Function()? beforeWork;

  Future<void> run(
    Future<void> Function(ClosedProfileGeneration closed) whileClosed, {
    Future<void> Function()? verifyRestarted,
    Future<void> Function()? rollBack,
  }) async {
    calls.add('close');
    final failure = closeFailure;
    if (failure != null) {
      calls.add('restart');
      throw failure;
    }
    await beforeWork?.call();
    try {
      await whileClosed(closed);
    } on ProfileRestartException {
      calls.add('stuck');
      rethrow;
    } catch (_) {
      calls.add('restart');
      rethrow;
    }
    calls.add('restart');
    try {
      await verifyRestarted?.call();
      calls.add('verified');
    } catch (e, st) {
      calls.add('rollBack');
      await rollBack?.call();
      calls.add('restart');
      throw ProfileRolledBackException(e, st);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testRoot;
  late Directory profileRoot;
  late Directory bundles;

  setUp(() {
    testRoot = Directory.systemTemp.createTempSync('lotti_restore_coord_');
    profileRoot = Directory(p.join(testRoot.path, 'profile'))..createSync();
    bundles = Directory(p.join(testRoot.path, 'bundles'));
  });

  tearDown(() => testRoot.deleteSync(recursive: true));

  ProfileBackupBundleCodec codec() => ProfileBackupBundleCodec(kdf: _kdf);

  void writeDatabase(Directory root, String name, String value) {
    final database = sqlite3.open(p.join(root.path, name));
    try {
      database
        ..execute('CREATE TABLE probe (value TEXT)')
        ..execute('INSERT INTO probe VALUES (?)', [value]);
    } finally {
      database.close();
    }
  }

  String probe(Directory root, String name) {
    final database = sqlite3.open(
      p.join(root.path, name),
      mode: OpenMode.readOnly,
    );
    try {
      return database.select('SELECT value FROM probe').single['value']
          as String;
    } finally {
      database.close();
    }
  }

  /// A backup whose journal says [value].
  Future<File> backupSaying(String value) async {
    final source = Directory(p.join(testRoot.path, 'source-$value'))
      ..createSync();
    writeDatabase(source, 'db.sqlite', value);
    writeDatabase(source, 'settings.sqlite', 'settings $value');
    final snapshot = await QuiescedProfileSnapshotService().stage(
      sourceRoot: source,
      stagingParent: Directory(p.join(testRoot.path, 'staging')),
      appVersion: '1.1.24+4410',
      profileType: 'real',
    );
    return codec().package(
      snapshot: snapshot,
      outputDirectory: bundles,
      passphrase: _passphrase,
    );
  }

  Future<ProfileContext> realProfile() async {
    final registry = ProfileRegistry(realRoot: profileRoot);
    final profile = (await registry.load()).profileById(
      Profile.realProfileId,
    )!;
    return ProfileContext.forProfile(profile: profile, root: profileRoot);
  }

  ProfileRestoreCoordinator coordinator(
    _FakeRunner runner,
    ProfileContext profile, {
    Future<void> Function()? verify,
  }) => ProfileRestoreCoordinator(
    runClosed: runner.run,
    currentProfile: () => profile,
    preflight: ProfileRestorePreflight(
      codec: codec(),
      restoreIdGenerator: () => 'r1',
    ),
    verifyRestarted: verify ?? () async {},
  );

  Directory work() =>
      Directory(p.join(profileRoot.path, profileRestoreWorkDirectoryName));

  group('ProfileRestoreCoordinator', () {
    late ProfileContext profile;
    late _FakeRunner runner;

    setUp(() async {
      writeDatabase(profileRoot, 'db.sqlite', 'current');
      writeDatabase(profileRoot, 'settings.sqlite', 'settings current');
      File(p.join(profileRoot.path, 'profiles.json')).writeAsStringSync('{}');
      profile = await realProfile();
      runner = _FakeRunner(
        ClosedProfileGeneration(profile: profile.profile, root: profileRoot),
      );
    });

    test('replaces the profile, keeps it once it proves healthy', () async {
      final bundle = await backupSaying('restored');

      final manifest = await coordinator(
        runner,
        profile,
      ).restore(bundle: bundle, passphrase: _passphrase);

      expect(manifest.profileType, 'real');
      expect(runner.calls, ['close', 'restart', 'verified']);
      expect(probe(profileRoot, 'db.sqlite'), 'restored');
      expect(probe(profileRoot, 'settings.sqlite'), 'settings restored');
      // Device entries stay; nothing of the restore is left over.
      expect(
        File(p.join(profileRoot.path, 'profiles.json')).readAsStringSync(),
        '{}',
      );
      expect(work().existsSync(), isFalse);
    });

    test('a restored profile that fails its check is rolled back', () async {
      final bundle = await backupSaying('restored');

      await expectLater(
        coordinator(
          runner,
          profile,
          verify: () async => throw StateError('migration failed'),
        ).restore(bundle: bundle, passphrase: _passphrase),
        throwsA(isA<ProfileRolledBackException>()),
      );

      expect(runner.calls, [
        'close',
        'restart',
        'rollBack',
        'restart',
      ]);
      expect(probe(profileRoot, 'db.sqlite'), 'current');
      expect(work().existsSync(), isFalse);
    });

    test('a bundle that cannot be read never closes the profile', () async {
      final bundle = await backupSaying('restored');

      await expectLater(
        coordinator(
          runner,
          profile,
        ).restore(bundle: bundle, passphrase: 'not the passphrase'),
        throwsA(isA<ProfileBackupWrongPassphraseException>()),
      );

      expect(runner.calls, isEmpty);
      expect(probe(profileRoot, 'db.sqlite'), 'current');
      expect(work().existsSync(), isFalse);
    });

    test('refuses a second restore while one runs', () async {
      final bundle = await backupSaying('restored');
      final release = Completer<void>();
      runner.beforeWork = () => release.future;
      final subject = coordinator(runner, profile);

      final first = subject.restore(bundle: bundle, passphrase: _passphrase);
      while (runner.calls.isEmpty) {
        await pumpEventQueue();
      }
      expect(subject.isRunning, isTrue);
      await expectLater(
        subject.restore(bundle: bundle, passphrase: _passphrase),
        throwsA(isA<ProfileRestoreBusyException>()),
      );

      release.complete();
      await first;
      expect(subject.isRunning, isFalse);
      expect(probe(profileRoot, 'db.sqlite'), 'restored');
    });

    test('a running profile switch is reported as busy and the staged copy '
        'removed', () async {
      final bundle = await backupSaying('restored');
      runner.closeFailure = const ProfileLifecycleBusyException();

      await expectLater(
        coordinator(
          runner,
          profile,
        ).restore(bundle: bundle, passphrase: _passphrase),
        throwsA(isA<ProfileRestoreBusyException>()),
      );

      expect(probe(profileRoot, 'db.sqlite'), 'current');
      expect(work().existsSync(), isFalse);
    });

    test('a profile that cannot be closed cleanly is not replaced', () async {
      final bundle = await backupSaying('restored');
      runner.closeFailure = ProfileQuiescenceException([
        ServiceDisposalFailure(
          service: 'JournalDb',
          error: TimeoutException('close'),
          stackTrace: StackTrace.empty,
        ),
      ]);

      await expectLater(
        coordinator(
          runner,
          profile,
        ).restore(bundle: bundle, passphrase: _passphrase),
        throwsA(isA<ProfileQuiescenceException>()),
      );

      expect(probe(profileRoot, 'db.sqlite'), 'current');
      expect(work().existsSync(), isFalse);
    });

    test('refuses to swap if the active profile changed meanwhile', () async {
      final bundle = await backupSaying('restored');
      final elsewhere = Directory(p.join(testRoot.path, 'elsewhere'))
        ..createSync();
      runner.closed = ClosedProfileGeneration(
        profile: profile.profile,
        root: elsewhere,
      );

      await expectLater(
        coordinator(
          runner,
          profile,
        ).restore(bundle: bundle, passphrase: _passphrase),
        throwsA(
          isA<ProfileRestoreIncompatibleException>().having(
            (e) => e.message,
            'message',
            contains('active profile changed'),
          ),
        ),
      );

      expect(probe(profileRoot, 'db.sqlite'), 'current');
      expect(work().existsSync(), isFalse);
    });

    test(
      'a swap that fails halfway is undone before anything starts',
      () async {
        final bundle = await backupSaying('restored');
        // Something in the incoming payload collides with a device entry, so
        // moving in fails after the profile already moved out.
        runner.beforeWork = () {
          final payload = Directory(
            p.join(work().path, 'incoming-r1', 'payload'),
          );
          File(p.join(payload.path, 'profiles.json')).writeAsStringSync('x');
        };

        await expectLater(
          coordinator(
            runner,
            profile,
          ).restore(bundle: bundle, passphrase: _passphrase),
          throwsA(isA<Exception>()),
        );

        expect(runner.calls, ['close', 'restart']);
        expect(probe(profileRoot, 'db.sqlite'), 'current');
        expect(
          File(p.join(profileRoot.path, 'profiles.json')).readAsStringSync(),
          '{}',
        );
        expect(work().existsSync(), isFalse);
      },
    );

    test('a swap whose undo also fails leaves the profile closed for the '
        'next launch', () async {
      final bundle = await backupSaying('restored');
      runner.beforeWork = () {
        File(
          p.join(work().path, 'incoming-r1', 'payload', 'profiles.json'),
        ).writeAsStringSync('x');
        // The undo needs this folder; a file in its place makes it fail.
        File(p.join(work().path, 'failed-r1')).writeAsStringSync('blocker');
      };

      await expectLater(
        coordinator(
          runner,
          profile,
        ).restore(bundle: bundle, passphrase: _passphrase),
        throwsA(isA<ProfileRestartException>()),
      );

      // Never restarted onto the half-swapped folder, and the journal is
      // still there for the next launch to finish the job.
      expect(runner.calls, ['close', 'stuck']);
      expect(ProfileRootSwap.hasPendingRestore(profileRoot), isTrue);
    });

    test('describes being busy', () {
      expect(
        const ProfileRestoreBusyException().toString(),
        contains('a restore, backup or profile switch is running'),
      );
    });
  });

  group('with a real profile generation', () {
    const channels = [
      'plugins.flutter.io/path_provider',
      'plugins.it_nomads.com/flutter_secure_storage',
      'window_manager',
    ];

    late ProfileRegistry registry;
    late ProfileSwitcher switcher;
    late List<String> switcherCalls;
    late Profile guest;

    setUp(() async {
      registry = ProfileRegistry(realRoot: profileRoot);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (MethodCall call) async =>
              channel == channels.first ? profileRoot.path : null,
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
      guest = await registry.createGuestProfile(name: 'Demo');
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

      switcherCalls = [];
      switcher = ProfileSwitcher(
        registry: registry,
        lifecycleHolder: holder,
        onSwitchStarted: () async => switcherCalls.add('splash'),
        onSwitchCompleted: () => switcherCalls.add('completed'),
        settleFrame: () async {},
      );
    });

    /// Backs the running profile up while it says [value].
    Future<File> backUp(String value) async {
      await getIt<SettingsDb>().saveSettingsItem('restore_probe', value);
      final snapshot = await ProfileBackupCoordinator(
        runClosed: switcher.runWithGenerationClosed,
        appVersion: () async => '1.1.24+4410',
      ).capture(stagingParent: Directory(p.join(testRoot.path, 'staging')));
      return codec().package(
        snapshot: snapshot,
        outputDirectory: bundles,
        passphrase: _passphrase,
      );
    }

    ProfileRestoreCoordinator restorer({Future<void> Function()? verify}) =>
        ProfileRestoreCoordinator(
          runClosed: switcher.runWithGenerationClosed<void>,
          preflight: ProfileRestorePreflight(codec: codec()),
          verifyRestarted: verify,
        );

    test('restores the backed-up state over a live profile', () async {
      final bundle = await backUp('from the backup');
      await getIt<SettingsDb>().saveSettingsItem('restore_probe', 'later');
      final before = getIt<SettingsDb>();

      // The production defaults: the codec takes its key-derivation cost
      // from the bundle, so the default preflight opens it as it is.
      await ProfileRestoreCoordinator(
        runClosed: switcher.runWithGenerationClosed<void>,
      ).restore(bundle: bundle, passphrase: _passphrase);

      // A fresh generation, reading the restored databases.
      expect(identical(getIt<SettingsDb>(), before), isFalse);
      expect(
        await getIt<SettingsDb>().itemByKey('restore_probe'),
        'from the backup',
      );
      expect(getIt<ProfileContext>().profile.id, guest.id);
      expect(
        Directory(
          p.join(registry.rootFor(guest).path, profileRestoreWorkDirectoryName),
        ).existsSync(),
        isFalse,
      );
    });

    test('a restored profile that fails its check leaves the live one as it '
        'was', () async {
      final bundle = await backUp('from the backup');
      await getIt<SettingsDb>().saveSettingsItem('restore_probe', 'later');

      await expectLater(
        restorer(
          verify: () async => throw StateError('migration failed'),
        ).restore(bundle: bundle, passphrase: _passphrase),
        throwsA(isA<ProfileRolledBackException>()),
      );

      expect(await getIt<SettingsDb>().itemByKey('restore_probe'), 'later');
      expect(switcherCalls.last, 'completed');
      expect(
        Directory(
          p.join(registry.rootFor(guest).path, profileRestoreWorkDirectoryName),
        ).existsSync(),
        isFalse,
      );
    });

    test('opens every database of the restored generation', () async {
      await expectLater(verifyProfileDatabasesOpen(), completes);
    });
  });
}
