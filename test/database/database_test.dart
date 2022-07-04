import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/utils/consts.dart';

final expectedActiveFlagNames = Platform.isMacOS
    ? {
        'private',
        'hide_for_screenshot',
        'listen_to_global_screenshot_hotkey',
      }
    : {
        'private',
        'hide_for_screenshot',
      };

final expectedFlags = <ConfigFlag>{
  ConfigFlag(
    name: 'private',
    description: 'Show private entries?',
    status: true,
  ),
  ConfigFlag(
    name: 'notify_exceptions',
    description: 'Notify when exceptions occur?',
    status: false,
  ),
  ConfigFlag(
    name: 'hide_for_screenshot',
    description: 'Hide Lotti when taking screenshots?',
    status: true,
  ),
  ConfigFlag(
    name: 'show_tasks_tab',
    description: 'Show Tasks tab?',
    status: false,
  ),
  ConfigFlag(
    name: 'show_bright_scheme',
    description: 'Show Bright ☀️ scheme?',
    status: false,
  ),
  ConfigFlag(
    name: showThemeConfigFlagName,
    description: 'Show Theme Config UI?',
    status: false,
  ),
};

final expectedMacFlags = <ConfigFlag>{
  ConfigFlag(
    name: 'listen_to_global_screenshot_hotkey',
    description: 'Listen to global screenshot hotkey?',
    status: true,
  ),
  ConfigFlag(
    name: 'enable_notifications',
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

        await db?.toggleConfigFlag(showBrightSchemeFlagName);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlagName),
          ConfigFlag(
            name: 'show_bright_scheme',
            description: 'Show Bright ☀️ scheme?',
            status: true,
          ),
        );

        expect(
          await db?.watchActiveConfigFlagNames().first,
          expectedActiveFlagNames.union({showBrightSchemeFlagName}),
        );

        await db?.toggleConfigFlag(showBrightSchemeFlagName);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlagName),
          ConfigFlag(
            name: 'show_bright_scheme',
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
          await db?.getConfigFlagByName(showBrightSchemeFlagName),
          ConfigFlag(
            name: 'show_bright_scheme',
            description: 'Show Bright ☀️ scheme?',
            status: false,
          ),
        );

        await db?.toggleConfigFlag(showBrightSchemeFlagName);

        expect(
          await db?.getConfigFlagByName(showBrightSchemeFlagName),
          ConfigFlag(
            name: 'show_bright_scheme',
            description: 'Show Bright ☀️ scheme?',
            status: true,
          ),
        );

        expect(await db?.getConfigFlagByName('invalid'), null);
      },
    );
  });
}
