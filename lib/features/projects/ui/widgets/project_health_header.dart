import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Expandable header showing projects for the selected category on the
/// tasks page.
///
/// Collapsed: shows a summary row inside a card with project/task counts
/// and a link to the category details page.
/// Expanded: the same card grows to include per-project rows that toggle a
/// task filter on tap; each row also has a navigation icon to open the
/// project detail page.
///
/// Stale selection detection is performed here: if [selectedProjectIds]
/// contains IDs that are no longer in the provider result, [onClearStale]
/// is scheduled via [WidgetsBinding.addPostFrameCallback].
class ProjectHealthHeader extends ConsumerStatefulWidget {
  const ProjectHealthHeader({
    required this.categoryId,
    required this.selectedProjectIds,
    required this.onToggleProject,
    required this.onClearStale,
    super.key,
  });

  final String categoryId;
  final Set<String> selectedProjectIds;
  final void Function(String projectId) onToggleProject;
  final void Function(Set<String> staleIds) onClearStale;

  @override
  ConsumerState<ProjectHealthHeader> createState() =>
      _ProjectHealthHeaderState();
}

class _ProjectHealthHeaderState extends ConsumerState<ProjectHealthHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(
      projectsForCategoryProvider(widget.categoryId),
    );

    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (List<ProjectEntry> projects) {
        // Reconcile stale project selections before the isEmpty check so that
        // clearing the last project in a category still removes hidden filters.
        if (widget.selectedProjectIds.isNotEmpty) {
          final validIds = projects.map((p) => p.meta.id).toSet();
          final stale = widget.selectedProjectIds.difference(validIds);
          if (stale.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onClearStale(stale);
            });
          }
        }

        if (projects.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: 4,
          ),
          child: ModernBaseCard(
            padding: EdgeInsets.zero,
            borderColor: widget.selectedProjectIds.isNotEmpty
                ? context.colorScheme.primary
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SummaryRow(
                    projects: projects,
                    expanded: _expanded,
                    categoryId: widget.categoryId,
                    selectedCount: widget.selectedProjectIds.length,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                  if (_expanded) ...[
                    Divider(
                      height: 2,
                      thickness: 2,
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    for (var i = 0; i < projects.length; i++) ...[
                      _ProjectRow(
                        project: projects[i],
                        isSelected: widget.selectedProjectIds.contains(
                          projects[i].meta.id,
                        ),
                        onToggle: () =>
                            widget.onToggleProject(projects[i].meta.id),
                      ),
                      if (i < projects.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: context.colorScheme.outlineVariant.withValues(
                            alpha: 0.25,
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow({
    required this.projects,
    required this.expanded,
    required this.categoryId,
    required this.selectedCount,
    required this.onTap,
  });

  final List<ProjectEntry> projects;
  final bool expanded;
  final String categoryId;
  final int selectedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var totalTasks = 0;
    var allLoaded = true;
    for (final project in projects) {
      ref
          .watch(projectTaskCountProvider(project.meta.id))
          .when(
            data: (count) => totalTasks += count,
            loading: () => allLoaded = false,
            error: (_, _) => allLoaded = false,
          );
    }

    final messages = context.messages;
    final subtitle = allLoaded
        ? messages.projectHealthSummary(projects.length, totalTasks)
        : messages.projectCountSummary(projects.length);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const ModernIconContainer(
                  icon: Icons.folder_outlined,
                  isCompact: true,
                ),
                if (selectedCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$selectedCount',
                          style: TextStyle(
                            color: context.colorScheme.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messages.projectHealthTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Navigate to category details (project management)
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                size: 18,
                color: context.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => getIt<NavService>().beamToNamed(
                '/settings/categories/$categoryId',
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: messages.projectManageTooltip,
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({
    required this.project,
    required this.isSelected,
    required this.onToggle,
  });

  final ProjectEntry project;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(projectTaskCountProvider(project.meta.id));
    final summaryAsync = ref.watch(
      projectAgentSummaryProvider(project.meta.id),
    );
    final healthAsync = ref.watch(
      projectHealthMetricsProvider(project.meta.id),
    );
    final messages = context.messages;

    final taskCountText = countAsync.when(
      data: messages.projectLinkedTaskCount,
      loading: () => '…',
      error: (_, _) => '—',
    );
    final summary = summaryAsync.asData?.value;
    final healthMetrics = healthAsync.asData?.value;

    final targetText = project.data.targetDate != null
        ? ' · ${project.data.targetDate!.ymd}'
        : '';

    final selectedBg = context.colorScheme.primaryContainer.withValues(
      alpha: 0.45,
    );

    return Material(
      color: isSelected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 12,
            right: 4,
            top: 10,
            bottom: 10,
          ),
          child: Row(
            children: [
              ModernIconContainer(
                icon: Icons.folder_outlined,
                isCompact: true,
                iconColor: isSelected ? context.colorScheme.primary : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.data.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isSelected ? context.colorScheme.primary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$taskCountText$targetText',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (healthMetrics != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ProjectHealthIndicator(
                          metrics: healthMetrics,
                          showReason: false,
                        ),
                      ),
                    if (summary != null && summary.isSummaryOutdated)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1, right: 4),
                              child: Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: context.colorScheme.tertiary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _outdatedSummaryText(
                                  context,
                                  summary.scheduledWakeAt,
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.colorScheme.tertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              ProjectStatusChip(status: project.data.status),
              // Navigate to project detail page
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => getIt<NavService>().beamToNamed(
                  '/settings/projects/${project.meta.id}',
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _outdatedSummaryText(
    BuildContext context,
    DateTime? scheduledWakeAt,
  ) {
    if (scheduledWakeAt == null) {
      return context.messages.projectSummaryOutdated;
    }

    final timeText = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(scheduledWakeAt),
      alwaysUse24HourFormat:
          MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false,
    );

    return context.messages.projectSummaryOutdatedScheduled(
      scheduledWakeAt.ymd,
      timeText,
    );
  }
}
