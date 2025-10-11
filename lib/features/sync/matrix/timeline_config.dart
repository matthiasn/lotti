import 'dart:core';

class TimelineConfig {
  const TimelineConfig({
    this.maxDrainPasses = 3,
    this.timelineLimits = const <int>[100, 300, 500, 1000],
    this.retryDelays = const <Duration>[
      Duration(milliseconds: 60),
      Duration(milliseconds: 120),
    ],
    this.readMarkerFollowUpDelay = const Duration(milliseconds: 150),
  });

  final int maxDrainPasses;
  final List<int> timelineLimits;
  final List<Duration> retryDelays;
  final Duration readMarkerFollowUpDelay;

  static const TimelineConfig production = TimelineConfig();
}
 
