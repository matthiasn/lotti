import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';

import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  Widget wrap(
    Widget child, {
    Size size = const Size(430, 900),
    ValueNotifier<bool>? listPaneVisible,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final content = listPaneVisible == null
        ? child
        : ValueListenableBuilder<bool>(
            valueListenable: listPaneVisible,
            builder: (context, visible, _) => ListDetailFocusTraversal(
              debugLabel: 'project-detail-test',
              listPaneVisible: visible,
              canHideListPane: true,
              onListPaneVisibilityChanged: (nextVisible) {
                listPaneVisible.value = nextVisible;
              },
              listPane: const SizedBox(width: 300, child: Text('Project list')),
              divider: const SizedBox(width: 3),
              detailPane: child,
            ),
          );

    return makeTestableWidget2(
      Theme(
        data: DesignSystemTheme.dark(),
        child: Scaffold(body: content),
      ),
      mediaQueryData: MediaQueryData(
        size: size,
        padding: const EdgeInsets.only(top: 20),
        textScaler: textScaler,
      ),
    );
  }

  group('ProjectMobileDetailContent', () {
    testWidgets('uses a real overflow menu and forwards project actions', (
      tester,
    ) async {
      var editRequests = 0;
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onEdit: () => editRequests++,
            onArchive: () {},
            onDelete: () {},
          ),
        ),
      );

      final menu = tester.widget<DesignSystemContextMenuButton>(
        find.byType(DesignSystemContextMenuButton),
      );
      expect(menu.items.map((item) => item.label), [
        'Edit project',
        'Archive',
        'Delete',
      ]);
      menu.items.first.onTap!();
      expect(editRequests, 1);
    });

    testWidgets('keeps project metadata close to the title with a menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onEdit: () {},
          ),
        ),
      );
      await tester.pump();

      final titleTop = tester.getTopLeft(find.text('Test Project')).dy;
      final statusTop = tester.getTopLeft(find.text('Open')).dy;
      expect(
        statusTop - titleTop,
        lessThan(48),
        reason: 'The menu hit target must not create an empty toolbar row.',
      );
    });

    testWidgets('disables mutating menu actions while an inline save runs', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onEdit: () {},
            onArchive: () {},
            onDelete: () {},
            isSaving: true,
          ),
        ),
      );

      final menu = tester.widget<DesignSystemContextMenuButton>(
        find.byType(DesignSystemContextMenuButton),
      );
      expect(menu.items, hasLength(3));
      expect(menu.items.every((item) => item.onTap == null), isTrue);
    });

    testWidgets('disables Add task while an inline save runs', (tester) async {
      var addRequests = 0;
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onAddTask: () async => addRequests++,
            isSaving: true,
          ),
          size: const Size(430, 1200),
        ),
      );
      await tester.pump();
      final addButton = find.widgetWithText(DesignSystemButton, 'Add task');
      await tester.ensureVisible(addButton);

      expect(
        tester.widget<DesignSystemButton>(addButton).onPressed,
        isNull,
      );
      await tester.tap(addButton, warnIfMissed: false);
      await tester.pump();
      expect(addRequests, 0);
    });

    testWidgets('rejects a stale Add task callback after saving starts', (
      tester,
    ) async {
      var addRequests = 0;
      const contentKey = ValueKey('project-detail');
      Widget content({required bool isSaving}) => ProjectMobileDetailContent(
        key: contentKey,
        record: makeTestProjectRecord(),
        currentTime: DateTime(2026, 3, 28, 1, 18),
        onAddTask: () async => addRequests++,
        isSaving: isSaving,
      );

      await tester.pumpWidget(
        wrap(content(isSaving: false), size: const Size(430, 1200)),
      );
      await tester.pump();
      final addButton = find.widgetWithText(DesignSystemButton, 'Add task');
      await tester.ensureVisible(addButton);
      final staleCallback = tester
          .widget<DesignSystemButton>(addButton)
          .onPressed!;

      await tester.pumpWidget(
        wrap(content(isSaving: true), size: const Size(430, 1200)),
      );
      staleCallback();
      await tester.pump();

      expect(addRequests, 0);
    });

    testWidgets(
      'marks the empty-health report action busy while the agent runs',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: makeTestProjectRecord(),
              currentTime: DateTime(2026, 3, 28, 1, 18),
              onRefreshReport: () {},
              isRefreshingReport: true,
            ),
          ),
        );

        final emptyState = tester.widget<ProjectHealthEmptyState>(
          find.byType(ProjectHealthEmptyState),
        );
        expect(emptyState.isRunningReport, isTrue);
      },
    );

    testWidgets('keeps interactive metadata usable at 200% text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onCategoryTap: () {},
            onStatusTap: () {},
          ),
          size: const Size(320, 900),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Test Project'), findsOneWidget);
      final categoryTarget = find.ancestor(
        of: find.text('Work'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(categoryTarget.first).height,
        greaterThanOrEqualTo(48),
      );
    });
    testWidgets('shows an honest empty health state without agent metrics', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HealthPanel), findsNothing);
      expect(find.text('No health report yet'), findsOneWidget);
      expect(find.text('Health Score'), findsNothing);
    });

    testWidgets('explains missing health when no project agent exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            hasProjectAgent: false,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'No project agent has been provisioned for this project yet.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DesignSystemButton, 'Run report'),
        findsNothing,
      );
    });

    testWidgets('renders the user-authored project description', (
      tester,
    ) async {
      final project = makeTestProject().copyWith(
        entryText: const EntryText(
          plainText:
              'Keep the habitat launch work aligned with Mission Control.',
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(project: project),
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Description'), findsOneWidget);
      expect(
        find.text(
          'Keep the habitat launch work aligned with Mission Control.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('prevents duplicate Add task requests while one is pending', (
      tester,
    ) async {
      final pending = Completer<void>();
      var addRequests = 0;
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onAddTask: () {
              addRequests++;
              return pending.future;
            },
          ),
          size: const Size(430, 1200),
        ),
      );
      await tester.pump();
      final addButton = find.widgetWithText(DesignSystemButton, 'Add task');
      await tester.ensureVisible(addButton);

      await tester.tap(addButton);
      await tester.pump();
      await tester.tap(addButton, warnIfMissed: false);
      await tester.pump();

      expect(addRequests, 1);
      expect(
        tester.widget<DesignSystemButton>(addButton).isLoading,
        isTrue,
      );

      pending.complete();
      await tester.pump();
      expect(
        tester.widget<DesignSystemButton>(addButton).isLoading,
        isFalse,
      );
    });

    testWidgets('disables project actions while Add task is pending', (
      tester,
    ) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onEdit: () {},
            onArchive: () {},
            onDelete: () {},
            onAddTask: () => pending.future,
            onCategoryTap: () {},
            onTargetDateTap: () {},
            onStatusTap: () {},
          ),
          size: const Size(430, 1200),
        ),
      );
      await tester.pump();
      final addButton = find.widgetWithText(DesignSystemButton, 'Add task');
      await tester.ensureVisible(addButton);

      await tester.tap(addButton);
      await tester.pump();

      final menu = tester.widget<DesignSystemContextMenuButton>(
        find.byType(DesignSystemContextMenuButton),
      );
      expect(menu.items, hasLength(3));
      expect(menu.items.every((item) => item.onTap == null), isTrue);
      expect(
        tester.widget<CategoryTag>(find.byType(CategoryTag)).onTap,
        isNull,
      );
      expect(
        tester.widget<ProjectStatusPill>(find.byType(ProjectStatusPill)).onTap,
        isNull,
      );
      expect(
        tester.widget<OutlinedMetaTag>(find.byType(OutlinedMetaTag)).onTap,
        isNull,
      );

      pending.complete();
      await tester.pump();
    });

    testWidgets('disables project actions while deletion is pending', (
      tester,
    ) async {
      final deletion = Completer<void>();
      var addRequests = 0;
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onEdit: () {},
            onArchive: () {},
            onDelete: () => deletion.future,
            onAddTask: () async => addRequests++,
            onCategoryTap: () {},
            onTargetDateTap: () {},
            onStatusTap: () {},
            onRefreshReport: () {},
            onCancelScheduledReportWake: () {},
          ),
          size: const Size(430, 1200),
        ),
      );
      await tester.pump();

      tester
          .widget<DesignSystemContextMenuButton>(
            find.byType(DesignSystemContextMenuButton),
          )
          .items
          .last
          .onTap!();
      await tester.pump();

      final pendingMenu = tester.widget<DesignSystemContextMenuButton>(
        find.byType(DesignSystemContextMenuButton),
      );
      expect(pendingMenu.items.every((item) => item.onTap == null), isTrue);
      expect(
        tester.widget<CategoryTag>(find.byType(CategoryTag)).onTap,
        isNull,
      );
      expect(
        tester.widget<ProjectStatusPill>(find.byType(ProjectStatusPill)).onTap,
        isNull,
      );
      expect(
        tester.widget<OutlinedMetaTag>(find.byType(OutlinedMetaTag)).onTap,
        isNull,
      );
      final report = tester.widget<ExpandableReportSection>(
        find.byType(ExpandableReportSection),
      );
      expect(report.onRefresh, isNull);
      expect(report.onCancelScheduledWake, isNull);
      final addButton = find.widgetWithText(DesignSystemButton, 'Add task');
      await tester.ensureVisible(addButton);
      expect(tester.widget<DesignSystemButton>(addButton).onPressed, isNull);
      await tester.tap(addButton, warnIfMissed: false);
      expect(addRequests, 0);

      deletion.complete();
      await tester.pump();
    });

    testWidgets('opens the first blocked task from the health action', (
      tester,
    ) async {
      final openTask = makeTestTask(id: 'open-task', title: 'Open task');
      final blockedTask =
          makeTestTask(
            id: 'blocked-task',
            title: 'Blocked task',
          ).copyWith(
            data: makeTestTask().data.copyWith(
              title: 'Blocked task',
              status: TaskStatus.blocked(
                id: 'blocked-status',
                createdAt: DateTime(2026, 3, 20),
                utcOffset: 0,
                reason: 'Waiting for launch clearance',
              ),
            ),
          );
      TaskSummary? opened;
      final record = makeTestProjectRecord(
        healthMetrics: makeTestProjectHealthMetrics(
          band: ProjectHealthBand.blocked,
        ),
        highlightedTaskSummaries: [
          makeTestTaskSummary(task: openTask),
          makeTestTaskSummary(task: blockedTask),
        ],
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onTaskTap: (summary) => opened = summary,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('View blocker'));
      await tester.pump();

      expect(opened?.task.meta.id, 'blocked-task');
    });

    testWidgets('keeps Back on the standalone mobile detail route', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );

      expect(find.byType(DesignSystemBackControl), findsOneWidget);
      expect(
        tester.getCenter(find.text('Back')).dx,
        lessThan(
          tester.getCenter(find.byType(ProjectMobileDetailContent)).dx,
        ),
      );
    });

    testWidgets('keeps a small mobile scrollbar outside the content gutter', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onBack: () {},
          ),
        ),
      );

      final scrollbar = tester.widget<DesignSystemScrollbar>(
        find.byType(DesignSystemScrollbar),
      );
      final scrollbarRect = tester.getRect(find.byType(DesignSystemScrollbar));
      final contentRect = tester.getRect(
        find.byType(ProjectMobileDetailContent),
      );
      expect(scrollbar.size, DesignSystemScrollbarSize.small);
      expect(scrollbarRect.right, contentRect.right);
    });

    testWidgets('omits mobile Back inside the desktop split view', (
      tester,
    ) async {
      final listPaneVisible = ValueNotifier(false);
      addTearDown(listPaneVisible.dispose);

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
          size: const Size(1280, 800),
          listPaneVisible: listPaneVisible,
        ),
      );

      expect(find.byType(DesignSystemBackControl), findsNothing);
    });

    testWidgets('caps wide desktop detail content at the reading measure', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1440, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
          size: const Size(1440, 900),
        ),
      );
      await tester.pump();

      final tokens = tester
          .element(find.byType(ProjectMobileDetailContent))
          .designTokens;
      expect(
        tester.getSize(find.byType(CustomScrollView)).width,
        kDetailContentMaxWidth - tokens.spacing.step5 * 2,
      );
      expect(
        tester.getSize(find.byType(ProjectHealthEmptyState)).width,
        tester.getSize(find.byType(CustomScrollView)).width,
      );
    });

    testWidgets('lazily builds far task rows as the detail page scrolls', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        highlightedTaskSummaries: List.generate(
          50,
          (index) => makeTestTaskSummary(
            task: makeTestTask(
              id: 'task-$index',
              title: 'Task $index',
            ),
            oneLiner: 'Summary line $index',
          ),
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Task 0'), findsOneWidget);
      expect(find.text('Task 49'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -8000));
      await tester.pump();

      expect(find.text('Task 49'), findsOneWidget);
    });

    testWidgets('shows health once in its assessment panel below metadata', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'project-1',
          title: 'Design system',
          categoryId: 'cat-1',
          targetDate: DateTime(2026, 3, 26),
          status: ProjectStatus.active(
            id: 'active',
            createdAt: DateTime(2026, 3, 20),
            utcOffset: 0,
          ),
        ),
        healthMetrics: makeTestProjectHealthMetrics(
          band: ProjectHealthBand.atRisk,
          rationale: 'The critical path is slipping behind plan.',
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Design system'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('At Risk'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);

      final titleTop = tester.getTopLeft(find.text('Design system'));
      final statusTop = tester.getTopLeft(find.text('Active'));
      final categoryTop = tester.getTopLeft(find.text('Work'));
      final riskTop = tester.getTopLeft(find.text('At Risk'));

      expect(statusTop.dy, greaterThan(titleTop.dy));
      expect((statusTop.dy - categoryTop.dy).abs(), lessThan(8));
      expect(riskTop.dy, greaterThan(titleTop.dy));
      expect(riskTop.dy, greaterThan(categoryTop.dy));
      expect(statusTop.dx, lessThan(categoryTop.dx));
    });

    testWidgets('uses the heading 3 title size from Figma', (tester) async {
      final record = makeTestProjectRecord(
        project: makeTestProject(
          id: 'project-1',
          title: 'Design system',
          categoryId: 'cat-1',
        ),
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Design system'));

      expect(title.style?.fontSize, 20);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(title.style?.height, closeTo(1.4, 0.0001));
    });

    testWidgets(
      'moves the status pill to its own right-aligned line when the title is too wide',
      (
        tester,
      ) async {
        final record = makeTestProjectRecord(
          project: makeTestProject(
            id: 'project-1',
            title:
                'A very long project title that should force the active selector onto a new line',
            categoryId: 'cat-1',
            targetDate: DateTime(2026, 3, 26),
            status: ProjectStatus.active(
              id: 'active',
              createdAt: DateTime(2026, 3, 20),
              utcOffset: 0,
            ),
          ),
        );

        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: record,
              currentTime: DateTime(2026, 3, 28, 1, 18),
            ),
            size: const Size(320, 900),
          ),
        );
        await tester.pump();

        final titleTop = tester.getTopLeft(
          find.textContaining('A very long project title'),
        );
        final statusTop = tester.getTopLeft(find.text('Active'));

        expect(statusTop.dy, greaterThan(titleTop.dy));
      },
    );

    testWidgets(
      'shows one refresh icon and a countdown pill in the report header',
      (
        tester,
      ) async {
        final now = DateTime(2026, 3, 28, 1, 18);
        await withClock(Clock.fixed(now), () async {
          final record = makeTestProjectRecord(
            reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
            reportNextWakeAt: now.add(const Duration(seconds: 90)),
          );

          await tester.pumpWidget(
            wrap(
              ProjectMobileDetailContent(
                record: record,
                currentTime: now,
                onRefreshReport: () {},
              ),
            ),
          );
          await tester.pump();

          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
          expect(find.byType(ShowcaseCountdownPill), findsOneWidget);
          expect(find.textContaining('Updated 1m ago'), findsOneWidget);
          expect(find.textContaining('↻'), findsNothing);
        });
      },
    );

    testWidgets(
      'forwards onCancelScheduledReportWake through to the underlying '
      'ExpandableReportSection so a tap on the report cancel × routes to '
      'the same callback the project details page wires up',
      (tester) async {
        var cancelCount = 0;
        final now = DateTime(2026, 3, 28, 1, 18);
        await withClock(Clock.fixed(now), () async {
          final record = makeTestProjectRecord(
            reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
            reportNextWakeAt: now.add(const Duration(seconds: 90)),
          );

          await tester.pumpWidget(
            wrap(
              ProjectMobileDetailContent(
                record: record,
                currentTime: now,
                onRefreshReport: () {},
                onCancelScheduledReportWake: () => cancelCount++,
              ),
            ),
          );
          await tester.pump();

          // Verify the prop reached the inner widget (catches a wiring bug
          // earlier than tapping would).
          final report = tester.widget<ExpandableReportSection>(
            find.byType(ExpandableReportSection),
          );
          expect(report.onCancelScheduledWake, isNotNull);

          // Then prove the callback is the same one we passed by invoking
          // it via the inner widget — `find.byIcon(Icons.close_rounded)`
          // would also match the X on individual recommendation tiles, so
          // we drive the report-section callback directly.
          report.onCancelScheduledWake!();
          expect(cancelCount, 1);
        });
      },
    );

    testWidgets(
      'leaves the ExpandableReportSection cancel callback null when the '
      'page does not pass onCancelScheduledReportWake (no agent identity)',
      (tester) async {
        final now = DateTime(2026, 3, 28, 1, 18);
        await withClock(Clock.fixed(now), () async {
          final record = makeTestProjectRecord(
            reportUpdatedAt: DateTime(2026, 3, 28, 1, 17),
            reportNextWakeAt: now.add(const Duration(seconds: 90)),
          );

          await tester.pumpWidget(
            wrap(
              ProjectMobileDetailContent(
                record: record,
                currentTime: now,
                onRefreshReport: () {},
              ),
            ),
          );
          await tester.pump();

          final report = tester.widget<ExpandableReportSection>(
            find.byType(ExpandableReportSection),
          );
          expect(report.onCancelScheduledWake, isNull);
        });
      },
    );

    testWidgets(
      'shows the empty-report placeholder when both the AI summary and the '
      'report content are empty',
      (tester) async {
        final record = makeTestProjectRecord(
          aiSummary: '',
          reportContent: '',
        );

        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: record,
              currentTime: DateTime(2026, 3, 28, 1, 18),
            ),
          ),
        );
        await tester.pump();

        // The empty-summary branch feeds `agentReportNone` into the report
        // section body, which the section renders as its TLDR.
        final report = tester.widget<ExpandableReportSection>(
          find.byType(ExpandableReportSection),
        );
        expect(report.body, 'No report available yet.');
        expect(find.textContaining('No report available yet.'), findsOneWidget);
      },
    );

    testWidgets('omits report freshness when no report exists', (tester) async {
      final record = makeTestProjectRecord(
        aiSummary: '',
        reportContent: '',
        hasReportTimestamp: false,
      );

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
        ),
      );
      await tester.pump();

      final report = tester.widget<ExpandableReportSection>(
        find.byType(ExpandableReportSection),
      );
      expect(report.trailingLabel, isNull);
    });

    testWidgets(
      'renders the tappable category placeholder when the project has no '
      'category but the page wires up onCategoryTap',
      (tester) async {
        var categoryTapCount = 0;
        final record = _makeRecordWithNoCategory();

        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: record,
              currentTime: DateTime(2026, 3, 28, 1, 18),
              onCategoryTap: () => categoryTapCount++,
            ),
          ),
        );
        await tester.pump();

        // No real category tag is shown; the placeholder tag carries the
        // "Category:" label and is marked as a placeholder.
        expect(find.byType(CategoryTag), findsNothing);
        final placeholder = tester.widget<OutlinedMetaTag>(
          find.widgetWithText(OutlinedMetaTag, 'Category'),
        );
        expect(placeholder.isPlaceholder, isTrue);

        await tester.tap(find.text('Category'));
        await tester.pump();
        expect(categoryTapCount, 1);
      },
    );

    testWidgets(
      'omits the category placeholder when the project has no category and '
      'onCategoryTap is not wired up',
      (tester) async {
        final record = _makeRecordWithNoCategory();

        await tester.pumpWidget(
          wrap(
            ProjectMobileDetailContent(
              record: record,
              currentTime: DateTime(2026, 3, 28, 1, 18),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CategoryTag), findsNothing);
        expect(find.text('Category'), findsNothing);
      },
    );
  });
}

/// A record without a category, shared by the category-placeholder tests.
ProjectRecord _makeRecordWithNoCategory() {
  return ProjectRecord(
    project: makeTestProject(
      id: 'project-1',
      title: 'Uncategorised project',
    ),
    category: null,
    healthMetrics: null,
    reportNextWakeAt: null,
    completedTaskCount: 0,
    totalTaskCount: 0,
    blockedTaskCount: 0,
    aiSummary: 'Test AI summary.',
    reportContent: 'Test AI summary.',
    reportUpdatedAt: DateTime(2026, 4, 2, 7, 30),
    highlightedTaskSummaries: const [],
    highlightedTasksTotalDuration: Duration.zero,
  );
}
