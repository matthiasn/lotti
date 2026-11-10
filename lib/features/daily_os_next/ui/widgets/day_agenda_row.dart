import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:material_ui/material_ui.dart';

/// One item of the Agenda, as a row on the agenda's one card.
///
/// Left to right: a time column (the item's first block's start, or a dash
/// when it has none), the category as a small dot, the title, and the
/// estimate. A second line appears only when there is something to say:
/// the agent's reason for the placement, in `aiCard.accent` with its
/// sparkle; then the outcome, the linked task's own name when it differs
/// from the item's, and *Overdue* in error ink.
///
/// - **In progress**: a `step1` teal edge down the row, the title in
///   subtitle2, and, while the progress is part-way, a thin bar in the
///   category colour.
/// - **Done**: the whole row at half opacity, the title struck through, and
///   the success check in place of the estimate.
/// - **Task-linked** rows end in a chevron and open the task ([onTap]);
///   standalone rows are the unmarked default and, given [onRename], their
///   title is click-to-edit.
class DayAgendaRow extends StatelessWidget {
  const DayAgendaRow({
    required this.item,
    this.start,
    this.displayTitle,
    this.whyReason,
    this.onTap,
    this.onRename,
    super.key,
  });

  final AgendaItem item;

  /// When the item's first block starts; null when it has no block.
  final DateTime? start;

  /// The linked task's live title. Shown on the meta line when it differs
  /// from the item's own title, so a task renamed elsewhere stays
  /// recognisable.
  final String? displayTitle;

  /// Why the agent placed the item where it did, when it says.
  final String? whyReason;

  /// Opens the backing task.
  final VoidCallback? onTap;

  /// Renames a standalone item; ignored for task-linked items, whose title
  /// belongs to the task.
  final ValueChanged<String>? onRename;

  bool get _isTaskLinked => item.taskId?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final done = item.state == AgendaItemState.done;
    final inProgress = item.state == AgendaItemState.inProgress;
    final category = categoryColorFromHex(item.category.colorHex);
    final caption = tokens.typography.styles.others.caption;
    final tabular = caption.copyWith(fontFeatures: numericBadgeFontFeatures);
    final progress = item.progress;
    final reason = whyReason;
    final displayTitle = this.displayTitle;
    final meta = [
      ?item.outcome,
      if (_isTaskLinked && displayTitle != null && displayTitle != item.title)
        displayTitle,
    ];
    final overdue = item.state == AgendaItemState.overdue;

    final titleStyle =
        (inProgress
                ? tokens.typography.styles.subtitle.subtitle2
                : tokens.typography.styles.body.bodySmall)
            .copyWith(
              color: tokens.colors.text.highEmphasis,
              decoration: done ? TextDecoration.lineThrough : null,
            );
    final onRename = this.onRename;
    final title = !_isTaskLinked && onRename != null && !done
        ? EditableTitle(
            value: item.title,
            onSubmitted: onRename,
            style: titleStyle,
          )
        : Text(item.title, style: titleStyle);

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if (reason != null) ...[
          SizedBox(height: tokens.spacing.step1),
          Row(
            children: [
              Icon(
                LottiIcons.aiSpark,
                size: tokens.typography.size.caption,
                color: tokens.colors.aiCard.accent,
              ),
              SizedBox(width: tokens.spacing.step2),
              Expanded(
                child: Text(
                  reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caption.copyWith(color: tokens.colors.aiCard.accent),
                ),
              ),
            ],
          ),
        ],
        if (meta.isNotEmpty || overdue) ...[
          SizedBox(height: tokens.spacing.step1),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: meta.join(' · ')),
                if (overdue) ...[
                  if (meta.isNotEmpty) const TextSpan(text: ' · '),
                  TextSpan(
                    text: messages.dailyOsNextAgendaStateOverdue,
                    style: caption.copyWith(
                      color: tokens.colors.alert.error.ink,
                    ),
                  ),
                ],
              ],
            ),
            style: caption.copyWith(color: tokens.colors.text.lowEmphasis),
          ),
        ],
        if (inProgress && progress != null && progress > 0 && progress < 1) ...[
          SizedBox(height: tokens.spacing.step2),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.xs),
            child: SizedBox(
              height: tokens.spacing.step1,
              child: LinearProgressIndicator(
                key: const Key('daily_os_agenda_row_progress'),
                value: progress,
                valueColor: AlwaysStoppedAnimation<Color>(category),
                backgroundColor: tokens.colors.decorative.level01,
              ),
            ),
          ),
        ],
      ],
    );

    final estimate = item.totalEstimateMinutes;
    final trailing = done
        ? Icon(
            LottiIcons.confirm,
            size: tokens.typography.size.bodySmall,
            color: tokens.colors.alert.success.defaultColor,
          )
        : estimate == null
        ? null
        : Text(
            formatMinutesCompact(estimate),
            style: tabular.copyWith(color: tokens.colors.text.mediumEmphasis),
          );

    final start = this.start;
    final scaler = MediaQuery.textScalerOf(context);
    // The time column grows with the user's text size, so every row's
    // dot and title still start on one vertical line.
    final timeWidth = scaler.scale(tokens.spacing.step10);
    // The time and the dot centre on the title's first line.
    final titleLine = scaler.scale(
      inProgress
          ? tokens.typography.lineHeight.subtitle2
          : tokens.typography.lineHeight.bodySmall,
    );
    double centredOnTitle(double height) =>
        ((titleLine - height) / 2).clamp(0, double.infinity);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TapTargets.minimum),
      // A one-line row shorter than the touch target sits centred in it,
      // rather than pinned to its top with the slack below.
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.cardPadding,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: timeWidth,
                padding: EdgeInsets.only(
                  top: centredOnTitle(
                    scaler.scale(tokens.typography.lineHeight.caption),
                  ),
                ),
                child: Text(
                  start == null ? '—' : formatClock(context, start),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tabular.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: centredOnTitle(tokens.spacing.step2),
                ),
                child: SizedBox.square(
                  key: const Key('daily_os_agenda_row_dot'),
                  dimension: tokens.spacing.step2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: category,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(child: details),
              if (trailing != null) ...[
                SizedBox(width: tokens.spacing.step3),
                Padding(
                  padding: EdgeInsets.only(
                    top: centredOnTitle(
                      done
                          ? tokens.typography.size.bodySmall
                          : scaler.scale(tokens.typography.lineHeight.caption),
                    ),
                  ),
                  child: trailing,
                ),
              ],
              if (_isTaskLinked) ...[
                SizedBox(width: tokens.spacing.step2),
                Padding(
                  padding: EdgeInsets.only(
                    top: centredOnTitle(tokens.typography.size.subtitle2),
                  ),
                  child: Icon(
                    LottiIcons.chevronRight,
                    size: tokens.typography.size.subtitle2,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final marked = inProgress
        ? Stack(
            children: [
              row,
              Positioned(
                key: const Key('daily_os_agenda_row_active_edge'),
                left: 0,
                top: 0,
                bottom: 0,
                width: tokens.spacing.step1,
                child: ColoredBox(color: tokens.colors.interactive.enabled),
              ),
            ],
          )
        : row;
    final tap = onTap;
    final tappable = tap == null
        ? marked
        : Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: tap, child: marked),
          );
    return done ? Opacity(opacity: 0.5, child: tappable) : tappable;
  }
}
