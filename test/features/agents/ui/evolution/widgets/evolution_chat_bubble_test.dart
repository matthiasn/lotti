import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required String text,
    required String role,
    bool animate = false,
  }) {
    return makeTestableWidgetWithScaffold(
      EvolutionChatBubble(text: text, role: role, animate: animate),
    );
  }

  group('EvolutionChatBubble', () {
    group('user role', () {
      testWidgets('displays text in a right-aligned bubble', (tester) async {
        await tester.pumpWidget(buildSubject(text: 'Hello', role: 'user'));
        await tester.pumpAndSettle();

        expect(find.text('Hello'), findsOneWidget);
        // User bubbles are right-aligned via Align
        final align = tester.widget<Align>(
          find.ancestor(
            of: find.text('Hello'),
            matching: find.byType(Align),
          ),
        );
        expect(align.alignment, Alignment.centerRight);
      });
    });

    testWidgets('a short reply shrinks to its text — the width factor is a '
        'cap, not the width', (tester) async {
      await tester.pumpWidget(buildSubject(text: 'Yes', role: 'user'));
      await tester.pumpAndSettle();

      final turnWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Yes'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .width;
      final available = tester.getSize(find.byType(EvolutionChatBubble)).width;

      // A tight 80% made "Yes" a near-full-width slab of empty container.
      expect(
        turnWidth,
        lessThan(available * EvolutionChatBubble.userTurnWidthFactor),
      );
    });

    testWidgets('a long reply is capped at the width factor', (tester) async {
      await tester.pumpWidget(
        buildSubject(text: 'x ' * 400, role: 'user'),
      );
      await tester.pumpAndSettle();

      final turnWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.byType(Text).first,
                  matching: find.byType(Container),
                )
                .first,
          )
          .width;
      final available = tester.getSize(find.byType(EvolutionChatBubble)).width;

      expect(
        turnWidth,
        lessThanOrEqualTo(
          available * EvolutionChatBubble.userTurnWidthFactor + 1,
        ),
      );
    });

    group('assistant role', () {
      testWidgets('renders markdown via AgentMarkdownView', (tester) async {
        await tester.pumpWidget(
          buildSubject(text: '**Bold** text', role: 'assistant'),
        );
        await tester.pumpAndSettle();

        // AgentMarkdownView widget should be present
        expect(find.byType(AgentMarkdownView), findsOneWidget);
        // The agent's prose is unbubbled: a container around a paragraph that
        // already spans the column added an edge without adding meaning, and
        // its fill left the agent's own words at the lowest contrast on the
        // page. Nothing decorated may wrap it.
        expect(
          find.ancestor(
            of: find.byType(AgentMarkdownView),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration != null,
            ),
          ),
          findsNothing,
        );
      });
    });

    group('system role', () {
      testWidgets('is a quiet centred line, not a pill', (tester) async {
        await tester.pumpWidget(
          buildSubject(text: 'Session started', role: 'system'),
        );
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.text('Session started'));
        expect(text.textAlign, TextAlign.center);

        // A system note reports on the session rather than speaking in it, so
        // it carries no container and no icon competing with the turns
        // around it.
        expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
        expect(
          find.ancestor(
            of: find.text('Session started'),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration != null,
            ),
          ),
          findsNothing,
        );
      });
    });

    group('thinking blocks', () {
      testWidgets('separates thinking into ThinkingDisclosure', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            text: '<think>Some reasoning</think>Visible answer',
            role: 'assistant',
          ),
        );
        await tester.pumpAndSettle();

        // ThinkingDisclosure should be rendered (collapsed by default).
        expect(find.byType(ThinkingDisclosure), findsOneWidget);
        // Visible answer should be shown via AgentMarkdownView.
        expect(find.byType(AgentMarkdownView), findsOneWidget);
        // Raw think tags should not be visible.
        expect(find.text('<think>Some reasoning</think>'), findsNothing);
      });

      testWidgets('ThinkingDisclosure is collapsed by default', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            text: '<think>Hidden reasoning</think>Answer here',
            role: 'assistant',
          ),
        );
        await tester.pumpAndSettle();

        // The "Show reasoning" toggle should be present.
        expect(find.text('Show reasoning'), findsOneWidget);
        expect(find.text('Hide reasoning'), findsNothing);
      });

      testWidgets(
        'a thinking-only turn renders the disclosure and no prose',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              text: '<think>Hidden reasoning only</think>',
              role: 'assistant',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ThinkingDisclosure), findsOneWidget);
          expect(find.byType(AgentMarkdownView), findsNothing);

          await tester.pumpWidget(
            buildSubject(
              text: '<think>Hidden reasoning</think>Visible answer',
              role: 'assistant',
            ),
          );
          await tester.pumpAndSettle();

          // A mixed turn keeps both, in order: the disclosure, then the answer.
          expect(find.byType(ThinkingDisclosure), findsOneWidget);
          expect(find.byType(AgentMarkdownView), findsOneWidget);
        },
      );

      testWidgets('renders plain message without ThinkingDisclosure', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(text: 'Plain message', role: 'assistant'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ThinkingDisclosure), findsNothing);
        expect(find.byType(AgentMarkdownView), findsOneWidget);
      });
    });

    group('unknown role', () {
      testWidgets('renders nothing for unknown role', (tester) async {
        await tester.pumpWidget(buildSubject(text: 'x', role: 'unknown'));
        await tester.pumpAndSettle();

        expect(find.text('x'), findsNothing);
      });
    });

    group('animation', () {
      testWidgets('shows entry animation when animate is true', (tester) async {
        await tester.pumpWidget(
          buildSubject(text: 'Animated', role: 'user', animate: true),
        );
        // Should have SlideTransition as a descendant of the bubble widget
        expect(
          find.descendant(
            of: find.byType(EvolutionChatBubble),
            matching: find.byType(SlideTransition),
          ),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        expect(find.text('Animated'), findsOneWidget);
      });

      testWidgets('skips animation when animate is false', (tester) async {
        await tester.pumpWidget(
          buildSubject(text: 'Static', role: 'user'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Static'), findsOneWidget);
        // No SlideTransition as a descendant of the bubble widget
        expect(
          find.descendant(
            of: find.byType(EvolutionChatBubble),
            matching: find.byType(SlideTransition),
          ),
          findsNothing,
        );
      });
    });
  });
}
