import 'package:lotti/database/database.dart';
import 'package:lotti/utils/consts.dart';

Future<void> initConfigFlags(
  JournalDb db, {
  required bool inMemoryDatabase,
}) async {
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: privateFlag,
      description: 'Show private entries?',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableMatrixFlag,
      description: 'Enable Matrix Sync',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableTooltipFlag,
      description: 'Enable Tooltips',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: recordLocationFlag,
      description: 'Record geolocation?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: resendAttachments,
      description: 'Resend Attachments',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableLoggingFlag,
      description: 'Enable logging?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableNotificationsFlag,
      description: 'Enable notifications?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableHabitsPageFlag,
      description: 'Enable Habits Page?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableDashboardsPageFlag,
      description: 'Enable Dashboards Page?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableCalendarPageFlag,
      description: 'Enable Calendar Page?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableEventsFlag,
      description: 'Enable Events?',
      status: false,
    ),
  );

  // AI label assignment flags
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableAiLabelAssignmentFlag,
      description: 'Enable AI label assignment via function calls',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: aiLabelAssignmentShadowFlag,
      description: 'Shadow mode: log suggestions, do not persist',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: includePrivateLabelsInPromptsFlag,
      description: 'Include private labels in {{labels}} prompt injection',
      status: true,
    ),
  );
}
