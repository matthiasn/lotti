import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_navigation_sidebar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_detail_pane.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_detail_showcase.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const viewportSize = Size(1600, 1000);

  Widget wrap(ProviderContainer container) {
    return makeTestableWidget2(
      UncontrolledProviderScope(
        container: container,
        child: Theme(
          data: DesignSystemTheme.dark(),
          child: const Scaffold(
            body: SizedBox(
              width: 1600,
              height: 1000,
              child: ProjectListDetailShowcase(),
            ),
          ),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: viewportSize),
    );
  }

  /// Pumps the showcase with a fresh container and a wide surface so the full
  /// desktop list+detail layout renders. Returns the container for state
  /// assertions; the surface size is reset on tear down.
  Future<ProviderContainer> pumpShowcase(WidgetTester tester) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(wrap(container));
    await tester.pump();
    return container;
  }

  ProjectListDetailState readState(ProviderContainer container) =>
      container.read(projectListDetailShowcaseControllerProvider);

  group('ProjectListDetailShowcase', () {
    testWidgets('renders both list and detail panes for initial selection', (
      tester,
    ) async {
      final container = await pumpShowcase(tester);

      // The first mock project is selected by default and rendered in the
      // detail pane.
      expect(
        readState(container).selectedProject?.project.data.title,
        'Device Sync',
      );
      expect(find.byType(ProjectListPane), findsOneWidget);
      expect(find.byType(ProjectDetailPane), findsOneWidget);

      // "Device Sync" appears in both the list row and the detail header.
      expect(find.text('Device Sync'), findsAtLeastNWidgets(2));
      expect(find.text('Health Score'), findsOneWidget);
    });

    testWidgets('updates the detail pane when a list project is selected', (
      tester,
    ) async {
      final container = await pumpShowcase(tester);

      await tester.tap(find.text('API Migration').first);
      await tester.pump();

      expect(
        readState(container).selectedProject?.project.meta.id,
        'api-migration',
      );
      expect(find.byType(ProjectDetailPane), findsOneWidget);
      // The detail pane now renders content unique to the API Migration
      // project's report.
      expect(find.textContaining('legacy webhook bridge'), findsOneWidget);
    });

    testWidgets(
      'tapping a sidebar destination invokes the no-op selection callback '
      '(line 45)',
      (tester) async {
        final container = await pumpShowcase(tester);

        final selectedBefore = readState(container).selectedProjectId;

        // "My Daily" only exists as a sidebar nav destination (not the top bar
        // title nor any project row), so tapping it routes through the
        // sidebar's onDestinationSelected -> the showcase no-op closure.
        final myDaily = find.descendant(
          of: find.byType(DesktopNavigationSidebar),
          matching: find.text('My Daily'),
        );
        expect(myDaily, findsOneWidget);

        await tester.tap(myDaily);
        await tester.pump();

        // The no-op closure does nothing: no exception, selection unchanged,
        // active tab stays on Projects (the showcase hard-codes activeIndex).
        expect(tester.takeException(), isNull);
        expect(readState(container).selectedProjectId, selectedBefore);
        expect(
          tester
              .widget<DesktopNavigationSidebar>(
                find.byType(DesktopNavigationSidebar),
              )
              .activeIndex,
          2,
        );
      },
    );

    testWidgets(
      'clearing the search routes through onSearchCleared (lines 68-69)',
      (tester) async {
        final container = await pumpShowcase(tester);

        // Type a query so the clear (cancel) icon appears.
        await tester.enterText(find.byType(TextField).first, 'Device');
        await tester.pump();
        expect(readState(container).searchQuery, 'Device');

        // Tap the clear icon -> onSearchCleared -> updateSearchQuery('').
        final clearIcon = find.byIcon(Icons.cancel_rounded).first;
        await tester.ensureVisible(clearIcon);
        await tester.tap(clearIcon);
        await tester.pump();

        expect(readState(container).searchQuery, '');
      },
    );

    testWidgets(
      'pressing the filter icon opens the projects filter modal '
      '(lines 70-74)',
      (tester) async {
        await pumpShowcase(tester);

        final filterIcon = find.byIcon(Icons.filter_list_rounded).first;
        await tester.ensureVisible(filterIcon);
        await tester.tap(filterIcon);
        await tester.pumpAndSettle();

        // showProjectsFilterModal renders the shared filter sheet, whose title
        // and the category list seeded from state.data.categories prove the
        // initialFilter/categories arguments were forwarded.
        expect(find.text('Tasks Filter'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
      },
    );

    testWidgets(
      'applying a category filter forwards onApplied to the controller '
      '(lines 70-74)',
      (tester) async {
        final container = await pumpShowcase(tester);

        await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
        await tester.pumpAndSettle();

        // Drill into the category selection modal and pick the "Study"
        // category (seeded from state.data.categories).
        final categoryField = find.byKey(
          const ValueKey('design-system-task-filter-field-category'),
        );
        await tester.ensureVisible(categoryField);
        await tester.tap(categoryField);
        await tester.pumpAndSettle();

        final studyOption = find.byKey(
          const ValueKey('design-system-filter-selection-option-study'),
        );
        await tester.ensureVisible(studyOption);
        await tester.tap(studyOption);
        await tester.pump();

        await tester.tap(
          find.byKey(
            const ValueKey('design-system-filter-selection-apply'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('design-system-task-filter-apply')),
        );
        await tester.pumpAndSettle();

        // onApplied -> controller.updateFilter narrows the visible projects to
        // the Study category, and selection re-homes onto a still-visible one.
        final state = readState(container);
        expect(state.filter.selectedCategoryIds, {'study'});
        expect(
          state.visibleProjects.map((record) => record.category?.id).toSet(),
          {'study'},
        );
        expect(state.selectedProject?.category?.id, 'study');
      },
    );
  });
}
