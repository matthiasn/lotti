import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject(RitualSessionHistoryEntry entry) {
    return makeTestableWidgetWithScaffold(
      RitualSessionHistoryCard(entry: entry),
    );
  }

  group('RitualSessionHistoryCard', () {
    testWidgets('renders recap tldr when present', (tester) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
        feedbackSummary: 'Legacy fallback summary.',
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: 'This recap summary should be shown.',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This recap summary should be shown.'), findsOneWidget);
      expect(find.text('Legacy fallback summary.'), findsNothing);
    });

    testWidgets('falls back to feedbackSummary when recap tldr is blank', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
        feedbackSummary: 'Legacy fallback summary.',
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: '   ',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Legacy fallback summary.'), findsOneWidget);
    });

    testWidgets('renders no summary when both tldr and feedbackSummary empty', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        tldr: '',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) => w is Text && w.maxLines == 3),
        findsNothing,
      );
    });

    testWidgets('renders human-readable rating labels from stored recap keys', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        categoryRatings: const {
          'internal_alignment': 4,
          'cleanAchievements': 3,
          'communication': 5,
        },
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Internal Alignment 4/5'), findsOneWidget);
      expect(find.text('Clean Achievements 3/5'), findsOneWidget);
      expect(find.text('Communication 5/5'), findsOneWidget);
      expect(find.text('General 4/5'), findsNothing);
      expect(find.text('General 3/5'), findsNothing);
    });
  });

  group('StatusRow', () {
    testWidgets('renders "Completed" label with primary color', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Completed'));
      final theme = Theme.of(tester.element(find.text('Completed')));
      expect(textWidget.style?.color, theme.colorScheme.primary);
      expect(textWidget.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('renders "Abandoned" label with error color', (tester) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.abandoned,
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Abandoned'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Abandoned'));
      final theme = Theme.of(tester.element(find.text('Abandoned')));
      expect(textWidget.style?.color, theme.colorScheme.error);
      expect(textWidget.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('renders "Active" label with tertiary color', (tester) async {
      final session = makeTestEvolutionSession(
        // ignore: avoid_redundant_argument_values
        status: EvolutionSessionStatus.active,
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Active'));
      final theme = Theme.of(tester.element(find.text('Active')));
      expect(textWidget.style?.color, theme.colorScheme.tertiary);
      expect(textWidget.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('status pill has colored background with low opacity', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session),
        ),
      );
      await tester.pumpAndSettle();

      // The status text is inside a Container with a colored background
      final statusText = find.text('Completed');
      final container = find.ancestor(
        of: statusText,
        matching: find.byType(Container),
      );
      expect(container, findsWidgets);

      // Find the decorated container wrapping the status label
      final decoratedContainer = tester
          .widgetList<Container>(container)
          .where(
            (c) => c.decoration is BoxDecoration,
          );
      expect(decoratedContainer, isNotEmpty);

      final decoration = decoratedContainer.first.decoration! as BoxDecoration;
      final theme = Theme.of(tester.element(statusText));
      final expectedColor = theme.colorScheme.primary;

      // Background color should be the primary color with reduced alpha
      expect(decoration.color, expectedColor.withValues(alpha: 0.12));
      expect(decoration.borderRadius, BorderRadius.circular(999));
    });
  });

  group('Section widget', () {
    testWidgets('renders title and child content within expanded card', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        recapMarkdown: '## Recap content\n\n- Point one',
        approvedChangeSummary: '- Changed directive tone',
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the tile to reveal sections
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Section titles should be rendered
      expect(find.text('Session Recap'), findsOneWidget);
      expect(find.text('Approved changes'), findsOneWidget);

      // Section titles should use titleSmall with bold weight
      final recapTitle = tester.widget<Text>(find.text('Session Recap'));
      expect(recapTitle.style?.fontWeight, FontWeight.w700);

      // The child content (AgentMarkdownView) should be rendered
      // as GptMarkdown widgets
      expect(find.byType(GptMarkdown), findsWidgets);
    });

    testWidgets('does not render section when content is empty', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        recapMarkdown: '',
        approvedChangeSummary: '',
        transcript: const [],
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // No section headings should appear
      expect(find.text('Session Recap'), findsNothing);
      expect(find.text('Approved changes'), findsNothing);
      expect(find.text('Conversation'), findsNothing);
    });
  });

  group('_ratingLabelForKey', () {
    testWidgets('splits camelCase key into title-cased words', (
      tester,
    ) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        categoryRatings: const {'cleanCode': 4},
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clean Code 4/5'), findsOneWidget);
    });

    testWidgets('falls back to General label for empty key', (tester) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        categoryRatings: const {'': 3},
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General 3/5'), findsOneWidget);
    });

    testWidgets(
      'resolves known FeedbackCategory enum name to localized label',
      (
        tester,
      ) async {
        final session = makeTestEvolutionSession(
          status: EvolutionSessionStatus.completed,
        );
        final recap = makeTestEvolutionSessionRecap(
          sessionId: session.id,
          categoryRatings: const {'accuracy': 5},
        );

        await tester.pumpWidget(
          buildSubject(
            RitualSessionHistoryEntry(session: session, recap: recap),
          ),
        );
        await tester.pumpAndSettle();

        // 'accuracy' matches FeedbackCategory.accuracy -> localized label
        expect(find.text('Accuracy 5/5'), findsOneWidget);
      },
    );

    testWidgets('handles underscore_separated keys', (tester) async {
      final session = makeTestEvolutionSession(
        status: EvolutionSessionStatus.completed,
      );
      final recap = makeTestEvolutionSessionRecap(
        sessionId: session.id,
        categoryRatings: const {'code_quality': 4},
      );

      await tester.pumpWidget(
        buildSubject(
          RitualSessionHistoryEntry(session: session, recap: recap),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Code Quality 4/5'), findsOneWidget);
    });
  });
}
