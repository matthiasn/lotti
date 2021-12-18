import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/location.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0.0,
  progress: const Duration(minutes: 0),
);

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  late final PersistenceCubit _persistenceCubit;

  final FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  AudioNote? _audioNote;
  final DeviceLocation _deviceLocation = DeviceLocation();

  AudioRecorderCubit({required PersistenceCubit persistenceCubit})
      : super(initialState) {
    _persistenceCubit = persistenceCubit;
  }

  Future<void> _openAudioSession() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          throw RecordingPermissionException(
              'Microphone permission not granted');
        }
      }

      await _myRecorder?.openAudioSession();
      emit(state.copyWith(status: AudioRecorderStatus.initialized));
      _myRecorder?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen((event) {
        updateProgress(event);
      });
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  void updateProgress(RecordingDisposition event) {
    emit(state.copyWith(
      progress: event.duration,
      decibels: event.decibels ?? 0.0,
    ));
  }

  void _saveAudioNoteJson() async {
    if (_audioNote != null) {
      _audioNote = _audioNote?.copyWith(updatedAt: DateTime.now());
    }
  }

  void _addGeolocation() async {
    try {
      _deviceLocation.getCurrentGeoLocation().then((Geolocation? geolocation) {
        if (geolocation != null) {
          _audioNote = _audioNote?.copyWith(geolocation: geolocation);
          _saveAudioNoteJson();
        }
      });
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  void record() async {
    try {
      await _openAudioSession();
      DateTime created = DateTime.now();
      String fileName =
          '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
      String day = DateFormat('yyyy-MM-dd').format(created);
      String relativePath = '/audio/$day/';
      String directory = await AudioUtils.createAssetDirectory(relativePath);
      String filePath = '$directory$fileName';
      String timezone = await FlutterNativeTimezone.getLocalTimezone();

      _audioNote = AudioNote(
          id: uuid.v1(options: {'msecs': created.millisecondsSinceEpoch}),
          timestamp: created.millisecondsSinceEpoch,
          createdAt: created,
          utcOffset: created.timeZoneOffset.inMinutes,
          timezone: timezone,
          audioFile: fileName,
          audioDirectory: relativePath,
          duration: const Duration(seconds: 0));

      _saveAudioNoteJson();
      _addGeolocation();

      _myRecorder
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
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  void stop() async {
    try {
      await _myRecorder?.stopRecorder();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
      _saveAudioNoteJson();
      emit(initialState);

      if (_audioNote != null) {
        AudioNote audioNote = _audioNote!;
        _persistenceCubit.createAudioEntry(audioNote);
      }
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _myRecorder?.stopRecorder();
  }
}
