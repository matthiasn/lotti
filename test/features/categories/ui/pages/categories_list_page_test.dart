import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_task_count_provider.dart';
import 'package:lotti/features/categories/ui/pages/categories_list_page.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/services/nav_service.dart';
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
      // Row taps drive navigation via the top-level `beamToNamed`, which
      // otherwise delegates through `getIt<NavService>()` (not registered
      // in these widget tests). Install a no-op override by default; the
      // navigation test replaces it with a capturing closure.
      beamToNamedOverride = (_) {};
    });

    tearDown(() async {
      beamToNamedOverride = null;
      await tearDownTestGetIt();
    });

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
        expect(find.text('No categories yet'), findsOneWidget);
        expect(
          find.text('Create a category to organize your entries'),
          findsOneWidget,
        );
      });

      testWidgets(
        'hides the corner FAB on an empty list — the empty state carries '
        'its own inline create button instead',
        (tester) async {
          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value([]),
          );

          await pumpCategoriesListPage(tester);

          expect(find.byType(DesignSystemFloatingActionButton), findsNothing);
          expect(find.text('Create category'), findsOneWidget);
        },
      );
    });

    group('Header', () {
      testWidgets(
        'shows a create-category FAB at the bottom-right (replaces the '
        'old app-bar text button) once categories exist',
        (tester) async {
          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value([
              CategoryTestUtils.createTestCategory(id: 'a', name: 'Alpha'),
            ]),
          );

          await pumpCategoriesListPage(tester);

          // The "+" affordance is now the design-system FAB, not a
          // TextButton in the header. The icon survives (default
          // `add_rounded` glyph baked into DesignSystemFloatingActionButton),
          // the legacy "Add Category" text label is gone (the FAB
          // carries a semanticLabel for screen readers instead).
          final fab = find.byType(DesignSystemFloatingActionButton);
          expect(fab, findsOneWidget);
          expect(
            tester.widget<DesignSystemFloatingActionButton>(fab).semanticLabel,
            'Create category',
          );
          expect(
            find.descendant(of: fab, matching: find.byIcon(Icons.add_rounded)),
            findsOneWidget,
          );
          expect(find.text('Add Category'), findsNothing);
        },
      );

      testWidgets(
        'tapping the create FAB beams to the create page — the same '
        'list-to-full-page flow as every other definition type',
        (tester) async {
          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value([
              CategoryTestUtils.createTestCategory(id: 'a', name: 'Alpha'),
            ]),
          );
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          await pumpCategoriesListPage(tester);

          await tester.tap(find.byType(DesignSystemFloatingActionButton));
          await tester.pump();

          expect(beamedTo, '/settings/categories/create');
        },
      );

      testWidgets('shows Categories title', (tester) async {
        when(() => mockRepository.watchCategories()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpCategoriesListPage(tester);

        expect(find.text('Categories'), findsOneWidget);
      });
    });

    group('Search', () {
      testWidgets(
        'renders a DesignSystemSearch above the list when categories load',
        (tester) async {
          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value([
              CategoryTestUtils.createTestCategory(
                id: 'a',
                name: 'Alpha',
              ),
            ]),
          );

          await pumpCategoriesListPage(tester);
          await tester.pumpAndSettle();

          expect(find.byType(DesignSystemSearch), findsOneWidget);
        },
      );

      testWidgets(
        'typing a query narrows the list to matching categories '
        '(case-insensitive name substring)',
        (tester) async {
          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value([
              CategoryTestUtils.createTestCategory(id: 'a', name: 'Alpha'),
              CategoryTestUtils.createTestCategory(id: 'b', name: 'Beta'),
              CategoryTestUtils.createTestCategory(id: 'c', name: 'Charlie'),
            ]),
          );

          await pumpCategoriesListPage(tester);
          await tester.pumpAndSettle();

          // All three rows visible by default.
          expect(find.text('Alpha'), findsOneWidget);
          expect(find.text('Beta'), findsOneWidget);
          expect(find.text('Charlie'), findsOneWidget);

          // Type a query that matches a single row.
          await tester.enterText(find.byType(DesignSystemSearch), 'BET');
          await tester.pump();

          expect(find.text('Beta'), findsOneWidget);
          expect(find.text('Alpha'), findsNothing);
          expect(find.text('Charlie'), findsNothing);
        },
      );

      testWidgets(
        'a query that matches no category shows the no-match empty state',
        (tester) async {
          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value([
              CategoryTestUtils.createTestCategory(id: 'a', name: 'Alpha'),
            ]),
          );

          await pumpCategoriesListPage(tester);
          await tester.pumpAndSettle();

          await tester.enterText(find.byType(DesignSystemSearch), 'zzzz');
          await tester.pump();

          expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
          // The empty-state message includes the active query verbatim
          // ("No categories match \"zzzz\""). Don't use `textContaining`
          // here — it would also match the EditableText showing the
          // typed query inside the search field.
          expect(
            find.text('No categories match "zzzz"'),
            findsOneWidget,
          );
        },
      );
    });

    group('Category Tile Design', () {
      testWidgets('renders CategoryIconChip with fallback letter', (
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
        expect(find.byType(CategoryIconChip), findsOneWidget);
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

      testWidgets('shows outlined amber star for favorited categories', (
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

        // One icon weight across the trailing slot — the star is an
        // outline like lock/eye-off; amber carries the favorite signal.
        final star = find.byIcon(Icons.star_rounded);
        expect(star, findsOneWidget);
        final tokens = tester.element(star).designTokens;
        expect(
          tester.widget<Icon>(star).color,
          tokens.colors.text.mediumEmphasis,
        );
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

        expect(find.byIcon(Icons.star_rounded), findsNothing);
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

      testWidgets(
        'tapping a category row beams to that category detail route',
        (tester) async {
          String? beamedTo;
          beamToNamedOverride = (path) => beamedTo = path;

          final categories = [
            CategoryTestUtils.createTestCategory(
              id: 'cat-42',
              name: 'Work',
            ),
          ];

          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value(categories),
          );

          await pumpCategoriesListPage(tester);

          // Nothing has been beamed before the tap.
          expect(beamedTo, isNull);

          await tester.tap(find.byType(DesignSystemListItem));
          await tester.pump();

          // The row's onTap routes through the top-level `beamToNamed`
          // with the category-id-scoped settings path.
          expect(beamedTo, '/settings/categories/cat-42');
        },
      );

      // NOTE: The `_CategoryListItem` subtitle's `error: (_, _) => ''`
      // branch (source line 270) is not exercised here. In this Riverpod
      // version a `FutureProvider` whose future completes with an error
      // settles into `AsyncLoading(error: …)` rather than a terminal
      // `AsyncError`, so `AsyncValue.when` (used without
      // `skipLoadingOnReload`) always routes through `loading:` — the
      // error branch is unreachable through provider overrides, which only
      // accept a future-returning function, never a direct `AsyncError`.
    });

    group('CategoriesListBody embedded alias', () {
      testWidgets(
        'CategoriesListBody renders a CategoriesListPage with its content',
        (tester) async {
          final categories = [
            CategoryTestUtils.createTestCategory(
              id: 'cat-body',
              name: 'Embedded',
            ),
          ];

          when(() => mockRepository.watchCategories()).thenAnswer(
            (_) => Stream.value(categories),
          );

          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              overrides: [
                categoryRepositoryProvider.overrideWithValue(mockRepository),
                categoryTaskCountProvider.overrideWith(
                  (ref, id) async => 3,
                ),
              ],
              child: const CategoriesListBody(),
            ),
          );
          await tester.pump();
          await tester.pumpAndSettle();

          // The body alias delegates to the full page, so the page widget
          // and its rendered category content are both present.
          expect(find.byType(CategoriesListPage), findsOneWidget);
          expect(find.text('Embedded'), findsOneWidget);
        },
      );
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
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
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
        expect(find.byIcon(Icons.star_rounded), findsNothing);
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
