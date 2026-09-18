const privateFlag = 'private';
const enableNotificationsFlag = 'enable_notifications';
// Which kinds of alert may reach the OS while `enable_notifications` is on.
// Seeded on, so switching notifications on means every kind until the user
// says otherwise on the Notifications settings page.
const notifyTaskSuggestionsFlag = 'notify_task_suggestions';
const notifyCheckInRemindersFlag = 'notify_check_in_reminders';
const notifyGoalAlertsFlag = 'notify_goal_alerts';
const notifyHabitRemindersFlag = 'notify_habit_reminders';
const notifyHabitAutoCompletionsFlag = 'notify_habit_auto_completions';
const notifyDayPlanOutcomesFlag = 'notify_day_plan_outcomes';
const notifySyncConflictsFlag = 'notify_sync_conflicts';

/// Whether the count of tasks in progress sits on the app icon (iOS, macOS).
const showTaskBadgeFlag = 'show_task_badge';

/// Whether an agent may re-word an armed alert with its banner's own copy —
/// off by default, because that copy lands on a lock screen (ADR 0063).
const notifyAgentCopyFlag = 'notify_agent_copy';
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

const kDefaultScrollAlignment = 0.3;
