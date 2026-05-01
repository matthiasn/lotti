import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// In-memory toggle for Flutter's repaint-rainbow overlay
/// (`debugRepaintRainbowEnabled`). Surfaced on the Maintenance page so a
/// production build can flip the overlay on, observe which regions
/// repaint, and flip it back off — all without a rebuild.
///
/// The flag lives in process memory (no DB persistence). Restarting the
/// app drops it back to `false`, which is what we want for a transient
/// diagnostic that should never accidentally stay enabled.
///
/// Mutations are mirrored into Flutter's
/// [debugRepaintRainbowEnabled] global and a forced frame is scheduled so
/// the change is observable on the next vsync without waiting for some
/// other widget to call `setState`.
final repaintRainbowEnabled = ValueNotifier<bool>(false)
  ..addListener(_applyRepaintRainbowFlag);

void _applyRepaintRainbowFlag() {
  debugRepaintRainbowEnabled = repaintRainbowEnabled.value;
  // Force a frame so the toggle is visible immediately. Otherwise the
  // overlay only renders the next time some unrelated widget triggers a
  // repaint — which on a quiet UI may take a while.
  SchedulerBinding.instance.scheduleForcedFrame();
}
