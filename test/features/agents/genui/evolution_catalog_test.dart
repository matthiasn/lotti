import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/genui/evolution_catalog.dart';

import '../../../widget_test_utils.dart';

/// Builds a widget for a [CatalogItem] with the given [data], wrapped in
/// a testable material app for pumping.
Widget _buildCatalogWidget(CatalogItem item, Map<String, Object?> data) {
  return Builder(
    builder: (context) {
      final itemContext = CatalogItemContext(
        data: data,
        id: 'test-component',
        buildChild: (id, [dataContext]) => const SizedBox.shrink(),
        dispatchEvent: (_) {},
        buildContext: context,
        dataContext: DataContext(DataModel(), '/'),
        getComponent: (_) => null,
        surfaceId: 'test-surface',
      );
      return item.widgetBuilder(itemContext);
    },
  );
}

void main() {
  group('buildEvolutionCatalog', () {
    test('contains all four catalog items', () {
      final catalog = buildEvolutionCatalog();
      final items = catalog.items;

      expect(items, hasLength(7));
      expect(
          items.map((i) => i.name),
          containsAll([
            'EvolutionProposal',
            'EvolutionNoteConfirmation',
            'MetricsSummary',
            'VersionComparison',
            'FeedbackClassification',
            'FeedbackCategoryBreakdown',
            'SessionProgress',
          ]));
    });

    test('has the correct catalog ID', () {
      final catalog = buildEvolutionCatalog();
      expect(catalog.catalogId, evolutionCatalogId);
    });
  });

  group('EvolutionProposal', () {
    testWidgets('renders proposal with directives and rationale',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'Be concise and helpful.',
            'reportDirective': 'Use bullet points.',
            'rationale': 'Users prefer brevity.',
          }),
        ),
      );

      expect(find.text('Be concise and helpful.'), findsOneWidget);
      expect(find.text('Use bullet points.'), findsOneWidget);
      expect(find.text('Users prefer brevity.'), findsOneWidget);
    });

    testWidgets('renders only general directive when report is empty',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'New general directive',
            'reportDirective': '',
            'rationale': 'Better performance',
          }),
        ),
      );

      expect(find.text('New general directive'), findsOneWidget);
      expect(find.text('Better performance'), findsOneWidget);
      // Report directive section should be absent when empty.
      expect(
        find.textContaining('Report Directive'),
        findsNothing,
      );
    });

    testWidgets('hides directive sections when empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': '',
            'reportDirective': '',
            'rationale': 'Rationale text',
          }),
        ),
      );

      expect(find.text('Rationale text'), findsOneWidget);
      // Both directive sections should be absent when empty.
      expect(
        find.textContaining('General Directive'),
        findsNothing,
      );
      expect(
        find.textContaining('Report Directive'),
        findsNothing,
      );
    });

    testWidgets('renders current general and report directives when provided',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'New general approach.',
            'reportDirective': 'New report format.',
            'rationale': 'Improvement rationale.',
            'currentGeneralDirective': 'Old general approach.',
            'currentReportDirective': 'Old report format.',
          }),
        ),
      );

      // Current directive sections should be present.
      expect(
        find.textContaining('Current Directives'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('General Directive'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('Report Directive'),
        findsNWidgets(2),
      );
      expect(find.text('Old general approach.'), findsOneWidget);
      expect(find.text('Old report format.'), findsOneWidget);
      // Proposed directives should also be present.
      expect(find.text('New general approach.'), findsOneWidget);
      expect(find.text('New report format.'), findsOneWidget);
    });

    testWidgets('renders only current report directive when general is empty',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': 'New general.',
            'reportDirective': '',
            'rationale': 'Rationale.',
            'currentGeneralDirective': '',
            'currentReportDirective': 'Old report only.',
          }),
        ),
      );

      // Only the report current directive should appear.
      expect(find.text('Old report only.'), findsOneWidget);
      expect(
        find.textContaining('Current Directives'),
        findsOneWidget,
      );
    });

    testWidgets('renders only report proposed directive when general is empty',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'generalDirective': '',
            'reportDirective': 'New report directive only.',
            'rationale': 'Report-focused rationale.',
          }),
        ),
      );

      expect(find.text('New report directive only.'), findsOneWidget);
      expect(find.text('Report-focused rationale.'), findsOneWidget);
      // General directive section should be absent.
      expect(
        find.textContaining('General Directive'),
        findsNothing,
      );
      // Proposed Report Directive section should be present.
      expect(
        find.textContaining('Proposed Directives'),
        findsOneWidget,
      );
    });

    testWidgets('dispatches proposal_approved on approve tap', (tester) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final itemContext = CatalogItemContext(
                data: <String, Object?>{
                  'generalDirective': 'Test general directive',
                  'reportDirective': 'Test report directive',
                  'rationale': 'Test rationale',
                },
                id: 'test-component',
                buildChild: (id, [dataContext]) => const SizedBox.shrink(),
                dispatchEvent: events.add,
                buildContext: context,
                dataContext: DataContext(DataModel(), '/'),
                getComponent: (_) => null,
                surfaceId: 'test-surface',
              );
              return evolutionProposalItem.widgetBuilder(itemContext);
            },
          ),
        ),
      );

      // The approve button wraps its text in an InkWell.
      await tester.tap(
        find.ancestor(
          of: find.text('Approve & Save'),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pump();

      expect(events, hasLength(1));
      final event = events.first as UserActionEvent;
      expect(event.name, 'proposal_approved');
    });

    testWidgets('dispatches proposal_rejected on reject tap', (tester) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final itemContext = CatalogItemContext(
                data: <String, Object?>{
                  'generalDirective': 'Test general directive',
                  'reportDirective': 'Test report directive',
                  'rationale': 'Test rationale',
                },
                id: 'test-component',
                buildChild: (id, [dataContext]) => const SizedBox.shrink(),
                dispatchEvent: events.add,
                buildContext: context,
                dataContext: DataContext(DataModel(), '/'),
                getComponent: (_) => null,
                surfaceId: 'test-surface',
              );
              return evolutionProposalItem.widgetBuilder(itemContext);
            },
          ),
        ),
      );

      // The reject button is an OutlinedButton
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(events, hasLength(1));
      final event = events.first as UserActionEvent;
      expect(event.name, 'proposal_rejected');
    });
  });

  group('EvolutionNoteConfirmation', () {
    testWidgets('renders note kind icon and content', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
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
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
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
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
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
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
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
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'unknown_kind',
            'content': 'Some content.',
          }),
        ),
      );

      expect(find.byIcon(Icons.note), findsOneWidget);
    });

    testWidgets('starts collapsed and shows expand_more icon', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content': 'A long note that spans multiple lines to test '
                'the expand/collapse behavior of the card widget.',
          }),
        ),
      );

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // The collapsed text should have maxLines: 2
      final collapsedText = tester.widgetList<Text>(find.byType(Text)).where(
            (t) => t.maxLines == 2,
          );
      expect(collapsedText, isNotEmpty);
    });

    testWidgets('expands on tap and shows expand_less icon', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content': 'A long note that spans multiple lines to test '
                'the expand/collapse behavior of the card widget.',
          }),
        ),
      );

      // Tap to expand
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('collapses again on second tap', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionNoteConfirmationItem, {
            'kind': 'reflection',
            'content': 'A long note content.',
          }),
        ),
      );

      // Tap to expand
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });
  });

  group('MetricsSummary', () {
    testWidgets('renders required metrics', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(metricsSummaryItem, {
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
          _buildCatalogWidget(metricsSummaryItem, {
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
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('hides optional metrics when absent', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(metricsSummaryItem, {
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
          _buildCatalogWidget(versionComparisonItem, {
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
          _buildCatalogWidget(versionComparisonItem, {
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
          _buildCatalogWidget(versionComparisonItem, {
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
          _buildCatalogWidget(versionComparisonItem, {
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

  group('FeedbackClassification', () {
    testWidgets('renders analytics icon and sentiment chips', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackClassificationItem, {
            'items': <Map<String, Object?>>[],
            'positiveCount': 3,
            'negativeCount': 2,
            'neutralCount': 1,
          }),
        ),
      );

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('1'), findsWidgets);
    });

    testWidgets('renders up to 5 feedback lines', (tester) async {
      final items = List.generate(
        5,
        (i) => <String, Object?>{
          'sentiment': 'positive',
          'category': 'general',
          'source': 'session',
          'detail': 'Feedback detail $i',
        },
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackClassificationItem, {
            'items': items,
            'positiveCount': 5,
            'negativeCount': 0,
            'neutralCount': 0,
          }),
        ),
      );

      for (var i = 0; i < 5; i++) {
        expect(find.text('Feedback detail $i'), findsOneWidget);
      }
    });

    testWidgets('shows more text when items exceed 5', (tester) async {
      final items = List.generate(
        8,
        (i) => <String, Object?>{
          'sentiment': 'negative',
          'category': 'accuracy',
          'source': 'session',
          'detail': 'Detail $i',
        },
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackClassificationItem, {
            'items': items,
            'positiveCount': 0,
            'negativeCount': 8,
            'neutralCount': 0,
          }),
        ),
      );

      // First 5 details shown, remainder indicated by "more" text.
      expect(find.text('Detail 0'), findsOneWidget);
      expect(find.text('Detail 4'), findsOneWidget);
      // The "3 items" text reflects items.length - 5 = 3.
      expect(find.text('3 items'), findsOneWidget);
      // Detail 5 onwards should not be visible.
      expect(find.text('Detail 5'), findsNothing);
    });

    testWidgets('hides sentiment chips with zero count', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackClassificationItem, {
            'items': <Map<String, Object?>>[],
            'positiveCount': 0,
            'negativeCount': 0,
            'neutralCount': 0,
          }),
        ),
      );

      expect(find.text('Positive Signals'), findsNothing);
      expect(find.text('Negative Signals'), findsNothing);
      expect(find.text('Neutral Signals'), findsNothing);
    });

    testWidgets('renders with empty items list', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackClassificationItem, {
            'items': <Map<String, Object?>>[],
            'positiveCount': 1,
            'negativeCount': 0,
            'neutralCount': 0,
          }),
        ),
      );

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
    });
  });

  group('FeedbackCategoryBreakdown', () {
    testWidgets('renders category icon and title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[
              {
                'name': 'accuracy',
                'count': 5,
                'positiveCount': 3,
                'negativeCount': 2,
              },
            ],
          }),
        ),
      );

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('accuracy'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders proportion bars for multiple categories',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[
              {'name': 'accuracy', 'count': 4, 'positiveCount': 2},
              {'name': 'communication', 'count': 6, 'negativeCount': 1},
            ],
          }),
        ),
      );

      expect(find.text('accuracy'), findsOneWidget);
      expect(find.text('communication'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('renders with empty categories list', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[],
          }),
        ),
      );

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    });

    testWidgets('renders categories without optional positive/negative counts',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(feedbackCategoryBreakdownItem, {
            'categories': <Map<String, Object?>>[
              {'name': 'tooling', 'count': 3},
            ],
          }),
        ),
      );

      expect(find.text('tooling'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('SessionProgress', () {
    testWidgets('renders loop icon, title, and session info', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 3,
            'totalSessions': 10,
            'feedbackCount': 7,
            'status': 'active',
          }),
        ),
      );

      expect(find.byIcon(Icons.loop), findsOneWidget);
      expect(find.text('Session 3 of 10'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders positive and negative metric chips when non-zero',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 1,
            'totalSessions': 5,
            'feedbackCount': 4,
            'positiveCount': 3,
            'negativeCount': 1,
            'status': 'completed',
          }),
        ),
      );

      expect(find.text('3'), findsWidgets);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('hides positive and negative chips when zero', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 2,
            'totalSessions': 8,
            'feedbackCount': 0,
            'positiveCount': 0,
            'negativeCount': 0,
            'status': 'active',
          }),
        ),
      );

      expect(find.text('+'), findsNothing);
      expect(find.text('-'), findsNothing);
    });

    testWidgets('renders completed status', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 5,
            'totalSessions': 5,
            'feedbackCount': 10,
            'status': 'completed',
          }),
        ),
      );

      expect(find.text('Session 5 of 5'), findsOneWidget);
    });

    testWidgets('renders abandoned status', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(sessionProgressItem, {
            'sessionNumber': 2,
            'totalSessions': 5,
            'feedbackCount': 3,
            'status': 'abandoned',
          }),
        ),
      );

      expect(find.text('Session 2 of 5'), findsOneWidget);
    });
  });
}
