import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    super.key,
  });

  final ProjectListItemData item;
  final bool selected;
  final double topOverlap;
  final double bottomOverlap;
  final double backgroundTopInset;
  final double backgroundBottomInset;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: ShowcasePalette.lowText(context),
    );
    final projectId = item.project.meta.id;
    final oneLiner = item.oneLiner;

    final row = GroupedCardRowSurface(
      key: key ?? ValueKey('project-row-surface-$projectId'),
      rowKey: ValueKey('project-overview-row-$projectId'),
      backgroundKey: ValueKey('project-row-background-$projectId'),
      selected: selected,
      hoverColor: ShowcasePalette.hoverFill(context),
      selectedColor: ShowcasePalette.selectedRow(context),
      topOverlap: topOverlap,
      bottomOverlap: bottomOverlap,
      backgroundTopInset: backgroundTopInset,
      backgroundBottomInset: backgroundBottomInset,
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step4,
        tokens.spacing.step4,
        tokens.spacing.step4,
        tokens.spacing.step4,
      ),
      onHoverChanged: onHoverChanged,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.project.data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: ShowcasePalette.highText(context),
                  ),
                ),
                if (oneLiner != null && oneLiner.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    oneLiner,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ShowcasePalette.lowText(context),
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step1),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: metaStyle,
                    children: _metaSpans(
                      context,
                      metaStyle,
                      item,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          ProjectStatusLabel(status: item.status),
        ],
      ),
    );
    final detailFocusController = ListDetailFocusTraversal.maybeOf(context);
    if (detailFocusController == null) return row;

    return AppCommandScope(
      handlers: {
        AppCommandId.expand: AppCommandHandler(
          invoke: (_) {
            onTap();
            detailFocusController.focusDetails();
          },
        ),
      },
      child: row,
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

  if (item.taskRollup.totalTaskCount == 0) {
    return [
      TextSpan(
        text: '${context.messages.projectTaskProgressNone} · $dueLabel',
        style: metaStyle,
      ),
    ];
  }

  return [
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _TinyProgressRing(
        key: ValueKey(
          'project-row-progress-ring-${item.project.meta.id}',
        ),
        progress: item.taskRollup.completionRatio,
        progressColor: tokens.colors.interactive.enabled,
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
      dimension: IconSizes.s,
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
    const strokeWidth = BorderWidths.emphasis;
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
