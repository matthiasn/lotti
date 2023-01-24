import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/utils/consts.dart';

final expectedActiveFlagNames = Platform.isMacOS
    ? {
        privateFlag,
        enableSyncInboxFlag,
        enableSyncOutboxFlag,
      }
    : {
        privateFlag,
        enableSyncInboxFlag,
        enableSyncOutboxFlag,
      };

final expectedFlags = <ConfigFlag>{
  const ConfigFlag(
    name: privateFlag,
    description: 'Show private entries?',
    status: true,
  ),
  const ConfigFlag(
    name: showBrightSchemeFlag,
    description: 'Show Bright ☀️ scheme?',
    status: false,
  ),
  const ConfigFlag(
    name: allowInvalidCertFlag,
    description: 'Allow invalid certificate? (not recommended)',
    status: false,
  ),
  const ConfigFlag(
    name: enableSyncInboxFlag,
    description: 'Enable sync inbox? (requires restart)',
    status: true,
  ),
  const ConfigFlag(
    name: enableSyncOutboxFlag,
    description: 'Enable sync outbox? (requires restart)',
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
      await initConfigFlags(db!);
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

        await db?.toggleConfigFlag(showBrightSchemeFlag);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlag),
          const ConfigFlag(
            name: showBrightSchemeFlag,
            description: 'Show Bright ☀️ scheme?',
            status: true,
          ),
        );

        expect(
          await db?.watchActiveConfigFlagNames().first,
          expectedActiveFlagNames.union({showBrightSchemeFlag}),
        );

        await db?.toggleConfigFlag(showBrightSchemeFlag);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlag),
          const ConfigFlag(
            name: showBrightSchemeFlag,
            description: 'Show Bright ☀️ scheme?',
            status: false,
          ),
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
          await db?.getConfigFlagByName(showBrightSchemeFlag),
          const ConfigFlag(
            name: showBrightSchemeFlag,
            description: 'Show Bright ☀️ scheme?',
            status: false,
          ),
        );

        await db?.toggleConfigFlag(showBrightSchemeFlag);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlag),
          const ConfigFlag(
            name: showBrightSchemeFlag,
            description: 'Show Bright ☀️ scheme?',
            status: true,
          ),
        );

        expect(await db?.getConfigFlagByName('invalid'), null);
      },
    );
  });
}
