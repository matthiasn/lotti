import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_one_liner_provider.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';
import 'package:lotti/features/projects/ui/widgets/shared_tag_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/utils/color.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: SizedBox(width: 402, height: 900, child: child),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(500, 1000)),
      ),
    );
  }

  ProjectCategoryGroup makeGroupedProjectsSection() {
    final workCategory = makeTestProjectListData().categories.first;
    return ProjectCategoryGroup(
      categoryId: workCategory.id,
      category: workCategory,
      projects: [
        makeTestProjectListItemData(
          project: makeTestProject(
            id: 'p1',
            title: 'Project Alpha',
            categoryId: workCategory.id,
          ),
        ),
        makeTestProjectListItemData(
          project: makeTestProject(
            id: 'p2',
            title: 'Project Beta',
            categoryId: workCategory.id,
          ),
        ),
      ],
    );
  }

  group('ProjectGroupHeader', () {
    testWidgets('renders category tag and project count', (tester) async {
      final data = makeTestProjectListData();
      final group = ProjectListDetailState(
        data: data,
        filter: const ProjectsFilter(
          searchMode: ProjectsSearchMode.localText,
        ),
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
        filter: const ProjectsFilter(
          searchMode: ProjectsSearchMode.localText,
        ),
        selectedProjectId: 'p1',
      ).visibleGroups.first;

      await tester.pumpWidget(
        wrap(
          ProjectGroupSection(
            group: group,
            selectedProjectId: 'p1',
            onProjectSelected: (_) {},
          ),
          overrides: noOneLinerOverrides(['p1']),
        ),
      );
      await tester.pump();

      expect(find.text('Project Alpha'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-overview-row-p1')),
        findsOneWidget,
      );
    });

    testWidgets('renders the grouped card with the Figma border treatment', (
      tester,
    ) async {
      final group = makeGroupedProjectsSection();

      await tester.pumpWidget(
        wrap(
          ProjectGroupSection(
            group: group,
            selectedProjectId: null,
            onProjectSelected: (_) {},
          ),
          overrides: noOneLinerOverrides(['p1', 'p2']),
        ),
      );
      await tester.pump();

      final cardFinder = find.byKey(
        ValueKey('project-group-card-${group.categoryId ?? 'unassigned'}'),
      );
      final decoration =
          tester.widget<DecoratedBox>(cardFinder).decoration as BoxDecoration;
      final border = decoration.border! as Border;
      final context = tester.element(cardFinder);

      expect(border.top.width, 1);
      expect(border.right.width, 1);
      expect(border.bottom.width, 1);
      expect(border.left.width, 1);
      expect(border.top.color, ShowcasePalette.border(context));
    });

    testWidgets(
      'keeps row backgrounds full-width while leaving row content inset',
      (tester) async {
        final group = makeGroupedProjectsSection();

        await tester.pumpWidget(
          wrap(
            ProjectGroupSection(
              group: group,
              selectedProjectId: null,
              onProjectSelected: (_) {},
            ),
            overrides: noOneLinerOverrides(['p1', 'p2']),
          ),
        );
        await tester.pump();

        final cardFinder = find.byType(ClipRRect);
        final rowFinder = find.byKey(const ValueKey('project-overview-row-p1'));
        final ringFinder = find.byKey(
          const ValueKey('project-row-progress-ring-p1'),
        );
        final cardTopLeft = tester.getTopLeft(cardFinder);
        final rowTopLeft = tester.getTopLeft(rowFinder);
        final ringTopLeft = tester.getTopLeft(ringFinder);

        // The row background spans the full card width...
        expect(rowTopLeft.dx, cardTopLeft.dx);
        // ...while the leading content (the progress ring) is inset by the
        // row's horizontal padding.
        expect(ringTopLeft.dx - rowTopLeft.dx, kProjectRowHorizontalPadding);
      },
    );

    testWidgets(
      'expands hovered row backgrounds to the full card segment',
      (
        tester,
      ) async {
        final group = makeGroupedProjectsSection();

        await tester.pumpWidget(
          wrap(
            ProjectGroupSection(
              group: group,
              selectedProjectId: null,
              onProjectSelected: (_) {},
            ),
            overrides: noOneLinerOverrides(['p1', 'p2']),
          ),
        );
        await tester.pump();

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await gesture.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('project-overview-row-p1')),
          ),
        );
        await tester.pump();

        final cardFinder = find.byType(ClipRRect);
        final backgroundFinder = find.byKey(
          const ValueKey('project-row-background-p1'),
        );
        final cardRect = tester.getRect(cardFinder);
        final backgroundRect = tester.getRect(backgroundFinder);

        expect(backgroundRect.left, cardRect.left);
        expect(backgroundRect.right, cardRect.right);
        expect(
          backgroundRect.top,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('project-overview-row-p1')),
                )
                .dy,
          ),
        );
        expect(
          backgroundRect.bottom,
          greaterThan(
            tester
                .getBottomLeft(
                  find.byKey(const ValueKey('project-overview-row-p1')),
                )
                .dy,
          ),
        );
      },
    );

    testWidgets(
      'hides the divider for hovered rows without changing section height',
      (tester) async {
        final group = makeGroupedProjectsSection();

        await tester.pumpWidget(
          wrap(
            ProjectGroupSection(
              group: group,
              selectedProjectId: null,
              onProjectSelected: (_) {},
            ),
            overrides: noOneLinerOverrides(['p1', 'p2']),
          ),
        );
        await tester.pump();

        final sectionFinder = find.byType(ProjectGroupSection);
        final initialHeight = tester.getSize(sectionFinder).height;

        expect(
          find.byKey(const ValueKey('project-group-divider-0')),
          findsOneWidget,
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer();
        await gesture.moveTo(
          tester.getCenter(
            find.byKey(const ValueKey('project-overview-row-p1')),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('project-group-divider-0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('project-group-divider-slot-0')),
          findsOneWidget,
        );
        expect(tester.getSize(sectionFinder).height, initialHeight);
      },
    );

    testWidgets(
      'hides the divider for selected rows without changing section height',
      (tester) async {
        final group = makeGroupedProjectsSection();

        await tester.pumpWidget(
          wrap(
            ProjectGroupSection(
              group: group,
              selectedProjectId: 'p1',
              onProjectSelected: (_) {},
            ),
            overrides: noOneLinerOverrides(['p1', 'p2']),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('project-group-divider-0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('project-group-divider-slot-0')),
          findsOneWidget,
        );
      },
    );
  });

  group('ProjectRow', () {
    testWidgets('renders title, progress ring percent, task-count chip and '
        'blocked chip, demoting the Open status pill', (tester) async {
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            categoryColor: const Color(0xFF4AB6E8),
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
          overrides: noOneLinerOverrides([item.project.meta.id]),
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
      // Completion percent (3/5 = 60%) is rendered inside the leading ring.
      expect(find.text('60'), findsOneWidget);
      // Task-count chip renders, and the blocked tasks (1) surface as a chip.
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      expect(find.text('5 tasks'), findsOneWidget);
      expect(find.text('1 Blocked'), findsOneWidget);
      // "Open" is the implicit default state, so its pill is demoted/omitted.
      expect(find.text('Open'), findsNothing);
    });

    // Canonical description used by the pair of one-liner tests below: shown
    // when the provider resolves it, omitted when it resolves null.
    const oneLiner = 'Steady progress; next milestone is API v2.';

    testWidgets('renders the one-liner when the provider resolves it', (
      tester,
    ) async {
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            categoryColor: const Color(0xFF4AB6E8),
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
          overrides: [
            projectOneLinerProvider(
              item.project.meta.id,
            ).overrideWith((ref) async => oneLiner),
          ],
        ),
      );
      await tester.pump();

      expect(find.text(oneLiner), findsOneWidget);
      expect(find.text('Test Project'), findsOneWidget);
    });

    testWidgets('omits the one-liner when the provider resolves null', (
      tester,
    ) async {
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            categoryColor: const Color(0xFF4AB6E8),
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
          overrides: noOneLinerOverrides([item.project.meta.id]),
        ),
      );
      await tester.pump();

      // The description line is absent, but the row still renders its title
      // and metadata (here the "Ongoing" due chip, since there's no target).
      expect(find.text(oneLiner), findsNothing);
      expect(find.text('Test Project'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            categoryColor: const Color(0xFF4AB6E8),
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () => tapped = true,
          ),
          overrides: noOneLinerOverrides([item.project.meta.id]),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Project'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  // ---- redesign behaviour (v2/v3): triage, ring states, urgency, demotion ----

  ProjectStatus statusOf(String kind) => switch (kind) {
    'active' => ProjectStatus.active(
      id: 's',
      createdAt: DateTime(2026),
      utcOffset: 0,
    ),
    'completed' => ProjectStatus.completed(
      id: 's',
      createdAt: DateTime(2026),
      utcOffset: 0,
    ),
    'onHold' => ProjectStatus.onHold(
      id: 's',
      createdAt: DateTime(2026),
      utcOffset: 0,
      reason: 'paused',
    ),
    _ => ProjectStatus.open(id: 's', createdAt: DateTime(2026), utcOffset: 0),
  };

  ProjectListItemData buildItem({
    String id = 'p1',
    String title = 'Test Project',
    String statusKind = 'active',
    int completed = 3,
    int total = 5,
    int blocked = 0,
    DateTime? targetDate,
  }) => makeTestProjectListItemData(
    project: makeTestProject(
      id: id,
      title: title,
      status: statusOf(statusKind),
      targetDate: targetDate,
    ),
    completedTaskCount: completed,
    totalTaskCount: total,
    blockedTaskCount: blocked,
  );

  Future<void> pumpRow(WidgetTester tester, ProjectListItemData data) =>
      tester.pumpWidget(
        wrap(
          ProjectRow(
            item: data,
            categoryColor: const Color(0xFF4AB6E8),
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
          overrides: noOneLinerOverrides([data.project.meta.id]),
        ),
      );

  group('projectNeedsAttention / projectTriageRank', () {
    test('a completed project never needs attention and ranks last', () {
      final i = buildItem(
        statusKind: 'completed',
        completed: 5,
        blocked: 3,
      );
      expect(projectNeedsAttention(i), isFalse);
      expect(projectTriageRank(i), 3);
    });

    test('blocked tasks make a project need attention (rank 0)', () {
      final i = buildItem(blocked: 2);
      expect(projectNeedsAttention(i), isTrue);
      expect(projectTriageRank(i), 0);
    });

    test('an overdue target date needs attention (rank 0)', () {
      withClock(Clock.fixed(DateTime(2026, 6, 24)), () {
        final i = buildItem(targetDate: DateTime(2026, 6, 10));
        expect(projectNeedsAttention(i), isTrue);
        expect(projectTriageRank(i), 0);
      });
    });

    test('a due-soon project is in-progress, not attention (rank 1)', () {
      withClock(Clock.fixed(DateTime(2026, 6, 24)), () {
        final i = buildItem(targetDate: DateTime(2026, 6, 27));
        expect(projectNeedsAttention(i), isFalse);
        expect(projectTriageRank(i), 1);
      });
    });

    test('a not-started project ranks after in-progress (rank 2)', () {
      expect(projectTriageRank(buildItem(completed: 0)), 2);
    });

    test('an in-progress project ranks 1', () {
      expect(projectTriageRank(buildItem()), 1);
    });
  });

  group('ProjectRow progress ring states', () {
    testWidgets('shows a check (not a percent) for a completed project', (
      tester,
    ) async {
      await pumpRow(tester, buildItem(statusKind: 'completed', completed: 5));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('100'), findsNothing);
    });

    testWidgets('shows a ready dot (not "0") for a not-started project', (
      tester,
    ) async {
      await pumpRow(tester, buildItem(completed: 0));
      await tester.pump();
      expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the completion percent for an in-progress project', (
      tester,
    ) async {
      await pumpRow(tester, buildItem());
      await tester.pump();
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets('keeps the numeral neutral for a calm in-progress project', (
      tester,
    ) async {
      await pumpRow(tester, buildItem());
      await tester.pump();
      final numeral = tester.widget<Text>(find.text('60'));
      final ctx = tester.element(find.text('60'));
      expect(numeral.style?.color, ShowcasePalette.highText(ctx));
    });

    testWidgets('turns the numeral to the attention colour for an at-risk '
        'project', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 6, 24)), () async {
        // 2/5 = 40%, overdue → needs attention.
        await pumpRow(
          tester,
          buildItem(completed: 2, targetDate: DateTime(2026, 6, 10)),
        );
        await tester.pump();
        final numeral = tester.widget<Text>(find.text('40'));
        final ctx = tester.element(find.text('40'));
        expect(numeral.style?.color, ShowcasePalette.error(ctx));
      });
    });
  });

  group(
    'ProjectRow due-chip urgency (icon encodes urgency, not only colour)',
    () {
      final now = DateTime(2026, 6, 24);

      testWidgets('overdue shows the warning icon', (tester) async {
        await withClock(Clock.fixed(now), () async {
          await pumpRow(tester, buildItem(targetDate: DateTime(2026, 6, 10)));
          await tester.pump();
          expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        });
      });

      testWidgets('due soon shows the schedule icon', (tester) async {
        await withClock(Clock.fixed(now), () async {
          await pumpRow(tester, buildItem(targetDate: DateTime(2026, 6, 27)));
          await tester.pump();
          expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
        });
      });

      testWidgets('a normal future date shows the event icon', (tester) async {
        await withClock(Clock.fixed(now), () async {
          await pumpRow(tester, buildItem(targetDate: DateTime(2026, 9)));
          await tester.pump();
          expect(find.byIcon(Icons.event_rounded), findsOneWidget);
        });
      });

      testWidgets('an undated project shows the Ongoing chip', (tester) async {
        await pumpRow(tester, buildItem());
        await tester.pump();
        expect(find.byIcon(Icons.all_inclusive_rounded), findsOneWidget);
        expect(find.text('Ongoing'), findsOneWidget);
      });
    },
  );

  group('ProjectRow attention wash', () {
    testWidgets('a blocked project paints the attention wash behind the row', (
      tester,
    ) async {
      await pumpRow(tester, buildItem(blocked: 1));
      await tester.pump();
      final bgFinder = find.byKey(const ValueKey('project-row-background-p1'));
      expect(bgFinder, findsOneWidget);
      final ctx = tester.element(bgFinder);
      final decoration =
          tester.widget<DecoratedBox>(bgFinder).decoration as BoxDecoration;
      expect(decoration.color, ShowcasePalette.attentionRowWash(ctx));
    });

    testWidgets('a healthy project has no resting wash', (tester) async {
      await pumpRow(tester, buildItem());
      await tester.pump();
      expect(
        find.byKey(const ValueKey('project-row-background-p1')),
        findsNothing,
      );
    });
  });

  group('ProjectRow status-pill demotion', () {
    for (final (kind, showsPill) in const [
      ('active', false),
      ('open', false),
      ('completed', true),
      ('onHold', true),
    ]) {
      testWidgets('$kind ${showsPill ? 'shows' : 'hides'} the status pill', (
        tester,
      ) async {
        await pumpRow(
          tester,
          buildItem(statusKind: kind, completed: kind == 'completed' ? 5 : 3),
        );
        await tester.pump();
        expect(
          find.byType(ProjectStatusPill),
          showsPill ? findsOneWidget : findsNothing,
        );
      });
    }
  });

  group('ProjectRow completed de-emphasis', () {
    Opacity columnOpacity(WidgetTester tester) => tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.text('Test Project'),
            matching: find.byType(Opacity),
          ),
        )
        .first;

    testWidgets('dims the whole content column for a completed project', (
      tester,
    ) async {
      await pumpRow(tester, buildItem(statusKind: 'completed', completed: 5));
      await tester.pump();
      expect(columnOpacity(tester).opacity, lessThan(1.0));
    });

    testWidgets('keeps an in-progress project at full opacity', (tester) async {
      await pumpRow(tester, buildItem());
      await tester.pump();
      expect(columnOpacity(tester).opacity, 1.0);
    });
  });

  group('ProjectGroupSection triage ordering + category colour', () {
    ProjectCategoryGroup groupWith(List<ProjectListItemData> projects) {
      final category = makeTestProjectListData().categories.first;
      return ProjectCategoryGroup(
        categoryId: category.id,
        category: category,
        projects: projects,
      );
    }

    testWidgets('orders rows attention-first, completed-last regardless of '
        'input order', (tester) async {
      final group = groupWith([
        buildItem(
          id: 'done',
          title: 'Done',
          statusKind: 'completed',
          completed: 5,
        ),
        buildItem(id: 'mid', title: 'Mid'),
        buildItem(id: 'urgent', title: 'Urgent', blocked: 2),
      ]);

      await tester.pumpWidget(
        wrap(
          ProjectGroupSection(
            group: group,
            selectedProjectId: null,
            onProjectSelected: (_) {},
          ),
          overrides: noOneLinerOverrides(['done', 'mid', 'urgent']),
        ),
      );
      await tester.pump();

      final urgentY = tester.getTopLeft(find.text('Urgent')).dy;
      final midY = tester.getTopLeft(find.text('Mid')).dy;
      final doneY = tester.getTopLeft(find.text('Done')).dy;
      expect(urgentY, lessThan(midY));
      expect(midY, lessThan(doneY));
    });

    testWidgets('tints the card surface and paints the spine in the category '
        'colour', (tester) async {
      final category = makeTestProjectListData().categories.first;
      final categoryColor = colorFromCssHex(category.color);
      final group = groupWith([buildItem()]);

      await tester.pumpWidget(
        wrap(
          ProjectGroupSection(
            group: group,
            selectedProjectId: null,
            onProjectSelected: (_) {},
          ),
          overrides: noOneLinerOverrides(['p1']),
        ),
      );
      await tester.pump();

      final cardFinder = find.byKey(
        ValueKey('project-group-card-${category.id}'),
      );
      final ctx = tester.element(cardFinder);
      final decoration =
          tester.widget<DecoratedBox>(cardFinder).decoration as BoxDecoration;
      expect(
        decoration.color,
        ShowcasePalette.categoryCardSurface(ctx, categoryColor),
      );

      // The spine rail is a ColoredBox painted in the category colour.
      final rails = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color == categoryColor);
      expect(rails, isNotEmpty);
    });
  });
}
