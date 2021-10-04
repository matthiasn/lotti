import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/location.dart';

enum AudioRecorderStatus { initializing, initialized, recording, stopped }

var uuid = const Uuid();

class AudioRecorderState extends Equatable {
  AudioRecorderStatus status = AudioRecorderStatus.initializing;
  Duration progress = Duration(seconds: 0);
  double decibels = 0.0;

  AudioRecorderState() {}

  AudioRecorderState.recording(AudioRecorderState other) {
    status = AudioRecorderStatus.recording;
  }

  AudioRecorderState.stopped(AudioRecorderState other) {
    status = AudioRecorderStatus.stopped;
  }

  AudioRecorderState.progress(
      AudioRecorderState other, RecordingDisposition event) {
    status = other.status;
    progress = event.duration;
    if (event.decibels != null) decibels = event.decibels!;
  }

  @override
  List<Object?> get props => [status, progress];
}

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  AudioNote? _audioNote;
  DeviceLocation _deviceLocation = DeviceLocation();

  AudioRecorderCubit() : super(AudioRecorderState()) {
    _myRecorder?.openAudioSession().then((value) {
      state.status = AudioRecorderStatus.initialized;
      emit(state);

      _myRecorder?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen((event) {
        updateProgress(event);
      });
    });
  }

  void updateProgress(RecordingDisposition event) {
    emit(AudioRecorderState.progress(state, event));
  }

  void _saveAudioNoteJson() async {
    String json = jsonEncode(_audioNote);
    print(json);
  }

  void record() async {
    DateTime now = DateTime.now();
    String fileName = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(now);
    String day = DateFormat('yyyy-MM-dd').format(now);

    var docDir = await getApplicationDocumentsDirectory();
    Directory directory =
        await Directory('${docDir.path}/audio/$day').create(recursive: true);

    String filePath = '${directory.path}/$fileName.aac';
    print('RECORD: ${filePath}');

    _audioNote = AudioNote(
        id: uuid.v1(options: {'msecs': now.millisecondsSinceEpoch}),
        createdAt: now.millisecondsSinceEpoch,
        audioFile: fileName,
        audioDirectory: filePath,
        durationMilliseconds: 0);

    _saveAudioNoteJson();

    _deviceLocation.getCurrentLocation().then((LocationData locationData) {
      if (_audioNote != null) {
        _audioNote!.latitude = locationData.latitude;
        _audioNote!.longitude = locationData.longitude;
      }
      _saveAudioNoteJson();
    });

    _myRecorder
        ?.startRecorder(
      toFile: filePath,
      codec: Codec.aacADTS,
    )
        .then((value) {
      emit(AudioRecorderState.recording(state));
    });
  }

  void stop() async {
    await _myRecorder?.stopRecorder();
    if (_audioNote != null) {
      _audioNote!.durationMilliseconds = state.progress.inMilliseconds;
    }
    _saveAudioNoteJson();
    emit(AudioRecorderState.stopped(state));
  }

  @override
  Future<void> close() async {
    super.close();
    _myRecorder?.stopRecorder();
  }
}
