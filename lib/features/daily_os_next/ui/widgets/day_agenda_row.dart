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
/// when it has none), the category as a small dot, the name — a linked
/// item's task's own — and the time planned, on the page's shared
/// [DayRowScaffold]. Lines below, running under the figure, appear only when
/// there is something to say: one meta line with the outcome, the agenda's
/// wording when it adds to the task's name, and *Overdue* in error ink; then
/// the agent's reason, quiet, behind its violet spark.
///
/// - **In progress**: "Now" under its time and a `step1` teal edge down the
///   row.
/// - **Done**: the title struck through in low-emphasis ink, no reason line,
///   and the check, in the time's ink, in place of the category dot.
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
    // A finished item no longer needs its reason.
    final reason = done ? null : whyReason;
    // A linked row leads with its task's own name — the one its block on
    // the timeline wears — and keeps the agenda's wording, when it differs,
    // on the meta line.
    final displayTitle = this.displayTitle;
    final renamed =
        _isTaskLinked && displayTitle != null && displayTitle != item.title;
    final primaryTitle = renamed ? displayTitle : item.title;
    // The agenda's wording joins the meta line only when it says something
    // the task's name does not: "Legal: Is a penguin a passenger?" under
    // "Ask Legal whether a penguin is a passenger" adds nothing.
    final meta = [
      ?item.outcome,
      if (renamed && !_restates(item.title, primaryTitle)) item.title,
    ];

    // The item's name in the weight its timeline block uses, so the two
    // read as one thing and the name stands apart from its caption meta.
    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      fontWeight: tokens.typography.weight.semiBold,
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

    // Under the name, full width beneath the figure too: one meta line,
    // then the agent's reason.
    final hasMeta = meta.isNotEmpty || overdue;
    final below = !hasMeta && reason == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMeta) ...[
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
                  style: caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
              // The agent's reason last: the spark marks it as hers, the
              // words stay quiet so they do not out-colour the item itself.
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
            ],
          );

    // Every list on the page keeps one meaning per column: the mark says
    // where a row stands (its category, or the check once done) and the
    // trailing figure is always its time.
    final estimate = plannedMinutes ?? item.totalEstimateMinutes;
    final start = this.start;
    final row = DayRowScaffold(
      time: start == null ? '—' : formatClock(context, start),
      timeOverline: inProgress ? messages.dailyOsNextAgendaNow : null,
      active: inProgress,
      // The check in the time's own ink: green would read as a category.
      leading: done
          ? Icon(
              LottiIcons.confirm,
              size: tokens.typography.size.caption,
              color: tokens.colors.text.mediumEmphasis,
            )
          // The dot names its category, to a pointer and to a screen reader.
          : Tooltip(
              message: item.category.name,
              child: SizedBox.square(
                key: const Key('daily_os_agenda_row_dot'),
                dimension: tokens.spacing.step2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: categoryColorFromHex(item.category.colorHex),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
      trailing: estimate == null && !_isTaskLinked
          ? null
          : DayRowTrailing(
              figure: estimate == null ? null : formatMinutesCompact(estimate),
              icon: _isTaskLinked ? LottiIcons.chevronRight : null,
            ),
      below: below,
      child: title,
    );

    final tap = onTap;
    return tap == null
        ? row
        : Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: tap, child: row),
          );
  }
}

/// Whether [wording] says nothing [name] does not: every word of it — short
/// ones too, so a "not" or a "no" is never dropped — appears in [name],
/// ignoring case and punctuation. "Legal: Is a penguin a passenger?" restates
/// "Ask Legal whether a penguin is a passenger"; "Do not call vendor" does
/// not restate "Call vendor".
bool _restates(String wording, String name) {
  Set<String> words(String text) => {
    for (final word in text.toLowerCase().split(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    ))
      if (word.isNotEmpty) word,
  };
  final meaning = words(wording);
  return meaning.isNotEmpty && words(name).containsAll(meaning);
}
