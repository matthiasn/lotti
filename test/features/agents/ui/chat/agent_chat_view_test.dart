import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';

import '../../../../widget_test_utils.dart';
import '../evolution/widgets/evolution_recorder_test_utils.dart';

void main() {
  testWidgets('the visible message footer follows locale word order', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        locale: const Locale('fr'),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: '1',
                role: AgentChatRole.agent,
                text: 'On y va.',
                createdAt: DateTime(2026, 8, 11, 9),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juno à 09:00'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Juno, 09:00 : On y va.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('On y va.'), findsNothing);
    expect(find.bySemanticsLabel('Juno à 09:00'), findsNothing);
  });

  testWidgets('renders persisted roles and forwards a composed message', (
    tester,
  ) async {
    var draft = '';
    var sent = false;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: draft,
              isSending: false,
              onDraftChanged: (value) => setState(() => draft = value),
              onSend: () => sent = true,
              onRetry: () {},
            ),
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: '1',
                role: AgentChatRole.agent,
                text: 'How did the gym go?',
                createdAt: DateTime(2026, 8, 11, 9),
              ),
              AgentChatMessage(
                id: '2',
                role: AgentChatRole.user,
                text: 'I went this morning.',
                createdAt: DateTime(2026, 8, 11, 9, 1),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How did the gym go?'), findsOneWidget);
    expect(find.text('I went this morning.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Keep me honest.');
    await tester.pump();
    expect(draft, 'Keep me honest.');
    await tester.tap(find.byIcon(Icons.send_rounded));
    expect(sent, isTrue);
  });

  testWidgets('shows the in-flight and retry states without losing history', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: 'Still here',
            isSending: true,
            hasFailedTurn: true,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () => retried = true,
          ),
        ),
        overrides: [
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('•••'), findsOneWidget);
    expect(find.text("That didn't send."), findsOneWidget);
    expect(find.text('Juno is replying…'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    expect(retried, isTrue);
  });

  testWidgets('renders agent markdown and expands a collapsed long reply', (
    tester,
  ) async {
    final longReply = List.generate(
      12,
      (index) => '${index + 1}. **Coaching point ${index + 1}** — details',
    ).join('\n');

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: 'long-reply',
                role: AgentChatRole.agent,
                text: longReply,
                createdAt: DateTime(2026, 8, 11, 9),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AgentMarkdownView), findsOneWidget);
    expect(
      tester.widget<GptMarkdown>(find.byType(GptMarkdown)).data,
      longReply,
    );
    // Height-based collapse: `GptMarkdown.maxLines` counts each block
    // element as one line, so it never truncated numbered coaching lists.
    // The clamp is a clipped viewport instead.
    const collapseClip = ValueKey('agent-reply-collapse');
    expect(find.byKey(collapseClip), findsOneWidget);
    final collapsedHeight = tester.getSize(find.byKey(collapseClip)).height;
    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    expect(find.text('Show less'), findsOneWidget);
    expect(find.byKey(collapseClip), findsNothing);
    expect(
      tester.getSize(find.byType(AgentMarkdownView)).height,
      greaterThan(collapsedHeight),
    );

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.byKey(collapseClip), findsOneWidget);
    expect(find.text('Show more'), findsOneWidget);
  });

  testWidgets('a reply that fits the collapsed viewport shows no toggle even '
      'when its character count is high', (tester) async {
    // Over the former 360-character heuristic, but rendering as a couple of
    // lines — the old line-count clamp showed a Show more button that did
    // nothing.
    final wideShortReply = List.filled(25, 'steady progress').join(' ');

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              AgentChatMessage(
                id: 'wide-short-reply',
                role: AgentChatRole.agent,
                text: wideShortReply,
                createdAt: DateTime(2026, 8, 11, 9),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Show more'), findsNothing);
    expect(find.text('Show less'), findsNothing);
  });

  testWidgets('restores an externally retained draft and submits it from the '
      'keyboard', (tester) async {
    var draft = '';
    var sent = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (value) => setState(() => draft = value),
                onSend: () => sent = true,
                onRetry: () {},
              ),
            );
          },
        ),
        overrides: [
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    rebuild(() => draft = 'Recovered draft');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Recovered draft',
    );

    tester
        .widget<TextField>(find.byType(TextField))
        .onSubmitted
        ?.call('Recovered draft');
    await tester.pump();
    expect(sent, isTrue);
  });

  testWidgets(
    'distinguishes a failed history load from an empty conversation',
    (
      tester,
    ) async {
      final harness = makeTestableWidgetWithContainer(
        Scaffold(
          body: AgentChatView(
            agentId: 'goal-1',
            agentName: 'Juno',
            draft: '',
            isSending: false,
            onDraftChanged: (_) {},
            onSend: () {},
            onRetry: () {},
          ),
        ),
        overrides: [
          agentChatProjectionProvider(
            'goal-1',
          ).overrideWith((ref) async => throw StateError('database offline')),
        ],
        retry: (_, _) => null,
      );
      addTearDown(harness.container.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load this conversation right now."),
        findsOneWidget,
      );
      expect(find.textContaining('Start a conversation'), findsNothing);
    },
  );

  testWidgets('editing a draft does not pull a scrolled conversation down', (
    tester,
  ) async {
    var draft = '';
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SizedBox(
              height: 420,
              child: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (value) => setState(() => draft = value),
                onSend: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
        overrides: [
          agentChatProjectionProvider('goal-1').overrideWith(
            (ref) async => [
              for (var index = 0; index < 30; index++)
                AgentChatMessage(
                  id: '$index',
                  role: AgentChatRole.agent,
                  text: 'Message $index with enough text to occupy a row.',
                  createdAt: DateTime(2026, 8, 11, 9, index),
                ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Message 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Still reading');
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Message 0'), findsOneWidget);
    expect(find.textContaining('Message 29'), findsNothing);
  });

  group('voice input', () {
    testWidgets('shows a mic button when idle with no text', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              ChatRecorderController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('shows send when text is present and mic when cleared', (
      tester,
    ) async {
      var draft = '';
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (v) => setState(() => draft = v),
                onSend: () {},
                onRetry: () {},
              ),
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              ChatRecorderController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('tapping the mic starts recording', (tester) async {
      var startCalled = false;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => IdleCallbackController(
                onStartCalled: () => startCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();

      expect(startCalled, isTrue);
    });

    testWidgets('shows waveform and cancel/stop while recording', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              RecordingTestController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WaveformBars), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('cancel button calls the recorder', (tester) async {
      var cancelCalled = false;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => RecordingCallbackController(
                onCancelCalled: () => cancelCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(cancelCalled, isTrue);

      // The controller transitions to idle, so the mic reappears.
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('stop button calls the recorder', (tester) async {
      var stopCalled = false;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => RecordingCallbackController(
                onStopCalled: () => stopCalled = true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      expect(stopCalled, isTrue);
    });

    testWidgets('a finished transcript fills the text field', (tester) async {
      var draft = '';
      late TranscriptEmittingController controller;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (v) => setState(() => draft = v),
                onSend: () {},
                onRetry: () {},
              ),
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => controller = TranscriptEmittingController(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      controller.emitTranscript('I walked this morning.');
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'I walked this morning.',
      );
      expect(draft, 'I walked this morning.');
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('shows partial transcript while processing', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => ProcessingTestController(
                partialTranscript: 'Transcribing audio…',
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Transcribing audio…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows progress indicator when processing with no partial', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => ProcessingTestController(partialTranscript: null),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a transcription error shows a toast and clears the error', (
      tester,
    ) async {
      late TranscriptEmittingController controller;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => controller = TranscriptEmittingController(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      controller.emitError('Microphone permission denied');
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Recording failed'),
        findsOneWidget,
      );
      expect(controller.clearResultCalls, greaterThan(0));
    });

    testWidgets('an empty transcript is not written to the draft', (
      tester,
    ) async {
      var draft = '';
      late TranscriptEmittingController controller;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: draft,
                isSending: false,
                onDraftChanged: (v) => setState(() => draft = v),
                onSend: () {},
                onRetry: () {},
              ),
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              () => controller = TranscriptEmittingController(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      controller.emitTranscript('   ');
      await tester.pumpAndSettle();

      expect(draft, '');
      expect(controller.clearResultCalls, greaterThan(0));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('mic button is hidden while sending', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'goal-1',
              agentName: 'Juno',
              draft: '',
              isSending: true,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
            ),
          ),
          overrides: [
            agentChatProjectionProvider(
              'goal-1',
            ).overrideWith((ref) async => const []),
            chatRecorderControllerProvider.overrideWith(
              ChatRecorderController.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });
  });
}
