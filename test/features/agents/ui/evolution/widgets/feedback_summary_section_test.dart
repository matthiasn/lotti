import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_category_breakdown.dart';
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
      testWidgets('shows no-feedback message when items list is empty',
          (tester) async {
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

      testWidgets('does not show segmented button when items list is empty',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(items: []);

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SegmentedButton<dynamic>), findsNothing);
      });
    });

    group('segmented button toggle', () {
      testWidgets('shows segmented button with By Sentiment and By Category',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              detail: 'Good accuracy',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));
        expect(
          find.text(context.messages.agentRitualReviewBySentiment),
          findsOneWidget,
        );
        expect(
          find.text(context.messages.agentRitualReviewByCategory),
          findsOneWidget,
        );
      });

      testWidgets('defaults to sentiment view showing sentiment groups',
          (tester) async {
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
        // Category breakdown should NOT be visible in sentiment view
        expect(find.byType(FeedbackCategoryBreakdown), findsNothing);
      });

      testWidgets('switching to category view hides sentiment groups',
          (tester) async {
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

        // Tap "By Category" segment
        await tester.tap(
          find.text(context.messages.agentRitualReviewByCategory),
        );
        await tester.pumpAndSettle();

        // Sentiment group headers should disappear
        expect(
          find.text(context.messages.agentRitualReviewNegativeSignals),
          findsNothing,
        );
        // Category breakdown widget should now be present
        expect(find.byType(FeedbackCategoryBreakdown), findsOneWidget);
      });

      testWidgets('switching back to sentiment view hides category breakdown',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.communication,
              detail: 'Clear communication',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));

        // Switch to category view
        await tester.tap(
          find.text(context.messages.agentRitualReviewByCategory),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FeedbackCategoryBreakdown), findsOneWidget);

        // Switch back to sentiment view
        await tester.tap(
          find.text(context.messages.agentRitualReviewBySentiment),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FeedbackCategoryBreakdown), findsNothing);
        expect(
          find.text(context.messages.agentRitualReviewPositiveSignals),
          findsOneWidget,
        );
      });
    });

    group('sentiment view groups', () {
      testWidgets('shows negative signals group header with correct count',
          (tester) async {
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
        // Count badge shows 2
        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('shows positive signals group header with correct count',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              detail: 'Great accuracy',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));
        expect(
          find.text(context.messages.agentRitualReviewPositiveSignals),
          findsOneWidget,
        );
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('shows neutral signals group header with correct count',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.neutral,
              category: FeedbackCategory.general,
              source: 'metric',
              detail: 'Observed but no clear signal',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackSummarySection));
        expect(
          find.text(context.messages.agentRitualReviewNeutralSignals),
          findsOneWidget,
        );
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets(
          'omits negative group header when there are no negative items',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              detail: 'Great result',
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
          findsNothing,
        );
        expect(
          find.text(context.messages.agentRitualReviewNeutralSignals),
          findsNothing,
        );
      });

      testWidgets(
          'shows all three sentiment groups when all sentiments present',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Bad accuracy',
            ),
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.communication,
              detail: 'Good communication',
            ),
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.neutral,
              category: FeedbackCategory.general,
              source: 'metric',
              detail: 'Neutral observation',
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

      testWidgets('renders FeedbackItemTile for each item in expanded group',
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

        // Groups are expanded by default — both tiles should be visible
        expect(find.byType(FeedbackItemTile), findsNWidgets(2));
        // AnimatedCrossFade renders both children simultaneously,
        // so each detail text may appear in multiple Text widgets.
        expect(find.text('Item A detail'), findsWidgets);
        expect(find.text('Item B detail'), findsWidgets);
      });

      testWidgets('collapsing sentiment group hides its FeedbackItemTiles',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Negative detail text',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackSummarySection(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Initially expanded — tile visible
        expect(find.byType(FeedbackItemTile), findsOneWidget);

        // Tap the group header GestureDetector to collapse
        final context = tester.element(find.byType(FeedbackSummarySection));
        await tester.tap(
          find.text(context.messages.agentRitualReviewNegativeSignals),
        );
        await tester.pumpAndSettle();

        // After collapse, the tile should be hidden
        expect(find.byType(FeedbackItemTile), findsNothing);
      });
    });
  });
}
