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
      name: enableUnifiedGoalsFlag,
      description: 'Enable unified Goals page?',
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
      name: enableEventsFlag,
      description: 'Enable Events?',
      status: false,
    ),
  );
  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: enableRelationshipsFlag,
      description: 'Enable People Page?',
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
      name: enableProjectsFlag,
      description: 'Enable Projects?',
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
      name: enableWhatsNewFlag,
      description: "Enable What's New feature?",
      status: false,
    ),
  );

  await db.insertFlagIfNotExists(
    const ConfigFlag(
      name: dailyOsOnboardingEnabledFlag,
      // Dark launch: the Daily OS surface remains available, but its coaching
      // walkthrough stays opt-in until production testing concludes. Its gate
      // still sequences behind FTUE and requires a resolvable planner route.
      description: 'Enable the Daily OS onboarding walkthrough?',
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

  for (final flagName in retiredConfigFlags) {
    await db.deleteConfigFlag(flagName);
  }
}

/// Flags the app no longer defines, deleted from existing installs on start.
///
/// This is storage cleanup, not a fix for a visible toggle: `FlagsBody`
/// renders only the names in its `defaultDisplayedItems` whitelist, so a row
/// the app has stopped defining is already invisible there. Deleting a flag's
/// `insertFlagIfNotExists` call stops *new* installs from getting the row, but
/// upgraded installs keep it forever — still stored, still emitted by
/// `watchConfigFlags`, and still readable by name. Entries can be dropped from
/// this list once every install that could still carry the row has upgraded
/// past it.
const retiredConfigFlags = <String>[
  // The standalone sidebar activity row was replaced by compact directional
  // badges on Settings, so this opt-in toggle no longer controls anything.
  'show_sync_activity_indicator',
  // Removed with the sync actor isolate (ADR 0046). Never read by any code
  // path: the actor it would have gated was never wired into the app.
  'enable_sync_actor',
  // The legacy Agents tab (never released, off by default) was superseded by
  // the unified Goals surface (`enable_unified_goals`); the tab, its list
  // page and its `/agents` routes were removed with it.
  'enable_agents_page',
];
