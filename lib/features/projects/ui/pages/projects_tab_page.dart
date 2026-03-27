import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
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
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final topPadding = isCompact ? 20.0 : 8.0;

    return Scaffold(
      backgroundColor: ShowcasePalette.page(context),
      body: SafeArea(
        bottom: false,
        child: DesignSystemScrollbar(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: ProjectsHeader(
                  title: context.messages.navTabTitleProjects,
                  searchEnabled: false,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topPadding,
                    16,
                    0,
                  ),
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
              ),
              ...visibleGroupsAsync.when(
                data: (groups) => groups.isEmpty
                    ? [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverToBoxAdapter(
                            child: _ProjectsOverviewMessage(
                              message:
                                  context.messages.projectShowcaseNoResults,
                            ),
                          ),
                        ),
                      ]
                    : [
                        ProjectsOverviewSliverList(
                          groups: groups,
                          onProjectTap: (project) {
                            final categoryId = project.project.meta.categoryId;
                            beamToNamed(
                              Uri(
                                path:
                                    '/settings/projects/${project.project.meta.id}',
                                queryParameters: categoryId == null
                                    ? null
                                    : {'categoryId': categoryId},
                              ).toString(),
                            );
                          },
                        ),
                      ],
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: DesignSystemSpinner(),
                    ),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ProjectsOverviewMessage(
                      message: context.messages.commonError,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsOverviewMessage extends StatelessWidget {
  const _ProjectsOverviewMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: ShowcasePalette.mediumText(context),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
