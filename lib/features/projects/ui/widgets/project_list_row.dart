import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_one_liner_provider.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

/// Horizontal padding applied to a project row's content. Exposed so the
/// owning list (`project_list_shared.dart`) can align dividers to the same
/// inset.
const kProjectRowHorizontalPadding = 16.0;

/// A target date within this window of today marks a row as "due soon", which
/// promotes its due chip to the warning accent so imminent deadlines stand out.
const _kDueSoonWindow = Duration(days: 7);

/// Stroke width of the leading progress ring. A drawing constant for the
/// [_ProgressRingPainter] custom painter rather than a layout spacing value.
const _kProgressRingStrokeWidth = 3.0;

/// Urgency bucket for a project's target date, driving the due chip's accent.
enum _DueStatus { overdue, soon, normal }

/// A single project row: a leading progress ring (with the completion percent
/// inside), the title and a quiet status pill, an optional one-liner, and a
/// meta-chip row surfacing task count, due date (coloured by urgency) and any
/// blocked tasks.
///
/// [categoryColor] is threaded down from the owning group so a project's
/// category identity reaches the row itself — it tints the progress ring for
/// healthy projects (red/amber/green is reserved for attention/completion).
class ProjectRow extends ConsumerWidget {
  const ProjectRow({
    required this.item,
    required this.categoryColor,
    required this.selected,
    required this.topOverlap,
    required this.bottomOverlap,
    required this.onHoverChanged,
    required this.onTap,
    this.backgroundTopInset = 0,
    this.backgroundBottomInset = 0,
    this.contentHorizontalPadding = kProjectRowHorizontalPadding,
    super.key,
  });

  final ProjectListItemData item;
  final Color categoryColor;
  final bool selected;
  final double topOverlap;
  final double bottomOverlap;
  final double backgroundTopInset;
  final double backgroundBottomInset;
  final double contentHorizontalPadding;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final projectId = item.project.meta.id;
    final oneLiner = ref.watch(projectOneLinerProvider(projectId)).value;

    final rollup = item.taskRollup;
    final completed = item.status is ProjectCompleted;
    final blockedCount = rollup.blockedTaskCount;
    final dueStatus = _dueStatusFor(item.targetDate, completed: completed);
    final needsAttention = projectNeedsAttention(item);

    final ringColor = completed
        ? ShowcasePalette.timeGreen(context)
        : needsAttention
        ? ShowcasePalette.error(context)
        : categoryColor;
    // "Active"/"Open" is the implicit default for an in-progress project and is
    // already conveyed by the ring, so only surface a status pill for the
    // less-obvious states; this stops a repetitive "Active" column from
    // competing with the urgent due/blocked chips for the trailing edge.
    final showStatusPill =
        item.status is! ProjectActive && item.status is! ProjectOpen;

    return GroupedCardRowSurface(
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
      padding: EdgeInsets.symmetric(
        horizontal: contentHorizontalPadding,
        vertical: tokens.spacing.step3,
      ),
      restingColor: needsAttention
          ? ShowcasePalette.attentionRowWash(context)
          : null,
      onHoverChanged: onHoverChanged,
      onTap: onTap,
      child: Row(
        children: [
          _ProjectProgressRing(
            key: ValueKey('project-row-progress-ring-$projectId'),
            progress: rollup.completionRatio,
            percent: rollup.completionPercent,
            ringColor: ringColor,
            completed: completed,
            needsAttention: needsAttention,
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            // Completed projects recede as a whole — title, description and
            // metadata dim together — leaving the green check ring as the one
            // vivid cue.
            child: Opacity(
              opacity: completed ? 0.55 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.project.data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.subtitle.subtitle1
                              .copyWith(
                                color: ShowcasePalette.highText(context),
                              ),
                        ),
                      ),
                      if (showStatusPill) ...[
                        SizedBox(width: tokens.spacing.step2),
                        ProjectStatusPill(status: item.status),
                      ],
                    ],
                  ),
                  if (oneLiner != null && oneLiner.isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      oneLiner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // bodySmall (not caption) gives the prose description a
                      // size step above the metadata chips so the two read as
                      // different kinds of text.
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: ShowcasePalette.mediumText(context),
                      ),
                    ),
                  ],
                  SizedBox(height: tokens.spacing.step2),
                  _ProjectMetaRow(
                    taskCount: rollup.totalTaskCount,
                    categoryColor: categoryColor,
                    targetDate: item.targetDate,
                    dueStatus: dueStatus,
                    blockedCount: blockedCount,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_DueStatus _dueStatusFor(DateTime? targetDate, {required bool completed}) {
  if (targetDate == null || completed) {
    return _DueStatus.normal;
  }
  final today = DateUtils.dateOnly(clock.now());
  final due = DateUtils.dateOnly(targetDate);
  if (due.isBefore(today)) {
    return _DueStatus.overdue;
  }
  if (!due.isAfter(today.add(_kDueSoonWindow))) {
    return _DueStatus.soon;
  }
  return _DueStatus.normal;
}

/// Whether a project needs attention now — it is not completed and is either
/// overdue or has blocked tasks. Shared by the row (attention wash + red ring)
/// and the section's triage ordering so both agree on "what needs me".
bool projectNeedsAttention(ProjectListItemData item) {
  if (item.status is ProjectCompleted) {
    return false;
  }
  if (item.taskRollup.blockedTaskCount > 0) {
    return true;
  }
  return _dueStatusFor(item.targetDate, completed: false) == _DueStatus.overdue;
}

/// Triage bucket used to order rows within a category section (lower sorts
/// first): needs-attention → in-progress → not-started → completed last, so
/// each coloured zone reads top-to-bottom as an "act on this first" ladder.
int projectTriageRank(ProjectListItemData item) {
  if (item.status is ProjectCompleted) {
    return 3;
  }
  if (projectNeedsAttention(item)) {
    return 0;
  }
  return item.taskRollup.completionPercent == 0 ? 2 : 1;
}

/// The row's metadata line: task count, due chip (accented when overdue/soon),
/// and a blocked chip when the project has blocked tasks. Rendered as a [Wrap]
/// of [_MetaChip]s so a single consistent chip system replaces ad-hoc
/// separators.
class _ProjectMetaRow extends StatelessWidget {
  const _ProjectMetaRow({
    required this.taskCount,
    required this.categoryColor,
    required this.targetDate,
    required this.dueStatus,
    required this.blockedCount,
  });

  final int taskCount;
  final Color categoryColor;
  final DateTime? targetDate;
  final _DueStatus dueStatus;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Identity tier: a quiet category-tinted task pill threads the category
        // hue into every row without competing with the loud semantic chips.
        _MetaChip(
          icon: Icons.task_alt_rounded,
          label: context.messages.settingsCategoriesTaskCount(taskCount),
          accent: categoryColor,
          tier: _ChipTier.identity,
        ),
        _buildDueChip(context),
        if (blockedCount > 0)
          _MetaChip(
            icon: Icons.block_rounded,
            label: context.messages.projectShowcaseBlockedLegend(blockedCount),
            accent: ShowcasePalette.error(context),
            tier: _ChipTier.semantic,
          ),
      ],
    );
  }

  Widget _buildDueChip(BuildContext context) {
    if (targetDate == null) {
      return _MetaChip(
        icon: Icons.all_inclusive_rounded,
        label: context.messages.projectShowcaseOngoing,
      );
    }
    final label = context.messages.projectShowcaseDueDate(
      DateFormat.MMMd(
        Localizations.localeOf(context).toString(),
      ).format(targetDate!),
    );
    // Icon shape — not just colour — encodes urgency so the signal survives for
    // colour-blind users (overdue ⚠ / soon ⏱ / normal 🗓). Only urgent dates
    // get the loud semantic weight; a normal date stays a quiet neutral chip.
    final (icon, accent, tier) = switch (dueStatus) {
      _DueStatus.overdue => (
        Icons.warning_amber_rounded,
        ShowcasePalette.error(context),
        _ChipTier.semantic,
      ),
      _DueStatus.soon => (
        Icons.schedule_rounded,
        ShowcasePalette.amber(context),
        _ChipTier.semantic,
      ),
      _DueStatus.normal => (Icons.event_rounded, null, _ChipTier.neutral),
    };
    return _MetaChip(icon: icon, label: label, accent: accent, tier: tier);
  }
}

/// Visual weight tier for a [_MetaChip]. [neutral] and [identity] are quiet
/// (faint fill, low-emphasis label) so the loud [semantic] urgency chips read
/// by weight, not by hue alone — and a warm category hue can't be mistaken for
/// an amber/red health signal.
enum _ChipTier { neutral, identity, semantic }

/// A small icon + label metadata chip carrying a [_ChipTier] visual weight.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.accent,
    this.tier = _ChipTier.neutral,
  }) : assert(
         tier == _ChipTier.neutral || accent != null,
         'identity/semantic chips require an accent colour',
       );

  final IconData icon;
  final String label;
  final Color? accent;
  final _ChipTier tier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final low = ShowcasePalette.lowText(context);
    // Quiet (neutral/identity) chips keep faint fills but a mediumText LABEL so
    // they stay recessive-but-readable; only semantic chips go full-chroma.
    final medium = ShowcasePalette.mediumText(context);
    final (fill, iconColor, labelColor) = switch (tier) {
      _ChipTier.neutral => (low.withValues(alpha: 0.08), low, medium),
      _ChipTier.identity => (accent!.withValues(alpha: 0.12), accent!, medium),
      _ChipTier.semantic => (accent!.withValues(alpha: 0.2), accent!, accent!),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: tokens.typography.size.caption, color: iconColor),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: tokens.typography.styles.others.caption.copyWith(
              color: labelColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Leading progress ring with the completion percentage inside (or a check for
/// completed projects). The arc colour is supplied by the caller so it can
/// carry category identity or an attention accent.
class _ProjectProgressRing extends StatelessWidget {
  const _ProjectProgressRing({
    required this.progress,
    required this.percent,
    required this.ringColor,
    required this.completed,
    required this.needsAttention,
    super.key,
  });

  final double progress;
  final int percent;
  final Color ringColor;
  final bool completed;
  final bool needsAttention;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final notStarted = !completed && percent == 0;
    return SizedBox.square(
      dimension: tokens.spacing.step7,
      child: CustomPaint(
        // A neutral track keeps the unfilled remainder reading as "work left"
        // regardless of the arc colour, so a low-progress arc stays legible and
        // the arc's hue is the only thing carrying health.
        painter: _ProgressRingPainter(
          progress: progress,
          trackColor: ShowcasePalette.lowText(context).withValues(alpha: 0.2),
          progressColor: ringColor,
        ),
        child: Center(child: _ringCenter(context, tokens, notStarted)),
      ),
    );
  }

  Widget _ringCenter(
    BuildContext context,
    DsTokens tokens,
    bool notStarted,
  ) {
    if (completed) {
      return Icon(
        Icons.check_rounded,
        size: tokens.typography.size.bodyLarge,
        color: ringColor,
      );
    }
    // A not-yet-started project shows a calm, low-emphasis "ready to begin" dot
    // rather than a deflating bare "0"; saturated colour stays reserved for
    // progress/health, never lifecycle stage.
    if (notStarted) {
      return Icon(
        Icons.fiber_manual_record,
        size: tokens.typography.size.caption,
        color: ShowcasePalette.lowText(context),
      );
    }
    // Pull the health signal into the gauge's brightest pixel: the numeral
    // takes the (red) attention colour, but stays neutral white when the ring
    // is just carrying calm category identity.
    return Text(
      '$percent',
      style: tokens.typography.styles.body.bodyLarge.copyWith(
        color: needsAttention ? ringColor : ShowcasePalette.highText(context),
        fontWeight: FontWeight.w700,
        height: 1,
        fontFeatures: numericBadgeFontFeatures,
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _kProgressRingStrokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - _kProgressRingStrokeWidth,
      size.height - _kProgressRingStrokeWidth,
    );
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kProgressRingStrokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kProgressRingStrokeWidth
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
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
