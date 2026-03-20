import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  group('CategoriesListPage Widget Tests', () {
    late MockCategoryRepository mockRepository;

    setUp(() async {
      await setUpTestGetIt();
      mockRepository = MockCategoryRepository();
    });

    tearDown(tearDownTestGetIt);

    /// Pumps the [CategoriesListPage] with the given overrides.
    ///
    /// By default, [categoryTaskCountProvider] returns 0 for all categories.
    /// Pass [taskCounts] to supply specific counts keyed by category ID.
    Future<void> pumpCategoriesListPage(
      WidgetTester tester, {
      bool settle = true,
      Map<String, int> taskCounts = const {},
    }) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(mockRepository),
            categoryTaskCountProvider.overrideWith((ref, categoryId) async {
              return taskCounts[categoryId] ?? 0;
            }),
          ],
          child: const CategoriesListPage(),
        ),
      );
      await tester.pump();
      if (settle) {
        await tester.pumpAndSettle();
      }
    }

    group('Loading and Error States', () {
      testWidgets('displays loading state initially', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => const Stream.empty(),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
              categoryTaskCountProvider.overrideWith(
                (ref, categoryId) async => 0,
              ),
            ],
            child: const CategoriesListPage(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays error state when stream errors', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.error(Exception('Test error')),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Test error'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('displays empty state when no categories', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.category_outlined), findsOneWidget);
        expect(find.byType(Text), findsAtLeastNWidgets(2));
      });
    });

    group('Header', () {
      testWidgets('shows localized back button and add category button', (
        tester,
      ) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        // Back button with chevron_left — localized, not hardcoded 'Back'
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
        expect(find.text('Go Back'), findsOneWidget);

        // Add category button
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.text('Add Category'), findsOneWidget);

        // No FAB
        expect(find.byType(FloatingActionButton), findsNothing);
      });

      testWidgets('shows large Categories title below top row', (
        tester,
      ) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.text('Categories'), findsOneWidget);
      });
    });

    group('Category Tile Design', () {
      testWidgets('renders icon badge with category color', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Red Category',
            color: '#FF0000',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        // Verify tile renders with category name and fallback letter
        expect(find.text('Red Category'), findsOneWidget);
        expect(find.text('R'), findsOneWidget);
      });

      testWidgets('renders task count subtitle', (tester) async {
        const categoryId = 'cat-123';
        final categories = [
          CategoryTestUtils.createTestCategory(
            id: categoryId,
            name: 'Work',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(
          tester,
          taskCounts: {categoryId: 5},
        );

        expect(find.text('5 tasks'), findsOneWidget);
      });

      testWidgets('renders singular task count', (tester) async {
        const categoryId = 'cat-singular';
        final categories = [
          CategoryTestUtils.createTestCategory(
            id: categoryId,
            name: 'Solo',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(
          tester,
          taskCounts: {categoryId: 1},
        );

        expect(find.text('1 task'), findsOneWidget);
      });

      testWidgets('renders zero task count', (tester) async {
        const categoryId = 'cat-zero';
        final categories = [
          CategoryTestUtils.createTestCategory(
            id: categoryId,
            name: 'Empty',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(
          tester,
          taskCounts: {categoryId: 0},
        );

        expect(find.text('0 tasks'), findsOneWidget);
      });

      testWidgets('shows loading placeholder before count arrives', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Loading'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
              categoryTaskCountProvider.overrideWith((ref, categoryId) {
                // Return a future that never completes to keep loading state
                return Completer<int>().future;
              }),
            ],
            child: const CategoriesListPage(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Should show dash placeholder during loading
        expect(find.text('\u2014'), findsOneWidget);
      });

      testWidgets('renders chevron trailing icon', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Test'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('shows favorite star for favorited categories', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Favorite',
            favorite: true,
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.star), findsOneWidget);
      });

      testWidgets('does not show star for non-favorite categories', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Normal'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.star), findsNothing);
      });

      testWidgets('shows fallback letter when no icon set', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.text('W'), findsOneWidget);
      });

      testWidgets('shows ? fallback for empty name without icon', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: ''),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.text('?'), findsOneWidget);
      });

      testWidgets('renders icon when CategoryIcon is set', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Fitness',
            icon: CategoryIcon.fitness,
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        // Should show the icon, not the fallback letter
        expect(find.text('F'), findsNothing);
        expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      });

      testWidgets('uses black foreground on light category color', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Light',
            color: '#FFFFCC',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        // Find the fallback letter Text widget and verify its color is black
        final textFinder = find.text('L');
        expect(textFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.style?.color, Colors.black);
      });

      testWidgets('uses white foreground on dark category color', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Dark',
            color: '#000033',
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        final textFinder = find.text('D');
        expect(textFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.style?.color, Colors.white);
      });

      testWidgets('uses ModernBaseCard for category items', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(ModernBaseCard), findsOneWidget);
      });

      testWidgets('ModernBaseCard is tappable', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        final card = tester.widget<ModernBaseCard>(find.byType(ModernBaseCard));
        expect(card.onTap, isNotNull);
      });
    });

    group('Status Indicators', () {
      testWidgets('displays private icon for private categories', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Private Category',
            private: true,
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('displays inactive icon for inactive categories', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Inactive Category',
            active: false,
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });

      testWidgets('displays all status icons together', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(
            name: 'Complex Category',
            private: true,
            active: false,
            favorite: true,
          ),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      });

      testWidgets('hides status icons for normal active categories', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Normal'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsNothing);
        expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
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

        await pumpCategoriesListPage(tester);

        final cards = find.byType(ModernBaseCard);
        expect(cards, findsNWidgets(3));

        final listTiles = find.byType(ListTile);

        final firstTitle =
            tester.widget<ListTile>(listTiles.at(0)).title as Text?;
        final secondTitle =
            tester.widget<ListTile>(listTiles.at(1)).title as Text?;
        final thirdTitle =
            tester.widget<ListTile>(listTiles.at(2)).title as Text?;

        expect(firstTitle?.data, equals('Alpha'));
        expect(secondTitle?.data, equals('Beta'));
        expect(thirdTitle?.data, equals('Zebra'));
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

        await pumpCategoriesListPage(tester);

        final tiles = find.byType(ListTile);
        final tile0 = tester.widget<ListTile>(tiles.at(0)).title as Text?;
        final tile1 = tester.widget<ListTile>(tiles.at(1)).title as Text?;
        final tile2 = tester.widget<ListTile>(tiles.at(2)).title as Text?;

        expect(tile0?.data, 'ALPHA');
        expect(tile1?.data, 'Beta');
        expect(tile2?.data, 'zebra');
      });

      testWidgets('displays multiple categories with correct tile count', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Work'),
          CategoryTestUtils.createTestCategory(name: 'Personal'),
          CategoryTestUtils.createTestCategory(name: 'Archived'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(ModernBaseCard), findsNWidgets(3));
        expect(find.byType(ListTile), findsNWidgets(3));
        expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      });
    });

    group('Interactions', () {
      testWidgets('displays category tile as tappable', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        final card = find.byType(ModernBaseCard);
        expect(card, findsOneWidget);

        final cardWidget = tester.widget<ModernBaseCard>(card);
        expect(cardWidget.onTap, isNotNull);
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

        await pumpCategoriesListPage(tester);

        expect(find.byType(ModernBaseCard), findsOneWidget);
      });

      testWidgets('scroll behavior with many categories', (tester) async {
        final manyCategories = List.generate(
          50,
          (i) => CategoryTestUtils.createTestCategory(name: 'Category $i'),
        );

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(manyCategories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.text('Category 0'), findsOneWidget);
        expect(find.text('Category 1'), findsOneWidget);

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -500),
        );
        await tester.pump();

        expect(find.text('Category 0'), findsNothing);
      });
    });

    group('Layout Structure', () {
      testWidgets('uses CustomScrollView with slivers', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverToBoxAdapter), findsWidgets);
      });
    });
  });
}
