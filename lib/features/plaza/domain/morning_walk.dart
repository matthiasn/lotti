/// The morning walk: a playlist of beacons flown in sequence, pausable,
/// abandoned by any movement.
///
/// Pure Dart; the harness feeds it time and flight completions.
library;

import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

/// One stop: fly to [pose], hold for [hold], move on.
class WalkStop {
  const WalkStop({required this.pose, required this.label, required this.hold});

  final CameraPose pose;
  final String label;
  final Duration hold;
}

/// Overview first, the top three anomalies, then home.
List<WalkStop> morningWalkStops(
  StreetPlan plan,
  FrontierPlaza plaza,
  List<TaskAttention> anomalies, {
  required String projectLabel,
}) {
  final stops = <WalkStop>[
    WalkStop(
      pose: plaza.overview,
      label: 'Overview — $projectLabel',
      hold: const Duration(seconds: 4),
    ),
  ];
  for (final anomaly in anomalies.take(3)) {
    final placement = plan.placements[anomaly.task.id];
    if (placement == null) continue;
    stops.add(
      WalkStop(
        pose: taskPoseFor(placement),
        label: anomaly.task.title,
        hold: const Duration(milliseconds: 3200),
      ),
    );
  }
  stops.add(
    WalkStop(
      pose: plaza.home,
      label: 'Home — $projectLabel',
      hold: const Duration(milliseconds: 1),
    ),
  );
  return stops;
}

/// Drives a walk through its stops. The harness calls [arrived] when a
/// flight lands and [tick] every frame; the stop [tick] returns is the one
/// to fly to next.
class MorningWalk {
  MorningWalk(this.stops) : assert(stops.isNotEmpty, 'a walk needs a stop');

  final List<WalkStop> stops;
  int _index = 0;
  bool paused = false;
  bool _holding = false;
  Duration _held = Duration.zero;
  bool _finished = false;

  int get index => _index;
  bool get finished => _finished;
  WalkStop get current => stops[_index];

  /// Human label for the HUD chip.
  String get chip =>
      'Morning walk · stop ${_index + 1} of ${stops.length} · '
      'space to ${paused ? 'resume' : 'pause'} · any move to exit';

  /// The flight to the current stop has landed; start holding.
  void arrived() {
    _holding = true;
    _held = Duration.zero;
  }

  /// Advances the hold timer. Returns the next stop to fly to when the hold
  /// is over, or null to keep holding.
  WalkStop? tick(Duration dt) {
    if (_finished || paused || !_holding) return null;
    _held += dt;
    if (_held < current.hold) return null;
    _holding = false;
    if (_index + 1 < stops.length) {
      _index++;
      return current;
    }
    _finished = true;
    return null;
  }

  void togglePause() => paused = !paused;

  /// Any movement input ends the walk.
  void abandon() => _finished = true;
}
