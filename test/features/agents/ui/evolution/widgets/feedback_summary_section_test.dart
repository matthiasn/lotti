import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_item_tile.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_summary_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject(FeedbackSummarySection widget) {
    return makeTestableWidgetWithScaffold(widget);
  }

  group('FeedbackSummarySection', () {
    group('empty state', () {
      testWidgets('shows no-feedback message when items list is empty', (
        tester,
      ) async {
        final feedback = makeTestClassifiedFeedback(items: []);

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));
        expect(
          find.text(context.messages.agentRitualReviewNoFeedback),
          findsOneWidget,
        );
      });

      testWidgets('does not show tab bar when items list is empty', (
        tester,
      ) async {
        final feedback = makeTestClassifiedFeedback(items: []);

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsNothing);
      });
    });

    group('sentiment tab view', () {
      testWidgets('shows tab bar with all three sentiment tabs', (
        tester,
      ) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Inaccurate report',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));
        expect(
          find.text(context.messages.agentRitualReviewNegativeSignals),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.agentRitualReviewPositiveSignals),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.agentRitualReviewNeutralSignals),
          findsOneWidget,
        );
      });

      testWidgets('shows count badges for each sentiment tab', (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'First negative',
            ),
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              category: FeedbackCategory.prioritization,
              detail: 'Second negative',
            ),
            makeTestClassifiedFeedbackItem(
              detail: 'One positive',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Negative tab badge shows 2, positive shows 1, neutral shows 0
        expect(find.text('2'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      });

      testWidgets(
        'renders FeedbackItemTile for items in the initially visible tab',
        (tester) async {
          final feedback = makeTestClassifiedFeedback(
            items: [
              makeTestClassifiedFeedbackItem(
                sentiment: FeedbackSentiment.negative,
                source: 'observation',
                detail: 'Item A detail',
              ),
              makeTestClassifiedFeedbackItem(
                sentiment: FeedbackSentiment.negative,
                category: FeedbackCategory.tooling,
                detail: 'Item B detail',
              ),
            ],
          );

          await tester.pumpWidget(
            buildSubject(FeedbackSummarySection(feedback: feedback)),
          );
          await tester.pumpAndSettle();

          // Default tab is Negative (first tab) — both tiles should be visible
          expect(find.byType(FeedbackItemTile), findsNWidgets(2));
          expect(find.text('Item A detail'), findsWidgets);
          expect(find.text('Item B detail'), findsWidgets);
        },
      );

      testWidgets('switching tabs shows items for the selected sentiment', (
        tester,
      ) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Negative item',
            ),
            makeTestClassifiedFeedbackItem(
              detail: 'Positive item',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));

        // Initial tab (Negative) shows negative item
        expect(find.text('Negative item'), findsWidgets);

        // Tap Positive tab
        await tester.tap(
          find.text(context.messages.agentRitualReviewPositiveSignals),
        );
        await tester.pumpAndSettle();

        // Positive item should now be visible
        expect(find.text('Positive item'), findsWidgets);
      });

      testWidgets('empty tab shows tab-specific empty-state message', (
        tester,
      ) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              detail: 'Positive item only',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));

        // Default tab (Negative) is empty — should show no-feedback message
        expect(
          find.text(context.messages.agentRitualReviewNoNegativeSignals),
          findsOneWidget,
        );

        // Positive tab has content, so no empty-state message should render.
        await tester.tap(
          find.text(context.messages.agentRitualReviewPositiveSignals),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(context.messages.agentRitualReviewNoPositiveSignals),
          findsNothing,
        );

        // Neutral tab is empty.
        await tester.tap(
          find.text(context.messages.agentRitualReviewNeutralSignals),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(context.messages.agentRitualReviewNoNeutralSignals),
          findsOneWidget,
        );
      });

      testWidgets('tab content fills available space via Expanded', (
        tester,
      ) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'A signal',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // The item list is wrapped in an Expanded widget (not a
        // fixed-height SizedBox) so it fills the remaining space.
        final expandedWidgets = tester.widgetList<Expanded>(
          find.byType(Expanded),
        );
        expect(expandedWidgets, isNotEmpty);
      });
    });
  });
}
