import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

Future<void> initConfigFlags(JournalDb db) async {
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: privateFlag,
      description: 'Show private entries?',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: notifyExceptionsFlag,
      description: 'Notify when exceptions occur?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: hideForScreenshotFlag,
      description: 'Hide Lotti when taking screenshots?',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: showTasksTabFlag,
      description: 'Show Tasks tab?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: showBrightSchemeFlag,
      description: 'Show Bright ☀️ scheme?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: allowInvalidCertFlag,
      description: 'Allow invalid certificate? (not recommended)',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableSyncInboxFlag,
      description: 'Enable sync inbox? (requires restart)',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableSyncOutboxFlag,
      description: 'Enable sync outbox? (requires restart)',
      status: true,
    ),
  );
  if (Platform.isMacOS) {
    await db.insertFlagIfNotExists(
      const ConfigFlag(
        name: listenToScreenshotHotkeyFlag,
        description: 'Listen to global screenshot hotkey?',
        status: true,
      ),
    );
    await db.insertFlagIfNotExists(
      const ConfigFlag(
        name: enableNotificationsFlag,
        description: 'Enable desktop notifications?',
        status: false,
      ),
    );
  }
  if (isDesktop) {
    await db.insertFlagIfNotExists(
      const ConfigFlag(
        name: showThemeConfigFlag,
        description: 'Show Theme Config UI?',
        status: false,
      ),
    );
  }
}
