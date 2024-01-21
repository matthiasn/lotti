import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/utils/consts.dart';

final expectedActiveFlagNames = {
  privateFlag,
  enableSyncFlag,
};

final expectedFlags = <ConfigFlag>{
  const ConfigFlag(
    name: privateFlag,
    description: 'Show private entries?',
    status: true,
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
};

final expectedMacFlags = <ConfigFlag>{
  const ConfigFlag(
    name: enableNotificationsFlag,
    description: 'Enable desktop notifications?',
    status: false,
  ),
};

void main() {
  JournalDb? db;

  group('Database Tests - ', () {
    setUp(() async {
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
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
      'Active config flag names are shown as expected',
      () async {
        final flags = await db?.watchActiveConfigFlagNames().first;
        expect(flags, expectedActiveFlagNames);
      },
    );

    test(
      'Toggle config flag works',
      () async {
        expect(
          await db?.watchActiveConfigFlagNames().first,
          expectedActiveFlagNames,
        );

        expect(
          await db?.watchActiveConfigFlagNames().first,
          expectedActiveFlagNames,
        );
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
