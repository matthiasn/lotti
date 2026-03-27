import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SizedBox(width: 402, height: 900, child: child),
        ),
      ),
      mediaQueryData: const MediaQueryData(size: Size(500, 1000)),
    );
  }

  group('ProjectGroupHeader', () {
    testWidgets('renders category tag and project count', (tester) async {
      final data = makeTestProjectListData();
      final group = ProjectListDetailState(
        data: data,
        searchQuery: '',
        selectedProjectId: 'p1',
      ).visibleGroups.first;

      await tester.pumpWidget(
        wrap(
          ProjectGroupHeader(group: group),
        ),
      );
      await tester.pump();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('1 project'), findsOneWidget);
    });
  });

  group('ProjectGroupSection', () {
    testWidgets('renders grouped project cards for the selected group', (
      tester,
    ) async {
      final data = makeTestProjectListData();
      final group = ProjectListDetailState(
        data: data,
        searchQuery: '',
        selectedProjectId: 'p1',
      ).visibleGroups.first;

      await tester.pumpWidget(
        wrap(
          ProjectGroupSection(
            group: group,
            selectedProjectId: 'p1',
            onProjectSelected: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Project Alpha'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-overview-row-p1')),
        findsOneWidget,
      );
    });
  });

  group('ProjectRow', () {
    testWidgets('renders title, task progress, and status tag', (tester) async {
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            showDivider: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Project'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey('project-row-progress-ring-${item.project.meta.id}'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            showDivider: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Project'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
