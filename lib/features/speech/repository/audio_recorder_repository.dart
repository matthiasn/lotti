import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_recorder_repository.g.dart';

/// Provider for the audio recorder repository.
/// Kept alive to maintain recording state across navigation.
@Riverpod(keepAlive: true)
AudioRecorderRepository audioRecorderRepository(Ref ref) {
  final repository = AudioRecorderRepository(AudioRecorder());
  ref.onDispose(() async {
    await repository.dispose();
  });
  return repository;
}

/// Repository that encapsulates all audio recording operations.
///
/// This repository provides a clean abstraction over the `record` package,
/// handling:
/// - Permission management
/// - Recording lifecycle (start, stop, pause, resume)
/// - Audio file creation and directory management
/// - Real-time amplitude monitoring for VU meter
/// - Comprehensive error handling and logging
///
/// All methods include error handling to ensure graceful degradation.
class AudioRecorderRepository {
  AudioRecorderRepository(this._audioRecorder);

  final AudioRecorder _audioRecorder;
  final LoggingService _loggingService = getIt<LoggingService>();

  /// Stream of amplitude updates for VU meter visualization.
  /// Emits amplitude values every 20ms while recording.
  Stream<Amplitude> get amplitudeStream => _audioRecorder.onAmplitudeChanged(
        const Duration(milliseconds: intervalMs),
      );

  /// Checks if the app has microphone permission.
  /// Returns false if permission check fails.
  Future<bool> hasPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'hasPermission',
      );
      return false;
    }
  }

  /// Checks if recording is currently paused.
  /// Returns false if check fails or recorder is not paused.
  Future<bool> isPaused() async {
    try {
      return await _audioRecorder.isPaused();
    } catch (e) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'isPaused',
      );
      return false;
    }
  }

  /// Checks if recording is currently active.
  /// Returns false if check fails or recorder is not recording.
  Future<bool> isRecording() async {
    try {
      return await _audioRecorder.isRecording();
    } catch (e) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'isRecording',
      );
      return false;
    }
  }

  Future<AudioNote?> startRecording() async {
    try {
      final created = DateTime.now();
      final fileName =
          '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.m4a';
      final day = DateFormat('yyyy-MM-dd').format(created);
      final relativePath = '/audio/$day/';
      final directory = await createAssetDirectory(relativePath);
      final filePath = '$directory$fileName';

      final audioNote = AudioNote(
        createdAt: created,
        audioFile: fileName,
        audioDirectory: relativePath,
        duration: Duration.zero,
      );

      const sampleRate = 48000;
      const autoGain = true;

      await _audioRecorder.start(
        const RecordConfig(
          sampleRate: sampleRate,
          autoGain: autoGain,
        ),
        path: filePath,
      );

      return audioNote;
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'startRecording',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> stopRecording() async {
    try {
      await _audioRecorder.stop();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'stopRecording',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _audioRecorder.pause();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'pauseRecording',
        stackTrace: stackTrace,
      );
    }
  }

  /// Resumes a paused recording.
  /// Only works if recording was previously paused.
  Future<void> resumeRecording() async {
    try {
      await _audioRecorder.resume();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'resumeRecording',
        stackTrace: stackTrace,
      );
    }
  }

  /// Disposes of the audio recorder and releases resources.
  /// Called when the repository is disposed.
  Future<void> dispose() async {
    try {
      await _audioRecorder.dispose();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'audio_recorder_repository',
        subDomain: 'dispose',
        stackTrace: stackTrace,
      );
    }
  }
}
