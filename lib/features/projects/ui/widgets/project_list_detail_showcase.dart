import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_circular_progress.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_data.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

class ProjectListDetailShowcase extends ConsumerWidget {
  const ProjectListDetailShowcase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectListDetailShowcaseControllerProvider);
    final controller = ref.read(
      projectListDetailShowcaseControllerProvider.notifier,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.page(context),
      ),
      child: SizedBox(
        width: 1440,
        height: 900,
        child: Row(
          children: [
            const _Sidebar(),
            Expanded(
              child: Column(
                children: [
                  const _MainTopBar(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 402,
                          child: _ProjectListPane(
                            state: state,
                            onProjectSelected: controller.selectProject,
                            onSearchChanged: controller.updateSearchQuery,
                            onSearchCleared: () =>
                                controller.updateSearchQuery(''),
                          ),
                        ),
                        Expanded(
                          child: state.selectedProject == null
                              ? const _NoResultsPane()
                              : _ProjectDetailPane(
                                  record: state.selectedProject!,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.surface(context),
        border: Border(
          right: BorderSide(color: _ProjectListDetailPalette.border(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Icon(
                  Icons.menu_rounded,
                  size: 24,
                  color: _ProjectListDetailPalette.highText(context),
                ),
                const SizedBox(width: 16),
                const DesignSystemBrandLogo(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesignSystemButton(
                label: context.messages.designSystemNavigationNewLabel,
                size: DesignSystemButtonSize.medium,
                leadingIcon: Icons.add_rounded,
                trailingIcon: Icons.keyboard_arrow_down_rounded,
                onPressed: () {},
              ),
              const Spacer(),
              const _AiAssistantOrb(),
            ],
          ),
          const SizedBox(height: 24),
          _SidebarNavItem(
            icon: Icons.calendar_today_outlined,
            label: context.messages.designSystemNavigationMyDailyLabel,
          ),
          const SizedBox(height: 4),
          _SidebarNavItem(
            icon: Icons.format_list_bulleted_rounded,
            label: context.messages.navTabTitleTasks,
          ),
          const SizedBox(height: 4),
          _SidebarNavItem(
            icon: Icons.folder_rounded,
            label: context.messages.designSystemBreadcrumbProjectsLabel,
            active: true,
          ),
          const SizedBox(height: 4),
          _SidebarNavItem(
            icon: Icons.bar_chart_rounded,
            label: context.messages.designSystemNavigationInsightsLabel,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _AiAssistantOrb extends StatelessWidget {
  const _AiAssistantOrb();

  static const _buttonSize = 56.0;
  static const _assetExtent = 108.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.messages.designSystemNavigationAiAssistantSectionTitle,
      child: SizedBox.square(
        dimension: _buttonSize,
        child: OverflowBox(
          minWidth: _assetExtent,
          maxWidth: _assetExtent,
          minHeight: _assetExtent,
          maxHeight: _assetExtent,
          child: ExcludeSemantics(
            child: Image.asset(
              'assets/design_system/ai_assistant_variant_1.png',
              width: _assetExtent,
              height: _assetExtent,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? _ProjectListDetailPalette.activeNav(context)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 288,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: _ProjectListDetailPalette.highText(context),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: _ProjectListDetailPalette.highText(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainTopBar extends StatelessWidget {
  const _MainTopBar();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _ProjectListDetailPalette.border(context)),
        ),
      ),
      child: Row(
        children: [
          Text(
            context.messages.designSystemBreadcrumbProjectsLabel,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: _ProjectListDetailPalette.highText(context),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.notifications_none_rounded,
            size: 28,
            color: _ProjectListDetailPalette.highText(context),
          ),
          const SizedBox(width: 16),
          const DesignSystemAvatar(
            image: AssetImage('assets/design_system/avatar_placeholder.png'),
          ),
        ],
      ),
    );
  }
}

class _ProjectListPane extends StatelessWidget {
  const _ProjectListPane({
    required this.state,
    required this.onProjectSelected,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  final ProjectListDetailShowcaseState state;
  final ValueChanged<String> onProjectSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: _ProjectListDetailPalette.border(context)),
        ),
      ),
      child: Column(
        children: [
          _SearchHeader(
            query: state.searchQuery,
            onSearchChanged: onSearchChanged,
            onSearchCleared: onSearchCleared,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: state.visibleGroups.isEmpty
                  ? const _NoResultsPane()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: state.visibleGroups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = state.visibleGroups[index];
                        return _ProjectGroupSection(
                          group: group,
                          selectedProjectId:
                              state.selectedProject?.project.meta.id,
                          onProjectSelected: onProjectSelected,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.query,
    required this.onSearchChanged,
    required this.onSearchCleared,
  });

  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: _ProjectListDetailPalette.page(context),
      child: Center(
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _ProjectListDetailPalette.border(context),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    4,
                    2,
                    12,
                    2,
                  ),
                  child: DesignSystemSearch(
                    hintText: context.messages.projectShowcaseSearchHint,
                    initialText: query,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                    onSearchPressed: onSearchChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: _ProjectListDetailPalette.teal(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectGroupSection extends StatefulWidget {
  const _ProjectGroupSection({
    required this.group,
    required this.selectedProjectId,
    required this.onProjectSelected,
  });

  final ProjectListDetailShowcaseGroup group;
  final String? selectedProjectId;
  final ValueChanged<String> onProjectSelected;

  @override
  State<_ProjectGroupSection> createState() => _ProjectGroupSectionState();
}

class _ProjectGroupSectionState extends State<_ProjectGroupSection> {
  String? _hoveredProjectId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = widget.group.projects.first.category;

    bool isHighlighted(ProjectListDetailMockRecord record) =>
        record.project.meta.id == widget.selectedProjectId ||
        record.project.meta.id == _hoveredProjectId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              _CategoryTag(
                label: widget.group.label,
                icon: category.icon?.iconData ?? Icons.label_outline,
                color: colorFromCssHex(category.color ?? '#4AB6E8'),
              ),
              const Spacer(),
              Text(
                context.messages.projectCountSummary(
                  widget.group.projects.length,
                ),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: _ProjectListDetailPalette.mediumText(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: _ProjectListDetailPalette.surface(context),
            child: SizedBox(
              width: 370,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < widget.group.projects.length;
                    index++
                  ) ...[
                    _ProjectRow(
                      record: widget.group.projects[index],
                      selected:
                          widget.group.projects[index].project.meta.id ==
                          widget.selectedProjectId,
                      hovered:
                          widget.group.projects[index].project.meta.id ==
                          _hoveredProjectId,
                      onHoverChanged: (hovered) {
                        setState(() {
                          _hoveredProjectId = hovered
                              ? widget.group.projects[index].project.meta.id
                              : _hoveredProjectId ==
                                    widget.group.projects[index].project.meta.id
                              ? null
                              : _hoveredProjectId;
                        });
                      },
                      onTap: () => widget.onProjectSelected(
                        widget.group.projects[index].project.meta.id,
                      ),
                    ),
                    if (index < widget.group.projects.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color:
                              isHighlighted(widget.group.projects[index]) ||
                                  isHighlighted(
                                    widget.group.projects[index + 1],
                                  )
                              ? Colors.transparent
                              : _ProjectListDetailPalette.border(context),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: _ProjectListDetailPalette.tagText(context),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: _ProjectListDetailPalette.tagText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.record,
    required this.selected,
    required this.hovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  final ProjectListDetailMockRecord record;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final showStateSurface = selected || hovered;
    final stateColor = selected
        ? _ProjectListDetailPalette.selectedRow(context)
        : _ProjectListDetailPalette.hoverFill(context);

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: showStateSurface ? stateColor : Colors.transparent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.project.data.title,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: _ProjectListDetailPalette.highText(
                                context,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TinyProgressRing(score: record.healthScore),
                          Text(
                            '${record.healthScore}',
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: _ProjectListDetailPalette.lowText(
                                    context,
                                  ),
                                ),
                          ),
                          Text(
                            '·',
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: _ProjectListDetailPalette.lowText(
                                    context,
                                  ),
                                ),
                          ),
                          Text(
                            _taskSummaryLabel(
                              context,
                              record.totalTaskCount,
                              record.project.data.targetDate,
                            ),
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: _ProjectListDetailPalette.lowText(
                                    context,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _ProjectStatusLabel(status: record.project.data.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _taskSummaryLabel(
    BuildContext context,
    int count,
    DateTime? targetDate,
  ) {
    final taskCount = context.messages.settingsCategoriesTaskCount(count);
    if (targetDate == null) {
      return '$taskCount · ${context.messages.projectShowcaseOngoing}';
    }

    return '$taskCount · ${context.messages.projectShowcaseDueDate(DateFormat('MMM d').format(targetDate))}';
  }
}

class _TinyProgressRing extends StatelessWidget {
  const _TinyProgressRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(
        value: score / 100,
        strokeWidth: 2,
        backgroundColor: _ProjectListDetailPalette.border(context),
        valueColor: AlwaysStoppedAnimation(
          _ProjectListDetailPalette.amber(context),
        ),
      ),
    );
  }
}

class _NoResultsPane extends StatelessWidget {
  const _NoResultsPane();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Text(
        context.messages.projectShowcaseNoResults,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: _ProjectListDetailPalette.mediumText(context),
        ),
      ),
    );
  }
}

class _ProjectDetailPane extends StatelessWidget {
  const _ProjectDetailPane({required this.record});

  final ProjectListDetailMockRecord record;

  @override
  Widget build(BuildContext context) {
    final progressValue = record.totalTaskCount == 0
        ? 0.0
        : record.completedTaskCount / record.totalTaskCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.page(context),
        border: Border(
          left: BorderSide(color: _ProjectListDetailPalette.border(context)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailHeader(record: record),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HealthPanel(
                    record: record,
                    progressValue: progressValue,
                  ),
                  const SizedBox(height: 16),
                  _TextSection(
                    title: context.messages.projectShowcaseDescriptionTitle,
                    body: record.project.entryText?.plainText ?? '',
                  ),
                  const SizedBox(height: 16),
                  _TextSection(
                    title: context.messages.projectShowcaseAiReportTitle,
                    body: record.aiSummary,
                    trailingLabel: _updatedLabel(
                      context,
                      record.reportUpdatedAt,
                      record.showcaseNow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.messages.projectShowcaseRecommendationsTitle,
                    style: context
                        .designTokens
                        .typography
                        .styles
                        .subtitle
                        .subtitle2
                        .copyWith(
                          color: _ProjectListDetailPalette.highText(context),
                        ),
                  ),
                  const SizedBox(height: 8),
                  _RecommendationsList(items: record.recommendations),
                  const SizedBox(height: 16),
                  _BottomPanels(record: record),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _updatedLabel(
    BuildContext context,
    DateTime updatedAt,
    DateTime showcaseNow,
  ) {
    final difference = showcaseNow.difference(updatedAt);
    final hours = difference.inHours < 1 ? 1 : difference.inHours;
    return context.messages.projectShowcaseUpdatedHoursAgo(hours);
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.record});

  final ProjectListDetailMockRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                record.project.data.title,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: _ProjectListDetailPalette.highText(context),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: _ProjectListDetailPalette.mediumText(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CategoryTag(
                label: record.category.name,
                icon: record.category.icon?.iconData ?? Icons.label_outline,
                color: colorFromCssHex(record.category.color ?? '#4AB6E8'),
              ),
              if (record.project.data.targetDate case final targetDate?) ...[
                const SizedBox(width: 8),
                _OutlinedMetaTag(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormat('MMM d, y').format(targetDate),
                ),
              ],
              const Spacer(),
              _ProjectStatusPill(
                status: record.project.data.status,
                large: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlinedMetaTag extends StatelessWidget {
  const _OutlinedMetaTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _ProjectListDetailPalette.white32(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: _ProjectListDetailPalette.white32(context),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: _ProjectListDetailPalette.white32(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({
    required this.record,
    required this.progressValue,
  });

  final ProjectListDetailMockRecord record;
  final double progressValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      width: 685,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.healthSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ProjectListDetailPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesignSystemCircularProgress(
                value: record.healthScore / 100,
                size: DesignSystemCircularProgressSize.large,
                progressColor: _ProjectListDetailPalette.amber(context),
                trackColor: _ProjectListDetailPalette.border(context),
                semanticsLabel:
                    context.messages.projectShowcaseHealthScoreTitle,
                center: Text('${record.healthScore}'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.messages.projectShowcaseHealthScoreTitle,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: _ProjectListDetailPalette.highText(context),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: _ProjectListDetailPalette.infoBlue(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            context
                                .messages
                                .projectShowcaseHealthScoreDescription,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: _ProjectListDetailPalette.grayText(
                                    context,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _ProjectListDetailPalette.error(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.messages.projectShowcaseBlockedTaskCount(
                            record.blockedTaskCount,
                          ),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: _ProjectListDetailPalette.mediumText(
                                  context,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DesignSystemButton(
                label: context.messages.projectShowcaseViewBlocker,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: _ProjectListDetailPalette.border(context),
          ),
          const SizedBox(height: 14),
          DesignSystemProgressBar(
            value: progressValue,
            label: context.messages.navTabTitleTasks,
            progressText: context.messages.projectShowcaseTasksCompleted(
              record.completedTaskCount,
              record.totalTaskCount,
            ),
            labelColor: _ProjectListDetailPalette.highText(context),
            progressColor: _ProjectListDetailPalette.highText(context),
            fillColor: _ProjectListDetailPalette.teal(context),
            trackColor: _ProjectListDetailPalette.border(context),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _LegendItem(
                color: _ProjectListDetailPalette.teal(context),
                label: context.messages.projectShowcaseCompletedLegend(
                  record.completedTaskCount,
                ),
              ),
              const SizedBox(width: 12),
              _LegendItem(
                color: _ProjectListDetailPalette.error(context),
                label: context.messages.projectShowcaseBlockedLegend(
                  record.blockedTaskCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            fontSize: 11,
            color: _ProjectListDetailPalette.mediumText(context),
          ),
        ),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.title,
    required this.body,
    this.trailingLabel,
  });

  final String title;
  final String body;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: _ProjectListDetailPalette.highText(context),
                ),
              ),
              const Spacer(),
              if (trailingLabel case final trailingLabel?)
                Text(
                  trailingLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: _ProjectListDetailPalette.mediumText(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: _ProjectListDetailPalette.highText(context),
          ),
        ),
      ],
    );
  }
}

class _RecommendationsList extends StatelessWidget {
  const _RecommendationsList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: _ProjectListDetailPalette.teal(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: _ProjectListDetailPalette.mediumText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BottomPanels extends StatelessWidget {
  const _BottomPanels({required this.record});

  final ProjectListDetailMockRecord record;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _ProjectTasksPanel(record: record)),
        const SizedBox(width: 16),
        Expanded(child: _ReviewSessionsPanel(record: record)),
      ],
    );
  }
}

class _ProjectTasksPanel extends StatelessWidget {
  const _ProjectTasksPanel({required this.record});

  final ProjectListDetailMockRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ProjectListDetailPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.messages.projectShowcaseProjectTasksTab,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: _ProjectListDetailPalette.highText(
                                  context,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountDotBadge(
                        count: record.highlightedTaskSummaries.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: _ProjectListDetailPalette.timeGreen(context),
                ),
                const SizedBox(width: 2),
                Text(
                  _formatDuration(record.highlightedTasksTotalDuration),
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: _ProjectListDetailPalette.timeGreen(context),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _ProjectListDetailPalette.border(context),
          ),
          for (
            var index = 0;
            index < record.highlightedTaskSummaries.length;
            index++
          ) ...[
            _TaskSummaryRow(summary: record.highlightedTaskSummaries[index]),
            if (index < record.highlightedTaskSummaries.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: _ProjectListDetailPalette.border(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _TaskSummaryRow extends StatelessWidget {
  const _TaskSummaryRow({required this.summary});

  final ProjectListDetailMockTaskSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.task.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: _ProjectListDetailPalette.highText(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: _ProjectListDetailPalette.white32(context),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(summary.estimatedDuration),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: _ProjectListDetailPalette.white32(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TaskStatePill(status: summary.task.data.status),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: _ProjectListDetailPalette.mediumText(context),
          ),
        ],
      ),
    );
  }
}

class _ReviewSessionsPanel extends StatelessWidget {
  const _ReviewSessionsPanel({required this.record});

  final ProjectListDetailMockRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _ProjectListDetailPalette.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.messages.projectShowcaseOneOnOneReviewsTab,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: _ProjectListDetailPalette.highText(
                                  context,
                                ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountDotBadge(count: record.reviewSessions.length),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.projectShowcaseSessionsCount(
                    record.reviewSessions.length,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: _ProjectListDetailPalette.mediumText(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _ProjectListDetailPalette.border(context),
          ),
          for (
            var index = 0;
            index < record.reviewSessions.length;
            index++
          ) ...[
            _ReviewSessionBlock(session: record.reviewSessions[index]),
            if (index < record.reviewSessions.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: _ProjectListDetailPalette.border(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReviewSessionBlock extends StatelessWidget {
  const _ReviewSessionBlock({required this.session});

  final ProjectListDetailMockReviewSession session;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  session.summaryLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: _ProjectListDetailPalette.mediumText(context),
                    fontSize: 13,
                  ),
                ),
              ),
              _StarsRow(rating: session.rating, size: 16),
            ],
          ),
        ),
        if (session.expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            color: _ProjectListDetailPalette.expandedSurface(context),
            child: Column(
              children: [
                for (final metric in session.metrics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReviewMetricRow(metric: metric),
                  ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: _ProjectListDetailPalette.border(context),
                ),
                if (session.note case final note?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      note,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: _ProjectListDetailPalette.mediumText(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewMetricRow extends StatelessWidget {
  const _ReviewMetricRow({required this.metric});

  final ProjectListDetailMockReviewMetric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      children: [
        Expanded(
          child: Text(
            switch (metric.type) {
              ProjectListDetailMockReviewMetricType.communication =>
                context.messages.agentFeedbackCategoryCommunication,
              ProjectListDetailMockReviewMetricType.usefulness =>
                context.messages.projectShowcaseUsefulness,
              ProjectListDetailMockReviewMetricType.accuracy =>
                context.messages.agentFeedbackCategoryAccuracy,
            },
            style: tokens.typography.styles.others.caption.copyWith(
              color: _ProjectListDetailPalette.mediumText(context),
            ),
          ),
        ),
        _StarsRow(rating: metric.rating, size: 14),
      ],
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({
    required this.rating,
    required this.size,
  });

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: _ProjectListDetailPalette.amber(context),
        ),
      ),
    );
  }
}

class _CountDotBadge extends StatelessWidget {
  const _CountDotBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.workTag(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: _ProjectListDetailPalette.tagText(context),
        ),
      ),
    );
  }
}

class _ProjectStatusPill extends StatelessWidget {
  const _ProjectStatusPill({
    required this.status,
    this.large = false,
  });

  final ProjectStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final statusColor = _projectStatusColor(context, status);
    final height = large ? 28.0 : 20.0;
    final horizontalPadding = large ? 8.0 : 4.0;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.subtleFill(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _projectStatusIcon(status),
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            _projectStatusLabel(context, status),
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: _ProjectListDetailPalette.highText(context),
            ),
          ),
          if (large) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: _ProjectListDetailPalette.mediumText(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectStatusLabel extends StatelessWidget {
  const _ProjectStatusLabel({required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _projectStatusIcon(status),
          size: 14,
          color: _projectStatusColor(context, status),
        ),
        const SizedBox(width: 4),
        Text(
          _projectStatusLabel(context, status),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: _ProjectListDetailPalette.highText(context),
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _TaskStatePill extends StatelessWidget {
  const _TaskStatePill({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final icon = switch (status) {
      TaskOpen() => Icons.radio_button_unchecked_rounded,
      TaskInProgress() => Icons.play_arrow_rounded,
      TaskGroomed() => Icons.circle_outlined,
      TaskBlocked() => Icons.warning_amber_rounded,
      TaskOnHold() => Icons.pause_circle_outline_rounded,
      TaskDone() => Icons.check_circle_outline_rounded,
      TaskRejected() => Icons.cancel_outlined,
    };

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _ProjectListDetailPalette.subtleFill(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: _ProjectListDetailPalette.mediumText(context),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: _ProjectListDetailPalette.mediumText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectListDetailPalette {
  static Color page(BuildContext context) =>
      context.designTokens.colors.background.level01;

  static Color surface(BuildContext context) =>
      context.designTokens.colors.background.level02;

  static Color expandedSurface(BuildContext context) =>
      context.designTokens.colors.background.level03;

  static Color healthSurface(BuildContext context) =>
      context.designTokens.colors.background.alternative01;

  static Color selectedRow(BuildContext context) =>
      context.designTokens.colors.surface.selected;

  static Color border(BuildContext context) =>
      context.designTokens.colors.decorative.level01;

  static Color highText(BuildContext context) =>
      context.designTokens.colors.text.highEmphasis;

  static Color mediumText(BuildContext context) =>
      context.designTokens.colors.text.mediumEmphasis;

  static Color lowText(BuildContext context) =>
      context.designTokens.colors.text.lowEmphasis;

  static Color grayText(BuildContext context) =>
      context.designTokens.colors.text.mediumEmphasis;

  static Color tagText(BuildContext context) =>
      context.designTokens.colors.text.onInteractiveAlert;

  static Color white32(BuildContext context) =>
      context.designTokens.colors.text.lowEmphasis;

  static Color subtleFill(BuildContext context) =>
      context.designTokens.colors.surface.enabled;

  static Color teal(BuildContext context) =>
      context.designTokens.colors.interactive.enabled;

  static Color activeNav(BuildContext context) =>
      context.designTokens.colors.surface.active;

  static Color hoverFill(BuildContext context) =>
      context.designTokens.colors.surface.hover;

  static Color amber(BuildContext context) =>
      context.designTokens.colors.alert.warning.defaultColor;

  static Color workTag(BuildContext context) =>
      context.designTokens.colors.alert.info.defaultColor;

  static Color infoBlue(BuildContext context) =>
      context.designTokens.colors.alert.info.defaultColor;

  static Color timeGreen(BuildContext context) =>
      context.designTokens.colors.alert.success.defaultColor;

  static Color error(BuildContext context) =>
      context.designTokens.colors.alert.error.defaultColor;
}

String _projectStatusLabel(BuildContext context, ProjectStatus status) =>
    switch (status) {
      ProjectActive() => context.messages.projectStatusActive,
      ProjectCompleted() => context.messages.projectStatusCompleted,
      ProjectArchived() => context.messages.projectStatusArchived,
      ProjectOnHold() => context.messages.projectStatusOnHold,
      ProjectOpen() => context.messages.projectStatusOpen,
    };

IconData _projectStatusIcon(ProjectStatus status) => switch (status) {
  ProjectActive() => Icons.play_arrow_rounded,
  ProjectCompleted() => Icons.check_circle_outline_rounded,
  ProjectArchived() => Icons.archive_outlined,
  ProjectOnHold() => Icons.pause_circle_outline_rounded,
  ProjectOpen() => Icons.radio_button_unchecked_rounded,
};

Color _projectStatusColor(BuildContext context, ProjectStatus status) =>
    switch (status) {
      ProjectActive() => _ProjectListDetailPalette.amber(context),
      ProjectCompleted() => _ProjectListDetailPalette.timeGreen(context),
      ProjectArchived() => _ProjectListDetailPalette.mediumText(context),
      ProjectOnHold() => _ProjectListDetailPalette.amber(context),
      ProjectOpen() => _ProjectListDetailPalette.infoBlue(context),
    };

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0 && seconds > 0) {
    return '${minutes}m ${seconds}s';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  return '${seconds}s';
}
