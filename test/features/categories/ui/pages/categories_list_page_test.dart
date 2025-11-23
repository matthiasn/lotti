import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/search/lotti_search_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../../test_helper.dart';
import '../../test_utils.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  group('CategoriesListPage Widget Tests', () {
    late MockCategoryRepository mockRepository;

    setUp(() {
      mockRepository = MockCategoryRepository();
    });

    group('Loading and Error States', () {
      testWidgets('displays loading state initially', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => const Stream.empty(),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        // Pump a few frames to let animations complete
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays error state when stream errors', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.error(Exception('Test error')),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Test error'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('displays empty state when no categories', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.category_outlined), findsOneWidget);
        // Empty state text would be localized
        expect(find.byType(Text), findsAtLeastNWidgets(2));
      });
    });

    group('Search Functionality', () {
      testWidgets('displays search bar', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(LottiSearchBar), findsOneWidget);
        expect(find.text('Search categories...'), findsOneWidget);
      });

      testWidgets('filters categories based on search query', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
          CategoryTestUtils.createTestCategory(name: 'Archive'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // All categories should be visible initially
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Personal'), findsOneWidget);
        expect(find.text('Archive'), findsOneWidget);

        // Enter search query
        await tester.enterText(find.byType(TextField), 'work');
        await tester.pump();

        // Only 'Work' category should be visible
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Personal'), findsNothing);
        expect(find.text('Archive'), findsNothing);
      });

      testWidgets('shows no results message when search has no matches',
          (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Enter search query with no matches
        await tester.enterText(find.byType(TextField), 'xyz');
        await tester.pumpAndSettle();

        expect(find.text('No categories found'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
      });

      testWidgets('clears search when clear button is tapped', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Enter search query
        await tester.enterText(find.byType(TextField), 'work');
        await tester.pump();

        // Only one category should be visible
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Personal'), findsNothing);

        // Tap clear button
        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pump();

        // All categories should be visible again
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Personal'), findsOneWidget);
      });

      testWidgets('search is case insensitive', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'PERSONAL'),
          CategoryTestUtils.createTestCategory(name: 'archive'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Search for 'WORK' should find 'Work'
        await tester.enterText(find.byType(TextField), 'WORK');
        await tester.pump();
        expect(find.text('Work'), findsOneWidget);

        // Clear and search for 'personal' should find 'PERSONAL'
        await tester.enterText(find.byType(TextField), 'personal');
        await tester.pump();
        expect(find.text('PERSONAL'), findsOneWidget);
      });
    });

    group('Modern Base Card', () {
      testWidgets('uses ModernBaseCard for category items', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(ModernBaseCard), findsOneWidget);
      });

      testWidgets('ModernBaseCard is tappable', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        final card = tester.widget<ModernBaseCard>(find.byType(ModernBaseCard));
        expect(card.onTap, isNotNull);
      });
    });

    group('Categories List Display', () {
      testWidgets('displays categories in alphabetical order', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Zebra'),
          CategoryTestUtils.createTestCategory(name: 'Alpha'),
          CategoryTestUtils.createTestCategory(name: 'Beta'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Find all ModernBaseCards
        final cards = find.byType(ModernBaseCard);
        expect(cards, findsNWidgets(3));

        // Find all ListTiles
        final listTiles = find.byType(ListTile);

        // Verify order - categories should be sorted alphabetically
        final firstTile = tester.widget<ListTile>(listTiles.at(0));
        final secondTile = tester.widget<ListTile>(listTiles.at(1));
        final thirdTile = tester.widget<ListTile>(listTiles.at(2));

        final firstTitle = firstTile.title as Text?;
        final secondTitle = secondTile.title as Text?;
        final thirdTitle = thirdTile.title as Text?;

        expect(firstTitle?.data, equals('Alpha'));
        expect(secondTitle?.data, equals('Beta'));
        expect(thirdTitle?.data, equals('Zebra'));
      });

      testWidgets('displays category with color avatar', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Test', color: '#FF0000'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Check for circular container with first letter
        expect(find.byType(ModernBaseCard), findsOneWidget);
        expect(find.text('T'), findsOneWidget); // First letter of 'Test'
      });

      testWidgets('displays private category icon', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
              name: 'Private Category', private: true),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('displays inactive category icon', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
              name: 'Inactive Category', active: false),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });

      testWidgets('displays category with AI settings subtitle',
          (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'AI Category',
            allowedPromptIds: ['prompt1', 'prompt2'],
            defaultLanguageCode: 'en',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should have subtitle with features
        final listTile = find.byType(ListTile);
        expect(listTile, findsOneWidget);

        final tile = tester.widget<ListTile>(listTile);
        expect(tile.subtitle, isNotNull);
      });
    });

    group('Interactions', () {
      testWidgets('displays category tile as tappable', (tester) async {
        final categoryId = const Uuid().v4();
        final categories = [
          CategoryTestUtils.createTestCategory(id: categoryId),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify the ModernBaseCard exists and is tappable
        final card = find.byType(ModernBaseCard);
        expect(card, findsOneWidget);

        // The ModernBaseCard should have an onTap callback
        final cardWidget = tester.widget<ModernBaseCard>(card);
        expect(cardWidget.onTap, isNotNull);
      });

      testWidgets('FAB exists and is tappable', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify FAB exists
        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);

        // The FAB should have an onPressed callback
        final fabWidget = tester.widget<FloatingActionButton>(fab);
        expect(fabWidget.onPressed, isNotNull);
      });
    });

    group('Multiple Categories', () {
      testWidgets('displays multiple categories correctly', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work', private: true),
          CategoryTestUtils.createTestCategory(
              name: 'Personal', defaultLanguageCode: 'en'),
          CategoryTestUtils.createTestCategory(name: 'Archived', active: false),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should display all 3 categories with ModernBaseCard
        expect(find.byType(ModernBaseCard), findsNWidgets(3));
        expect(find.byType(ListTile), findsNWidgets(3));

        // Check that they're sorted alphabetically
        final tiles = find.byType(ListTile);
        final tile0 = tester.widget<ListTile>(tiles.at(0)).title as Text?;
        final tile1 = tester.widget<ListTile>(tiles.at(1)).title as Text?;
        final tile2 = tester.widget<ListTile>(tiles.at(2)).title as Text?;

        expect(tile0?.data, 'Archived');
        expect(tile1?.data, 'Personal');
        expect(tile2?.data, 'Work');

        // Verify icons are displayed correctly
        expect(
            find.byIcon(Icons.lock_outline), findsOneWidget); // Work is private
        expect(find.byIcon(Icons.visibility_off_outlined),
            findsOneWidget); // Archived is inactive
      });

      testWidgets('handles categories with automatic prompts', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'AI Enhanced',
            automaticPrompts: {
              AiResponseType.audioTranscription: ['prompt1'],
              AiResponseType.imageAnalysis: ['prompt2'],
            },
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should display the category with subtitle showing it has automatic prompts
        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        expect(listTile.subtitle, isNotNull);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles category with empty name', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: ''),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should show '?' for empty name
        expect(find.text('?'), findsOneWidget);
      });

      testWidgets('handles mixed case sorting correctly', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'zebra'),
          CategoryTestUtils.createTestCategory(name: 'ALPHA'),
          CategoryTestUtils.createTestCategory(name: 'Beta'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should sort case-insensitively
        final tiles = find.byType(ListTile);
        final tile0 = tester.widget<ListTile>(tiles.at(0)).title as Text?;
        final tile1 = tester.widget<ListTile>(tiles.at(1)).title as Text?;
        final tile2 = tester.widget<ListTile>(tiles.at(2)).title as Text?;

        expect(tile0?.data, 'ALPHA');
        expect(tile1?.data, 'Beta');
        expect(tile2?.data, 'zebra');
      });

      testWidgets('handles search with partial matches', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Development'),
          CategoryTestUtils.createTestCategory(name: 'Developer Tools'),
          CategoryTestUtils.createTestCategory(name: 'Production'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Search for 'dev' should find both Development and Developer Tools
        await tester.enterText(find.byType(TextField), 'dev');
        await tester.pump();

        expect(find.byType(ModernBaseCard), findsNWidgets(2));
        expect(find.text('Development'), findsOneWidget);
        expect(find.text('Developer Tools'), findsOneWidget);
        expect(find.text('Production'), findsNothing);
      });

      testWidgets('search state persists when categories update',
          (tester) async {
        final categoriesController =
            StreamController<List<CategoryDefinition>>();

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => categoriesController.stream,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        // Initial categories
        categoriesController.add([
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
        ]);
        await tester.pumpAndSettle();

        // Set search query
        await tester.enterText(find.byType(TextField), 'work');
        await tester.pump();
        expect(find.byType(ModernBaseCard), findsOneWidget);

        // Update categories (add new one)
        categoriesController.add([
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
          CategoryTestUtils.createTestCategory(name: 'Workspace'),
        ]);
        await tester.pumpAndSettle();

        // Search query should still be applied
        expect(find.byType(ModernBaseCard),
            findsNWidgets(2)); // Work and Workspace

        await categoriesController.close();
      });

      testWidgets('handles whitespace in search queries', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'My Work'),
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Workspace'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Search with leading/trailing spaces should be trimmed
        await tester.enterText(find.byType(TextField), '  work  ');
        await tester.pump();

        // All categories containing "work" should be found
        expect(find.byType(ModernBaseCard), findsNWidgets(3));
        expect(find.text('My Work'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Workspace'), findsOneWidget);

        // Test with tabs and multiple spaces
        await tester.enterText(find.byType(TextField), '\t  work\n  ');
        await tester.pump();

        // Should still find all work-related categories
        expect(find.byType(ModernBaseCard), findsNWidgets(3));

        // Test empty string with only whitespace
        await tester.enterText(find.byType(TextField), '   \t\n  ');
        await tester.pump();

        // Should show all categories (empty search after trim)
        expect(find.byType(ModernBaseCard), findsNWidgets(3));
      });

      testWidgets('displays all state icons correctly together',
          (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Complex Category',
            private: true,
            active: false,
            defaultLanguageCode: 'en',
            allowedPromptIds: ['prompt1'],
            automaticPrompts: {
              AiResponseType.audioTranscription: ['prompt2'],
            },
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should show both private and inactive icons
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

        // Should have subtitle with all features
        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.subtitle, isNotNull);
      });

      testWidgets('scroll behavior with many categories', (tester) async {
        final manyCategories = List.generate(
          50,
          (i) => CategoryTestUtils.createTestCategory(name: 'Category $i'),
        );

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(manyCategories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should use CustomScrollView (with slivers)
        expect(find.byType(CustomScrollView), findsOneWidget);

        // Verify first few are visible
        expect(find.text('Category 0'), findsOneWidget);
        expect(find.text('Category 1'), findsOneWidget);

        // Scroll down
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();

        // Later items should now be visible
        expect(find.text('Category 0'), findsNothing); // Scrolled away
      });

      testWidgets('search performance with many categories', (tester) async {
        final manyCategories = List.generate(
          100,
          (i) => CategoryTestUtils.createTestCategory(name: 'Category $i'),
        );

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(manyCategories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Search for specific number
        await tester.enterText(find.byType(TextField), '42');
        await tester.pump();

        // Should find only one category
        expect(find.byType(ModernBaseCard), findsOneWidget);
        expect(find.text('Category 42'), findsOneWidget);
      });

      testWidgets('ModernBaseCard tap interaction with search active',
          (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Apply search filter
        await tester.enterText(find.byType(TextField), 'work');
        await tester.pump();

        // Verify card is still tappable after search
        final card = find.byType(ModernBaseCard);
        expect(card, findsOneWidget);

        final cardWidget = tester.widget<ModernBaseCard>(card);
        expect(cardWidget.onTap, isNotNull);
      });
    });

    group('SettingsPageHeader Integration', () {
      testWidgets('displays SettingsPageHeader with correct title',
          (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should have SettingsPageHeader
        expect(find.byType(SettingsPageHeader), findsOneWidget);

        // Should display correct title (localized)
        expect(find.byType(SliverAppBar), findsOneWidget);
      });

      testWidgets('shows back button in SettingsPageHeader', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should have back button (chevron_left icon)
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      });

      testWidgets('uses CustomScrollView with slivers', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pumpAndSettle();

        // Should use CustomScrollView for sliver structure
        expect(find.byType(CustomScrollView), findsOneWidget);

        // Should have SettingsPageHeader as a sliver
        expect(find.byType(SettingsPageHeader), findsOneWidget);

        // Should have SliverToBoxAdapter for search bar
        expect(find.byType(SliverToBoxAdapter), findsWidgets);
      });
    });
  });
}
