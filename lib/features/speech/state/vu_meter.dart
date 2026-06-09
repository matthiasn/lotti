import 'dart:collection';
import 'dart:math' as math;

/// Default window size for VU-meter RMS calculation, in milliseconds.
const defaultVuWindowMs = 300;

/// Reference level where 0 VU corresponds to -18 dBFS.
const double vuReferenceLevelDbfs = -18;

/// Sliding-window VU meter: turns a stream of dBFS samples into a VU reading
/// using a fixed-length RMS window.
///
/// Self-contained and deterministic — feed it consecutive [addSample] calls
/// and it returns the current level in VU (where 0 VU corresponds to
/// [referenceDbfs]), clamped to the `[-20, 3]` VU display range. It owns its
/// own sliding buffer and has no dependency on the recorder, so it can be
/// constructed and exercised directly in tests.
class VuMeter {
  VuMeter({
    required this.windowSamples,
    this.referenceDbfs = vuReferenceLevelDbfs,
  });

  /// Number of most-recent dBFS samples retained for the RMS window.
  final int windowSamples;

  /// dBFS level mapped to 0 VU.
  final double referenceDbfs;

  final Queue<double> _buffer = Queue<double>();

  /// Appends [dbfs] to the sliding window and returns the current VU reading.
  ///
  /// Consecutive calls model consecutive amplitude samples; the oldest samples
  /// fall out of the window once it exceeds [windowSamples].
  double addSample(double dbfs) {
    _buffer.addLast(dbfs);
    while (_buffer.length > windowSamples) {
      _buffer.removeFirst();
    }
    if (_buffer.isEmpty) return -20;

    // Convert each dBFS sample to linear amplitude (0 dBFS = 1.0), accumulate
    // squares, then take the RMS and convert back to dB.
    var sumOfSquares = 0.0;
    for (final sample in _buffer) {
      final linear = math.pow(10, sample / 20).toDouble();
      sumOfSquares += linear * linear;
    }
    final rms = math.sqrt(sumOfSquares / _buffer.length);
    // 20 * log10(rms); math.log is natural log, so divide by ln10.
    final rmsDb = 20 * (math.log(rms) / math.ln10);
    // VU in dB = level above the reference (0 VU == referenceDbfs).
    final vuDb = rmsDb - referenceDbfs;
    return vuDb.clamp(-20.0, 3.0);
  }

  /// Clears the sliding window (e.g. when recording stops).
  void reset() => _buffer.clear();
}
