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
const _kProjectRowVerticalPadding = 6.0;
const _kProjectRowHorizontalPadding = 16.0;
const _kProjectRowOverlap = 1.0;

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
class ProjectGroupSection extends StatefulWidget {
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
  State<ProjectGroupSection> createState() => _ProjectGroupSectionState();
}

class _ProjectGroupSectionState extends State<ProjectGroupSection> {
  String? _hoveredProjectId;

  @override
  Widget build(BuildContext context) {
    final priorities = widget.group.projects
        .map(
          (project) => _interactionPriority(
            projectId: project.project.meta.id,
            selectedProjectId: widget.selectedProjectId,
            hoveredProjectId: _hoveredProjectId,
          ),
        )
        .toList(growable: false);
    final topOverlaps = List<double>.filled(widget.group.projects.length, 0);
    final bottomOverlaps = List<double>.filled(widget.group.projects.length, 0);
    final visibleDividers = List<bool>.filled(
      math.max(widget.group.projects.length - 1, 0),
      true,
    );

    for (var index = 0; index < widget.group.projects.length - 1; index++) {
      final upperPriority = priorities[index];
      final lowerPriority = priorities[index + 1];
      if (upperPriority == 0 && lowerPriority == 0) {
        continue;
      }

      visibleDividers[index] = false;
      if (lowerPriority > upperPriority) {
        topOverlaps[index + 1] = _kProjectRowOverlap;
      } else {
        bottomOverlaps[index] = _kProjectRowOverlap;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ProjectGroupHeader(group: widget.group),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          key: ValueKey(
            'project-group-card-${widget.group.categoryId ?? 'unassigned'}',
          ),
          decoration: BoxDecoration(
            color: _projectGroupBackgroundColor(context),
            borderRadius: BorderRadius.circular(_kProjectGroupCardRadius),
            border: Border.all(color: ShowcasePalette.border(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kProjectGroupCardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: _kProjectGroupCardPadding),
                for (
                  var index = 0;
                  index < widget.group.projects.length;
                  index++
                ) ...[
                  ProjectRow(
                    item: widget.group.projects[index],
                    selected:
                        widget.group.projects[index].project.meta.id ==
                        widget.selectedProjectId,
                    topOverlap: topOverlaps[index],
                    bottomOverlap: bottomOverlaps[index],
                    backgroundTopInset: _kProjectGroupCardPadding,
                    backgroundBottomInset: _kProjectGroupCardPadding,
                    onHoverChanged: (hovered) {
                      final projectId =
                          widget.group.projects[index].project.meta.id;
                      setState(() {
                        if (hovered) {
                          _hoveredProjectId = projectId;
                        } else if (_hoveredProjectId == projectId) {
                          _hoveredProjectId = null;
                        }
                      });
                    },
                    onTap: () => widget.onProjectSelected(
                      widget.group.projects[index],
                    ),
                  ),
                  if (index < widget.group.projects.length - 1) ...[
                    const SizedBox(height: _kProjectGroupCardPadding),
                    if (visibleDividers[index])
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _kProjectRowHorizontalPadding,
                        ),
                        child: Divider(
                          key: ValueKey('project-group-divider-$index'),
                          height: 1,
                          thickness: 1,
                          color: ShowcasePalette.border(context),
                        ),
                      )
                    else
                      SizedBox(
                        key: ValueKey(
                          'project-group-divider-slot-$index',
                        ),
                        height: _kProjectRowOverlap,
                      ),
                    const SizedBox(height: _kProjectGroupCardPadding),
                  ],
                ],
                const SizedBox(height: _kProjectGroupCardPadding),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant ProjectGroupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hoveredProjectId != null &&
        widget.group.projects.every(
          (project) => project.project.meta.id != _hoveredProjectId,
        )) {
      _hoveredProjectId = null;
    }
  }
}

/// A single project row in the list, with task-progress ring, task count,
/// due label, and status tag.
class ProjectRow extends StatelessWidget {
  const ProjectRow({
    required this.item,
    required this.selected,
    required this.topOverlap,
    required this.bottomOverlap,
    required this.onHoverChanged,
    required this.onTap,
    this.backgroundTopInset = 0,
    this.backgroundBottomInset = 0,
    this.contentHorizontalPadding = _kProjectRowHorizontalPadding,
    super.key,
  });

  final ProjectListItemData item;
  final bool selected;
  final double topOverlap;
  final double bottomOverlap;
  final double backgroundTopInset;
  final double backgroundBottomInset;
  final double contentHorizontalPadding;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProjectRowSurface(
      key: key ?? ValueKey('project-row-surface-${item.project.meta.id}'),
      item: item,
      selected: selected,
      topOverlap: topOverlap,
      bottomOverlap: bottomOverlap,
      backgroundTopInset: backgroundTopInset,
      backgroundBottomInset: backgroundBottomInset,
      contentHorizontalPadding: contentHorizontalPadding,
      onHoverChanged: onHoverChanged,
      onTap: onTap,
    );
  }
}

class _ProjectRowSurface extends StatefulWidget {
  const _ProjectRowSurface({
    required this.item,
    required this.selected,
    required this.topOverlap,
    required this.bottomOverlap,
    required this.onHoverChanged,
    required this.onTap,
    this.backgroundTopInset = 0,
    this.backgroundBottomInset = 0,
    this.contentHorizontalPadding = _kProjectRowHorizontalPadding,
    super.key,
  });

  final ProjectListItemData item;
  final bool selected;
  final double topOverlap;
  final double bottomOverlap;
  final double backgroundTopInset;
  final double backgroundBottomInset;
  final double contentHorizontalPadding;
  final ValueChanged<bool> onHoverChanged;
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

    return Semantics(
      selected: widget.selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('project-overview-row-${widget.item.project.meta.id}'),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onHover: (value) {
            if (_hovered != value) {
              setState(() {
                _hovered = value;
              });
              widget.onHoverChanged(value);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (backgroundColor != null)
                Positioned(
                  top: -(widget.backgroundTopInset + widget.topOverlap),
                  right: 0,
                  bottom:
                      -(widget.backgroundBottomInset + widget.bottomOverlap),
                  left: 0,
                  child: DecoratedBox(
                    key: ValueKey(
                      'project-row-background-${widget.item.project.meta.id}',
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.contentHorizontalPadding,
                  _kProjectRowVerticalPadding,
                  widget.contentHorizontalPadding,
                  _kProjectRowVerticalPadding,
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}

int _interactionPriority({
  required String projectId,
  required String? selectedProjectId,
  required String? hoveredProjectId,
}) {
  if (projectId == selectedProjectId) {
    return 2;
  }
  if (projectId == hoveredProjectId) {
    return 1;
  }
  return 0;
}

Color _projectGroupBackgroundColor(BuildContext context) {
  return ShowcasePalette.groupedCardSurface(context);
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
        progressColor: _progressRingColor(context, item.taskRollup),
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

Color _progressRingColor(
  BuildContext context,
  ProjectTaskRollupData taskRollup,
) {
  final completionPercent = taskRollup.completionPercent;

  if (completionPercent >= 80) {
    return ShowcasePalette.timeGreen(context);
  }
  if (completionPercent >= 50) {
    return ShowcasePalette.amber(context);
  }
  return ShowcasePalette.error(context);
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
