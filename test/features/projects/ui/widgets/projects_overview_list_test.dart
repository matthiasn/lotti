import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
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
          overrides: noOneLinerOverrides(['p1', 'p2']),
        ),
      );
      await tester.pump();

      expect(find.text('Apollo'), findsOneWidget);
      expect(find.text('Borealis'), findsOneWidget);
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
          overrides: noOneLinerOverrides(['p-tap']),
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

    List<ProjectCategoryGroup> threeGroups() => [
      for (final (id, title) in const [
        ('cat-1', 'Apollo'),
        ('cat-2', 'Borealis'),
        ('cat-3', 'Cygnus'),
      ])
        ProjectCategoryGroup(
          categoryId: id,
          category: null,
          projects: [
            makeTestProjectListItemData(
              project: makeTestProject(id: 'pj-$id', title: title),
            ),
          ],
        ),
    ];

    const allOverrides = ['pj-cat-1', 'pj-cat-2', 'pj-cat-3'];

    testWidgets('flows sections into two columns on a wide viewport', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrap(
          ProjectsOverviewSliverList(
            groups: threeGroups(),
            onProjectTap: (_) {},
          ),
          overrides: noOneLinerOverrides(allOverrides),
        ),
      );
      await tester.pump();

      expect(find.text('Apollo'), findsOneWidget);
      expect(find.text('Cygnus'), findsOneWidget);

      // Greedy balance places cat-1 in the left column and cat-2 in the right,
      // so the two cards sit side by side (cat-2 starts further right).
      final left = tester.getTopLeft(
        find.byKey(const ValueKey('project-group-card-cat-1')),
      );
      final right = tester.getTopLeft(
        find.byKey(const ValueKey('project-group-card-cat-2')),
      );
      expect(left.dx, lessThan(right.dx));
    });

    testWidgets('stacks sections in one column on a narrow viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectsOverviewSliverList(
            groups: threeGroups(),
            onProjectTap: (_) {},
          ),
          overrides: noOneLinerOverrides(allOverrides),
        ),
      );
      await tester.pump();

      // Default (narrow) surface: the cards share a left edge and stack.
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('project-group-card-cat-1')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('project-group-card-cat-2')),
      );
      expect(first.dx, second.dx);
      expect(first.dy, lessThan(second.dy));
    });
  });

  group('balanceProjectColumns', () {
    ProjectCategoryGroup groupOf(String id, int projectCount) =>
        ProjectCategoryGroup(
          categoryId: id,
          category: null,
          projects: [
            for (var i = 0; i < projectCount; i++)
              makeTestProjectListItemData(
                project: makeTestProject(id: '$id-$i', title: '$id-$i'),
              ),
          ],
        );

    double columnHeight(List<ProjectCategoryGroup> column) =>
        column.fold(0, (sum, group) => sum + 1.5 + group.projectCount);

    test('splits categories into two optimally balanced columns', () {
      // Heights 4.5 / 3.5 / 3.5 / 4.5 → the optimal partition is 8 vs 8.
      final (left, right) = balanceProjectColumns([
        groupOf('a', 3),
        groupOf('b', 2),
        groupOf('c', 2),
        groupOf('d', 3),
      ]);

      expect(left.length + right.length, 4);
      expect(left, isNotEmpty);
      expect(right, isNotEmpty);
      expect(columnHeight(left) - columnHeight(right), 0);
    });

    test('keeps a single category in the first column', () {
      final (left, right) = balanceProjectColumns([groupOf('only', 4)]);

      expect(left, hasLength(1));
      expect(right, isEmpty);
    });

    test('falls back to a greedy fill beyond the brute-force cap', () {
      final groups = [for (var i = 0; i < 16; i++) groupOf('g$i', i % 3 + 1)];

      final (left, right) = balanceProjectColumns(groups);

      expect(left.length + right.length, 16);
      expect(left, isNotEmpty);
      expect(right, isNotEmpty);
      // The greedy fill still keeps the two columns reasonably close in height.
      expect((columnHeight(left) - columnHeight(right)).abs(), lessThan(5));
    });
  });
}
