import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
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
class TasksRootPage extends ConsumerWidget {
  const TasksRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onDelta: ref
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth,
    );
    final listPaneWidth = resolvedListPane.width;
    final paneController = ref.read(paneWidthControllerProvider.notifier);

    return DecoratedBox(
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
              child: const TasksTabPage(),
            ),
            divider: ResizableDivider(
              currentValue: listPaneWidth,
              minValue: minListPaneWidth,
              maxValue: maxListPaneWidth,
              onDrag: resolvedListPane.onDrag,
            ),
            detailPane: _TasksDetailPane(
              stackDepth: stack.length,
              detail: AnimatedSwitcher(
                // Fast cross-fade (200ms): stepping row-by-row through tasks is
                // the split view's core interaction, and matches the logbook
                // split so both panes feel identical.
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
    );
  }
}

class _TasksDetailPane extends StatelessWidget {
  const _TasksDetailPane({required this.stackDepth, required this.detail});

  final int stackDepth;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    if (splitController?.listPaneVisible != false) {
      return detail;
    }

    final tokens = context.designTokens;
    final horizontalInset =
        tokens.spacing.step2 +
        (stackDepth > 1 ? TapTargets.minimum + tokens.spacing.step1 : 0);
    return Stack(
      fit: StackFit.expand,
      children: [
        detail,
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
                onPressed: splitController!.showListPane,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
