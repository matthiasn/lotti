import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';

import '../../../test_helper.dart';
import '../../tts/test_utils.dart';

/// The voice as the conversation sees it: what it was asked to speak, and
/// how often it was stopped.
class _Voice extends TtsPlaybackController {
  _Voice(this._initial);

  final TtsPlaybackState _initial;
  final spoken = <({String sourceId, String text})>[];
  final stoppedSources = <String?>[];
  TtsModelDownloadConsent? consent;
  Future<bool> Function()? canPlayNow;
  int stops = 0;

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
    consent = confirmModelDownload;
    canPlayNow = canPlay;
    spoken.add((sourceId: sourceId, text: text));
    state = TtsPlaybackState(
      status: TtsPlaybackStatus.playing,
      sourceId: sourceId,
    );
  }

  @override
  Future<void> stop({String? sourceId}) async {
    stops++;
    stoppedSources.add(sourceId);
    state = const TtsPlaybackState();
  }
}

/// A recorder sitting in the status the test gives it.
class _Recorder extends ChatRecorderController {
  _Recorder(this._status);

  final ChatRecorderStatus _status;

  @override
  ChatRecorderState build() =>
      ChatRecorderState(status: _status, amplitudeHistory: const []);
}

/// Her customization as set, without storage.
class _Custom extends CompanionCustomizationController {
  _Custom(this._value, {this.known = true});

  final CompanionCustomization _value;
  final bool known;

  @override
  bool get loaded => known;

  @override
  CompanionCustomization build() => _value;

  void mute() => state = state.copyWith(speaksReplies: false);
}

/// The composer, mid-send or settled as the test says.
class _Composer extends FrontChatController {
  _Composer({required this.sending});

  final bool sending;

  @override
  FrontChatComposerState build() => FrontChatComposerState(isSending: sending);

  void settle() => state = const FrontChatComposerState();
}

/// Hosts the voice as the pane does, and shows the pose she holds.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    FrontVoice.listenForSpokenReply(ref, context);
    return Text('${FrontVoice.holdingOf(ref)?.name}');
  }
}

void main() {
  final spokenAt = DateTime(2026, 10, 31, 9);

  AgentChatMessage message(
    String id,
    AgentChatRole role,
    String text,
    DateTime at,
  ) => AgentChatMessage(id: id, role: role, text: text, createdAt: at);

  late List<AgentChatMessage> thread;
  late Map<String, List<FrontDoorEntry>> doors;
  late _Voice voice;
  late _Custom custom;
  late _Composer composer;

  setUp(() {
    doors = {};
    thread = [
      message('u-old', AgentChatRole.user, 'Earlier', DateTime(2026, 10, 30)),
      message('a-old', AgentChatRole.agent, 'Before', DateTime(2026, 10, 30)),
    ];
  });

  Future<ProviderContainer> pumpHost(
    WidgetTester tester, {
    String active = 'c-1',
    bool tts = true,
    bool speaksReplies = true,
    bool customizationKnown = true,
    ChatRecorderStatus recorder = ChatRecorderStatus.idle,
    TtsPlaybackState playing = const TtsPlaybackState(),
    bool sending = false,
    Stream<QueryAccessSnapshot?>? journalAccess,
  }) async {
    voice = _Voice(playing);
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) => Stream.value(switch (flag) {
              enableCompanionFlag => true,
              enableAiSummaryTtsFlag => tts,
              _ => false,
            }),
          ),
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          companionCustomizationProvider.overrideWith(
            () => custom = _Custom(
              CompanionCustomization(speaksReplies: speaksReplies),
              known: customizationKnown,
            ),
          ),
          ttsPlaybackControllerProvider.overrideWith(() => voice),
          agentResolvedSetupProvider.overrideWith((ref, id) async => null),
          frontActiveConversationProvider.overrideWith((ref) async => active),
          // Nothing her journal answers rest on is hidden.
          frontJournalAccessProvider.overrideWith(
            (ref) =>
                journalAccess ??
                Stream.value(
                  const QueryAccessSnapshot(
                    showPrivate: false,
                    categories: {},
                    entries: {},
                  ),
                ),
          ),
          frontChatThreadProvider.overrideWith(
            (ref) async => FrontChatThread(
              messages: List.of(thread),
              doorsByMessageId: Map.of(doors),
            ),
          ),
          frontChatControllerProvider.overrideWith(
            () => composer = _Composer(sending: sending),
          ),
          chatRecorderControllerProvider.overrideWith(
            () => _Recorder(recorder),
          ),
        ],
        child: const _Host(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(_Host)));
  }

  /// Her reply lands in the thread on screen.
  Future<void> reply(
    WidgetTester tester,
    ProviderContainer container,
    String text,
  ) async {
    thread = [
      ...thread,
      message('u-1', AgentChatRole.user, 'How many?', spokenAt),
      message(
        'a-1',
        AgentChatRole.agent,
        text,
        spokenAt.add(const Duration(seconds: 3)),
      ),
      message(
        'a-2',
        AgentChatRole.agent,
        'And one more thing.',
        spokenAt.add(const Duration(seconds: 4)),
      ),
    ];
    container.invalidate(frontChatThreadProvider);
    await tester.pump();
    await tester.pump();
  }

  void speakTurn(ProviderContainer container, String conversationId) =>
      container.read(frontSpokenTurnProvider.notifier).state = (
        conversationId: conversationId,
        spokenAt: spokenAt,
      );

  group('her answer to a spoken turn', () {
    testWidgets('is spoken — her first reply after it, under the '
        "conversation's voice — and then nothing more is owed", (
      tester,
    ) async {
      final container = await pumpHost(tester);
      speakTurn(container, 'c-1');

      await reply(tester, container, 'Forty-two.');

      expect(voice.spoken, [
        (sourceId: frontVoiceSourceId('c-1'), text: 'Forty-two.'),
      ]);
      expect(container.read(frontSpokenTurnProvider), isNull);
    });

    testWidgets('a voice whose model is not there yet asks before it is '
        'fetched', (tester) async {
      final container = await pumpHost(tester);
      speakTurn(container, 'c-1');
      await reply(tester, container, 'Forty-two.');

      voice.consent!(kTtsModels.first).ignore();
      await tester.pumpAndSettle();

      expect(find.text('Download the voice model?'), findsOne);
    });

    testWidgets('takes the voice over from whatever is speaking', (
      tester,
    ) async {
      final container = await pumpHost(
        tester,
        playing: const TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: 'day-briefing:2026-10-31',
        ),
      );
      speakTurn(container, 'c-1');

      await reply(tester, container, 'Forty-two.');

      expect(voice.stops, 1);
      expect(voice.spoken.single.text, 'Forty-two.');
    });

    testWidgets('waits while another conversation is on screen', (
      tester,
    ) async {
      final container = await pumpHost(tester, active: 'c-2');
      speakTurn(container, 'c-1');

      await reply(tester, container, 'Forty-two.');

      expect(voice.spoken, isEmpty);
      expect(container.read(frontSpokenTurnProvider), isNotNull);
    });

    testWidgets('waits out the inbox, which gathers every conversation, '
        'and is spoken once its own conversation is back', (tester) async {
      final container = await pumpHost(tester);
      speakTurn(container, 'c-1');
      container.read(frontInboxFilterProvider.notifier).toggle();
      await tester.pump();

      await reply(tester, container, 'Forty-two.');
      expect(voice.spoken, isEmpty);
      expect(container.read(frontSpokenTurnProvider), isNotNull);

      container.read(frontInboxFilterProvider.notifier).clear();
      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();
      expect(voice.spoken.single.text, 'Forty-two.');
    });

    testWidgets('stays written until her saved setting is known — a mute '
        'is never guessed at', (tester) async {
      final container = await pumpHost(tester, customizationKnown: false);
      speakTurn(container, 'c-1');

      await reply(tester, container, 'Forty-two.');

      expect(voice.spoken, isEmpty);
    });

    testWidgets('a mute while she prepares holds as playback starts, and a '
        'mute while she speaks stops her own voice only', (tester) async {
      final container = await pumpHost(tester);
      speakTurn(container, 'c-1');
      await reply(tester, container, 'Forty-two.');
      expect(await voice.canPlayNow!(), isTrue);

      custom.mute();
      await tester.pump();

      expect(await voice.canPlayNow!(), isFalse);
      expect(voice.stoppedSources, [frontVoiceSourceId('c-1')]);
    });

    testWidgets('a mute stops her where she is speaking, though another '
        'conversation is open, and leaves any other voice alone', (
      tester,
    ) async {
      await pumpHost(
        tester,
        active: 'c-2',
        playing: TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: frontVoiceSourceId('c-1'),
        ),
      );

      custom.mute();
      await tester.pump();

      expect(voice.stoppedSources, [frontVoiceSourceId('c-1')]);
    });

    testWidgets('a mute leaves the day briefing speaking', (tester) async {
      await pumpHost(
        tester,
        playing: const TtsPlaybackState(
          status: TtsPlaybackStatus.playing,
          sourceId: 'day-briefing:2026-10-31',
        ),
      );

      custom.mute();
      await tester.pump();

      expect(voice.stoppedSources, isEmpty);
    });

    testWidgets('stays written when she is muted', (tester) async {
      final container = await pumpHost(tester, speaksReplies: false);
      speakTurn(container, 'c-1');

      await reply(tester, container, 'Forty-two.');

      expect(voice.spoken, isEmpty);
      expect(container.read(frontSpokenTurnProvider), isNull);
    });

    testWidgets('stays written when read-aloud is switched off', (
      tester,
    ) async {
      final container = await pumpHost(tester, tts: false);
      speakTurn(container, 'c-1');

      await reply(tester, container, 'Forty-two.');

      expect(voice.spoken, isEmpty);
      expect(container.read(frontSpokenTurnProvider), isNull);
    });
  });

  group('an answer that lives in a door', () {
    /// A journal question routed with a dispatch alone: no reply of hers,
    /// the answer in its door.
    Future<void> answerInDoor(
      WidgetTester tester,
      ProviderContainer container, {
      bool settleFirst = false,
    }) async {
      if (!thread.any((m) => m.id == 'u-1')) {
        thread = [
          ...thread,
          message('u-1', AgentChatRole.user, 'What did I do?', spokenAt),
        ];
      }
      if (settleFirst) composer.settle();
      doors = {
        'u-1': [
          FrontDoorEntry(
            doorId: 'd-1',
            record: FrontDoorRecord(
              segmentIndex: 0,
              text: 'What did I do?',
              kind: FrontDestinationKind.journal,
              status: FrontDoorStatus.done,
              claimedAt: spokenAt,
              outcome: const FrontDoorAnswer(
                text: 'You fixed the feeder [1].',
                summaryBased: false,
                incomplete: false,
                fromJournal: true,
              ),
            ),
          ),
        ],
      };
      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('is spoken, though she wrote no reply, and she stops '
        'thinking', (tester) async {
      final container = await pumpHost(tester);
      speakTurn(container, 'c-1');

      await answerInDoor(tester, container);

      expect(voice.spoken, [
        (sourceId: frontVoiceSourceId('c-1'), text: 'You fixed the feeder.'),
      ]);
      expect(container.read(frontSpokenTurnProvider), isNull);
      expect(find.text('null'), findsOne);
    });

    testWidgets('waits until what the journal answer rests on is known, '
        'then says it once it may be shown', (tester) async {
      final access = StreamController<QueryAccessSnapshot?>();
      addTearDown(access.close);
      final container = await pumpHost(tester, journalAccess: access.stream);
      // Kept alive as the pane's door cards keep it.
      final keep = container.listen(frontJournalAccessProvider, (_, _) {});
      addTearDown(keep.close);
      speakTurn(container, 'c-1');

      await answerInDoor(tester, container);
      expect(voice.spoken, isEmpty);
      expect(container.read(frontSpokenTurnProvider), isNotNull);

      access.add(
        const QueryAccessSnapshot(
          showPrivate: false,
          categories: {},
          entries: {},
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(voice.spoken.single.text, 'You fixed the feeder.');
    });

    testWidgets('waits for the send, whose wake walks the doors, to settle', (
      tester,
    ) async {
      final container = await pumpHost(tester, sending: true);
      speakTurn(container, 'c-1');

      await answerInDoor(tester, container);
      expect(voice.spoken, isEmpty);
      expect(container.read(frontSpokenTurnProvider), isNotNull);

      composer.settle();
      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();

      expect(voice.spoken.single.text, 'You fixed the feeder.');
    });

    testWidgets('a thread still reloading is not read: its old value may '
        'hold the reply without the answers its doors brought', (
      tester,
    ) async {
      final container = await pumpHost(tester, sending: true);
      speakTurn(container, 'c-1');
      // While she works, her reply is projected, its door not yet.
      thread = [
        ...thread,
        message('u-1', AgentChatRole.user, 'What did I do?', spokenAt),
        message(
          'a-1',
          AgentChatRole.agent,
          'Let me look.',
          spokenAt.add(const Duration(seconds: 1)),
        ),
      ];
      container.invalidate(frontChatThreadProvider);
      await tester.pump();
      await tester.pump();

      // The send settles and the thread reloads with the door's answer;
      // the reload first holds the reply-only thread as its value.
      await answerInDoor(tester, container, settleFirst: true);

      expect(voice.spoken.single.text, 'Let me look.\n\nYou fixed the feeder.');
    });
  });

  testWidgets('a typed turn is answered in writing only', (tester) async {
    final container = await pumpHost(tester);

    await reply(tester, container, 'Forty-two.');

    expect(voice.spoken, isEmpty);
  });

  group('the pose she holds', () {
    testWidgets('listening while the user speaks', (tester) async {
      await pumpHost(tester, recorder: ChatRecorderStatus.recording);

      expect(find.text('listen'), findsOne);
    });

    testWidgets('thinking while a spoken answer is on its way, at rest '
        'once it is', (tester) async {
      final container = await pumpHost(tester);
      expect(find.text('null'), findsOne);

      speakTurn(container, 'c-1');
      await tester.pump();
      expect(find.text('think'), findsOne);

      await reply(tester, container, 'Forty-two.');
      expect(find.text('null'), findsOne);
    });
  });
}
