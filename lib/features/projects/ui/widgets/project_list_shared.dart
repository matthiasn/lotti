import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

const _kProjectGroupCardRadius = 16.0;
const _kProjectGroupCardPadding = 8.0;
const _kProjectRowGap = 16.0;
const _kProjectRowSegmentPadding = 8.0;

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
            color: _projectGroupBackgroundColor(context),
            borderRadius: BorderRadius.circular(_kProjectGroupCardRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kProjectGroupCardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < group.projects.length; index++) ...[
                  ProjectRow(
                    item: group.projects[index],
                    selected:
                        group.projects[index].project.meta.id ==
                        selectedProjectId,
                    onTap: () => onProjectSelected(group.projects[index]),
                  ),
                  if (index < group.projects.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _kProjectGroupCardPadding,
                      ),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: ShowcasePalette.border(context),
                      ),
                    ),
                ],
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
    required this.onTap,
    super.key,
  });

  final ProjectListItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProjectRowSurface(
      item: item,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _ProjectRowSurface extends StatefulWidget {
  const _ProjectRowSurface({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ProjectListItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProjectRowSurface> createState() => _ProjectRowSurfaceState();
}

class _ProjectRowSurfaceState extends State<_ProjectRowSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: ShowcasePalette.lowText(context),
    );
    final backgroundColor = widget.selected
        ? ShowcasePalette.selectedRow(context)
        : (_hovered ? ShowcasePalette.hoverFill(context) : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('project-overview-row-${widget.item.project.meta.id}'),
        onTap: widget.onTap,
        onHover: (value) {
          if (_hovered != value) {
            setState(() {
              _hovered = value;
            });
          }
        },
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _kProjectRowSegmentPadding,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.project.data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: ShowcasePalette.highText(context),
                              ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: metaStyle,
                            children: _metaSpans(
                              context,
                              metaStyle,
                              widget.item,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _kProjectRowGap),
                  ProjectStatusLabel(status: widget.item.status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _projectGroupBackgroundColor(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  if (brightness == Brightness.dark) {
    return const Color(0xFF222222);
  }
  return ShowcasePalette.surface(context);
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
      child: _TinyProgressRing(
        key: ValueKey(
          'project-row-progress-ring-${item.project.meta.id}',
        ),
        progress: item.taskRollup.completionRatio,
        progressColor: item.taskRollup.blockedTaskCount > 0
            ? ShowcasePalette.amber(context)
            : ShowcasePalette.timeGreen(context),
        trackColor: ShowcasePalette.highText(
          context,
        ).withValues(alpha: 0.12),
      ),
    ),
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(width: tokens.spacing.step1),
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
      dimension: 16,
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
    const strokeWidth = 2.285714;
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
