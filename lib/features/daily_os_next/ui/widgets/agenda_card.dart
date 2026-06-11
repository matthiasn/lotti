import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/link_badge.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row on the Agenda view.
///
/// The row keeps the category stripe and order number visible while using a
/// compact task-list rhythm: title first, then quiet bare-icon metadata
/// (reason sparkle, estimate, state). Task-linked items carry a [LinkBadge]
/// that opens the task; standalone items are the unmarked default with a
/// click-to-edit title (handoff v2 item 3).
class AgendaCard extends StatelessWidget {
  const AgendaCard({
    required this.index,
    required this.item,
    this.displayTitle,
    this.whyReason,
    this.coverArtId,
    this.coverArtCropX = 0.5,
    this.onTap,
    this.onRename,
    super.key,
  });

  final int index;
  final AgendaItem item;

  /// Live title of the linked task, shown on the [LinkBadge] so a task
  /// renamed elsewhere stays recognisable. The card title itself stays
  /// on [AgendaItem.title] — the agenda intent line.
  final String? displayTitle;

  /// Reason for the first block linked to this agenda item, surfaced
  /// in the Why pill. Null when no AI placement backs the item.
  final String? whyReason;

  /// Linked task cover art image ID, when the backing task has one.
  final String? coverArtId;

  /// Horizontal crop for [coverArtId], matching the task cover-art crop.
  final double coverArtCropX;

  /// Opens the backing task when `item.taskId` is available.
  final VoidCallback? onTap;

  /// Inline rename for **standalone** items (no backing task). When
  /// provided and the item has no task, the title becomes click-to-edit.
  /// Task-linked titles stay read-only here — they're edited on the task.
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = _categoryColor();
    final progress = item.progress;
    final borderRadius = BorderRadius.circular(tokens.radii.m);
    // Mid-day the fold belongs to what's next: finished items collapse to
    // one quiet receipt row so in-progress and upcoming cards own the
    // viewport.
    if (item.state == AgendaItemState.done) {
      final doneRow = DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          borderRadius: borderRadius,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              SizedBox(
                width: tokens.spacing.step6,
                child: Text(
                  '$index',
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: category,
                    fontWeight: tokens.typography.weight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Icon(
                Icons.check_rounded,
                size: 14,
                color: tokens.colors.alert.success.defaultColor,
              ),
            ],
          ),
        ),
      );
      final callback = onTap;
      if (callback == null) return doneRow;
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: callback,
          borderRadius: borderRadius,
          child: doneRow,
        ),
      );
    }
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
                    coverArtId: coverArtId,
                    coverArtCropX: coverArtCropX,
                    onOpenTask: onTap,
                    onRename: onRename,
                  ),
                  if (progress != null && progress > 0 && progress < 1) ...[
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
      type: MaterialType.transparency,
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
    required this.coverArtId,
    required this.coverArtCropX,
    required this.onOpenTask,
    required this.onRename,
  });

  final int index;
  final AgendaItem item;
  final String? displayTitle;
  final Color category;
  final String? whyReason;
  final String? coverArtId;
  final double coverArtCropX;
  final VoidCallback? onOpenTask;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AgendaLeading(
          index: index,
          color: category,
          coverArtId: coverArtId,
          coverArtCropX: coverArtCropX,
        ),
        SizedBox(width: tokens.spacing.step4),
        Expanded(
          child: _AgendaContent(
            item: item,
            displayTitle: displayTitle,
            whyReason: whyReason,
            onOpenTask: onOpenTask,
            onRename: onRename,
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
    required this.onOpenTask,
    required this.onRename,
  });

  final AgendaItem item;
  final String? displayTitle;
  final String? whyReason;
  final VoidCallback? onOpenTask;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isDesktop = isDesktopLayout(context);
    final isTaskLinked = item.taskId != null && item.taskId!.isNotEmpty;
    final hasMeta =
        whyReason != null ||
        item.totalEstimateMinutes != null ||
        item.state != AgendaItemState.open;
    final titleStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    // Standalone titles are click-to-edit; task-linked titles are
    // edited on the task itself (handoff v2 item 3).
    final title = !isTaskLinked && onRename != null
        ? EditableTitle(
            value: item.title,
            onSubmitted: onRename!,
            style: titleStyle,
          )
        : Text(
            item.title,
            style: titleStyle,
            maxLines: isDesktop ? 2 : 3,
            overflow: TextOverflow.fade,
            softWrap: true,
          );
    final meta = _AgendaMetaRow(item: item, whyReason: whyReason);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop && hasMeta)
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
          if (hasMeta) ...[
            SizedBox(height: tokens.spacing.step3),
            meta,
          ],
        ],
        // Only the exception is marked: task-linked items carry the badge
        // that opens the task; standalone blocks are the calm default and
        // carry nothing.
        if (isTaskLinked) ...[
          SizedBox(height: tokens.spacing.step3),
          LinkBadge(
            label: displayTitle ?? item.title,
            onTap: onOpenTask,
          ),
        ],
        if (item.outcome != null) ...[
          SizedBox(height: tokens.spacing.step3),
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

class _AgendaLeading extends StatelessWidget {
  const _AgendaLeading({
    required this.index,
    required this.color,
    required this.coverArtId,
    required this.coverArtCropX,
  });

  final int index;
  final Color color;
  final String? coverArtId;
  final double coverArtCropX;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final imageId = coverArtId?.trim();
    final size = tokens.spacing.step9;
    if (imageId == null || imageId.isEmpty) {
      return SizedBox(
        width: size,
        child: Align(
          alignment: Alignment.topCenter,
          child: _NumberedCircle(
            index: index,
            color: color,
            size: tokens.spacing.step7,
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: CoverArtThumbnail(
                imageId: imageId,
                size: size,
                cropX: coverArtCropX,
              ),
            ),
          ),
          Positioned(
            left: tokens.spacing.step1,
            bottom: tokens.spacing.step1,
            child: _NumberedCircle(
              index: index,
              color: color,
              size: tokens.spacing.step6,
              solid: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedCircle extends StatelessWidget {
  const _NumberedCircle({
    required this.index,
    required this.color,
    required this.size,
    this.solid = false,
  });

  final int index;
  final Color color;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final solidForeground = _higherContrastForeground(
      background: color,
      first: tokens.colors.text.highEmphasis,
      second: tokens.colors.text.onInteractiveAlert,
    );
    // The bare order number is enough on the card surface; a plated ring
    // on every row was decoration without function. The solid plate stays
    // for the cover-art overlay where the number needs its own contrast.
    if (!solid) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '$index',
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
              fontWeight: tokens.typography.weight.bold,
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: tokens.typography.styles.others.caption.copyWith(
          color: solidForeground,
          fontWeight: tokens.typography.weight.bold,
        ),
      ),
    );
  }
}

Color _higherContrastForeground({
  required Color background,
  required Color first,
  required Color second,
}) {
  final firstContrast = _contrastRatio(background, first);
  final secondContrast = _contrastRatio(background, second);
  return firstContrast >= secondContrast ? first : second;
}

double _contrastRatio(Color background, Color foreground) {
  final opaqueForeground = foreground.a < 1
      ? Color.alphaBlend(foreground, background)
      : foreground;
  final backgroundLuminance = background.computeLuminance();
  final foregroundLuminance = opaqueForeground.computeLuminance();
  final lighter = math.max(backgroundLuminance, foregroundLuminance);
  final darker = math.min(backgroundLuminance, foregroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

class _AgendaMetaRow extends StatelessWidget {
  const _AgendaMetaRow({required this.item, required this.whyReason});

  final AgendaItem item;
  final String? whyReason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final children = <Widget>[
      if (whyReason != null) _WhyMeta(reason: whyReason!),
      if (item.totalEstimateMinutes != null)
        _EstimateMeta(minutes: item.totalEstimateMinutes!),
      if (item.state != AgendaItemState.open) _StateMeta(state: item.state),
    ];
    if (children.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
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
    // A bare sparkle carries "the agent placed this for a reason"; the
    // reason itself lives in the tooltip. A labelled tinted pill on every
    // AI row out-shouted the titles.
    return Tooltip(
      message: reason,
      child: Semantics(
        label: context.messages.dailyOsNextDayWhyChipLabel,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: tokens.typography.size.caption,
          color: color.withValues(alpha: 0.8),
        ),
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
          size: tokens.typography.size.caption,
          color: color,
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          context.messages.dailyOsNextEstimateMinutes(minutes),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
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
      // Neutral: in-progress is the normal mid-day condition, not a
      // warning — amber is reserved for overdue.
      AgendaItemState.inProgress => (
        tokens.colors.text.mediumEmphasis,
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
    // Done is a glyph, in-progress a quiet colored caption; only the
    // overdue alarm earns a tinted container.
    return switch (state) {
      AgendaItemState.done => Semantics(
        label: label,
        child: Icon(Icons.check_rounded, size: 14, color: color),
      ),
      AgendaItemState.overdue => DsPill(
        variant: DsPillVariant.tinted,
        color: color,
        label: label,
        labelColor: color,
      ),
      _ => Text(
        label,
        style: tokens.typography.styles.others.caption.copyWith(color: color),
      ),
    };
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
        height: tokens.spacing.step1,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          backgroundColor: tokens.colors.background.level03,
        ),
      ),
    );
  }
}
