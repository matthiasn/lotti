import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';
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
    final overviewAsync = ref.watch(projectsOverviewProvider);
    final visibleGroupsAsync = ref.watch(visibleProjectGroupsProvider);
    final filter = ref.watch(projectsFilterControllerProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final topPadding = isCompact ? 20.0 : 8.0;
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
          data: (groups) => ProjectsOverviewContent(
            title: context.messages.navTabTitleProjects,
            groups: groups,
            query: filter.textQuery,
            scrollController: _scrollController,
            headerPadding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
            listBottomPadding: 112,
            onSearchChanged: (value) {
              ref
                  .read(projectsFilterControllerProvider.notifier)
                  .setTextQuery(value);
            },
            onSearchCleared: () {
              ref
                  .read(projectsFilterControllerProvider.notifier)
                  .setTextQuery(
                    '',
                  );
            },
            onSearchPressed: (value) {
              ref
                  .read(projectsFilterControllerProvider.notifier)
                  .setTextQuery(value);
            },
            onProjectTap: (project) {
              beamToNamed('/projects/${project.project.meta.id}');
            },
            titleTrailing: Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: ShowcasePalette.highText(context),
            ),
            searchTrailing: IconButton(
              tooltip: context.messages.projectsFilterTooltip,
              onPressed: () => showProjectsFilterModal(
                context: context,
                initialFilter: filter,
                categories: categories,
                onApplied: (nextFilter) {
                  ref.read(projectsFilterControllerProvider.notifier).filter =
                      nextFilter;
                },
                presentation: isCompact
                    ? DesignSystemFilterPresentation.mobile
                    : DesignSystemFilterPresentation.desktop,
              ),
              icon: Icon(
                Icons.tune_rounded,
                size: 24,
                color: ShowcasePalette.teal(context),
              ),
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

List<CategoryDefinition> _filterCategoriesFromOverview(
  List<ProjectCategoryGroup> groups,
) {
  return groups
      .map((group) => group.category)
      .whereType<CategoryDefinition>()
      .toList(growable: false);
}
