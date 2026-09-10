import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/popovers/design_system_popover_anchor.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_groups.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/features/projects/ui/widgets/project_task_list_options_sheet.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_tag_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/journal_image_fixtures.dart';
import '../../../../test_utils/material_ui_finders.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);

  Widget wrap(Widget child) {
    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 400, child: child),
          ),
        ),
      ),
    );
  }

  group('TaskSummaryRow', () {
    testWidgets('renders task title, one-liner, and estimated duration', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        oneLiner: 'Implementation phase done, release next',
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      expect(find.text('Build feature'), findsOneWidget);
      expect(
        find.text('Implementation phase done, release next'),
        findsOneWidget,
      );
      expect(find.text('45m'), findsOneWidget);
      expect(find.byIcon(LottiIcons.timer), findsOneWidget);
      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
    });

    testWidgets('calls onTap when the row is tapped', (tester) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
      );
      Object? tappedSummary;

      await tester.pumpWidget(
        wrap(
          TaskSummaryRow(
            summary: summary,
            onTap: (value) => tappedSummary = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Build feature'));
      await tester.pump();

      expect(tappedSummary, same(summary));
    });

    testWidgets('uses the lighter Figma body-small task title style', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Build feature'));

      expect(title.style?.fontSize, 14);
      expect(title.style?.fontWeight, FontWeight.w400);
      expect(title.style?.height, closeTo(1.4286, 0.0001));
    });

    testWidgets(
      'uses the Figma subtitle style for the one-liner',
      (tester) async {
        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: 'Build feature'),
          oneLiner: 'Implementation phase done, release next',
        );

        await tester.pumpWidget(
          wrap(TaskSummaryRow(summary: summary)),
        );
        await tester.pump();

        final subtitle = tester.widget<Text>(
          find.text('Implementation phase done, release next'),
        );

        expect(subtitle.style?.fontSize, 12);
        expect(subtitle.style?.fontWeight, FontWeight.w400);
        expect(subtitle.style?.height, closeTo(1.3333, 0.0001));
        expect(subtitle.style?.letterSpacing, 0.25);
        expect(subtitle.maxLines, 3);
      },
    );

    testWidgets(
      'uses the same body-small typography for duration and task status',
      (tester) async {
        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: 'Build feature'),
          estimatedDuration: const Duration(minutes: 45),
        );

        await tester.pumpWidget(
          wrap(TaskSummaryRow(summary: summary)),
        );
        await tester.pump();

        final duration = tester.widget<Text>(find.text('45m'));
        final status = tester.widget<Text>(find.text('Open'));

        expect(duration.style?.fontSize, 14);
        expect(duration.style?.fontWeight, FontWeight.w400);
        expect(duration.style?.height, closeTo(1.4286, 0.0001));
        expect(status.style?.fontSize, duration.style?.fontSize);
        expect(status.style?.fontWeight, duration.style?.fontWeight);
        expect(status.style?.height, duration.style?.height);
      },
    );

    testWidgets('uses a 16px timer icon in the metadata row', (tester) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(LottiIcons.timer));
      expect(icon.size, 16);
    });

    testWidgets('omits the subtitle when the task has no one-liner', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
        estimatedDuration: const Duration(minutes: 45),
      );

      await tester.pumpWidget(
        wrap(TaskSummaryRow(summary: summary)),
      );
      await tester.pump();

      final titleRect = tester.getRect(find.text('Build feature'));
      final statusRect = tester.getRect(find.text('Open'));

      expect(
        find.text('Implementation phase done, release next'),
        findsNothing,
      );
      expect(statusRect.top, greaterThan(titleRect.bottom - 1));
    });

    testWidgets(
      'lets the title and one-liner wrap while keeping metadata below them',
      (tester) async {
        const longTitle =
            'Sync database optimization and recovery tooling for long-running '
            'offline reconciliation';
        const longOneLiner =
            'Implementation phase is done, but release validation, rollout '
            'notes, and post-release monitoring still need to be completed.';

        final summary = makeTestTaskSummary(
          task: makeTestTask(id: 't1', title: longTitle),
          oneLiner: longOneLiner,
          estimatedDuration: const Duration(hours: 2, minutes: 30),
        );

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 260,
              child: TaskSummaryRow(summary: summary),
            ),
          ),
        );
        await tester.pump();

        final titleFinder = find.text(longTitle);
        final subtitleFinder = find.text(longOneLiner);
        final statusFinder = find.text('Open');
        final titleRect = tester.getRect(titleFinder);
        final subtitleRect = tester.getRect(subtitleFinder);
        final statusRect = tester.getRect(statusFinder);

        expect(tester.getSize(titleFinder).height, greaterThan(20));
        expect(tester.getSize(subtitleFinder).height, greaterThan(16));
        expect(subtitleRect.top, greaterThan(titleRect.bottom - 1));
        expect(statusRect.top, greaterThan(subtitleRect.bottom - 1));
      },
    );

    testWidgets('extends hover fill to the full task row segment', (
      tester,
    ) async {
      final summary = makeTestTaskSummary(
        task: makeTestTask(id: 't1', title: 'Build feature'),
      );

      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 600,
            child: CustomScrollView(
              slivers: [
                ProjectTasksSliverPanel(
                  record: makeTestProjectRecord(
                    highlightedTaskSummaries: [
                      summary,
                      makeTestTaskSummary(
                        task: makeTestTask(id: 't2', title: 'Second task'),
                      ),
                    ],
                  ),
                  now: now,
                  options: const ProjectTaskListOptions(
                    groupBy: ProjectTaskGroupBy.none,
                  ),
                  onTaskTap: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final rowFinder = find.text('Build feature');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(rowFinder));
      await tester.pump();

      final backgroundFinder = find.byKey(
        const ValueKey('task-summary-row-background-t1'),
      );
      final backgroundRect = tester.getRect(backgroundFinder);
      final rowRect = tester.getRect(find.byType(TaskSummaryRow).first);

      expect(backgroundRect.left, rowRect.left);
      expect(backgroundRect.right, rowRect.right);
      expect(backgroundRect.top, lessThan(rowRect.top));
      expect(backgroundRect.bottom, greaterThan(rowRect.bottom));
    });

    group('cover art', () {
      final image = buildJournalImage();

      /// A task summary carrying [coverArtId], since the shared factory
      /// builds plain tasks.
      TaskSummary withCoverArt(String? coverArtId, {double cropX = 0.5}) {
        final task = makeTestTask(id: 't1', title: 'Build feature');
        return makeTestTaskSummary(
          task: task.copyWith(
            data: task.data.copyWith(
              coverArtId: coverArtId,
              coverArtCropX: cropX,
            ),
          ),
          oneLiner: 'Implementation phase done, release next',
        );
      }

      Future<void> pumpRow(WidgetTester tester, TaskSummary summary) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [createEntryControllerOverride(image)],
            child: wrap(TaskSummaryRow(summary: summary)),
          ),
        );
        await tester.pump();
      }

      testWidgets('renders the task cover art with its stored crop', (
        tester,
      ) async {
        await pumpRow(tester, withCoverArt('image-1', cropX: 0.25));

        final thumbnail = tester.widget<CoverArtThumbnail>(
          find.byType(CoverArtThumbnail),
        );
        expect(thumbnail.imageId, 'image-1');
        expect(
          thumbnail.cropX,
          0.25,
          reason: 'the row must honour the crop the user chose on the task',
        );
      });

      testWidgets('draws no thumbnail when the task has no cover art', (
        tester,
      ) async {
        await pumpRow(tester, withCoverArt(null));
        expect(find.byType(CoverArtThumbnail), findsNothing);
      });

      testWidgets('treats a blank cover art id as no cover art', (
        tester,
      ) async {
        // Sync and import have both been seen leaving whitespace behind; a
        // blank id resolves to nothing and would reserve an empty square.
        await pumpRow(tester, withCoverArt('   '));
        expect(find.byType(CoverArtThumbnail), findsNothing);
      });

      testWidgets('the thumbnail is a square that leads the row', (
        tester,
      ) async {
        await pumpRow(tester, withCoverArt('image-1'));

        final thumbRect = tester.getRect(find.byType(CoverArtThumbnail));
        final titleRect = tester.getRect(find.text('Build feature'));
        expect(thumbRect.width, thumbRect.height);
        expect(
          thumbRect.right,
          lessThanOrEqualTo(titleRect.left),
          reason: 'the thumbnail leads the text, never overlaps it',
        );
        expect(
          thumbRect.top,
          closeTo(titleRect.top, thumbRect.height),
          reason: 'the thumbnail aligns with the title, not the row centre',
        );
      });

      testWidgets('the text column gives up exactly the thumbnail width', (
        tester,
      ) async {
        await pumpRow(tester, withCoverArt(null));
        final withoutArt = tester.getRect(find.text('Build feature')).left;

        await pumpRow(tester, withCoverArt('image-1'));
        final withArt = tester.getRect(find.text('Build feature')).left;
        final thumbRect = tester.getRect(find.byType(CoverArtThumbnail));

        expect(
          withArt - withoutArt,
          closeTo(thumbRect.width + 12, 0.5),
          reason:
              'the text starts after the square plus one spacing step — the '
              'row gives the thumbnail real space rather than overlapping',
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('the thumbnail takes its size from the spacing scale', (
        tester,
      ) async {
        // Same square as the day planner's agenda card, so a task is the
        // same size wherever it is listed.
        await pumpRow(tester, withCoverArt('image-1'));
        final tokens = DesignSystemTheme.dark().extension<DsTokens>()!;
        expect(
          tester.getRect(find.byType(CoverArtThumbnail)).width,
          tokens.spacing.step9,
        );
      });
    });
  });

  group('ProjectTasksSliverPanel', () {
    Widget wrapSliver(
      Widget sliver, {
      double width = 400,
      double? screenWidth,
      double textScale = 1,
    }) {
      return makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: CustomScrollView(slivers: [sliver]),
              ),
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: Size(screenWidth ?? width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
      );
    }

    TaskSummary summary(
      String id,
      String title, {
      required DateTime createdAt,
      bool done = false,
      Duration estimate = const Duration(hours: 1),
    }) {
      final task = makeTestTask(id: id, title: title, createdAt: createdAt);
      return makeTestTaskSummary(
        task: done
            ? task.copyWith(
                data: task.data.copyWith(
                  status: TaskStatus.done(
                    id: 'done-$id',
                    createdAt: createdAt,
                    utcOffset: 0,
                  ),
                ),
              )
            : task,
        estimatedDuration: estimate,
      );
    }

    final record = makeTestProjectRecord(
      highlightedTaskSummaries: [
        summary('a', 'Implement sync', createdAt: DateTime(2026, 8, 3)),
        summary(
          'b',
          'Offline cache',
          createdAt: DateTime(2026, 9, 2),
          estimate: const Duration(hours: 2, minutes: 30),
        ),
        summary(
          'c',
          'Ship it',
          createdAt: DateTime(2026, 8, 20),
          done: true,
          estimate: const Duration(minutes: 10),
        ),
      ],
      highlightedTasksTotalDuration: const Duration(hours: 3, minutes: 40),
    );

    testWidgets('a row keeps its element when a reorder moves its task', (
      tester,
    ) async {
      final alpha = makeTestTaskSummary(
        task: makeTestTask(
          id: 'alpha',
          title: 'Alpha',
          createdAt: DateTime(2026, 9),
        ),
      );
      final beta = makeTestTaskSummary(
        task: makeTestTask(
          id: 'beta',
          title: 'Beta',
          createdAt: DateTime(2026, 9, 2),
        ),
      );
      final pair = makeTestProjectRecord(
        highlightedTaskSummaries: [alpha, beta],
      );

      Future<void> pumpSorted(ProjectTaskSortBy sortBy) async {
        await tester.pumpWidget(
          wrapSliver(
            ProjectTasksSliverPanel(
              record: pair,
              now: now,
              options: ProjectTaskListOptions(
                groupBy: ProjectTaskGroupBy.none,
                sortBy: sortBy,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      double top(String title) => tester.getTopLeft(find.text(title)).dy;

      await pumpSorted(ProjectTaskSortBy.title);
      expect(top('Alpha'), lessThan(top('Beta')));
      final betaRow = find.byKey(projectTaskRowKey(beta));
      final betaElement = tester.element(betaRow);

      await pumpSorted(ProjectTaskSortBy.created);
      expect(top('Beta'), lessThan(top('Alpha')), reason: 'newest first');
      expect(
        tester.element(betaRow),
        same(betaElement),
        reason: 'the element follows the task, not the index',
      );
    });

    testWidgets('renders the header with count and total estimate', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(record: record, now: now),
          width: 900,
        ),
      );
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'count badge');
      expect(find.text('3h 40m'), findsOneWidget, reason: 'total estimate');
    });

    testWidgets(
      'the header reads title, count, then a trailing rail flush to the right',
      (tester) async {
        await tester.pumpWidget(
          wrapSliver(
            ProjectTasksSliverPanel(
              record: record,
              now: now,
              onOptionsChanged: (_) {},
              onAddTask: () {},
            ),
            width: 900,
          ),
        );
        await tester.pump();

        final header = tester.getRect(find.text('Project Tasks'));
        final badge = tester.getRect(find.byType(CountDotBadge));
        final duration = tester.getRect(find.text('3h 40m'));
        final sort = tester.getRect(find.byIcon(LottiIcons.sort));
        final addTask = tester.getRect(find.text('Add task'));

        // The count belongs to the heading it counts; the estimate is a value
        // of the list and joins the controls in the trailing rail.
        expect(badge.left, greaterThan(header.right));
        expect(duration.left, greaterThan(badge.right));
        expect(sort.left, greaterThan(duration.right));
        expect(
          addTask.left,
          greaterThan(sort.right),
          reason: 'Sort sits with the actions, immediately before Add task.',
        );

        // A `Spacer` beside loose `Flexible`s used to split the free space
        // three ways, stranding the controls mid-row with slack behind them.
        final panel = tester.getRect(find.byType(CustomScrollView));
        expect(
          panel.right - tester.getRect(find.byType(DesignSystemButton)).right,
          lessThan(40),
          reason: 'The actions end at the card edge, not somewhere before it.',
        );
        expect(
          badge.left - header.right,
          lessThan(40),
          reason: 'The badge stays beside its heading, not adrift from it.',
        );
      },
    );

    testWidgets('every header element is centred on one another', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            onOptionsChanged: (_) {},
            onAddTask: () {},
          ),
          width: 900,
        ),
      );
      await tester.pump();

      final centre = tester.getRect(find.text('Project Tasks')).center.dy;
      for (final finder in [
        find.byType(CountDotBadge),
        find.text('3h 40m'),
        // The rows carry a timer glyph too; the header's is the first built.
        find.byIcon(LottiIcons.timer).first,
        find.byIcon(LottiIcons.sort),
        find.text('Add task'),
      ]) {
        expect(
          tester.getRect(finder).center.dy,
          closeTo(centre, 1.5),
          reason: 'Header elements share one vertical centre.',
        );
      }
    });

    testWidgets(
      'a pinned group header repaints the card outline it paints over',
      (tester) async {
        await tester.pumpWidget(
          wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
        );
        await tester.pump();

        // The panel's outline is painted behind the slivers, so the header's
        // opaque full-width fill would erase the card's left and right
        // hairlines wherever a group starts. It has to carry them itself.
        final header = find.byKey(
          const ValueKey('project-task-group-month:2026-9'),
        );
        expect(header, findsOneWidget);
        final decorated = tester.widget<Container>(
          find.descendant(of: header, matching: find.byType(Container)).first,
        );
        final sides =
            (decorated.foregroundDecoration! as BoxDecoration).border!
                as Border;
        final border = ShowcasePalette.border(
          tester.element(find.text('September 2026')),
        );
        expect(sides.left.color, border);
        expect(sides.right.color, border);
        expect(sides.left.width, BorderWidths.hairline);
        expect(
          sides.top,
          BorderSide.none,
          reason: 'Only the sides are missing; the top would double a divider.',
        );

        // The hairlines only land on the card's own outline if the header
        // spans the panel edge to edge.
        final panel = tester.getRect(find.byType(CustomScrollView));
        final headerRect = tester.getRect(header);
        expect(headerRect.left, closeTo(panel.left, 0.01));
        expect(headerRect.right, closeTo(panel.right, 0.01));

        // Carried as a foreground decoration, the sides paint over the fill
        // without insetting the row's content the way a border side in
        // `decoration` would.
        expect(
          (decorated.decoration! as BoxDecoration).border,
          isA<Border>().having(
            (b) => b.left,
            'left',
            BorderSide.none,
          ),
          reason: 'The laid-out border stays the bottom rule only.',
        );
      },
    );

    testWidgets(
      'the compact header drops the estimate and shrinks Add task to a glyph',
      (tester) async {
        await tester.pumpWidget(
          wrapSliver(
            ProjectTasksSliverPanel(
              record: record,
              now: now,
              onOptionsChanged: (_) {},
              onAddTask: () {},
            ),
            width: 360,
          ),
        );
        await tester.pump();

        expect(find.text('3h 40m'), findsNothing);
        expect(find.text('Add task'), findsNothing);
        expect(find.text('Project Tasks'), findsOneWidget);
        expect(find.byType(CountDotBadge), findsOneWidget);
        expect(find.byIcon(LottiIcons.add), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'groups by creation month, newest first, and folds done tasks',
      (tester) async {
        await tester.pumpWidget(
          wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
        );
        await tester.pump();

        expect(find.text('September 2026'), findsOneWidget);
        expect(find.text('August 2026'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('· 1 task'), findsNWidgets(3));
        expect(find.text('· 2h 30m'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('September 2026')).dy,
          lessThan(tester.getTopLeft(find.text('August 2026')).dy),
        );
        expect(find.text('Offline cache'), findsOneWidget);
        expect(find.text('Implement sync'), findsOneWidget);
        expect(
          find.text('Ship it'),
          findsNothing,
          reason: 'The Done group starts folded.',
        );

        await tester.tap(find.text('Done'));
        await tester.pump();
        expect(find.text('Ship it'), findsOneWidget);

        await tester.tap(find.text('September 2026'));
        await tester.pump();
        expect(find.text('Offline cache'), findsNothing);
        expect(find.text('Implement sync'), findsOneWidget);
      },
    );

    testWidgets('an ungrouped list shows rows without headers', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            options: const ProjectTaskListOptions(
              groupBy: ProjectTaskGroupBy.none,
              keepDoneInGroups: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('September 2026'), findsNothing);
      expect(
        find.byKey(const ValueKey('project-task-group-done')),
        findsNothing,
      );
      expect(find.text('Ship it'), findsOneWidget);
      expect(find.text('Offline cache'), findsOneWidget);
    });

    testWidgets('renders only the header for a project without tasks', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: makeTestProjectRecord(),
            now: now,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Project Tasks'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('folds report through onOptionsChanged and read back', (
      tester,
    ) async {
      final reported = <ProjectTaskListOptions>[];
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            onOptionsChanged: reported.add,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(reported.single.collapsedGroups, isEmpty);
      expect(
        find.text('Ship it'),
        findsNothing,
        reason: 'The host owns the fold; nothing moves until it re-renders.',
      );

      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            options: reported.single,
            onOptionsChanged: reported.add,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Ship it'), findsOneWidget);

      await tester.tap(find.text('September 2026'));
      await tester.pump();
      expect(reported.last.collapsedGroups, {
        const ProjectTaskMonthKey(2026, 9).id,
      });
    });

    testWidgets('the control opens the sheet on a phone', (tester) async {
      const options = ProjectTaskListOptions(
        groupBy: ProjectTaskGroupBy.status,
        sortBy: ProjectTaskSortBy.title,
      );
      ProjectTaskListOptions? reported;
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            options: options,
            onOptionsChanged: (value) => reported = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(findMaterialTooltip('Sort and group'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTaskListOptionsSheetContent), findsOneWidget);
      expect(find.byType(DesignSystemPopoverSurface), findsNothing);

      await tester.tap(find.byKey(const ValueKey('project-tasks-group-none')));
      await tester.pump();
      expect(reported, options.copyWith(groupBy: ProjectTaskGroupBy.none));

      await tester.pumpWidget(
        wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
      );
      await tester.pump();
      expect(
        findMaterialTooltip('Sort and group'),
        findsNothing,
        reason: 'A read-only showcase wires no control.',
      );
    });

    testWidgets('the control opens a popover on a desktop-wide screen', (
      tester,
    ) async {
      ProjectTaskListOptions? reported;
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            onOptionsChanged: (value) => reported = value,
          ),
          width: 900,
          screenWidth: 1200,
        ),
      );
      await tester.pump();

      await tester.tap(findMaterialTooltip('Sort and group'));
      await tester.pump();
      expect(find.byType(DesignSystemPopoverSurface), findsOneWidget);
      expect(find.byType(ProjectTaskListOptionsSheetContent), findsOneWidget);

      final titleRow = find.byKey(const ValueKey('project-tasks-sort-title'));
      await tester.ensureVisible(titleRow);
      await tester.pump();
      await tester.tap(titleRow);
      await tester.pump();
      expect(reported?.sortBy, ProjectTaskSortBy.title);
      expect(
        find.byType(DesignSystemPopoverSurface),
        findsOneWidget,
        reason: 'A pick applies at once and leaves the popover open.',
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(DesignSystemPopoverSurface), findsNothing);
    });

    testWidgets(
      'group headers pin while their rows scroll and push each other',
      (
        tester,
      ) async {
        final many = makeTestProjectRecord(
          highlightedTaskSummaries: [
            for (var i = 0; i < 12; i++)
              summary('s$i', 'September task $i', createdAt: DateTime(2026, 9)),
            for (var i = 0; i < 12; i++)
              summary('a$i', 'August task $i', createdAt: DateTime(2026, 8)),
          ],
        );
        await tester.pumpWidget(
          wrapSliver(ProjectTasksSliverPanel(record: many, now: now)),
        );
        await tester.pump();
        final viewportTop = tester.getRect(find.byType(CustomScrollView)).top;
        expect(
          tester.getRect(find.text('September 2026')).top,
          greaterThan(viewportTop),
        );

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();
        expect(
          tester.getRect(find.text('September 2026')).top,
          closeTo(viewportTop + 14, 6),
          reason: 'The header of the group being scrolled stays pinned.',
        );
        expect(
          find.text('Project Tasks'),
          findsNothing,
          reason: 'The card header scrolls away.',
        );

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pump();
        expect(
          tester.getRect(find.text('August 2026')).top,
          closeTo(viewportTop + 14, 6),
          reason: 'The next group header takes the pinned slot.',
        );
        expect(
          find.text('September 2026'),
          findsNothing,
          reason: 'Pushed out.',
        );
      },
    );

    testWidgets('a highlighted row paints the wash without a pointer', (
      tester,
    ) async {
      final one = summary('h', 'Hot row', createdAt: DateTime(2026, 9));
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: makeTestProjectRecord(highlightedTaskSummaries: [one]),
            now: now,
            focus: const ProjectTaskFocus(
              taskId: 'h',
              request: 1,
              scroll: false,
            ),
          ),
        ),
      );
      await tester.pump();
      final wash = find.byKey(const ValueKey('task-summary-row-background-h'));
      expect(wash, findsOneWidget);

      await tester.pump(ProjectTasksSliverPanel.highlightDuration);
      expect(wash, findsNothing, reason: 'The highlight fades on its own.');
    });

    testWidgets('focus scrolls a deep row into view, unfolding its group', (
      tester,
    ) async {
      final many = makeTestProjectRecord(
        highlightedTaskSummaries: [
          for (var i = 0; i < 40; i++)
            summary('s$i', 'September task $i', createdAt: DateTime(2026, 9)),
          summary('done', 'Shipped', createdAt: DateTime(2026, 8), done: true),
        ],
      );
      final reported = <ProjectTaskListOptions>[];
      Widget subject({
        ProjectTaskFocus? focus,
        ProjectTaskListOptions? options,
      }) => wrapSliver(
        ProjectTasksSliverPanel(
          record: many,
          now: now,
          focus: focus,
          options: options ?? ProjectTaskListOptions.defaults,
          onOptionsChanged: reported.add,
        ),
      );
      await tester.pumpWidget(subject());
      await tester.pump();
      expect(find.text('September task 39'), findsNothing, reason: 'lazy');

      await tester.pumpWidget(
        subject(focus: const ProjectTaskFocus(taskId: 's39', request: 1)),
      );
      for (var i = 0; i < ProjectTasksSliverPanel.maxScrollAttempts; i++) {
        await tester.pump();
      }
      await tester.pump(MotionDurations.medium2);
      final viewport = tester.getRect(find.byType(CustomScrollView));
      final row = tester.getRect(find.text('September task 39'));
      expect(row.top, greaterThanOrEqualTo(viewport.top));
      expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(
        find.byKey(const ValueKey('task-summary-row-background-s39')),
        findsOneWidget,
      );
      expect(reported, isEmpty, reason: 'September was never folded.');

      // A task in the folded Done group: the fold opens through the host.
      await tester.pumpWidget(
        subject(focus: const ProjectTaskFocus(taskId: 'done', request: 2)),
      );
      await tester.pump();
      expect(reported.single.isCollapsed('done'), isFalse);
      await tester.pumpWidget(
        subject(
          focus: const ProjectTaskFocus(taskId: 'done', request: 2),
          options: reported.single,
        ),
      );
      for (var i = 0; i < ProjectTasksSliverPanel.maxScrollAttempts; i++) {
        await tester.pump();
      }
      await tester.pump(MotionDurations.medium2);
      final shipped = tester.getRect(find.text('Shipped'));
      expect(shipped.top, greaterThanOrEqualTo(viewport.top));
      expect(shipped.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('focus on an ungrouped list steps through the viewport', (
      tester,
    ) async {
      final many = makeTestProjectRecord(
        highlightedTaskSummaries: [
          for (var i = 0; i < 40; i++)
            summary('t$i', 'Task $i', createdAt: DateTime(2026, 9)),
        ],
      );
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: many,
            now: now,
            options: const ProjectTaskListOptions(
              groupBy: ProjectTaskGroupBy.none,
              sortBy: ProjectTaskSortBy.title,
            ),
            focus: const ProjectTaskFocus(taskId: 't9', request: 1),
          ),
        ),
      );
      for (var i = 0; i < ProjectTasksSliverPanel.maxScrollAttempts; i++) {
        await tester.pump();
      }
      await tester.pump(MotionDurations.medium2);
      final viewport = tester.getRect(find.byType(CustomScrollView));
      final row = tester.getRect(find.text('Task 9'));
      expect(row.top, greaterThanOrEqualTo(viewport.top));
      expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    test('ProjectTaskFocus compares by task, request and mode', () {
      const a = ProjectTaskFocus(taskId: 't', request: 1);
      expect(a, const ProjectTaskFocus(taskId: 't', request: 1));
      expect(
        a.hashCode,
        const ProjectTaskFocus(taskId: 't', request: 1).hashCode,
      );
      expect(a, isNot(const ProjectTaskFocus(taskId: 't', request: 2)));
      expect(
        a,
        isNot(const ProjectTaskFocus(taskId: 't', request: 1, scroll: false)),
      );
      expect(a, isNot(const ProjectTaskFocus(taskId: 'u', request: 1)));
    });

    testWidgets('Add task is labelled when wide and a glyph when compact', (
      tester,
    ) async {
      var requests = 0;
      Widget panel({bool adding = false, bool enabled = true}) =>
          ProjectTasksSliverPanel(
            record: record,
            now: now,
            onAddTask: () => requests++,
            isAddingTask: adding,
            isAddTaskEnabled: enabled,
          );

      await tester.pumpWidget(wrapSliver(panel(), width: 900));
      await tester.pump();
      expect(find.text('Add task'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      expect(requests, 1);
      expect(find.text('3h 40m'), findsOneWidget);

      // A narrowed desktop pane, as in the list-and-detail showcase, still
      // fits the full header.
      await tester.pumpWidget(wrapSliver(panel(), width: 548));
      await tester.pump();
      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('3h 40m'), findsOneWidget);

      await tester.pumpWidget(wrapSliver(panel()));
      await tester.pump();
      expect(find.text('Add task'), findsNothing);
      await tester.tap(findMaterialTooltip('Add task'));
      expect(requests, 2);
      expect(
        find.text('3h 40m'),
        findsNothing,
        reason: 'The compact header leaves estimates to the group headers.',
      );
      expect(find.text('Project Tasks'), findsOneWidget);

      await tester.pumpWidget(wrapSliver(panel(), width: 900, textScale: 1.3));
      await tester.pump();
      expect(find.text('3h 40m'), findsNothing, reason: 'Large text compacts.');
      expect(find.text('Add task'), findsNothing);
      expect(findMaterialTooltip('Add task'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrapSliver(panel(adding: true), width: 900));
      await tester.pump();
      final button = tester.widget<DesignSystemButton>(
        find.byType(DesignSystemButton),
      );
      expect(button.isLoading, isTrue);
      expect(button.onPressed, isNull);

      await tester.pumpWidget(wrapSliver(panel(enabled: false)));
      await tester.pump();
      final glyph = tester.widget<DesignSystemIconAction>(
        find.byWidgetPredicate(
          (w) => w is DesignSystemIconAction && w.tooltip == 'Add task',
        ),
      );
      expect(glyph.onPressed, isNull);

      await tester.pumpWidget(
        wrapSliver(ProjectTasksSliverPanel(record: record, now: now)),
      );
      await tester.pump();
      expect(findMaterialTooltip('Add task'), findsNothing);
      expect(find.text('Add task'), findsNothing);
    });

    testWidgets('groups by due window, overdue first and undated last', (
      tester,
    ) async {
      TaskSummary dueOn(String id, String title, DateTime? due) {
        final task = makeTestTask(
          id: id,
          title: title,
          createdAt: DateTime(2026, 9),
        );
        return makeTestTaskSummary(
          task: due == null
              ? task
              : task.copyWith(data: task.data.copyWith(due: due)),
        );
      }

      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: makeTestProjectRecord(
              highlightedTaskSummaries: [
                dueOn('none', 'Undated', null),
                dueOn('later', 'Next month', DateTime(2026, 10, 20)),
                dueOn('week', 'Tomorrow', DateTime(2026, 9, 6)),
                dueOn('late', 'Yesterday', DateTime(2026, 9, 4)),
              ],
            ),
            now: now,
            options: const ProjectTaskListOptions(
              groupBy: ProjectTaskGroupBy.dueWindow,
            ),
          ),
        ),
      );
      await tester.pump();

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Overdue'), lessThan(top('Yesterday')));
      expect(top('Yesterday'), lessThan(top('This week')));
      expect(top('This week'), lessThan(top('Tomorrow')));
      expect(top('Tomorrow'), lessThan(top('Later')));
      expect(top('Later'), lessThan(top('Next month')));
      expect(top('Next month'), lessThan(top('No due date')));
      expect(top('No due date'), lessThan(top('Undated')));
    });

    testWidgets('names every group key, and the ungrouped set not at all', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        wrapSliver(
          SliverToBoxAdapter(
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      String label(ProjectTaskGroupKey key) =>
          projectTaskGroupLabel(context, key);

      expect(label(const ProjectTaskMonthKey(2026, 9)), 'September 2026');
      expect(
        label(
          ProjectTaskStatusKey(
            TaskStatus.open(id: 'open', createdAt: now, utcOffset: 0),
          ),
        ),
        'Open',
      );
      expect(
        label(const ProjectTaskDueWindowKey(ProjectDueWindow.overdue)),
        'Overdue',
      );
      expect(
        label(const ProjectTaskDueWindowKey(ProjectDueWindow.thisWeek)),
        'This week',
      );
      expect(
        label(const ProjectTaskDueWindowKey(ProjectDueWindow.later)),
        'Later',
      );
      expect(
        label(const ProjectTaskDueWindowKey(ProjectDueWindow.none)),
        'No due date',
      );
      expect(label(const ProjectTaskDoneKey()), 'Done');
      expect(
        label(const ProjectTaskAllKey()),
        isEmpty,
        reason: 'the ungrouped set never shows a header',
      );
    });

    testWidgets('due-window groups move on at local midnight', (
      tester,
    ) async {
      final task = makeTestTask(
        id: 'due',
        title: 'Feed the penguins',
        createdAt: DateTime(2026, 9),
      );
      final dueToday = makeTestTaskSummary(
        task: task.copyWith(
          data: task.data.copyWith(due: DateTime(2026, 9, 5, 8)),
        ),
      );
      final beforeMidnight = DateTime(2026, 9, 5, 23, 59);
      await withClock(Clock.fixed(DateTime(2026, 9, 6, 0, 1)), () async {
        await tester.pumpWidget(
          wrapSliver(
            ProjectTasksSliverPanel(
              record: makeTestProjectRecord(
                highlightedTaskSummaries: [dueToday],
              ),
              now: beforeMidnight,
              options: const ProjectTaskListOptions(
                groupBy: ProjectTaskGroupBy.dueWindow,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('This week'), findsOneWidget);
        expect(find.text('Overdue'), findsNothing);

        await tester.pump(const Duration(minutes: 1, seconds: 2));

        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('This week'), findsNothing);
      });
    });

    testWidgets('forwards row taps to onTaskTap with the tapped summary', (
      tester,
    ) async {
      final tapped = summary('t', 'Tap me', createdAt: DateTime(2026, 9));
      TaskSummary? received;
      await tester.pumpWidget(
        wrapSliver(
          ProjectTasksSliverPanel(
            record: makeTestProjectRecord(highlightedTaskSummaries: [tapped]),
            now: now,
            onTaskTap: (s) => received = s,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(received, same(tapped));
    });
  });
}
