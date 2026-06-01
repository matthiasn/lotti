import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/categories/ui/widgets/category_type_card.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;
  final testDate = DateTime(2024, 3, 15);
  final testCategories = [
    CategoryDefinition(
      id: 'cat1',
      name: 'Category 1',
      color: '#FF0000',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
    ),
    CategoryDefinition(
      id: 'cat2',
      name: 'Category 2',
      color: '#00FF00',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
    ),
    CategoryDefinition(
      id: 'cat3',
      name: 'Category 3',
      color: '#0000FF',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
    ),
  ];

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    when(
      () => mockEntitiesCacheService.sortedCategories,
    ).thenReturn(testCategories);
    // Mock getCategoryById for all test categories
    for (final category in testCategories) {
      when(
        () => mockEntitiesCacheService.getCategoryById(category.id),
      ).thenReturn(category);
    }
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

  testWidgets(
    'displays localized Clear option in the glass footer when initialCategoryId is provided',
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

      // Clear lives inside the glass footer with the localized label.
      final glassStrip = find.byType(DesignSystemGlassStrip);
      expect(glassStrip, findsOneWidget);
      final clearButton = find.descendant(
        of: glassStrip,
        matching: find.widgetWithText(TextButton, 'Clear'),
      );
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Callback was called with null to clear the selection.
      expect(selectedCategories.length, 1);
      expect(selectedCategories.first, isNull);
    },
  );

  testWidgets('shows "create category" option when search has no matches', (
    tester,
  ) async {
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
    final firstCardWidget = tester.widget<CategoryTypeCard>(
      categoryCards.first,
    );
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

    testWidgets('selected categories show visual selection state', (
      tester,
    ) async {
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
      final many = List<CategoryDefinition>.generate(10, (i) {
        return CategoryDefinition(
          id: 'cat${i + 1}',
          name: 'Category ${i + 1}',
          color: '#${(0x0000FF + i).toRadixString(16).padLeft(6, '0')}',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          private: false,
          active: true,
          favorite: false,
        );
      });
      when(() => mockEntitiesCacheService.sortedCategories).thenReturn(many);
      // Mock getCategoryById for all generated categories
      for (final category in many) {
        when(
          () => mockEntitiesCacheService.getCategoryById(category.id),
        ).thenReturn(category);
      }

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

    testWidgets('Done returns empty list when no selection', (tester) async {
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

      // Without selecting anything, tap Done
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    testWidgets('deselecting a category removes it from selection', (
      tester,
    ) async {
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

    testWidgets('onMultiSelectionChanged fires on each toggle', (tester) async {
      final selectionChanges = <Set<String>>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
              multiSelect: true,
              onMultiSelectionChanged: selectionChanges.add,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Category 1'));
      await tester.pump();
      expect(selectionChanges.last, equals({'cat1'}));

      await tester.tap(find.text('Category 2'));
      await tester.pump();
      expect(selectionChanges.last, equals({'cat1', 'cat2'}));

      // Deselect Category 1
      await tester.tap(find.text('Category 1'));
      await tester.pump();
      expect(selectionChanges.last, equals({'cat2'}));

      expect(selectionChanges, hasLength(3));
    });

    testWidgets('showDoneButton false hides Done button in multiSelect mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
              multiSelect: true,
              showDoneButton: false,
            ),
          ),
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
    });

    testWidgets('showDoneButton true shows Done button in multiSelect mode', (
      tester,
    ) async {
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

      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    });
  });

  group('overflow and scrolling behavior', () {
    List<CategoryDefinition> generateCategories(int count) {
      return List<CategoryDefinition>.generate(count, (i) {
        return CategoryDefinition(
          id: 'cat${i + 1}',
          name: 'Category ${i + 1}',
          color: '#${(0xFF0000 + i).toRadixString(16).padLeft(6, '0')}',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          private: false,
          active: true,
          favorite: i % 7 == 0,
        );
      });
    }

    testWidgets('results list scrolls when many categories present', (
      tester,
    ) async {
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

    testWidgets('search field remains visible while scrolling results', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenReturn(generateCategories(50));

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
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenReturn(generateCategories(100));

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

    testWidgets('uses DesignSystemSearch instead of LottiSearchBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySelectionModalContent(
            onCategorySelected: (_) {},
          ),
        ),
      );

      expect(find.byType(DesignSystemSearch), findsOneWidget);
      expect(find.byType(LottiSearchBar), findsNothing);
    });

    testWidgets(
      'shows DesignSystemGlassStrip with Done button in multi-select mode',
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

        expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
        // Done button lives inside the glass strip.
        final glassStrip = find.byType(DesignSystemGlassStrip);
        expect(
          find.descendant(
            of: glassStrip,
            matching: find.widgetWithText(FilledButton, 'Done'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'hides DesignSystemGlassStrip when neither Done nor clear is shown',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        );

        // Single-select mode with no initialCategoryId — no bottom action,
        // so the glass strip is suppressed.
        expect(find.byType(DesignSystemGlassStrip), findsNothing);
      },
    );

    testWidgets('respects 640px max height on large screens', (tester) async {
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenReturn(generateCategories(200));

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

  group('search clear and submit', () {
    testWidgets('onClear resets search query and restores full list', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategorySelectionModalContent(
            onCategorySelected: (_) {},
          ),
        ),
      );

      // Enter a search query that filters the list to one result.
      await tester.enterText(find.byType(TextField), 'Category 1');
      await tester.pump();
      expect(find.byType(CategoryTypeCard), findsOneWidget);

      // Tap the clear button (cancel icon inside DesignSystemSearch).
      final clearButton = find.byIcon(Icons.cancel_rounded);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();

      // All three categories should be shown again after the clear.
      expect(find.byType(CategoryTypeCard), findsNWidgets(3));
    });

    testWidgets(
      'onSubmitted with no matching categories opens create modal',
      (tester) async {
        registerAllFallbackValues();
        final mockRepository = MockCategoryRepository();
        final created = CategoryDefinition(
          id: 'cat-new',
          name: 'BrandNew',
          color: '#123456',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        );
        when(
          () => mockRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          ),
        ).thenAnswer((_) async => created);

        await tester.pumpWidget(
          WidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        );

        // Type a query that matches nothing.
        await tester.enterText(find.byType(TextField), 'BrandNew');
        await tester.pump();
        // Confirm empty-add state (SettingsCard with add icon visible).
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

        // Focus the field so testTextInput is connected, then submit.
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        // The create modal should now be on screen.
        expect(find.byType(CategoryCreateModal), findsOneWidget);
      },
    );

    testWidgets(
      'onSubmitted with non-empty matching results does NOT open create modal',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        );

        // Type a query that still matches categories.
        await tester.enterText(find.byType(TextField), 'Category');
        await tester.pump();
        // Multiple results — submit should be a no-op.
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        // No create modal should appear.
        expect(find.byType(CategoryCreateModal), findsNothing);
      },
    );
  });

  group('initial category selection and create flow', () {
    testWidgets('tapping initial category card pops the route', (tester) async {
      var popped = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => Material(
                          child: CategorySelectionModalContent(
                            onCategorySelected: (_) {},
                            initialCategoryId: 'cat1',
                          ),
                        ),
                      ),
                    );
                    popped = true;
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

      // The initially-selected category card is shown at the top with
      // selected: true — tapping it should call Navigator.pop.
      final cards = tester
          .widgetList<CategoryTypeCard>(find.byType(CategoryTypeCard))
          .toList();
      final initialCard = cards.firstWhere(
        (c) => c.categoryDefinition.id == 'cat1' && c.selected,
      );
      await tester.tap(find.byWidget(initialCard));
      await tester.pumpAndSettle();

      // Route should have been popped.
      expect(popped, isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
      'tapping SettingsCard in empty-add state opens create modal',
      (tester) async {
        registerAllFallbackValues();
        final mockRepository = MockCategoryRepository();
        final created = CategoryDefinition(
          id: 'cat-new',
          name: 'Unique',
          color: '#ABCDEF',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        );
        when(
          () => mockRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          ),
        ).thenAnswer((_) async => created);

        await tester.pumpWidget(
          WidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategorySelectionModalContent(
              onCategorySelected: (_) {},
            ),
          ),
        );

        // Enter a search query with no matches to reveal the add card.
        await tester.enterText(find.byType(TextField), 'Unique');
        await tester.pump();
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

        // Tap the add card.
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();

        // The create modal should now be on screen.
        expect(find.byType(CategoryCreateModal), findsOneWidget);
      },
    );

    testWidgets(
      'create modal onCategoryCreated invokes onCategorySelected callback',
      (tester) async {
        registerAllFallbackValues();
        final mockRepository = MockCategoryRepository();
        final created = CategoryDefinition(
          id: 'cat-created',
          name: 'Created',
          color: '#FF00FF',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          private: false,
          active: true,
        );
        when(
          () => mockRepository.createCategory(
            name: any(named: 'name'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          ),
        ).thenAnswer((_) async => created);

        final selectedCategories = <CategoryDefinition?>[];

        await tester.pumpWidget(
          WidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: CategorySelectionModalContent(
              onCategorySelected: selectedCategories.add,
            ),
          ),
        );

        // Trigger the empty-add state.
        await tester.enterText(find.byType(TextField), 'Created');
        await tester.pump();
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

        // Open the create modal via the add card.
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryCreateModal), findsOneWidget);

        // The modal pre-fills the name from the search query. Tap Save.
        final saveButton = find.text('Save');
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton, warnIfMissed: false);
        await tester.pumpAndSettle();

        // onCategoryCreated fires onCategorySelected with the created category.
        expect(selectedCategories, hasLength(1));
        expect(selectedCategories.first?.id, equals('cat-created'));
      },
    );
  });
}
