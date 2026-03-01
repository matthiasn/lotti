import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_category_breakdown.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_item_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject(FeedbackCategoryBreakdown widget) {
    return makeTestableWidgetWithScaffold(widget);
  }

  group('FeedbackCategoryBreakdown', () {
    group('empty state', () {
      testWidgets('renders nothing (SizedBox.shrink) when items are empty',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(items: []);

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // No category labels should appear
        expect(find.byType(FeedbackItemTile), findsNothing);
        expect(find.byIcon(Icons.verified_outlined), findsNothing);
      });
    });

    group('category grouping', () {
      testWidgets('groups items by category and shows category label',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Inaccurate report',
            ),
            makeTestClassifiedFeedbackItem(
              detail: 'Correct priority',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackCategoryBreakdown));

        // Category label appears in the header (size 14) and badge in tiles (size 10).
        // At least one occurrence should be found.
        expect(
          find.text(context.messages.agentFeedbackCategoryAccuracy),
          findsAtLeastNWidgets(1),
        );
        // Count badge shows 2
        expect(find.text('2'), findsOneWidget);
        // Both items rendered as tiles (expanded by default)
        expect(find.byType(FeedbackItemTile), findsNWidgets(2));
      });

      testWidgets('renders separate groups for different categories',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Accuracy issue',
            ),
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.neutral,
              category: FeedbackCategory.timeliness,
              source: 'metric',
              detail: 'Timeliness observation',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackCategoryBreakdown));
        expect(
          find.text(context.messages.agentFeedbackCategoryAccuracy),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.text(context.messages.agentFeedbackCategoryTimeliness),
          findsAtLeastNWidgets(1),
        );
        // One tile per category (both expanded by default)
        expect(find.byType(FeedbackItemTile), findsNWidgets(2));
      });

      testWidgets('sorts categories by item count descending', (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            // accuracy: 1 item
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Single accuracy item',
            ),
            // communication: 2 items
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.communication,
              detail: 'Communication A',
            ),
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.communication,
              detail: 'Communication B',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackCategoryBreakdown));

        // Find the header-level texts (size 14, white) to check ordering
        final accuracyHeaderFinder = find.descendant(
          of: find.byType(FeedbackCategoryBreakdown),
          matching: find.text(context.messages.agentFeedbackCategoryAccuracy),
        );
        final commHeaderFinder = find.descendant(
          of: find.byType(FeedbackCategoryBreakdown),
          matching:
              find.text(context.messages.agentFeedbackCategoryCommunication),
        );

        // Both should appear somewhere
        expect(accuracyHeaderFinder, findsAtLeastNWidgets(1));
        expect(commHeaderFinder, findsAtLeastNWidgets(1));

        // Communication (2 items) should appear before accuracy (1 item):
        // pick the top-most occurrence of each label for comparison.
        final commY = tester
            .widgetList<Text>(commHeaderFinder)
            .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
            .reduce((a, b) => a < b ? a : b);
        final accuracyY = tester
            .widgetList<Text>(accuracyHeaderFinder)
            .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
            .reduce((a, b) => a < b ? a : b);
        expect(commY, lessThan(accuracyY));
      });

      testWidgets('shows item detail text within expanded group',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              category: FeedbackCategory.tooling,
              source: 'observation',
              detail: 'Tool usage was inefficient',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // AnimatedCrossFade renders both children simultaneously
        expect(find.text('Tool usage was inefficient'), findsWidgets);
      });
    });

    group('category icons', () {
      testWidgets('accuracy category shows verified_outlined icon',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Accuracy feedback',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
      });

      testWidgets('communication category shows chat_outlined icon',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.communication,
              detail: 'Communication feedback',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chat_outlined), findsOneWidget);
      });

      testWidgets('prioritization category shows sort_outlined icon',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.prioritization,
              sentiment: FeedbackSentiment.neutral,
              source: 'metric',
              detail: 'Priority feedback',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.sort_outlined), findsOneWidget);
      });

      testWidgets('tooling category shows build_outlined icon', (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.tooling,
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Tool feedback',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      });

      testWidgets('timeliness category shows schedule_outlined icon',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.timeliness,
              sentiment: FeedbackSentiment.neutral,
              source: 'metric',
              detail: 'Timeliness feedback',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
      });

      testWidgets('general category shows info_outlined icon', (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.general,
              sentiment: FeedbackSentiment.neutral,
              source: 'observation',
              detail: 'General feedback',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.info_outlined), findsOneWidget);
      });
    });

    group('expand/collapse', () {
      testWidgets('category group starts expanded showing items',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Accuracy issue detail',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Expanded by default — tile visible; the group header shows expand_less.
        // The tile itself also shows expand_more (its own collapsed state).
        // So we see both. Check that the tile is present.
        expect(find.byType(FeedbackItemTile), findsOneWidget);
        // The group header expand_less should be present (size 18)
        final expandLessWidgets = tester
            .widgetList<Icon>(
              find.byIcon(Icons.expand_less),
            )
            .where((icon) => icon.size == 18)
            .toList();
        expect(expandLessWidgets, isNotEmpty);
      });

      testWidgets('tapping category header collapses items', (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Accuracy issue detail',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Tap the category icon to hit the GestureDetector header
        await tester.tap(find.byIcon(Icons.verified_outlined));
        await tester.pumpAndSettle();

        // After collapse, tile hidden
        expect(find.byType(FeedbackItemTile), findsNothing);
        // Group header now shows expand_more (size 18)
        final expandMoreWidgets = tester
            .widgetList<Icon>(
              find.byIcon(Icons.expand_more),
            )
            .where((icon) => icon.size == 18)
            .toList();
        expect(expandMoreWidgets, isNotEmpty);
      });

      testWidgets('tapping collapsed header re-expands items', (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.tooling,
              detail: 'Great tool usage',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Collapse via the category icon
        await tester.tap(find.byIcon(Icons.build_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(FeedbackItemTile), findsNothing);

        // Re-expand
        await tester.tap(find.byIcon(Icons.build_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(FeedbackItemTile), findsOneWidget);
        // AnimatedCrossFade renders both children simultaneously
        expect(find.text('Great tool usage'), findsWidgets);
      });

      testWidgets('collapsing one category does not collapse other categories',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Accuracy detail',
            ),
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.communication,
              detail: 'Communication detail',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Both groups are initially expanded
        expect(find.byType(FeedbackItemTile), findsNWidgets(2));

        // Collapse accuracy group by tapping its icon
        await tester.tap(find.byIcon(Icons.verified_outlined));
        await tester.pumpAndSettle();

        // Accuracy detail gone, communication detail still visible
        expect(find.text('Accuracy detail'), findsNothing);
        expect(find.text('Communication detail'), findsWidgets);
        // Only one tile remaining (communication)
        expect(find.byType(FeedbackItemTile), findsOneWidget);
      });
    });

    group('item count badge', () {
      testWidgets('shows correct count for category with multiple items',
          (tester) async {
        final feedback = makeTestClassifiedFeedback(
          items: [
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.prioritization,
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Priority issue 1',
            ),
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.prioritization,
              sentiment: FeedbackSentiment.negative,
              source: 'observation',
              detail: 'Priority issue 2',
            ),
            makeTestClassifiedFeedbackItem(
              category: FeedbackCategory.prioritization,
              sentiment: FeedbackSentiment.neutral,
              source: 'metric',
              detail: 'Priority observation',
            ),
          ],
        );

        await tester.pumpWidget(
          buildSubject(FeedbackCategoryBreakdown(feedback: feedback)),
        );
        await tester.pumpAndSettle();

        // Count badge shows 3
        expect(find.text('3'), findsOneWidget);
      });
    });
  });
}
