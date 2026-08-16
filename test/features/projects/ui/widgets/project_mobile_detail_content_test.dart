import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_summary_card.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_detail_content.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';

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
    testWidgets('composes project work with one unified agent surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            agentActions: const Text('Agent decisions'),
          ),
          size: const Size(430, 1400),
        ),
      );
      await tester.pump();

      expect(find.byType(ProjectTasksSliverPanel), findsOneWidget);
      final card = tester.widget<ProjectAgentSummaryCard>(
        find.byType(ProjectAgentSummaryCard),
      );
      expect(card.actions, isA<Text>());
      expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
    });

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
          size: const Size(430, 1400),
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
          size: const Size(430, 1400),
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

    testWidgets('hides the overflow menu while an inline save runs', (
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
          size: const Size(430, 1400),
        ),
      );

      expect(find.byType(DesignSystemContextMenuButton), findsNothing);
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

    testWidgets('hides agent proposal actions while a mutation runs', (
      tester,
    ) async {
      Widget subject({required bool isSaving}) => ProjectMobileDetailContent(
        record: makeTestProjectRecord(),
        currentTime: DateTime(2026, 3, 28, 1, 18),
        agentActions: const Text('Agent decisions'),
        isSaving: isSaving,
      );

      await tester.pumpWidget(
        wrap(subject(isSaving: true), size: const Size(430, 1200)),
      );
      await tester.pump();

      expect(find.text('Agent decisions'), findsNothing);

      await tester.pumpWidget(
        wrap(subject(isSaving: false), size: const Size(430, 1200)),
      );
      await tester.pump();

      expect(find.text('Agent decisions'), findsOneWidget);
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

    testWidgets('uses the task AI card for an empty assessment', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
          ),
          size: const Size(430, 1400),
        ),
      );

      expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
      expect(find.byType(TldrHeader), findsOneWidget);
      expect(find.text('No health assessment yet'), findsOneWidget);
    });

    testWidgets('serializes assignment from the unprovisioned health state', (
      tester,
    ) async {
      final assignment = Completer<void>();
      var assignmentRequests = 0;
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            hasProjectAgent: false,
            onAssignAgent: () {
              assignmentRequests++;
              return assignment.future;
            },
          ),
          size: const Size(430, 1400),
        ),
      );

      final assignRow = find.widgetWithText(
        DesignSystemListItem,
        'Assign an agent',
      );
      await tester.tap(assignRow);
      await tester.pump();
      await tester.tap(assignRow);

      expect(assignmentRequests, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      assignment.complete();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('reuses the tappable task breadcrumb at 200% text scale', (
      tester,
    ) async {
      var categoryTaps = 0;
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onCategoryTap: () => categoryTaps++,
            onStatusTap: () {},
          ),
          size: const Size(320, 900),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Test Project'), findsOneWidget);
      expect(find.byType(TaskHierarchyCrumb), findsOneWidget);
      await tester.tap(find.text('Work'));
      expect(categoryTaps, 1);
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
          size: const Size(430, 1400),
        ),
      );
      await tester.pump();

      expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
      expect(find.text('No health assessment yet'), findsOneWidget);
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
          size: const Size(430, 1400),
        ),
      );
      await tester.pump();

      expect(
        find.text(
          'No project agent has been provisioned for this project yet.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AgentSummaryCardSurface), findsNothing);
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

      expect(find.byType(DesignSystemContextMenuButton), findsNothing);
      expect(
        tester
            .widget<TaskHierarchyCrumb>(find.byType(TaskHierarchyCrumb))
            .onCategoryTap,
        isNull,
      );
      expect(
        tester.widget<ProjectStatusPill>(find.byType(ProjectStatusPill)).onTap,
        isNull,
      );
      expect(
        tester.widget<DsPill>(find.widgetWithText(DsPill, 'Target Date')).onTap,
        isNull,
      );

      pending.complete();
      await tester.pump();
    });

    testWidgets('locks navigation until Add task finishes', (tester) async {
      final pending = Completer<void>();
      var backRequests = 0;
      var openedTasks = 0;
      final record = makeTestProjectRecord(
        highlightedTaskSummaries: [makeTestTaskSummary()],
      );
      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: record,
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onBack: () => backRequests++,
            onTaskTap: (_) => openedTasks++,
            onAddTask: () => pending.future,
          ),
          size: const Size(430, 1200),
        ),
      );
      await tester.pump();
      final addButton = find.widgetWithText(DesignSystemButton, 'Add task');
      await tester.ensureVisible(addButton);

      await tester.tap(addButton);
      await tester.pump();

      expect(
        tester
            .widget<DesignSystemBackControl>(
              find.byType(DesignSystemBackControl),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<ProjectTasksSliverPanel>(
              find.byType(ProjectTasksSliverPanel),
            )
            .onTaskTap,
        isNull,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isFalse,
      );
      await tester.tap(
        find.byType(DesignSystemBackControl),
        warnIfMissed: false,
      );
      await tester.tap(
        find.text(record.highlightedTaskSummaries.single.task.data.title),
      );
      expect(backRequests, 0);
      expect(openedTasks, 0);

      pending.complete();
      await tester.pump();

      expect(
        tester
            .widget<DesignSystemBackControl>(
              find.byType(DesignSystemBackControl),
            )
            .onTap,
        isNotNull,
      );
      expect(
        tester
            .widget<ProjectTasksSliverPanel>(
              find.byType(ProjectTasksSliverPanel),
            )
            .onTaskTap,
        isNotNull,
      );
      expect(
        tester.widget<PopScope>(find.byType(PopScope).last).canPop,
        isTrue,
      );
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

      expect(find.byType(DesignSystemContextMenuButton), findsNothing);
      expect(
        tester
            .widget<TaskHierarchyCrumb>(find.byType(TaskHierarchyCrumb))
            .onCategoryTap,
        isNull,
      );
      expect(
        tester.widget<ProjectStatusPill>(find.byType(ProjectStatusPill)).onTap,
        isNull,
      );
      expect(
        tester.widget<DsPill>(find.widgetWithText(DsPill, 'Target Date')).onTap,
        isNull,
      );
      final agentCard = tester.widget<ProjectAgentSummaryCard>(
        find.byType(ProjectAgentSummaryCard),
      );
      expect(agentCard.isMutating, isTrue);
      expect(find.text('Agent decisions'), findsNothing);
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

      await tester.tap(find.text('1 task blocked'));
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
        tester.getSize(find.byType(ProjectAgentSummaryCard)).width,
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

    testWidgets('shows health once inside the AI card after project work', (
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
      final tasksTop = tester.getTopLeft(find.text('Project Tasks'));

      expect(statusTop.dy, greaterThan(titleTop.dy));
      expect(categoryTop.dy, lessThan(titleTop.dy));
      expect(riskTop.dy, greaterThan(titleTop.dy));
      expect(riskTop.dy, greaterThan(categoryTop.dy));
      expect(riskTop.dy, greaterThan(tasksTop.dy));
      expect(statusTop.dy, greaterThan(titleTop.dy));
    });

    testWidgets('uses the same heading tier as Task Details', (tester) async {
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
      final tokens = tester.element(find.text('Design system')).designTokens;

      expect(
        title.style?.fontSize,
        tokens.typography.styles.heading.heading2.fontSize,
      );
      expect(
        title.style?.fontWeight,
        tokens.typography.styles.heading.heading2.fontWeight,
      );
      expect(title.style?.height, closeTo(1.15, 0.0001));
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

    testWidgets('uses the same summary body and disclosure as task agents', (
      tester,
    ) async {
      final record = makeTestProjectRecord(
        aiSummary: 'Short project read.',
        reportContent: 'Short project read.\n\nMore detail.',
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

      expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
      expect(find.byType(TldrHeader), findsOneWidget);
      expect(find.byType(TldrBody), findsOneWidget);
      expect(find.text('Short project read.'), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('forwards report controls to the unified agent card', (
      tester,
    ) async {
      void refresh() {}
      void cancel() {}

      await tester.pumpWidget(
        wrap(
          ProjectMobileDetailContent(
            record: makeTestProjectRecord(),
            currentTime: DateTime(2026, 3, 28, 1, 18),
            onRefreshReport: refresh,
            onCancelScheduledReportWake: cancel,
            isRefreshingReport: true,
          ),
        ),
      );
      await tester.pump();

      final card = tester.widget<ProjectAgentSummaryCard>(
        find.byType(ProjectAgentSummaryCard),
      );
      expect(card.onRefresh, same(refresh));
      expect(card.onCancelScheduledWake, same(cancel));
      expect(card.isRefreshing, isTrue);
    });

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

        expect(find.text('No health assessment yet'), findsOneWidget);
        expect(find.byType(TldrBody), findsNothing);
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

      expect(find.textContaining('Updated'), findsNothing);
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

        // No real category crumb is shown; the Task-style muted metadata pill
        // remains the explicit affordance for assigning one.
        expect(find.byType(CategoryTag), findsNothing);
        final placeholder = tester.widget<DsPill>(
          find.widgetWithText(DsPill, 'Category'),
        );
        expect(placeholder.variant, DsPillVariant.muted);

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
