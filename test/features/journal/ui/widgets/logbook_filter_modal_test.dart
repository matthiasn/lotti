import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/ui/widgets/logbook_filter_modal.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

/// Minimal host page whose button invokes [showLogbookFilterModal] with a
/// context inside the test ProviderScope — the same way the logbook header's
/// filter icon calls it in production.
class _ModalLauncher extends StatelessWidget {
  const _ModalLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showLogbookFilterModal(context),
          child: const Text('open filter'),
        ),
      ),
    );
  }
}

void main() {
  late FakeJournalPageController fakeController;

  /// Pumps [child] with the page controller pinned to [state] for the
  /// journal (non-tasks) scope.
  Widget buildBench({
    required JournalPageState state,
    required Widget child,
  }) {
    fakeController = FakeJournalPageController(state);
    return makeTestableWidgetNoScroll(
      child,
      overrides: [
        journalPageScopeProvider.overrideWithValue(false),
        journalPageControllerProvider(
          false,
        ).overrideWith(() => fakeController),
      ],
    );
  }

  group('JournalFilter', () {
    JournalPageState createState({
      Set<DisplayFilter> filters = const {},
    }) {
      return JournalPageState(
        filters: filters,
        fullTextMatches: {},
        taskStatuses: const ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {},
      );
    }

    Widget buildSubject(JournalPageState state) => buildBench(
      state: state,
      child: const Scaffold(body: JournalFilter()),
    );

    testWidgets('renders three multi-select filter pills with icons', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pump();

      expect(find.byType(DesignSystemFilterChoicePill), findsNWidgets(3));

      // Each toggle carries its rounded icon (state-independent).
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    });

    testWidgets('active filters render as selected pills', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          createState(
            filters: {
              DisplayFilter.starredEntriesOnly,
              DisplayFilter.flaggedEntriesOnly,
              DisplayFilter.privateEntriesOnly,
            },
          ),
        ),
      );
      await tester.pump();

      final pills = tester.widgetList<DesignSystemFilterChoicePill>(
        find.byType(DesignSystemFilterChoicePill),
      );
      expect(pills.where((pill) => pill.selected).length, 3);
    });

    // Each filter toggles its own DisplayFilter value through setFilters.
    for (final filter in [
      (icon: Icons.star_rounded, value: DisplayFilter.starredEntriesOnly),
      (icon: Icons.flag_rounded, value: DisplayFilter.flaggedEntriesOnly),
      (icon: Icons.shield_rounded, value: DisplayFilter.privateEntriesOnly),
    ]) {
      testWidgets('tapping ${filter.value.name} filter calls setFilters', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(createState()));
        await tester.pump();

        await tester.tap(find.byIcon(filter.icon));
        await tester.pump();

        expect(fakeController.filtersCalls, isNotEmpty);
        expect(fakeController.filtersCalls.last, contains(filter.value));
      });
    }

    testWidgets('toggling a second filter keeps the first (multi-select)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          createState(filters: {DisplayFilter.starredEntriesOnly}),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.flag_rounded));
      await tester.pump();

      expect(
        fakeController.filtersCalls.last,
        containsAll(<DisplayFilter>[
          DisplayFilter.starredEntriesOnly,
          DisplayFilter.flaggedEntriesOnly,
        ]),
      );
    });

    testWidgets('deselecting active filter removes it', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          createState(
            filters: {DisplayFilter.starredEntriesOnly},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.star_rounded));
      await tester.pump();

      expect(fakeController.filtersCalls, isNotEmpty);
      expect(
        fakeController.filtersCalls.last,
        isNot(contains(DisplayFilter.starredEntriesOnly)),
      );
    });
  });

  group('showLogbookFilterModal', () {
    late MockEntitiesCacheService mockEntitiesCacheService;

    final mockCategories = [
      CategoryDefinition(
        id: 'cat1',
        createdAt: DateTime(2023),
        updatedAt: DateTime(2023),
        name: 'Work',
        vectorClock: null,
        private: false,
        active: true,
        favorite: true,
        color: '#FF0000',
      ),
    ];

    setUp(() async {
      mockEntitiesCacheService = MockEntitiesCacheService();
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenReturn(mockCategories);

      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EntitiesCacheService>(
            mockEntitiesCacheService,
          );
        },
      );
    });

    tearDown(tearDownTestGetIt);

    Widget buildSubject() => buildBench(
      state: const JournalPageState(
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
      ),
      child: const _ModalLauncher(),
    );

    Future<void> openModal(WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.tap(find.text('open filter'));
      await tester.pumpAndSettle();
    }

    /// Opens the modal and navigates onto the category sub-page. Returns the
    /// barrier count of the open sheet so callers can assert no nested modal
    /// was pushed.
    Future<int> openCategoryPage(WidgetTester tester) async {
      await openModal(tester);
      final barrierCount = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.byType(TaskCategoryFilterOverviewRow));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCategoryFilter), findsOneWidget);
      return barrierCount;
    }

    testWidgets('opens sheet with display, entry-type, and category sections', (
      tester,
    ) async {
      await openModal(tester);

      expect(find.byType(LogbookFilterSheet), findsOneWidget);
      expect(find.text('Filter journal'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Entry types'), findsOneWidget);
      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(EntryTypeFilter), findsOneWidget);
      expect(find.byType(TaskCategoryFilterOverviewRow), findsOneWidget);
      expect(find.byType(TaskCategoryFilter), findsNothing);
    });

    testWidgets('category row navigates within the same sheet', (
      tester,
    ) async {
      await openModal(tester);

      final barrierCount = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.byType(TaskCategoryFilterOverviewRow));
      await tester.pump(const Duration(milliseconds: 500));

      // The category page replaces the overview inside the same Wolt sheet —
      // no nested modal (which would add a barrier) is pushed.
      expect(find.byType(TaskCategoryFilter), findsOneWidget);
      expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));
    });

    for (final navigation in ['Back button', 'Done']) {
      testWidgets('$navigation returns to the filter overview', (tester) async {
        final barrierCount = await openCategoryPage(tester);

        final target = navigation == 'Done'
            ? find.widgetWithText(DesignSystemButton, 'Done')
            : find.ancestor(
                of: find.byIcon(Icons.arrow_back_rounded),
                matching: find.byType(IconButton),
              );
        await tester.tap(target);
        await tester.pumpAndSettle();

        expect(find.byType(TaskCategoryFilter), findsNothing);
        expect(find.byType(JournalFilter), findsOneWidget);
        expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));
      });
    }

    for (final navigation in ['Escape', 'system back']) {
      testWidgets('$navigation returns to the filter overview', (tester) async {
        final barrierCount = await openCategoryPage(tester);

        if (navigation == 'Escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();

        expect(find.byType(TaskCategoryFilter), findsNothing);
        expect(find.byType(JournalFilter), findsOneWidget);
        expect(find.byType(ModalBarrier), findsNWidgets(barrierCount));
      });
    }

    testWidgets('modal can be closed by tapping outside', (tester) async {
      await openModal(tester);
      expect(find.byType(LogbookFilterSheet), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(LogbookFilterSheet), findsNothing);
    });

    testWidgets(
      "filter changes in the modal land in the caller's controller",
      (tester) async {
        // The modal shares the parent provider container, so toggling a pill
        // must hit the same controller instance the page uses.
        await openModal(tester);

        await tester.tap(find.byIcon(Icons.star_rounded));
        await tester.pump();

        expect(fakeController.filtersCalls, isNotEmpty);
        expect(
          fakeController.filtersCalls.last,
          contains(DisplayFilter.starredEntriesOnly),
        );
      },
    );
  });
}
