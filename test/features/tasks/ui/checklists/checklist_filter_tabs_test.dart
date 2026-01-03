import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_filter_tabs.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';

import '../../../../test_helper.dart';

void main() {
  group('ChecklistFilterTabs', () {
    testWidgets('renders Open and All tabs', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTabs(
            filter: ChecklistFilter.openOnly,
            onFilterChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('calls onFilterChanged when Open tab is tapped',
        (tester) async {
      ChecklistFilter? selectedFilter;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTabs(
            filter: ChecklistFilter.all,
            onFilterChanged: (filter) => selectedFilter = filter,
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();

      expect(selectedFilter, ChecklistFilter.openOnly);
    });

    testWidgets('calls onFilterChanged when All tab is tapped', (tester) async {
      ChecklistFilter? selectedFilter;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTabs(
            filter: ChecklistFilter.openOnly,
            onFilterChanged: (filter) => selectedFilter = filter,
          ),
        ),
      );

      await tester.tap(find.text('All'));
      await tester.pump();

      expect(selectedFilter, ChecklistFilter.all);
    });
  });

  group('ChecklistFilterTab', () {
    testWidgets('shows underline when selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTab(
            label: 'Test',
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      // Find the AnimatedOpacity that wraps the underline
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 1.0);
    });

    testWidgets('hides underline when not selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTab(
            label: 'Test',
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      // Find the AnimatedOpacity that wraps the underline
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 0.0);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTab(
            label: 'Test',
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Test'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTab(
            label: 'Custom Label',
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Custom Label'), findsOneWidget);
    });

    testWidgets('uses bold font weight when selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTab(
            label: 'Test',
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Test'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('uses normal font weight when not selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistFilterTab(
            label: 'Test',
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Test'));
      expect(text.style?.fontWeight, FontWeight.w400);
    });
  });
}
