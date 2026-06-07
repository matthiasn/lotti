// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_helper.dart';
import '../../test_utils/fake_journal_page_controller.dart';

void main() {
  late FakeJournalPageController fakeController;

  /// Wraps [child] in the shared bench with the page controller pinned to
  /// [state] for the [scope] tab.
  Widget buildBench({
    required JournalPageState state,
    required Widget child,
    bool scope = false,
  }) {
    fakeController = FakeJournalPageController(state);

    return WidgetTestBench(
      child: ProviderScope(
        overrides: [
          journalPageScopeProvider.overrideWithValue(scope),
          journalPageControllerProvider(
            scope,
          ).overrideWith(() => fakeController),
        ],
        child: child,
      ),
    );
  }

  group('JournalSliverAppBar search mode toggle', () {
    Widget buildSubject(JournalPageState state) => buildBench(
      state: state,
      scope: state.showTasks,
      child: const CustomScrollView(slivers: [JournalSliverAppBar()]),
    );

    testWidgets('toggle is hidden when enableVectorSearch is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            showTasks: true,
            enableVectorSearch: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<SearchMode>),
        findsNothing,
      );
    });

    testWidgets('toggle is visible on journal tab when flag is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            enableVectorSearch: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<SearchMode>),
        findsOneWidget,
      );
    });

    testWidgets('toggle is visible on tasks tab when flag is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            showTasks: true,
            enableVectorSearch: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(SegmentedButton<SearchMode>),
        findsOneWidget,
      );
      // Both segments are visible
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    });

    testWidgets('tapping vector segment calls setSearchMode', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            showTasks: true,
            enableVectorSearch: true,
            searchMode: SearchMode.fullText,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the vector segment
      await tester.tap(find.byIcon(Icons.hub_outlined));
      await tester.pumpAndSettle();

      expect(fakeController.searchModeCalls, contains(SearchMode.vector));
    });

    testWidgets('shows loading indicator when vector search is in-flight', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            showTasks: true,
            enableVectorSearch: true,
            searchMode: SearchMode.vector,
            vectorSearchInFlight: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows timing info after vector search completes', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          const JournalPageState(
            showTasks: true,
            enableVectorSearch: true,
            searchMode: SearchMode.vector,
            vectorSearchElapsed: Duration(milliseconds: 324),
            vectorSearchResultCount: 8,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('324'), findsOneWidget);
      expect(find.textContaining('8'), findsOneWidget);
    });
  });

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

    testWidgets('renders SegmentedButton with three segments', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(SegmentedButton<DisplayFilter>), findsOneWidget);

      // Verify three filter icons are present (starred, flagged, private)
      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('shows filled icons when filters are active', (tester) async {
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
      await tester.pumpAndSettle();

      // Active filters show filled icons
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);

      // Outlined icons should not be present
      expect(find.byIcon(Icons.star_outline), findsNothing);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
    });

    // Each filter toggles its own DisplayFilter value through setFilters.
    for (final filter in [
      (icon: Icons.star_outline, value: DisplayFilter.starredEntriesOnly),
      (icon: Icons.flag_outlined, value: DisplayFilter.flaggedEntriesOnly),
      (icon: Icons.shield_outlined, value: DisplayFilter.privateEntriesOnly),
    ]) {
      testWidgets('tapping ${filter.value.name} filter calls setFilters', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(createState()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(filter.icon));
        await tester.pump();

        expect(fakeController.filtersCalls, isNotEmpty);
        expect(fakeController.filtersCalls.last, contains(filter.value));
      });
    }

    testWidgets('multi-selection is enabled', (tester) async {
      await tester.pumpWidget(buildSubject(createState()));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<DisplayFilter>>(
        find.byType(SegmentedButton<DisplayFilter>),
      );

      expect(segmentedButton.multiSelectionEnabled, isTrue);
      expect(segmentedButton.emptySelectionAllowed, isTrue);
    });

    testWidgets('deselecting active filter removes it', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          createState(
            filters: {DisplayFilter.starredEntriesOnly},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the active starred filter to deselect
      await tester.tap(find.byIcon(Icons.star));
      await tester.pump();

      expect(fakeController.filtersCalls, isNotEmpty);
      expect(
        fakeController.filtersCalls.last,
        isNot(contains(DisplayFilter.starredEntriesOnly)),
      );
    });
  });

  group('JournalFilterIcon', () {
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

    setUp(() {
      mockEntitiesCacheService = MockEntitiesCacheService();
      when(
        () => mockEntitiesCacheService.sortedCategories,
      ).thenReturn(mockCategories);

      getIt.allowReassignment = true;
      getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });

    tearDown(getIt.reset);

    Widget buildSubject() => buildBench(
      state: const JournalPageState(
        taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        selectedTaskStatuses: {'OPEN'},
      ),
      child: const Scaffold(body: JournalFilterIcon()),
    );

    testWidgets('renders filter icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(JournalFilterIcon), findsOneWidget);
      expect(find.byIcon(MdiIcons.filterVariant), findsOneWidget);
    });

    testWidgets('opens modal when tapped', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap on the filter icon
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify the modal contains expected components
      expect(find.byType(JournalFilter), findsOneWidget);
      expect(find.byType(EntryTypeFilter), findsOneWidget);
      expect(find.byType(TaskCategoryFilter), findsOneWidget);
    });

    testWidgets('modal can be closed by tapping outside', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.byIcon(MdiIcons.filterVariant));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(JournalFilter), findsOneWidget);

      // Tap outside the modal (barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.byType(JournalFilter), findsNothing);
    });

    testWidgets('is wrapped in Padding with correct spacing', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Nearest Padding ancestor is the one JournalFilterIcon itself adds.
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byType(IconButton),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsets.only(right: AppTheme.spacingSmall),
      );
    });

    testWidgets(
      'modal filter changes call controller (via UncontrolledProviderScope)',
      (tester) async {
        // This test verifies that filter changes in the modal use the same
        // controller instance as the parent, proving UncontrolledProviderScope
        // correctly shares state.
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.byIcon(MdiIcons.filterVariant));
        await tester.pumpAndSettle();

        // Verify modal is open with JournalFilter
        expect(find.byType(JournalFilter), findsOneWidget);

        // Tap on the starred filter icon in the modal
        await tester.tap(find.byIcon(Icons.star_outline));
        await tester.pump();

        // Verify the controller's setFilters was called
        // This proves the modal is using the same controller instance
        expect(fakeController.filtersCalls, isNotEmpty);
        expect(
          fakeController.filtersCalls.last,
          contains(DisplayFilter.starredEntriesOnly),
        );
      },
    );
  });
}
