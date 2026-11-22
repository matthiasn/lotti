import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';

import '../../relationships/helpers/check_in_speech_fakes.dart';

void main() {
  group('subjectTakeLiveProvider', () {
    late int built;
    late FakeAudioRecorderController recorder;

    ProviderContainer containerWith({String? runningFor}) {
      built = 0;
      recorder = FakeAudioRecorderController(runningFor: runningFor);
      final container = ProviderContainer(
        overrides: [
          audioRecorderControllerProvider.overrideWith(() {
            built++;
            return recorder;
          }),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('asking never stands the recorder up: one nobody built is not '
        'recording', () {
      final container = containerWith(runningFor: 'goal-1');
      final sub = container.listen(
        subjectTakeLiveProvider('goal-1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(sub.read(), isFalse);
      expect(built, 0);
    });

    test("it turns true once a recorder exists with this subject's take, "
        'and only for this subject', () async {
      final container = containerWith(runningFor: 'goal-1');
      final mine = container.listen(
        subjectTakeLiveProvider('goal-1'),
        (_, _) {},
      );
      final other = container.listen(
        subjectTakeLiveProvider('goal-2'),
        (_, _) {},
      );
      addTearDown(mine.close);
      addTearDown(other.close);
      expect(mine.read(), isFalse);

      // Someone opens a recorder — a sheet, the sidebar.
      container.read(audioRecorderControllerProvider);
      await pumpEventQueue();

      expect(built, 1);
      expect(mine.read(), isTrue);
      expect(other.read(), isFalse);
    });

    test('a paused take is still live; a stopped one is not', () async {
      final container = containerWith(runningFor: 'goal-1')
        ..read(audioRecorderControllerProvider);
      final live = container.listen(
        subjectTakeLiveProvider('goal-1'),
        (_, _) {},
      );
      addTearDown(live.close);
      expect(live.read(), isTrue);

      await recorder.pause();
      expect(live.read(), isTrue);

      await recorder.stop();
      expect(live.read(), isFalse);
    });
  });
}
