import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_recorder_repository.g.dart';

/// Provider for the audio recorder repository.
/// Kept alive to maintain recording state across navigation.
@Riverpod(keepAlive: true)
AudioRecorderRepository audioRecorderRepository(Ref ref) {
  final repository = AudioRecorderRepository();
  ref.onDispose(() async {
    await repository.dispose();
  });
  return repository;
}

/// Constants for audio recording configuration
class AudioRecorderConstants {
  const AudioRecorderConstants._();

  // Recording configuration
  static const int sampleRate = 48000;
  static const bool autoGain = true;
  static const String audioFileExtension = '.m4a';
  static const String audioDirectoryPrefix = '/audio/';

  // Date formats
  static const String fileNameDateFormat = 'yyyy-MM-dd_HH-mm-ss-S';
  static const String directoryDateFormat = 'yyyy-MM-dd';

  // Domain names for logging
  static const String domainName = 'audio_recorder_repository';
  static const String hasPermissionSubdomain = 'hasPermission';
  static const String isPausedSubdomain = 'isPaused';
  static const String isRecordingSubdomain = 'isRecording';
  static const String startRecordingSubdomain = 'startRecording';
  static const String stopRecordingSubdomain = 'stopRecording';
  static const String pauseRecordingSubdomain = 'pauseRecording';
  static const String resumeRecordingSubdomain = 'resumeRecording';
  static const String disposeSubdomain = 'dispose';
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
  AudioRecorderRepository([AudioRecorder? audioRecorder])
      : _audioRecorder = audioRecorder ?? AudioRecorder();

  final AudioRecorder _audioRecorder;
  final LoggingService _loggingService = getIt<LoggingService>();

  /// Stream of amplitude updates for VU meter visualization.
  /// Emits amplitude values every 20ms while recording.
  Stream<Amplitude> get amplitudeStream => _audioRecorder.onAmplitudeChanged(
        const Duration(milliseconds: intervalMs),
      );

  /// Checks if the app has microphone permission.
  /// In Flatpak environments, relies on PulseAudio socket permissions.
  /// Returns false if permission check fails.
  Future<bool> hasPermission() async {
    try {
      // In Flatpak, audio access is handled via PulseAudio socket permissions
      // set in the manifest with --socket=pulseaudio
      // No need for XDG Desktop Portal as there's no microphone portal yet

      if (Platform.isLinux && PortalService.isRunningInFlatpak) {
        _loggingService.captureEvent(
          'Running in Flatpak - audio access via PulseAudio socket permissions',
          domain: AudioRecorderConstants.domainName,
          subDomain: AudioRecorderConstants.hasPermissionSubdomain,
        );
        // In Flatpak, assume permission is available if PulseAudio socket is granted
        // The manifest should include --socket=pulseaudio
      }

      // Check the standard recorder permission (works for both Flatpak and native)
      return await _audioRecorder.hasPermission();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.hasPermissionSubdomain,
        stackTrace: stackTrace,
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
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.isPausedSubdomain,
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
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.isRecordingSubdomain,
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

      _loggingService.captureEvent(
        'Starting audio recording: path=$filePath, sampleRate=$sampleRate, autoGain=$autoGain, isLinux=${Platform.isLinux}, isFlatpak=${PortalService.shouldUsePortal}',
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.startRecordingSubdomain,
      );

      await _audioRecorder.start(
        const RecordConfig(
          sampleRate: sampleRate,
          autoGain: autoGain,
        ),
        path: filePath,
      );

      _loggingService.captureEvent(
        'Audio recording started successfully',
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.startRecordingSubdomain,
      );

      return audioNote;
    } catch (e, stackTrace) {
      // Log context information separately
      _loggingService
        ..captureEvent(
          'Recording error context: isLinux=${Platform.isLinux}, isFlatpak=${PortalService.shouldUsePortal}',
          domain: AudioRecorderConstants.domainName,
          subDomain: AudioRecorderConstants.startRecordingSubdomain,
        )
        // Pass the original exception object
        ..captureException(
          e,
          domain: AudioRecorderConstants.domainName,
          subDomain: AudioRecorderConstants.startRecordingSubdomain,
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
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.stopRecordingSubdomain,
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
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.pauseRecordingSubdomain,
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
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.resumeRecordingSubdomain,
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
        domain: AudioRecorderConstants.domainName,
        subDomain: AudioRecorderConstants.disposeSubdomain,
        stackTrace: stackTrace,
      );
    }
  }
}
