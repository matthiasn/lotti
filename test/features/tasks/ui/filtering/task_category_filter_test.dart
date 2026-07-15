import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late FakeJournalPageController controller;
  late MockPagingController pagingController;
  late MockEntitiesCacheService cache;

  final categories = [
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
    CategoryDefinition(
      id: 'cat2',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      name: 'Personal',
      vectorClock: null,
      private: false,
      active: true,
      favorite: false,
      color: '#00FF00',
    ),
    CategoryDefinition(
      id: 'cat3',
      createdAt: DateTime(2023),
      updatedAt: DateTime(2023),
      name: 'Health',
      vectorClock: null,
      private: false,
      active: true,
      favorite: true,
      color: '#0000FF',
    ),
  ];

  setUp(() async {
    pagingController = MockPagingController();
    cache = MockEntitiesCacheService();
    when(() => cache.sortedCategories).thenReturn(categories);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  JournalPageState state({Set<String> selectedIds = const {'cat1'}}) {
    return JournalPageState(
      showTasks: true,
      pagingController: pagingController,
      taskStatuses: const ['OPEN'],
      selectedTaskStatuses: const {'OPEN'},
      selectedCategoryIds: selectedIds,
    );
  }

  Widget subject(Widget child, {Set<String> selectedIds = const {'cat1'}}) {
    controller = FakeJournalPageController(state(selectedIds: selectedIds));
    return makeTestableWidget(
      Material(child: child),
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
        journalPageControllerProvider(
          true,
        ).overrideWith(() => controller),
      ],
    );
  }

  Finder row(String title) => find.byWidgetPredicate(
    (widget) => widget is DesignSystemSelectionRow && widget.title == title,
  );

  testWidgets('renders all categories as divider-free searchable rows', (
    tester,
  ) async {
    await tester.pumpWidget(subject(const TaskCategoryFilter()));
    await tester.pump();

    expect(find.byType(DesignSystemSearch), findsOneWidget);
    expect(row('Work'), findsOneWidget);
    expect(row('Personal'), findsOneWidget);
    expect(row('Health'), findsOneWidget);
    expect(find.text('...'), findsNothing);
    expect(
      tester.widget<DesignSystemSelectionRow>(row('Work')).selected,
      isTrue,
    );
    expect(
      tester.getSemantics(row('Work')).flagsCollection.isChecked,
      CheckedState.isTrue,
    );
  });

  testWidgets('category, unassigned, and all rows invoke their exact actions', (
    tester,
  ) async {
    await tester.pumpWidget(subject(const TaskCategoryFilter()));
    await tester.pump();
    final messages = tester.element(find.byType(TaskCategoryFilter)).messages;

    await tester.tap(row('Work'));
    await tester.tap(row(messages.taskCategoryUnassignedLabel));
    await tester.tap(row(messages.taskCategoryAllLabel));

    expect(controller.toggledCategoryIds, ['cat1', '']);
    expect(controller.selectAllCategoriesCalled, 1);
  });

  testWidgets('search is case-insensitive and exposes a live empty state', (
    tester,
  ) async {
    await tester.pumpWidget(subject(const TaskCategoryFilter()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'PER');
    await tester.pump();
    expect(row('Personal'), findsOneWidget);
    expect(row('Work'), findsNothing);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    final emptyLabel = tester
        .element(find.byType(TaskCategoryFilter))
        .messages
        .filterSelectionNoMatches;
    expect(find.text(emptyLabel), findsOneWidget);
    expect(
      tester.getSemantics(find.text(emptyLabel)).flagsCollection.isLiveRegion,
      isTrue,
    );
  });

  testWidgets('clearing search restores special and category rows', (
    tester,
  ) async {
    await tester.pumpWidget(subject(const TaskCategoryFilter()));
    await tester.pump();
    final messages = tester.element(find.byType(TaskCategoryFilter)).messages;

    await tester.enterText(find.byType(TextField), 'personal');
    await tester.pump();
    expect(row('Personal'), findsOneWidget);
    expect(row(messages.taskCategoryAllLabel), findsNothing);

    await tester.tap(find.byIcon(Icons.cancel_rounded));
    await tester.pump();

    expect(row(messages.taskCategoryAllLabel), findsOneWidget);
    expect(row(messages.taskCategoryUnassignedLabel), findsOneWidget);
    expect(row('Work'), findsOneWidget);
    expect(row('Personal'), findsOneWidget);
    expect(row('Health'), findsOneWidget);
  });

  testWidgets('empty catalogs still expose All and Unassigned', (tester) async {
    when(() => cache.sortedCategories).thenReturn([]);
    await tester.pumpWidget(subject(const TaskCategoryFilter()));
    await tester.pump();
    final messages = tester.element(find.byType(TaskCategoryFilter)).messages;

    expect(row(messages.taskCategoryAllLabel), findsOneWidget);
    expect(row(messages.taskCategoryUnassignedLabel), findsOneWidget);
  });

  testWidgets(
    'overview summarizes selection and navigates in the parent flow',
    (
      tester,
    ) async {
      var navigationCalls = 0;
      await tester.pumpWidget(
        subject(
          TaskCategoryFilterOverviewRow(onPressed: () => navigationCalls++),
          selectedIds: const {'cat1', 'cat2', 'cat3', ''},
        ),
      );
      await tester.pump();

      final overview = tester.widget<DesignSystemSelectionRow>(
        find.byType(DesignSystemSelectionRow),
      );
      expect(overview.subtitle, 'Work, Personal +2');
      expect(overview.type, DesignSystemSelectionRowType.navigation);
      await tester.tap(find.byType(DesignSystemSelectionRow));
      expect(navigationCalls, 1);
    },
  );

  testWidgets('overview uses All when no category filter is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        TaskCategoryFilterOverviewRow(onPressed: () {}),
        selectedIds: const {},
      ),
    );
    await tester.pump();
    final messages = tester
        .element(find.byType(TaskCategoryFilterOverviewRow))
        .messages;

    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byType(DesignSystemSelectionRow),
          )
          .subtitle,
      messages.taskCategoryAllLabel,
    );
  });
}
