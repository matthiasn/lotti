import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ai/ui/settings/services/connection_verifier_service.dart';
import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/spoken_track.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_companion.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_view.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../agents/test_data/ai_config_factories.dart';
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

  test('she opens her arms to be dressed on "make me yours"', () {
    expect(OnboardingCompanionBeat.dressUp.cue, GestureName.openBoth);
    expect(OnboardingCompanionBeat.dressUp.holding, isNull);
    expect(
      OnboardingCompanionBeat.dressUp.sourceId,
      'onboarding-companion-make-her-yours',
    );
  });

  test('she offers the voices she can have', () {
    expect(OnboardingCompanionBeat.voices.cue, GestureName.openSmall);
    expect(OnboardingCompanionBeat.voices.holding, isNull);
    expect(
      OnboardingCompanionBeat.voices.sourceId,
      'onboarding-companion-voices',
    );
  });

  test('on the key step she waits, thinks while it is checked, and takes '
      'the verdict well or badly', () {
    expect(
      OnboardingCompanionBeat.ofKeyCheck(const ConnectionCheckIdle()),
      OnboardingCompanionBeat.key,
    );
    expect(
      OnboardingCompanionBeat.ofKeyCheck(const ConnectionCheckChecking()),
      OnboardingCompanionBeat.keyChecking,
    );
    expect(
      OnboardingCompanionBeat.ofKeyCheck(
        const ConnectionCheckVerified(modelCount: 1, latency: Duration.zero),
      ),
      OnboardingCompanionBeat.keyVerified,
    );
    expect(
      OnboardingCompanionBeat.ofKeyCheck(
        const ConnectionCheckFailedHttp(status: 401, message: 'no'),
      ),
      OnboardingCompanionBeat.keyRejected,
    );
    expect(
      OnboardingCompanionBeat.ofKeyCheck(
        const ConnectionCheckFailedNetwork(message: 'offline'),
      ),
      OnboardingCompanionBeat.keyRejected,
    );
    expect(OnboardingCompanionBeat.key.cue, isNull);
    expect(OnboardingCompanionBeat.key.holding, isNull);
    expect(OnboardingCompanionBeat.keyChecking.holding, GestureName.think);
    expect(OnboardingCompanionBeat.keyVerified.cue, GestureName.thumbs);
    expect(OnboardingCompanionBeat.keyRejected.cue, GestureName.shrug);
    // One step, one voice.
    expect(
      {
        for (final beat in [
          OnboardingCompanionBeat.key,
          OnboardingCompanionBeat.keyChecking,
          OnboardingCompanionBeat.keyVerified,
          OnboardingCompanionBeat.keyRejected,
        ])
          beat.sourceId,
      },
      {'onboarding-companion-key'},
    );
  });

  test('she celebrates her first words, and presents the areas', () {
    expect(OnboardingCompanionBeat.firstWords.cue, GestureName.celebrate);
    expect(
      OnboardingCompanionBeat.firstWords.sourceId,
      'onboarding-companion-first-words',
    );
    expect(OnboardingCompanionBeat.areas.cue, GestureName.openBoth);
    expect(
      OnboardingCompanionBeat.areas.sourceId,
      'onboarding-companion-areas',
    );
  });

  test('she presents the one key she recommends', () {
    expect(OnboardingCompanionBeat.recommend.cue, GestureName.presentRight);
    expect(OnboardingCompanionBeat.recommend.holding, isNull);
  });

  test('each step speaks under its own source; one step shares one', () {
    expect(
      OnboardingCompanionBeat.welcome.sourceId,
      'onboarding-companion-welcome',
    );
    expect(
      OnboardingCompanionBeat.recommend.sourceId,
      'onboarding-companion-connect',
    );
    final firstTask = {
      for (final phase in OnboardingFirstTaskPhase.values)
        OnboardingCompanionBeat.of(phase).sourceId,
    };
    expect(firstTask, {'onboarding-companion-first-task'});
    for (final beat in OnboardingCompanionBeat.values) {
      expect(beat.sourceId, startsWith(OnboardingCompanion.sourcePrefix));
    }
  });

  group('OnboardingCompanion', () {
    late FakeTtsEngine engine;
    late FakeTtsAudioPlayer player;
    late FakeTtsModelRepository models;
    late Stream<bool> Function() readAloud;
    late ValueNotifier<Widget> shown;
    late FakeCloudSpeechSynthesizer cloud;

    setUp(() {
      engine = FakeTtsEngine();
      player = FakeTtsAudioPlayer();
      models = FakeTtsModelRepository();
      readAloud = () => Stream.value(true);
      shown = ValueNotifier(const SizedBox());
      cloud = FakeCloudSpeechSynthesizer();
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
            cloudSpeechSynthesizerProvider.overrideWithValue(cloud),
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

    testWidgets("her view lip-syncs to her step's own source", (tester) async {
      await show(
        tester,
        const OnboardingCompanion(beat: OnboardingCompanionBeat.recommend),
      );

      final speaker = tester.widget<CompanionSpeaker>(
        find.byType(CompanionSpeaker),
      );
      expect(speaker.sourceId, OnboardingCompanionBeat.recommend.sourceId);
      // Dressed for onboarding as a whole, so every step shows one outfit.
      expect(speaker.dressedFor, OnboardingCompanion.dressedFor);
    });

    testWidgets('across a crossfade the new step takes over her voice, and '
        'the outgoing step leaving does not silence it', (tester) async {
      // Keyed where the column matches its children, so each step keeps
      // its state as the other comes and goes.
      const welcome = Expanded(
        key: ValueKey('welcome'),
        child: OnboardingCompanion(
          beat: OnboardingCompanionBeat.welcome,
          line: 'Hello',
        ),
      );
      const connect = Expanded(
        key: ValueKey('connect'),
        child: OnboardingCompanion(
          beat: OnboardingCompanionBeat.recommend,
          line: 'Mistral',
        ),
      );
      await show(tester, const Column(children: [welcome]));
      expect(engine.calls.single.text, 'Hello');

      // Both on screen, as while the steps crossfade: the welcome's line
      // gives way to the new one.
      await swap(
        tester,
        const Column(
          children: [
            welcome,
            connect,
          ],
        ),
      );
      expect(engine.calls.map((c) => c.text), ['Hello', 'Mistral']);
      expect(player.stopCount, 1);

      // The crossfade ends and the welcome leaves; its dispose ends only
      // its own utterance, which is no longer the one playing.
      await swap(tester, const Column(children: [connect]));

      expect(player.stopCount, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompanionSpeaker)),
      );
      expect(
        container.read(ttsPlaybackControllerProvider).sourceId,
        OnboardingCompanionBeat.recommend.sourceId,
      );
    });

    group('with a cloud voice', () {
      final voice = TtsCloudRoute(
        provider: testInferenceProvider(
          id: 'mistral',
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        model: testAiModel(
          id: 'voice',
          providerModelId: 'voxtral-mini-tts-3-0',
        ),
        languageCode: 'de',
      );

      setUp(() {
        final file = MockIoFile();
        when(() => file.path).thenReturn('/tmp/first_words.wav');
        when(file.existsSync).thenReturn(false);
        cloud.output = file;
        // Nothing on the device to speak with, and read-aloud off: the cloud
        // voice needs neither.
        engine = FakeTtsEngine(supported: false);
        models = FakeTtsModelRepository(installed: false);
        readAloud = () => Stream.value(false);
      });

      testWidgets('speaks her line in that voice, in its language', (
        tester,
      ) async {
        await show(
          tester,
          OnboardingCompanion(
            beat: OnboardingCompanionBeat.firstWords,
            line: 'Jetzt hörst du mich.',
            cloudVoice: voice,
          ),
        );

        expect(cloud.calls.single.text, 'Jetzt hörst du mich.');
        expect(cloud.calls.single.route, voice);
        expect(engine.calls, isEmpty);
        expect(models.ensureCount, 0);
        expect(player.playCount, 1);
      });

      testWidgets('the read-aloud switch does not silence or repeat it', (
        tester,
      ) async {
        final flag = StreamController<bool>();
        addTearDown(flag.close);
        readAloud = () => flag.stream;
        await show(
          tester,
          OnboardingCompanion(
            beat: OnboardingCompanionBeat.firstWords,
            line: 'Hallo.',
            cloudVoice: voice,
          ),
        );
        expect(cloud.calls, hasLength(1));

        flag
          ..add(true)
          ..add(false);
        await _pumpFrames(tester);

        expect(cloud.calls, hasLength(1));
        expect(player.stopCount, 0);
      });

      testWidgets('a line replaced while the earlier one waits is never '
          'spoken', (tester) async {
        await show(
          tester,
          OnboardingCompanion(
            beat: OnboardingCompanionBeat.firstWords,
            line: 'Eins.',
            cloudVoice: voice,
          ),
        );
        await swap(
          tester,
          OnboardingCompanion(
            beat: OnboardingCompanionBeat.firstWords,
            line: 'Zwei.',
            cloudVoice: voice,
          ),
        );

        expect(cloud.calls.map((c) => c.text), ['Eins.', 'Zwei.']);
      });
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
