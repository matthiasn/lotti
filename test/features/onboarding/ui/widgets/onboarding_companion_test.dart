import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_view.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../tts/test_utils.dart';

const _line = 'Talk. Lotti turns it into a plan.';

/// Her ticker runs for as long as she is on screen, so these tests pump a
/// fixed number of frames instead of settling.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

CompanionView _view(WidgetTester tester) =>
    tester.widget<CompanionView>(find.byType(CompanionView));

void main() {
  test('each first-task frame has its beat', () {
    expect(
      OnboardingFirstTaskPhase.values.map(OnboardingCompanionBeat.of),
      [
        OnboardingCompanionBeat.prompt,
        OnboardingCompanionBeat.listening,
        OnboardingCompanionBeat.thinking,
        OnboardingCompanionBeat.created,
      ],
    );
  });

  test('she greets, listens, thinks and celebrates', () {
    expect(OnboardingCompanionBeat.welcome.cue, GestureName.wave);
    expect(OnboardingCompanionBeat.prompt.cue, GestureName.wave);
    expect(OnboardingCompanionBeat.listening.holding, GestureName.listen);
    expect(OnboardingCompanionBeat.thinking.holding, GestureName.think);
    expect(OnboardingCompanionBeat.created.cue, GestureName.celebrate);
  });

  group('OnboardingCompanion', () {
    late FakeTtsEngine engine;
    late FakeTtsAudioPlayer player;
    late FakeTtsModelRepository models;
    late Stream<bool> Function() readAloud;
    late ValueNotifier<Widget> shown;

    setUp(() {
      engine = FakeTtsEngine();
      player = FakeTtsAudioPlayer();
      models = FakeTtsModelRepository();
      readAloud = () => Stream.value(true);
      shown = ValueNotifier(const SizedBox());
    });

    tearDown(() => shown.dispose());

    // One scope for the whole test, its child swapped through [shown]:
    // pumping a fresh bench would hand the scope new overrides.
    Future<void> show(WidgetTester tester, Widget child) async {
      shown.value = child;
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => flagName == enableAiSummaryTtsFlag
                  ? readAloud()
                  : Stream.value(flagName == enableCompanionFlag),
            ),
            ttsEngineProvider.overrideWithValue(engine),
            ttsPlaybackControllerProvider.overrideWith(
              () => TtsPlaybackController(logger: MockDomainLogger()),
            ),
            ttsAudioPlayerProvider.overrideWithValue(player),
            ttsModelRepositoryProvider.overrideWithValue(models),
            spokenTrackLoaderProvider.overrideWithValue(
              (clip, text) => Completer<MouthTrack>().future,
            ),
          ],
          child: SizedBox.square(
            dimension: 200,
            child: ValueListenableBuilder<Widget>(
              valueListenable: shown,
              builder: (_, child, _) => child,
            ),
          ),
        ),
      );
      await _pumpFrames(tester);
    }

    Future<void> swap(WidgetTester tester, Widget child) async {
      shown.value = child;
      await _pumpFrames(tester);
    }

    testWidgets("cues the beat's gesture once she is on screen", (
      tester,
    ) async {
      await show(
        tester,
        const OnboardingCompanion(beat: OnboardingCompanionBeat.welcome),
      );
      expect(_view(tester).controller!.gesture, GestureName.wave);

      await swap(
        tester,
        const OnboardingCompanion(beat: OnboardingCompanionBeat.created),
      );
      expect(_view(tester).controller!.gesture, GestureName.celebrate);
    });

    testWidgets("holds the beat's gesture, in the framing given", (
      tester,
    ) async {
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.listening,
          framing: CompanionFraming.bust,
        ),
      );

      expect(_view(tester).holding, GestureName.listen);
      expect(_view(tester).framing, CompanionFraming.bust);
    });

    testWidgets('speaks her line where the voice is on hand', (tester) async {
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: _line,
        ),
      );

      expect(engine.calls.single.text, _line);
      expect(player.playCount, 1);
    });

    testWidgets('is silent while the voice model is not installed', (
      tester,
    ) async {
      models = FakeTtsModelRepository(installed: false);
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: _line,
        ),
      );

      expect(engine.calls, isEmpty);
      // A first impression never starts the model download.
      expect(models.ensureCount, 0);
    });

    testWidgets('is silent while read-aloud is off', (tester) async {
      readAloud = () => Stream.value(false);
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: _line,
        ),
      );

      expect(engine.calls, isEmpty);
    });

    testWidgets('speaks once the read-aloud flag loads', (tester) async {
      final flag = StreamController<bool>();
      addTearDown(flag.close);
      readAloud = () => flag.stream;
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: _line,
        ),
      );
      expect(engine.calls, isEmpty);

      flag.add(true);
      await _pumpFrames(tester);

      expect(engine.calls.single.text, _line);
    });

    testWidgets('turning read-aloud off silences her', (tester) async {
      final flag = StreamController<bool>();
      addTearDown(flag.close);
      readAloud = () => flag.stream;
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: _line,
        ),
      );
      flag.add(true);
      await _pumpFrames(tester);
      expect(engine.calls.single.text, _line);
      expect(player.stopCount, 0);

      flag.add(false);
      await _pumpFrames(tester);

      expect(player.stopCount, 1);
      expect(engine.calls, hasLength(1));
    });

    testWidgets('a new line replaces the one she is saying', (tester) async {
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.prompt,
          line: 'First',
        ),
      );

      await swap(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.thinking,
          line: 'Second',
        ),
      );

      expect(engine.calls.map((c) => c.text), ['First', 'Second']);
      expect(player.stopCount, 1);
      expect(player.playCount, 2);
    });

    testWidgets('a null line stops her, so she never talks over a recording', (
      tester,
    ) async {
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.prompt,
          line: _line,
        ),
      );
      expect(player.stopCount, 0);

      await swap(
        tester,
        const OnboardingCompanion(beat: OnboardingCompanionBeat.listening),
      );

      expect(player.stopCount, 1);
      expect(engine.calls, hasLength(1));
    });

    testWidgets('leaving the surface stops her', (tester) async {
      await show(
        tester,
        const OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: _line,
        ),
      );
      expect(player.stopCount, 0);

      await swap(tester, const SizedBox());

      expect(player.stopCount, 1);
    });
  });
}
