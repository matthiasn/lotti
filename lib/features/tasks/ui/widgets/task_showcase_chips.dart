import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/utils/color.dart';

/// Showcase chip rendering a category as a calm, neutral surface pill that
/// matches [TaskShowcaseMetaChip]'s dimensions. The category [colorHex] is
/// carried only by a small leading icon, not a full saturated fill, so the
/// row stays quiet and the chip lines up in height with the other metadata.
class TaskShowcaseCategoryChip extends StatelessWidget {
  const TaskShowcaseCategoryChip({
    required this.label,
    required this.icon,
    required this.colorHex,
    super.key,
  });

  final String label;
  final IconData icon;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = colorFromCssHex(colorHex);
    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        // Stronger hairline (decorative.level02) so the chip boundary is
        // perceptible against the near-same-tone surface for low-vision users.
        border: Border.all(color: TaskShowcasePalette.containerBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: TaskShowcasePalette.mediumText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Showcase pill for a task label: a tinted, rounded chip in [color]. When
/// [outlined] is true the fill is transparent and only the border carries the
/// color.
class TaskShowcaseLabelChip extends StatelessWidget {
  const TaskShowcaseLabelChip({
    required this.label,
    required this.color,
    this.outlined = false,
    super.key,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 20,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: tokens.typography.styles.others.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Showcase metadata chip: a bordered surface pill pairing [icon] with [label]
/// in muted text (e.g. due date, estimate).
class TaskShowcaseMetaChip extends StatelessWidget {
  const TaskShowcaseMetaChip({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        // Stronger hairline (decorative.level02) so each chip's boundary is
        // perceptible against the near-same-tone surface for low-vision users.
        border: Border.all(color: TaskShowcasePalette.containerBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: TaskShowcasePalette.mediumText(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.mediumText(context),
              // Tabular figures so dates/distances line up when chips stack.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the SVG priority glyph for [priority], sized to [size].
class TaskShowcasePriorityGlyph extends StatelessWidget {
  const TaskShowcasePriorityGlyph({
    required this.priority,
    this.size = 16,
    super.key,
  });

  final TaskPriority priority;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (priority) {
      TaskPriority.p0Urgent => 'assets/design_system/task_priority_p0.svg',
      TaskPriority.p1High => 'assets/design_system/task_priority_high.svg',
      TaskPriority.p2Medium => 'assets/design_system/task_priority_medium.svg',
      TaskPriority.p3Low => 'assets/design_system/task_priority_low.svg',
    };

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
    );
  }
}

/// Renders the SVG status glyph for [status], tinted from the palette to match
/// the status (e.g. info for in-progress, error for blocked), sized to [size].
class TaskShowcaseStatusGlyph extends StatelessWidget {
  const TaskShowcaseStatusGlyph({
    required this.status,
    this.size = 16,
    super.key,
  });

  final TaskStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (status) {
      TaskOpen() => 'assets/design_system/task_status_open.svg',
      TaskGroomed() => 'assets/design_system/task_status_groomed.svg',
      TaskInProgress() => 'assets/design_system/project_status_active.svg',
      TaskBlocked() => 'assets/design_system/task_status_blocked.svg',
      TaskOnHold() => 'assets/design_system/task_status_on_hold.svg',
      TaskDone() => 'assets/design_system/task_status_done.svg',
      TaskRejected() => 'assets/design_system/task_status_rejected.svg',
    };
    final color = switch (status) {
      TaskOpen() => TaskShowcasePalette.mediumText(context),
      TaskGroomed() || TaskInProgress() => TaskShowcasePalette.info(context),
      TaskBlocked() || TaskRejected() => TaskShowcasePalette.error(context),
      TaskOnHold() => TaskShowcasePalette.warning(context),
      TaskDone() => TaskShowcasePalette.success(context),
    };

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Status glyph followed by the localized status name. When [expanded] it
/// renders as a tappable-looking filled pill with a trailing unfold chevron;
/// otherwise it is a compact glyph-plus-caption row.
class TaskShowcaseStatusLabel extends StatelessWidget {
  const TaskShowcaseStatusLabel({
    required this.status,
    this.expanded = false,
    super.key,
  });

  final TaskStatus status;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final textColor = TaskShowcasePalette.highText(context);

    return Container(
      height: expanded ? 28 : null,
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? tokens.spacing.step3 : 0,
        vertical: expanded ? tokens.spacing.step2 : 0,
      ),
      decoration: expanded
          ? BoxDecoration(
              color: TaskShowcasePalette.subtleFill(context),
              borderRadius: BorderRadius.circular(20),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcaseStatusGlyph(status: status),
          SizedBox(
            width: expanded ? tokens.spacing.step2 : tokens.spacing.step1,
          ),
          Text(
            label,
            style:
                (expanded
                        ? tokens.typography.styles.subtitle.subtitle2
                        : tokens.typography.styles.others.caption)
                    .copyWith(color: textColor),
          ),
          if (expanded) ...[
            SizedBox(width: tokens.spacing.step1),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: TaskShowcasePalette.mediumText(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rounded section/segment pill pairing [icon] with [label]. When [active] it
/// uses the accent fill with dark foreground; otherwise a subtle fill with
/// muted text.
class TaskShowcaseSectionPill extends StatelessWidget {
  const TaskShowcaseSectionPill({
    required this.icon,
    required this.label,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final foreground = active
        ? Colors.black
        : TaskShowcasePalette.mediumText(context);
    final background = active
        ? TaskShowcasePalette.accent(context)
        : TaskShowcasePalette.subtleFill(context);

    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          SizedBox(width: tokens.spacing.step2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
