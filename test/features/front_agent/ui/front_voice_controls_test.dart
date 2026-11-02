import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/companion_stage_page.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../tts/test_utils.dart';

/// The voice as her controls see it: what it was asked to speak, and what
/// it was asked to stop.
class _Voice extends TtsPlaybackController {
  _Voice(this._initial);

  final TtsPlaybackState _initial;
  final spoken = <({String sourceId, String text})>[];
  final stoppedSources = <String?>[];

  @override
  TtsPlaybackState build() => _initial;

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
    state = TtsPlaybackState(
      status: TtsPlaybackStatus.playing,
      sourceId: sourceId,
    );
  }

  @override
  Future<void> stop({String? sourceId}) async {
    stoppedSources.add(sourceId);
    state = const TtsPlaybackState();
  }
}

/// Her customization as set, without storage.
class _Custom extends CompanionCustomizationController {
  _Custom({required this.speaks});

  final bool speaks;

  @override
  bool get loaded => true;

  @override
  CompanionCustomization build() =>
      CompanionCustomization(speaksReplies: speaks);
}

/// Pins the inbox filter as the test says.
class _Inbox extends FrontInboxFilter {
  _Inbox({required this.on});

  final bool on;

  @override
  bool build() => on;
}

void main() {
  final at = DateTime(2026, 11, 3, 9);
  const source = 'front-chat:c-1';

  AgentChatMessage message(String id, AgentChatRole role, String text, int s) =>
      AgentChatMessage(
        id: id,
        role: role,
        text: text,
        createdAt: at.add(Duration(seconds: s)),
      );

  // Two turns: the control says the answer to the latest one.
  final answered = FrontChatThread(
    messages: [
      message('u1', AgentChatRole.user, 'What is due today?', 0),
      message('a1', AgentChatRole.agent, 'Nothing today.', 1),
      message('u2', AgentChatRole.user, 'Anything overdue?', 2),
      message(
        'a2',
        AgentChatRole.agent,
        'One: [Count the eggs](lotti://task/t1).',
        3,
      ),
    ],
  );

  late _Voice voice;

  Future<void> pump(
    WidgetTester tester, {
    Widget child = const FrontVoiceButton(conversationId: 'c-1'),
    FrontChatThread? thread,
    TtsPlaybackState playing = const TtsPlaybackState(),
    bool companion = true,
    bool speaks = true,
    bool inbox = false,
  }) async {
    voice = _Voice(playing);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: Center(child: child)),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) => Stream.value(switch (flag) {
              enableCompanionFlag => companion,
              enableAiSummaryTtsFlag => true,
              _ => false,
            }),
          ),
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          companionCustomizationProvider.overrideWith(
            () => _Custom(speaks: speaks),
          ),
          ttsPlaybackControllerProvider.overrideWith(() => voice),
          agentResolvedSetupProvider.overrideWith((ref, id) async => null),
          frontChatThreadProvider.overrideWith(
            (ref) async => thread ?? answered,
          ),
          frontInboxFilterProvider.overrideWith(() => _Inbox(on: inbox)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('FrontVoiceButton', () {
    testWidgets('says her latest answer again, from the start, as she says '
        'it aloud', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Say it again'));
      await tester.pump();

      expect(voice.spoken, [(sourceId: source, text: 'One: Count the eggs.')]);
    });

    testWidgets('stops her while she speaks, and a second tap restarts '
        'the answer from the start', (tester) async {
      await pump(
        tester,
        playing: const TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: source,
        ),
      );

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(voice.stoppedSources, [null]);
      expect(find.byTooltip('Say it again'), findsOneWidget);

      await tester.tap(find.byTooltip('Say it again'));
      await tester.pump();
      expect(voice.spoken.single.text, 'One: Count the eggs.');
      expect(find.byTooltip('Stop'), findsOneWidget);
    });

    testWidgets('a stop stays within reach while she speaks, even muted', (
      tester,
    ) async {
      await pump(
        tester,
        speaks: false,
        playing: const TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: source,
        ),
      );
      expect(find.byKey(FrontVoiceControlKeys.replay), findsOneWidget);
    });

    testWidgets('another source speaking leaves her control idle', (
      tester,
    ) async {
      await pump(
        tester,
        playing: const TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: 'task-1',
        ),
      );
      expect(find.byTooltip('Say it again'), findsOneWidget);
    });

    for (final (reason, setup) in [
      ('she is muted', (speaks: false, inbox: false, companion: true)),
      ('the inbox is open', (speaks: true, inbox: true, companion: true)),
      ('the companion is off', (speaks: true, inbox: false, companion: false)),
    ]) {
      testWidgets('is gone while $reason', (tester) async {
        await pump(
          tester,
          speaks: setup.speaks,
          inbox: setup.inbox,
          companion: setup.companion,
        );
        expect(find.byKey(FrontVoiceControlKeys.replay), findsNothing);
      });
    }

    testWidgets('is gone while there is no answer yet to say', (tester) async {
      await pump(
        tester,
        thread: FrontChatThread(
          messages: [message('u1', AgentChatRole.user, 'Hello?', 0)],
        ),
      );
      expect(find.byKey(FrontVoiceControlKeys.replay), findsNothing);
    });
  });

  testWidgets('the stage control stands her up full screen in her '
      'conversation, her voice control at her feet', (tester) async {
    await pump(tester, child: const FrontStageButton(conversationId: 'c-1'));

    await tester.tap(find.byTooltip('View companion full screen'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final stage = tester.widget<CompanionStagePage>(
      find.byType(CompanionStagePage),
    );
    expect(stage.sourceId, source);
    expect(find.byKey(FrontVoiceControlKeys.replay), findsOneWidget);
    await tester.tap(find.byTooltip('Say it again'));
    await tester.pump();
    expect(voice.spoken.single.sourceId, source);
  });
}
