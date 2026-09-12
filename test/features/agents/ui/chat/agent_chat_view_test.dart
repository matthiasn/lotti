import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/screenshot_harness.dart';
import '../../../../widget_test_utils.dart';
import '../evolution/widgets/evolution_recorder_test_utils.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('reply links keep message attribution and accessible actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final taps = <(AgentChatMessage, String, String)>[];
    final message = AgentChatMessage(
      id: 'feeder-reply',
      role: AgentChatRole.agent,
      text: 'See the [Decision](query-source:feeder).',
      createdAt: DateTime(2026, 9, 10, 9),
    );
    try {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'agent',
              agentName: 'Juno',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
              composerEnabled: false,
              history: AsyncData([message]),
              onLinkTap: (message, url, title) =>
                  taps.add((message, url, title)),
            ),
          ),
          locale: const Locale('fr'),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Juno à 09:00'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Juno, 09:00 : ${message.text}'),
        findsNothing,
      );
      final link = find.bySemanticsLabel('Decision');
      expect(
        tester
            .getSemantics(link)
            .getSemanticsData()
            .hasAction(
              SemanticsAction.tap,
            ),
        isTrue,
      );
      await tester.tap(find.text('Decision', findRichText: true));
      expect(taps, [(message, 'query-source:feeder', 'Decision')]);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });

  testWidgets(
    'partial transcription expands within a narrow keyboard viewport and cancels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        const size = Size(320, 760);
        const keyboard = 240.0;
        setTestSurfaceSize(tester, size);
        final partial = List.generate(
          12,
          (index) =>
              'Penguin feeder discussion $index keeps the smaller hopper '
              'available for the next habitat trial.',
        ).join(' ');
        var cancelled = 0;
        var sent = 0;
        final drafts = <String>[];
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: Builder(
                builder: (context) => AgentChatView(
                  agentId: 'agent',
                  agentName: 'Habitat Watcher',
                  draft: '',
                  isSending: false,
                  onDraftChanged: drafts.add,
                  onSend: () => sent++,
                  onRetry: () {},
                  showVoiceDetails: true,
                  history: const AsyncData([]),
                  footer: Padding(
                    padding: EdgeInsets.all(context.designTokens.spacing.step4),
                    child: Text(
                      context.messages.queryTranscribing,
                      style:
                          context.designTokens.typography.styles.others.caption,
                    ),
                  ),
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(1.5),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            overrides: [
              chatRecorderControllerProvider.overrideWith(
                () => ProcessingTestController(
                  partialTranscript: partial,
                  onCancelCalled: () => cancelled++,
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        final previewText = find.text(partial);
        expect(
          MediaQuery.textScalerOf(tester.element(previewText)).scale(10),
          15,
        );
        final collapsed = tester.widget<Text>(previewText);
        expect(collapsed.maxLines, inInclusiveRange(1, 3));
        expect(collapsed.overflow, TextOverflow.ellipsis);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Show more'))
              .flagsCollection
              .isExpanded,
          Tristate.isFalse,
        );
        await tester.tap(find.text('Show more'));
        await tester.pump();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Show less'))
              .flagsCollection
              .isExpanded,
          Tristate.isTrue,
        );
        final scroll = find.byKey(const ValueKey('chat-transcription-preview'));
        final viewport = tester.getRect(scroll);
        final chat = tester.getRect(find.byType(AgentChatView));
        expect(viewport.height, lessThanOrEqualTo(chat.height / 4));
        final cancel = find.widgetWithText(DesignSystemButton, 'Cancel');
        final cancelRect = tester.getRect(cancel);
        expect(cancelRect.height, greaterThanOrEqualTo(TapTargets.minimum));
        expect(cancelRect.top, greaterThanOrEqualTo(viewport.bottom));
        expect(cancelRect.bottom, lessThanOrEqualTo(size.height - keyboard));
        expect(cancelRect.right, lessThanOrEqualTo(size.width));
        final scrollController = tester
            .widget<SingleChildScrollView>(scroll)
            .controller!;
        expect(scrollController.position.maxScrollExtent, greaterThan(0));
        await tester.drag(scroll, const Offset(0, -120));
        await tester.pump();
        expect(scrollController.offset, greaterThan(0));
        expect(tester.getRect(cancel), cancelRect);
        await tester.tap(find.text('Show less'));
        await tester.pump();
        expect(tester.widget<Text>(previewText).maxLines, collapsed.maxLines);
        await tester.tap(find.text('Show more'));
        await tester.pump();
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        expect(cancelled, 1);
        expect(drafts, isEmpty);
        expect(sent, 0);
        expect(find.text(partial), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      }
    },
  );

  for (final partial in <String?>[null, 'The smaller hopper stays.']) {
    testWidgets('short or empty transcription remains compact: $partial', (
      tester,
    ) async {
      var cancelled = false;
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'agent',
              agentName: 'Habitat Watcher',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
              showVoiceDetails: true,
              history: const AsyncData([]),
            ),
          ),
          overrides: [
            chatRecorderControllerProvider.overrideWith(
              () => ProcessingTestController(
                partialTranscript: partial,
                onCancelCalled: () => cancelled = true,
              ),
            ),
          ],
        ),
      );
      expect(find.text(partial ?? 'Transcribing…'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
      final cancel = find.widgetWithText(DesignSystemButton, 'Cancel');
      expect(
        tester.getSize(cancel).height,
        greaterThanOrEqualTo(TapTargets.minimum),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'supporting evidence belongs to its reply surface and reading width',
    (tester) async {
      final message = AgentChatMessage(
        id: 'reply',
        role: AgentChatRole.agent,
        text: 'The feeder was approved.',
        createdAt: DateTime(2026, 9, 10),
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'agent',
              agentName: 'Habitat Watcher',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
              history: AsyncData([message]),
              conversationId: 'query',
              composerEnabled: false,
              groupAttachmentsWithReply: true,
              replyTextStyle: dsTokensLight.typography.styles.body.bodySmall,
              attachmentBuilder: (_, _) => const SizedBox(
                width: double.infinity,
                child: Text('Exact approved passage'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final reply = find.byKey(const ValueKey('goal-chat-message-reply'));
      final evidence = find.text('Exact approved passage');
      expect(find.descendant(of: reply, matching: evidence), findsOneWidget);
      expect(
        tester.getRect(reply).contains(tester.getTopLeft(evidence)),
        isTrue,
      );
      expect(tester.getSize(evidence).width, lessThanOrEqualTo(520));
      expect(
        tester.widget<GptMarkdown>(find.byType(GptMarkdown)).style!.fontSize,
        dsTokensLight.typography.styles.body.bodySmall.fontSize,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a scoped history bypasses the agent log and can disable composition',
    (tester) async {
      var logReads = 0;
      final message = AgentChatMessage(
        id: 'query-reply',
        role: AgentChatRole.agent,
        text: 'The feeder was approved.',
        createdAt: DateTime(2026, 9, 10),
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'agent',
              agentName: 'Habitat Watcher',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
              history: AsyncData([message]),
              conversationId: 'query-chat',
              composerEnabled: false,
              scrollOnReplies: false,
              attachmentBuilder: (_, _) => const Text('Exact approved passage'),
              footer: const Text('Archived fixture'),
            ),
          ),
          overrides: [
            agentChatProjectionProvider('agent').overrideWith((ref) async {
              logReads++;
              return [];
            }),
          ],
        ),
      );
      await tester.pump();
      expect(logReads, 0);
      expect(find.text('The feeder was approved.'), findsOneWidget);
      expect(find.text('Exact approved passage'), findsOneWidget);
      expect(find.text('Archived fixture'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
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
    await tester.tap(find.byIcon(LottiIcons.send));
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

  testWidgets(
    'custom activity label describes composer and thinking semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: AgentChatView(
                agentId: 'goal-1',
                agentName: 'Juno',
                draft: '',
                isSending: true,
                sendingLabel: 'Searching linked notes and recordings…',
                history: const AsyncData([]),
                onDraftChanged: (_) {},
                onSend: () {},
                onRetry: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('Searching linked notes and recordings…'),
          findsOneWidget,
        );
        expect(find.text('Juno is replying…'), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape('Searching linked notes and recordings…')),
          ),
          findsWidgets,
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape('Juno is replying…'))),
          findsNothing,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('renders agent markdown and expands a collapsed long reply', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
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
              onLinkTap: (_, _, _) {},
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
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Show more'))
            .flagsCollection
            .isExpanded,
        Tristate.isFalse,
      );

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Show less'))
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );
      expect(find.byKey(collapseClip), findsNothing);
      expect(
        tester.getSize(find.byType(AgentMarkdownView)).height,
        greaterThan(collapsedHeight),
      );

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(find.byKey(collapseClip), findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });

  testWidgets('a reply that fits the collapsed viewport shows no toggle', (
    tester,
  ) async {
    // The toggle is measurement-driven: content that renders inside the
    // collapsed viewport must not offer a Show more that would do nothing.
    const wideShortReply = 'Nice work today — both habits are on track.';

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

      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
      expect(find.byIcon(LottiIcons.send), findsNothing);
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

      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
      expect(find.byIcon(LottiIcons.send), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(find.byIcon(LottiIcons.send), findsOneWidget);
      expect(find.byIcon(LottiIcons.mic), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
      expect(find.byIcon(LottiIcons.send), findsNothing);
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

      await tester.tap(find.byIcon(LottiIcons.mic));
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
      expect(find.byIcon(LottiIcons.close), findsOneWidget);
      expect(find.byIcon(LottiIcons.stop), findsOneWidget);
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

      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pump();
      expect(cancelCalled, isTrue);

      // The controller transitions to idle, so the mic reappears.
      await tester.pumpAndSettle();
      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
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

      await tester.tap(find.byIcon(LottiIcons.stop));
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
      expect(find.byIcon(LottiIcons.send), findsOneWidget);
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
      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
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
      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
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

      controller.emitError(
        'Microphone permission denied. Please enable it in Settings.',
        kind: ChatRecorderErrorKind.permissionDenied,
      );
      await tester.pump();
      await tester.pump();

      // The toast names the actual problem instead of the generic line.
      expect(
        find.textContaining("Lotti can't use the microphone"),
        findsOneWidget,
      );
      expect(find.textContaining('Recording failed'), findsNothing);
      expect(controller.clearResultCalls, greaterThan(0));
    });

    testWidgets('a missing audio model and a failed request read '
        'differently', (tester) async {
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

      controller.emitError(
        'No audio-capable models configured',
        kind: ChatRecorderErrorKind.noAudioModel,
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('No transcription model is set up yet'),
        findsOneWidget,
      );

      controller.emitError(
        'network down',
        kind: ChatRecorderErrorKind.transcriptionFailed,
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('transcribing it failed'),
        findsOneWidget,
      );
      // The raw diagnostic English never reaches the toast.
      expect(find.textContaining('network down'), findsNothing);
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
      expect(find.byIcon(LottiIcons.mic), findsOneWidget);
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

      expect(find.byIcon(LottiIcons.mic), findsNothing);
      expect(find.byIcon(LottiIcons.send), findsNothing);
    });
  });

  testWidgets(
    'a long reply scrolled out and back is collapsed on its first frame',
    (tester) async {
      // The user-visible bug: ListView.builder disposes an item's State once
      // it passes the cache extent. Coming back, the reply re-measured from
      // scratch, so for one frame it laid out at FULL height — which grows
      // the content above the viewport and forces the scroll position to be
      // corrected. That correction is the flashing and bouncing reported
      // while scrolling a goal chat.
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Comfortably more than the 8-line collapsed clamp.
      final longReply = List.generate(
        40,
        (line) => 'Line $line of a long agent reply that keeps going.',
      ).join('\n\n');
      final history = <AgentChatMessage>[
        AgentChatMessage(
          id: 'long',
          role: AgentChatRole.agent,
          text: longReply,
          createdAt: DateTime(2026, 8, 11, 9),
        ),
        // Enough trailing traffic to push the long reply well past the
        // cache extent once the view settles at the newest message.
        for (var i = 0; i < 40; i++)
          AgentChatMessage(
            id: 'filler-$i',
            role: i.isEven ? AgentChatRole.user : AgentChatRole.agent,
            text: 'Short follow-up $i.',
            createdAt: DateTime(2026, 8, 11, 9, i + 1),
          ),
      ];

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
            ).overrideWith((ref) async => history),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final collapse = find.byKey(const ValueKey('agent-reply-collapse'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;

      // The view settles at the newest message, far below the long reply,
      // whose State has been disposed by then.
      expect(
        find.byKey(const ValueKey('goal-chat-message-long')),
        findsNothing,
        reason:
            'the long reply must leave the cache extent for the recycle '
            'path to be exercised',
      );

      // Bring it back and look at the VERY FIRST frame it is rebuilt in.
      position.jumpTo(0);
      await tester.pump();

      expect(
        collapse,
        findsOneWidget,
        reason:
            'a recycled reply must lay out collapsed immediately, not '
            'after a measure-and-rebuild round trip',
      );
      // The symptom itself: laying the reply out at full height grows the
      // content above the viewport, and the scroll machinery corrects the
      // offset away from where the user put it. A collapsed first frame
      // leaves the requested offset alone.
      expect(
        position.pixels,
        0,
        reason:
            'a full-height first frame forces a scroll correction, '
            'which is what makes the list jump',
      );
    },
  );
  testWidgets(
    'query recording clock crosses a minute without moving stop controls',
    (tester) async {
      var stopped = 0;
      final recorder = RecordingCallbackController(
        initialElapsed: const Duration(seconds: 59),
        onStopCalled: () => stopped++,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'agent',
              agentName: 'Habitat Watcher',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () {},
              onRetry: () {},
              showVoiceDetails: true,
              history: const AsyncData([]),
            ),
          ),
          overrides: [
            chatRecorderControllerProvider.overrideWith(() => recorder),
          ],
        ),
      );
      final clock = tester.getRect(find.text('00:59'));
      final stop = tester.getRect(find.text('Stop'));
      recorder.updateElapsed(const Duration(minutes: 1));
      await tester.pump();
      expect(tester.getRect(find.text('01:00')), clock);
      expect(tester.getRect(find.text('Stop')), stop);
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(stopped, 1);
      expect(find.text('01:00'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'query transcription can be cancelled without submitting partial text',
    (tester) async {
      var cancelled = 0;
      var sent = 0;
      final recorder = ProcessingTestController(
        partialTranscript: 'Feeder cali',
        onCancelCalled: () => cancelled++,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: AgentChatView(
              agentId: 'agent',
              agentName: 'Habitat Watcher',
              draft: '',
              isSending: false,
              onDraftChanged: (_) {},
              onSend: () => sent++,
              onRetry: () {},
              showVoiceDetails: true,
              history: const AsyncData([]),
            ),
          ),
          overrides: [
            chatRecorderControllerProvider.overrideWith(() => recorder),
          ],
        ),
      );
      expect(find.text('Feeder cali'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, 1);
      expect(sent, 0);
      expect(find.text('Feeder cali'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
