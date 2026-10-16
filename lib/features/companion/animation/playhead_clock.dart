import 'package:clock/clock.dart';

/// The playhead between the player's reports.
///
/// A media player reports its position in coarse steps, so a mouth that read
/// it directly would hold one shape for several frames and then jump. The
/// clock carries the latest report forward by the time since it arrived,
/// scaled by the playback speed, and starts again from every new report, so
/// it never drifts from the voice for longer than one report.
///
/// It carries a report forward by at most [maxLead]: a player that stalls
/// stops reporting, and the mouth has to stop with it rather than run on
/// through the words.
class PlayheadClock {
  PlayheadClock({this.maxLead = const Duration(milliseconds: 250)});

  /// How far past the latest report the clock may run.
  final Duration maxLead;

  final Stopwatch _sinceReport = clock.stopwatch();
  Duration? _reported;

  /// The playhead now, given the player's latest [reported] position and the
  /// playback [speed] (media seconds per second).
  Duration at(Duration reported, {double speed = 1}) {
    if (reported != _reported) {
      _reported = reported;
      _sinceReport
        ..reset()
        ..start();
    }
    final lead = _sinceReport.elapsed * speed;
    return reported + (lead < maxLead ? lead : maxLead);
  }
}
