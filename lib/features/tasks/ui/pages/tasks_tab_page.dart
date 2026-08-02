import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
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
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_rail.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsing_task_list_header.dart';
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
import 'package:lotti/utils/color.dart';
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
  final _collapseController = TaskListHeaderCollapseController();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _collapseController.addListener(_onCollapseChanged);
  }

  void _onSearchFocusChanged() {
    _collapseController.setSearchFocused(focused: _searchFocusNode.hasFocus);
  }

  /// A scroll-driven collapse hides the search field, so a field left focused
  /// (desktop keeps focus indefinitely after a click) must release it — the
  /// typed text lives in the page state and survives.
  void _onCollapseChanged() {
    if (_collapseController.collapsed && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _collapseController
      ..removeListener(_onCollapseChanged)
      ..dispose();
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
            invoke: (_) {
              _collapseController.expand();
              // The field does not exist while the header is collapsed, so
              // focusing it in the same frame as the expand is a no-op — the
              // shortcut would silently do nothing. Wait for the frame that
              // rebuilds the expanded header, exactly as the compact bar's
              // search affordance does.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _searchFocusNode.requestFocus();
              });
            },
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
          body: _TasksTabPageBody(
            searchFocusNode: _searchFocusNode,
            collapseController: _collapseController,
          ),
        ),
      ),
    );
  }
}

class _TasksTabPageBody extends ConsumerStatefulWidget {
  const _TasksTabPageBody({
    required this.searchFocusNode,
    required this.collapseController,
  });

  final FocusNode searchFocusNode;
  final TaskListHeaderCollapseController collapseController;

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
    _scrollController
      ..addListener(listener)
      ..addListener(_onScrolled);
    // Seed the collapse controller's delta baseline once the scroll view has
    // laid out, so even the first scroll event has an offset to diff against.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      widget.collapseController.primeBaseline(_scrollController.offset);
    });
  }

  /// Forwards each scroll frame to the collapse controller, mirroring how the
  /// task details page feeds its offset into `taskAppBarControllerProvider`.
  void _onScrolled() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _feedScroll(
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
    );
  }

  /// Whether this pane renders the collapsing header at all, mirrored from
  /// the [LayoutBuilder] that decides it. A desktop-wide pane shows the
  /// static header and must not accumulate collapse state behind it: the
  /// state machine would unfocus the still-visible search field, and
  /// narrowing the window later would snap the header shut with no gesture.
  bool _collapsingPane = true;

  /// Records, and answers, whether this pane keeps the static header. Called
  /// from the layout builder so the scroll feed and the rendered header can
  /// never disagree about which mode the pane is in.
  bool _paneUsesStaticHeader(BoxConstraints constraints) {
    final static = constraints.maxWidth >= kDesktopBreakpoint;
    _collapsingPane = !static;
    if (static && widget.collapseController.collapsed) {
      // Resizing INTO the static header must not leave a collapsed flag
      // behind for the next narrowing to spring on the user.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.collapseController.expand();
      });
    }
    return static;
  }

  void _feedScroll({
    required double pixels,
    required double maxScrollExtent,
  }) {
    if (!_collapsingPane) {
      widget.collapseController.expand();
      return;
    }
    widget.collapseController.handleScroll(
      pixels: pixels,
      maxScrollExtent: maxScrollExtent,
    );
  }

  @override
  void dispose() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController
      ..removeListener(listener)
      ..removeListener(_onScrolled)
      ..dispose();
    _hoveredTaskIdNotifier.dispose();
    super.dispose();
  }

  /// Re-expands the header and, once the search field is back on screen,
  /// hands it focus — the compact bar's search affordance.
  void _expandAndFocusSearch() {
    widget.collapseController.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.searchFocusNode.requestFocus();
    });
  }

  /// Opens the filter modal from the compact bar and, when it closes with a
  /// changed filter shape, re-expands the header so the chip row confirms
  /// what the user just applied. Closing without changes leaves the compact
  /// bar (and the user's scroll position focus) alone.
  Future<void> _openFiltersFromCompactBar() async {
    final before = _filterFingerprint(
      ref.read(journalPageControllerProvider(true)),
    );
    await showTaskFilterModal(context, showTasks: true);
    if (!mounted) return;
    final after = _filterFingerprint(
      ref.read(journalPageControllerProvider(true)),
    );
    if (before != after) widget.collapseController.expand();
  }

  /// Order-insensitive digest of every filter clause set, for detecting a
  /// changed filter shape across the modal round trip.
  static String _filterFingerprint(JournalPageState state) {
    final clauses = [
      state.selectedTaskStatuses,
      state.selectedPriorities,
      state.selectedCategoryIds,
      state.selectedLabelIds,
      state.selectedProjectIds,
      // Bracket every id: the empty string is a real selection ("Unassigned"),
      // so a bare join cannot tell {} from {''} and the header would miss a
      // filter change across the modal round trip.
    ].map((clause) => (clause.toList()..sort()).map((id) => '[$id]').join()).join('|');
    // The modal can also change agent mode, sort and (with vector search on)
    // the search MODE without touching a clause set. All three alter what the
    // list shows, so all three must re-expand the header.
    return '$clauses'
        '|${state.agentAssignmentFilter.name}'
        '|${state.sortOption.name}'
        '|${state.searchMode.name}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(journalPageControllerProvider(true));
    final controller = ref.read(journalPageControllerProvider(true).notifier);

    // One narrowing predicate for the whole page — the funnel tint, the
    // clause badge, the collapsed caption and the chip row all read the same
    // count, so they cannot claim different things about the same list.
    final liveFilter = liveTasksFilterFor(state);
    final activeFilterCount = taskFilterNarrowingClauseCount(liveFilter);
    final filtersActive = activeFilterCount > 0;

    final expandedHeader = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TabSectionHeader(
          searchFocusNode: widget.searchFocusNode,
          title: context.messages.navTabTitleTasks,
          query: state.match,
          searchHint: context.messages.searchTasksHint,
          filterTooltip: context.messages.tasksFilterTitle,
          filtersActive: filtersActive,
          onSearchChanged: (value) {
            unawaited(controller.setSearchString(value));
          },
          onSearchCleared: () {
            unawaited(controller.setSearchString(''));
          },
          onSearchPressed: (value) {
            unawaited(controller.setSearchString(value));
          },
          onFilterPressed: () => showTaskFilterModal(context, showTasks: true),
        ),
        // Desktop saved filters live under Tasks in the global sidebar.
        // Mobile retains the compact task-pane switcher because it has no
        // persistent navigation sidebar.
        if (!isDesktopLayout(context)) const SavedTaskFilterRail(),
        const _TasksTabActiveFilters(),
      ],
    );

    // A resolved saved view is the *named* abstraction of its clause shape:
    // the expanded header suppresses the clause chips for it, so the
    // collapsed bar mirrors that — name in the title, no clause-count badge —
    // and the two states never disagree about how narrowing is represented.
    final activeSavedFilterId = ref.watch(currentSavedTaskFilterIdProvider);
    final savedFilters =
        ref.watch(savedTaskFiltersControllerProvider).value ??
        const <SavedTaskFilter>[];
    final activeSavedFilterName = activeSavedFilterId == null
        ? null
        : savedFilters
              .where((filter) => filter.id == activeSavedFilterId)
              .firstOrNull
              ?.name;

    // The compact title's context run names every narrowing species through
    // one channel, composed rather than precedence-picked: the saved view's
    // name OR the localized ad-hoc clause count, then the search query in
    // locale quotation marks — 'Errands · “x”', '4 filters', '“x”'.
    final contextParts = <String>[
      if (activeSavedFilterName != null)
        activeSavedFilterName
      else if (filtersActive)
        context.messages.tasksCompactFilterCount(activeFilterCount),
      if (state.match.isNotEmpty)
        context.messages.tasksCompactSearchContext(state.match),
    ];

    final compactBar = TaskListCompactHeaderBar(
      title: context.messages.navTabTitleTasks,
      searchTooltip: context.messages.searchTasksHint,
      filterTooltip: context.messages.tasksFilterTitle,
      expandSemanticHint: context.messages.tasksCompactHeaderExpandHint,
      filtersActive: filtersActive,
      searchActive: state.match.isNotEmpty,
      contextLabel: contextParts.isEmpty ? null : contextParts.join(' · '),
      onExpandRequested: widget.collapseController.expand,
      onSearchRequested: _expandAndFocusSearch,
      onFilterPressed: () => unawaited(_openFiltersFromCompactBar()),
    );

    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<String?>(
        valueListenable: isDesktopLayout(context)
            ? getIt<NavService>().desktopSelectedTaskId
            : _noSelectionNotifier,
        builder: (context, activeTaskId, _) => LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // Gate on the PANE's width, not the window's: the desktop
              // split view hosts this page in a ~400px list pane where
              // vertical space is as scarce as on a phone, so it collapses
              // too. Only a pane that is itself desktop-wide (full-width
              // window with no split) keeps the static header.
              if (_paneUsesStaticHeader(constraints))
                expandedHeader
              else
                ListenableBuilder(
                  listenable: widget.collapseController,
                  builder: (context, _) => CollapsingTaskListHeader(
                    collapsed: widget.collapseController.collapsed,
                    reduceMotion: MediaQuery.disableAnimationsOf(context),
                    expandedHeader: expandedHeader,
                    compactBar: compactBar,
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  // Keep the current page's items visible while re-fetching
                  // so pull-to-refresh swaps the list atomically instead of
                  // blanking it mid-animation.
                  onRefresh: () =>
                      controller.refreshQuery(preserveVisibleItems: true),
                  child: NotificationListener<ScrollMetricsNotification>(
                    // Content can shrink without any gesture (a filter narrowing
                    // the list); if it can no longer scroll, the collapse
                    // controller must re-expand the header itself.
                    onNotification: (notification) {
                      widget.collapseController.handleContentDimensionsChanged(
                        maxScrollExtent: notification.metrics.maxScrollExtent,
                        pixels: notification.metrics.pixels,
                      );
                      return false;
                    },
                    child: NotificationListener<ScrollNotification>(
                      // The scrollable's own notifications — not the
                      // [ScrollController] listener — are the authoritative
                      // scroll signal: they fire for every input path (touch
                      // drag, trackpad, wheel, scrollbar jump, keyboard) and
                      // survive a controller that is momentarily detached or
                      // attached to a rebuilt viewport. depth 0 keeps nested
                      // horizontal scrollers inside rows from driving the
                      // header.
                      onNotification: (notification) {
                        if (notification.depth == 0 &&
                            notification is ScrollUpdateNotification) {
                          _feedScroll(
                            pixels: notification.metrics.pixels,
                            maxScrollExtent:
                                notification.metrics.maxScrollExtent,
                          );
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _scrollController,
                        slivers: [
                          if (state.pagingController
                              case final pagingController?)
                            PagingListener<int, JournalEntity>(
                              key: const ValueKey('tasks-tab-paged-list'),
                              controller: pagingController,
                              builder: (context, pagingState, fetchNextPage) {
                                final entries = buildTaskBrowseEntries(
                                  items:
                                      pagingState.items ??
                                      const <JournalEntity>[],
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
                                    // The sliver has no horizontal inset, so
                                    // this indicator must bring its own — a
                                    // message long enough to wrap (long
                                    // locale, large text scale) otherwise
                                    // renders flush against the screen edge.
                                    noItemsFoundIndicatorBuilder: (context) =>
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: context
                                                .designTokens
                                                .spacing
                                                .step9,
                                          ),
                                          child: DesignSystemEmptyState(
                                            icon: Icons.list_outlined,
                                            title: context
                                                .messages
                                                .taskShowcaseNoResults,
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
                                        child: DetailContentWidth(
                                          child: TaskBrowseListItem(
                                            entry: entry,
                                            sortOption: state.sortOption,
                                            showCreationDate:
                                                state.showCreationDate,
                                            showDueDate: state.showDueDate,
                                            showCoverArt: true,
                                            // When the user has narrowed the list
                                            // to a single status via the filter,
                                            // every row would carry the same
                                            // chip — drop it. With 0 (no filter)
                                            // or 2+ statuses selected the chip
                                            // disambiguates rows.
                                            showStatus:
                                                state
                                                    .selectedTaskStatuses
                                                    .length !=
                                                1,
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
                                                    entryIndex <
                                                        entries.length - 1
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

/// Returns the task list to its RESTING view: the default open-work status
/// set, every optional facet cleared, and no search query.
///
/// Deliberately not [SavedTaskFilterActivator.clearToDefault], which the
/// rail's "All" pill uses: that writes an EMPTY status set, and
/// `JournalPageController._buildQueryParams` reads empty as "every status",
/// so it deliberately *widens* the list to include done, rejected and parked
/// tasks. "All tasks" means that; "Clear all" does not — a user removing
/// their filters expects the view they started from, not one with more in it
/// than they have ever seen.
///
/// The two writes are sequenced rather than raced: they target one controller
/// and each triggers its own query refresh, so `Future.wait` would interleave
/// them non-deterministically.
Future<void> _clearAll(
  JournalPageController controller,
  bool searchActive,
) async {
  await controller.applyBatchFilterUpdate(
    statuses: defaultSelectedTaskStatuses,
    categoryIds: const <String>{},
    labelIds: const <String>{},
    projectIds: const <String>{},
    priorities: const <String>{},
    sortOption: TaskSortOption.byPriority,
    agentAssignmentFilter: AgentAssignmentFilter.all,
  );
  if (searchActive) await controller.setSearchString('');
}

/// The entity's own colour where it has one, falling back to the page accent.
///
/// Same resolution the saved-filter rail and the task rows use, so one
/// category reads as one colour everywhere on the page.
Color _entityAccent(String? hex, Color fallback) =>
    hex == null || hex.isEmpty ? fallback : colorFromCssHex(hex);

class _TasksTabActiveFilters extends ConsumerWidget {
  const _TasksTabActiveFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A matched saved view is already the named abstraction for its complete
    // filter shape. Repeating every underlying clause immediately below it
    // creates a second, competing representation of the same state. Keep
    // removable chips for ad-hoc/custom filters only.
    final activeId = ref.watch(currentSavedTaskFilterIdProvider);
    final saved =
        ref.watch(savedTaskFiltersControllerProvider).value ??
        const <SavedTaskFilter>[];
    final hasResolvedSavedView =
        activeId != null && saved.any((filter) => filter.id == activeId);
    if (hasResolvedSavedView) {
      return const SizedBox.shrink();
    }

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

    // The default open-work status set is the page's resting view, not a
    // narrowing — echoing it as removable chips made an unfiltered list look
    // filtered, and made the chip count disagree with the collapsed bar's
    // clause badge. Status chips appear only once the selection deviates.
    final statusesNarrowed = !setEquals(statuses, defaultSelectedTaskStatuses);

    final agentFilter = state.agentAssignmentFilter;

    if (taskFilterNarrowingClauseCount(liveTasksFilterFor(state)) == 0) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    // The agent clause narrows the list exactly like a facet does, so it is
    // represented and removable exactly like one — otherwise the header could
    // read "1 filter" with an empty chip row below it.
    if (agentFilter != AgentAssignmentFilter.all) {
      chips.add(
        ActiveFilterChip(
          label: agentFilter == AgentAssignmentFilter.hasAgent
              ? context.messages.tasksAgentFilterHasAgent
              : context.messages.tasksAgentFilterNoAgent,
          accentColor: accent,
          leadingIcon: Icons.smart_toy_outlined,
          onRemove: () => unawaited(
            controller.applyBatchFilterUpdate(
              agentAssignmentFilter: AgentAssignmentFilter.all,
            ),
          ),
        ),
      );
    }

    for (final status in statusesNarrowed ? statuses : const <String>{}) {
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
          // The category's OWN colour, resolved exactly as the rail and the
          // task rows do. Painting every category chip with the shared teal
          // made "Personal" mint in the header and blue on every row beneath
          // it, and spent the selection accent on something that isn't a
          // selection state.
          accentColor: _entityAccent(category?.color, accent),
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
          accentColor: _entityAccent(label?.color, accent),
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

    // Ending a multi-clause filter session chip-by-chip is the most
    // expensive common exit on the page; from two narrowings up, one tap
    // restores the resting view. See [_clearAll] for why that is NOT the
    // rail's "All" reset. It also clears the search query — "Clear all"
    // that leaves a query silently narrowing the list is a lie, and the
    // query is counted below so the chip appears whenever two things are
    // narrowing, whichever kind they are. The leading pad separates the
    // batch action from the single-chip removals beside it.
    final searchActive = state.match.isNotEmpty;
    if (chips.length + (searchActive ? 1 : 0) >= 2) {
      final tokens = context.designTokens;
      chips.add(
        Padding(
          padding: EdgeInsets.only(left: tokens.spacing.step3),
          child: DesignSystemChip(
            // Same metrics as the ActiveFilterChips it shares the wrap with,
            // so the batch action reads as part of that row rather than as a
            // louder, squarer component glued onto it.
            size: DesignSystemChipSize.compactPill,
            label: context.messages.tasksFilterClearAll,
            leadingIcon: Icons.close_rounded,
            onPressed: () => unawaited(_clearAll(controller, searchActive)),
          ),
        ),
      );
    }

    final tokens = context.designTokens;
    return DetailContentWidth(
      child: Padding(
        // The step2 top beat matches the rail's own vertical padding, so
        // search -> rail and rail -> chips share one rhythm.
        padding: EdgeInsets.only(
          top: tokens.spacing.step2,
          bottom: tokens.spacing.step5,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            // Chips in a run differ slightly in height (glyph vs avatar vs
            // plain); centre them so a shorter one stops hanging off the top.
            crossAxisAlignment: WrapCrossAlignment.center,
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
