import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget sliver, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(body: CustomScrollView(slivers: [sliver])),
        ),
      ),
    );
  }

  group('ProjectsOverviewSliverList', () {
    testWidgets('renders one section per category group with its projects', (
      tester,
    ) async {
      final groups = [
        ProjectCategoryGroup(
          categoryId: 'cat-1',
          category: null,
          projects: [
            makeTestProjectListItemData(
              project: makeTestProject(id: 'p1', title: 'Apollo'),
            ),
          ],
        ),
        ProjectCategoryGroup(
          categoryId: 'cat-2',
          category: null,
          projects: [
            makeTestProjectListItemData(
              project: makeTestProject(id: 'p2', title: 'Borealis'),
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        wrap(
          ProjectsOverviewSliverList(
            groups: groups,
            onProjectTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Apollo'), findsOneWidget);
      expect(find.text('Borealis'), findsOneWidget);
      expect(
        tester
            .widgetList<ProjectGroupSection>(find.byType(ProjectGroupSection))
            .map((section) => section.key),
        const [
          ValueKey('project-group-cat-1'),
          ValueKey('project-group-cat-2'),
        ],
      );
    });

    testWidgets('forwards project taps with the tapped item', (tester) async {
      final item = makeTestProjectListItemData(
        project: makeTestProject(id: 'p-tap', title: 'Tap Me'),
      );
      ProjectListItemData? tapped;

      await tester.pumpWidget(
        wrap(
          ProjectsOverviewSliverList(
            groups: [
              ProjectCategoryGroup(
                categoryId: 'cat-1',
                category: null,
                projects: [item],
              ),
            ],
            onProjectTap: (i) => tapped = i,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, same(item));
    });

    testWidgets('renders nothing for an empty group list', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProjectsOverviewSliverList(
            groups: const [],
            onProjectTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
