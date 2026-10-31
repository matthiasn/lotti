import 'dart:math' as math;
import 'dart:typed_data';

/// Mono samples in -1..1 and their rate.
typedef Pcm = ({int sampleRate, List<double> samples});

/// Reads a 16-bit PCM WAV, averaging its channels: the format both the
/// on-device and the cloud voice write.
///
/// Throws [FormatException] for anything else, a truncated or malformed
/// file included.
Pcm readPcm16(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Not a RIFF/WAVE file');
  }
  var at = 12;
  int? channels;
  int? sampleRate;
  while (at + 8 <= bytes.length) {
    final id = tag(at);
    final size = data.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      // A clip cut short, or a chunk too small for what it must say, is as
      // unreadable as any other non-WAV: the caller falls back on it.
      if (size < 16 || body + 16 > bytes.length) {
        throw const FormatException('Truncated fmt chunk');
      }
      final format = data.getUint16(body, Endian.little);
      final bits = data.getUint16(body + 14, Endian.little);
      if (format != 1 || bits != 16) {
        throw FormatException('Only 16-bit PCM is supported ($format/$bits)');
      }
      channels = data.getUint16(body + 2, Endian.little);
      if (channels == 0) {
        throw const FormatException('fmt chunk declares no channels');
      }
      sampleRate = data.getUint32(body + 4, Endian.little);
    } else if (id == 'data') {
      if (channels == null || sampleRate == null) {
        throw const FormatException('data chunk before fmt chunk');
      }
      final end = math.min(bytes.length, body + size);
      final frames = (end - body) ~/ (2 * channels);
      final samples = List<double>.filled(frames, 0);
      for (var f = 0; f < frames; f++) {
        var sum = 0;
        for (var ch = 0; ch < channels; ch++) {
          sum += data.getInt16(body + (f * channels + ch) * 2, Endian.little);
        }
        samples[f] = sum / channels / 32768;
      }
      return (sampleRate: sampleRate, samples: samples);
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('No data chunk');
}
