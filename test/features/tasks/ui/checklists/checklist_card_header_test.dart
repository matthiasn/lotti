import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_header.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_filter_tabs.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/progress_indicator.dart';

import '../../../../test_helper.dart';

void main() {
  group('ChecklistCardHeader', () {
    Widget buildHeader({
      String title = 'Test Checklist',
      bool isExpanded = true,
      bool isSortingMode = false,
      bool isEditingTitle = false,
      int completedCount = 2,
      int totalCount = 4,
      double completionRate = 0.5,
      ChecklistFilter filter = ChecklistFilter.openOnly,
      int? reorderIndex,
      VoidCallback? onToggleExpand,
      VoidCallback? onTitleTap,
      void Function(String?)? onTitleSave,
      VoidCallback? onTitleCancel,
      ValueChanged<ChecklistFilter>? onFilterChanged,
      VoidCallback? onDelete,
      VoidCallback? onExportMarkdown,
      VoidCallback? onShareMarkdown,
    }) {
      return WidgetTestBench(
        child: ChecklistCardHeader(
          title: title,
          isExpanded: isExpanded,
          isSortingMode: isSortingMode,
          isEditingTitle: isEditingTitle,
          completedCount: completedCount,
          totalCount: totalCount,
          completionRate: completionRate,
          filter: filter,
          reorderIndex: reorderIndex,
          onToggleExpand: onToggleExpand ?? () {},
          onTitleTap: onTitleTap ?? () {},
          onTitleSave: onTitleSave ?? (_) {},
          onTitleCancel: onTitleCancel ?? () {},
          onFilterChanged: onFilterChanged ?? (_) {},
          onDelete: onDelete,
          onExportMarkdown: onExportMarkdown,
          onShareMarkdown: onShareMarkdown,
        ),
      );
    }

    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(buildHeader(title: 'My Checklist'));

      expect(find.text('My Checklist'), findsOneWidget);
    });

    testWidgets('shows chevron in normal mode', (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('hides chevron in sorting mode', (tester) async {
      await tester.pumpWidget(buildHeader(isSortingMode: true));

      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('shows drag handle in sorting mode', (tester) async {
      await tester.pumpWidget(buildHeader(isSortingMode: true));

      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    });

    testWidgets('hides drag handle in normal mode', (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.byIcon(Icons.drag_indicator), findsNothing);
    });

    testWidgets('shows menu button in normal mode', (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('hides menu button in sorting mode', (tester) async {
      await tester.pumpWidget(buildHeader(isSortingMode: true));

      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });

    testWidgets('shows filter tabs when expanded and has items',
        (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.byType(ChecklistFilterTabs), findsOneWidget);
    });

    testWidgets('hides filter tabs when collapsed', (tester) async {
      await tester.pumpWidget(buildHeader(
        isExpanded: false,
      ));

      // Filter tabs are in AnimatedCrossFade showing secondChild
      final crossFades = tester.widgetList<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      final hiddenCount = crossFades
          .where((cf) => cf.crossFadeState == CrossFadeState.showSecond)
          .length;
      expect(hiddenCount, greaterThan(0));
    });

    testWidgets('hides filter tabs when empty (totalCount = 0)',
        (tester) async {
      await tester.pumpWidget(buildHeader(
        totalCount: 0,
      ));

      // All AnimatedCrossFades should show secondChild when empty
      final crossFades = tester.widgetList<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      final hiddenCount = crossFades
          .where((cf) => cf.crossFadeState == CrossFadeState.showSecond)
          .length;
      // At least dividers and progress row should be hidden
      expect(hiddenCount, greaterThanOrEqualTo(3));
    });

    testWidgets('shows progress indicator', (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.byType(ChecklistProgressIndicator), findsWidgets);
    });

    testWidgets('calls onToggleExpand when chevron tapped', (tester) async {
      var toggled = false;
      await tester.pumpWidget(buildHeader(
        onToggleExpand: () => toggled = true,
      ));

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('calls onTitleTap when title tapped in expanded mode',
        (tester) async {
      var titleTapped = false;
      await tester.pumpWidget(buildHeader(
        onTitleTap: () => titleTapped = true,
      ));

      // Find the title text and tap it
      await tester.tap(find.text('Test Checklist'));
      await tester.pump();

      expect(titleTapped, isTrue);
    });

    testWidgets('calls onFilterChanged when filter tab tapped', (tester) async {
      ChecklistFilter? selectedFilter;
      await tester.pumpWidget(buildHeader(
        onFilterChanged: (f) => selectedFilter = f,
      ));

      await tester.tap(find.text('All'));
      await tester.pump();

      expect(selectedFilter, ChecklistFilter.all);
    });

    testWidgets('shows delete dialog when delete menu item selected',
        (tester) async {
      await tester.pumpWidget(buildHeader(
        onDelete: () {},
      ));

      // Open menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      // Tap delete
      await tester.tap(find.text('Delete checklist?'));
      await tester.pump();

      // Dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
        'wraps drag handle in ReorderableDragStartListener when reorderIndex provided',
        (tester) async {
      await tester.pumpWidget(buildHeader(
        isSortingMode: true,
        reorderIndex: 0,
      ));

      expect(find.byType(ReorderableDragStartListener), findsOneWidget);
    });

    testWidgets('does not wrap drag handle when reorderIndex is null',
        (tester) async {
      await tester.pumpWidget(buildHeader(
        isSortingMode: true,
      ));

      expect(find.byType(ReorderableDragStartListener), findsNothing);
    });
  });
}
