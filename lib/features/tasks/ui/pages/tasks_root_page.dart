import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_column.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_back_leading.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Responsive entry point for the tasks feature.
///
/// On non-desktop layouts (per `isDesktopLayout`) it shows the full-width
/// [TasksTabPage]. On desktop it renders a resizable split pane: the
/// [TasksTabPage] list on the left (width driven by `paneWidthControllerProvider`
/// and a [ResizableDivider]) and, on the right, the [TaskDetailsPage] for the
/// task at the top of `NavService.desktopTaskDetailStack`, or a
/// [DesktopDetailEmptyState] when nothing is selected. A selected task enables
/// persisted focus mode, which keeps the list mounted offstage and exposes a
/// separate restore action over every detail state.
///
/// In focus mode the freed width buys a third column rather than a wider
/// task: a persistent [TaskMetaColumn] carries the task's metadata beside it,
/// where the pane is at least [kTaskMetaColumnMinHostWidth] wide. Narrower
/// than that, the metadata stays in its fly-out.
class TasksRootPage extends ConsumerStatefulWidget {
  const TasksRootPage({super.key});

  @override
  ConsumerState<TasksRootPage> createState() => _TasksRootPageState();
}

class _TasksRootPageState extends ConsumerState<TasksRootPage> {
  final _tasksTabController = TasksTabPageController();

  @override
  void dispose() {
    _tasksTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) {
      return const TasksTabPage();
    }

    final paneWidths = ref.watch(paneWidthControllerProvider);
    // Scales the flat default proportionally on large windows so the list
    // pane doesn't stay pinned to a laptop-tuned width while the detail
    // pane grows unbounded — see scaledPaneWidth's doc comment. A no-op once
    // the user has dragged the list pane to any other width.
    final resolvedListPane = resolvedPaneWidth(
      storedWidth: paneWidths.listPaneWidth,
      flatDefault: defaultListPaneWidth,
      minValue: minListPaneWidth,
      maxValue: maxListPaneWidth,
      screenWidth: MediaQuery.sizeOf(context).width,
      onDelta: (delta) => ref
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(delta, allowWhileCollapsed: true),
    );
    final listPaneWidth = resolvedListPane.width;
    final paneController = ref.read(paneWidthControllerProvider.notifier);

    return AppCommandScope(
      handlers: {
        AppCommandId.focusSearch: AppCommandHandler(
          invoke: (_) {
            paneController.expandListPane();
            _tasksTabController.focusSearch();
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TaskShowcasePalette.page(context),
        ),
        child: ValueListenableBuilder<List<String>>(
          valueListenable: getIt<NavService>().desktopTaskDetailStack,
          builder: (context, stack, _) {
            final selectedTaskId = stack.isEmpty ? null : stack.last;
            final canHideListPane = selectedTaskId != null;
            final listPaneVisible =
                !paneWidths.listPaneCollapsed || !canHideListPane;
            final detailChild = selectedTaskId != null
                ? TaskDetailsPage(
                    key: ValueKey(selectedTaskId),
                    taskId: selectedTaskId,
                  )
                : DesktopDetailEmptyState(
                    key: const ValueKey<String>(
                      'tasks-root-empty-detail',
                    ),
                    message: context.messages.desktopEmptyStateSelectTask,
                  );

            return ListDetailFocusTraversal(
              debugLabel: 'tasks-split',
              listPaneVisible: listPaneVisible,
              canHideListPane: canHideListPane,
              onListPaneVisibilityChanged: (visible) {
                if (visible) {
                  paneController.expandListPane();
                } else {
                  paneController.collapseListPane();
                }
              },
              listPane: SizedBox(
                width: listPaneWidth,
                child: TasksTabPage(controller: _tasksTabController),
              ),
              divider: ResizableDivider(
                currentValue: listPaneWidth,
                minValue: minListPaneWidth,
                maxValue: maxListPaneWidth,
                onDrag: resolvedListPane.onDrag,
              ),
              detailPane: _TasksDetailPane(
                stackDepth: stack.length,
                selectedTaskId: selectedTaskId,
                // The details column is the collapsed-list layout: once the
                // reader has hidden the list to focus one task, the pane is
                // wide enough to carry the task's metadata beside it instead
                // of over it. Null keeps the fly-out as the only host.
                metaColumnTaskId: listPaneVisible ? null : selectedTaskId,
                detail: AnimatedSwitcher(
                  // Fast cross-fade (200ms): stepping row-by-row through tasks
                  // is the split view's core interaction, and matches the
                  // logbook split so both panes feel identical.
                  duration: MotionDurations.short4,
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ...previousChildren.map(
                          (child) => ExcludeFocus(child: child),
                        ),
                        ?currentChild,
                      ],
                    );
                  },
                  child: detailChild,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The right half of the tasks split view: the task itself, the "show list"
/// affordance over it while the list is hidden, and — when the pane is wide
/// enough — the persistent [TaskMetaColumn] beside it.
class _TasksDetailPane extends StatelessWidget {
  const _TasksDetailPane({
    required this.stackDepth,
    required this.detail,
    required this.metaColumnTaskId,
    required this.selectedTaskId,
  });

  final int stackDepth;
  final Widget detail;

  /// The task on show, whatever the layout — unlike [metaColumnTaskId], which
  /// is null in every state that has no metadata column. The "show list"
  /// affordance reads it to tell whether cover art sits behind it.
  final String? selectedTaskId;

  /// The task whose metadata the column shows, or null when this layout has
  /// no column (list pane visible, or no task selected).
  final String? metaColumnTaskId;

  @override
  Widget build(BuildContext context) {
    final taskId = metaColumnTaskId;
    // The pane's own width, not the window's: the navigation sidebar can be
    // collapsed, and asking MediaQuery would answer the wrong question by up
    // to a sidebar's width.
    //
    // One tree shape in every state — always a Row, with the column as an
    // optional trailing child. Swapping between "body" and "Row(body,
    // column)" would rebuild the task page from scratch on every collapse,
    // losing its scroll position and its state.
    return LayoutBuilder(
      builder: (context, constraints) {
        final showColumn =
            taskId != null &&
            constraints.maxWidth >= kTaskMetaColumnMinHostWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TaskMetaColumnScope(
                visible: showColumn,
                child: _TaskPaneBody(
                  stackDepth: stackDepth,
                  detail: detail,
                  selectedTaskId: selectedTaskId,
                ),
              ),
            ),
            if (showColumn)
              TaskMetaColumn(
                key: ValueKey('task-meta-column-$taskId'),
                taskId: taskId,
              ),
          ],
        );
      },
    );
  }
}

class _TaskPaneBody extends StatelessWidget {
  const _TaskPaneBody({
    required this.stackDepth,
    required this.detail,
    required this.selectedTaskId,
  });

  final int stackDepth;
  final Widget detail;
  final String? selectedTaskId;

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    final tokens = context.designTokens;
    final horizontalInset =
        tokens.spacing.step2 +
        (stackDepth > 1 ? TapTargets.minimum + tokens.spacing.step1 : 0);
    return Stack(
      fit: StackFit.expand,
      children: [
        detail,
        if (splitController?.listPaneVisible == false)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: horizontalInset,
                  top: tokens.spacing.step2,
                ),
                child: TaskDetailShowListButton(
                  key: const ValueKey('tasks-show-list-pane'),
                  taskId: selectedTaskId,
                  onPressed: splitController!.showListPane,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
