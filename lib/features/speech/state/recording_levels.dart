/// dBFS floor used to normalise amplitudes into 0..1. Values below this clamp
/// to 0; -45 keeps speech visible without amplifying room noise into
/// oscillating full-height bars.
const minDbfs = -45.0;

/// Maps a raw dBFS reading into the 0..1 range used by the live level bars.
///
/// Pure: NaN/infinite inputs collapse to 0, values are clamped to
/// `[minDbfs, 0]`, then linearly rescaled so [minDbfs] maps to 0 and 0 dBFS
/// maps to 1.
double normaliseDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  final clamped = dbfs.clamp(minDbfs, 0.0);
  return (clamped - minDbfs) / -minDbfs;
}
