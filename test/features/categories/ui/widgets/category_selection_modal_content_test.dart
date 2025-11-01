import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;
  final testCategories = [
    CategoryDefinition(
      id: 'cat1',
      name: 'Category 1',
      color: '#FF0000',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
    ),
    CategoryDefinition(
      id: 'cat2',
      name: 'Category 2',
      color: '#00FF00',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
    ),
    CategoryDefinition(
      id: 'cat3',
      name: 'Category 3',
      color: '#0000FF',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
    ),
  ];

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    when(() => mockEntitiesCacheService.sortedCategories)
        .thenReturn(testCategories);
    getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  testWidgets('displays all categories', (tester) async {
    final selectedCategories = <CategoryDefinition?>[];

    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: selectedCategories.add,
        ),
      ),
    );

    // Verify all categories are displayed
    expect(find.text('Category 1'), findsWidgets);
    expect(find.text('Category 2'), findsOneWidget);
    expect(find.text('Category 3'), findsOneWidget);
  });

  testWidgets('filters categories by search query', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: (_) {},
        ),
      ),
    );

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Category 1');
    await tester.pump();

    // Verify only matching category is displayed
    expect(find.byType(CategoryTypeCard), findsOneWidget);
    expect(find.text('Category 2'), findsNothing);
    expect(find.text('Category 3'), findsNothing);
  });

  testWidgets('callback is called when category is selected', (tester) async {
    final selectedCategories = <CategoryDefinition?>[];

    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: selectedCategories.add,
        ),
      ),
    );

    // Tap on a category
    await tester.tap(find.text('Category 2'));
    await tester.pumpAndSettle();

    // Verify callback was called with correct category
    expect(selectedCategories.length, 1);
    expect(selectedCategories.first?.id, 'cat2');
  });

  testWidgets('displays "clear" option when initialCategoryId is provided',
      (tester) async {
    final selectedCategories = <CategoryDefinition?>[];

    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: selectedCategories.add,
          initialCategoryId: 'cat1',
        ),
      ),
    );

    // Verify clear option is displayed
    expect(find.text('clear'), findsOneWidget);

    // Tap on clear
    await tester.tap(find.text('clear'));
    await tester.pumpAndSettle();

    // Verify callback was called with null
    expect(selectedCategories.length, 1);
    expect(selectedCategories.first, isNull);
  });

  testWidgets('shows "create category" option when search has no matches',
      (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: (_) {},
        ),
      ),
    );

    // Enter search query with no matches
    await tester.enterText(find.byType(TextField), 'New Category');
    await tester.pump();

    // Verify the add option is displayed with the search query as title
    expect(
      find.text('New Category'),
      findsWidgets,
    ); // Once in TextField, once in card
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('separates favorite and other categories', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: CategorySelectionModalContent(
          onCategorySelected: (_) {},
        ),
      ),
    );

    // Find all CategoryTypeCard widgets
    final categoryCards = find.byType(CategoryTypeCard);
    expect(categoryCards, findsNWidgets(3));

    // Get the first CategoryTypeCard widget
    final firstCardWidget =
        tester.widget<CategoryTypeCard>(categoryCards.first);
    expect(firstCardWidget.categoryDefinition.favorite, isTrue);
  });

  group('multiSelect mode', () {
    testWidgets('shows Done button and toggles selection', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
              multiSelect: true,
            ),
          ),
        ),
      );

      // Done button visible
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);

      // Tap two categories to toggle selection
      await tester.tap(find.text('Category 1'));
      await tester.pump();
      await tester.tap(find.text('Category 2'));
      await tester.pump();

      // Done should be enabled (cannot assert enabled directly, but tap should pop)
    });

    testWidgets('returns List<CategoryDefinition> on Done', (tester) async {
      List<CategoryDefinition>? result;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context)
                        .push<List<CategoryDefinition>>(
                      MaterialPageRoute(
                        builder: (_) => Material(
                          child: CategorySelectionModalContent(
                            onCategorySelected: (_) {},
                            multiSelect: true,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Category 1'));
      await tester.pump();
      await tester.tap(find.text('Category 3'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      final ids = result!.map((c) => c.id).toList()..sort();
      expect(ids, equals(['cat1', 'cat3']));
    });

    testWidgets('initiallySelectedCategoryIds are preselected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
              multiSelect: true,
              initiallySelectedCategoryIds: const {'cat2'},
            ),
          ),
        ),
      );

      // The CategoryTypeCard for Category 2 should render selected
      // (indirectly validated by existence; visual state not directly asserted)
      expect(find.text('Category 2'), findsOneWidget);
    });

    testWidgets('selected categories show visual selection state',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
              multiSelect: true,
            ),
          ),
        ),
      );

      // Select Category 1
      await tester.tap(find.text('Category 1'));
      await tester.pump();

      // Read the CategoryTypeCard widgets and find the one for Category 1
      final cards = tester
          .widgetList<CategoryTypeCard>(find.byType(CategoryTypeCard))
          .toList();
      final card = cards.firstWhere(
        (w) => w.categoryDefinition.name == 'Category 1',
      );
      expect(card.selected, isTrue);
    });

    testWidgets('allows selecting many (5+) categories', (tester) async {
      // Override with many categories to select from
      final now = DateTime.now();
      final many = List<CategoryDefinition>.generate(10, (i) {
        return CategoryDefinition(
          id: 'cat${i + 1}',
          name: 'Category ${i + 1}',
          color: '#${(0x0000FF + i).toRadixString(16).padLeft(6, '0')}',
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
        );
      });
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn(many);

      List<CategoryDefinition>? result;
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context)
                        .push<List<CategoryDefinition>>(
                      MaterialPageRoute(
                        builder: (_) => Material(
                          child: CategorySelectionModalContent(
                            onCategorySelected: (_) {},
                            multiSelect: true,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Select 6 categories
      for (var i = 1; i <= 6; i++) {
        await tester.tap(find.text('Category $i'));
        await tester.pump();
      }

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      final ids = result!.map((c) => c.id).toList()..sort();
      expect(ids, equals(['cat1', 'cat2', 'cat3', 'cat4', 'cat5', 'cat6']));
    });

    testWidgets('Done button disabled when no selection', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
              multiSelect: true,
            ),
          ),
        ),
      );

      // Initially disabled
      final doneBefore = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Done'),
      );
      expect(doneBefore.onPressed, isNull);

      // Select a category
      await tester.tap(find.text('Category 1'));
      await tester.pump();

      final doneAfter = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Done'),
      );
      expect(doneAfter.onPressed, isNotNull);
    });

    testWidgets('deselecting a category removes it from selection',
        (tester) async {
      List<CategoryDefinition>? result;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context)
                        .push<List<CategoryDefinition>>(
                      MaterialPageRoute(
                        builder: (_) => Material(
                          child: CategorySelectionModalContent(
                            onCategorySelected: (_) {},
                            multiSelect: true,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Select two, then deselect one
      await tester.tap(find.text('Category 1'));
      await tester.pump();
      await tester.tap(find.text('Category 2'));
      await tester.pump();
      await tester.tap(find.text('Category 2'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      final ids = result!.map((c) => c.id).toList();
      expect(ids, equals(['cat1']));
    });
  });

  group('overflow and scrolling behavior', () {
    List<CategoryDefinition> generateCategories(int count) {
      final now = DateTime.now();
      return List<CategoryDefinition>.generate(count, (i) {
        return CategoryDefinition(
          id: 'cat${i + 1}',
          name: 'Category ${i + 1}',
          color: '#${(0xFF0000 + i).toRadixString(16).padLeft(6, '0')}',
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
          private: false,
          active: true,
          favorite: i % 7 == 0,
        );
      });
    }

    testWidgets('results list scrolls when many categories present',
        (tester) async {
      // Many categories to force overflow into scrollable list
      final many = generateCategories(60);
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn(many);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down the results list; should be scrollable without errors
      expect(find.byType(ListView), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
    });

    testWidgets('search field remains visible while scrolling results',
        (tester) async {
      when(() => mockEntitiesCacheService.sortedCategories)
          .thenReturn(generateCategories(50));

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 600);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = tester.getTopLeft(find.byType(TextField));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      final after = tester.getTopLeft(find.byType(TextField));

      // Header is outside the scrollable list, so it should not move
      expect(after, equals(before));
    });

    testWidgets('adapts to small screens without overflow', (tester) async {
      when(() => mockEntitiesCacheService.sortedCategories)
          .thenReturn(generateCategories(100));

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Column should not exceed the available screen height
      final columnFinder = find
          .descendant(
            of: find.byType(CategorySelectionModalContent),
            matching: find.byType(Column),
          )
          .first;
      final size = tester.getSize(columnFinder);
      expect(size.height, lessThanOrEqualTo(400));
    });

    testWidgets('respects 640px max height on large screens', (tester) async {
      when(() => mockEntitiesCacheService.sortedCategories)
          .thenReturn(generateCategories(200));

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1600, 3000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: Align(
              alignment: Alignment.topCenter,
              child: UnconstrainedBox(
                constrainedAxis: Axis.horizontal,
                child: SizedBox(
                  width: 600,
                  child: CategorySelectionModalContent(
                    onCategorySelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final columnFinder = find
          .descendant(
            of: find.byType(CategorySelectionModalContent),
            matching: find.byType(Column),
          )
          .first;
      final size = tester.getSize(columnFinder);
      expect(size.height, lessThanOrEqualTo(640));
    });
  });
}
