import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
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
    Widget? leading,
    Widget? Function(BuildContext, AgentChatMessage)? footerTrailing,
    ValueChanged<ScrollMetrics>? onThreadScrolled,
    bool reducedMotion = false,
    VoidCallback? onSendSpoken,
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
                leading: leading,
                footerTrailingBuilder: footerTrailing,
                onThreadScrolled: onThreadScrolled,
                onSendSpoken: onSendSpoken,
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

    testWidgets("the thread's own list reports where it is; a scroll inside "
        'a message does not', (tester) async {
      final offsets = <double>[];
      await pumpView(
        tester,
        history: [
          for (var i = 0; i < 40; i++)
            AgentChatMessage(
              id: 'm$i',
              role: i.isEven ? AgentChatRole.user : AgentChatRole.agent,
              text: 'Penguin count $i',
              createdAt: at,
            ),
        ],
        // A scrollable inside a message, as a long transcript preview is.
        footerTrailing: (context, message) => message.id == 'm39'
            ? SizedBox(
                key: const Key('inner'),
                height: 40,
                child: ListView(
                  children: [for (var i = 0; i < 20; i++) Text('line $i')],
                ),
              )
            : null,
        onThreadScrolled: (metrics) => offsets.add(metrics.pixels),
      );
      await tester.pumpAndSettle();
      expect(offsets, isNotEmpty, reason: 'laid out, it reports where it is');
      final thread = offsets.last;

      offsets.clear();
      await tester.drag(find.byKey(const Key('inner')), const Offset(0, -30));
      await tester.pump();
      expect(offsets, isEmpty);

      await tester.drag(find.text('Penguin count 39'), const Offset(0, 300));
      await tester.pump();
      expect(offsets, isNotEmpty);
      expect(offsets.last, lessThan(thread));
    });

    testWidgets('her thinking is unboxed too, so her turn keeps its shape', (
      tester,
    ) async {
      await pumpView(tester, isSending: true);

      final thinking = find.ancestor(
        of: find.text('•••'),
        matching: find.byType(DecoratedBox),
      );
      final box = tester.widget<DecoratedBox>(thinking.first);
      expect((box.decoration as BoxDecoration).color, isNull);
    });

    testWidgets('what leads the thread scrolls in above its first message', (
      tester,
    ) async {
      await pumpView(tester, leading: const Text('Her', key: Key('lead')));

      final lead = tester.getRect(find.byKey(const Key('lead')));
      final first = tester.getRect(find.text('How many hatchlings?'));
      expect(lead.bottom, lessThanOrEqualTo(first.top));
    });
  });

  group('voice first', () {
    testWidgets('one large talk control leads; typing is a tap away, '
        'focused, and holds for the session', (tester) async {
      final recorder = await pumpView(tester);
      expect(find.byKey(const Key('agent-chat-talk')), findsOne);
      // The disc says what it does as its label and tooltip; under it only
      // the one quiet way to type.
      expect(find.text('Tap to talk'), findsNothing);
      expect(find.bySemanticsLabel('Tap to talk'), findsOne);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Tap to talk',
        ),
        findsOne,
      );
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byKey(const Key('agent-chat-talk')));
      await tester.pump();
      expect(recorder.starts, 1);
      await recorder.cancel();
      await tester.pump();

      // A way round the disc at caption tier, never a second button.
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('agent-chat-type-instead')),
            )
            .size,
        DesignSystemButtonSize.dense,
      );
      await tester.tap(find.byKey(const Key('agent-chat-type-instead')));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);

      // The choice holds: the same session opens on typing.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AgentChatView)),
      );
      expect(container.read(agentChatPrefersTypingProvider), isTrue);
    });

    testWidgets('on a desktop a key typed at rest starts typing with it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpView(tester);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
      await tester.pump();

      expect(draft, 'h');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AgentChatView)),
      );
      expect(container.read(agentChatPrefersTypingProvider), isTrue);
    });

    testWidgets('on a desktop a shortcut chord never starts typing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpView(tester);
      await tester.pump();

      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
      }

      expect(draft, isEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AgentChatView)),
      );
      expect(container.read(agentChatPrefersTypingProvider), isFalse);
    });

    testWidgets('on a phone a key at rest does nothing — the disc leads', (
      tester,
    ) async {
      await pumpView(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
      await tester.pump();

      expect(draft, isEmpty);
    });

    testWidgets('while listening the disc is a pill carrying what it hears; '
        'a tap sends, Cancel discards', (tester) async {
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
      );

      // The waveform says it is listening: no line says so too, and screen
      // readers hear it on the pill. The pill ends in what a tap does.
      expect(find.text('Listening — tap when done'), findsNothing);
      expect(find.text('Transcribing…'), findsNothing);
      expect(find.bySemanticsLabel('Listening — tap when done'), findsOne);
      expect(
        find
                .descendant(
                  of: find.byKey(const Key('agent-chat-talk-stop')),
                  matching: find.byIcon(LottiIcons.arrowUp),
                )
                .evaluate()
                .isNotEmpty ||
            tester
                    .widget<Icon>(find.byKey(const Key('agent-chat-talk-stop')))
                    .icon ==
                LottiIcons.arrowUp,
        isTrue,
      );
      // The talk disc's own teal, stretched into a pill.
      final pill = tester.widget<Material>(
        find.byKey(const Key('agent-chat-talk')),
      );
      expect(pill.shape, isA<StadiumBorder>());
      expect(
        pill.color,
        tester
            .element(find.byKey(const Key('agent-chat-talk')))
            .designTokens
            .colors
            .interactive
            .enabled,
      );
      // What it heard runs across it, up to the stop mark at its end.
      final waveform = tester.widget<CustomPaint>(
        find.byKey(const Key('agent-chat-talk-waveform')),
      );
      expect(
        (waveform.painter! as WaveformBarsPainter).amplitudes,
        const [0.4, 0.6, 0.5],
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('agent-chat-talk')),
          matching: find.byKey(const Key('agent-chat-talk-stop')),
        ),
        findsOne,
      );

      await tester.tap(find.byKey(const Key('agent-chat-talk')));
      expect(recorder.stops, 1);

      // Cancel is a quiet word in the slot "Type instead" holds at rest.
      expect(
        find.descendant(
          of: find.byKey(const Key('agent-chat-talk-cancel')),
          matching: find.text('Cancel'),
        ),
        findsOne,
      );
      await tester.tap(find.byKey(const Key('agent-chat-talk-cancel')));
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

    testWidgets('the pill opens from the disc it was, as tall, to 4.4 discs '
        'wide', (tester) async {
      await pumpView(tester, status: ChatRecorderStatus.recording);
      Size size() => tester.getSize(find.byKey(const Key('agent-chat-talk')));
      final talk = tester
          .element(find.byKey(const Key('agent-chat-talk')))
          .designTokens
          .spacing
          .step10;

      expect(size().width, lessThan(talk * 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(size(), Size(talk * 4.4, talk));
    });

    testWidgets('with reduced motion the pill is open at once', (
      tester,
    ) async {
      await pumpView(
        tester,
        status: ChatRecorderStatus.recording,
        reducedMotion: true,
      );
      final talk = tester
          .element(find.byKey(const Key('agent-chat-talk')))
          .designTokens
          .spacing
          .step10;

      expect(
        tester.getSize(find.byKey(const Key('agent-chat-talk'))).width,
        talk * 4.4,
      );
    });

    testWidgets('while transcribing the pill holds the words and takes no '
        'tap, and Cancel still lets the turn go', (tester) async {
      final semantics = tester.ensureSemantics();
      final recorder = await pumpView(
        tester,
        status: ChatRecorderStatus.processing,
      );

      // The wait is the pill's spinner, said to screen readers in words.
      expect(find.bySemanticsLabel('Transcribing…'), findsOne);
      expect(find.byKey(const Key('agent-chat-talk-waveform')), findsOne);
      expect(
        tester
            .widget(find.byKey(const Key('agent-chat-talk-transcribing')))
            .runtimeType,
        DesignSystemSpinner,
      );
      expect(find.byKey(const Key('agent-chat-talk-stop')), findsNothing);
      await tester.tap(find.byKey(const Key('agent-chat-talk')));
      expect(recorder.stops, 0);

      // A stalled turn always has its way out, as quiet as "Type instead".
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const Key('agent-chat-talk-cancel')),
            )
            .size,
        DesignSystemButtonSize.dense,
      );
      await tester.tap(
        find.byKey(const Key('agent-chat-talk-cancel')).hitTestable(),
      );
      expect(recorder.cancels, 1);
      semantics.dispose();
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
  });
}
