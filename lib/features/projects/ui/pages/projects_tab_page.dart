import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Top-level Projects tab.
///
/// On desktop it renders a resizable two-pane layout: a list scaffold on the
/// left (width driven by [paneWidthControllerProvider] via a [ResizableDivider])
/// and, on the right, [ProjectDetailsPage] for the project currently selected
/// in `NavService.desktopSelectedProjectId`, falling back to an empty-state.
/// With a selection, the list can move offstage into persisted focus mode while
/// retaining its state. On mobile it shows only the list scaffold; tapping a
/// project beams to `/projects/<id>`.
///
/// The list scaffold watches [visibleProjectGroupsProvider] (the raw
/// [projectsOverviewProvider] snapshot with [projectsFilterControllerProvider]
/// applied), wires the search/filter header into that filter controller, and
/// offers a create-project FAB. Scrolling pings [UserActivityService] to keep
/// the session active.
class ProjectsTabPage extends ConsumerStatefulWidget {
  const ProjectsTabPage({super.key});

  @override
  ConsumerState<ProjectsTabPage> createState() => _ProjectsTabPageState();
}

class _ProjectsTabPageState extends ConsumerState<ProjectsTabPage> {
  final _scrollController = ScrollController();
  final _searchFocusNode = FocusNode(debugLabel: 'projects-search');

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
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopLayout(context);

    final Widget child;
    if (isDesktop) {
      final paneWidths = ref.watch(paneWidthControllerProvider);
      // Scales the flat default proportionally on large windows — see
      // scaledPaneWidth's doc comment. A no-op once the user has dragged
      // the list pane to any other width.
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
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: ShowcasePalette.page(context),
        ),
        child: ValueListenableBuilder<String?>(
          valueListenable: getIt<NavService>().desktopSelectedProjectId,
          builder: (context, selectedProjectId, _) {
            final canHideListPane = selectedProjectId != null;
            final listPaneVisible =
                !paneWidths.listPaneCollapsed || !canHideListPane;

            return ListDetailFocusTraversal(
              debugLabel: 'projects-split',
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
                child: _ProjectsListScaffold(
                  scrollController: _scrollController,
                  searchFocusNode: _searchFocusNode,
                ),
              ),
              divider: ResizableDivider(
                currentValue: listPaneWidth,
                minValue: minListPaneWidth,
                maxValue: maxListPaneWidth,
                onDrag: resolvedListPane.onDrag,
              ),
              detailPane: selectedProjectId != null
                  ? _ProjectsDetailPane(
                      key: ValueKey(selectedProjectId),
                      projectId: selectedProjectId,
                    )
                  : DesktopDetailEmptyState(
                      message: context.messages.desktopEmptyStateSelectProject,
                    ),
            );
          },
        ),
      );
    } else {
      child = _ProjectsListScaffold(
        scrollController: _scrollController,
        searchFocusNode: _searchFocusNode,
      );
    }

    return AppCommandScope(
      handlers: {
        AppCommandId.focusSearch: AppCommandHandler(
          invoke: (_) => _focusSearch(isDesktop: isDesktop),
        ),
        AppCommandId.createInContext: AppCommandHandler(
          invoke: (invocation) =>
              showProjectCreateModal(context: invocation.context),
        ),
      },
      child: child,
    );
  }

  void _focusSearch({required bool isDesktop}) {
    if (!isDesktop) {
      _searchFocusNode.requestFocus();
      return;
    }

    ref.read(paneWidthControllerProvider.notifier).expandListPane();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

final _noProjectSelectionNotifier = ValueNotifier<String?>(null);

class _ProjectsDetailPane extends StatelessWidget {
  const _ProjectsDetailPane({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    final detail = ProjectDetailsPage(projectId: projectId);
    final tokens = context.designTokens;
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
                  left: tokens.spacing.step5,
                  top: tokens.spacing.step4,
                ),
                child: TabHeaderIconButton(
                  key: const ValueKey('projects-show-list-pane'),
                  icon: Icons.view_sidebar_rounded,
                  tooltip: context.messages.listPaneShowTooltip,
                  onPressed: splitController!.showListPane,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectsListScaffold extends ConsumerWidget {
  const _ProjectsListScaffold({
    required this.scrollController,
    required this.searchFocusNode,
  });

  final ScrollController scrollController;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final splitController = ListDetailFocusTraversal.maybeOf(context);
    final canHideListPane =
        splitController?.listPaneVisible == true &&
        splitController?.canHideListPane == true;
    final overviewAsync = ref.watch(projectsOverviewProvider);
    final visibleGroupsAsync = ref.watch(visibleProjectGroupsProvider);
    final filter = ref.watch(projectsFilterControllerProvider);
    final filtersActive =
        filter.selectedCategoryIds.isNotEmpty ||
        (filter.selectedStatusIds.isNotEmpty &&
            !const SetEquality<String>().equals(
              filter.selectedStatusIds,
              currentProjectStatusFilterIds,
            )) ||
        filter.sortMode != ProjectsSortMode.actionable;
    // Reserve room so the floating create button never lands on top of the
    // last project card. The FAB is lifted above the bottom nav by
    // `occupiedHeight`, so the scroll content must clear that plus the FAB's
    // own footprint (step12) — same clearance the AI settings list uses.
    final listBottomPadding =
        DesignSystemBottomNavigationBar.occupiedHeight(context) +
        tokens.spacing.step12;
    final categories = overviewAsync.maybeWhen(
      data: (overview) => _filterCategoriesFromOverview(overview.groups),
      orElse: () => const <CategoryDefinition>[],
    );
    final rawHasProjects = overviewAsync.maybeWhen(
      data: (overview) =>
          overview.groups.any((group) => group.projects.isNotEmpty),
      orElse: () => false,
    );
    final isDefaultCurrent =
        const SetEquality<String>().equals(
          filter.selectedStatusIds,
          currentProjectStatusFilterIds,
        ) &&
        filter.selectedCategoryIds.isEmpty &&
        filter.textQuery.trim().isEmpty &&
        filter.sortMode == ProjectsSortMode.actionable;
    final floatingActionButton = visibleGroupsAsync.maybeWhen(
      data: (_) => DesignSystemFloatingActionButton(
        semanticLabel: context.messages.projectCreateButton,
        onPressed: () => showProjectCreateModal(context: context),
      ),
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: ShowcasePalette.page(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: floatingActionButton == null
          ? null
          : DesignSystemBottomNavigationFabPadding(
              child: floatingActionButton,
            ),
      body: SafeArea(
        bottom: false,
        child: visibleGroupsAsync.when(
          skipLoadingOnReload: true,
          data: (groups) => ValueListenableBuilder<String?>(
            valueListenable: isDesktopLayout(context)
                ? getIt<NavService>().desktopSelectedProjectId
                : _noProjectSelectionNotifier,
            builder: (context, activeProjectId, _) {
              return Column(
                children: [
                  TabSectionHeader(
                    searchFocusNode: searchFocusNode,
                    title: context.messages.navTabTitleProjects,
                    query: filter.textQuery,
                    searchHint: context.messages.projectShowcaseSearchHint,
                    filterTooltip: context.messages.projectsFilterTooltip,
                    filtersActive: filtersActive,
                    titleLeading: canHideListPane
                        ? TabHeaderIconButton(
                            key: const ValueKey(
                              'projects-hide-list-pane',
                            ),
                            icon: Icons.view_sidebar_rounded,
                            tooltip: context.messages.listPaneHideTooltip,
                            onPressed: splitController!.hideListPane,
                          )
                        : null,
                    onSearchChanged: (value) {
                      ref
                          .read(projectsFilterControllerProvider.notifier)
                          .setTextQuery(value);
                    },
                    onSearchCleared: () {
                      ref
                          .read(projectsFilterControllerProvider.notifier)
                          .setTextQuery('');
                    },
                    onSearchPressed: (value) {
                      ref
                          .read(projectsFilterControllerProvider.notifier)
                          .setTextQuery(value);
                    },
                    onFilterPressed: () => showProjectsFilterModal(
                      context: context,
                      initialFilter: ref
                          .read(projectsFilterControllerProvider.notifier)
                          .filter,
                      categories: categories,
                      onApplied: (nextFilter) {
                        ref
                                .read(projectsFilterControllerProvider.notifier)
                                .filter =
                            nextFilter;
                      },
                    ),
                  ),
                  const _ProjectsViewControls(),
                  _ProjectsTabActiveFilters(categories: categories),
                  Expanded(
                    child: ProjectsOverviewContent(
                      title: context.messages.navTabTitleProjects,
                      renderHeader: false,
                      groups: groups,
                      query: filter.textQuery,
                      selectedProjectId: activeProjectId,
                      scrollController: scrollController,
                      listBottomPadding: listBottomPadding,
                      emptyTitle: !rawHasProjects
                          ? context.messages.projectsEmptyTitle
                          : isDefaultCurrent
                          ? context.messages.projectsEmptyCurrentTitle
                          : context.messages.projectsEmptyFilteredTitle,
                      emptyBody: !rawHasProjects
                          ? context.messages.projectsEmptyBody
                          : isDefaultCurrent
                          ? context.messages.projectsEmptyCurrentBody
                          : context.messages.projectsEmptyFilteredBody,
                      emptyActionLabel: !rawHasProjects
                          ? context.messages.projectCreateButton
                          : isDefaultCurrent
                          ? context.messages.projectsScopeAll
                          : context.messages.projectsClearFilters,
                      onEmptyAction: !rawHasProjects
                          ? () => showProjectCreateModal(context: context)
                          : isDefaultCurrent
                          ? () => ref
                                .read(
                                  projectsFilterControllerProvider.notifier,
                                )
                                .setSelectedStatusIds(const {})
                          : () => ref
                                .read(
                                  projectsFilterControllerProvider.notifier,
                                )
                                .resetToCurrent(),
                      onProjectTap: (project) {
                        beamToNamed('/projects/${project.project.meta.id}');
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          loading: () => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          error: (error, _) => Center(
            child: Text(context.messages.commonError),
          ),
        ),
      ),
    );
  }
}

class _ProjectsViewControls extends ConsumerWidget {
  const _ProjectsViewControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final filter = ref.watch(projectsFilterControllerProvider);
    final controller = ref.read(projectsFilterControllerProvider.notifier);
    final isCurrent = const SetEquality<String>().equals(
      filter.selectedStatusIds,
      currentProjectStatusFilterIds,
    );
    final isAll = filter.selectedStatusIds.isEmpty;

    return DetailContentWidth(
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.step4),
        child: Row(
          children: [
            DesignSystemChip(
              label: context.messages.projectsScopeCurrent,
              selected: isCurrent,
              size: DesignSystemChipSize.compactPill,
              onPressed: () => controller.setSelectedStatusIds(
                currentProjectStatusFilterIds,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            DesignSystemChip(
              label: context.messages.projectsScopeAll,
              selected: isAll,
              size: DesignSystemChipSize.compactPill,
              onPressed: () => controller.setSelectedStatusIds(const {}),
            ),
            const Spacer(),
            DesignSystemContextMenuButton(
              icon: Icons.sort_rounded,
              tooltip: context.messages.projectsSortTooltip,
              items: [
                for (final mode in ProjectsSortMode.values)
                  DesignSystemContextMenuItem(
                    label: _sortModeLabel(context, mode),
                    icon: filter.sortMode == mode ? Icons.check_rounded : null,
                    onTap: () => controller.setSortMode(mode),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _sortModeLabel(BuildContext context, ProjectsSortMode mode) =>
    switch (mode) {
      ProjectsSortMode.actionable => context.messages.projectsSortActionable,
      ProjectsSortMode.targetDate => context.messages.projectsSortTargetDate,
      ProjectsSortMode.recent => context.messages.projectsSortRecent,
      ProjectsSortMode.name => context.messages.projectsSortName,
    };

/// Renders a chip row reflecting the currently active Projects-tab filters
/// (status + category). Each chip removes its filter when tapped or when
/// its ✕ is pressed. Hidden entirely when no filters are active.
class _ProjectsTabActiveFilters extends ConsumerWidget {
  const _ProjectsTabActiveFilters({required this.categories});

  final List<CategoryDefinition> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(projectsFilterControllerProvider);
    final controller = ref.read(projectsFilterControllerProvider.notifier);
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;

    final statusIds = filter.selectedStatusIds;
    final showStatusChips = !const SetEquality<String>().equals(
      statusIds,
      currentProjectStatusFilterIds,
    );
    final categoryIds = filter.selectedCategoryIds;
    if (statusIds.isEmpty && categoryIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    for (final id in showStatusChips ? statusIds : const <String>{}) {
      final kind = projectStatusKindFromFilterId(id);
      final status = buildProjectStatus(kind, DateTime(2000));
      final (label, color, icon) = projectStatusAttributes(context, status);
      chips.add(
        ActiveFilterChip(
          label: label,
          accentColor: color,
          leadingIcon: icon,
          onRemove: () => controller.setSelectedStatusIds(
            statusIds.difference({id}),
          ),
        ),
      );
    }

    final categoriesById = {for (final c in categories) c.id: c};
    for (final id in categoryIds) {
      final category = categoriesById[id];
      chips.add(
        ActiveFilterChip(
          label: category?.name ?? context.messages.projectsUnavailableCategory,
          accentColor: accent,
          onRemove: () => controller.setSelectedCategoryIds(
            categoryIds.difference({id}),
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return DetailContentWidth(
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

List<CategoryDefinition> _filterCategoriesFromOverview(
  List<ProjectCategoryGroup> groups,
) {
  return groups
      .map((group) => group.category)
      .whereType<CategoryDefinition>()
      .toList(growable: false);
}
