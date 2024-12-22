import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart';

AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0,
  progress: Duration.zero,
  showIndicator: false,
  language: '',
);

const intervalMs = 100;

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  AudioRecorderCubit() : super(initialState) {
    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: intervalMs))
        .listen((Amplitude amp) {
      emit(
        state.copyWith(
          progress: Duration(
            milliseconds: state.progress.inMilliseconds + intervalMs,
          ),
          decibels: amp.current + 160,
        ),
      );
    });
  }

  final _audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  String? _linkedId;
  String? _language;
  AudioNote? _audioNote;

  Future<void> record({
    String? linkedId,
  }) async {
    _linkedId = linkedId;

    try {
      if (await _audioRecorder.hasPermission()) {
        if (await _audioRecorder.isPaused()) {
          await resume();
        } else if (await _audioRecorder.isRecording()) {
          await stop();
        } else {
          final created = DateTime.now();
          final fileName =
              '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
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
          emit(
            state.copyWith(
              status: AudioRecorderStatus.recording,
              linkedId: linkedId,
            ),
          );
        }
      } else {
        _loggingDb.captureEvent(
          'no audio recording permission',
          domain: 'recorder_cubit',
        );
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<String?> stop() async {
    try {
      debugPrint('stop recording');
      await _audioRecorder.stop();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
      emit(initialState.copyWith(status: AudioRecorderStatus.stopped));
      if (_audioNote != null) {
        final journalAudio = await persistenceLogic.createAudioEntry(
          _audioNote!,
          language: _language,
          linkedId: _linkedId,
        );
        _linkedId = null;
        final entryId = journalAudio?.meta.id;
        return entryId;
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  Future<void> pause() async {
    await _audioRecorder.pause();
    emit(state.copyWith(status: AudioRecorderStatus.paused));
  }

  Future<void> resume() async {
    await _audioRecorder.resume();
  }

  void setLanguage(String language) {
    _language = language;
    emit(state.copyWith(language: language));
  }

  void setIndicatorVisible({required bool showIndicator}) {
    emit(state.copyWith(showIndicator: showIndicator));
  }

  @override
  Future<void> close() async {
    await super.close();
    await _audioRecorder.dispose();
    await _amplitudeSub?.cancel();
  }
}
