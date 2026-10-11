import 'package:lotti/features/daily_os_next/state/capture_state.dart';

/// Floor for the raw dBFS value mirrored into the visual meter. Mirrors
/// [CaptureState.defaultDbfs] so an idle/quiet meter renders at its resting
/// level instead of jumping to silence.
const double minVisualDbfs = CaptureState.defaultDbfs;

/// Clamps a raw dBFS reading into the `[minVisualDbfs, 0]` range used by the
/// numeric dBFS readout. NaN/infinite inputs collapse to [minVisualDbfs].
double sanitizeVisualDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return minVisualDbfs;
  return dbfs.clamp(minVisualDbfs, 0.0);
}
