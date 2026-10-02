import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';

AudioRecorderState _state({
  required AudioRecorderStatus status,
  String? linkedId,
}) => AudioRecorderState(
  status: status,
  progress: Duration.zero,
  vu: -20,
  dBFS: -160,
  showIndicator: false,
  modalVisible: false,
  linkedId: linkedId,
);

void main() {
  group('isActiveSessionFor', () {
    test('a recording linked to the id is active for it', () {
      final state = _state(
        status: AudioRecorderStatus.recording,
        linkedId: 'entry-1',
      );
      expect(state.isActiveSessionFor('entry-1'), isTrue);
    });

    test('a paused recording linked to the id still counts as active', () {
      final state = _state(
        status: AudioRecorderStatus.paused,
        linkedId: 'entry-1',
      );
      expect(state.isActiveSessionFor('entry-1'), isTrue);
    });

    test('a stopped session linked to the id is not active', () {
      final state = _state(
        status: AudioRecorderStatus.stopped,
        linkedId: 'entry-1',
      );
      expect(state.isActiveSessionFor('entry-1'), isFalse);
    });

    test("a recording linked to another id is not this one's", () {
      final state = _state(
        status: AudioRecorderStatus.recording,
        linkedId: 'entry-2',
      );
      expect(state.isActiveSessionFor('entry-1'), isFalse);
    });

    test("a recording linked to nothing is nobody's", () {
      final state = _state(status: AudioRecorderStatus.recording);
      expect(state.isActiveSessionFor('entry-1'), isFalse);
    });
  });
}
