const privateFlag = 'private';
const enableNotificationsFlag = 'enable_notifications';
const recordLocationFlag = 'record_location';
const enableMatrixFlag = 'enable_matrix';
const enableTooltipFlag = 'enable_tooltip';
const enableAiStreamingFlag = 'enable_ai_streaming';
const enableQueryChatFlag = 'enable_query_chat';
const enableAiSummaryTtsFlag = 'enable_ai_summary_tts';
const resendAttachments = 'resend_attachments';
const enableLoggingFlag = 'enable_logging';

const enableHabitsPageFlag = 'enable_habits_page';
const enableDashboardsPageFlag = 'enable_dashboards_page';
const enableUnifiedGoalsFlag = 'enable_unified_goals';
const enableDailyOsPageFlag = 'enable_daily_os_page';
const enableEventsFlag = 'enable_events';
const enableRelationshipsFlag = 'enable_relationships';
const enableSessionRatingsFlag = 'enable_session_ratings';
const enableProjectsFlag = 'enable_projects';
const enableEmbeddingsFlag = 'enable_embeddings';
const enableVectorSearchFlag = 'enable_vector_search';

const enableWhatsNewFlag = 'enable_whats_new';
const dailyOsOnboardingEnabledFlag = 'daily_os_onboarding_enabled';
const enableForkHealingFlag = 'enable_fork_healing';

const logSlowQueriesFlag = 'log_slow_queries';

/// The flags that each add a whole section to the app — a top-level
/// navigation destination with its own pages.
///
/// This is what separates *Settings → Sections* from *Config Flags*: a flag
/// belongs here when turning it on gives the user somewhere new to go, not
/// when it changes how an existing surface behaves. The membership test is
/// therefore mechanical rather than editorial — it is exactly the set
/// `NavService` watches to build its tab specs.
///
/// Order matches `NavService._tabSpecs`, so the Sections list reads top to
/// bottom in the same order as the navigation it produces.
const sectionFlags = <String>[
  enableDailyOsPageFlag,
  enableProjectsFlag,
  enableUnifiedGoalsFlag,
  enableHabitsPageFlag,
  enableDashboardsPageFlag,
  enableRelationshipsFlag,
  enableEventsFlag,
];

const kDefaultScrollAlignment = 0.3;
