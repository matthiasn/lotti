import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Shared category header row showing the category tag and project count.
class ProjectGroupHeader extends StatelessWidget {
  const ProjectGroupHeader({
    required this.group,
    super.key,
  });

  final ProjectCategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = group.category;
    final color = colorFromCssHex(category?.color ?? defaultCategoryColorHex);

    return Row(
      children: [
        CategoryTag(
          label: category?.name ?? context.messages.taskCategoryUnassignedLabel,
          icon: category?.icon?.iconData ?? Icons.folder_outlined,
          color: color,
        ),
        const Spacer(),
        Text(
          context.messages.projectCountSummary(group.projectCount),
          style: tokens.typography.styles.others.caption.copyWith(
            color: ShowcasePalette.mediumText(context),
          ),
        ),
      ],
    );
  }
}

/// A category-labelled section containing grouped project rows.
class ProjectGroupSection extends StatelessWidget {
  const ProjectGroupSection({
    required this.group,
    required this.selectedProjectId,
    required this.onProjectSelected,
    super.key,
  });

  final ProjectCategoryGroup group;
  final String? selectedProjectId;
  final ValueChanged<ProjectListItemData> onProjectSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ProjectGroupHeader(group: group),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ShowcasePalette.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShowcasePalette.border(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (var index = 0; index < group.projects.length; index++)
                  ProjectRow(
                    item: group.projects[index],
                    selected:
                        group.projects[index].project.meta.id ==
                        selectedProjectId,
                    showDivider: index < group.projects.length - 1,
                    onTap: () => onProjectSelected(group.projects[index]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A single project row in the list, with task-progress ring, task count,
/// due label, and status tag.
class ProjectRow extends StatelessWidget {
  const ProjectRow({
    required this.item,
    required this.selected,
    required this.showDivider,
    required this.onTap,
    super.key,
  });

  final ProjectListItemData item;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: ShowcasePalette.lowText(context),
    );

    return DesignSystemListItem(
      key: ValueKey('project-overview-row-${item.project.meta.id}'),
      title: item.project.data.title,
      subtitleSpans: _metaSpans(context, metaStyle, item),
      trailing: ProjectStatusLabel(status: item.status),
      showDivider: showDivider,
      activated: selected,
      selected: selected,
      activatedBackgroundColor: ShowcasePalette.selectedRow(context),
      hoverBackgroundColor: ShowcasePalette.hoverFill(context),
      onTap: onTap,
    );
  }
}

List<InlineSpan> _metaSpans(
  BuildContext context,
  TextStyle metaStyle,
  ProjectListItemData item,
) {
  final tokens = context.designTokens;
  final taskCount = context.messages.settingsCategoriesTaskCount(
    item.taskRollup.totalTaskCount,
  );
  final dueLabel = item.targetDate == null
      ? context.messages.projectShowcaseOngoing
      : context.messages.projectShowcaseDueDate(
          DateFormat.MMMd(
            Localizations.localeOf(context).toString(),
          ).format(item.targetDate!),
        );

  return [
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: _TinyProgressRing(
          key: ValueKey('project-row-progress-ring-${item.project.meta.id}'),
          progress: item.taskRollup.completionRatio,
          progressColor: item.taskRollup.blockedTaskCount > 0
              ? ShowcasePalette.amber(context)
              : ShowcasePalette.timeGreen(context),
          trackColor: ShowcasePalette.lowText(context).withValues(alpha: 0.18),
        ),
      ),
    ),
    TextSpan(
      text: '${item.taskRollup.completionPercent}% · ',
      style: metaStyle,
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Icon(
        Icons.format_list_bulleted_rounded,
        size: tokens.typography.lineHeight.caption,
        color: ShowcasePalette.lowText(context),
      ),
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(width: tokens.spacing.step1),
    ),
    TextSpan(text: '$taskCount · $dueLabel', style: metaStyle),
  ];
}

class _TinyProgressRing extends StatelessWidget {
  const _TinyProgressRing({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    super.key,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CustomPaint(
        painter: _TinyProgressRingPainter(
          progress: progress,
          trackColor: trackColor,
          progressColor: progressColor,
        ),
      ),
    );
  }
}

class _TinyProgressRingPainter extends CustomPainter {
  const _TinyProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.25;
    const inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _TinyProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
