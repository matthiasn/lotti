import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/location.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/timezone.dart';
import 'package:permission_handler/permission_handler.dart';

AudioRecorderState initialState = AudioRecorderState(
  status: AudioRecorderStatus.initializing,
  decibels: 0.0,
  progress: const Duration(minutes: 0),
);

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  final InsightsDb _insightsDb = getIt<InsightsDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  String? _linkedId;

  FlutterSoundRecorder? _myRecorder;
  AudioNote? _audioNote;
  DeviceLocation? _deviceLocation;

  AudioRecorderCubit() : super(initialState) {
    if (!Platform.isLinux && !Platform.isWindows) {
      _deviceLocation = DeviceLocation();
    }
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
      _myRecorder = FlutterSoundRecorder();
      await _myRecorder?.openAudioSession();
      emit(state.copyWith(status: AudioRecorderStatus.initialized));
      _myRecorder?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen((event) {
        updateProgress(event);
      });
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
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
      _deviceLocation?.getCurrentGeoLocation().then((Geolocation? geolocation) {
        if (geolocation != null) {
          _audioNote = _audioNote?.copyWith(geolocation: geolocation);
          _saveAudioNoteJson();
        }
      });
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }
  }

  void record({
    String? linkedId,
  }) async {
    _linkedId = linkedId;
    try {
      await _openAudioSession();
      DateTime created = DateTime.now();
      String fileName =
          '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
      String day = DateFormat('yyyy-MM-dd').format(created);
      String relativePath = '/audio/$day/';
      String directory = await createAssetDirectory(relativePath);
      String filePath = '$directory$fileName';

      _audioNote = AudioNote(
          id: uuid.v1(options: {'msecs': created.millisecondsSinceEpoch}),
          timestamp: created.millisecondsSinceEpoch,
          createdAt: created,
          utcOffset: created.timeZoneOffset.inMinutes,
          timezone: await getLocalTimezone(),
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
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
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
        persistenceLogic.createAudioEntry(
          audioNote,
          linkedId: _linkedId,
        );
        _linkedId = null;
      }
    } catch (exception, stackTrace) {
      await _insightsDb.captureException(exception, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _myRecorder?.stopRecorder();
  }
}
