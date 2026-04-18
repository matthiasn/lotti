import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/pages/projects_tab_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_finders.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';
import '../../test_utils.dart';

void main() {
  late MockUserActivityService mockUserActivityService;

  ProjectCategoryGroup buildWorkGroup() {
    final category = CategoryTestUtils.createTestCategory(
      id: 'work',
      name: 'Work',
    );

    return ProjectCategoryGroup(
      categoryId: category.id,
      category: category,
      projects: [
        ProjectListItemData(
          project: makeTestProject(
            id: 'project-1',
            title: 'Device Sync',
            status: ProjectStatus.active(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            categoryId: category.id,
            targetDate: DateTime(2024, 3, 27),
          ),
          category: category,
          taskRollup: const ProjectTaskRollupData(
            totalTaskCount: 5,
            completedTaskCount: 3,
            blockedTaskCount: 1,
          ),
        ),
        ProjectListItemData(
          project: makeTestProject(
            id: 'project-2',
            title: 'API Migration',
            status: ProjectStatus.completed(
              id: 'status-2',
              createdAt: DateTime(2024, 3, 16),
              utcOffset: 0,
            ),
            categoryId: category.id,
            targetDate: DateTime(2024, 3, 30),
          ),
          category: category,
          taskRollup: const ProjectTaskRollupData(
            totalTaskCount: 3,
            completedTaskCount: 3,
          ),
        ),
      ],
    );
  }

  ProjectCategoryGroup buildStudyGroup() {
    final category = CategoryTestUtils.createTestCategory(
      id: 'study',
      name: 'Study',
    );

    return ProjectCategoryGroup(
      categoryId: category.id,
      category: category,
      projects: [
        ProjectListItemData(
          project: makeTestProject(
            id: 'project-3',
            title: 'React Course',
            categoryId: category.id,
          ),
          category: category,
          taskRollup: const ProjectTaskRollupData(totalTaskCount: 2),
        ),
      ],
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<ProjectCategoryGroup> groups,
    MediaQueryData? mediaQueryData,
    ThemeData? theme,
    bool overrideVisibleGroups = true,
  }) async {
    final snapshot = ProjectsOverviewSnapshot(groups: groups);
    final overrides = [
      projectsOverviewProvider.overrideWith(
        (ref) => Stream.value(snapshot),
      ),
      if (overrideVisibleGroups)
        visibleProjectGroupsProvider.overrideWith(
          (ref) => AsyncValue.data(groups),
        ),
    ];

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ProjectsTabPage(),
        mediaQueryData: mediaQueryData,
        theme: theme ?? withOverrides(ThemeData.dark(useMaterial3: true)),
        overrides: overrides,
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    mockUserActivityService = MockUserActivityService();
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<UserActivityService>(mockUserActivityService);
        final mockNavService = MockNavService();
        when(() => mockNavService.isDesktopMode).thenReturn(false);
        when(
          () => mockNavService.desktopSelectedProjectId,
        ).thenReturn(ValueNotifier<String?>(null));
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  testWidgets('renders grouped projects with an enabled search bar', (
    tester,
  ) async {
    await pumpPage(
      tester,
      groups: [buildWorkGroup(), buildStudyGroup()],
    );

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2 projects'), findsOneWidget);
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('API Migration'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(findRichTextContaining('5 tasks'), findsOneWidget);
    expect(findRichTextContaining('Due Mar 27'), findsOneWidget);
    expect(find.bySemanticsLabel('New Project'), findsOneWidget);
    expect(find.byType(DesignSystemBottomNavigationFabPadding), findsOneWidget);
    expect(find.byType(DesignSystemFloatingActionButton), findsOneWidget);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isTrue);
  });

  testWidgets('renders the grouped projects page in light theme', (
    tester,
  ) async {
    await pumpPage(
      tester,
      groups: [buildWorkGroup(), buildStudyGroup()],
      theme: withOverrides(ThemeData.light(useMaterial3: true)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2 projects'), findsOneWidget);
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('row tap opens the top-level project detail route', (
    tester,
  ) async {
    var navigatedPath = '';
    beamToNamedOverride = (path) => navigatedPath = path;

    await pumpPage(
      tester,
      groups: [buildWorkGroup()],
    );

    await tester.tap(find.text('Device Sync'));
    await tester.pump();

    expect(
      navigatedPath,
      '/projects/project-1',
    );
  });

  testWidgets('create button opens the project create route', (
    tester,
  ) async {
    var navigatedPath = '';
    beamToNamedOverride = (path) => navigatedPath = path;

    await pumpPage(
      tester,
      groups: [buildWorkGroup()],
    );

    await tester.tap(find.bySemanticsLabel('New Project'));
    await tester.pump();

    expect(
      navigatedPath,
      '/settings/projects/create',
    );
  });

  testWidgets('opens the shared filter modal from the header icon', (
    tester,
  ) async {
    await pumpPage(
      tester,
      groups: [buildWorkGroup(), buildStudyGroup()],
    );

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tasks Filter'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
  });

  testWidgets('opens the shared DS status picker from the filter sheet', (
    tester,
  ) async {
    await pumpPage(
      tester,
      groups: [buildWorkGroup(), buildStudyGroup()],
    );

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    final statusField = find.byKey(
      const ValueKey('design-system-task-filter-field-status'),
    );
    await tester.ensureVisible(statusField);
    await tester.pumpAndSettle();
    await tester.tap(statusField);
    await tester.pumpAndSettle();

    // Selection modal content is rendered inline (no separate sheet widget)
    expect(find.byType(DesignSystemCheckbox), findsNWidgets(5));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('renders the same grouped data on phone and desktop widths', (
    tester,
  ) async {
    final groups = [buildWorkGroup(), buildStudyGroup()];

    await pumpPage(
      tester,
      groups: groups,
      mediaQueryData: phoneMediaQueryData,
    );
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('React Course'), findsOneWidget);

    // Set view size so isDesktopLayout actually returns true
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(
      tester,
      groups: groups,
      mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
    );
    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('React Course'), findsOneWidget);
    expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 540,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'desktop layout shows detail page when project is selected',
    (tester) async {
      final navService = getIt<NavService>() as MockNavService;
      final selectedNotifier = ValueNotifier<String?>('project-1');
      when(
        () => navService.desktopSelectedProjectId,
      ).thenReturn(selectedNotifier);

      // Suppress errors from the detail page — we only need the
      // branching code in ProjectsTabPage to be exercised.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {};
      addTearDown(() => FlutterError.onError = originalOnError);

      await pumpPage(
        tester,
        groups: [buildWorkGroup()],
        mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
      );

      expect(find.byType(DesktopDetailEmptyState), findsNothing);
      expect(find.byType(ProjectDetailsPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows no-results message when groups are empty', (
    tester,
  ) async {
    await pumpPage(tester, groups: []);

    expect(
      find.text('No projects match your search.'),
      findsOneWidget,
    );
  });

  testWidgets('filters visible projects by substring search', (tester) async {
    await pumpPage(
      tester,
      groups: [buildWorkGroup(), buildStudyGroup()],
      overrideVisibleGroups: false,
    );

    await tester.enterText(find.byType(TextField), 'sync');
    await tester.pump();

    expect(find.text('Device Sync'), findsOneWidget);
    expect(find.text('API Migration'), findsNothing);
    expect(find.text('React Course'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Study'), findsNothing);
    expect(find.text('1 project'), findsOneWidget);
  });

  testWidgets('shows loading indicator while data is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ProjectsTabPage(),
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        overrides: [
          projectsOverviewProvider.overrideWith(
            (ref) => Stream.value(
              ProjectsOverviewSnapshot(groups: [buildWorkGroup()]),
            ),
          ),
          visibleProjectGroupsProvider.overrideWith(
            (ref) => const AsyncValue<List<ProjectCategoryGroup>>.loading(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
    );
  });

  testWidgets('shows localized error message on failure', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ProjectsTabPage(),
        theme: withOverrides(ThemeData.dark(useMaterial3: true)),
        overrides: [
          projectsOverviewProvider.overrideWith(
            (ref) => Stream.value(
              ProjectsOverviewSnapshot(groups: [buildWorkGroup()]),
            ),
          ),
          visibleProjectGroupsProvider.overrideWith(
            (ref) => AsyncValue<List<ProjectCategoryGroup>>.error(
              Exception('test'),
              StackTrace.empty,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets(
    'applies filter state when apply button is tapped in the filter modal',
    (tester) async {
      await pumpPage(
        tester,
        groups: [buildWorkGroup(), buildStudyGroup()],
      );

      // Open the filter modal
      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tasks Filter'), findsOneWidget);

      // Tap the apply button
      final applyButton = find.byKey(
        const ValueKey('design-system-task-filter-apply'),
      );
      await tester.ensureVisible(applyButton);
      await tester.pumpAndSettle();
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // Verify the filter modal has closed
      expect(find.text('Tasks Filter'), findsNothing);
    },
  );

  group('active-filter chip row', () {
    testWidgets('is hidden when no status or category filters are selected', (
      tester,
    ) async {
      await pumpPage(
        tester,
        groups: [buildWorkGroup()],
      );

      expect(find.byType(ActiveFilterChip), findsNothing);
    });

    testWidgets(
      'renders one chip per selected status and clears that status when '
      'the chip is tapped',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
        );

        // Seed the filter controller with a status selection before asserting.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectsTabPage)),
        );
        container
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedStatusIds(
              const {ProjectStatusFilterIds.active},
            );
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsOneWidget);

        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pumpAndSettle();

        expect(
          container.read(projectsFilterControllerProvider).selectedStatusIds,
          isEmpty,
        );
      },
    );

    testWidgets(
      'renders one chip per selected category and clears that category '
      'when the chip is tapped',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectsTabPage)),
        );
        container
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedCategoryIds(const {'work'});
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsOneWidget);

        await tester.tap(find.byType(ActiveFilterChip));
        await tester.pumpAndSettle();

        expect(
          container.read(projectsFilterControllerProvider).selectedCategoryIds,
          isEmpty,
        );
      },
    );
  });

  group('desktop split layout', () {
    testWidgets(
      'renders a ResizableDivider between list and detail panes so the '
      'user can adjust the list-pane width',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
          mediaQueryData: const MediaQueryData(size: Size(1280, 800)),
        );

        expect(find.byType(ResizableDivider), findsOneWidget);
        // And the detail pane is present (empty-state placeholder when no
        // project is selected).
        expect(find.byType(DesktopDetailEmptyState), findsOneWidget);
      },
    );
  });

  group('header search wiring', () {
    testWidgets(
      'typing into the search field updates the projects filter '
      'controller textQuery',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectsTabPage)),
        );

        await tester.enterText(find.byType(TextField), 'device');
        await tester.pump();

        expect(
          container.read(projectsFilterControllerProvider).textQuery,
          'device',
        );
      },
    );

    testWidgets(
      'clearing the search via the TextField ✕ resets the controller to '
      'an empty query',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectsTabPage)),
        );

        await tester.enterText(find.byType(TextField), 'abc');
        await tester.pump();
        expect(
          container.read(projectsFilterControllerProvider).textQuery,
          'abc',
        );

        await tester.enterText(find.byType(TextField), '');
        await tester.pump();

        expect(
          container.read(projectsFilterControllerProvider).textQuery,
          isEmpty,
        );
      },
    );
  });

  group('_ProjectsTabActiveFilters category resolution', () {
    testWidgets(
      'a selected categoryId that is not present in the overview is '
      'silently skipped (no chip rendered) and does not crash',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectsTabPage)),
        );
        container
            .read(projectsFilterControllerProvider.notifier)
            .setSelectedCategoryIds(const {'ghost-category'});
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsNothing);
      },
    );

    testWidgets(
      'status + category selections render one chip each and update the '
      'controller independently when removed',
      (tester) async {
        await pumpPage(
          tester,
          groups: [buildWorkGroup()],
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProjectsTabPage)),
        );
        container.read(projectsFilterControllerProvider.notifier)
          ..setSelectedStatusIds(const {ProjectStatusFilterIds.active})
          ..setSelectedCategoryIds(const {'work'});
        await tester.pumpAndSettle();

        expect(find.byType(ActiveFilterChip), findsNWidgets(2));

        // Remove only the status chip — find its ActiveFilterChip by its
        // descendant "Active" label to disambiguate from any duplicate
        // Text nodes elsewhere in the tree.
        final statusChip = find.ancestor(
          of: find.text('Active').first,
          matching: find.byType(ActiveFilterChip),
        );
        await tester.tap(statusChip.first);
        await tester.pumpAndSettle();

        final state = container.read(projectsFilterControllerProvider);
        expect(state.selectedStatusIds, isEmpty);
        expect(state.selectedCategoryIds, equals({'work'}));
      },
    );
  });
}
