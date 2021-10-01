import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

enum RecorderStatus { initializing, initialized, recording, stopped }

class AudioRecorderState2 extends Equatable {
  bool recorderIsInitialized = false;
  bool isRecording = false;
  RecorderStatus status = RecorderStatus.initializing;

  AudioRecorderState2() {}

  AudioRecorderState2.recording(AudioRecorderState2 other) {
    recorderIsInitialized = other.recorderIsInitialized;
    status = RecorderStatus.recording;
    isRecording = true;
  }

  AudioRecorderState2.stopped(AudioRecorderState2 other) {
    recorderIsInitialized = other.recorderIsInitialized;
    status = RecorderStatus.stopped;
    isRecording = false;
  }

  @override
  // TODO: implement props
  List<Object?> get props => [isRecording, status, recorderIsInitialized];
}

class AudioRecorderCubit extends Cubit<AudioRecorderState2> {
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();

  AudioRecorderCubit() : super(AudioRecorderState2()) {
    _myRecorder?.openAudioSession().then((value) {
      state.recorderIsInitialized = true;
      state.status = RecorderStatus.initialized;
      emit(state);
    });
  }

  void record() async {
    var docDir = await getApplicationDocumentsDirectory();
    String _path = '${docDir.path}/flutter_sound.aac';
    print('RECORD: ${_path}');

    _myRecorder
        ?.startRecorder(
          toFile: _path,
          codec: Codec.aacADTS,
        )
        .then((value) {});
    emit(AudioRecorderState2.recording(state));
  }

  void stop() async {
    await _myRecorder?.stopRecorder().then((value) {
      emit(AudioRecorderState2.stopped(state));
    });
  }
}
