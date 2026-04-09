import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_header.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_quick_filter.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/tasks_tab_header.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

typedef TasksTabCreateTaskCallback =
    Future<void> Function(WidgetRef ref, String? categoryId);

typedef TasksTabProjectHeaderBuilder =
    Widget Function({
      required String categoryId,
      required Set<String> selectedProjectIds,
      required void Function(String projectId) onToggleProject,
      required void Function(Set<String> staleIds) onClearStale,
    });

class TasksTabPage extends ConsumerWidget {
  const TasksTabPage({
    super.key,
    this.onCreateTaskPressed,
    this.projectHeaderBuilder,
  });

  final TasksTabCreateTaskCallback? onCreateTaskPressed;
  final TasksTabProjectHeaderBuilder? projectHeaderBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalPageControllerProvider(true));
    final selectedCategoryIds = state.selectedCategoryIds;
    final categoryId = selectedCategoryIds.length == 1
        ? selectedCategoryIds.first
        : null;

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
      ],
      child: Scaffold(
        backgroundColor: TaskShowcasePalette.page(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingAddIcon(
          createFn: () {
            unawaited(
              (onCreateTaskPressed ?? _defaultCreateTaskPressed)(
                ref,
                categoryId,
              ),
            );
          },
          semanticLabel: context.messages.addActionAddTask,
        ),
        body: _TasksTabPageBody(
          projectHeaderBuilder: projectHeaderBuilder,
        ),
      ),
    );
  }
}

class _TasksTabPageBody extends ConsumerStatefulWidget {
  const _TasksTabPageBody({
    this.projectHeaderBuilder,
  });

  final TasksTabProjectHeaderBuilder? projectHeaderBuilder;

  @override
  ConsumerState<_TasksTabPageBody> createState() => _TasksTabPageBodyState();
}

class _TasksTabPageBodyState extends ConsumerState<_TasksTabPageBody> {
  final _scrollController = ScrollController();
  final ValueNotifier<String?> _hoveredTaskIdNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
  }

  @override
  void dispose() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController
      ..removeListener(listener)
      ..dispose();
    _hoveredTaskIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalPageControllerProvider(true));
    final controller = ref.read(journalPageControllerProvider(true).notifier);

    return SafeArea(
      bottom: false,
      child: VisibilityDetector(
        key: const Key('tasks_tab_page'),
        onVisibilityChanged: controller.updateVisibility,
        child: RefreshIndicator(
          onRefresh: controller.refreshQuery,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _scrollController,
            cacheExtent: 1500,
            slivers: [
              SliverToBoxAdapter(
                child: ProjectsOverviewContentWidth(
                  child: TasksTabHeader(
                    query: state.match,
                    onSearchChanged: (value) {
                      unawaited(controller.setSearchString(value));
                    },
                    onSearchCleared: () {
                      unawaited(controller.setSearchString(''));
                    },
                    onSearchPressed: (value) {
                      unawaited(controller.setSearchString(value));
                    },
                    onFilterPressed: () =>
                        showTaskFilterModal(context, showTasks: true),
                  ),
                ),
              ),
              if (state.selectedLabelIds.isNotEmpty)
                SliverToBoxAdapter(
                  child: ProjectsOverviewContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: const TaskLabelQuickFilter(),
                      ),
                    ),
                  ),
                ),
              if (state.enableProjects &&
                  state.showProjectsHeader &&
                  state.selectedCategoryIds.length == 1)
                SliverToBoxAdapter(
                  child: ProjectsOverviewContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child:
                          (widget.projectHeaderBuilder ??
                          _defaultProjectHeaderBuilder)(
                            categoryId: state.selectedCategoryIds.first,
                            selectedProjectIds: state.selectedProjectIds,
                            onToggleProject: (projectId) {
                              unawaited(
                                controller.toggleProjectFilter(projectId),
                              );
                            },
                            onClearStale: (staleIds) {
                              unawaited(
                                controller.removeStaleProjectFilters(staleIds),
                              );
                            },
                          ),
                    ),
                  ),
                ),
              if (state.pagingController case final pagingController?)
                PagingListener<int, JournalEntity>(
                  controller: pagingController,
                  builder: (context, pagingState, fetchNextPage) {
                    final entries = buildTaskBrowseEntries(
                      items: pagingState.items ?? const <JournalEntity>[],
                      sortOption: state.sortOption,
                      now: clock.now(),
                      hasNextPage: pagingState.hasNextPage,
                    );
                    final entryIndexByTaskId = <String, int>{
                      for (var i = 0; i < entries.length; i++)
                        entries[i].task.meta.id: i,
                    };

                    return PagedSliverList<int, JournalEntity>(
                      state: pagingState,
                      fetchNextPage: fetchNextPage,
                      builderDelegate: PagedChildBuilderDelegate<JournalEntity>(
                        animateTransitions: true,
                        invisibleItemsThreshold: 10,
                        firstPageProgressIndicatorBuilder: (_) => const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                        newPageProgressIndicatorBuilder: (_) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                        noItemsFoundIndicatorBuilder: (_) => Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(
                            child: Text(context.messages.taskShowcaseNoResults),
                          ),
                        ),
                        itemBuilder: (context, item, index) {
                          if (item is! Task) {
                            return const SizedBox.shrink();
                          }
                          final entryIndex = entryIndexByTaskId[item.meta.id];
                          if (entryIndex == null) {
                            return const SizedBox.shrink();
                          }
                          final entry = entries[entryIndex];

                          final distance = state.showDistances
                              ? state.vectorSearchDistances[item.meta.id]
                              : null;

                          return ProjectsOverviewContentWidth(
                            child: TaskBrowseListItem(
                              key: ValueKey(item.meta.id),
                              entry: entry,
                              sortOption: state.sortOption,
                              showCreationDate: state.showCreationDate,
                              showDueDate: state.showDueDate,
                              showCoverArt: state.showCoverArt,
                              vectorDistance: distance,
                              previousTaskIdInSection:
                                  entryIndex > 0 && !entry.isFirstInSection
                                  ? entries[entryIndex - 1].task.meta.id
                                  : null,
                              nextTaskIdInSection:
                                  !entry.isLastInSection &&
                                      entryIndex < entries.length - 1
                                  ? entries[entryIndex + 1].task.meta.id
                                  : null,
                              hoveredTaskIdNotifier: _hoveredTaskIdNotifier,
                              onTap: () => getIt<NavService>().beamToNamed(
                                '/tasks/${item.meta.id}',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                )
              else
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _defaultCreateTaskPressed(
  WidgetRef ref,
  String? categoryId,
) async {
  // Capture the service before the await to avoid using ref after disposal.
  final agentService = ref.read(taskAgentServiceProvider);
  final task = await createTask(categoryId: categoryId);
  if (task != null) {
    unawaited(autoAssignCategoryAgentWith(agentService, task));
    getIt<NavService>().beamToNamed('/tasks/${task.meta.id}');
  }
}

Widget _defaultProjectHeaderBuilder({
  required String categoryId,
  required Set<String> selectedProjectIds,
  required void Function(String projectId) onToggleProject,
  required void Function(Set<String> staleIds) onClearStale,
}) {
  return ProjectHealthHeader(
    categoryId: categoryId,
    selectedProjectIds: selectedProjectIds,
    onToggleProject: onToggleProject,
    onClearStale: onClearStale,
  );
}
