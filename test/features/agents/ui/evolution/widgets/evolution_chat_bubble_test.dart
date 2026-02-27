import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
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

    group('assistant role', () {
      testWidgets('renders markdown via GptMarkdown', (tester) async {
        await tester.pumpWidget(
          buildSubject(text: '**Bold** text', role: 'assistant'),
        );
        await tester.pumpAndSettle();

        // GptMarkdown widget should be present
        expect(find.byType(GptMarkdown), findsOneWidget);
        // Left-aligned
        final align = tester.widget<Align>(
          find.ancestor(
            of: find.byType(GptMarkdown),
            matching: find.byType(Align),
          ),
        );
        expect(align.alignment, Alignment.centerLeft);
      });
    });

    group('system role', () {
      testWidgets('displays centered text with info icon', (tester) async {
        await tester.pumpWidget(
          buildSubject(text: 'Session started', role: 'system'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Session started'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
        // Verify the bubble is wrapped in a Center via ancestor check
        expect(
          find.ancestor(
            of: find.text('Session started'),
            matching: find.byType(Center),
          ),
          findsOneWidget,
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
        // Visible answer should be shown via GptMarkdown.
        expect(find.byType(GptMarkdown), findsOneWidget);
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

      testWidgets('renders plain message without ThinkingDisclosure',
          (tester) async {
        await tester.pumpWidget(
          buildSubject(text: 'Plain message', role: 'assistant'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ThinkingDisclosure), findsNothing);
        expect(find.byType(GptMarkdown), findsOneWidget);
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
