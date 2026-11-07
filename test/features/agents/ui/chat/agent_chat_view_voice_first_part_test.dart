import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/agent_typing_indicator.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/chat_recording_pill.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
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

      final field = tester.getRect(find.byType(TextField));
      final bubble = tester.getRect(
        find
            .ancestor(
              of: find.text('How many hatchlings?'),
              matching: find.byType(Align),
            )
            .first,
      );
      final view = tester.getRect(find.byType(AgentChatView));
      expect(field.center.dx, closeTo(view.center.dx, 1));
      // The user's bubble keeps to the column's right edge, as the field
      // does.
      expect(bubble.right, closeTo(view.center.dx + 300, 1));
      expect(field.right, lessThanOrEqualTo(view.center.dx + 300));
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

  group('voice first', () {
    Finder tooltipped(String message) => find.byWidgetPredicate(
      (w) => w is Tooltip && w.message == message,
    );

    testWidgets('one field for both: the mic at its end starts listening, '
        'and words typed turn it into send', (tester) async {
      final recorder = await pumpView(tester);

      // No talk disc and no mode to switch: the field is there at once.
      expect(find.byType(TextField), findsOne);
      expect(find.text('Type instead'), findsNothing);
      // A phone keeps its keyboard down until the field is tapped.
      expect(tester.widget<TextField>(find.byType(TextField)).autofocus, false);

      await tester.tap(find.byIcon(LottiIcons.mic));
      await tester.pump();
      expect(recorder.starts, 1);
      await recorder.cancel();
      await tester.pump();

      draft = 'How many?';
      await pumpView(tester);
      expect(find.byIcon(LottiIcons.mic), findsNothing);
      await tester.tap(tooltipped('Send message'));
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

    testWidgets('while listening, stop is the send arrow it is, and Cancel '
        'or Escape lets it go', (tester) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
      );

      final waveform =
          tester
                  .widget<CustomPaint>(
                    find.byKey(ChatRecordingPillKeys.waveform),
                  )
                  .painter!
              as WaveformBarsPainter;
      expect(waveform.amplitudes, const [0.4, 0.6, 0.5]);
      expect(tooltipped('Stop and transcribe'), findsNothing);
      expect(
        find.descendant(
          of: tooltipped('Send message'),
          matching: find.byIcon(LottiIcons.arrowUp),
        ),
        findsOne,
      );
      await tester.tap(find.byIcon(LottiIcons.arrowUp));
      expect(recorder.stops, 1);

      await tester.tap(find.byIcon(LottiIcons.close));
      expect(recorder.cancels, 1);
    });

    testWidgets('Escape cancels while listening', (tester) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(recorder.cancels, 1);
    });

    testWidgets('outside a voice-first chat stop says it transcribes', (
      tester,
    ) async {
      await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
        voiceFirst: false,
      );

      expect(
        find.descendant(
          of: tooltipped('Stop and transcribe'),
          matching: find.byIcon(LottiIcons.stop),
        ),
        findsOne,
      );
    });

    testWidgets('while transcribing, Cancel still lets the turn go', (
      tester,
    ) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.processing,
      );

      expect(find.text('Transcribing…'), findsOne);
      await tester.tap(find.byKey(ChatRecordingPillKeys.cancel));
      expect(recorder.cancels, 1);
    });

    testWidgets('a host that asks hears a transcript went out spoken', (
      tester,
    ) async {
      var spoken = 0;
      final recorder = await pumpView(tester, onSendSpoken: () => spoken++);

      recorder.hear('And the tagging?');
      await tester.pump();

      expect(draft, 'And the tagging?');
      expect(spoken, 1);
      expect(sends, 0, reason: 'a spoken send is not a typed one');
    });

    testWidgets('what was said goes out as it is', (tester) async {
      final recorder = await pumpView(tester);

      recorder.hear('And the tagging?');
      await tester.pump();

      expect(draft, 'And the tagging?');
      expect(sends, 1);
    });

    testWidgets('outside a voice-first chat a transcript waits in the draft', (
      tester,
    ) async {
      final recorder = await pumpView(tester, voiceFirst: false);

      recorder.hear('And the tagging?');
      await tester.pump();

      expect(draft, 'And the tagging?');
      expect(sends, 0);
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
