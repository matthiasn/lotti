import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/features/onboarding/state/onboarding_rollout.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    registerAllFallbackValues();
    // JournalDb resolves a documents directory on construction even in-memory.
    tempDir = Directory.systemTemp.createTempSync('lotti_onboarding_rollout_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => tempDir.path,
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // ---------------------------------------------------------------------
  // Step 2 of the rollout: the one-time force-enable, run from `get_it`.
  //
  // Uses a real in-memory JournalDb rather than a mock: the whole point of
  // this routine is `upsertConfigFlag`'s overwrite semantics winning where
  // `insertFlagIfNotExists` does not, and a mock would assert against a
  // restatement of those semantics instead of the real ones.
  // ---------------------------------------------------------------------
  group('applyOnboardingRolloutFlags', () {
    late JournalDb journalDb;
    late SettingsDb settingsDb;
    late DomainLogger logger;

    setUp(() async {
      journalDb = JournalDb(
        inMemoryDatabase: true,
        background: false,
        readPool: 0,
      );
      settingsDb = SettingsDb(inMemoryDatabase: true);
      logger = DomainLogger(loggingService: LoggingService());
    });

    tearDown(() async {
      await journalDb.close();
      await settingsDb.close();
    });

    Future<void> apply() => applyOnboardingRolloutFlags(
      journalDb: journalDb,
      settingsDb: settingsDb,
      logger: logger,
    );

    Future<bool?> status(String name) async =>
        (await journalDb.getConfigFlagByName(name))?.status;

    Future<String?> marker() =>
        settingsDb.itemByKey(onboardingRolloutFlagsAppliedKey);

    /// Reproduces the beta/dev cohort: a build that seeded these flags while
    /// they still defaulted off, leaving a `false` row that today's `true`
    /// seed default can never overwrite (`insertFlagIfNotExists` is
    /// insert-only).
    Future<void> seedPreRolloutInstall() async {
      await initConfigFlags(journalDb, inMemoryDatabase: true);
      for (final name in onboardingRolloutFlags) {
        final flag = await journalDb.getConfigFlagByName(name);
        await journalDb.upsertConfigFlag(flag!.copyWith(status: false));
      }
    }

    test(
      'force-enables both flags for the beta/dev false-row cohort',
      () async {
        await seedPreRolloutInstall();

        await apply();

        expect(await status(enableOnboardingFtueFlag), isTrue);
        expect(await status(dailyOsOnboardingEnabledFlag), isTrue);
      },
    );

    test('records the marker so the force-enable is one-time', () async {
      await seedPreRolloutInstall();
      expect(await marker(), isNull);

      await apply();

      expect(await marker(), 'true');
    });

    test(
      'a later opt-out survives every subsequent launch — the marker, not the '
      'flag value, is what makes this one-time',
      () async {
        await seedPreRolloutInstall();
        await apply();

        // The user turns both back off in Settings > Advanced > Flags.
        for (final name in onboardingRolloutFlags) {
          await journalDb.toggleConfigFlag(name);
          expect(await status(name), isFalse);
        }

        // Two more launches must not re-force them.
        await apply();
        await apply();

        expect(await status(enableOnboardingFtueFlag), isFalse);
        expect(await status(dailyOsOnboardingEnabledFlag), isFalse);
      },
    );

    test(
      'leaves an already-true row untouched — the fresh-install cohort the '
      'seed default already covers',
      () async {
        // Today's seed defaults are `true`, so a fresh install needs no
        // correction at all.
        await initConfigFlags(journalDb, inMemoryDatabase: true);
        expect(await status(enableOnboardingFtueFlag), isTrue);

        await apply();

        expect(await status(enableOnboardingFtueFlag), isTrue);
        expect(await status(dailyOsOnboardingEnabledFlag), isTrue);
        expect(await marker(), 'true');
      },
    );

    test('preserves the seeded description when flipping a row', () async {
      await seedPreRolloutInstall();
      final before = await journalDb.getConfigFlagByName(
        enableOnboardingFtueFlag,
      );

      await apply();

      final after = await journalDb.getConfigFlagByName(
        enableOnboardingFtueFlag,
      );
      // `config_flags.description` is UNIQUE and the Flags page renders it:
      // the rollout must overwrite only `status`.
      expect(after!.description, before!.description);
      expect(after.name, before.name);
    });

    test('tolerates an unseeded flag row rather than inserting one', () async {
      // `initConfigFlags` never ran (nothing to correct). Absent must stay
      // absent — inserting here would race the seeder's own description.
      await apply();

      expect(await status(enableOnboardingFtueFlag), isNull);
      expect(await status(dailyOsOnboardingEnabledFlag), isNull);
      expect(await marker(), 'true');
    });

    test('skips the flag work entirely once the marker is present', () async {
      await seedPreRolloutInstall();
      await settingsDb.saveSettingsItem(
        onboardingRolloutFlagsAppliedKey,
        'true',
      );

      await apply();

      expect(await status(enableOnboardingFtueFlag), isFalse);
      expect(await status(dailyOsOnboardingEnabledFlag), isFalse);
    });

    test(
      'converges after process death between the flag writes and the marker '
      '— the flag loop is idempotent, so the retry is a no-op plus the marker',
      () async {
        await seedPreRolloutInstall();

        // Launch 1: the flags land, then the process dies before the marker
        // write. Reproduced by driving the same writes `apply()` would and
        // leaving the marker absent -- the exact torn state on disk.
        for (final name in onboardingRolloutFlags) {
          final flag = await journalDb.getConfigFlagByName(name);
          await journalDb.upsertConfigFlag(flag!.copyWith(status: true));
        }
        expect(await marker(), isNull);

        // Launch 2: no opt-out can have interleaved -- the app was dead, and
        // this runs before any UI is reachable.
        await apply();

        expect(await status(enableOnboardingFtueFlag), isTrue);
        expect(await status(dailyOsOnboardingEnabledFlag), isTrue);
        expect(await marker(), 'true');

        // And having converged, a *later* opt-out is now permanent.
        await journalDb.toggleConfigFlag(enableOnboardingFtueFlag);
        await apply();
        expect(await status(enableOnboardingFtueFlag), isFalse);
      },
    );
  });

  // A startup-path failure must never take the app down, and must never
  // burn the marker — the next launch has to be able to retry.
  group('applyOnboardingRolloutFlags — failures are logged and swallowed', () {
    late MockJournalDb journalDb;
    late MockSettingsDb settingsDb;
    late MockDomainLogger logger;

    setUp(() {
      journalDb = MockJournalDb();
      settingsDb = MockSettingsDb();
      logger = MockDomainLogger();
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
    });

    void verifyLogged() => verify(
      () => logger.error(
        LogDomain.onboarding,
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'onboardingRolloutFlags',
      ),
    ).called(1);

    Future<void> apply() => applyOnboardingRolloutFlags(
      journalDb: journalDb,
      settingsDb: settingsDb,
      logger: logger,
    );

    test('a flag read failure logs and leaves the marker unwritten', () async {
      when(
        () => journalDb.getConfigFlagByName(any()),
      ).thenThrow(Exception('db down'));

      await expectLater(apply(), completes);

      verifyLogged();
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });

    test('a flag write failure logs and leaves the marker unwritten', () async {
      when(() => journalDb.getConfigFlagByName(any())).thenAnswer(
        (_) async => const ConfigFlag(
          name: enableOnboardingFtueFlag,
          description: 'Enable the new onboarding (FTUE) flow?',
          status: false,
        ),
      );
      when(() => journalDb.upsertConfigFlag(any())).thenThrow(
        Exception('write failed'),
      );

      await expectLater(apply(), completes);

      verifyLogged();
      verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
    });

    test('a marker read failure logs and does not touch the flags', () async {
      when(() => settingsDb.itemByKey(any())).thenThrow(Exception('db down'));

      await expectLater(apply(), completes);

      verifyLogged();
      verifyNever(() => journalDb.upsertConfigFlag(any()));
    });
  });

  // ---------------------------------------------------------------------
  // Step 3/B1: retire the welcome for installs already set up before the
  // rollout reached them.
  // ---------------------------------------------------------------------
  group('applyOnboardingRolloutBackfill', () {
    late SettingsDb settingsDb;

    setUp(() {
      settingsDb = SettingsDb(inMemoryDatabase: true);
    });

    tearDown(() => settingsDb.close());

    Future<void> backfill({required bool providerReady}) =>
        applyOnboardingRolloutBackfill(
          readProviderReady: () async => providerReady,
          settingsDb: settingsDb,
          logger: DomainLogger(loggingService: LoggingService()),
        );

    Future<String?> completedKey() =>
        settingsDb.itemByKey(onboardingWelcomeCompletedKey);
    Future<String?> marker() =>
        settingsDb.itemByKey(onboardingRolloutBackfillAppliedKey);

    test(
      'retires the welcome for an install that already has a working setup',
      () async {
        await backfill(providerReady: true);

        expect(await completedKey(), 'true');
        expect(await marker(), 'true');
      },
    );

    test(
      'leaves the welcome owed for an un-set-up install — the cohort the '
      'rollout exists to reach',
      () async {
        await backfill(providerReady: false);

        expect(await completedKey(), isNull);
        // Still marked: the question "was this install set up when the
        // rollout arrived?" has been answered, and re-asking it later would
        // retire the welcome mid-flow for a user who connects a provider.
        expect(await marker(), 'true');
      },
    );

    test('does not re-run once the marker is present', () async {
      await settingsDb.saveSettingsItem(
        onboardingRolloutBackfillAppliedKey,
        'true',
      );
      var readinessReads = 0;

      await applyOnboardingRolloutBackfill(
        readProviderReady: () async {
          readinessReads++;
          return true;
        },
        settingsDb: settingsDb,
        logger: DomainLogger(loggingService: LoggingService()),
      );

      expect(readinessReads, 0);
      expect(await completedKey(), isNull);
    });

    test(
      'does not resurrect the welcome for a user who replays it after the '
      'rollout',
      () async {
        // First launch: configured install, welcome retired + marker written.
        await backfill(providerReady: true);
        // The user replays from Settings > Onboarding; the replay path does
        // not clear `welcome_completed`, but a re-run must not re-write it
        // either.
        await settingsDb.removeSettingsItem(onboardingWelcomeCompletedKey);

        await backfill(providerReady: true);

        expect(await completedKey(), isNull);
      },
    );
  });

  group('applyOnboardingRolloutBackfill — failures never suppress the '
      'welcome', () {
    late MockSettingsDb settingsDb;
    late MockDomainLogger logger;

    setUp(() {
      settingsDb = MockSettingsDb();
      logger = MockDomainLogger();
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => settingsDb.saveSettingsItem(any(), any()),
      ).thenAnswer((_) async => 1);
    });

    Future<void> backfill({
      required Future<bool> Function() readProviderReady,
    }) => applyOnboardingRolloutBackfill(
      readProviderReady: readProviderReady,
      settingsDb: settingsDb,
      logger: logger,
    );

    void verifyLogged() => verify(
      () => logger.error(
        LogDomain.onboarding,
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'onboardingRolloutBackfill',
      ),
    ).called(1);

    test(
      'a readiness failure logs, does not retire the welcome, and leaves the '
      'marker unwritten so the next launch retries',
      () async {
        await expectLater(
          backfill(
            readProviderReady: () async => throw Exception('resolver down'),
          ),
          completes,
        );

        verifyLogged();
        verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
      },
    );

    test(
      'a failed retire leaves the marker unwritten so the next launch retries '
      '— never marked-as-migrated with the welcome still owed',
      () async {
        // The retire write fails; every other write would succeed.
        when(
          () => settingsDb.saveSettingsItem(
            onboardingWelcomeCompletedKey,
            any(),
          ),
        ).thenThrow(Exception('write failed'));

        await expectLater(
          backfill(readProviderReady: () async => true),
          completes,
        );

        verifyLogged();
        // The retire must go through the injected db (the throwing
        // `writeOnboardingWelcomeCompleted`), not the swallowing
        // `markOnboardingWelcomeCompleted` that resolves its own `SettingsDb`
        // from `getIt` -- routing it there is exactly the bug this pins: the
        // failure would be swallowed out of sight and the marker written below.
        verify(
          () => settingsDb.saveSettingsItem(
            onboardingWelcomeCompletedKey,
            'true',
          ),
        ).called(1);
        // The whole point: the marker must not record a migration that never
        // landed, or this configured install is stuck being offered the
        // welcome forever.
        verifyNever(
          () => settingsDb.saveSettingsItem(
            onboardingRolloutBackfillAppliedKey,
            any(),
          ),
        );
      },
    );

    test('a marker read failure logs and skips the readiness read', () async {
      when(() => settingsDb.itemByKey(any())).thenThrow(Exception('db down'));
      var readinessReads = 0;

      await expectLater(
        backfill(
          readProviderReady: () async {
            readinessReads++;
            return true;
          },
        ),
        completes,
      );

      verifyLogged();
      expect(readinessReads, 0);
    });
  });

  group('onboardingRolloutBackfillProvider', () {
    late SettingsDb settingsDb;

    setUp(() async {
      settingsDb = SettingsDb(inMemoryDatabase: true);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<SettingsDb>()
            ..registerSingleton<SettingsDb>(settingsDb);
        },
      );
    });

    tearDown(() async {
      await settingsDb.close();
      await tearDownTestGetIt();
    });

    test('wires the Daily OS readiness signal into the backfill', () async {
      final container = ProviderContainer(
        overrides: [
          dailyOsOnboardingProviderReadyProvider.overrideWith(
            (ref) async => true,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(onboardingRolloutBackfillProvider.future);

      expect(
        await settingsDb.itemByKey(onboardingWelcomeCompletedKey),
        'true',
      );
    });

    test(
      'reads readiness once per container, not on every gate rebuild',
      () async {
        var builds = 0;
        final container = ProviderContainer(
          overrides: [
            dailyOsOnboardingProviderReadyProvider.overrideWith((ref) async {
              builds++;
              return false;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(onboardingRolloutBackfillProvider.future);
        await container.read(onboardingRolloutBackfillProvider.future);

        // Not autoDispose: the completed future stays cached, bounding the
        // migration to one run per app session.
        expect(builds, 1);
      },
    );
  });

  // The cohort matrix from the rollout plan, asserted end-to-end against the
  // real seeder, the real force-enable, and the real backfill: flag state and
  // welcome-owed outcome for every install we ship this to.
  group('rollout cohort matrix', () {
    late JournalDb journalDb;
    late SettingsDb settingsDb;

    setUp(() async {
      journalDb = JournalDb(
        inMemoryDatabase: true,
        background: false,
        readPool: 0,
      );
      settingsDb = SettingsDb(inMemoryDatabase: true);
    });

    tearDown(() async {
      await journalDb.close();
      await settingsDb.close();
    });

    /// One full startup for a given cohort: seed flags, force-enable, then run
    /// the readiness-dependent backfill — the same order `registerSingletons()`
    /// and the welcome gate impose at runtime.
    Future<void> startUp({
      required bool hasPreRolloutFlagRows,
      required bool providerReady,
    }) async {
      final logger = DomainLogger(loggingService: LoggingService());
      await initConfigFlags(journalDb, inMemoryDatabase: true);
      if (hasPreRolloutFlagRows) {
        for (final name in onboardingRolloutFlags) {
          final flag = await journalDb.getConfigFlagByName(name);
          await journalDb.upsertConfigFlag(flag!.copyWith(status: false));
        }
      }
      await applyOnboardingRolloutFlags(
        journalDb: journalDb,
        settingsDb: settingsDb,
        logger: logger,
      );
      await applyOnboardingRolloutBackfill(
        readProviderReady: () async => providerReady,
        settingsDb: settingsDb,
        logger: logger,
      );
    }

    Future<bool> welcomeOwed() async =>
        await settingsDb.itemByKey(onboardingWelcomeCompletedKey) != 'true';

    for (final cohort in const [
      // (label, has a pre-rollout `false` flag row, already configured)
      ('fresh install', false, false),
      ('existing user who never ran an FTUE-flag build', false, false),
      ('beta/dev install carrying a false flag row', true, false),
    ]) {
      test('${cohort.$1}: both flags end on and the welcome is owed', () async {
        await startUp(
          hasPreRolloutFlagRows: cohort.$2,
          providerReady: cohort.$3,
        );

        expect(await journalDb.getConfigFlag(enableOnboardingFtueFlag), isTrue);
        expect(
          await journalDb.getConfigFlag(dailyOsOnboardingEnabledFlag),
          isTrue,
        );
        expect(await welcomeOwed(), isTrue);
      });
    }

    test(
      'existing configured user: flags on, welcome retired, Daily OS takes '
      'the beat instead',
      () async {
        await startUp(hasPreRolloutFlagRows: true, providerReady: true);

        expect(await journalDb.getConfigFlag(enableOnboardingFtueFlag), isTrue);
        expect(
          await journalDb.getConfigFlag(dailyOsOnboardingEnabledFlag),
          isTrue,
        );
        expect(await welcomeOwed(), isFalse);
      },
    );

    test(
      'existing user with no working provider: welcome is owed — the cohort '
      'the request calls out',
      () async {
        await startUp(hasPreRolloutFlagRows: true, providerReady: false);

        expect(await welcomeOwed(), isTrue);
      },
    );

    test('a pre-migration opt-out is overridden exactly once', () async {
      // Indistinguishable from the beta/dev cohort by flag value alone, so
      // the rollout force-enables it — the accepted trade-off. What must hold
      // is that the *next* opt-out sticks forever.
      await startUp(hasPreRolloutFlagRows: true, providerReady: false);
      expect(await journalDb.getConfigFlag(enableOnboardingFtueFlag), isTrue);

      await journalDb.toggleConfigFlag(enableOnboardingFtueFlag);
      await startUp(hasPreRolloutFlagRows: false, providerReady: false);

      expect(await journalDb.getConfigFlag(enableOnboardingFtueFlag), isFalse);
    });
  });
}
