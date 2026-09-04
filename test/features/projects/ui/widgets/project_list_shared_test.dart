import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(
    Widget child, {
    List<Override> overrides = const [],
    double width = 402,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: SizedBox(width: width, height: 900, child: child),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: Size(width, 1000),
          textScaler: textScaler,
        ),
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

    testWidgets('constrains a long category before the count at 200% text', (
      tester,
    ) async {
      final data = makeTestProjectListData();
      final category = data.categories.first.copyWith(
        name: 'Interplanetary Penguin Habitat Safety Operations',
      );
      final group = ProjectCategoryGroup(
        categoryId: category.id,
        category: category,
        projects: [
          makeTestProjectListItemData(
            project: makeTestProject(categoryId: category.id),
            category: category,
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          ProjectGroupHeader(group: group),
          width: 280,
          textScaler: const TextScaler.linear(2),
        ),
      );

      final labelRect = tester.getRect(find.text(category.name));
      final countRect = tester.getRect(find.text('1 project'));
      expect(labelRect.right, lessThan(countRect.left));
      expect(tester.takeException(), isNull);
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
        ),
      );
      await tester.pump();

      expect(find.text('Project Alpha'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-overview-row-p1')),
        findsOneWidget,
      );
    });

    testWidgets('collapses and restores a category without losing its header', (
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
        ),
      );

      await tester.tap(find.text('Work'));
      await tester.pump();
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Project Alpha'), findsNothing);
      expect(find.byIcon(LottiIcons.expand), findsOneWidget);

      await tester.tap(find.text('Work'));
      await tester.pump();
      expect(find.text('Project Alpha'), findsOneWidget);
      expect(find.byIcon(LottiIcons.collapse), findsOneWidget);
    });

    testWidgets('centers the visible group header inside its 48dp tap target', (
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
        ),
      );

      final headerRect = tester.getRect(find.byType(InkWell).first);
      final labelRect = tester.getRect(find.text('Work'));
      expect(headerRect.height, greaterThanOrEqualTo(TapTargets.minimum));
      expect(labelRect.center.dy, closeTo(headerRect.center.dy, 0.1));
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
          ),
        );
        await tester.pump();

        final cardFinder = find.byType(ClipRRect);
        final rowFinder = find.byKey(const ValueKey('project-overview-row-p1'));
        final titleFinder = find.text('Project Alpha');
        final cardTopLeft = tester.getTopLeft(cardFinder);
        final rowTopLeft = tester.getTopLeft(rowFinder);
        final titleTopLeft = tester.getTopLeft(titleFinder);

        expect(rowTopLeft.dx, cardTopLeft.dx);
        final tokens = tester.element(rowFinder).designTokens;
        expect(titleTopLeft.dx - rowTopLeft.dx, tokens.spacing.step4);
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
        final rowRect = tester.getRect(
          find.byKey(const ValueKey('project-overview-row-p1')),
        );
        expect(backgroundRect.top, rowRect.top);
        expect(backgroundRect.bottom, greaterThanOrEqualTo(rowRect.bottom));
      },
    );

    testWidgets(
      'keyboard focus uses the full-width hover background',
      (tester) async {
        final group = makeGroupedProjectsSection();

        await tester.pumpWidget(
          wrap(
            ProjectGroupSection(
              group: group,
              selectedProjectId: null,
              onProjectSelected: (_) {},
            ),
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        final cardFinder = find.byType(ClipRRect);
        final backgroundFinder = find.byKey(
          const ValueKey('project-row-background-p1'),
        );
        final cardRect = tester.getRect(cardFinder);
        final backgroundRect = tester.getRect(backgroundFinder);
        final decoration =
            tester.widget<DecoratedBox>(backgroundFinder).decoration
                as BoxDecoration;
        final context = tester.element(backgroundFinder);

        expect(decoration.color, ShowcasePalette.hoverFill(context));
        expect(backgroundRect.left, cardRect.left);
        expect(backgroundRect.right, cardRect.right);
        expect(backgroundRect.top, cardRect.top);
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
        expect(
          tester
              .getSize(
                find.byKey(
                  const ValueKey('project-group-divider-slot-0'),
                ),
              )
              .height,
          BorderWidths.hairline,
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
    testWidgets('Right opens the focused project and enters the detail pane', (
      tester,
    ) async {
      final item = makeTestProjectListItemData();
      final dividerFocusNode = FocusNode(debugLabel: 'test-divider');
      final detailFocusNode = FocusNode(debugLabel: 'test-project-detail');
      addTearDown(dividerFocusNode.dispose);
      addTearDown(detailFocusNode.dispose);
      var taps = 0;

      await tester.pumpWidget(
        wrap(
          AppCommandHost(
            handlers: const {},
            platform: TargetPlatform.windows,
            child: ListDetailFocusTraversal(
              debugLabel: 'projects-test',
              listPane: SizedBox(
                width: 360,
                child: ProjectRow(
                  item: item,
                  selected: false,
                  topOverlap: 0,
                  bottomOverlap: 0,
                  onHoverChanged: (_) {},
                  onTap: () => taps++,
                ),
              ),
              divider: Focus(
                focusNode: dividerFocusNode,
                child: const SizedBox(width: 3),
              ),
              detailPane: Align(
                alignment: Alignment.topLeft,
                child: TextButton(
                  focusNode: detailFocusNode,
                  onPressed: () {},
                  child: const Text('Project detail action'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(taps, 1);
      expect(detailFocusNode.hasFocus, isTrue);
      expect(dividerFocusNode.hasFocus, isFalse);
    });

    testWidgets('renders title, task progress, and status tag', (tester) async {
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
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
      expect(find.byIcon(LottiIcons.checkAll), findsOneWidget);
    });

    testWidgets('displays one-liner when available', (tester) async {
      const oneLiner = 'Steady progress; next milestone is API v2.';
      final item = makeTestProjectListItemData(oneLiner: oneLiner);

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text(oneLiner), findsOneWidget);
      expect(find.text('Test Project'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Test Project')).maxLines, 2);
      expect(tester.widget<Text>(find.text(oneLiner)).maxLines, 2);
    });

    testWidgets('labels an empty project without a warning-colored 0% ring', (
      tester,
    ) async {
      final item = makeTestProjectListItemData(
        totalTaskCount: 0,
        completedTaskCount: 0,
      );

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
        ),
      );

      expect(
        find.text('No tasks · Ongoing', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('0%'), findsNothing);
      expect(
        find.byKey(
          ValueKey('project-row-progress-ring-${item.project.meta.id}'),
        ),
        findsNothing,
      );
    });

    testWidgets('hides one-liner when null', (tester) async {
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Project'), findsOneWidget);
      // Only title and metadata row — no extra Text widget for one-liner.
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
      final oneLinerTexts = textWidgets.where(
        (t) =>
            t.maxLines == 2 &&
            t.overflow == TextOverflow.ellipsis &&
            t.style?.fontSize == 12,
      );
      expect(oneLinerTexts, isEmpty);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final item = makeTestProjectListItemData();

      await tester.pumpWidget(
        wrap(
          ProjectRow(
            item: item,
            selected: false,
            topOverlap: 0,
            bottomOverlap: 0,
            onHoverChanged: (_) {},
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
