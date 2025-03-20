import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

final expectedActiveFlagNames = {
  privateFlag,
  enableSyncFlag,
  enableTooltipFlag,
};

final expectedFlags = <ConfigFlag>{
  const ConfigFlag(
    name: privateFlag,
    description: 'Show private entries?',
    status: true,
  ),
  const ConfigFlag(
    name: attemptEmbedding,
    description: 'Create LLM embedding',
    status: false,
  ),
  const ConfigFlag(
    name: autoTranscribeFlag,
    description: 'Automatically transcribe audio',
    status: false,
  ),
  const ConfigFlag(
    name: recordLocationFlag,
    description: 'Record geolocation?',
    status: false,
  ),
  const ConfigFlag(
    name: allowInvalidCertFlag,
    description: 'Allow invalid certificate? (not recommended)',
    status: false,
  ),
  const ConfigFlag(
    name: enableSyncFlag,
    description: 'Enable sync? (requires restart)',
    status: true,
  ),
  const ConfigFlag(
    name: enableMatrixFlag,
    description: 'Enable Matrix Sync',
    status: false,
  ),
  const ConfigFlag(
    name: releaseHideLinkedEntries,
    description: 'Release hiding linked entries',
    status: false,
  ),
  const ConfigFlag(
    name: enableTooltipFlag,
    description: 'Enable Tooltips',
    status: true,
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
    name: useCloudInferenceFlag,
    description: 'Use Cloud Inference',
    status: false,
  ),
};

final expectedMacFlags = <ConfigFlag>{
  const ConfigFlag(
    name: enableNotificationsFlag,
    description: 'Enable notifications?',
    status: false,
  ),
};

void main() {
  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();

  group('Database Tests - ', () {
    setUp(() async {
      getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );
    });
    tearDown(() async {
      await db?.close();
      getIt.unregister<UpdateNotifications>();
    });

    test(
      'Config flags are initialized as expected',
      () async {
        final flags = await db?.watchConfigFlags().first;

        if (Platform.isMacOS) {
          expect(flags, expectedFlags.union(expectedMacFlags));
        } else {
          expect(flags, expectedFlags);
        }
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
  });
}
