import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

class ProjectsTabPage extends ConsumerStatefulWidget {
  const ProjectsTabPage({super.key});

  @override
  ConsumerState<ProjectsTabPage> createState() => _ProjectsTabPageState();
}

class _ProjectsTabPageState extends ConsumerState<ProjectsTabPage> {
  final _scrollController = ScrollController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopLayout(context);

    if (isDesktop) {
      final paneWidths = ref.watch(paneWidthControllerProvider);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ShowcasePalette.page(context),
        ),
        child: Row(
          children: [
            SizedBox(
              width: paneWidths.listPaneWidth,
              child: _ProjectsListScaffold(
                scrollController: _scrollController,
              ),
            ),
            ResizableDivider(
              onDrag: (delta) => ref
                  .read(paneWidthControllerProvider.notifier)
                  .updateListPaneWidth(delta),
            ),
            Expanded(
              child: ValueListenableBuilder<String?>(
                valueListenable: getIt<NavService>().desktopSelectedProjectId,
                builder: (context, selectedProjectId, _) {
                  if (selectedProjectId != null) {
                    return ProjectDetailsPage(
                      key: ValueKey(selectedProjectId),
                      projectId: selectedProjectId,
                    );
                  }
                  return DesktopDetailEmptyState(
                    message: context.messages.desktopEmptyStateSelectProject,
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return _ProjectsListScaffold(
      scrollController: _scrollController,
    );
  }
}

final _noProjectSelectionNotifier = ValueNotifier<String?>(null);

class _ProjectsListScaffold extends ConsumerWidget {
  const _ProjectsListScaffold({
    required this.scrollController,
  });

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(projectsOverviewProvider);
    final visibleGroupsAsync = ref.watch(visibleProjectGroupsProvider);
    final filter = ref.watch(projectsFilterControllerProvider);
    final categories = overviewAsync.maybeWhen(
      data: (overview) => _filterCategoriesFromOverview(overview.groups),
      orElse: () => const <CategoryDefinition>[],
    );
    final floatingActionButton = visibleGroupsAsync.maybeWhen(
      data: (_) => DesignSystemFloatingActionButton(
        semanticLabel: context.messages.projectCreateButton,
        onPressed: () => beamToNamed('/settings/projects/create'),
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
          data: (groups) => ValueListenableBuilder<String?>(
            valueListenable: isDesktopLayout(context)
                ? getIt<NavService>().desktopSelectedProjectId
                : _noProjectSelectionNotifier,
            builder: (context, activeProjectId, _) => Column(
              children: [
                TabSectionHeader(
                  title: context.messages.navTabTitleProjects,
                  query: filter.textQuery,
                  searchHint: context.messages.projectShowcaseSearchHint,
                  filterTooltip: context.messages.projectsFilterTooltip,
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
                    initialFilter: filter,
                    categories: categories,
                    onApplied: (nextFilter) {
                      ref
                              .read(projectsFilterControllerProvider.notifier)
                              .filter =
                          nextFilter;
                    },
                  ),
                ),
                _ProjectsTabActiveFilters(categories: categories),
                Expanded(
                  child: ProjectsOverviewContent(
                    title: context.messages.navTabTitleProjects,
                    renderHeader: false,
                    groups: groups,
                    query: filter.textQuery,
                    selectedProjectId: activeProjectId,
                    scrollController: scrollController,
                    listBottomPadding: 112,
                    onProjectTap: (project) {
                      beamToNamed('/projects/${project.project.meta.id}');
                    },
                  ),
                ),
              ],
            ),
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
    final categoryIds = filter.selectedCategoryIds;
    if (statusIds.isEmpty && categoryIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    for (final id in statusIds) {
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
      if (category == null) continue;
      chips.add(
        ActiveFilterChip(
          label: category.name,
          accentColor: accent,
          onRemove: () => controller.setSelectedCategoryIds(
            categoryIds.difference({id}),
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

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

List<CategoryDefinition> _filterCategoriesFromOverview(
  List<ProjectCategoryGroup> groups,
) {
  return groups
      .map((group) => group.category)
      .whereType<CategoryDefinition>()
      .toList(growable: false);
}
