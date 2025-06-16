import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recorder_controller.g.dart';

const intervalMs = 100;

@riverpod
class AudioRecorderController extends _$AudioRecorderController {
  late final AudioRecorderRepository _recorderRepository;
  StreamSubscription<Amplitude>? _amplitudeSub;
  late final LoggingService _loggingService;
  String? _linkedId;
  String? _categoryId;
  String? _language;
  AudioNote? _audioNote;

  @override
  AudioRecorderState build() {
    _recorderRepository = ref.watch(audioRecorderRepositoryProvider);
    _loggingService = getIt<LoggingService>();

    _amplitudeSub = _recorderRepository.amplitudeStream.listen((Amplitude amp) {
      state = state.copyWith(
        progress: Duration(
          milliseconds: state.progress.inMilliseconds + intervalMs,
        ),
        decibels: amp.current + 160,
      );
    });

    ref.onDispose(() async {
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
      if (await _recorderRepository.hasPermission()) {
        if (await _recorderRepository.isPaused()) {
          await resume();
        } else if (await _recorderRepository.isRecording()) {
          await stop();
        } else {
          _audioNote = await _recorderRepository.startRecording();
          if (_audioNote != null) {
            state = state.copyWith(
              status: AudioRecorderStatus.recording,
              linkedId: linkedId,
            );
          }
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
      await _recorderRepository.stopRecording();
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
    await _recorderRepository.pauseRecording();
    state = state.copyWith(status: AudioRecorderStatus.paused);
  }

  Future<void> resume() async {
    await _recorderRepository.resumeRecording();
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
