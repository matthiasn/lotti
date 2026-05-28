import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row on the Agenda view.
///
/// The row keeps the category stripe and order number visible while using a
/// compact task-list rhythm: title first, then reason, estimate, and state as
/// one caption-weight metadata line.
class AgendaCard extends StatelessWidget {
  const AgendaCard({
    required this.index,
    required this.item,
    this.displayTitle,
    this.whyReason,
    this.onTap,
    super.key,
  });

  final int index;
  final AgendaItem item;
  final String? displayTitle;

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
    final borderRadius = BorderRadius.circular(tokens.radii.m);
    final card = ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: borderRadius,
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ColoredBox(
                  color: category,
                  child: SizedBox(width: tokens.spacing.step1),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AgendaCardTop(
                    index: index,
                    item: item,
                    displayTitle: displayTitle,
                    category: category,
                    whyReason: whyReason,
                  ),
                  if (progress != null) ...[
                    SizedBox(height: tokens.spacing.step4),
                    _ProgressBar(progress: progress, color: category),
                  ],
                ],
              ),
            ),
          ],
        ),
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

class _AgendaCardTop extends StatelessWidget {
  const _AgendaCardTop({
    required this.index,
    required this.item,
    required this.displayTitle,
    required this.category,
    required this.whyReason,
  });

  final int index;
  final AgendaItem item;
  final String? displayTitle;
  final Color category;
  final String? whyReason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberedCircle(index: index, color: category),
        SizedBox(width: tokens.spacing.step4),
        Expanded(
          child: _AgendaContent(
            item: item,
            displayTitle: displayTitle,
            whyReason: whyReason,
          ),
        ),
      ],
    );
  }
}

class _AgendaContent extends StatelessWidget {
  const _AgendaContent({
    required this.item,
    required this.displayTitle,
    required this.whyReason,
  });

  final AgendaItem item;
  final String? displayTitle;
  final String? whyReason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isDesktop = isDesktopLayout(context);
    final title = Text(
      displayTitle ?? item.title,
      style: tokens.typography.styles.subtitle.subtitle2.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
      maxLines: isDesktop ? 2 : 3,
      overflow: TextOverflow.fade,
      softWrap: true,
    );
    final meta = _AgendaMetaRow(item: item, whyReason: whyReason);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              SizedBox(width: tokens.spacing.step4),
              meta,
            ],
          )
        else ...[
          title,
          SizedBox(height: tokens.spacing.step2),
          meta,
        ],
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
    );
  }
}

class _NumberedCircle extends StatelessWidget {
  const _NumberedCircle({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: tokens.spacing.step6,
      height: tokens.spacing.step6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: tokens.typography.styles.others.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AgendaMetaRow extends StatelessWidget {
  const _AgendaMetaRow({required this.item, required this.whyReason});

  final AgendaItem item;
  final String? whyReason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (whyReason != null) _WhyMeta(reason: whyReason!),
        if (whyReason != null) const _MetaSeparator(),
        if (item.totalEstimateMinutes != null) ...[
          _EstimateMeta(minutes: item.totalEstimateMinutes!),
          const _MetaSeparator(),
        ],
        _StateMeta(state: item.state),
      ],
    );
  }
}

class _WhyMeta extends StatelessWidget {
  const _WhyMeta({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tokens.colors.aiCard.accent;
    return Tooltip(
      message: reason,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: tokens.spacing.step3,
            color: color,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            context.messages.dailyOsNextDayWhyChipLabel,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimateMeta extends StatelessWidget {
  const _EstimateMeta({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = tokens.colors.text.lowEmphasis;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: tokens.spacing.step3,
          color: color,
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          context.messages.dailyOsNextEstimateMinutes(minutes),
          style: tokens.typography.styles.others.caption.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MetaSeparator extends StatelessWidget {
  const _MetaSeparator();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      '·',
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}

class _StateMeta extends StatelessWidget {
  const _StateMeta({required this.state});

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
    return Text(
      label,
      style: tokens.typography.styles.others.caption.copyWith(
        color: color,
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
