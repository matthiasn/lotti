import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/vector_clock_counter_cubit.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/audio_utils.dart';

import 'audio_notes_cubit.dart';

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
  late final VectorClockCubit _vectorClockCubit;
  late final AudioNotesCubit _audioNotesCubit;
  final FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  AudioNote? _audioNote;
  final DeviceLocation _deviceLocation = DeviceLocation();

  AudioRecorderCubit(
      {required VectorClockCubit vectorClockCubit,
      required AudioNotesCubit audioNotesCubit})
      : super(AudioRecorderState()) {
    _audioNotesCubit = audioNotesCubit;
    _vectorClockCubit = vectorClockCubit;
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

  void assignVectorClock() {
    String host = _vectorClockCubit.state.host;
    int nextAvailableCounter = _vectorClockCubit.state.nextAvailableCounter;

    if (_audioNote?.vectorClock == null) {
      _audioNote!.vectorClock = VectorClock(<String, int>{});
    }

    _audioNote!.vectorClock!.vclock[host] = nextAvailableCounter;
    _vectorClockCubit.increment();
  }

  void _saveAudioNoteJson() async {
    if (_audioNote != null) {
      _audioNote!.updatedAt = DateTime.now();
      assignVectorClock();
      String json = jsonEncode(_audioNote);
      File file =
          File('${await AudioUtils.getFullAudioPath(_audioNote!)}.json');
      await file.writeAsString(json);
      print(json);
      _audioNotesCubit.save(_audioNote!);
    }
  }

  void _addGeolocation() async {
    _deviceLocation.getCurrentLocation().then((LocationData locationData) {
      if (_audioNote != null) {
        _audioNote!.latitude = locationData.latitude;
        _audioNote!.longitude = locationData.longitude;
      }
      _saveAudioNoteJson();
    });
  }

  void record() async {
    DateTime created = DateTime.now();
    String fileName =
        '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created)}.aac';
    String day = DateFormat('yyyy-MM-dd').format(created);
    String relativePath = '/audio/$day/';
    String directory = await AudioUtils.createAudioDirectory(relativePath);
    String filePath = '${directory}$fileName';
    print('RECORD: ${filePath}');
    String timezone = await FlutterNativeTimezone.getLocalTimezone();

    _audioNote = AudioNote(
        id: uuid.v1(options: {'msecs': created.millisecondsSinceEpoch}),
        timestamp: created.millisecondsSinceEpoch,
        createdAt: created,
        utcOffset: created.timeZoneOffset.inMinutes,
        timezone: timezone,
        audioFile: fileName,
        audioDirectory: relativePath,
        duration: Duration(seconds: 0));

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
      emit(AudioRecorderState.recording(state));
    });
  }

  void stop() async {
    await _myRecorder?.stopRecorder();
    if (_audioNote != null) {
      _audioNote!.duration = state.progress;
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
