import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_mobile_list_detail_showcase.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  Widget wrap(
    ProviderContainer container, {
    required ThemeData theme,
    required Size viewportSize,
  }) {
    return makeTestableWidget2(
      UncontrolledProviderScope(
        container: container,
        child: Theme(
          data: theme,
          child: Scaffold(
            body: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: const TaskMobileListDetailShowcase(),
            ),
          ),
        ),
      ),
      mediaQueryData: MediaQueryData(
        size: viewportSize,
        padding: phoneMediaQueryData.padding,
      ),
    );
  }

  group('TaskMobileListDetailShowcase', () {
    late ProviderContainer container;

    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          final mockTimeService = MockTimeService();
          when(mockTimeService.getStream).thenAnswer(
            (_) => const Stream.empty(),
          );
          when(() => mockTimeService.linkedFrom).thenReturn(null);
          getIt.registerSingleton<TimeService>(mockTimeService);
        },
      );
      container = ProviderContainer(
        overrides: [
          taskLiveDataProvider.overrideWith(
            // ignore: avoid_redundant_argument_values
            (ref, taskId) => Future.value(null),
          ),
          taskOneLinerProvider.overrideWith(
            // ignore: avoid_redundant_argument_values
            (ref, taskId) => Future.value(null),
          ),
          agentUpdateStreamProvider.overrideWith(
            (ref, agentId) => const Stream<Set<String>>.empty(),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await tearDownTestGetIt();
    });

    testWidgets('renders split list/detail layout and syncs selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(920, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(920, 920),
        ),
      );
      await tester.pump();

      expect(find.text('Payment confirmation'), findsAtLeastNWidgets(2));
      expect(find.text('AI Task Summary'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('AI Task Summary')).style?.fontSize,
        14,
      );
      expect(
        tester.widget<Text>(find.text('AI Task Summary')).style?.fontWeight,
        FontWeight.w600,
      );
      // Section headers and counts now use the caption token (12px) so the
      // group hierarchy is lighter than the task title (Figma alignment).
      expect(tester.widget<Text>(find.text('Today')).style?.fontSize, 12);
      expect(
        tester.widget<Text>(find.text('Today')).style?.fontWeight,
        FontWeight.w400,
      );
      expect(tester.widget<Text>(find.text('3 tasks')).style?.fontSize, 12);
      expect(
        tester.widget<Text>(find.text('3 tasks')).style?.fontWeight,
        FontWeight.w400,
      );
      expect(tester.widget<Text>(find.text('Read more')).style?.fontSize, 14);
      expect(
        tester.widget<Text>(find.text('User Testing').first).style,
        isNotNull,
      );
      expect(
        tester.widget<Text>(find.text('User Testing').first).style?.fontSize,
        14,
      );
      expect(
        tester.widget<Text>(find.text('User Testing').first).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester
            .widget<TaskListSectionsList>(find.byType(TaskListSectionsList))
            .bottomPadding,
        184,
      );
      expect(find.text('My Daily'), findsOneWidget);

      await tester.tap(find.text('User Testing').first);
      await tester.pump();

      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        'user-testing',
      );
      expect(find.text('User Testing'), findsAtLeastNWidgets(2));
    });

    testWidgets('keeps selection when compact layout navigates back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('User Testing').first);
      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('My Daily'), findsNothing);
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        'user-testing',
      );

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(find.text('Tasks'), findsAtLeastNWidgets(2));
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        'user-testing',
      );
    });

    testWidgets('opens the mobile task filter sheet', (tester) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Tasks Filter'), findsOneWidget);
    });

    testWidgets(
      'opens filter sheet from split-view list screen (line 54/56-57)',
      (tester) async {
        tester.view.physicalSize = const Size(920, 920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrap(
            container,
            theme: DesignSystemTheme.dark(),
            viewportSize: const Size(920, 920),
          ),
        );
        await tester.pump();

        // In split-view mode the Row layout is rendered; tap the filter icon.
        final filterIcon = find.byIcon(Icons.filter_list_rounded).first;
        await tester.ensureVisible(filterIcon);
        await tester.tap(filterIcon);
        await tester.pumpAndSettle();

        expect(find.text('Tasks Filter'), findsOneWidget);
      },
    );

    testWidgets('clears search query in split-view mode (line 60)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(920, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(920, 920),
        ),
      );
      await tester.pump();

      // Type a search query so the clear button appears.
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'User Testing');
      await tester.pump();

      expect(
        container.read(taskListDetailShowcaseControllerProvider).searchQuery,
        'User Testing',
      );

      // Tap the clear (cancel) icon to invoke onSearchCleared.
      final clearButton = find.byIcon(Icons.cancel_rounded).first;
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      await tester.pump();

      expect(
        container.read(taskListDetailShowcaseControllerProvider).searchQuery,
        '',
      );
    });

    testWidgets('clears search query in compact list mode (line 91)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      // Type a search query so the clear button appears.
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Payment');
      await tester.pump();

      expect(
        container.read(taskListDetailShowcaseControllerProvider).searchQuery,
        'Payment',
      );

      // Tap the clear icon to invoke onSearchCleared.
      final clearButton = find.byIcon(Icons.cancel_rounded).first;
      await tester.ensureVisible(clearButton);
      await tester.tap(clearButton);
      await tester.pump();

      expect(
        container.read(taskListDetailShowcaseControllerProvider).searchQuery,
        '',
      );
    });

    testWidgets('shows TaskListActiveFilters chip bar when filter is applied '
        '(lines 180-182)', (tester) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      // Verify no active filter chips yet.
      expect(find.byType(TaskListActiveFilters), findsNothing);

      // Apply a status filter so appliedCount > 0.
      final currentState = container.read(
        taskListDetailShowcaseControllerProvider,
      );
      final withStatusSelected = currentState.filterState.copyWith(
        statusField: currentState.filterState.statusField?.copyWith(
          selectedIds: const {'open'},
        ),
      );
      container
          .read(taskListDetailShowcaseControllerProvider.notifier)
          .updateFilterState(withStatusSelected);
      await tester.pump();

      expect(find.byType(TaskListActiveFilters), findsOneWidget);
      // The active-filters widget shows the applied filter count.
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .filterState
            .appliedCount,
        1,
      );
    });

    testWidgets('shows empty results widget when search matches nothing '
        '(lines 188-189)', (tester) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      expect(find.byType(TaskShowcaseEmptyResults), findsNothing);

      // Enter a query that matches no task title, category, or project.
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'zzznomatch999');
      await tester.pump();

      expect(find.byType(TaskShowcaseEmptyResults), findsOneWidget);
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .visibleSections
            .isEmpty,
        isTrue,
      );
    });

    testWidgets('tapping the FAB in the list screen invokes no-op callback '
        '(line 209)', (tester) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          container,
          theme: DesignSystemTheme.dark(),
          viewportSize: const Size(430, 920),
        ),
      );
      await tester.pump();

      // Capture the selected task id before tapping the FAB.
      final selectedIdBefore = container
          .read(taskListDetailShowcaseControllerProvider)
          .selectedTask
          ?.task
          .meta
          .id;

      // The FAB sits in a Positioned inside the list screen's Stack.
      // ensureVisible scrolls it into view before tapping.
      final fab = find.byType(DesignSystemFloatingActionButton).first;
      await tester.ensureVisible(fab);
      await tester.tap(fab);
      await tester.pump();

      // No state change is expected; the selection must equal the captured
      // value (unchanged), not just be non-null.
      expect(
        container
            .read(taskListDetailShowcaseControllerProvider)
            .selectedTask
            ?.task
            .meta
            .id,
        equals(selectedIdBefore),
      );
    });
  });
}
