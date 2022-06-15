import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/location.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:permission_handler/permission_handler.dart';

AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0,
  progress: Duration.zero,
);

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  AudioRecorderCubit() : super(initialState) {
    if (!Platform.isLinux && !Platform.isWindows) {
      _deviceLocation = DeviceLocation();
    }
  }

  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  String? _linkedId;

  FlutterSoundRecorder? _myRecorder;
  AudioNote? _audioNote;
  DeviceLocation? _deviceLocation;

  Future<void> _openAudioSession() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          throw RecordingPermissionException(
            'Microphone permission not granted',
          );
        }
      }
      _myRecorder = FlutterSoundRecorder();
      await _myRecorder?.openAudioSession();
      emit(state.copyWith(status: AudioRecorderStatus.initialized));
      await _myRecorder
          ?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen(updateProgress);
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void updateProgress(RecordingDisposition event) {
    emit(
      state.copyWith(
        progress: event.duration,
        decibels: event.decibels ?? 0,
      ),
    );
  }

  Future<void> _saveAudioNoteJson() async {
    if (_audioNote != null) {
      _audioNote = _audioNote?.copyWith(updatedAt: DateTime.now());
    }
  }

  Future<void> _addGeolocation() async {
    try {
      await _deviceLocation
          ?.getCurrentGeoLocation()
          .then((Geolocation? geolocation) {
        if (geolocation != null) {
          _audioNote = _audioNote?.copyWith(geolocation: geolocation);
          _saveAudioNoteJson();
        }
      });
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> record({
    String? linkedId,
  }) async {
    if (state.status == AudioRecorderStatus.recording) {
      await stop();
    } else {
      _linkedId = linkedId;
      try {
        await _openAudioSession();
        final created = DateTime.now();
        final fileName =
            '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
        final day = DateFormat('yyyy-MM-dd').format(created);
        final relativePath = '/audio/$day/';
        final directory = await createAssetDirectory(relativePath);
        final filePath = '$directory$fileName';

        _audioNote = AudioNote(
          id: uuid.v1(options: {'msecs': created.millisecondsSinceEpoch}),
          timestamp: created.millisecondsSinceEpoch,
          createdAt: created,
          utcOffset: created.timeZoneOffset.inMinutes,
          timezone: await getLocalTimezone(),
          audioFile: fileName,
          audioDirectory: relativePath,
          duration: Duration.zero,
        );

        await _saveAudioNoteJson();
        unawaited(_addGeolocation());

        await _myRecorder
            ?.startRecorder(
          toFile: filePath,
          codec: Codec.aacADTS,
          sampleRate: 48000,
          bitRate: 128000,
        )
            .then((value) {
          emit(state.copyWith(status: AudioRecorderStatus.recording));
        });
      } catch (exception, stackTrace) {
        _loggingDb.captureException(
          exception,
          domain: 'recorder_cubit',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> stop() async {
    try {
      await _myRecorder?.stopRecorder();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
      await _saveAudioNoteJson();
      emit(initialState);

      if (_audioNote != null) {
        final audioNote = _audioNote!;
        await persistenceLogic.createAudioEntry(
          audioNote,
          linkedId: _linkedId,
        );
        _linkedId = null;
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'recorder_cubit',
        stackTrace: stackTrace,
      );
    }
    await getIt<AppRouter>().pop();
  }

  @override
  Future<void> close() async {
    await super.close();
    await _myRecorder?.stopRecorder();
  }
}
