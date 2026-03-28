import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  List<CategoryDefinition> buildTestCategories() {
    return [
      CategoryTestUtils.createTestCategory(id: 'cat-work', name: 'Work'),
      CategoryTestUtils.createTestCategory(
        id: 'cat-personal',
        name: 'Personal',
      ),
    ];
  }

  Future<void> pumpModalTrigger(
    WidgetTester tester, {
    required ProjectsFilter initialFilter,
    required List<CategoryDefinition> categories,
    required ValueChanged<ProjectsFilter> onApplied,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const ValueKey('open-filter-modal'),
                  onPressed: () => showProjectsFilterModal(
                    context: context,
                    initialFilter: initialFilter,
                    categories: categories,
                    onApplied: onApplied,
                    presentation: DesignSystemFilterPresentation.desktop,
                  ),
                  child: const Text('Open Filter'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'opens desktop filter modal with status and category fields',
    (tester) async {
      await pumpModalTrigger(
        tester,
        initialFilter: const ProjectsFilter(),
        categories: buildTestCategories(),
        onApplied: (_) {},
      );

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Apply filter'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
    },
  );

  testWidgets('applies filter when apply button is tapped', (tester) async {
    ProjectsFilter? appliedFilter;

    await pumpModalTrigger(
      tester,
      initialFilter: const ProjectsFilter(),
      categories: buildTestCategories(),
      onApplied: (filter) => appliedFilter = filter,
    );

    await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
    await tester.pump(const Duration(milliseconds: 500));

    final applyButton = find.byKey(
      const ValueKey('design-system-task-filter-apply'),
    );
    await tester.ensureVisible(applyButton);
    await tester.tap(applyButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(appliedFilter, isNotNull);
    expect(appliedFilter!.selectedStatusIds, isEmpty);
    expect(appliedFilter!.selectedCategoryIds, isEmpty);
  });

  testWidgets(
    'status selection modal opens with five status options and icons',
    (tester) async {
      await pumpModalTrigger(
        tester,
        initialFilter: const ProjectsFilter(),
        categories: buildTestCategories(),
        onApplied: (_) {},
      );

      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pump(const Duration(milliseconds: 500));

      final statusField = find.byKey(
        const ValueKey('design-system-task-filter-field-status'),
      );
      await tester.ensureVisible(statusField);
      await tester.pumpAndSettle();
      await tester.tap(statusField);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DesignSystemFilterSelectionSheet), findsOneWidget);
      expect(find.byType(DesignSystemCheckbox), findsNWidgets(5));
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('On Hold'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      // Status options should have icons from projectStatusAttributes
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'applies filter with selected status after status selection',
    (tester) async {
      ProjectsFilter? appliedFilter;

      await pumpModalTrigger(
        tester,
        initialFilter: const ProjectsFilter(),
        categories: buildTestCategories(),
        onApplied: (filter) => appliedFilter = filter,
      );

      // Open the filter modal
      await tester.tap(find.byKey(const ValueKey('open-filter-modal')));
      await tester.pump(const Duration(milliseconds: 500));

      // Open the status selection modal
      final statusField = find.byKey(
        const ValueKey('design-system-task-filter-field-status'),
      );
      await tester.ensureVisible(statusField);
      await tester.pumpAndSettle();
      await tester.tap(statusField);
      await tester.pump(const Duration(milliseconds: 500));

      // Select the "Active" status option
      final activeOption = find.byKey(
        const ValueKey('design-system-filter-selection-option-active'),
      );
      await tester.ensureVisible(activeOption);
      await tester.tap(activeOption);
      await tester.pump();

      // Confirm selection
      final selectionDone = find.byKey(
        const ValueKey('design-system-filter-selection-apply'),
      );
      await tester.ensureVisible(selectionDone);
      await tester.tap(selectionDone);
      await tester.pump(const Duration(milliseconds: 500));

      // Apply the filter from the main filter modal
      final applyButton = find.byKey(
        const ValueKey('design-system-task-filter-apply'),
      );
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(appliedFilter, isNotNull);
      expect(
        appliedFilter!.selectedStatusIds,
        {ProjectStatusFilterIds.active},
      );
    },
  );
}
