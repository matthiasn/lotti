import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
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
      testWidgets('shows add category button', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.text('Add Category'), findsOneWidget);
      });

      testWidgets('shows Categories title', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.text('Categories'), findsOneWidget);
      });
    });

    group('Category Tile Design', () {
      testWidgets('renders CategoryIconBadge with fallback letter', (
        tester,
      ) async {
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

        expect(find.text('Red Category'), findsOneWidget);
        expect(find.text('R'), findsOneWidget);
        expect(find.byType(CategoryIconBadge), findsOneWidget);
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
                return Completer<int>().future;
              }),
            ],
            child: const CategoriesListPage(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

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

        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
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

      testWidgets('uses DesignSystemListItem for category rows', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(DesignSystemListItem), findsOneWidget);
      });

      testWidgets('DesignSystemListItem is tappable', (tester) async {
        final categories = [
          CategoryTestUtils.createTestCategory(),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.onTap, isNotNull);
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
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
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

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.title, 'Alpha');
        expect(second.title, 'Beta');
        expect(third.title, 'Zebra');
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

        final items = find.byType(DesignSystemListItem);
        final item0 = tester.widget<DesignSystemListItem>(items.at(0));
        final item1 = tester.widget<DesignSystemListItem>(items.at(1));
        final item2 = tester.widget<DesignSystemListItem>(items.at(2));

        expect(item0.title, 'ALPHA');
        expect(item1.title, 'Beta');
        expect(item2.title, 'zebra');
      });

      testWidgets('displays multiple categories with correct item count', (
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

        expect(find.byType(DesignSystemListItem), findsNWidgets(3));
        expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      });

      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'A'),
          CategoryTestUtils.createTestCategory(name: 'B'),
          CategoryTestUtils.createTestCategory(name: 'C'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        final items = find.byType(DesignSystemListItem);
        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });
    });

    group('Layout Structure', () {
      testWidgets('uses CustomScrollView with slivers', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('renders items inside DesignSystemGroupedList', (
        tester,
      ) async {
        final categories = [
          CategoryTestUtils.createTestCategory(name: 'Test'),
        ];

        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value(categories),
        );

        await pumpCategoriesListPage(tester);

        expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      });
    });
  });
}
