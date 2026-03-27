import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

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
    final visibleGroupsAsync = ref.watch(visibleProjectGroupsProvider);

    return Scaffold(
      backgroundColor: ShowcasePalette.page(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: visibleGroupsAsync.maybeWhen(
        data: (_) => ProjectCreateFab(
          semanticLabel: context.messages.projectCreateButton,
          onPressed: () => beamToNamed('/settings/projects/create'),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        bottom: false,
        child: visibleGroupsAsync.when(
          data: (groups) => ProjectsOverviewContent(
            title: context.messages.navTabTitleProjects,
            groups: groups,
            searchEnabled: false,
            scrollController: _scrollController,
            listBottomPadding: 112,
            onProjectTap: (project) {
              final categoryId = project.project.meta.categoryId;
              beamToNamed(
                Uri(
                  path: '/settings/projects/${project.project.meta.id}',
                  queryParameters: categoryId == null
                      ? null
                      : {'categoryId': categoryId},
                ).toString(),
              );
            },
            titleTrailing: Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: ShowcasePalette.highText(context),
            ),
            searchTrailing: Icon(
              Icons.tune_rounded,
              size: 24,
              color: ShowcasePalette.teal(context),
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
