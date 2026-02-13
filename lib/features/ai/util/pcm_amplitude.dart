import 'dart:math';
import 'dart:typed_data';

/// Computes dBFS (decibels relative to full scale) from a PCM 16-bit
/// signed little-endian audio chunk.
///
/// Returns a value typically in the range [-80, 0] where 0 is maximum
/// amplitude and -80 is near-silence.
///
/// The [pcmBytes] must contain an even number of bytes (each sample is
/// 2 bytes, little-endian). Trailing odd bytes are ignored.
/// Returns [floorDbfs] for empty or silent input.
double computeDbfsFromPcm16(Uint8List pcmBytes, {double floorDbfs = -80}) {
  final numSamples = pcmBytes.length ~/ 2;
  if (numSamples == 0) return floorDbfs;

  // Interpret bytes as Int16 samples (little-endian)
  final byteData = ByteData.sublistView(pcmBytes);
  var sumSquares = 0.0;

  for (var i = 0; i < numSamples; i++) {
    final sample = byteData.getInt16(i * 2, Endian.little);
    sumSquares += sample * sample;
  }

  // RMS = sqrt(sum(sample^2) / numSamples)
  final rms = sqrt(sumSquares / numSamples);

  if (rms == 0) return floorDbfs;

  // dBFS = 20 * log10(rms / 32768)
  final dbfs = 20 * log(rms / 32768) / ln10;

  return dbfs.clamp(floorDbfs, 0);
}
