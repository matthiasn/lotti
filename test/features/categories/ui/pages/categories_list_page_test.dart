import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
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

        // Find all ListTiles
        final listTiles = find.byType(ListTile);
        expect(listTiles, findsNWidgets(3));

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

        // Check for CircleAvatar with first letter
        expect(find.byType(CircleAvatar), findsOneWidget);
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

        // Verify the ListTile exists and is tappable
        final listTile = find.byType(ListTile);
        expect(listTile, findsOneWidget);

        // The ListTile should have an onTap callback
        final tile = tester.widget<ListTile>(listTile);
        expect(tile.onTap, isNotNull);
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

        // Should display all 3 categories
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
    });
  });
}
