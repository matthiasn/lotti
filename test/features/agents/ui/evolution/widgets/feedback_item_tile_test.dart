import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_item_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

import '../../../../../widget_test_utils.dart';
import '../../../test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject(FeedbackItemTile tile) {
    return makeTestableWidgetWithScaffold(tile);
  }

  group('FeedbackItemTile', () {
    group('detail text', () {
      testWidgets('renders detail text in collapsed state', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          detail: 'Wrong priority assignment to task',
          sentiment: FeedbackSentiment.negative,
          source: 'observation',
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        // AnimatedCrossFade renders both children simultaneously;
        // at least one widget with this text should be present.
        expect(
          find.text('Wrong priority assignment to task'),
          findsWidgets,
        );
      });

      testWidgets('detail text remains visible after expand', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          detail: 'Agent communicated clearly and promptly',
          category: FeedbackCategory.communication,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        // Tap the expand icon to trigger expand
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('Agent communicated clearly and promptly'),
          findsWidgets,
        );
      });
    });

    group('source label', () {
      testWidgets('shows localized "Observation" label for observation source',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          source: 'observation',
          sentiment: FeedbackSentiment.negative,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackSourceObservation),
          findsOneWidget,
        );
      });

      testWidgets('shows localized "Decision" label for decision source',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          category: FeedbackCategory.prioritization,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackSourceDecision),
          findsOneWidget,
        );
      });

      testWidgets('shows localized "Metric" label for metric source',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          source: 'metric',
          sentiment: FeedbackSentiment.neutral,
          category: FeedbackCategory.timeliness,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackSourceMetric),
          findsOneWidget,
        );
      });

      testWidgets('shows localized "Rating" label for rating source',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          source: 'rating',
          category: FeedbackCategory.general,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackSourceRating),
          findsOneWidget,
        );
      });

      testWidgets('shows raw source string for unknown source', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          source: 'custom_source',
          sentiment: FeedbackSentiment.neutral,
          category: FeedbackCategory.general,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        expect(find.text('custom_source'), findsOneWidget);
      });
    });

    group('category badge', () {
      testWidgets('renders localized accuracy category badge', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          sentiment: FeedbackSentiment.negative,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackCategoryAccuracy),
          findsOneWidget,
        );
      });

      testWidgets('renders localized communication category badge',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          category: FeedbackCategory.communication,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackCategoryCommunication),
          findsOneWidget,
        );
      });

      testWidgets('renders localized prioritization category badge',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          category: FeedbackCategory.prioritization,
          sentiment: FeedbackSentiment.neutral,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackCategoryPrioritization),
          findsOneWidget,
        );
      });

      testWidgets('renders localized tooling category badge', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          category: FeedbackCategory.tooling,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackCategoryTooling),
          findsOneWidget,
        );
      });

      testWidgets('renders localized timeliness category badge',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          category: FeedbackCategory.timeliness,
          sentiment: FeedbackSentiment.neutral,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackCategoryTimeliness),
          findsOneWidget,
        );
      });

      testWidgets('renders localized general category badge', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          category: FeedbackCategory.general,
          sentiment: FeedbackSentiment.neutral,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(FeedbackItemTile));
        expect(
          find.text(context.messages.agentFeedbackCategoryGeneral),
          findsOneWidget,
        );
      });
    });

    group('sentiment color strip', () {
      testWidgets('negative item uses primaryRed color strip', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          sentiment: FeedbackSentiment.negative,
          source: 'observation',
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final colorStrip =
            tester.widgetList<Container>(find.byType(Container)).firstWhere(
                  (c) =>
                      c.decoration is BoxDecoration &&
                      (c.decoration! as BoxDecoration).color ==
                          GameyColors.primaryRed,
                  orElse: () => throw TestFailure(
                    'No Container with primaryRed color found',
                  ),
                );
        expect(colorStrip, isNotNull);
      });

      testWidgets('positive item uses primaryGreen color strip',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem();

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final colorStrip =
            tester.widgetList<Container>(find.byType(Container)).firstWhere(
                  (c) =>
                      c.decoration is BoxDecoration &&
                      (c.decoration! as BoxDecoration).color ==
                          GameyColors.primaryGreen,
                  orElse: () => throw TestFailure(
                    'No Container with primaryGreen color found',
                  ),
                );
        expect(colorStrip, isNotNull);
      });

      testWidgets('neutral item uses primaryOrange color strip',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          sentiment: FeedbackSentiment.neutral,
          category: FeedbackCategory.general,
          source: 'metric',
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        final colorStrip =
            tester.widgetList<Container>(find.byType(Container)).firstWhere(
                  (c) =>
                      c.decoration is BoxDecoration &&
                      (c.decoration! as BoxDecoration).color ==
                          GameyColors.primaryOrange,
                  orElse: () => throw TestFailure(
                    'No Container with primaryOrange color found',
                  ),
                );
        expect(colorStrip, isNotNull);
      });
    });

    group('expand/collapse', () {
      testWidgets('starts collapsed showing expand_more icon', (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          detail: 'Feedback detail text',
          sentiment: FeedbackSentiment.negative,
          source: 'observation',
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsNothing);
      });

      testWidgets('tapping the expand icon toggles to expand_less icon',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          detail: 'Feedback detail text',
          sentiment: FeedbackSentiment.negative,
          source: 'observation',
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        // Tile starts collapsed — tap the expand_more icon to expand
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsNothing);
      });

      testWidgets('tapping expand icon twice returns to collapsed state',
          (tester) async {
        final item = makeTestClassifiedFeedbackItem(
          detail: 'Feedback detail text',
          category: FeedbackCategory.communication,
        );

        await tester.pumpWidget(
          buildSubject(FeedbackItemTile(item: item)),
        );
        await tester.pumpAndSettle();

        // First tap: expand via expand_more icon
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        // Second tap: collapse via expand_less icon
        await tester.tap(find.byIcon(Icons.expand_less));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });
    });
  });
}
