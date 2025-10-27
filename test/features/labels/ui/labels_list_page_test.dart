import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

Widget _buildPage({
  required List<LabelDefinition> labels,
  Map<String, int> usageCounts = const {},
}) {
  return ProviderScope(
    overrides: [
      labelsStreamProvider.overrideWith((ref) => Stream.value(labels)),
      labelUsageStatsProvider.overrideWith((ref) => Stream.value(usageCounts)),
    ],
    child: makeTestableWidgetWithScaffold(const LabelsListPage()),
  );
}

void main() {
  testWidgets('renders labels with usage stats', (tester) async {
    await tester.pumpWidget(
      _buildPage(
        labels: [testLabelDefinition1, testLabelDefinition2],
        usageCounts: {'label-1': 3, 'label-2': 1},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Urgent'), findsWidgets);
    expect(find.text('Backlog'), findsWidgets);
    expect(find.textContaining('Used on 3 tasks'), findsOneWidget);
    expect(find.textContaining('Used on 1 task'), findsOneWidget);
  });

  testWidgets('filters list based on search query', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField, skipOffstage: false).first,
      'backlog',
    );
    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsWidgets);
    expect(find.text('Urgent'), findsNothing);
  });

  testWidgets('search filters labels case-insensitively', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField, skipOffstage: false).first,
      'BACK',
    );
    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsWidgets);
    expect(find.text('Urgent'), findsNothing);
  });

  testWidgets('empty state shows when no labels exist', (tester) async {
    await tester.pumpWidget(_buildPage(labels: const []));
    await tester.pumpAndSettle();

    expect(find.text('No labels yet'), findsOneWidget);
  });

  testWidgets('error state displays error message and details', (tester) async {
    final widget = ProviderScope(
      overrides: [
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.error('boom'),
        ),
      ],
      child: makeTestableWidgetWithScaffold(const LabelsListPage()),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Failed to load labels'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('popup menu shows edit and delete options', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('delete confirmation shows label name and cancel keeps list',
      (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Urgent'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Label still visible after cancel
    expect(find.text('Urgent'), findsWidgets);
  });

  testWidgets('private badge renders for private labels', (tester) async {
    final privateLabel = testLabelDefinition1.copyWith(private: true);
    await tester.pumpWidget(
      _buildPage(labels: [privateLabel]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Private'), findsOneWidget);
  });

  // Note: FAB behavior is covered by dedicated editor sheet tests; here we
  // verify presence and focus coverage via other interactions.

  testWidgets('shows create-from-search CTA and opens editor prefilled',
      (tester) async {
    // Provide a mock repository to satisfy LabelEditorSheet dependencies.
    final mockRepo = _MockLabelsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labelsRepositoryProvider.overrideWithValue(mockRepo),
          labelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              testLabelDefinition1,
              testLabelDefinition2,
            ]),
          ),
          labelUsageStatsProvider.overrideWith(
            (ref) => Stream.value(const <String, int>{}),
          ),
        ],
        child: makeTestableWidgetWithScaffold(const LabelsListPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Enter a query that matches no existing label
    const query = 'NewLabelX';
    await tester.enterText(
      find.byType(TextField, skipOffstage: false).first,
      query,
    );
    await tester.pumpAndSettle();

    // CTA should reflect the exact typed casing
    expect(find.text('Create "$query" label'), findsOneWidget);

    // Tap to open the label editor, which should be prefilled with the query
    await tester.tap(find.text('Create "$query" label'));
    await tester.pumpAndSettle();

    expect(find.byType(LabelEditorSheet), findsOneWidget);
    expect(find.text(query), findsWidgets);
  });

  testWidgets('settings search field capitalizes words', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
    );
    await tester.pumpAndSettle();

    final searchFieldFinder = find.byType(TextField, skipOffstage: false).first;
    final tf = tester.widget<TextField>(searchFieldFinder);
    expect(tf.textCapitalization, TextCapitalization.words);
  });
}

class _MockLabelsRepository extends Mock implements LabelsRepository {}
