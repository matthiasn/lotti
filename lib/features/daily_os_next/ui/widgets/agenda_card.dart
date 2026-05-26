import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row on the Agenda view.
///
/// Layout follows `prototype/screens/plan.jsx → AgendaCard`:
/// 3 px left border in the category's stripe color, numbered circle,
/// title + WhyChip, outcome subtitle, right-side estimate + state
/// badge, optional progress bar at the bottom.
class AgendaCard extends StatelessWidget {
  const AgendaCard({
    required this.index,
    required this.item,
    this.whyReason,
    this.onTap,
    super.key,
  });

  final int index;
  final AgendaItem item;

  /// Reason for the first block linked to this agenda item, surfaced
  /// in the WhyChip. Null when no AI placement backs the item.
  final String? whyReason;

  /// Opens the backing task when `item.taskId` is available.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = _categoryColor();
    final progress = item.progress;
    final borderRadius = BorderRadius.circular(tokens.radii.l);
    final card = Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: borderRadius,
        border: Border(
          left: BorderSide(color: category, width: 3),
        ),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberedCircle(index: index, color: category),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: tokens.typography.styles.subtitle.subtitle1
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (whyReason != null) ...[
                          SizedBox(width: tokens.spacing.step2),
                          WhyChip(reason: whyReason!),
                        ],
                      ],
                    ),
                    if (item.outcome != null) ...[
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        item.outcome!,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              _RightMeta(item: item),
            ],
          ),
          if (progress != null) ...[
            SizedBox(height: tokens.spacing.step4),
            _ProgressBar(progress: progress, color: category),
          ],
        ],
      ),
    );
    final callback = onTap;
    if (callback == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: callback,
        borderRadius: borderRadius,
        child: card,
      ),
    );
  }

  Color _categoryColor() => categoryColorFromHex(item.category.colorHex);
}

class _NumberedCircle extends StatelessWidget {
  const _NumberedCircle({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RightMeta extends StatelessWidget {
  const _RightMeta({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (item.totalEstimateMinutes != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: tokens.colors.text.lowEmphasis,
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                context.messages.dailyOsNextEstimateMinutes(
                  item.totalEstimateMinutes!,
                ),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        SizedBox(height: tokens.spacing.step1),
        _StateBadge(state: item.state),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final AgendaItemState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (color, label) = switch (state) {
      AgendaItemState.open => (
        tokens.colors.text.lowEmphasis,
        context.messages.dailyOsNextAgendaStateOpen,
      ),
      AgendaItemState.inProgress => (
        tokens.colors.alert.warning.defaultColor,
        context.messages.dailyOsNextAgendaStateInProgress,
      ),
      AgendaItemState.overdue => (
        tokens.colors.alert.error.defaultColor,
        context.messages.dailyOsNextAgendaStateOverdue,
      ),
      AgendaItemState.done => (
        tokens.colors.alert.success.defaultColor,
        context.messages.dailyOsNextAgendaStateDone,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Text(
        label,
        style: tokens.typography.styles.others.caption.copyWith(color: color),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          backgroundColor: tokens.colors.background.level03,
        ),
      ),
    );
  }
}
