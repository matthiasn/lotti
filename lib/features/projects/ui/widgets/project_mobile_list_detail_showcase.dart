import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_chrome.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/projects_filter_modal.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_content.dart';
import 'package:lotti/features/projects/ui/widgets/review_sessions_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

const _kMobileScreenWidth = 402.0;
const _kMobileScreenGap = 32.0;

class ProjectMobileListDetailShowcase extends ConsumerStatefulWidget {
  const ProjectMobileListDetailShowcase({super.key});

  @override
  ConsumerState<ProjectMobileListDetailShowcase> createState() =>
      _ProjectMobileListDetailShowcaseState();
}

class _ProjectMobileListDetailShowcaseState
    extends ConsumerState<ProjectMobileListDetailShowcase> {
  bool _showDetailInCompactMode = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectListDetailShowcaseControllerProvider);
    final controller = ref.read(
      projectListDetailShowcaseControllerProvider.notifier,
    );
    final selected = state.selectedProject;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSplitView =
            constraints.maxWidth >=
            (_kMobileScreenWidth * 2) + _kMobileScreenGap;

        if (showSplitView) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProjectMobileListScreen(
                state: state,
                onSearchChanged: controller.updateSearchQuery,
                onSearchCleared: () => controller.updateSearchQuery(''),
                onFilterPressed: () => showProjectsFilterModal(
                  context: context,
                  initialFilter: state.filter,
                  categories: state.data.categories,
                  onApplied: controller.updateFilter,
                  presentation: DesignSystemFilterPresentation.mobile,
                ),
                onProjectOpened: controller.selectProject,
              ),
              const SizedBox(width: _kMobileScreenGap),
              if (selected != null)
                _ProjectMobileDetailScreen(
                  record: selected,
                  currentTime: state.data.currentTime,
                ),
            ],
          );
        }

        if (_showDetailInCompactMode && selected != null) {
          return _ProjectMobileDetailScreen(
            record: selected,
            currentTime: state.data.currentTime,
            onBack: () {
              setState(() {
                _showDetailInCompactMode = false;
              });
            },
          );
        }

        return _ProjectMobileListScreen(
          state: state,
          onSearchChanged: controller.updateSearchQuery,
          onSearchCleared: () => controller.updateSearchQuery(''),
          onFilterPressed: () => showProjectsFilterModal(
            context: context,
            initialFilter: state.filter,
            categories: state.data.categories,
            onApplied: controller.updateFilter,
            presentation: DesignSystemFilterPresentation.mobile,
          ),
          onProjectOpened: (projectId) {
            controller.selectProject(projectId);
            setState(() {
              _showDetailInCompactMode = true;
            });
          },
        );
      },
    );
  }
}

class _ProjectMobileListScreen extends StatelessWidget {
  const _ProjectMobileListScreen({
    required this.state,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onFilterPressed,
    required this.onProjectOpened,
  });

  final ProjectListDetailState state;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onFilterPressed;
  final ValueChanged<String> onProjectOpened;

  @override
  Widget build(BuildContext context) {
    final groups = state.visibleGroups;
    final selectedId = state.selectedProject?.project.meta.id;

    return DesignSystemShowcaseMobileShell(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DesignSystemShowcaseMobileStatusBar(),
              Expanded(
                child: ProjectsOverviewContent(
                  title: context.messages.designSystemBreadcrumbProjectsLabel,
                  query: state.searchQuery,
                  groups: groups,
                  selectedProjectId: selectedId,
                  onSearchChanged: onSearchChanged,
                  onSearchCleared: onSearchCleared,
                  onSearchPressed: onSearchChanged,
                  onProjectTap: (item) => onProjectOpened(item.project.meta.id),
                  titleTrailing: Icon(
                    Icons.notifications_none_rounded,
                    size: 34,
                    color: ShowcasePalette.highText(context),
                  ),
                  searchTrailing: IconButton(
                    tooltip: context.messages.projectsFilterTooltip,
                    onPressed: onFilterPressed,
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 24,
                      color: ShowcasePalette.teal(context),
                    ),
                  ),
                  listBottomPadding: 184,
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 140,
            child: ProjectCreateFab(
              semanticLabel: context.messages.designSystemNavigationNewLabel,
              onPressed: () {},
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: DesignSystemNavigationTabBar(
                            items: [
                              DesignSystemNavigationTabBarItem(
                                label: context
                                    .messages
                                    .designSystemNavigationMyDailyLabel,
                                icon: Icons.calendar_today_outlined,
                              ),
                              DesignSystemNavigationTabBarItem(
                                label: context.messages.navTabTitleTasks,
                                icon: Icons.format_list_bulleted_rounded,
                              ),
                              DesignSystemNavigationTabBarItem(
                                label: context
                                    .messages
                                    .designSystemBreadcrumbProjectsLabel,
                                icon: Icons.folder_rounded,
                                active: true,
                              ),
                              DesignSystemNavigationTabBarItem(
                                label: context
                                    .messages
                                    .designSystemNavigationInsightsLabel,
                                icon: Icons.bar_chart_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const _ProfileAccessoryButton(),
                  ],
                ),
                const SizedBox(height: 18),
                const DesignSystemShowcaseMobileHomeIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectMobileDetailScreen extends StatefulWidget {
  const _ProjectMobileDetailScreen({
    required this.record,
    required this.currentTime,
    this.onBack,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final VoidCallback? onBack;

  @override
  State<_ProjectMobileDetailScreen> createState() =>
      _ProjectMobileDetailScreenState();
}

class _ProjectMobileDetailScreenState
    extends State<_ProjectMobileDetailScreen> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemShowcaseMobileShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesignSystemShowcaseMobileStatusBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step4,
              tokens.spacing.step3,
              tokens.spacing.step4,
              0,
            ),
            child: DesignSystemShowcaseMobileDetailHeader(
              foregroundColor: ShowcasePalette.highText(context),
              onBack: widget.onBack,
            ),
          ),
          Expanded(
            child: DesignSystemScrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MobileDetailHeader(record: widget.record),
                    const SizedBox(height: 16),
                    HealthPanel(record: widget.record),
                    const SizedBox(height: 24),
                    TextSection(
                      title: context.messages.projectShowcaseDescriptionTitle,
                      body: widget.record.project.entryText?.plainText ?? '',
                    ),
                    const SizedBox(height: 24),
                    TextSection(
                      title: context.messages.projectShowcaseAiReportTitle,
                      body: widget.record.aiSummary,
                      trailingLabel: showcaseUpdatedLabel(
                        context,
                        updatedAt: widget.record.reportUpdatedAt,
                        currentTime: widget.currentTime,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.messages.projectShowcaseRecommendationsTitle,
                      style: context
                          .designTokens
                          .typography
                          .styles
                          .subtitle
                          .subtitle2
                          .copyWith(
                            color: ShowcasePalette.highText(context),
                          ),
                    ),
                    const SizedBox(height: 12),
                    RecommendationsList(items: widget.record.recommendations),
                    const SizedBox(height: 24),
                    ProjectTasksPanel(record: widget.record),
                    const SizedBox(height: 24),
                    ReviewSessionsPanel(record: widget.record),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: DesignSystemShowcaseMobileHomeIndicator()),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MobileDetailHeader extends StatelessWidget {
  const _MobileDetailHeader({required this.record});

  final ProjectRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.project.data.title,
                style: context.designTokens.typography.styles.heading.heading2
                    .copyWith(
                      color: ShowcasePalette.highText(context),
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CategoryTag(
                    label: record.category.name,
                    icon: record.category.icon?.iconData ?? Icons.label_outline,
                    color: colorFromCssHex(
                      record.category.color ?? defaultCategoryColorHex,
                    ),
                  ),
                  if (record.project.data.targetDate case final targetDate?)
                    _MobileOutlinedMetaTag(
                      icon: Icons.watch_later_outlined,
                      label: MaterialLocalizations.of(
                        context,
                      ).formatShortDate(targetDate),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ProjectStatusPill(
            status: record.project.data.status,
            large: true,
          ),
        ),
      ],
    );
  }
}

class _ProfileAccessoryButton extends StatelessWidget {
  const _ProfileAccessoryButton();

  @override
  Widget build(BuildContext context) {
    return DesignSystemNavigationFrostedSurface(
      borderRadius: BorderRadius.circular(999),
      child: const SizedBox.square(
        dimension: 60,
        child: Center(
          child: DesignSystemAvatar(
            image: AssetImage('assets/design_system/avatar_placeholder.png'),
          ),
        ),
      ),
    );
  }
}

class _MobileOutlinedMetaTag extends StatelessWidget {
  const _MobileOutlinedMetaTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: ShowcasePalette.lowText(context),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: ShowcasePalette.lowText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
