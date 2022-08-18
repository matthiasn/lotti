import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/utils/consts.dart';

final expectedActiveFlagNames = Platform.isMacOS
    ? {
        privateFlag,
        hideForScreenshotFlag,
        listenToScreenshotHotkeyFlag,
        enableSyncInboxFlag,
        enableSyncOutboxFlag,
      }
    : {
        privateFlag,
        hideForScreenshotFlag,
        enableSyncInboxFlag,
        enableSyncOutboxFlag,
      };

final expectedFlags = <ConfigFlag>{
  ConfigFlag(
    name: privateFlag,
    description: 'Show private entries?',
    status: true,
  ),
  ConfigFlag(
    name: notifyExceptionsFlag,
    description: 'Notify when exceptions occur?',
    status: false,
  ),
  ConfigFlag(
    name: hideForScreenshotFlag,
    description: 'Hide Lotti when taking screenshots?',
    status: true,
  ),
  ConfigFlag(
    name: showTasksTabFlag,
    description: 'Show Tasks tab?',
    status: false,
  ),
  ConfigFlag(
    name: showBrightSchemeFlag,
    description: 'Show Bright ☀️ scheme?',
    status: false,
  ),
  ConfigFlag(
    name: showThemeConfigFlag,
    description: 'Show Theme Config UI?',
    status: false,
  ),
  ConfigFlag(
    name: allowInvalidCertFlag,
    description: 'Allow invalid certificate? (not recommended)',
    status: false,
  ),
  ConfigFlag(
    name: enableSyncInboxFlag,
    description: 'Enable sync inbox? (requires restart)',
    status: true,
  ),
  ConfigFlag(
    name: enableSyncOutboxFlag,
    description: 'Enable sync outbox? (requires restart)',
    status: true,
  ),
  ConfigFlag(
    name: enableBeamerNavFlag,
    description: 'Show new navigation (in progress)',
    status: false,
  ),
};

final expectedMacFlags = <ConfigFlag>{
  ConfigFlag(
    name: listenToScreenshotHotkeyFlag,
    description: 'Listen to global screenshot hotkey?',
    status: true,
  ),
  ConfigFlag(
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
      await db?.initConfigFlags();
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
          ConfigFlag(
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
          ConfigFlag(
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
          ConfigFlag(
            name: showBrightSchemeFlag,
            description: 'Show Bright ☀️ scheme?',
            status: false,
          ),
        );

        await db?.toggleConfigFlag(showBrightSchemeFlag);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlag),
          ConfigFlag(
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
