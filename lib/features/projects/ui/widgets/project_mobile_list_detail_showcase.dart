import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_showcase_mobile_detail_header.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/ui/widgets/health_panel.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/features/projects/ui/widgets/project_tasks_panel.dart';
import 'package:lotti/features/projects/ui/widgets/review_sessions_panel.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

const _kMobileScreenWidth = 402.0;
const _kMobileScreenHeight = 874.0;
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
    required this.onProjectOpened,
  });

  final ProjectListDetailState state;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onProjectOpened;

  @override
  Widget build(BuildContext context) {
    final groups = state.visibleGroups;
    final selectedId = state.selectedProject?.project.meta.id;

    return _MobileScreenShell(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MobileStatusBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.messages.designSystemBreadcrumbProjectsLabel,
                        style: context
                            .designTokens
                            .typography
                            .styles
                            .heading
                            .heading2
                            .copyWith(
                              color: ShowcasePalette.highText(context),
                            ),
                      ),
                    ),
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 34,
                      color: ShowcasePalette.highText(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: DesignSystemSearch(
                          hintText: context.messages.projectShowcaseSearchHint,
                          initialText: state.searchQuery,
                          onChanged: onSearchChanged,
                          onClear: onSearchCleared,
                          onSearchPressed: onSearchChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.tune_rounded,
                      size: 24,
                      color: ShowcasePalette.teal(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: groups.isEmpty
                      ? const NoResultsPane()
                      : DesignSystemScrollbar(
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 184),
                            itemCount: groups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 20),
                            itemBuilder: (context, index) {
                              return ProjectGroupSection(
                                group: groups[index],
                                selectedProjectId: selectedId,
                                onProjectSelected: onProjectOpened,
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 140,
            child: _CreateProjectFab(
              semanticLabel: context.messages.designSystemNavigationNewLabel,
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
                const _MobileHomeIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectMobileDetailScreen extends StatelessWidget {
  const _ProjectMobileDetailScreen({
    required this.record,
    required this.currentTime,
    this.onBack,
  });

  final ProjectRecord record;
  final DateTime currentTime;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return _MobileScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MobileStatusBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step4,
              tokens.spacing.step3,
              tokens.spacing.step4,
              0,
            ),
            child: DesignSystemShowcaseMobileDetailHeader(
              foregroundColor: ShowcasePalette.highText(context),
              onBack: onBack,
            ),
          ),
          Expanded(
            child: DesignSystemScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MobileDetailHeader(record: record),
                    const SizedBox(height: 16),
                    HealthPanel(record: record),
                    const SizedBox(height: 24),
                    TextSection(
                      title: context.messages.projectShowcaseDescriptionTitle,
                      body: record.project.entryText?.plainText ?? '',
                    ),
                    const SizedBox(height: 24),
                    TextSection(
                      title: context.messages.projectShowcaseAiReportTitle,
                      body: record.aiSummary,
                      trailingLabel: showcaseUpdatedLabel(
                        context,
                        updatedAt: record.reportUpdatedAt,
                        currentTime: currentTime,
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
                    RecommendationsList(items: record.recommendations),
                    const SizedBox(height: 24),
                    ProjectTasksPanel(record: record),
                    const SizedBox(height: 24),
                    ReviewSessionsPanel(record: record),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: _MobileHomeIndicator()),
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

class _MobileScreenShell extends StatelessWidget {
  const _MobileScreenShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final frameColor = isLight
        ? tokens.colors.background.level01
        : tokens.colors.background.level03;
    final frameBorderColor = isLight
        ? tokens.colors.decorative.level02
        : Colors.black.withValues(alpha: 0.6);

    return SizedBox(
      width: _kMobileScreenWidth,
      height: _kMobileScreenHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: frameColor,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: frameBorderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.1 : 0.28),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ShowcasePalette.page(context),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileStatusBar extends StatelessWidget {
  const _MobileStatusBar();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final iconColor = ShowcasePalette.highText(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Text(
              '9:41',
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: iconColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Icon(Icons.wifi_rounded, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Icon(Icons.battery_full_rounded, size: 20, color: iconColor),
          ],
        ),
      ),
    );
  }
}

class _CreateProjectFab extends StatelessWidget {
  const _CreateProjectFab({required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ShowcasePalette.teal(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const SizedBox.square(
          dimension: 56,
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 24,
              color: Colors.black,
            ),
          ),
        ),
      ),
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

class _MobileHomeIndicator extends StatelessWidget {
  const _MobileHomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      height: 5,
      decoration: BoxDecoration(
        color: ShowcasePalette.mediumText(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
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
