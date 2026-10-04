part of 'tasks_tab_page.dart';

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
          leadingIcon: LottiIcons.aiModel,
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
          leadingIcon: LottiIcons.folder,
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
            leadingIcon: LottiIcons.close,
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
  final context = ref.context;
  Task? task;
  try {
    task = await createTask(
      categoryId: filterContext.categoryId,
      projectId: filterContext.projectId,
      labelIds: filterContext.labelIds.isEmpty
          ? null
          : filterContext.labelIds.toList(growable: false),
      status: filterContext.status,
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to create task',
      name: 'TasksTabPage',
      error: error,
      stackTrace: stackTrace,
    );
  }
  if (task == null) {
    if (!context.mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.commonError,
    );
    return;
  }
  // Awaited, not fire-and-forget: the assignment decides what the task page
  // paints. Navigating first meant a category with a default agent opened
  // its new task as first-run (block, narrow measure), then flipped to the
  // established layout the moment the agent landed — a full reflow one beat
  // after the page appeared. It is a local write, and it is a no-op for a
  // category with no default template.
  await autoAssignCategoryAgentWith(agentService, task);
  ref.read(navServiceProvider).beamToNamed('/tasks/${task.meta.id}');
}
