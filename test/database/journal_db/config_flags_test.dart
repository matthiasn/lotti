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
    // order-independent. The only flag any test mutates is [enableMatrixFlag]
    // ("preserves existing flag status when re-run"); restoring it to its
    // default `false` via [upsertConfigFlag] keeps both the DB row and the
    // in-memory flag cache in sync.
    if (await db.getConfigFlagByName(enableMatrixFlag) != null) {
      await db.upsertConfigFlag(
        const ConfigFlag(
          name: enableMatrixFlag,
          description: 'Enable Matrix Sync',
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
        enableEventsFlag: false,
        enableDailyOsPageFlag: false,
        dailyOsNextEnabledFlag: false,
        enableSessionRatingsFlag: false,
        enableSyncActorFlag: false,
        enableProjectsFlag: false,
        logSlowQueriesFlag: false,
        enableEmbeddingsFlag: false,
        enableVectorSearchFlag: false,
        enableWhatsNewFlag: false,
        showSyncActivityIndicatorFlag: false,
        showSidebarWakeQueueFlag: false,
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
      // User toggles a flag.
      await db.toggleConfigFlag(enableMatrixFlag);
      expect(await getStatus(enableMatrixFlag), isTrue);

      // Re-running init should not reset their toggle.
      await initConfigFlags(db, inMemoryDatabase: true);
      expect(await getStatus(enableMatrixFlag), isTrue);
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
  });
}
