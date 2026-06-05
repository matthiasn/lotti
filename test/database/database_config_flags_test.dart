import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

final Set<String> expectedActiveFlagNames = {
  privateFlag,
  enableTooltipFlag,
  enableAiStreamingFlag,
  for (final domain in LogDomain.values)
    if (domain.defaultEnabled) domain.flagName,
};

final expectedFlags = <ConfigFlag>{
  const ConfigFlag(
    name: privateFlag,
    description: 'Show private entries?',
    status: true,
  ),
  const ConfigFlag(
    name: recordLocationFlag,
    description: 'Record geolocation?',
    status: false,
  ),
  // enableSyncFlag removed; enableMatrixFlag is the source of truth for sync visibility
  const ConfigFlag(
    name: enableMatrixFlag,
    description: 'Enable Matrix Sync',
    status: false,
  ),
  const ConfigFlag(
    name: enableTooltipFlag,
    description: 'Enable Tooltips',
    status: true,
  ),
  const ConfigFlag(
    name: enableAiStreamingFlag,
    description: 'Enable AI streaming responses?',
    status: true,
  ),
  const ConfigFlag(
    name: enableAiSummaryTtsFlag,
    description: 'Enable local AI summary playback?',
    status: false,
  ),
  const ConfigFlag(
    name: resendAttachments,
    description: 'Resend Attachments',
    status: false,
  ),
  const ConfigFlag(
    name: enableLoggingFlag,
    description: 'Enable logging?',
    status: false,
  ),
  const ConfigFlag(
    name: enableHabitsPageFlag,
    description: 'Enable Habits Page?',
    status: false,
  ),
  const ConfigFlag(
    name: enableDashboardsPageFlag,
    description: 'Enable Dashboards Page?',
    status: false,
  ),
  const ConfigFlag(
    name: enableNotificationsFlag,
    description: 'Enable notifications?',
    status: false,
  ),
  const ConfigFlag(
    name: enableEventsFlag,
    description: 'Enable Events?',
    status: false,
  ),
  const ConfigFlag(
    name: enableDailyOsPageFlag,
    description: 'Enable DailyOS Page?',
    status: false,
  ),
  const ConfigFlag(
    name: dailyOsNextEnabledFlag,
    description: 'Use the next-generation agentic DailyOS surface?',
    status: false,
  ),
  const ConfigFlag(
    name: enableSessionRatingsFlag,
    description: 'Enable session ratings?',
    status: false,
  ),
  const ConfigFlag(
    name: enableSyncActorFlag,
    description: 'Enable Sync Actor (isolate-based sync)?',
    status: false,
  ),
  const ConfigFlag(
    name: enableProjectsFlag,
    description: 'Enable Projects?',
    status: false,
  ),
  for (final domain in LogDomain.values)
    ConfigFlag(
      name: domain.flagName,
      description: 'Log ${domain.label}',
      status: domain.defaultEnabled,
    ),
  const ConfigFlag(
    name: logSlowQueriesFlag,
    description: 'Log slow database queries',
    status: false,
  ),
  const ConfigFlag(
    name: enableEmbeddingsFlag,
    description: 'Generate embeddings for entries?',
    status: false,
  ),
  const ConfigFlag(
    name: enableVectorSearchFlag,
    description: 'Enable vector search UI?',
    status: false,
  ),
  const ConfigFlag(
    name: enableSyncedAlertsFlag,
    description: 'Enable synced alerts?',
    status: false,
  ),
  const ConfigFlag(
    name: enableWhatsNewFlag,
    description: "Enable What's New feature?",
    status: false,
  ),
  const ConfigFlag(
    name: showSyncActivityIndicatorFlag,
    description: 'Show live sync activity in the sidebar.',
    status: false,
  ),
  const ConfigFlag(
    name: showSidebarWakeQueueFlag,
    description: 'Show the inline Wake Queue in the sidebar.',
    status: false,
  ),
  const ConfigFlag(
    name: enableForkHealingFlag,
    description: 'Enable agent fork healing?',
    status: false,
  ),
};

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb config flags - ', () {
    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      await db?.close();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    group('watchConfigFlags before flags loaded -', () {
      test('emits flags after async bootstrap when not yet loaded', () async {
        // Create a fresh db that has NOT had initConfigFlags called yet.
        final freshDb = JournalDb(inMemoryDatabase: true);
        addTearDown(freshDb.close);

        // watchConfigFlags is called before flags are loaded; it should still
        // emit a non-null set (possibly empty on a bare db, but no crash).
        final flags = await freshDb.watchConfigFlags().first;
        expect(flags, isNotNull);
      });
    });

    test(
      'Config flags are initialized as expected',
      () async {
        final flags = await db?.watchConfigFlags().first;
        expect(flags, expectedFlags);
      },
    );

    test(
      'ConfigFlag can be retrieved by name',
      () async {
        expect(
          await db?.getConfigFlagByName(recordLocationFlag),
          const ConfigFlag(
            name: recordLocationFlag,
            description: 'Record geolocation?',
            status: false,
          ),
        );

        await db?.toggleConfigFlag(recordLocationFlag);

        expect(
          await db?.getConfigFlagByName(recordLocationFlag),
          const ConfigFlag(
            name: recordLocationFlag,
            description: 'Record geolocation?',
            status: true,
          ),
        );

        expect(await db?.getConfigFlagByName('invalid'), null);
      },
    );

    test(
      'watchConfigFlag returns correct flag status as a stream',
      () async {
        final existingFlag = await db!.getConfigFlagByName(recordLocationFlag);
        await db!.upsertConfigFlag(existingFlag!.copyWith(status: false));

        final emittedValuesFuture = db!
            .watchConfigFlag(recordLocationFlag)
            .take(2)
            .toList();
        await db!.toggleConfigFlag(recordLocationFlag);

        expect(await emittedValuesFuture, [false, true]);
      },
    );

    test(
      'watchConfigFlags emits updates from the shared in-memory snapshot',
      () async {
        final existingFlag = await db!.getConfigFlagByName(recordLocationFlag);
        await db!.upsertConfigFlag(existingFlag!.copyWith(status: false));

        final emittedFlagsFuture = db!.watchConfigFlags().take(2).toList();
        await db!.toggleConfigFlag(recordLocationFlag);
        final emittedFlags = await emittedFlagsFuture;
        final initialFlags = emittedFlags.first;
        expect(
          db!.findConfigFlag(recordLocationFlag, initialFlags.toList()),
          false,
        );
        final updatedFlags = emittedFlags.last;

        expect(
          db!.findConfigFlag(recordLocationFlag, updatedFlags.toList()),
          true,
        );
      },
    );

    test(
      'watchActiveConfigFlagNames returns active flag names correctly',
      () async {
        final existingFlag = await db!.getConfigFlagByName(recordLocationFlag);
        await db!.upsertConfigFlag(existingFlag!.copyWith(status: false));

        final emittedFlagsFuture = db!
            .watchActiveConfigFlagNames()
            .take(2)
            .toList();
        await db!.toggleConfigFlag(recordLocationFlag);
        final emittedFlags = await emittedFlagsFuture;
        final activeFlags = emittedFlags.first;
        expect(activeFlags, expectedActiveFlagNames);
        final updatedFlags = emittedFlags.last;
        expect(updatedFlags, {...expectedActiveFlagNames, recordLocationFlag});
      },
    );

    test(
      'findConfigFlag finds config flag status correctly',
      () async {
        final flags = await db?.listConfigFlags().get();
        expect(flags, isNotNull);

        final result = db?.findConfigFlag(privateFlag, flags!);
        expect(result, true);

        final result2 = db?.findConfigFlag(recordLocationFlag, flags!);
        expect(result2, false);

        final result3 = db?.findConfigFlag('non-existent-flag', flags!);
        expect(result3, false);
      },
    );

    test(
      'getConfigFlag retrieves flag value correctly',
      () async {
        expect(await db?.getConfigFlag(privateFlag), true);
        expect(await db?.getConfigFlag(recordLocationFlag), false);
        expect(await db?.getConfigFlag('non-existent-flag'), false);
      },
    );

    test(
      'upsertConfigFlag updates existing flag or inserts new one',
      () async {
        // Update existing flag
        const newFlag = ConfigFlag(
          name: recordLocationFlag,
          description: 'Record geolocation?',
          status: true,
        );

        await db?.upsertConfigFlag(newFlag);
        expect(
          await db?.getConfigFlagByName(recordLocationFlag),
          newFlag,
        );

        // Insert new flag
        const customFlag = ConfigFlag(
          name: 'custom_flag_test',
          description: 'Custom flag for testing',
          status: true,
        );

        await db?.upsertConfigFlag(customFlag);
        expect(
          await db?.getConfigFlagByName('custom_flag_test'),
          customFlag,
        );
      },
    );

    test(
      'insertFlagIfNotExists inserts only if flag does not exist',
      () async {
        // Try to insert existing flag with different status
        const existingFlag = ConfigFlag(
          name: privateFlag,
          description: 'Show private entries?',
          status: false, // Original is true
        );

        await db?.insertFlagIfNotExists(existingFlag);

        // Should still have the original value
        expect(
          await db?.getConfigFlagByName(privateFlag),
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: true,
          ),
        );

        // Insert a new flag
        const newTestFlag = ConfigFlag(
          name: 'test_new_flag',
          description: 'Test new flag insertion',
          status: true,
        );

        await db?.insertFlagIfNotExists(newTestFlag);
        expect(
          await db?.getConfigFlagByName('test_new_flag'),
          newTestFlag,
        );
      },
    );

    group('watchConfigFlags bootstrap failure -', () {
      test(
        'bootstrap errors surface on the stream instead of going unhandled',
        () async {
          final throwingDb = _BootstrapThrowingJournalDb();
          addTearDown(throwingDb.close);

          await expectLater(
            throwingDb.watchConfigFlags().first,
            throwsStateError,
          );
        },
      );
    });

    group('config flags bootstrap -', () {
      test(
        'getConfigFlag bootstraps and loads persisted flags into the cache',
        () async {
          // Persist a flag directly via SQL so the in-memory cache does NOT
          // know about it, then force a fresh bootstrap on a new JournalDb
          // sharing nothing with `db`.
          final freshDb = JournalDb(inMemoryDatabase: true);
          addTearDown(freshDb.close);

          // Seed a flag row before any bootstrap so the bootstrap's
          // listConfigFlags() returns a non-empty set, exercising the
          // change-detection + cache-replacement branch.
          await freshDb
              .into(freshDb.configFlags)
              .insert(
                const ConfigFlag(
                  name: 'bootstrap-test-flag',
                  description: 'Bootstrap test flag',
                  status: true,
                ),
              );

          // Reset the in-memory cache state is not exposed; instead use a
          // brand-new db and read through getConfigFlag which triggers
          // _ensureConfigFlagsLoaded -> _replaceConfigFlags.
          final value = await freshDb.getConfigFlag('bootstrap-test-flag');
          expect(value, isTrue);
          expect(await freshDb.getConfigFlag('missing-flag'), isFalse);
        },
      );

      test(
        'a failed bootstrap is not cached — the next read retries and '
        'succeeds once the underlying query recovers',
        () async {
          final flakyDb = _FlakyBootstrapJournalDb();
          addTearDown(flakyDb.close);

          // The async bootstrap failure propagates to the caller…
          await expectLater(
            flakyDb.getConfigFlag('retry-flag'),
            throwsA(anything),
          );

          // …but must reset the bootstrap future so this read starts a
          // fresh load instead of replaying the cached failure.
          flakyDb.failBootstrap = false;
          await flakyDb
              .into(flakyDb.configFlags)
              .insert(
                const ConfigFlag(
                  name: 'retry-flag',
                  description: 'Retry flag',
                  status: true,
                ),
              );
          expect(await flakyDb.getConfigFlag('retry-flag'), isTrue);
        },
      );
    });
  });
}

/// Forces the lazy config-flag bootstrap to fail so the stream error path
/// in `watchConfigFlags` is exercised.
class _BootstrapThrowingJournalDb extends JournalDb {
  _BootstrapThrowingJournalDb() : super(inMemoryDatabase: true);

  @override
  drift.Selectable<ConfigFlag> listConfigFlags() {
    throw StateError('config flags unavailable');
  }
}

/// Fails the config-flag bootstrap *asynchronously* (the query itself
/// errors, unlike [_BootstrapThrowingJournalDb]'s synchronous throw) so the
/// bootstrap future's failure-reset path is exercised; flipping
/// [failBootstrap] lets the same instance recover afterwards.
class _FlakyBootstrapJournalDb extends JournalDb {
  _FlakyBootstrapJournalDb() : super(inMemoryDatabase: true);

  bool failBootstrap = true;

  @override
  drift.Selectable<ConfigFlag> listConfigFlags() {
    if (failBootstrap) {
      // Querying a non-existent table fails when the statement runs, which
      // is after the bootstrap future has been installed.
      return customSelect('SELECT * FROM no_such_table').map(
        (_) => throw StateError('unreachable - the query itself fails'),
      );
    }
    return super.listConfigFlags();
  }
}
