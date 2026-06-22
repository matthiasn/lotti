import 'package:lotti/database/database.dart';
import 'package:lotti/services/logging_domains.dart';
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
      name: enableAiStreamingFlag,
      description: 'Enable AI streaming responses?',
      status: true,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableAiSummaryTtsFlag,
      description: 'Enable local AI summary playback?',
      status: false,
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
      name: enableEventsFlag,
      description: 'Enable Events?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableDailyOsPageFlag,
      description: 'Enable DailyOS Page?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: dailyOsNextEnabledFlag,
      description: 'Use the next-generation agentic DailyOS surface?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableSessionRatingsFlag,
      description: 'Enable session ratings?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableSyncActorFlag,
      description: 'Enable Sync Actor (isolate-based sync)?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableProjectsFlag,
      description: 'Enable Projects?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableKnowledgeGraphFlag,
      description: 'Enable Knowledge Graph?',
      status: false,
    ),
  );

  // One toggle per logging domain. Flag names for sync / agentRuntime /
  // agentWorkflow deliberately match the historical log_sync /
  // log_agent_runtime / log_agent_workflow flags so existing preferences
  // survive. Errors are always logged regardless of these flags.
  for (final domain in LogDomain.values) {
    await db.insertFlagIfNotExists(
      ConfigFlag(
        name: domain.flagName,
        description: 'Log ${domain.label}',
        status: domain.defaultEnabled,
      ),
    );
  }

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: logSlowQueriesFlag,
      description: 'Log slow database queries',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableEmbeddingsFlag,
      description: 'Generate embeddings for entries?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableVectorSearchFlag,
      description: 'Enable vector search UI?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableSyncedAlertsFlag,
      description: 'Enable synced alerts?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableWhatsNewFlag,
      description: "Enable What's New feature?",
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableOnboardingFtueFlag,
      // Off by default: the new onboarding (FTUE) flow is still being built;
      // until it's enabled, first-run AI setup falls back to the provider
      // selection modal. Flip on to make the FTUE the new-user front door.
      description: 'Enable the new onboarding (FTUE) flow?',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: showSyncActivityIndicatorFlag,
      description: 'Show live sync activity in the sidebar.',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: showSidebarWakeQueueFlag,
      description: 'Show the inline Wake Queue in the sidebar.',
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableForkHealingFlag,
      description: 'Enable agent fork healing?',
      status: false,
    ),
  );

  // No additional flags for label guardrails: always-on behavior.
}
