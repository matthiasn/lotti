import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One item of the Agenda, as a row on the agenda's one card.
///
/// Left to right: a time column (the item's first block's start, or a dash
/// when it has none), the category as a small dot, the title, and the
/// estimate, on the page's shared [DayRowScaffold]. Further lines appear
/// only when there is something to say: the outcome, the linked task's own
/// name when it differs from the item's, and *Overdue* in error ink; then
/// the agent's reason, quiet, behind its violet spark.
///
/// - **In progress**: "Now" under its time, a `step1` teal edge down the row,
///   and, while the progress is part-way, a thin neutral bar for how far
///   along it is.
/// - **Done**: the title struck through in low-emphasis ink, no reason line,
///   and the success check in place of the estimate.
/// - **Task-linked** rows end in a chevron and open the task ([onTap]);
///   standalone rows are the unmarked default and, given [onRename], their
///   title is click-to-edit.
class DayAgendaRow extends StatelessWidget {
  const DayAgendaRow({
    required this.item,
    this.start,
    this.plannedMinutes,
    this.displayTitle,
    this.whyReason,
    this.onTap,
    this.onRename,
    super.key,
  });

  final AgendaItem item;

  /// When the item's first block starts; null when it has no block.
  final DateTime? start;

  /// The time today's plan gives the item — its blocks' length. Shown in
  /// place of the task's whole estimate, which can run past today.
  final int? plannedMinutes;

  /// The linked task's live title: the row's title when it differs from the
  /// item's own, which then moves to the meta line — so the row and the
  /// task's block on the timeline go by one name.
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
    final overdue = item.state == AgendaItemState.overdue;
    final caption = tokens.typography.styles.others.caption;
    final progress = item.progress;
    // A finished item no longer needs its reason.
    final reason = done ? null : whyReason;
    // A linked row leads with its task's own name — the one its block on
    // the timeline wears — and keeps the agenda's wording, when it differs,
    // on the meta line.
    final displayTitle = this.displayTitle;
    final renamed =
        _isTaskLinked && displayTitle != null && displayTitle != item.title;
    final primaryTitle = renamed ? displayTitle : item.title;
    final meta = [
      ?item.outcome,
      if (renamed) item.title,
    ];

    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: done
          ? tokens.colors.text.lowEmphasis
          : tokens.colors.text.highEmphasis,
      decoration: done ? TextDecoration.lineThrough : null,
    );
    final onRename = this.onRename;
    final title = !_isTaskLinked && onRename != null && !done
        ? EditableTitle(
            value: item.title,
            onSubmitted: onRename,
            style: titleStyle,
          )
        : Text(
            primaryTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          );

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: caption.copyWith(color: tokens.colors.text.lowEmphasis),
          ),
        ],
        // The agent's reason last: the spark marks it as hers, the words
        // stay quiet so they do not out-colour the item itself.
        if (reason != null) ...[
          SizedBox(height: tokens.spacing.step1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step1),
                child: Icon(
                  LottiIcons.aiSpark,
                  size: tokens.typography.size.caption,
                  color: tokens.colors.aiCard.accent,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Expanded(
                child: Text(
                  reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
            ],
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
                // Quiet: the row's teal edge already says "now"; the bar
                // only says how far along.
                valueColor: AlwaysStoppedAnimation<Color>(
                  tokens.colors.decorative.level03,
                ),
                backgroundColor: tokens.colors.decorative.level01,
              ),
            ),
          ),
        ],
      ],
    );

    final estimate = plannedMinutes ?? item.totalEstimateMinutes;
    final mark = done
        ? Icon(
            LottiIcons.confirm,
            size: tokens.typography.size.bodySmall,
            color: tokens.colors.alert.success.defaultColor,
          )
        : estimate == null
        ? null
        : Text(
            formatMinutesCompact(estimate),
            style: caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontFeatures: dayFigures,
            ),
          );
    final trailing = mark == null && !_isTaskLinked
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?mark,
              if (_isTaskLinked) ...[
                if (mark != null) SizedBox(width: tokens.spacing.step2),
                Icon(
                  LottiIcons.chevronRight,
                  size: tokens.typography.size.subtitle2,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ],
            ],
          );

    final start = this.start;
    final row = DayRowScaffold(
      time: start == null ? '—' : formatClock(context, start),
      timeOverline: inProgress ? messages.dailyOsNextAgendaNow : null,
      leading: SizedBox.square(
        key: const Key('daily_os_agenda_row_dot'),
        dimension: tokens.spacing.step2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: categoryColorFromHex(item.category.colorHex),
            shape: BoxShape.circle,
          ),
        ),
      ),
      trailing: trailing,
      child: details,
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
    return tap == null
        ? marked
        : Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: tap, child: marked),
          );
  }
}
