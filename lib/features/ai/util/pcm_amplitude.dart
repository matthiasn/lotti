import 'dart:math';
import 'dart:typed_data';

/// Amplitude measurements for one PCM 16-bit audio chunk.
///
/// [dbfs] is the RMS level in decibels relative to full scale (0 = loudest,
/// the floor for silence). [peakSample] / [rmsSample] are in raw int16 units
/// (0–32767). Used to drive the live mic visualizers and silence detection.
class Pcm16AmplitudeStats {
  const Pcm16AmplitudeStats({
    required this.dbfs,
    required this.nonZeroSampleCount,
    required this.peakSample,
    required this.rmsSample,
  });

  final double dbfs;
  final int nonZeroSampleCount;
  final int peakSample;
  final double rmsSample;
}

/// Measures RMS and peak information from a PCM 16-bit signed little-endian
/// audio chunk.
///
/// Each sample is 2 bytes; a trailing odd byte is ignored. The reported
/// [Pcm16AmplitudeStats.dbfs] is clamped to `[floorDbfs, 0]`, and empty or
/// fully-silent input yields [floorDbfs].
Pcm16AmplitudeStats measurePcm16Amplitude(
  Uint8List pcmBytes, {
  double floorDbfs = -80,
}) {
  final numSamples = pcmBytes.length ~/ 2;
  if (numSamples == 0) {
    return Pcm16AmplitudeStats(
      dbfs: floorDbfs,
      nonZeroSampleCount: 0,
      peakSample: 0,
      rmsSample: 0,
    );
  }

  // Interpret bytes as Int16 samples (little-endian)
  final byteData = ByteData.sublistView(pcmBytes);
  var sumSquares = 0.0;
  var peakSample = 0;
  var nonZeroSampleCount = 0;

  for (var i = 0; i < numSamples; i++) {
    final sample = byteData.getInt16(i * 2, Endian.little);
    final absSample = sample.abs();
    if (absSample > 0) nonZeroSampleCount += 1;
    if (absSample > peakSample) peakSample = absSample;
    sumSquares += sample * sample;
  }

  // RMS = sqrt(sum(sample^2) / numSamples)
  final rms = sqrt(sumSquares / numSamples);

  if (rms == 0) {
    return Pcm16AmplitudeStats(
      dbfs: floorDbfs,
      nonZeroSampleCount: nonZeroSampleCount,
      peakSample: peakSample,
      rmsSample: rms,
    );
  }

  // dBFS = 20 * log10(rms / 32768)
  final dbfs = 20 * log(rms / 32768) / ln10;

  return Pcm16AmplitudeStats(
    dbfs: dbfs.clamp(floorDbfs, 0),
    nonZeroSampleCount: nonZeroSampleCount,
    peakSample: peakSample,
    rmsSample: rms,
  );
}
