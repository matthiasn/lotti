import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/agent_typing_indicator.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// A recorder whose state the test sets, and whose stop and cancel it counts.
class _Recorder extends ChatRecorderController {
  _Recorder(this._initial);

  final ChatRecorderStatus _initial;
  int stops = 0;
  int cancels = 0;
  int starts = 0;

  @override
  ChatRecorderState build() =>
      ChatRecorderState(status: _initial, amplitudeHistory: const []);

  @override
  List<double> getNormalizedAmplitudeHistory() => const [0.4, 0.6, 0.5];

  @override
  Future<void> start({
    ChatTranscriptionTargetResolver? resolveTranscriptionTarget,
    ChatTranscriptCorrector? correctTranscript,
    ChatDictionaryCategoryResolver? resolveDictionaryCategory,
  }) async {
    starts++;
    state = state.copyWith(status: ChatRecorderStatus.recording);
  }

  @override
  Future<void> stopAndTranscribe() async => stops++;

  @override
  Future<void> cancel() async {
    cancels++;
    state = const ChatRecorderState.initial();
  }

  /// What was said, as a finished transcription lands.
  void hear(String text) => state = ChatRecorderState(
    status: ChatRecorderStatus.idle,
    amplitudeHistory: const [],
    transcript: text,
  );
}

void main() {
  final at = DateTime(2026, 10, 31, 9);
  final messages = [
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
      runKey: 'run-1',
    ),
  ];

  late String draft;
  late int sends;

  setUp(() {
    draft = '';
    sends = 0;
  });

  Future<_Recorder> pumpView(
    WidgetTester tester, {
    ChatRecorderStatus status = ChatRecorderStatus.idle,
    bool conversational = true,
    bool voiceFirst = true,
    bool isSending = false,
    List<AgentChatMessage>? history,
    Widget? Function(BuildContext, AgentChatMessage)? footerTrailing,
    bool reducedMotion = false,
    VoidCallback? onSendSpoken,
    double? contentMaxWidth,
    bool composerEnabled = true,
    AgentReplyBodyBuilder? replyBodyBuilder,
  }) async {
    final recorder = _Recorder(status);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: AgentChatView(
                agentId: 'agent',
                agentName: 'Companion',
                draft: draft,
                isSending: isSending,
                onDraftChanged: (value) => draft = value,
                onSend: () => sends++,
                onRetry: () {},
                history: AsyncData(history ?? messages),
                conversational: conversational,
                voiceFirst: voiceFirst,
                footerTrailingBuilder: footerTrailing,
                onSendSpoken: onSendSpoken,
                contentMaxWidth: contentMaxWidth,
                composerEnabled: composerEnabled,
                replyBodyBuilder: replyBodyBuilder,
              ),
            ),
          ),
        ),
        overrides: [
          chatRecorderControllerProvider.overrideWith(() => recorder),
        ],
      ),
    );
    await tester.pump();
    return recorder;
  }

  group('a conversation', () {
    testWidgets('her words are unboxed prose and nobody carries a name and '
        'time line; the footer stays for what a host adds', (tester) async {
      await pumpView(
        tester,
        footerTrailing: (context, message) =>
            message.role == AgentChatRole.agent
            ? const Text('900 tokens', key: Key('cost'))
            : null,
      );

      expect(find.textContaining('Companion · '), findsNothing);
      expect(find.textContaining('You · '), findsNothing);
      expect(find.byKey(const Key('cost')), findsOne);
      final hers = find.ancestor(
        of: find.text('Forty-two.'),
        matching: find.byType(DecoratedBox),
      );
      final box = tester.widget<DecoratedBox>(hers.first);
      expect((box.decoration as BoxDecoration).color, isNull);
    });

    testWidgets('a log keeps the name-and-time line on every message', (
      tester,
    ) async {
      await pumpView(tester, conversational: false, voiceFirst: false);

      expect(find.textContaining('Companion · '), findsOne);
      expect(find.textContaining('You · '), findsOne);
    });

    testWidgets("on a phone the user's words stop short of the far edge in a "
        'conversation; a log keeps its reading width', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      double userWidth() => tester
          .widget<ConstrainedBox>(
            find
                .ancestor(
                  of: find.text('How many hatchlings?'),
                  matching: find.byType(ConstrainedBox),
                )
                .first,
          )
          .constraints
          .maxWidth;

      await pumpView(tester);
      expect(userWidth(), 400 * 0.8);

      await pumpView(tester, conversational: false, voiceFirst: false);
      expect(userWidth(), kActionListContentMaxWidth);
    });

    testWidgets('her thinking is unboxed too, so her turn keeps its shape', (
      tester,
    ) async {
      await pumpView(tester, isSending: true);

      final thinking = find.ancestor(
        of: find.byType(AgentTypingIndicator),
        matching: find.byType(DecoratedBox),
      );
      final box = tester.widget<DecoratedBox>(thinking.first);
      expect((box.decoration as BoxDecoration).color, isNull);
    });
  });

  group('a reading column', () {
    testWidgets('keeps the thread and the field to one centred width, their '
        'edges lined up', (tester) async {
      tester.view
        ..physicalSize = const Size(1400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpView(tester, contentMaxWidth: 600);

      final card = tester.getRect(find.byKey(DesignSystemChatInputKeys.card));
      final bubble = tester.getRect(
        find
            .ancestor(
              of: find.text('How many hatchlings?'),
              matching: find.byType(Align),
            )
            .first,
      );
      final view = tester.getRect(find.byType(AgentChatView));
      // The input's card is the column: centred, its edges the column's.
      expect(card.center.dx, closeTo(view.center.dx, 1));
      expect(card.width, closeTo(600, 1));
      // The user's bubble keeps to the column's right edge, as the card
      // does.
      expect(bubble.right, closeTo(card.right, 1));
    });

    testWidgets('without one, the thread keeps its usual gutter', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1400, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpView(tester);

      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(
        list.padding,
        EdgeInsets.all(
          tester
              .element(find.byType(ListView).first)
              .designTokens
              .spacing
              .step5,
        ),
      );
    });
  });

  group('a host-drawn reply body', () {
    testWidgets('draws her reply where the host asks, her words in it as '
        'the view draws them; other replies as usual', (tester) async {
      final asked = <String>[];
      await pumpView(
        tester,
        history: [
          AgentChatMessage(
            id: 'drawn',
            role: AgentChatRole.agent,
            text: 'ignored',
            createdAt: DateTime(2026, 11, 7, 9),
          ),
          AgentChatMessage(
            id: 'plain',
            role: AgentChatRole.agent,
            text: 'Left as she wrote it.',
            createdAt: DateTime(2026, 11, 7, 9, 1),
          ),
          AgentChatMessage(
            id: 'mine',
            role: AgentChatRole.user,
            text: 'And mine?',
            createdAt: DateTime(2026, 11, 7, 9, 2),
          ),
        ],
        replyBodyBuilder: (context, message, prose) {
          asked.add(message.id);
          if (message.id != 'drawn') return null;
          return Column(
            children: [
              prose('Her **own** words'),
              const SizedBox(key: Key('drawn-by-host'), height: 8),
            ],
          );
        },
      );

      expect(find.byKey(const Key('drawn-by-host')), findsOne);
      expect(find.textContaining('own', findRichText: true), findsOne);
      expect(find.textContaining('ignored', findRichText: true), findsNothing);
      expect(
        find.textContaining('Left as she wrote it.', findRichText: true),
        findsOne,
      );
      // Asked only for her replies: the user's words are never drawn so.
      expect(asked, isNot(contains('mine')));
    });
  });

  group('voice first', () {
    testWidgets('one field for both: the mic at its end starts listening, '
        'and words typed bring send beside it', (tester) async {
      final recorder = await pumpView(tester);

      // No talk disc and no mode to switch: the field is there at once.
      expect(find.byType(TextField), findsOne);
      // A phone keeps its keyboard down until the field is tapped.
      expect(tester.widget<TextField>(find.byType(TextField)).autofocus, false);

      await tester.tap(find.byKey(DesignSystemChatInputKeys.mic));
      await tester.pump();
      expect(recorder.starts, 1);
      await recorder.cancel();
      await tester.pump();

      draft = 'How many?';
      await pumpView(tester);
      expect(find.byKey(DesignSystemChatInputKeys.mic), findsOne);
      await tester.tap(find.byKey(DesignSystemChatInputKeys.send));
      expect(sends, 1);
    });

    testWidgets('on a desktop the field takes the keyboard at once', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpView(tester);

      expect(tester.widget<TextField>(find.byType(TextField)).autofocus, true);
    });

    testWidgets('while listening, the voice runs across the row, Done ends '
        'the take, and Cancel or Escape lets it go', (tester) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
      );

      expect(
        tester
            .widget<DesignSystemVoiceWaveform>(
              find.byKey(DesignSystemChatInputKeys.waveform),
            )
            .levels,
        const [0.4, 0.6, 0.5],
      );
      await tester.tap(find.byKey(DesignSystemChatInputKeys.done));
      expect(recorder.stops, 1);

      await tester.tap(find.byKey(DesignSystemChatInputKeys.cancel));
      expect(recorder.cancels, 1);
    });

    testWidgets('Escape cancels while listening', (tester) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(recorder.cancels, 1);
    });

    testWidgets('while transcribing, Cancel still lets the turn go', (
      tester,
    ) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.processing,
      );

      expect(find.text('Transcribing…'), findsWidgets);
      await tester.tap(find.byKey(DesignSystemChatInputKeys.cancel));
      expect(recorder.cancels, 1);
    });

    testWidgets('what was said lands in the field to be read — nothing goes '
        'out by itself', (tester) async {
      final recorder = await pumpView(tester);

      recorder.hear('And the tagging?');
      await tester.pump();

      expect(draft, 'And the tagging?');
      expect(sends, 0);
      expect(find.text('And the tagging?'), findsOne);
    });

    testWidgets('a take adds to what is already written', (tester) async {
      draft = 'First the count.';
      final recorder = await pumpView(tester);

      recorder.hear('And the tagging?');
      await tester.pump();

      expect(draft, 'First the count. And the tagging?');
    });

    testWidgets('read and corrected, what was said goes out as a spoken turn '
        'to a host that asks', (tester) async {
      var spoken = 0;
      final recorder = await pumpView(tester, onSendSpoken: () => spoken++);

      recorder.hear('And the taging?');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'And the tagging?');
      await tester.pump();
      await tester.tap(find.byKey(DesignSystemChatInputKeys.send));

      expect(spoken, 1);
      expect(sends, 0, reason: 'a spoken send is not a typed one');
    });

    testWidgets('a typed draft, or one cleared and typed again, goes out as '
        'typed', (tester) async {
      var spoken = 0;
      final recorder = await pumpView(tester, onSendSpoken: () => spoken++);

      recorder.hear('And the tagging?');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Typed instead');
      await tester.pump();
      await tester.tap(find.byKey(DesignSystemChatInputKeys.send));

      expect((sends, spoken), (1, 0));
    });

    testWidgets('a view without a composer leaves what was said to the one '
        'that has it: it neither drafts nor sends it', (tester) async {
      var spoken = 0;
      final recorder = await pumpView(
        tester,
        composerEnabled: false,
        onSendSpoken: () => spoken++,
      );

      recorder.hear('And the tagging?');
      await tester.pump();

      expect(draft, isEmpty);
      expect(spoken, 0);
      expect(sends, 0);
    });
  });
}
