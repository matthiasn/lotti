import 'dart:core';

/// Tuning parameters for timeline draining and read marker behaviour.
///
/// Defaults are chosen based on empirical testing with typical homeserver
/// latencies and SDK update timings:
/// - maxDrainPasses: Limits redundant homeserver syncs per refresh while still
///   allowing the timeline to catch a just-arrived event. 3 passes yielded
///   consistent correctness without noticeable UI latency.
/// - timelineLimits: Snapshot escalation strategy used when the live timeline
///   has not yet incorporated new events. These tiers keep the query sizes
///   bounded for most rooms while still allowing recovery for large rooms.
/// - retryDelays: Small intra-pass delays for the live timeline to settle when
///   we are at the tail. Sub-200ms total avoids perceptible lag while fixing
///   the one-behind edge.
/// - readMarkerFollowUpDelay: A small nudge to re-check when we intentionally
///   do not advance due to retriable failures.
class TimelineConfig {
  const TimelineConfig({
    this.maxDrainPasses = 3,
    this.timelineLimits = const <int>[100, 300, 500, 1000],
    this.retryDelays = const <Duration>[
      Duration(milliseconds: 60),
      Duration(milliseconds: 120),
    ],
    this.readMarkerFollowUpDelay = const Duration(milliseconds: 150),
    this.collectMetrics = false,
  });

  final int maxDrainPasses;
  final List<int> timelineLimits;
  final List<Duration> retryDelays;
  final Duration readMarkerFollowUpDelay;

  /// When true, increments metrics counters if a metrics object is provided.
  /// Disabled by default for zero overhead in hot paths.
  final bool collectMetrics;

  static const TimelineConfig production = TimelineConfig();

  /// Conservative preset for low-end devices or constrained environments.
  static const TimelineConfig lowEnd = TimelineConfig(
    maxDrainPasses: 2,
    timelineLimits: <int>[50, 100, 200],
    retryDelays: <Duration>[Duration(milliseconds: 50)],
    readMarkerFollowUpDelay: Duration(milliseconds: 100),
  );
}
