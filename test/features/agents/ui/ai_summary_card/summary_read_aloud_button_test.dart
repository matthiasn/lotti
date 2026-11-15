import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/state/skill_entity_provider.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:lotti/utils/consts.dart';

import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../tts/test_utils.dart';
import '../../test_data/ai_config_factories.dart';
import '../../test_data/entity_factories.dart';

/// The app-wide playback state, set by the test, recording what the button
/// asks of the voice.
class _Playback extends TtsPlaybackController {
  _Playback(this.initial);

  final TtsPlaybackState initial;
  final spoken = <({String sourceId, String text})>[];
  final routes = <TtsCloudRoute?>[];
  TtsModelDownloadConsent? confirmModelDownload;
  int stops = 0;

  @override
  TtsPlaybackState build() => initial;

  @override
  Future<void> speak({
    required String sourceId,
    required String text,
    String language = 'en',
    Future<bool> Function()? canPlay,
    TtsModelDownloadConsent? confirmModelDownload,
    TtsCloudRoute? cloudRoute,
  }) async {
    spoken.add((sourceId: sourceId, text: text));
    routes.add(cloudRoute);
    this.confirmModelDownload = confirmModelDownload;
  }

  @override
  Future<void> stop({String? sourceId}) async => stops++;
}

void main() {
  late _Playback playback;

  Future<TtsPlayButton> pump(
    WidgetTester tester,
    TtsPlaybackState state, {
    TtsCloudRoute? cloudRoute,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        SummaryReadAloudButton(
          sourceId: 'task-1',
          text: 'Two left.',
          cloudRoute: cloudRoute,
        ),
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(
            () => playback = _Playback(state),
          ),
        ],
      ),
    );
    return tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
  }

  testWidgets('idle, it plays its own words under its own source', (
    tester,
  ) async {
    final button = await pump(tester, const TtsPlaybackState());

    expect(button.mode, TtsButtonMode.idle);
    expect(button.progress, isNull);
    button.onPlay();
    expect(playback.spoken, [(sourceId: 'task-1', text: 'Two left.')]);
    // No route from the host: the on-device voice.
    expect(playback.routes, [null]);
  });

  testWidgets("it speaks with its host's cloud voice", (tester) async {
    final route = TtsCloudRoute(
      provider: testInferenceProvider(
        id: 'mistral',
        inferenceProviderType: InferenceProviderType.mistral,
      ),
      model: testAiModel(id: 'voice', providerModelId: 'voxtral-mini-tts-3-0'),
      languageCode: 'de',
    );
    final button = await pump(
      tester,
      const TtsPlaybackState(),
      cloudRoute: route,
    );
    button.onPlay();
    expect(playback.routes, [route]);
  });

  testWidgets('a play asks before the voice model downloads, showing its '
      'size', (tester) async {
    final button = await pump(tester, const TtsPlaybackState());
    button.onPlay();
    final consent = playback.confirmModelDownload;
    expect(consent, isNotNull, reason: 'the model must never download unasked');

    final agreed = consent!(ttsModelByIdOrDefault(kDefaultTtsModelId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Download the voice model?'), findsOneWidget);
    await tester.tap(find.text('Download (398.4 MB)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await agreed, isTrue);
  });

  testWidgets('another source playing leaves it idle', (tester) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-2',
        duration: Duration(seconds: 10),
        position: Duration(seconds: 5),
      ),
    );

    expect(button.mode, TtsButtonMode.idle);
    expect(button.progress, isNull);
  });

  for (final status in [
    TtsPlaybackStatus.downloadingModel,
    TtsPlaybackStatus.synthesizing,
  ]) {
    testWidgets('its source ${status.name} reads as preparing', (
      tester,
    ) async {
      final button = await pump(
        tester,
        TtsPlaybackState(status: status, sourceId: 'task-1'),
      );

      expect(button.mode, TtsButtonMode.preparing);
      expect(button.progress, isNull);
    });
  }

  testWidgets('its source playing reports how far it has read, and stops', (
    tester,
  ) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-1',
        duration: Duration(seconds: 10),
        position: Duration(seconds: 4),
      ),
    );

    expect(button.mode, TtsButtonMode.playing);
    expect(button.progress, closeTo(0.4, 1e-9));
    button.onStop();
    expect(playback.stops, 1);
  });

  testWidgets('playing before the duration is known shows no progress', (
    tester,
  ) async {
    final button = await pump(
      tester,
      const TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        sourceId: 'task-1',
      ),
    );

    expect(button.mode, TtsButtonMode.playing);
    expect(button.progress, isNull);
  });

  group('TaskPromptReadAloudButton', () {
    final mistral = testInferenceProvider(
      id: 'mistral',
      inferenceProviderType: InferenceProviderType.mistral,
    );
    final voice = testAiModel(
      id: 'voice',
      providerModelId: 'voxtral-mini-tts-3-0',
    );
    final cloudSetup = ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.resolved,
      profile: ResolvedProfile(
        thinkingModelId: 'thinking',
        thinkingProvider: mistral,
        speechModelId: voice.providerModelId,
        speechProvider: mistral,
        speechModel: voice,
      ),
    );

    Future<void> pumpPrompt(
      WidgetTester tester, {
      String? taskId = 'task-1',
      String text = 'Add OAuth.',
      bool readAloud = true,
      bool engineSupported = true,
      ResolvedAgentSetup? setup,
    }) async {
      await tester.pumpWidget(
        makeTestableWidget(
          TaskPromptReadAloudButton(
            taskId: taskId,
            sourceId: 'prompt-1',
            text: text,
          ),
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) =>
                  Stream.value(flagName == enableAiSummaryTtsFlag && readAloud),
            ),
            ttsEngineProvider.overrideWithValue(
              FakeTtsEngine(supported: engineSupported),
            ),
            taskAgentProvider.overrideWith(
              (ref, id) async => makeTestIdentity(agentId: 'agent-1'),
            ),
            taskAgentResolvedSetupProvider.overrideWith(
              (ref, agentId) async => agentId == 'agent-1' ? setup : null,
            ),
            skillEntityProvider('task-1').overrideWithValue(
              testTask.copyWith(
                data: testTask.data.copyWith(languageCode: 'de-AT'),
              ),
            ),
            ttsPlaybackControllerProvider.overrideWith(
              () => playback = _Playback(const TtsPlaybackState()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("it reads the prompt with its task report's cloud voice, in "
        "the task's language, under the prompt's own source", (tester) async {
      await pumpPrompt(tester, engineSupported: false, setup: cloudSetup);

      final button = tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
      expect(button.playLabel, 'Read prompt aloud');
      button.onPlay();

      expect(playback.spoken, [(sourceId: 'prompt-1', text: 'Add OAuth.')]);
      final route = playback.routes.single!;
      expect(route.provider, mistral);
      expect(route.model, voice);
      expect(route.languageCode, 'de');
    });

    testWidgets('without a task it reads with the on-device voice', (
      tester,
    ) async {
      await pumpPrompt(tester, taskId: null, setup: cloudSetup);

      tester.widget<TtsPlayButton>(find.byType(TtsPlayButton)).onPlay();

      expect(playback.spoken, [(sourceId: 'prompt-1', text: 'Add OAuth.')]);
      expect(playback.routes, [null]);
    });

    testWidgets('read aloud switched off shows no control', (tester) async {
      await pumpPrompt(tester, readAloud: false, setup: cloudSetup);

      expect(find.byType(TtsPlayButton), findsNothing);
    });

    testWidgets('no cloud voice and no on-device engine shows no control', (
      tester,
    ) async {
      await pumpPrompt(tester, engineSupported: false);

      expect(find.byType(TtsPlayButton), findsNothing);
    });

    testWidgets('an empty prompt shows no control', (tester) async {
      await pumpPrompt(tester, text: '');

      expect(find.byType(TtsPlayButton), findsNothing);
    });
  });
}
