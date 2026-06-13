/// Max number of amplitude samples retained for the live waveform
/// (~10s at 50ms; the UI samples this down to fit).
const int chatAmplitudeHistoryMax = 200;

/// dBFS that maps to the bottom of the normalised waveform range.
const int chatAmplitudeMinDbfs = -80;

/// dBFS that maps to the top of the normalised waveform range.
const int chatAmplitudeMaxDbfs = -10;

/// Lowest normalised bar height (so silence still renders a sliver).
const double chatAmplitudeMinNormalized = 0.05;

/// Highest normalised bar height.
const double chatAmplitudeMaxNormalized = 1;

/// Appends [dbfs] to [history] and trims it to [max] samples, dropping the
/// oldest sample when the window overflows.
///
/// Pure: returns a new list and never mutates [history], so the controller can
/// hand it straight to `state.copyWith`. Shared by the batch and realtime
/// recording paths to keep the rolling-window behaviour identical.
List<double> appendAmplitudeSample(
  List<double> history,
  double dbfs, {
  int max = chatAmplitudeHistoryMax,
}) {
  final next = List<double>.from(history)..add(dbfs);
  if (next.length > max) next.removeAt(0);
  return next;
}

/// Normalises a single dBFS reading into the `[minNormalized, maxNormalized]`
/// waveform range, clamping out-of-range readings to the endpoints.
double normalizeAmplitudeSample(double dbfs) {
  const rangeDbfs = chatAmplitudeMaxDbfs - chatAmplitudeMinDbfs; // 70
  const rangeNormalized =
      chatAmplitudeMaxNormalized - chatAmplitudeMinNormalized; // 0.95

  if (dbfs <= chatAmplitudeMinDbfs) return chatAmplitudeMinNormalized;
  if (dbfs >= chatAmplitudeMaxDbfs) return chatAmplitudeMaxNormalized;
  final normalized = (dbfs - chatAmplitudeMinDbfs) / rangeDbfs; // 0..1
  final scaled = normalized * rangeNormalized + chatAmplitudeMinNormalized;
  return scaled.clamp(chatAmplitudeMinNormalized, chatAmplitudeMaxNormalized);
}

/// Maps an amplitude [history] of dBFS readings to the normalised waveform
/// heights the UI renders.
List<double> normalizeAmplitudeHistory(List<double> history) =>
    history.map(normalizeAmplitudeSample).toList();
