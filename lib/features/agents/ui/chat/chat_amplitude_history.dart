/// Max number of amplitude samples retained for the live waveform
/// (20 s at the recorder's 100 ms; the waveform draws what fits).
const int chatAmplitudeHistoryMax = 200;

/// Appends [dbfs] to [history] and trims it to [max] samples, dropping the
/// oldest sample when the window overflows.
///
/// Pure: returns a new list and never mutates [history], so the controller can
/// hand it straight to `state.copyWith`. Used by the batch recorder
/// to maintain its rolling waveform window.
List<double> appendAmplitudeSample(
  List<double> history,
  double dbfs, {
  int max = chatAmplitudeHistoryMax,
}) {
  final next = List<double>.from(history)..add(dbfs);
  if (next.length > max) next.removeAt(0);
  return next;
}
