import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';

/// Riverpod stand-in for [AudioRecorderController] that serves a fixed
/// [AudioRecorderState] (idle/stopped by default) without booting the
/// platform-plugin-backed recorder repository.
class StubAudioRecorderController extends AudioRecorderController {
  StubAudioRecorderController([AudioRecorderState? state])
    : _state =
          state ??
          AudioRecorderState(
            status: AudioRecorderStatus.stopped,
            progress: Duration.zero,
            vu: -20,
            dBFS: -160,
            showIndicator: false,
            modalVisible: false,
          );

  final AudioRecorderState _state;

  @override
  AudioRecorderState build() => _state;
}
