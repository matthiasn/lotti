import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

enum RecorderStatus { initializing, initialized, recording, stopped }

class AudioRecorderState extends Equatable {
  bool recorderIsInitialized = false;
  bool isRecording = false;
  RecorderStatus status = RecorderStatus.initializing;
  Duration progress = Duration(seconds: 0);

  AudioRecorderState() {}

  AudioRecorderState.recording(AudioRecorderState other) {
    recorderIsInitialized = other.recorderIsInitialized;
    status = RecorderStatus.recording;
    isRecording = true;
  }

  AudioRecorderState.stopped(AudioRecorderState other) {
    recorderIsInitialized = other.recorderIsInitialized;
    status = RecorderStatus.stopped;
    isRecording = false;
  }

  AudioRecorderState.progress(
      AudioRecorderState other, RecordingDisposition event) {
    print('progress event: $event');
    recorderIsInitialized = other.recorderIsInitialized;
    status = other.status;
    isRecording = other.isRecording;
    progress = event.duration;
  }

  @override
  // TODO: implement props
  List<Object?> get props =>
      [isRecording, status, recorderIsInitialized, progress];
}

class AudioRecorderCubit extends Cubit<AudioRecorderState> {
  FlutterSoundRecorder? _myRecorder = FlutterSoundRecorder();

  AudioRecorderCubit() : super(AudioRecorderState()) {
    _myRecorder?.openAudioSession().then((value) {
      state.recorderIsInitialized = true;
      state.status = RecorderStatus.initialized;
      emit(state);

      _myRecorder?.setSubscriptionDuration(const Duration(milliseconds: 500));
      _myRecorder?.onProgress?.listen((event) {
        updateProgress(event);
      });
    });
  }

  void updateProgress(RecordingDisposition event) {
    AudioRecorderState newState = AudioRecorderState.progress(state, event);
    print('updateProgress $newState');
    emit(AudioRecorderState.progress(state, event));
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
        .then((value) {
      emit(AudioRecorderState.recording(state));
    });
  }

  void stop() async {
    await _myRecorder?.stopRecorder().then((value) {
      emit(AudioRecorderState.stopped(state));
    });
  }
}
