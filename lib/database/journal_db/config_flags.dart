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
      name: attemptEmbedding,
      description: 'Create LLM embedding',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    ConfigFlag(
      name: enableSyncFlag,
      description: 'Enable sync? (requires restart)',
      status: inMemoryDatabase,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: autoTranscribeFlag,
      description: 'Automatically transcribe audio',
      status: false,
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
      name: useCloudInferenceFlag,
      description: 'Use Cloud Inference',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableAutoTaskTldrFlag,
      description: 'Enable auto task TLDR',
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
      name: enablePremiumTaskUiFlag,
      description: 'Enable Premium Task UI?',
      status: false,
    ),
  );
}
