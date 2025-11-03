import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:mocktail/mocktail.dart';
import '../../../mocks/mocks.dart';

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
  setUp(() {
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      final mock = MockEntitiesCacheService();
      // No categories needed for this suite; return empty list
      when(() => mock.sortedCategories)
          .thenReturn(const <CategoryDefinition>[]);
      getIt.registerSingleton<EntitiesCacheService>(mock);
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<EntitiesCacheService>()) {
      await getIt.reset(dispose: false);
    }
  });
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

  testWidgets('list item uses chevron and no popup menu', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1]),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_right), findsWidgets);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  // Deletion now happens in the details page; list does not show a popup menu anymore.

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

  testWidgets('shows create-from-search CTA with typed query', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    // We navigate to a new page in the app; here we only assert the CTA exists.
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

  testWidgets('renders applicable category chips under label when present',
      (tester) async {
    // Arrange categories and mock cache lookups
    final catWork = CategoryDefinition(
      id: 'cat-work',
      name: 'Work',
      color: '#00AA00',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      private: false,
      active: true,
    );
    final catPersonal = CategoryDefinition(
      id: 'cat-personal',
      name: 'Personal',
      color: '#AA00AA',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      private: false,
      active: true,
    );

    // The setUp() registered a mock cache; enrich it for this test
    final cache = getIt<EntitiesCacheService>();
    when(() => cache.sortedCategories).thenReturn([catWork, catPersonal]);
    when(() => cache.getCategoryById('cat-work')).thenReturn(catWork);
    when(() => cache.getCategoryById('cat-personal')).thenReturn(catPersonal);

    final scopedLabel = testLabelDefinition1.copyWith(
      applicableCategoryIds: ['cat-work', 'cat-personal'],
    );

    // Act
    await tester.pumpWidget(_buildPage(labels: [scopedLabel]));
    await tester.pumpAndSettle();

    // Assert: category chips show by name
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Personal'), findsWidgets);
  });

  testWidgets('category chips use category color and contrast-aware text',
      (tester) async {
    // Use one light and one dark color to test foreground selection.
    final catLight = CategoryDefinition(
      id: 'cat-light',
      name: 'Bright',
      color: '#F9F871', // light yellow
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      private: false,
      active: true,
    );
    final catDark = CategoryDefinition(
      id: 'cat-dark',
      name: 'Deep',
      color: '#3D0066', // dark purple
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      private: false,
      active: true,
    );

    final cache = getIt<EntitiesCacheService>();
    when(() => cache.sortedCategories).thenReturn([catLight, catDark]);
    when(() => cache.getCategoryById('cat-light')).thenReturn(catLight);
    when(() => cache.getCategoryById('cat-dark')).thenReturn(catDark);

    final scopedLabel = testLabelDefinition1.copyWith(
      applicableCategoryIds: ['cat-light', 'cat-dark'],
    );

    await tester.pumpWidget(_buildPage(labels: [scopedLabel]));
    await tester.pumpAndSettle();

    final lightChip = tester.widget<Chip>(find.widgetWithText(Chip, 'Bright'));
    final darkChip = tester.widget<Chip>(find.widgetWithText(Chip, 'Deep'));

    // Background equals category color
    expect(lightChip.backgroundColor, colorFromCssHex(catLight.color));
    expect(darkChip.backgroundColor, colorFromCssHex(catDark.color));

    // Foreground contrast: get Text style inside each Chip
    final lightText = tester.widget<Text>(find.descendant(
        of: find.widgetWithText(Chip, 'Bright'),
        matching: find.text('Bright')));
    final darkText = tester.widget<Text>(find.descendant(
        of: find.widgetWithText(Chip, 'Deep'), matching: find.text('Deep')));
    expect(lightText.style?.color, Colors.black);
    expect(darkText.style?.color, Colors.white);
  });
}

// No longer needed in this suite.
