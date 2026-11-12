import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A WAV file that is written while a cloud voice is still making it, so it
/// can be played before the voice has finished.
///
/// The voice sends one synthesis as a stream — one voice, one intonation
/// from the first word to the last — much faster than it plays: measured on
/// Voxtral (2026-11-12), the first audio 0.3 s after the request and 12.8 s
/// of it within 2 s. The player reads the file like any other. It starts
/// once [playable], with [playableBytes] written, and from then on what is
/// written stays ahead of what is played unless the network stalls; a
/// player that reaches the end of what is written before [done] is opened
/// again where it stopped (see `TtsPlaybackController`).
///
/// Neither future throws: a stream that fails ends both, and says why in
/// [failure].
class GrowingSpeechClip {
  GrowingSpeechClip._(this.file, this._audio);

  /// Starts writing [audio] — a WAV file's bytes in order, header first —
  /// to [file].
  static Future<GrowingSpeechClip> start(
    File file,
    Stream<Uint8List> audio,
  ) async {
    final clip = GrowingSpeechClip._(file, StreamIterator(audio));
    final out = await file.open(mode: FileMode.write);
    clip._writing = clip._write(out);
    return clip;
  }

  /// A WAV header, as the voices write it.
  static const int headerBytes = 44;

  /// What has to be written before the file is played: the header and two
  /// seconds of 24 kHz 16-bit mono, a lead a brief stall does not use up.
  static const int playableBytes = headerBytes + 2 * 24000 * 2;

  final File file;
  final StreamIterator<Uint8List> _audio;
  final _playable = Completer<void>();
  final _done = Completer<void>();
  late final Future<void> _writing;
  int _written = 0;
  bool _complete = false;
  bool _cancelled = false;

  /// Why the stream ended early, when it did.
  ({Object error, StackTrace stackTrace})? failure;

  /// Completes when enough is written to start playing, or the stream has
  /// ended — with all of a short clip, with nothing ([hasAudio]), or in
  /// [failure].
  Future<void> get playable => _playable.future;

  /// Completes when the stream has ended: the file is whole ([isComplete]),
  /// or it was cancelled or failed.
  Future<void> get done => _done.future;

  /// Whether any audio was written. A text of a word can come back as a
  /// stream without any, which is no failure.
  bool get hasAudio => _written > headerBytes;

  /// Whether the file holds all of the clip, its header saying how much.
  bool get isComplete => _complete;

  /// Stops writing. The file is left as it is, for the caller to delete.
  Future<void> cancel() async {
    _cancelled = true;
    await _audio.cancel();
    await _writing;
  }

  Future<void> _write(RandomAccessFile out) async {
    try {
      while (!_cancelled && await _audio.moveNext()) {
        await out.writeFrom(_audio.current);
        _written += _audio.current.length;
        if (_written >= playableBytes && !_playable.isCompleted) {
          _playable.complete();
        }
      }
      if (!_cancelled && hasAudio) {
        // The header of a streamed WAV does not know its length: once it is
        // known, it is written in, for every reader that goes by it.
        await out.setPosition(4);
        await out.writeFrom(_uint32(_written - 8));
        await out.setPosition(40);
        await out.writeFrom(_uint32(_written - headerBytes));
        await out.close();
        _complete = true;
      } else {
        await out.close();
      }
    } on Object catch (error, stackTrace) {
      failure = (error: error, stackTrace: stackTrace);
      // Whatever it failed at, the file is let go of; it may be closed
      // already.
      out.close().ignore();
    } finally {
      if (!_playable.isCompleted) _playable.complete();
      _done.complete();
    }
  }

  static Uint8List _uint32(int value) =>
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
}
