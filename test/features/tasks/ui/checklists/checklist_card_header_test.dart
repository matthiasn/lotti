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

    testWidgets('normal expanded mode shows title, chevron, menu, filters',
        (tester) async {
      await tester.pumpWidget(buildHeader(title: 'My Checklist'));

      expect(find.text('My Checklist'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsNothing);
      expect(find.byType(ChecklistFilterTabs), findsOneWidget);
      expect(find.byType(ChecklistProgressIndicator), findsWidgets);
    });

    testWidgets('sorting mode shows drag handle, hides chevron and menu',
        (tester) async {
      await tester.pumpWidget(buildHeader(isSortingMode: true));

      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });

    testWidgets(
        'drag handle wrapped in ReorderableDragStartListener when reorderIndex provided',
        (tester) async {
      await tester.pumpWidget(
        buildHeader(isSortingMode: true, reorderIndex: 0),
      );
      expect(find.byType(ReorderableDragStartListener), findsOneWidget);

      // Without reorderIndex, no ReorderableDragStartListener
      await tester.pumpWidget(buildHeader(isSortingMode: true));
      expect(find.byType(ReorderableDragStartListener), findsNothing);
    });

    testWidgets('hides filter tabs when collapsed', (tester) async {
      await tester.pumpWidget(buildHeader(isExpanded: false));

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
      await tester.pumpWidget(buildHeader(totalCount: 0));

      final crossFades = tester.widgetList<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      final hiddenCount = crossFades
          .where((cf) => cf.crossFadeState == CrossFadeState.showSecond)
          .length;
      expect(hiddenCount, greaterThanOrEqualTo(3));
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
      await tester.pumpWidget(buildHeader(onDelete: () {}));

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete checklist?'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
