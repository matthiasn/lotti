import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_chrome.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_list_pane.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_filter_modal.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

const _kTaskMobileScreenWidth = 402.0;
const _kTaskMobileScreenGap = 32.0;

class TaskMobileListDetailShowcase extends ConsumerStatefulWidget {
  const TaskMobileListDetailShowcase({super.key});

  @override
  ConsumerState<TaskMobileListDetailShowcase> createState() =>
      _TaskMobileListDetailShowcaseState();
}

class _TaskMobileListDetailShowcaseState
    extends ConsumerState<TaskMobileListDetailShowcase> {
  bool _showDetailInCompactMode = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskListDetailShowcaseControllerProvider);
    final controller = ref.read(
      taskListDetailShowcaseControllerProvider.notifier,
    );
    final selected = state.selectedTask;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSplitView =
            constraints.maxWidth >=
            (_kTaskMobileScreenWidth * 2) + _kTaskMobileScreenGap;

        if (showSplitView) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskMobileListScreen(
                onFilterPressed: () => showTaskShowcaseFilterModal(
                  context: context,
                  initialState: state.filterState,
                  onApplied: controller.updateFilterState,
                  presentation: TaskShowcaseFilterPresentation.mobile,
                ),
                onSearchChanged: controller.updateSearchQuery,
                onSearchCleared: () => controller.updateSearchQuery(''),
                onTaskOpened: controller.selectTask,
                state: state,
              ),
              const SizedBox(width: _kTaskMobileScreenGap),
              if (selected != null)
                _TaskMobileDetailScreen(
                  record: selected,
                ),
            ],
          );
        }

        if (_showDetailInCompactMode && selected != null) {
          return _TaskMobileDetailScreen(
            record: selected,
            onBack: () {
              setState(() {
                _showDetailInCompactMode = false;
              });
            },
          );
        }

        return _TaskMobileListScreen(
          onFilterPressed: () => showTaskShowcaseFilterModal(
            context: context,
            initialState: state.filterState,
            onApplied: controller.updateFilterState,
            presentation: TaskShowcaseFilterPresentation.mobile,
          ),
          onSearchChanged: controller.updateSearchQuery,
          onSearchCleared: () => controller.updateSearchQuery(''),
          onTaskOpened: (taskId) {
            controller.selectTask(taskId);
            setState(() {
              _showDetailInCompactMode = true;
            });
          },
          state: state,
        );
      },
    );
  }
}

class _TaskMobileListScreen extends StatelessWidget {
  const _TaskMobileListScreen({
    required this.state,
    required this.onTaskOpened,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onFilterPressed,
  });

  final TaskListDetailState state;
  final ValueChanged<String> onTaskOpened;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return DesignSystemShowcaseMobileShell(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DesignSystemShowcaseMobileStatusBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.messages.navTabTitleTasks,
                        style: context
                            .designTokens
                            .typography
                            .styles
                            .heading
                            .heading2
                            .copyWith(
                              color: TaskShowcasePalette.highText(context),
                            ),
                      ),
                    ),
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 34,
                      color: TaskShowcasePalette.highText(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: DesignSystemSearch(
                          hintText: context.messages.searchTasksHint,
                          initialText: state.searchQuery,
                          onChanged: onSearchChanged,
                          onClear: onSearchCleared,
                          onSearchPressed: onSearchChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onFilterPressed,
                      icon: Icon(
                        Icons.tune_rounded,
                        color: TaskShowcasePalette.accent(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.filterState.appliedCount > 0)
                TaskListActiveFilters(state: state),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: state.visibleSections.isEmpty
                      ? TaskShowcaseEmptyResults(
                          message: context.messages.taskShowcaseNoResults,
                        )
                      : TaskListSectionsList(
                          sections: state.visibleSections,
                          selectedTaskId: state.selectedTask?.task.meta.id,
                          onTaskSelected: onTaskOpened,
                          bottomPadding: 184,
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 140,
            child: Semantics(
              button: true,
              label: context.messages.designSystemNavigationNewLabel,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TaskShowcasePalette.accent(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const SizedBox.square(
                  dimension: 56,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: _TaskMobileBottomNavigation(),
          ),
        ],
      ),
    );
  }
}

class _TaskMobileDetailScreen extends StatelessWidget {
  const _TaskMobileDetailScreen({
    required this.record,
    this.onBack,
  });

  final TaskRecord record;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DesignSystemShowcaseMobileShell(
      child: Stack(
        children: [
          Column(
            children: [
              const DesignSystemShowcaseMobileStatusBar(),
              Expanded(
                child: DesignSystemScrollbar(
                  child: SingleChildScrollView(
                    child: TaskShowcaseDetailContent(
                      record: record,
                      compact: true,
                      onBack: onBack,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.designTokens.spacing.step3),
              const Center(child: DesignSystemShowcaseMobileHomeIndicator()),
              SizedBox(height: context.designTokens.spacing.step4),
            ],
          ),
          const Positioned(
            right: 16,
            bottom: 132,
            child: TaskShowcaseFloatingAiButton(),
          ),
        ],
      ),
    );
  }
}

class _TaskMobileBottomNavigation extends StatelessWidget {
  const _TaskMobileBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: DesignSystemNavigationTabBar(
                      items: [
                        DesignSystemNavigationTabBarItem(
                          label: context
                              .messages
                              .designSystemNavigationMyDailyLabel,
                          icon: Icons.calendar_today_outlined,
                        ),
                        DesignSystemNavigationTabBarItem(
                          label: context.messages.navTabTitleTasks,
                          icon: Icons.format_list_bulleted_rounded,
                          active: true,
                        ),
                        DesignSystemNavigationTabBarItem(
                          label: context
                              .messages
                              .designSystemBreadcrumbProjectsLabel,
                          icon: Icons.folder_rounded,
                        ),
                        DesignSystemNavigationTabBarItem(
                          label: context
                              .messages
                              .designSystemNavigationInsightsLabel,
                          icon: Icons.bar_chart_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const TaskShowcaseProfileButton(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const DesignSystemShowcaseMobileHomeIndicator(),
        const SizedBox(height: 12),
      ],
    );
  }
}
