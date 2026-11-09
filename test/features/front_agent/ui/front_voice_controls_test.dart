import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
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
  Future<bool> Function()? canPlay;

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
    this.canPlay = canPlay;
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

/// The composer, mid-send or settled as the test says.
class _Composer extends FrontChatController {
  _Composer({required this.sending});

  final bool sending;

  /// What was sent, as it was sent.
  @override
  FrontChatComposerState build() => FrontChatComposerState(isSending: sending);
}

/// A spoken reply still owed, or none.
class _Spoken extends FrontSpokenTurnNotifier {
  _Spoken({required this.owed});

  final bool owed;

  @override
  FrontSpokenTurn? build() =>
      owed ? (conversationId: 'c-1', spokenAt: DateTime(2026, 11, 3)) : null;
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

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    Widget child = const FrontVoiceButton(conversationId: 'c-1'),
    FrontChatThread? thread,
    TtsPlaybackState playing = const TtsPlaybackState(),
    bool companion = true,
    bool speaks = true,
    bool inbox = false,
    String active = 'c-1',
    bool sending = false,
    bool spokenOwed = false,
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
          // Nothing her journal answers rest on is hidden.
          frontJournalAccessProvider.overrideWith(
            (ref) => Stream.value(
              const QueryAccessSnapshot(
                showPrivate: false,
                categories: {},
                entries: {},
              ),
            ),
          ),
          frontActiveConversationProvider.overrideWith(
            (ref) async => active,
          ),
          frontChatControllerProvider.overrideWith(
            () => _Composer(sending: sending),
          ),
          frontSpokenTurnProvider.overrideWith(
            () => _Spoken(owed: spokenOwed),
          ),
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

      // "Again", not a speaker: her mute beside it is the speaker.
      expect(
        find.descendant(
          of: find.byKey(FrontVoiceControlKeys.replay),
          matching: find.byIcon(LottiIcons.replay),
        ),
        findsOne,
      );

      await tester.tap(find.byTooltip('Say it again'));
      await tester.pump();

      expect(voice.spoken, [(sourceId: source, text: 'One: Count the eggs.')]);
    });

    testWidgets('the mute is still asked as playback starts after the '
        'control that started her is gone — her stage closed', (tester) async {
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      await pump(
        tester,
        child: ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (_, on, _) => on
              ? const FrontVoiceButton(conversationId: 'c-1')
              : const SizedBox.shrink(),
        ),
      );
      await tester.tap(find.byTooltip('Say it again'));
      await tester.pump();

      shown.value = false;
      await tester.pump();
      expect(find.byType(FrontVoiceButton), findsNothing);

      expect(await voice.canPlay!(), isTrue);
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

    for (final (reason, active, sending, owed) in [
      ('a send is in flight: the answer may be partial', 'c-1', true, false),
      ('her spoken reply is still owed', 'c-1', false, true),
      ('another conversation is on screen', 'c-2', false, false),
    ]) {
      testWidgets('offers no replay while $reason', (tester) async {
        await pump(
          tester,
          active: active,
          sending: sending,
          spokenOwed: owed,
        );
        expect(find.byKey(FrontVoiceControlKeys.replay), findsNothing);
      });
    }

    testWidgets('keeps the stop within reach mid-send', (tester) async {
      await pump(
        tester,
        sending: true,
        playing: const TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: source,
        ),
      );
      expect(find.byTooltip('Stop'), findsOneWidget);
    });

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
}
