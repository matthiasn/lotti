import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';

import '../../../widget_test_utils.dart';
import 'evolution_catalog_test_helpers.dart';

void main() {
  group('EvolutionNoteConfirmation', () {
    testWidgets('renders note kind icon and content', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content': 'Users prefer short reports.',
          }),
        ),
      );

      // AnimatedCrossFade renders both children, so we expect 2 Text widgets.
      expect(find.text('Users prefer short reports.'), findsNWidgets(2));
      expect(find.byIcon(Icons.psychology), findsOneWidget);
    });

    testWidgets('renders hypothesis icon correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'hypothesis',
            'content': 'Test hypothesis.',
          }),
        ),
      );

      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    });

    testWidgets('renders decision icon correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'decision',
            'content': 'A decision was made.',
          }),
        ),
      );

      expect(find.byIcon(Icons.gavel), findsOneWidget);
    });

    testWidgets('renders pattern icon correctly', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'pattern',
            'content': 'A pattern was found.',
          }),
        ),
      );

      expect(find.byIcon(Icons.pattern), findsOneWidget);
    });

    testWidgets('renders fallback icon for unknown kind', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'unknown_kind',
            'content': 'Some content.',
          }),
        ),
      );

      expect(find.byIcon(Icons.note), findsOneWidget);
    });

    testWidgets('starts collapsed and shows chevron_right icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content':
                'A long note that spans multiple lines to test '
                'the expand/collapse behavior of the card widget.',
          }),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      // The collapsed text should have maxLines: 2
      final collapsedText = tester
          .widgetList<Text>(find.byType(Text))
          .where(
            (t) => t.maxLines == 2,
          );
      expect(collapsedText, isNotEmpty);
    });

    testWidgets('expands on tap and shows keyboard_arrow_down icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content':
                'A long note that spans multiple lines to test '
                'the expand/collapse behavior of the card widget.',
          }),
        ),
      );

      // Tap to expand. The chevron icon flips immediately via setState; the
      // 200ms AnimatedCrossFade is settled by a single bounded pump.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('collapses again on second tap', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content': 'A long note content.',
          }),
        ),
      );

      // Tap to expand (bounded pump settles the 200ms cross-fade).
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Tap again to collapse.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('MetricsSummary', () {
    testWidgets('renders required metrics', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(metricsSummaryItem, {
            'totalWakes': 42,
            'successRate': 0.85,
            'failureCount': 3,
          }),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders optional metrics when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(metricsSummaryItem, {
            'totalWakes': 10,
            'successRate': 1.0,
            'failureCount': 0,
            'averageDurationSeconds': 12.5,
            'activeInstances': 3,
          }),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('13s'), findsOneWidget);
      // Only the activeInstances chip renders the literal '3' value.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides optional metrics when absent', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(metricsSummaryItem, {
            'totalWakes': 5,
            'successRate': 0.6,
            'failureCount': 2,
          }),
        ),
      );

      // Only 3 metric chips should be present (no avgDuration or active)
      expect(find.text('5'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // Optional metric labels should be absent.
      expect(find.text('Avg Duration'), findsNothing);
      expect(find.text('Active'), findsNothing);
    });
  });

  group('VersionComparison', () {
    testWidgets('renders version comparison with directives', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(versionComparisonItem, {
            'beforeVersion': 1,
            'afterVersion': 2,
            'beforeDirectives': 'Old approach',
            'afterDirectives': 'New approach',
          }),
        ),
      );

      expect(find.text('v1 → v2'), findsOneWidget);
      expect(find.text('Old approach'), findsOneWidget);
      expect(find.text('New approach'), findsOneWidget);
    });

    testWidgets('renders changes summary when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(versionComparisonItem, {
            'beforeVersion': 3,
            'afterVersion': 4,
            'beforeDirectives': 'Before text',
            'afterDirectives': 'After text',
            'changesSummary': 'Improved error handling.',
          }),
        ),
      );

      expect(find.text('Improved error handling.'), findsOneWidget);
    });

    testWidgets('hides changes summary when absent', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(versionComparisonItem, {
            'beforeVersion': 1,
            'afterVersion': 2,
            'beforeDirectives': 'Before',
            'afterDirectives': 'After',
          }),
        ),
      );

      expect(find.text('v1 → v2'), findsOneWidget);
      // No FontStyle.italic text (changesSummary) should be present.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.style?.fontStyle == FontStyle.italic,
        ),
        findsNothing,
      );
    });

    testWidgets('renders compare_arrows icon', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          buildCatalogWidget(versionComparisonItem, {
            'beforeVersion': 1,
            'afterVersion': 2,
            'beforeDirectives': 'A',
            'afterDirectives': 'B',
          }),
        ),
      );

      expect(find.byIcon(Icons.compare_arrows), findsOneWidget);
    });
  });
}
