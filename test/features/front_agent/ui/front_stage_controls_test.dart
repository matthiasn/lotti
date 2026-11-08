import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/ai/util/inference_provider_resolver.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/ui/front_stage_controls.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../tts/test_utils.dart';

/// The shared recorder as the stage drives it: what it was asked to do, and
/// the transcription target each take was started with.
class _Recorder extends ChatRecorderController {
  _Recorder({this.micAllowed = true, this.opening});

  /// Whether the microphone opens: a refused one leaves the recorder idle.
  final bool micAllowed;

  /// Holds the microphone's opening back until completed — a permission
  /// prompt, a slow device.
  final Future<void>? opening;
  int stops = 0;
  int cancels = 0;
  final targets = <ChatTranscriptionTargetResolver?>[];

  @override
  ChatRecorderState build() => const ChatRecorderState.initial();

  @override
  Future<void> start({
    ChatTranscriptionTargetResolver? resolveTranscriptionTarget,
    ChatTranscriptCorrector? correctTranscript,
    ChatDictionaryCategoryResolver? resolveDictionaryCategory,
  }) async {
    targets.add(resolveTranscriptionTarget);
    if (opening case final opening?) await opening;
    if (micAllowed) {
      state = state.copyWith(status: ChatRecorderStatus.recording);
    }
  }

  @override
  Future<void> stopAndTranscribe() async {
    stops++;
    state = state.copyWith(status: ChatRecorderStatus.processing);
  }

  @override
  Future<void> cancel() async {
    cancels++;
    state = const ChatRecorderState.initial();
  }

  @override
  List<double> getNormalizedAmplitudeHistory() => const [0.3, 0.6];
}

/// Her composer, mid-send or settled as the test says.
class _Composer extends FrontChatController {
  _Composer({required this.sending});

  final bool sending;

  @override
  FrontChatComposerState build() => FrontChatComposerState(isSending: sending);
}

/// Her customization, known and speaking.
class _Custom extends CompanionCustomizationController {
  @override
  bool get loaded => true;

  @override
  CompanionCustomization build() => const CompanionCustomization();
}

void main() {
  final at = DateTime(2026, 10, 31, 9);
  final answered = FrontChatThread(
    messages: [
      AgentChatMessage(
        id: 'u1',
        role: AgentChatRole.user,
        text: 'How many hatchlings?',
        createdAt: at,
      ),
      AgentChatMessage(
        id: 'a1',
        role: AgentChatRole.agent,
        text: 'Forty-two.',
        createdAt: at,
      ),
    ],
  );

  late _Recorder recorder;
  Future<ResolvedInferenceProvider> ears() async =>
      throw UnimplementedError('never resolved here');

  setUp(() async {
    recorder = _Recorder();
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    FrontChatThread? thread,
    bool sending = false,
    Widget child = const FrontStageControls(conversationId: 'c-1'),
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: Center(child: child)),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) => Stream.value(switch (flag) {
              enableCompanionFlag => true,
              enableAiSummaryTtsFlag => true,
              _ => false,
            }),
          ),
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          companionCustomizationProvider.overrideWith(_Custom.new),
          agentResolvedSetupProvider.overrideWith((ref, id) async => null),
          frontJournalAccessProvider.overrideWith(
            (ref) => Stream.value(
              const QueryAccessSnapshot(
                showPrivate: false,
                categories: {},
                entries: {},
              ),
            ),
          ),
          frontActiveConversationProvider.overrideWith((ref) async => 'c-1'),
          frontChatThreadProvider.overrideWith(
            (ref) async => thread ?? FrontChatThread.empty,
          ),
          chatRecorderControllerProvider.overrideWith(() => recorder),
          frontChatControllerProvider.overrideWith(
            () => _Composer(sending: sending),
          ),
          settingsDefaultDictationTargetProvider.overrideWithValue(ears),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  String caption(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(FrontStageControlKeys.caption)).data!;

  testWidgets('held, she listens on the Settings default ears, and letting '
      'go sends what was said', (tester) async {
    await pump(tester);
    expect(caption(tester), 'Tap or hold to talk');
    // Nothing said yet: nothing to say again.
    expect(find.byKey(FrontVoiceControlKeys.replay), findsNothing);

    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(FrontStageControlKeys.talk)),
    );
    await tester.pump();
    expect(recorder.targets, [same(ears)]);
    // The take rises over the disc, which stays under the finger.
    expect(find.byType(FrontStageTake), findsOneWidget);
    expect(find.byKey(FrontStageControlKeys.talk), findsOneWidget);

    await tester.pump(kLongPressTimeout);
    expect(caption(tester), 'Release to send');
    expect(find.byIcon(LottiIcons.arrowUp), findsOneWidget);
    // The disc is the one send on screen: the take carries none.
    expect(
      find.descendant(
        of: find.byType(FrontStageTake),
        matching: find.byIcon(LottiIcons.arrowUp),
      ),
      findsNothing,
    );
    expect(recorder.stops, 0);

    await finger.up();
    await tester.pump();
    expect(recorder.stops, 1);
    expect(recorder.cancels, 0);
  });

  testWidgets('a quick tap leaves her listening hands free, the disc now '
      'the send arrow that the next tap sends with', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(FrontStageControlKeys.talk));
    await tester.pump();

    expect(recorder.targets, hasLength(1));
    expect(recorder.stops, 0, reason: 'a tap is not a hold: nothing is sent');
    expect(caption(tester), 'Tap to send');
    expect(
      find.descendant(
        of: find.byType(FrontStageTake),
        matching: find.byIcon(LottiIcons.arrowUp),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(FrontStageControlKeys.talk));
    await tester.pump();
    expect(recorder.stops, 1);
    expect(recorder.targets, hasLength(1), reason: 'no second take');
  });

  testWidgets("hands free, the pill's × lets it go", (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(FrontStageControlKeys.talk));
    await tester.pump();

    await tester.tap(find.byKey(FrontStageControlKeys.takeCancel));
    await tester.pump();

    expect(recorder.cancels, 1);
    expect(recorder.stops, 0);
    expect(caption(tester), 'Tap or hold to talk');
  });

  testWidgets('a hold dragged off the disc turns to cancel, and letting go '
      'there sends nothing; back on, it sends again', (tester) async {
    await pump(tester);
    final centre = tester.getCenter(find.byKey(FrontStageControlKeys.talk));

    final finger = await tester.startGesture(centre);
    await tester.pump(kLongPressTimeout);
    await finger.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(caption(tester), 'Release to cancel');
    expect(find.byIcon(LottiIcons.close), findsWidgets);

    await finger.moveTo(centre);
    await tester.pump();
    expect(caption(tester), 'Release to send');

    await finger.moveBy(const Offset(0, -200));
    await tester.pump();
    await finger.up();
    await tester.pump();
    expect(recorder.cancels, 1);
    expect(recorder.stops, 0);
  });

  testWidgets('a hold is a hold however late the microphone opens: '
      'letting go after it opened sends', (tester) async {
    final opened = Completer<void>();
    recorder = _Recorder(opening: opened.future);
    await pump(tester);

    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(FrontStageControlKeys.talk)),
    );
    // Held past the threshold while the microphone is still opening.
    await tester.pump(kLongPressTimeout * 2);
    expect(caption(tester), 'Tap or hold to talk');

    opened.complete();
    await tester.pump();
    await tester.pump();
    expect(caption(tester), 'Release to send');

    await finger.up();
    await tester.pump();
    expect(recorder.stops, 1);
    expect(recorder.cancels, 0);
  });

  testWidgets('a refused microphone never promises a send', (tester) async {
    recorder = _Recorder(micAllowed: false);
    await pump(tester);

    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(FrontStageControlKeys.talk)),
    );
    await tester.pump(kLongPressTimeout);
    expect(caption(tester), 'Tap or hold to talk');

    await finger.up();
    await tester.pump();
    expect(recorder.stops, 0);
  });

  testWidgets('while her answer is on its way the disc waits, and a press '
      'starts nothing', (tester) async {
    await pump(tester, sending: true);

    expect(caption(tester), 'Finding who knows…');
    expect(find.byType(DesignSystemSpinner), findsOneWidget);
    await tester.tap(find.byKey(FrontStageControlKeys.talk));
    await tester.pump();
    expect(recorder.targets, isEmpty);
  });

  testWidgets('started from the keyboard, Escape lets it go — the disc '
      'keeps the focus the pill would take', (tester) async {
    await pump(tester);
    Focus.of(
      tester.element(find.byKey(FrontStageControlKeys.talk)),
    ).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(caption(tester), 'Tap to send');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(recorder.cancels, 1);
    expect(recorder.stops, 0);
    expect(caption(tester), 'Tap or hold to talk');
  });

  testWidgets('Escape while the microphone is still opening lets the take '
      "go before it listens; at rest Escape is not the disc's", (
    tester,
  ) async {
    final opened = Completer<void>();
    recorder = _Recorder(opening: opened.future);
    await pump(tester);
    Focus.of(
      tester.element(find.byKey(FrontStageControlKeys.talk)),
    ).requestFocus();
    await tester.pump();

    // At rest the disc lets Escape through, to whatever closes the stage.
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.escape),
      isFalse,
    );
    expect(recorder.cancels, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(recorder.targets, hasLength(1), reason: 'the start is pending');

    // A second key while it opens asks for no second start…
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(recorder.targets, hasLength(1));

    // …so the first can still be let go.
    expect(
      await tester.sendKeyEvent(LogicalKeyboardKey.escape),
      isTrue,
    );
    expect(recorder.cancels, 1);
  });

  for (final key in [LogicalKeyboardKey.space, LogicalKeyboardKey.enter]) {
    testWidgets('${key.keyLabel} starts her listening hands free, and sends', (
      tester,
    ) async {
      await pump(tester);
      Focus.of(
        tester.element(find.byKey(FrontStageControlKeys.talk)),
      ).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(recorder.targets, hasLength(1));
      expect(caption(tester), 'Tap to send');

      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(recorder.stops, 1);
    });
  }

  testWidgets('a hold the system takes away carries on hands free: nothing '
      'said is lost to it, and nothing is sent', (tester) async {
    await pump(tester);

    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(FrontStageControlKeys.talk)),
    );
    await tester.pump(kLongPressTimeout);
    await finger.cancel();
    await tester.pump();

    expect(recorder.cancels, 0);
    expect(recorder.stops, 0);
    expect(caption(tester), 'Tap to send');
  });

  testWidgets('a screen reader, which taps, starts her listening hands free', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    // One node says it, the disc's: the caption is not read twice.
    tester.semantics.tap(find.semantics.byLabel('Tap or hold to talk'));
    await tester.pump();

    expect(recorder.targets, hasLength(1));
    expect(find.byType(FrontStageTake), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('her answer said again stands beside the disc once there is '
      'one, and steps aside while she listens', (tester) async {
    await pump(tester, thread: answered);
    expect(find.byKey(FrontVoiceControlKeys.replay), findsOneWidget);

    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(FrontStageControlKeys.talk)),
    );
    await tester.pump();
    expect(find.byKey(FrontVoiceControlKeys.replay), findsNothing);
    await finger.up();
  });

  testWidgets('her stage, opened before she has said anything, still offers '
      'a way to answer her', (tester) async {
    await pump(
      tester,
      child: const _OpenStage(),
    );

    await tester.tap(find.byType(_OpenStage));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(FrontStageControlKeys.talk), findsOneWidget);
    expect(caption(tester), 'Tap or hold to talk');
  });
}

/// Opens her stage in conversation c-1, as the header's stage control does.
class _OpenStage extends StatelessWidget {
  const _OpenStage();

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => openFrontStage(context, 'c-1'),
    child: const Text('Open her stage'),
  );
}
