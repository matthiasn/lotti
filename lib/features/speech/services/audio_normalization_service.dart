import 'dart:async';
import 'dart:io';

// Using the audio-only variant to avoid heavy/full ffmpeg and fix CocoaPods 404s
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Runner function signature used to execute normalization commands.
typedef NormalizationRunner = Future<bool> Function({
  required String inputPath,
  required String outputPath,
  required String filterChain,
  Duration? timeout,
});

class AudioNormalizationService {
  AudioNormalizationService({NormalizationRunner? runner})
      : _runner = runner ?? _defaultRunner;

  final NormalizationRunner _runner;

  LoggingService get _log => getIt<LoggingService>();

  Future<bool> maybeNormalizeAudioNote({
    required String audioDirectory,
    required String audioFile,
    required double avgDbfs,
    required Duration duration,
  }) async {
    final shouldNormalize =
        await _shouldNormalize(avgDbfs: avgDbfs, duration: duration);
    if (!shouldNormalize) return false;

    final inputPath =
        p.join(getDocumentsDirectory().path, audioDirectory, audioFile);
    return _normalizeFile(
        inputPath: inputPath, duration: duration, avgDbfs: avgDbfs);
  }

  Future<bool> _shouldNormalize({
    required double avgDbfs,
    required Duration duration,
  }) async {
    if (!Platform.isMacOS) return false;
    if (!getIt.isRegistered<JournalDb>()) return false;
    final enabled =
        await getIt<JournalDb>().getConfigFlag(normalizeAudioOnDesktopFlag);
    if (!enabled) return false;
    if (duration.inSeconds < 1) return false; // skip very short clips
    if (avgDbfs >= -20.0) return false; // already loud enough
    return true;
  }

  Future<bool> _normalizeFile({
    required String inputPath,
    required Duration duration,
    required double avgDbfs,
  }) async {
    try {
      final input = File(inputPath);
      if (!input.existsSync()) {
        _log.captureEvent(
          {'message': 'normalize_skip_missing', 'inputPath': inputPath},
          domain: 'audio_normalization',
          subDomain: 'decision',
        );
        return false;
      }

      final dir = input.parent;
      final tmpOut = File(p.join(
          dir.path, '${p.basenameWithoutExtension(input.path)}.norm.tmp.m4a'));
      const filter =
          'dynaudnorm=f=150:g=7:p=0.9:m=7:s=10:r=0.5,alimiter=limit=-1dB';

      _log.captureEvent(
        {
          'message': 'normalize_start',
          'inputPath': input.path,
          'outputPath': tmpOut.path,
          'filter': filter,
          'durationSec': duration.inSeconds,
          'avgDbfs': avgDbfs,
        },
        domain: 'audio_normalization',
        subDomain: 'start',
      );

      final ok = await _runner(
        inputPath: input.path,
        outputPath: tmpOut.path,
        filterChain: filter,
        timeout: const Duration(seconds: 30),
      );
      if (!ok) {
        _log.captureEvent(
          {'message': 'normalize_failed', 'inputPath': input.path},
          domain: 'audio_normalization',
          subDomain: 'error',
        );
        if (tmpOut.existsSync()) {
          await tmpOut.delete();
        }
        return false;
      }

      // Atomic replace: backup then rename
      final backup = File('${input.path}.bak');
      if (backup.existsSync()) {
        await backup.delete();
      }
      await input.rename(backup.path);
      await tmpOut.rename(input.path);
      await backup.delete();

      _log.captureEvent(
        {'message': 'normalize_complete', 'inputPath': input.path},
        domain: 'audio_normalization',
        subDomain: 'complete',
      );
      return true;
    } catch (e, st) {
      _log.captureException(
        e,
        domain: 'audio_normalization',
        subDomain: 'error',
        stackTrace: st,
      );
      return false;
    }
  }
}

Future<bool> _defaultRunner({
  required String inputPath,
  required String outputPath,
  required String filterChain,
  Duration? timeout,
}) async {
  // Quote paths to handle spaces safely.
  String q(String s) => '"${s.replaceAll('"', r'\"')}"';
  final cmd =
      '-y -i ${q(inputPath)} -af $filterChain -c:a aac -b:a 96k ${q(outputPath)}';
  final session = await FFmpegKit.execute(cmd);
  final rc = await session.getReturnCode();
  return ReturnCode.isSuccess(rc);
}
