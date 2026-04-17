import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
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
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_quick_filter.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
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
import 'package:visibility_detector/visibility_detector.dart';

typedef TasksTabCreateTaskCallback =
    Future<void> Function(WidgetRef ref, String? categoryId);

class TasksTabPage extends ConsumerWidget {
  const TasksTabPage({
    super.key,
    this.onCreateTaskPressed,
  });

  final TasksTabCreateTaskCallback? onCreateTaskPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(journalPageControllerProvider(true));
    final selectedCategoryIds = state.selectedCategoryIds;
    final categoryId = selectedCategoryIds.length == 1
        ? selectedCategoryIds.first
        : null;
    final floatingActionButton = DesignSystemFloatingActionButton(
      semanticLabel: context.messages.addActionAddTask,
      onPressed: () {
        unawaited(
          (onCreateTaskPressed ?? _defaultCreateTaskPressed)(
            ref,
            categoryId,
          ),
        );
      },
    );

    return ProviderScope(
      overrides: [
        journalPageScopeProvider.overrideWithValue(true),
      ],
      child: Scaffold(
        // Task list pane uses the darker `background.level01` (#181818)
        // surface — Figma pairs it against the lighter sidebar (level02,
        // #222222) for contrast.
        backgroundColor: context.designTokens.colors.background.level01,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: DesignSystemBottomNavigationFabPadding(
          child: floatingActionButton,
        ),
        body: const _TasksTabPageBody(),
      ),
    );
  }
}

class _TasksTabPageBody extends ConsumerStatefulWidget {
  const _TasksTabPageBody();

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
      child: VisibilityDetector(
        key: const Key('tasks_tab_page'),
        onVisibilityChanged: controller.updateVisibility,
        child: ValueListenableBuilder<String?>(
          valueListenable: isDesktopLayout(context)
              ? getIt<NavService>().desktopSelectedTaskId
              : _noSelectionNotifier,
          builder: (context, activeTaskId, _) => Column(
            children: [
              TabSectionHeader(
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
              const _TasksTabActiveFilters(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refreshQuery,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    cacheExtent: 1500,
                    slivers: [
                      if (state.selectedLabelIds.isNotEmpty)
                        const SliverToBoxAdapter(
                          key: ValueKey('tasks-tab-label-quick-filter'),
                          child: ProjectsOverviewContentWidth(
                            child: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: _QuickLabelFilterContainer(),
                            ),
                          ),
                        ),
                      if (state.pagingController case final pagingController?)
                        PagingListener<int, JournalEntity>(
                          key: const ValueKey('tasks-tab-paged-list'),
                          controller: pagingController,
                          builder: (context, pagingState, fetchNextPage) {
                            final entries = buildTaskBrowseEntries(
                              items:
                                  pagingState.items ?? const <JournalEntity>[],
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
                                      ? state.vectorSearchDistances[item
                                            .meta
                                            .id]
                                      : null;

                                  return KeyedSubtree(
                                    key: ValueKey(item.meta.id),
                                    child: ProjectsOverviewContentWidth(
                                      child: TaskBrowseListItem(
                                        entry: entry,
                                        sortOption: state.sortOption,
                                        showCreationDate:
                                            state.showCreationDate,
                                        showDueDate: state.showDueDate,
                                        showCoverArt: true,
                                        vectorDistance: distance,
                                        previousTaskIdInSection:
                                            entryIndex > 0 &&
                                                !entry.isFirstInSection
                                            ? entries[entryIndex - 1]
                                                  .task
                                                  .meta
                                                  .id
                                            : null,
                                        nextTaskIdInSection:
                                            !entry.isLastInSection &&
                                                entryIndex < entries.length - 1
                                            ? entries[entryIndex + 1]
                                                  .task
                                                  .meta
                                                  .id
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
      if (category == null) continue;
      chips.add(
        ActiveFilterChip(
          label: category.name,
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
      if (label == null) continue;
      chips.add(
        ActiveFilterChip(
          label: label.name,
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

class _QuickLabelFilterContainer extends StatelessWidget {
  const _QuickLabelFilterContainer();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step2,
      ),
      child: const TaskLabelQuickFilter(),
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
