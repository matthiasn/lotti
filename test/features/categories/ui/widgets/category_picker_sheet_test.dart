import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/widgets/category_create_modal.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../test_utils.dart';

/// A generated bundle of three id-sets for the [resolveCategoryMultiResult]
/// property test.
typedef _MultiCase = ({Set<String> raw, Set<String> live, Set<String> initial});

void main() {
  final cat1 = CategoryTestUtils.createTestCategory(
    id: 'cat1',
    name: 'Category 1',
    color: '#FF0000',
    favorite: true,
  );
  final cat2 = CategoryTestUtils.createTestCategory(
    id: 'cat2',
    name: 'Category 2',
    color: '#00FF00',
  );
  final cat3 = CategoryTestUtils.createTestCategory(
    id: 'cat3',
    name: 'Category 3',
    color: '#0000FF',
    private: true,
  );
  final testCategories = [cat1, cat2, cat3];

  late MockEntitiesCacheService mockCache;

  setUp(() {
    mockCache = MockEntitiesCacheService();
    when(() => mockCache.sortedCategories).thenReturn(testCategories);
    for (final category in testCategories) {
      when(
        () => mockCache.getCategoryById(category.id),
      ).thenReturn(category);
    }
    getIt.registerSingleton<EntitiesCacheService>(mockCache);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  // Pushes the single-mode sheet on a route, runs [interact], and returns the
  // value the route was popped with.
  Future<CategorySingleResult?> pickSingle(
    WidgetTester tester, {
    required Future<void> Function() interact,
    String? currentCategoryId,
    List<CategoryDefinition>? options,
    List<Override> overrides = const [],
  }) async {
    CategorySingleResult? captured;
    await tester.pumpWidget(
      WidgetTestBench(
        overrides: overrides,
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                captured = await Navigator.of(context)
                    .push<CategorySingleResult>(
                      MaterialPageRoute(
                        builder: (_) => Material(
                          child: CategoryPickerSheet(
                            mode: CategoryPickerMode.single,
                            options: options ?? testCategories,
                            currentCategoryId: currentCategoryId,
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
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await interact();
    await tester.pumpAndSettle();
    return captured;
  }

  Widget pumpMulti(
    ValueNotifier<Set<String>> staged, {
    bool showUnassignedRow = false,
    List<Override> overrides = const [],
  }) {
    return WidgetTestBench(
      overrides: overrides,
      child: Material(
        child: CategoryPickerSheet(
          mode: CategoryPickerMode.multi,
          options: testCategories,
          initialSelectedIds: staged.value,
          stagedNotifier: staged,
          showUnassignedRow: showUnassignedRow,
        ),
      ),
    );
  }

  group('resolveCategoryMultiResult', () {
    test('strips the unassigned sentinel into includesUnassigned', () {
      final result = resolveCategoryMultiResult(
        raw: {'cat1', kCategoryPickerUnassignedSentinel},
        initialSelectedIds: const {},
        liveIds: const {'cat1', 'cat2'},
        intersectWithLiveIds: true,
      );
      expect(result.ids, {'cat1'});
      expect(result.includesUnassigned, isTrue);
      expect(result.ids.contains(kCategoryPickerUnassignedSentinel), isFalse);
    });

    test('intersect drops ids no longer present in the live set', () {
      final result = resolveCategoryMultiResult(
        raw: {'cat1', 'deleted'},
        initialSelectedIds: const {},
        liveIds: const {'cat1', 'cat2'},
        intersectWithLiveIds: true,
      );
      expect(result.ids, {'cat1'});
    });

    test('keeps dead ids when intersect is disabled', () {
      final result = resolveCategoryMultiResult(
        raw: {'cat1', 'deleted'},
        initialSelectedIds: const {},
        liveIds: const {'cat1'},
        intersectWithLiveIds: false,
      );
      expect(result.ids, {'cat1', 'deleted'});
    });

    test('changed is false when the committed set equals the seed', () {
      final result = resolveCategoryMultiResult(
        raw: {'cat1', 'cat2'},
        initialSelectedIds: const {'cat2', 'cat1'},
        liveIds: const {'cat1', 'cat2'},
        intersectWithLiveIds: true,
      );
      expect(result.changed, isFalse);
    });

    test('changed is true when the committed set differs from the seed', () {
      final result = resolveCategoryMultiResult(
        raw: {'cat1'},
        initialSelectedIds: const {'cat1', 'cat2'},
        liveIds: const {'cat1', 'cat2'},
        intersectWithLiveIds: true,
      );
      expect(result.changed, isTrue);
    });

    test('changed reflects a toggle of the unassigned sentinel alone', () {
      final result = resolveCategoryMultiResult(
        raw: {'cat1', kCategoryPickerUnassignedSentinel},
        initialSelectedIds: const {'cat1'},
        liveIds: const {'cat1'},
        intersectWithLiveIds: true,
      );
      expect(result.ids, {'cat1'});
      expect(result.includesUnassigned, isTrue);
      expect(result.changed, isTrue);
    });

    test('changed is false when an unchanged seed holds a now-dead id', () {
      // The user changed nothing, but a previously-selected id is no longer
      // live. Intersecting both sides keeps `changed` honest (no false edit).
      final result = resolveCategoryMultiResult(
        raw: {'cat1', 'dead'},
        initialSelectedIds: const {'cat1', 'dead'},
        liveIds: const {'cat1', 'cat2'},
        intersectWithLiveIds: true,
      );
      expect(result.ids, {'cat1'});
      expect(result.changed, isFalse);
    });

    glados.Glados<_MultiCase>(
      glados.any.combine4<List<int>, List<int>, List<int>, int, _MultiCase>(
        glados.any.list(glados.any.int),
        glados.any.list(glados.any.int),
        glados.any.list(glados.any.int),
        glados.any.int,
        (rawInts, liveInts, initialInts, flag) => (
          raw: {
            for (final n in rawInts) 'id$n',
            if (flag.isEven) kCategoryPickerUnassignedSentinel,
          },
          live: {for (final n in liveInts) 'id$n'},
          initial: {for (final n in initialInts) 'id$n'},
        ),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test('structural invariants hold for any id sets', (c) {
      final result = resolveCategoryMultiResult(
        raw: c.raw,
        initialSelectedIds: c.initial,
        liveIds: c.live,
        intersectWithLiveIds: true,
      );
      // The sentinel never leaks into the committed ids.
      expect(result.ids.contains(kCategoryPickerUnassignedSentinel), isFalse);
      // includesUnassigned exactly mirrors the raw set.
      expect(
        result.includesUnassigned,
        c.raw.contains(kCategoryPickerUnassignedSentinel),
      );
      // With intersect on, every committed id is live.
      expect(result.ids.difference(c.live), isEmpty);
    }, tags: 'glados');
  });

  group('single mode', () {
    testWidgets('renders every category', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: testCategories,
            ),
          ),
        ),
      );

      expect(find.text('Category 1'), findsOneWidget);
      expect(find.text('Category 2'), findsOneWidget);
      expect(find.text('Category 3'), findsOneWidget);
    });

    testWidgets('tapping a row applies and pops CategoryPicked', (
      tester,
    ) async {
      final result = await pickSingle(
        tester,
        interact: () => tester.tap(find.text('Category 2')),
      );

      expect(result, isA<CategoryPicked>());
      expect((result! as CategoryPicked).category.id, 'cat2');
      expect(result.categoryOrNull?.id, 'cat2');
      // Route was popped: the launcher button is visible again.
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('pins the current category at the top with a clear row', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: testCategories,
              currentCategoryId: 'cat2',
            ),
          ),
        ),
      );

      // Clear row present, current category shown.
      expect(
        find.byKey(const ValueKey('category-picker-clear')),
        findsOneWidget,
      );
      // The current (cat2) is pinned above the favorite (cat1).
      final yCurrent = tester
          .getTopLeft(find.byKey(const ValueKey('category-picker-row-cat2')))
          .dy;
      final yFavorite = tester
          .getTopLeft(find.byKey(const ValueKey('category-picker-row-cat1')))
          .dy;
      expect(yCurrent, lessThan(yFavorite));
    });

    testWidgets('tapping the clear row pops CategoryCleared', (tester) async {
      final result = await pickSingle(
        tester,
        currentCategoryId: 'cat2',
        interact: () =>
            tester.tap(find.byKey(const ValueKey('category-picker-clear'))),
      );

      expect(result, isA<CategoryCleared>());
      expect(result.isExplicitClear, isTrue);
      expect(result.categoryOrNull, isNull);
    });

    testWidgets('search filters the list to matching categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: testCategories,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Category 1');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('category-picker-row-cat1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('category-picker-row-cat2')),
        findsNothing,
      );
      expect(find.text('Category 3'), findsNothing);
    });

    testWidgets('orders favorites before others with a divider between', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: testCategories,
            ),
          ),
        ),
      );

      final yFavorite = tester
          .getTopLeft(find.byKey(const ValueKey('category-picker-row-cat1')))
          .dy;
      final yOther = tester
          .getTopLeft(find.byKey(const ValueKey('category-picker-row-cat2')))
          .dy;
      expect(yFavorite, lessThan(yOther));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('offers to create a category when the search has no matches', (
      tester,
    ) async {
      registerAllFallbackValues();
      final mockRepository = MockCategoryRepository();
      when(
        () => mockRepository.createCategory(
          name: any(named: 'name'),
          color: any(named: 'color'),
          icon: any(named: 'icon'),
        ),
      ).thenAnswer(
        (_) async => CategoryTestUtils.createTestCategory(
          id: 'cat-new',
          name: 'BrandNew',
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: testCategories,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'BrandNew');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('category-picker-create')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('category-picker-create')));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryCreateModal), findsOneWidget);
    });

    testWidgets('shows an empty-state message when nothing matches and create '
        'is disabled', (tester) async {
      await tester.pumpWidget(
        const WidgetTestBench(
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: [],
              allowCreate: false,
            ),
          ),
        ),
      );

      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('row semantics expose favorite and private badge state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        WidgetTestBench(
          child: Material(
            child: CategoryPickerSheet(
              mode: CategoryPickerMode.single,
              options: testCategories,
            ),
          ),
        ),
      );

      final favorite = tester.getSemantics(
        find.byKey(const ValueKey('category-picker-row-cat1')),
      );
      expect(favorite.label, contains('Category 1'));
      expect(favorite.label, contains('Favorite'));

      final private = tester.getSemantics(
        find.byKey(const ValueKey('category-picker-row-cat3')),
      );
      expect(private.label, contains('Private'));

      handle.dispose();
    });
  });

  group('multi mode', () {
    testWidgets('tapping a row toggles it in the staged set', (tester) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await tester.pumpWidget(pumpMulti(staged));

      await tester.tap(find.text('Category 1'));
      await tester.pump();
      expect(staged.value, {'cat1'});

      await tester.tap(find.text('Category 1'));
      await tester.pump();
      expect(staged.value, isEmpty);
    });

    testWidgets('renders a seeded selection as checked', (tester) async {
      final staged = ValueNotifier<Set<String>>({'cat2'});
      addTearDown(staged.dispose);

      await tester.pumpWidget(pumpMulti(staged));

      final checkbox = tester.widget<DesignSystemCheckbox>(
        find.descendant(
          of: find.byKey(const ValueKey('category-picker-row-cat2')),
          matching: find.byType(DesignSystemCheckbox),
        ),
      );
      expect(checkbox.value, isTrue);

      final unchecked = tester.widget<DesignSystemCheckbox>(
        find.descendant(
          of: find.byKey(const ValueKey('category-picker-row-cat1')),
          matching: find.byType(DesignSystemCheckbox),
        ),
      );
      expect(unchecked.value, isFalse);
    });

    testWidgets('the unassigned row toggles the sentinel', (tester) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await tester.pumpWidget(pumpMulti(staged, showUnassignedRow: true));

      await tester.tap(
        find.byKey(const ValueKey('category-picker-unassigned')),
      );
      await tester.pump();
      expect(staged.value, {kCategoryPickerUnassignedSentinel});
    });

    testWidgets('no unassigned row unless requested', (tester) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await tester.pumpWidget(pumpMulti(staged));

      expect(
        find.byKey(const ValueKey('category-picker-unassigned')),
        findsNothing,
      );
    });
  });

  group('helper integration (Wolt modal)', () {
    testWidgets('showCategoryPicker resolves to the tapped category', (
      tester,
    ) async {
      CategorySingleResult? result;
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showCategoryPicker(
                    context: context,
                    title: 'Pick a category',
                    options: testCategories,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Category 2'));
      await tester.pumpAndSettle();

      expect(result, isA<CategoryPicked>());
      expect((result! as CategoryPicked).category.id, 'cat2');
    });

    testWidgets('showCategoryMultiPicker commits the staged set on Apply', (
      tester,
    ) async {
      CategoryMultiResult? result;
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showCategoryMultiPicker(
                    context: context,
                    title: 'Pick categories',
                    initialSelectedIds: const {},
                    options: testCategories,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Category 1'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('category-picker-apply')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.ids, {'cat1'});
      expect(result!.includesUnassigned, isFalse);
      expect(result!.changed, isTrue);
    });
  });
}
