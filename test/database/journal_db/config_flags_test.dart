import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/utils/consts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JournalDb db;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('lotti_config_flags_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => tempDir.path,
        );
    db = JournalDb(inMemoryDatabase: true, background: false, readPool: 0);
  });

  tearDown(() async {
    // Reset to a clean, fully-defaulted flag set so each test is
    // order-independent. The only flag any test mutates is the restored
    // Daily OS rollout flag ("preserves existing flag status when re-run");
    // restoring it to its
    // default `false` via [upsertConfigFlag] keeps both the DB row and the
    // in-memory flag cache in sync.
    if (await db.getConfigFlagByName(enableDailyOsPageFlag) != null) {
      await db.upsertConfigFlag(
        const ConfigFlag(
          name: enableDailyOsPageFlag,
          description: 'Enable DailyOS Page?',
          status: false,
        ),
      );
    }
  });

  tearDownAll(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<bool?> getStatus(String name) async {
    final flag = await db.getConfigFlagByName(name);
    return flag?.status;
  }

  group('initConfigFlags', () {
    test('inserts every expected flag with the documented default', () async {
      await initConfigFlags(db, inMemoryDatabase: true);

      // Defaults must match the source: flags here are listed with the
      // expected initial status.
      const defaults = <String, bool>{
        privateFlag: true,
        enableMatrixFlag: false,
        enableTooltipFlag: true,
        enableAiStreamingFlag: true,
        enableAiSummaryTtsFlag: false,
        recordLocationFlag: false,
        resendAttachments: false,
        enableLoggingFlag: false,
        enableNotificationsFlag: false,
        enableHabitsPageFlag: false,
        enableDashboardsPageFlag: false,
        enableDailyOsPageFlag: false,
        enableEventsFlag: false,
        enableSessionRatingsFlag: false,
        enableProjectsFlag: false,
        logSlowQueriesFlag: false,
        enableEmbeddingsFlag: false,
        enableVectorSearchFlag: false,
        enableWhatsNewFlag: false,
        // Dark-launched until production testing concludes. The prepared
        // rollout migration force-enables it when its release lever is
        // intentionally pulled.
        dailyOsOnboardingEnabledFlag: false,
      };

      for (final entry in defaults.entries) {
        final flag = await db.getConfigFlagByName(entry.key);
        expect(flag, isNotNull, reason: 'flag missing: ${entry.key}');
        expect(
          flag!.status,
          entry.value,
          reason: 'flag default mismatch: ${entry.key}',
        );
      }
    });

    test('every flag has a non-empty description', () async {
      await initConfigFlags(db, inMemoryDatabase: true);
      final all = await db.watchConfigFlags().first;
      expect(all, isNotEmpty);
      for (final flag in all) {
        expect(
          flag.description.trim(),
          isNotEmpty,
          reason: 'flag ${flag.name} has empty description',
        );
      }
    });

    test(
      'seeds one flag per LogDomain with its default-enabled status',
      () async {
        await initConfigFlags(db, inMemoryDatabase: true);

        for (final domain in LogDomain.values) {
          final flag = await db.getConfigFlagByName(domain.flagName);
          expect(flag, isNotNull, reason: 'missing flag: ${domain.flagName}');
          expect(
            flag!.status,
            domain.defaultEnabled,
            reason: 'default mismatch for ${domain.flagName}',
          );
        }
      },
    );

    test('preserves existing flag status when re-run', () async {
      await initConfigFlags(db, inMemoryDatabase: true);
      // An existing install enabled Daily OS before the rollout flag was
      // temporarily removed from the app's seed list.
      final flag = await db.getConfigFlagByName(enableDailyOsPageFlag);
      await db.upsertConfigFlag(flag!.copyWith(status: !flag.status));
      expect(await getStatus(enableDailyOsPageFlag), isTrue);

      // Re-running init should not reset their toggle.
      await initConfigFlags(db, inMemoryDatabase: true);
      expect(await getStatus(enableDailyOsPageFlag), isTrue);
    });

    test(
      'is idempotent: running twice does not duplicate or change defaults',
      () async {
        await initConfigFlags(db, inMemoryDatabase: true);
        final firstAll = await db.watchConfigFlags().first;
        final firstNames = firstAll.map((f) => f.name).toSet();

        await initConfigFlags(db, inMemoryDatabase: true);
        final secondAll = await db.watchConfigFlags().first;
        final secondNames = secondAll.map((f) => f.name).toSet();

        expect(secondAll.length, firstAll.length);
        expect(secondNames, firstNames);
      },
    );

    test('deletes retired flags left behind by older installs', () async {
      // Dropping a seed call is not enough: upgraded installs retain the
      // persisted row and keep emitting it to flag observers. Simulate those
      // installs by writing every retired row back before initialization.
      for (final retired in retiredConfigFlags) {
        await db.upsertConfigFlag(
          ConfigFlag(
            name: retired,
            description: 'Retired test flag: $retired',
            status: true,
          ),
        );
        expect(await db.getConfigFlagByName(retired), isNotNull);
      }

      await initConfigFlags(db, inMemoryDatabase: true);

      final names = (await db.watchConfigFlags().first)
          .map((f) => f.name)
          .toSet();
      for (final retired in retiredConfigFlags) {
        expect(await db.getConfigFlagByName(retired), isNull);
        expect(names, isNot(contains(retired)));
      }
    });

    test('a retired flag is never seeded, not even transiently', () async {
      // Asserting the final table state cannot catch the mistake this guards:
      // a flag left in the seed calls *and* listed as retired is inserted and
      // then deleted within the same `initConfigFlags` run, so the table ends
      // up correct while every start pays an insert, a delete and two stream
      // emissions. Watch what the flag stream actually emits instead.
      for (final retired in retiredConfigFlags) {
        await db.deleteConfigFlag(retired);
      }

      final emitted = <String>{};
      final subscription = db.watchConfigFlags().listen((flags) {
        emitted.addAll(flags.map((flag) => flag.name));
      });
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await initConfigFlags(db, inMemoryDatabase: true);
      await pumpEventQueue();

      for (final retired in retiredConfigFlags) {
        expect(
          emitted,
          isNot(contains(retired)),
          reason:
              '$retired is retired but still seeded by initConfigFlags, so '
              'every start inserts and then deletes it again',
        );
      }
    });
  });
}
