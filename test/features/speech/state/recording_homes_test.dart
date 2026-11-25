import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_homes.dart';

import '../../relationships/helpers/check_in_speech_fakes.dart';

/// A recorder whose audio stack failed to load.
class _BrokenRecorder extends FakeAudioRecorderController {
  @override
  AudioRecorderState build() => throw StateError('no audio stack');
}

void main() {
  late FakeAudioRecorderController recorder;
  late ProviderContainer container;

  ProviderContainer make(FakeAudioRecorderController fake) {
    final made = ProviderContainer(
      overrides: [audioRecorderControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(made.dispose);
    return made;
  }

  setUp(() {
    recorder = FakeAudioRecorderController();
    container = make(recorder)..read(audioRecorderControllerProvider);
  });

  RecordingHomes homes() => container.read(recordingHomesProvider.notifier);
  Map<String, int> state() => container.read(recordingHomesProvider);
  bool away() => takeAwayFromHome(container.read);

  group('RecordingHomes', () {
    test('starts empty', () {
      expect(state(), isEmpty);
    });

    test('counts the homes of one subject, and lets it go with the last', () {
      homes()
        ..enter('task-1')
        ..enter('task-1');
      expect(state(), {'task-1': 2});
      homes().leave('task-1');
      expect(state(), {'task-1': 1});
      homes().leave('task-1');
      expect(state(), isEmpty);
    });

    test('leaving a subject never entered changes nothing', () {
      homes()
        ..enter('task-1')
        ..leave('task-2');
      expect(state(), {'task-1': 1});
    });
  });

  group('takeAwayFromHome', () {
    test('nothing recording: no', () {
      expect(away(), isFalse);
    });

    test('a running take with no home on screen: yes', () async {
      await recorder.record(linkedId: 'task-1');
      expect(away(), isTrue);
    });

    test("a take whose subject's home is on screen: no", () async {
      homes().enter('task-1');
      await recorder.record(linkedId: 'task-1');
      expect(away(), isFalse);
    });

    test("another subject's home on screen leaves the take away", () async {
      homes().enter('task-2');
      await recorder.record(linkedId: 'task-1');
      expect(away(), isTrue);
    });

    test('a take a check-in draws in place: no', () async {
      await recorder.record(linkedId: 'task-1');
      recorder.setInlineHostVisible(visible: true);
      expect(away(), isFalse);
    });

    test('a paused take still counts', () async {
      await recorder.record(linkedId: 'task-1');
      await recorder.pause();
      expect(away(), isTrue);
    });

    test('a recorder that cannot be built: no, rather than throwing', () {
      final broken = make(_BrokenRecorder());
      expect(takeAwayFromHome(broken.read), isFalse);
    });
  });
}
