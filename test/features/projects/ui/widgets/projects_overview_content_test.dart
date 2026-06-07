import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

Future<void> _pumpContent(
  WidgetTester tester, {
  required List<ProjectCategoryGroup> groups,
  required ValueChanged<ProjectListItemData> onProjectTap,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: ProjectsOverviewContent(
              title: 'Projects',
              groups: groups,
              onProjectTap: onProjectTap,
            ),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(402, 874)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'projects header sits outside the CustomScrollView so scroll gestures '
    'do not drag the title',
    (tester) async {
      await _pumpContent(tester, groups: const [], onProjectTap: (_) {});

      final headerFinder = find.byType(ProjectsHeader);
      final scrollFinder = find.byType(CustomScrollView);

      expect(headerFinder, findsOneWidget);
      expect(scrollFinder, findsOneWidget);

      // Header must not be inside the scroll view — otherwise the title
      // would scroll with the list (regression for the Figma static header).
      expect(
        find.descendant(of: scrollFinder, matching: headerFinder),
        findsNothing,
      );
    },
  );

  testWidgets('empty groups render the NoResultsPane instead of the list', (
    tester,
  ) async {
    await _pumpContent(tester, groups: const [], onProjectTap: (_) {});

    expect(find.byType(NoResultsPane), findsOneWidget);
    expect(find.byType(ProjectsOverviewSliverList), findsNothing);
  });

  testWidgets('non-empty groups render their projects and no empty pane', (
    tester,
  ) async {
    await _pumpContent(
      tester,
      groups: [
        ProjectCategoryGroup(
          categoryId: 'cat-1',
          category: null,
          projects: [
            makeTestProjectListItemData(
              project: makeTestProject(id: 'p1', title: 'Apollo'),
            ),
          ],
        ),
      ],
      onProjectTap: (_) {},
      overrides: noOneLinerOverrides(['p1']),
    );

    expect(find.text('Apollo'), findsOneWidget);
    expect(find.byType(NoResultsPane), findsNothing);
  });

  testWidgets('forwards project taps to onProjectTap with the tapped item', (
    tester,
  ) async {
    final item = makeTestProjectListItemData(
      project: makeTestProject(id: 'p-tap', title: 'Tap Me'),
    );
    ProjectListItemData? tapped;

    await _pumpContent(
      tester,
      groups: [
        ProjectCategoryGroup(
          categoryId: 'cat-1',
          category: null,
          projects: [item],
        ),
      ],
      onProjectTap: (i) => tapped = i,
      overrides: noOneLinerOverrides(['p-tap']),
    );

    await tester.tap(find.text('Tap Me'));
    await tester.pump();

    expect(tapped?.project.meta.id, 'p-tap');
  });
}
