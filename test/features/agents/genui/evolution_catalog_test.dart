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

      expect(items, hasLength(4));
      expect(
          items.map((i) => i.name),
          containsAll([
            'EvolutionProposal',
            'EvolutionNoteConfirmation',
            'MetricsSummary',
            'VersionComparison',
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
            'directives': 'Be concise and helpful.',
            'rationale': 'Users prefer brevity.',
          }),
        ),
      );

      expect(find.text('Be concise and helpful.'), findsOneWidget);
      expect(find.text('Users prefer brevity.'), findsOneWidget);
    });

    testWidgets('renders current directives when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'directives': 'New directives',
            'rationale': 'Better performance',
            'currentDirectives': 'Old directives',
          }),
        ),
      );

      expect(find.text('New directives'), findsOneWidget);
      expect(find.text('Old directives'), findsOneWidget);
    });

    testWidgets('hides current directives section when empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          _buildCatalogWidget(evolutionProposalItem, {
            'directives': 'New directives',
            'rationale': 'Rationale text',
          }),
        ),
      );

      expect(find.text('New directives'), findsOneWidget);
      expect(find.text('Rationale text'), findsOneWidget);
      // Current directives section label should be absent.
      expect(find.text('Current Directives'), findsNothing);
    });

    testWidgets('dispatches proposal_approved on approve tap', (tester) async {
      final events = <UiEvent>[];

      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              final itemContext = CatalogItemContext(
                data: <String, Object?>{
                  'directives': 'Test directives',
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
                  'directives': 'Test directives',
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
}
