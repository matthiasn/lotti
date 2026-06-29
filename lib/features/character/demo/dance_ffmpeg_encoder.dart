import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Pipes raw RGBA frames into one `ffmpeg` process and muxes them with the
/// track's audio into an H.264/AAC MP4 — the single encoder shared by the live
/// app's exact-frame export and the offline MP4 exporter, so the (long, fiddly)
/// ffmpeg argument vector and the bt709 colour tags live in one place.
///
/// Feed frames with [writeFrame], then [finish] (or [kill] on abort). The video
/// is `-shortest`-trimmed to the muxed audio window (`startSec`/`durationSec`).
final class DanceFfmpegEncoder {
  DanceFfmpegEncoder._(
    this._process,
    this._stdoutDone,
    this._stderrDone,
    this._stderrBuffer,
  );

  /// Starts ffmpeg reading raw `rgba` frames of [width]×[height] at [fps] from
  /// stdin, muxing the `[startSec, startSec+durationSec]` window of [audioPath].
  static Future<DanceFfmpegEncoder> start({
    required int width,
    required int height,
    required int fps,
    required double startSec,
    required double durationSec,
    required String outputPath,
    required String audioPath,
    required int crf,
    required int audioKbps,
    required String x264Preset,
  }) async {
    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    final args = [
      '-y',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s:v',
      '${width}x$height',
      '-framerate',
      '$fps',
      '-i',
      'pipe:0',
      '-ss',
      startSec.toStringAsFixed(6),
      '-t',
      durationSec.toStringAsFixed(6),
      '-i',
      audioPath,
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c:v',
      'libx264',
      '-preset',
      x264Preset,
      '-crf',
      '$crf',
      '-pix_fmt',
      'yuv420p',
      '-profile:v',
      'high',
      '-level',
      '4.2',
      '-r',
      '$fps',
      '-g',
      '${math.max(1, (fps / 2).round())}',
      '-bf',
      '2',
      '-colorspace',
      'bt709',
      '-color_primaries',
      'bt709',
      '-color_trc',
      'bt709',
      '-c:a',
      'aac',
      '-b:a',
      '${audioKbps}k',
      '-ar',
      '48000',
      '-movflags',
      '+faststart',
      '-shortest',
      outputFile.path,
    ];
    final process = await Process.start('ffmpeg', args);
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout.drain<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuffer.write);
    return DanceFfmpegEncoder._(process, stdoutDone, stderrDone, stderrBuffer);
  }

  final Process _process;
  final Future<void> _stdoutDone;
  final Future<void> _stderrDone;
  final StringBuffer _stderrBuffer;
  bool _killed = false;

  /// Writes one raw RGBA frame to ffmpeg's stdin.
  Future<void> writeFrame(Uint8List rgba) async {
    _process.stdin.add(rgba);
    await _process.stdin.flush();
  }

  /// Closes the pipe and waits for ffmpeg; throws on a non-zero exit.
  Future<void> finish() async {
    await _process.stdin.close();
    final exitCode = await _process.exitCode;
    await _stdoutDone;
    await _stderrDone;
    if (exitCode != 0) {
      throw StateError('ffmpeg failed with exit $exitCode\n$_stderrBuffer');
    }
  }

  /// Aborts the encode (idempotent).
  void kill() {
    if (_killed) return;
    _killed = true;
    _process.kill();
  }
}
