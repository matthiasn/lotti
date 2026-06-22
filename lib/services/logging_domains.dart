/// The curated set of structured-logging domains.
///
/// `LogDomain` is the single source of truth for logging domains. Each value
/// carries the metadata needed to wire a config flag, render a Settings
/// toggle, route the event to the right file, and write a stable wire name
/// into the log line.
///
/// Domains consolidate the ~70 ad-hoc domain strings used historically. The
/// original fine-grained string is preserved in the `subDomain` argument of
/// `DomainLogger.log` / `DomainLogger.error` where it adds information.
///
/// Toggling happens in Settings → Advanced → Logging via the per-domain config
/// flag ([flagName]). Errors are always logged regardless of whether the
/// domain is enabled.
enum LogDomain {
  /// Matrix sync, outbox, vector clocks, backfill, key verification, etc.
  ///
  /// Off by default and the only domain that routes to the shared `sync-*.log`
  /// file (so the noisy sync stream can be reviewed in isolation).
  sync(
    flagName: 'log_sync',
    label: 'Sync',
    defaultEnabled: false,
    routesToSyncFile: true,
  ),

  /// Unified AI inference, prompts, model selection, image analysis.
  ai(flagName: 'log_ai', label: 'AI'),

  /// Chat recorder, chat sessions and chat messages.
  chat(flagName: 'log_chat', label: 'Chat'),

  /// Audio recording, playback, waveform, transcription.
  speech(flagName: 'log_speech', label: 'Speech & audio'),

  /// Journal entities, entries, editor, entity caches.
  persistence(flagName: 'log_persistence', label: 'Persistence'),

  /// App database, migrations, maintenance, purge, logging DB.
  database(flagName: 'log_database', label: 'Database'),

  /// Agent wake orchestrator and runtime.
  agentRuntime(flagName: 'log_agent_runtime', label: 'Agent runtime'),

  /// Agent workflow execution, soul documents, improver, feedback extraction.
  agentWorkflow(flagName: 'log_agent_workflow', label: 'Agent workflow'),

  /// Tasks and checklists.
  tasks(flagName: 'log_tasks', label: 'Tasks & checklists'),

  /// Labels and label guardrails.
  labels(flagName: 'log_labels', label: 'Labels'),

  /// Health data, workouts, step counts.
  health(flagName: 'log_health', label: 'Health'),

  /// Habit definitions and completions.
  habits(flagName: 'log_habits', label: 'Habits'),

  /// Geolocation capture.
  location(flagName: 'log_location', label: 'Location'),

  /// Screenshots and the screen-capture portal.
  screenshots(flagName: 'log_screenshots', label: 'Screenshots'),

  /// Calendar, time entries, pomodoro.
  calendar(flagName: 'log_calendar', label: 'Calendar & time'),

  /// Routing, deep links, navigation.
  navigation(flagName: 'log_navigation', label: 'Navigation'),

  /// Theme loading and theming.
  theming(flagName: 'log_theming', label: 'Theming'),

  /// Local and push notifications.
  notifications(flagName: 'log_notifications', label: 'Notifications'),

  /// What's-new feature.
  whatsNew(flagName: 'log_whats_new', label: "What's new"),

  /// First-time-user experience (FTUE) / onboarding funnel.
  onboarding(flagName: 'log_onboarding', label: 'Onboarding & FTUE'),

  /// Settings, config flags, service registration.
  settings(flagName: 'log_settings', label: 'Settings'),

  /// Session ratings.
  ratings(flagName: 'log_ratings', label: 'Ratings'),

  /// Daily OS surfaces: trends, dashboards, measurements, charts, insights.
  dailyOs(flagName: 'log_daily_os', label: 'Daily OS'),

  /// Fallback domain for app lifecycle, windowing, startup, and anything that
  /// doesn't map to a more specific domain.
  general(flagName: 'log_general', label: 'General');

  const LogDomain({
    required this.flagName,
    required this.label,
    this.defaultEnabled = true,
    this.routesToSyncFile = false,
  });

  /// The config-flag name controlling this domain (`log_<snake>`).
  ///
  /// `sync` / `agentRuntime` / `agentWorkflow` deliberately reuse the historical
  /// `log_sync` / `log_agent_runtime` / `log_agent_workflow` flag names so
  /// existing user preferences survive the migration.
  final String flagName;

  /// English fallback label. The Settings UI shows a localized label; this is
  /// used when no localization is available (e.g. tests, fallbacks).
  final String label;

  /// Whether the domain is enabled by default. Only relevant when the global
  /// logging flag is on. All domains default on except [sync].
  final bool defaultEnabled;

  /// Whether events for this domain route to the shared `sync-*.log` file
  /// instead of a per-domain file. Only [sync] does.
  final bool routesToSyncFile;

  /// The string written into log files and used as the per-domain file stem.
  ///
  /// Equal to [name] so the wire format is stable and grep-friendly.
  String get wireName => name;
}
