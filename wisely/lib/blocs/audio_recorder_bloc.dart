import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

enum RecorderStatus { initializing, initialized, recording, stopped }

abstract class AudioRecorderEvent {}

class RecordEvent extends AudioRecorderEvent {}

class StopRecordEvent extends AudioRecorderEvent {}

class AudioRecorderState extends Equatable {
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();
  bool recorderIsInited = false;
  bool isRecording = false;
  RecorderStatus status = RecorderStatus.initializing;

  AudioRecorderState() {
    _myRecorder?.openAudioSession().then((value) {
      recorderIsInited = true;
      status = RecorderStatus.initialized;
    });
  }

  Future<void> record() async {
    var docDir = await getApplicationDocumentsDirectory();
    String _path = '${docDir.path}/flutter_sound.aac';
    print('RECORD: ${_path}');

    await _myRecorder
        ?.startRecorder(
      toFile: _path,
      codec: Codec.aacADTS,
    )
        .then((value) {
      isRecording = true;
      status = RecorderStatus.recording;
    });
  }

  Future<void> stopRecorder() async {
    await _myRecorder?.stopRecorder().then((value) {
      isRecording = false;
      status = RecorderStatus.stopped;
    });
  }

  @override
  void dispose() {
    _myRecorder?.closeAudioSession();
  }

  @override
  // TODO: implement props
  List<Object?> get props => [isRecording, status];
}

class AudioRecorderBloc extends Bloc<AudioRecorderEvent, AudioRecorderState> {
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();

  AudioRecorderBloc() : super(AudioRecorderState()) {
    on<RecordEvent>((event, emit) async {
      state.isRecording = true;
      emit(state);
      state.record();
    });
    on<StopRecordEvent>((event, emit) async {
      state.isRecording = false;
      state.stopRecorder();
      emit(state);
    });
  }
}
