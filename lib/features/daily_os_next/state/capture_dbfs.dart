import 'package:lotti/features/daily_os_next/state/capture_state.dart';

/// dBFS floor used to normalise amplitudes into 0..1. Values below this clamp
/// to 0; -45 keeps speech visible without amplifying room noise into
/// oscillating full-height bars.
const minDbfs = -45.0;

/// Floor for the raw dBFS value mirrored into the visual meter. Mirrors
/// [CaptureState.defaultDbfs] so an idle/quiet meter renders at its resting
/// level instead of jumping to silence.
const double minVisualDbfs = CaptureState.defaultDbfs;

/// Maps a raw dBFS reading into the 0..1 range used by the live waveform.
///
/// Pure: NaN/infinite inputs collapse to 0, values are clamped to
/// `[minDbfs, 0]`, then linearly rescaled so [minDbfs] maps to 0 and 0 dBFS
/// maps to 1.
double normaliseDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  final clamped = dbfs.clamp(minDbfs, 0.0);
  return (clamped - minDbfs) / -minDbfs;
}

/// Clamps a raw dBFS reading into the `[minVisualDbfs, 0]` range used by the
/// numeric dBFS readout. NaN/infinite inputs collapse to [minVisualDbfs].
double sanitizeVisualDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return minVisualDbfs;
  return dbfs.clamp(minVisualDbfs, 0.0);
}
