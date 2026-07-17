import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_rail.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Signature for the create-task action invoked by the [TasksTabPage] FAB.
typedef TasksTabCreateTaskCallback =
    Future<void> Function(
      WidgetRef ref,
      TaskCreationFilterContext filterContext,
    );

/// Unambiguous active-filter values inherited by a task created from the task
/// list.
///
/// Category, project, and status are populated only for a single real
/// selection. Every selected real label is retained. Empty IDs are UI
/// sentinels for "Unassigned" and are therefore never persisted on a task.
@immutable
class TaskCreationFilterContext {
  const TaskCreationFilterContext({
    this.categoryId,
    this.projectId,
    this.labelIds = const <String>{},
    this.status,
  });

  factory TaskCreationFilterContext.fromPageState(JournalPageState state) {
    return TaskCreationFilterContext(
      categoryId: _singleRealSelection(state.selectedCategoryIds),
      projectId: _singleRealSelection(state.selectedProjectIds),
      labelIds: Set<String>.unmodifiable(
        state.selectedLabelIds.where((id) => id.isNotEmpty),
      ),
      status: _singleRealSelection(state.selectedTaskStatuses),
    );
  }

  final String? categoryId;
  final String? projectId;
  final Set<String> labelIds;
  final String? status;
}

String? _singleRealSelection(Set<String> selections) {
  if (selections.length != 1) return null;
  final selection = selections.single;
  return selection.isEmpty ? null : selection;
}

/// Tasks list tab: a paginated, infinite-scroll list of tasks with a
/// search/filter header and a create-task floating action button.
///
/// Watches `journalPageControllerProvider(true)` for the active filter state
/// and feeds its paging controller into a [PagedSliverList] of
/// [TaskBrowseListItem]s; active filters are surfaced as removable chips and
/// pull-to-refresh swaps the page atomically. The FAB calls
/// [onCreateTaskPressed] (or a default that creates a task and navigates to
/// it) with every unambiguous inheritable filter value.
class TasksTabPage extends ConsumerStatefulWidget {
  const TasksTabPage({
    super.key,
    this.onCreateTaskPressed,
  });

  final TasksTabCreateTaskCallback? onCreateTaskPressed;

  @override
  ConsumerState<TasksTabPage> createState() => _TasksTabPageState();
}

class _TasksTabPageState extends ConsumerState<TasksTabPage> {
  final _searchFocusNode = FocusNode(debugLabel: 'tasks-search');

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalPageControllerProvider(true));
    final filterContext = TaskCreationFilterContext.fromPageState(state);
    final floatingActionButton = DesignSystemFloatingActionButton(
      semanticLabel: context.messages.addActionAddTask,
      onPressed: () {
        unawaited(
          (widget.onCreateTaskPressed ?? _defaultCreateTaskPressed)(
            ref,
            filterContext,
          ),
        );
      },
    );

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
      ],
      child: AppCommandScope(
        debugLabel: 'tasks-list',
        handlers: {
          AppCommandId.refresh: AppCommandHandler(
            invoke: (_) => ref
                .read(journalPageControllerProvider(true).notifier)
                .refreshQuery(preserveVisibleItems: true),
          ),
          AppCommandId.createInContext: AppCommandHandler(
            invoke: (_) =>
                (widget.onCreateTaskPressed ?? _defaultCreateTaskPressed)(
                  ref,
                  filterContext,
                ),
          ),
          AppCommandId.focusSearch: AppCommandHandler(
            invoke: (_) => _searchFocusNode.requestFocus(),
          ),
        },
        child: Scaffold(
          // Task list pane uses the darker `background.level01` (#181818)
          // surface — Figma pairs it against the lighter sidebar (level02,
          // #222222) for contrast.
          backgroundColor: context.designTokens.colors.background.level01,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: DesignSystemBottomNavigationFabPadding(
            child: floatingActionButton,
          ),
          body: _TasksTabPageBody(searchFocusNode: _searchFocusNode),
        ),
      ),
    );
  }
}

class _TasksTabPageBody extends ConsumerStatefulWidget {
  const _TasksTabPageBody({required this.searchFocusNode});

  final FocusNode searchFocusNode;

  @override
  ConsumerState<_TasksTabPageBody> createState() => _TasksTabPageBodyState();
}

/// A constant notifier that never changes, used to avoid creating a new
/// [ValueNotifier] on every build in mobile mode.
final _noSelectionNotifier = ValueNotifier<String?>(null);

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
      child: ValueListenableBuilder<String?>(
        valueListenable: isDesktopLayout(context)
            ? getIt<NavService>().desktopSelectedTaskId
            : _noSelectionNotifier,
        builder: (context, activeTaskId, _) => Column(
          children: [
            TabSectionHeader(
              searchFocusNode: widget.searchFocusNode,
              title: context.messages.navTabTitleTasks,
              query: state.match,
              searchHint: context.messages.searchTasksHint,
              filterTooltip: context.messages.tasksFilterTitle,
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
            // Saved views are task-scoped controls, so they stay beside the
            // task list on every form factor instead of displacing global
            // desktop navigation. The rail self-collapses when no views exist.
            const SavedTaskFilterRail(),
            const _TasksTabActiveFilters(),
            Expanded(
              child: RefreshIndicator(
                // Keep the current page's items visible while re-fetching
                // so pull-to-refresh swaps the list atomically instead of
                // blanking it mid-animation.
                onRefresh: () =>
                    controller.refreshQuery(preserveVisibleItems: true),
                child: CustomScrollView(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    if (state.pagingController case final pagingController?)
                      PagingListener<int, JournalEntity>(
                        key: const ValueKey('tasks-tab-paged-list'),
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
                              invisibleItemsThreshold: 10,
                              firstPageProgressIndicatorBuilder: (_) =>
                                  const Padding(
                                    padding: EdgeInsets.only(top: 32),
                                    child: Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    ),
                                  ),
                              newPageProgressIndicatorBuilder: (_) =>
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    ),
                                  ),
                              noItemsFoundIndicatorBuilder: (_) => Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Center(
                                  child: Text(
                                    context.messages.taskShowcaseNoResults,
                                  ),
                                ),
                              ),
                              itemBuilder: (context, item, index) {
                                if (item is! Task) {
                                  return const SizedBox.shrink();
                                }
                                final entryIndex =
                                    entryIndexByTaskId[item.meta.id];
                                if (entryIndex == null) {
                                  return const SizedBox.shrink();
                                }
                                final entry = entries[entryIndex];

                                final distance = state.showDistances
                                    ? state.vectorSearchDistances[item.meta.id]
                                    : null;

                                return KeyedSubtree(
                                  key: ValueKey(item.meta.id),
                                  child: ProjectsOverviewContentWidth(
                                    child: TaskBrowseListItem(
                                      entry: entry,
                                      sortOption: state.sortOption,
                                      showCreationDate: state.showCreationDate,
                                      showDueDate: state.showDueDate,
                                      showCoverArt: true,
                                      // When the user has narrowed the list
                                      // to a single status via the filter,
                                      // every row would carry the same
                                      // chip — drop it. With 0 (no filter)
                                      // or 2+ statuses selected the chip
                                      // disambiguates rows.
                                      showStatus:
                                          state.selectedTaskStatuses.length !=
                                          1,
                                      vectorDistance: distance,
                                      previousTaskIdInSection:
                                          entryIndex > 0 &&
                                              !entry.isFirstInSection
                                          ? entries[entryIndex - 1].task.meta.id
                                          : null,
                                      nextTaskIdInSection:
                                          !entry.isLastInSection &&
                                              entryIndex < entries.length - 1
                                          ? entries[entryIndex + 1].task.meta.id
                                          : null,
                                      selectedTaskId: activeTaskId,
                                      hoveredTaskIdNotifier:
                                          _hoveredTaskIdNotifier,
                                      onTap: () =>
                                          getIt<NavService>().beamToNamed(
                                            '/tasks/${item.meta.id}',
                                          ),
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
          ],
        ),
      ),
    );
  }
}

// ignore: specify_nonobvious_property_types
final _visibleProjectsTitleProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final projects = await getIt<JournalDb>().getVisibleProjects();
      return <String, String>{
        for (final project in projects) project.meta.id: project.data.title,
      };
    });

class _TasksTabActiveFilters extends ConsumerWidget {
  const _TasksTabActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalPageControllerProvider(true));
    final controller = ref.read(journalPageControllerProvider(true).notifier);
    final cache = getIt<EntitiesCacheService>();
    final projectTitles =
        ref.watch(_visibleProjectsTitleProvider).asData?.value ??
        const <String, String>{};
    final brightness = Theme.of(context).brightness;
    final accent = TaskShowcasePalette.accent(context);

    final statuses = state.selectedTaskStatuses;
    final priorities = state.selectedPriorities;
    final categoryIds = state.selectedCategoryIds;
    final labelIds = state.selectedLabelIds;
    final projectIds = state.selectedProjectIds;

    final total =
        statuses.length +
        priorities.length +
        categoryIds.length +
        labelIds.length +
        projectIds.length;
    if (total == 0) return const SizedBox.shrink();

    final chips = <Widget>[];

    for (final status in statuses) {
      chips.add(
        ActiveFilterChip(
          label: taskLabelFromStatusString(status, context),
          accentColor: taskColorFromStatusString(
            status,
            brightness: brightness,
          ),
          leadingIcon: taskIconFromStatusString(status),
          onRemove: () => unawaited(
            controller.applyBatchFilterUpdate(
              statuses: statuses.difference({status}),
            ),
          ),
        ),
      );
    }

    for (final priority in priorities) {
      final taskPriority = _priorityFromInternalId(priority);
      chips.add(
        ActiveFilterChip(
          label: priority,
          accentColor:
              _priorityAccent(priority, brightness: brightness) ?? accent,
          avatar: taskPriority != null
              ? TaskShowcasePriorityGlyph(priority: taskPriority)
              : null,
          onRemove: () => unawaited(
            controller.applyBatchFilterUpdate(
              priorities: priorities.difference({priority}),
            ),
          ),
        ),
      );
    }

    for (final id in categoryIds) {
      final category = cache.getCategoryById(id);
      final label = id.isEmpty
          ? context.messages.tasksQuickFilterUnassignedLabel
          : category?.name;
      if (label == null) continue;
      chips.add(
        ActiveFilterChip(
          label: label,
          accentColor: accent,
          onRemove: () => unawaited(
            controller.applyBatchFilterUpdate(
              categoryIds: categoryIds.difference({id}),
              projectIds: const <String>{},
            ),
          ),
        ),
      );
    }

    for (final id in labelIds) {
      final label = cache.getLabelById(id);
      final chipLabel = id.isEmpty
          ? context.messages.tasksQuickFilterUnassignedLabel
          : label?.name;
      if (chipLabel == null) continue;
      chips.add(
        ActiveFilterChip(
          label: chipLabel,
          accentColor: accent,
          onRemove: () => unawaited(
            controller.applyBatchFilterUpdate(
              labelIds: labelIds.difference({id}),
            ),
          ),
        ),
      );
    }

    for (final id in projectIds) {
      final title = projectTitles[id];
      if (title == null) continue;
      chips.add(
        ActiveFilterChip(
          label: title,
          accentColor: accent,
          leadingIcon: Icons.folder_outlined,
          onRemove: () => unawaited(
            controller.applyBatchFilterUpdate(
              projectIds: projectIds.difference({id}),
            ),
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    return ProjectsOverviewContentWidth(
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.step5),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: chips,
          ),
        ),
      ),
    );
  }
}

TaskPriority? _priorityFromInternalId(String id) => switch (id) {
  'P0' => TaskPriority.p0Urgent,
  'P1' => TaskPriority.p1High,
  'P2' => TaskPriority.p2Medium,
  'P3' => TaskPriority.p3Low,
  _ => null,
};

/// Accent colour for a priority chip — red for P0, green for P2, etc.,
/// picked up from the shared task colour palette so the chip border and
/// glyph match the priority badges used elsewhere in the app.
Color? _priorityAccent(String id, {required Brightness brightness}) {
  final isLight = brightness == Brightness.light;
  return switch (id) {
    'P0' => isLight ? taskIconColorDarkRed : taskIconColorRed,
    'P1' => isLight ? taskIconColorDarkOrange : taskIconColorOrange,
    'P2' => isLight ? taskIconColorDarkGreen : taskIconColorGreen,
    'P3' => isLight ? taskIconColorDarkBlue : taskIconColorBlue,
    _ => null,
  };
}

Future<void> _defaultCreateTaskPressed(
  WidgetRef ref,
  TaskCreationFilterContext filterContext,
) async {
  // Capture the service before the await to avoid using ref after disposal.
  final agentService = ref.read(taskAgentServiceProvider);
  final task = await createTask(
    categoryId: filterContext.categoryId,
    projectId: filterContext.projectId,
    labelIds: filterContext.labelIds.isEmpty
        ? null
        : filterContext.labelIds.toList(growable: false),
    status: filterContext.status,
  );
  if (task != null) {
    unawaited(autoAssignCategoryAgentWith(agentService, task));
    getIt<NavService>().beamToNamed('/tasks/${task.meta.id}');
  }
}
