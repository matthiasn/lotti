/// How often a task agent whose automatic updates are on wakes after a change.
///
/// The on/off switch (`AgentConfig.automaticUpdatesEnabled`) stays the consent
/// gate: with it off the agent only runs when asked, whatever its cadence. A
/// cadence only decides *when* an agent that may wake on its own does so.
///
/// Resolved most-specific-first — the task's own choice, then its category's,
/// then the app-wide default (see [resolveAgentWakeCadence]). Persisted by
/// [name]; an unknown name from a newer build reads as "not set", so the next
/// level up applies.
enum AgentWakeCadence {
  /// About two minutes after a change, so a burst of edits is one run.
  live,

  /// At most once an hour. A finished recording, a stopped timer and a task
  /// marked done still update right away; an image analysis within a minute.
  hourly,

  /// Only after a recording finishes — or when asked. Every other change
  /// marks the report out of date without starting a run.
  recordingsOnly;

  /// The cadence named [name], or `null` for a missing or unknown name.
  static AgentWakeCadence? fromName(String? name) {
    for (final cadence in values) {
      if (cadence.name == name) return cadence;
    }
    return null;
  }

  /// How long a change waits for others to join it before the agent runs, or
  /// `null` when changes alone never start a run.
  Duration? get coalescingWindow => switch (this) {
    live => liveCoalescingWindow,
    hourly => const Duration(hours: 1),
    recordingsOnly => null,
  };

  /// Whether stopping a timer or completing the task runs the agent at once,
  /// taking every pending change with it.
  bool get flushesOnFinishedWork => this != recordingsOnly;

  /// Whether an image analysis pulls the next run forward to within
  /// [imageAnalysisWindow].
  bool get respondsToImageAnalysis => this != recordingsOnly;
}

/// The coalescing window of [AgentWakeCadence.live], and of every agent that
/// has no cadence (all non-task agents).
const Duration liveCoalescingWindow = Duration(seconds: 120);

/// The longest an image analysis waits before the agent runs. Several images
/// taken in a row land inside one window and share one run; the window starts
/// at the first analysis and is never extended.
const Duration imageAnalysisWindow = Duration(minutes: 1);

/// The cadence an app with no explicit choice uses.
const AgentWakeCadence defaultAgentWakeCadence = AgentWakeCadence.hourly;

/// The cadence that applies: [task] when set, else [category], else [global],
/// else [defaultAgentWakeCadence].
AgentWakeCadence resolveAgentWakeCadence({
  AgentWakeCadence? task,
  AgentWakeCadence? category,
  AgentWakeCadence? global,
}) => task ?? category ?? global ?? defaultAgentWakeCadence;
