import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recorder_controller.g.dart';

const intervalMs = 100;

@riverpod
class AudioRecorderController extends _$AudioRecorderController {
  final _audioRecorder = AudioRecorder();
  late final AudioPlayerCubit _audioPlayerCubit;
  StreamSubscription<Amplitude>? _amplitudeSub;
  late final LoggingService _loggingService;
  String? _linkedId;
  String? _categoryId;
  String? _language;
  AudioNote? _audioNote;

  @override
  AudioRecorderState build() {
    _audioPlayerCubit = getIt<AudioPlayerCubit>();
    _loggingService = getIt<LoggingService>();

    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: intervalMs))
        .listen((Amplitude amp) {
      state = state.copyWith(
        progress: Duration(
          milliseconds: state.progress.inMilliseconds + intervalMs,
        ),
        decibels: amp.current + 160,
      );
    });

    ref.onDispose(() async {
      await _audioRecorder.dispose();
      await _amplitudeSub?.cancel();
    });

    return AudioRecorderState(
      status: AudioRecorderStatus.initializing,
      decibels: 0,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
      language: '',
    );
  }

  Future<void> record({
    String? linkedId,
  }) async {
    _linkedId = linkedId;

    try {
      // Pause any playing audio first
      if (_audioPlayerCubit.state.status == AudioPlayerStatus.playing) {
        await _audioPlayerCubit.pause();
      }

      if (await _audioRecorder.hasPermission()) {
        if (await _audioRecorder.isPaused()) {
          await resume();
        } else if (await _audioRecorder.isRecording()) {
          await stop();
        } else {
          final created = DateTime.now();
          final fileName =
              '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.m4a';
          final day = DateFormat('yyyy-MM-dd').format(created);
          final relativePath = '/audio/$day/';
          final directory = await createAssetDirectory(relativePath);
          final filePath = '$directory$fileName';

          _audioNote = AudioNote(
            createdAt: created,
            audioFile: fileName,
            audioDirectory: relativePath,
            duration: Duration.zero,
          );

          await _audioRecorder.start(
            const RecordConfig(sampleRate: 48000),
            path: filePath,
          );
          state = state.copyWith(
            status: AudioRecorderStatus.recording,
            linkedId: linkedId,
          );
        }
      } else {
        _loggingService.captureEvent(
          'no audio recording permission',
          domain: 'recorder_controller',
        );
      }
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        stackTrace: stackTrace,
      );
    }
  }

  Future<String?> stop() async {
    try {
      debugPrint('stop recording');
      await _audioRecorder.stop();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: '',
      );
      if (_audioNote != null) {
        final journalAudio = await SpeechRepository.createAudioEntry(
          _audioNote!,
          language: _language,
          linkedId: _linkedId,
          categoryId: _categoryId,
        );
        _linkedId = null;
        final entryId = journalAudio?.meta.id;
        return entryId;
      }
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  Future<void> pause() async {
    await _audioRecorder.pause();
    state = state.copyWith(status: AudioRecorderStatus.paused);
  }

  Future<void> resume() async {
    await _audioRecorder.resume();
  }

  void setLanguage(String language) {
    _language = language;
    state = state.copyWith(language: language);
  }

  void setIndicatorVisible({required bool showIndicator}) {
    state = state.copyWith(showIndicator: showIndicator);
  }

  void setModalVisible({required bool modalVisible}) {
    debugPrint('AudioRecorderController: setModalVisible($modalVisible)');
    state = state.copyWith(modalVisible: modalVisible);
  }

  void setCategoryId(String? categoryId) {
    if (categoryId != _categoryId) {
      _categoryId = categoryId;
    }
  }
}
