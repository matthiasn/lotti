/// Which settings surface each stored `ConfigFlag` appears on.
///
/// One concept, one file, and deliberately outside the UI layer: the pages
/// read this assignment rather than owning it, so a test can ask where a flag
/// lives without importing a widget — and the two halves of the partition
/// cannot drift into separate layers.
///
/// Every flag `initConfigFlags` creates belongs to exactly one of four
/// surfaces:
///
/// | Surface | Holds | Rule |
/// |---------|-------|------|
/// | Sections | [sectionFlags] | The flag adds a top-level navigation destination |
/// | Notifications | [notificationSettingsFlags] | The flag decides what may reach the OS |
/// | Config Flags | [configFlagGroups] | Everything else a user may set |
/// | Advanced → Logging | the `LogDomain` toggles and `log_slow_queries` | Diagnostics with their own page |
///
/// `database_config_flags_test` asserts that partition against the flags a
/// real database ends up holding, so a flag added to `initConfigFlags` without
/// a home fails there rather than shipping as a toggle nobody can reach.
library;

import 'package:lotti/utils/consts.dart';

/// The flags that each add a whole section to the app — a top-level
/// navigation destination with its own pages.
///
/// This is what separates *Settings → Sections* from *Config Flags*: a flag
/// belongs here when turning it on gives the user somewhere new to go, not
/// when it changes how an existing surface behaves. The membership test is
/// therefore mechanical rather than editorial — `NavService` builds its tab
/// watch list from this very constant, so the two cannot disagree about which
/// flags produce a destination.
///
/// Order is the order `NavService` yields its tab specs in, so the Sections
/// list reads top to bottom in the same order as the navigation it produces.
/// Reordering here reorders the app's tabs; that is the point, not a
/// side effect.
const sectionFlags = <String>[
  enableDailyOsPageFlag,
  enableProjectsFlag,
  enableUnifiedGoalsFlag,
  enableHabitsPageFlag,
  enableDashboardsPageFlag,
  enableRelationshipsFlag,
  enableEventsFlag,
];

/// The flags Settings → Notifications owns: the master switch that lets
/// anything reach the OS at all, one switch per kind of alert, the task count
/// on the app icon, and whether an agent may word an alert in its own copy.
///
/// They are not Config Flags rows: the kinds are greyed while the master is
/// off, so they read as one decision, and a second copy of the master switch
/// on the flags page would bypass the hook's ordering. The page lays the rows
/// out itself; this list is only where they live.
const notificationSettingsFlags = <String>[
  enableNotificationsFlag,
  notifyTaskSuggestionsFlag,
  notifyCheckInRemindersFlag,
  notifyGoalAlertsFlag,
  notifyHabitRemindersFlag,
  notifyHabitAutoCompletionsFlag,
  notifyDayPlanOutcomesFlag,
  notifySyncConflictsFlag,
  showTaskBadgeFlag,
  notifyAgentCopyFlag,
];

/// The two jobs the Config Flags page still does, after the rows that turn
/// whole app sections on moved out to Sections.
///
/// The split is what stops that page reading as one undifferentiated list of
/// switches: a preference is something a user might reasonably want to change
/// about a feature they already have, while the second group is diagnostics
/// and unfinished work whose rows a user has no reason to touch unless asked
/// to. Rendered in enum-declaration order.
enum ConfigFlagGroup { preferences, advanced }

/// Canonical render order for the Config Flags page, by group. Adding a flag
/// here also requires icon + title + subtitle wiring in `ConfigFlagLabels`;
/// `config_flag_labels_test` asserts the far end of that chain.
///
/// [sectionFlags] and [notificationSettingsFlags] are deliberately absent — a
/// flag listed in two places would give one stored value two homes, and the
/// tests assert the sets stay disjoint.
const Map<ConfigFlagGroup, List<String>> configFlagGroups = {
  ConfigFlagGroup.preferences: [
    privateFlag,
    recordLocationFlag,
    enableTooltipFlag,
    enableSessionRatingsFlag,
    enableWhatsNewFlag,
    enableAiStreamingFlag,
    enableAiSummaryTtsFlag,
    enableMatrixFlag,
  ],
  ConfigFlagGroup.advanced: [
    enableQueryChatFlag,
    enableMobileSidebarNavigationFlag,
    enableEmbeddingsFlag,
    enableVectorSearchFlag,
    dailyOsOnboardingEnabledFlag,
    enableForkHealingFlag,
    enableLoggingFlag,
    resendAttachments,
  ],
};

/// Every flag the Config Flags page renders, flattened across the groups in
/// render order — the view the coverage and retirement checks read, and what
/// callers that only care *whether* a flag is on that page should use.
List<String> get configFlagsOnFlagsPage => [
  for (final group in ConfigFlagGroup.values) ...?configFlagGroups[group],
];
