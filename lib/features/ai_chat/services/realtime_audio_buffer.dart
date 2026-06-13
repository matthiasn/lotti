import 'dart:async';
import 'dart:typed_data';

import 'package:lotti/features/ai/util/pcm_amplitude.dart';

/// Default maximum PCM buffer size: ~2 minutes at 16kHz × 16-bit × mono
/// = ~3.84 MB. Beyond this, older audio is discarded (transcription still
/// works via streaming — the buffer is only for the saved audio file).
const int defaultMaxRealtimePcmBytes = 3840000;

/// Capped PCM accumulator with per-chunk amplitude reporting for realtime
/// transcription sessions.
///
/// Owns the audio-side state that used to live inside
/// `RealtimeTranscriptionService`: a [BytesBuilder] holding the most recent
/// [maxBytes] of PCM 16-bit mono audio (for the saved audio file) and a
/// broadcast stream of dBFS values computed from each incoming chunk (for VU
/// meters). Self-contained and deterministic, so it can be exercised
/// directly in tests without driving the realtime pipeline.
class RealtimeAudioBuffer {
  RealtimeAudioBuffer({this.maxBytes = defaultMaxRealtimePcmBytes})
    : assert(maxBytes > 0, 'maxBytes must be positive');

  /// Maximum number of PCM bytes retained; older audio falls out first.
  final int maxBytes;

  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  /// Stream of amplitude values (dBFS) computed from each added PCM chunk.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Number of PCM bytes currently buffered (always ≤ [maxBytes]).
  int get length => _pcmBuffer.length;

  /// Appends [chunk] to the buffer, evicting the oldest bytes when the total
  /// would exceed [maxBytes], and emits the chunk's dBFS on [amplitudeStream].
  void addChunk(Uint8List chunk) {
    final newTotal = _pcmBuffer.length + chunk.length;
    if (newTotal > maxBytes) {
      final existing = _pcmBuffer.takeBytes();
      if (chunk.length >= maxBytes) {
        _pcmBuffer.add(chunk.sublist(chunk.length - maxBytes));
      } else {
        final excess = newTotal - maxBytes;
        final kept = existing.length - excess;
        final merged = Uint8List(kept + chunk.length)
          ..setRange(0, kept, existing, excess)
          ..setRange(kept, kept + chunk.length, chunk);
        _pcmBuffer.add(merged);
      }
    } else {
      _pcmBuffer.add(chunk);
    }

    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(computeDbfsFromPcm16(chunk));
    }
  }

  /// Returns a copy of the buffered PCM bytes, leaving the buffer intact.
  Uint8List toBytes() => _pcmBuffer.toBytes();

  /// Discards all buffered PCM (start of a new session).
  void clear() => _pcmBuffer.clear();

  /// Closes [amplitudeStream]. Buffering still works afterwards; amplitude
  /// emission stops. The long-lived `RealtimeTranscriptionService` singleton
  /// deliberately never closes its buffer — sessions restart via [clear] —
  /// but standalone owners (and tests) should close it when done.
  Future<void> close() => _amplitudeController.close();
}
