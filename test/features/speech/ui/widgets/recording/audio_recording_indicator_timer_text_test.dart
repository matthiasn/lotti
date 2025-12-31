import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AudioRecordingIndicator text width is stable', (tester) async {
    Override overrideWithProgress(Duration d) {
      return audioRecorderControllerProvider.overrideWith(
        () => _FakeRecorderController(
          AudioRecorderState(
            status: AudioRecorderStatus.recording,
            progress: d,
            vu: -10,
            dBFS: -20,
            showIndicator: true,
            modalVisible: false,
          ),
        ),
      );
    }

    Future<double> pumpAndMeasure(Duration d) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [overrideWithProgress(d)],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: AudioRecordingIndicator()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final byKey = find.byKey(const Key('audio_recording_indicator'));
      expect(byKey, findsOneWidget);
      final textFinder = find.descendant(
        of: byKey,
        matching: find.byType(Text),
      );
      expect(textFinder, findsOneWidget);
      return tester.getSize(textFinder).width;
    }

    final w1 = await pumpAndMeasure(const Duration(minutes: 41));
    final w2 = await pumpAndMeasure(const Duration(minutes: 48));
    expect(w1, equals(w2));
  });
}

class _FakeRecorderController extends AudioRecorderController {
  _FakeRecorderController(this._initial);
  final AudioRecorderState _initial;
  @override
  AudioRecorderState build() => _initial;
}
