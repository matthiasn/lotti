import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agenda_order.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agenda_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/features/design_system/components/cards/ds_rows_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Intent-first projection of the [DraftPlan]: its items as [DayAgendaRow]s
/// on one [DsRowsCard], in the order of the day.
/// How full the day is lives in the page's briefing strip above, shared with
/// the other tabs.
///
/// The list opens on now: when the day starts with two or more finished
/// items, they fold into one summary row ("5 items done", with the time
/// they spanned) that unfolds on a tap, so the item under way and the next
/// one are in view without scrolling. The fold is this view's state, so a
/// reload of the plan keeps it as the user left it.
///
/// With no plan ([hasPlan] false) the body is a dashed "No plan yet" card.
class AgendaView extends StatefulWidget {
  const AgendaView({
    required this.draft,
    this.hasPlan = true,
    this.onRenameItem,
    this.header,
    this.onStartCheckIn,
    super.key,
  });

  /// Starts the check-in from a day without a plan: what its "No plan yet"
  /// row does on a tap.
  final VoidCallback? onStartCheckIn;

  final DraftPlan draft;

  /// Scrolls in above the list — the page's briefing on a phone, so it
  /// gives the screen back to the day as the list scrolls.
  final Widget? header;

  /// False when the day has no drafted plan (the [draft] is a
  /// synthetic empty aggregate so the surface can still render).
  final bool hasPlan;

  /// Inline rename for standalone agenda items (handoff v2 item 3).
  final void Function(AgendaItem item, String title)? onRenameItem;

  /// The fewest leading finished items worth folding: one finished item is
  /// shown as it is.
  static const int foldDoneFrom = 2;

  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  bool _showDone = false;

  DraftPlan get draft => widget.draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onRenameItem = widget.onRenameItem;
    final hasPlan = widget.hasPlan;
    final ordered = agendaItemsByStart(draft);
    final doneRun = ordered
        .takeWhile((e) => e.item.state == AgendaItemState.done)
        .toList();
    final folds = doneRun.length >= AgendaView.foldDoneFrom;
    Widget row(({AgendaItem item, DateTime? start}) entry) => _LiveAgendaRow(
      key: ValueKey(entry.item.id),
      item: entry.item,
      start: entry.start,
      plannedMinutes: _plannedMinutesFor(entry.item),
      whyReason: _whyReasonFor(entry.item),
      onTap: _taskTapFor(entry.item),
      onRename: onRenameItem == null
          ? null
          : (title) => onRenameItem(entry.item, title),
    );
    final header = widget.header;
    return SingleChildScrollView(
      // Extra bottom inset: the host fades the last stretch at the fold, so
      // the final row must be able to scroll fully clear of the band.
      padding: EdgeInsets.only(bottom: tokens.spacing.step10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Padding(
            // step5 horizontal: the agenda shares the page's single left
            // rail with the masthead and the briefing.
            padding: EdgeInsets.only(
              left: tokens.spacing.step5,
              top: tokens.spacing.step4,
              right: tokens.spacing.step5,
            ),
            // The page sets the reading column (one for every tab).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (draft.agendaItems.isNotEmpty)
                  DsRowsCard(
                    rows: [
                      if (folds) ...[
                        _DoneRunRow(
                          key: const ValueKey('daily_os_agenda_done_run'),
                          count: doneRun.length,
                          first: doneRun.first.start,
                          expanded: _showDone,
                          onToggle: () =>
                              setState(() => _showDone = !_showDone),
                        ),
                        if (_showDone) ...doneRun.map(row),
                        ...ordered.skip(doneRun.length).map(row),
                      ] else
                        ...ordered.map(row),
                    ],
                  ),
                // "No plan yet" copy only when there genuinely is no plan;
                // a real plan with zero agenda items keeps just the strip.
                if (draft.agendaItems.isEmpty && !hasPlan)
                  _AgendaEmptyState(onTap: widget.onStartCheckIn),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The time the plan gives [item] today: its linked blocks' length, not
  /// the task's whole estimate. Null when it has no block.
  int? _plannedMinutesFor(AgendaItem item) {
    final ids = item.linkedBlockIds.toSet();
    final minutes = [
      for (final block in draft.blocks)
        if (ids.contains(block.id) && block.state != TimeBlockState.dropped)
          block.duration.inMinutes,
    ];
    return minutes.isEmpty ? null : minutes.fold<int>(0, (a, b) => a + b);
  }

  String? _whyReasonFor(AgendaItem item) {
    if (item.linkedBlockIds.isEmpty) return null;
    final firstId = item.linkedBlockIds.first;
    for (final block in draft.blocks) {
      if (block.id == firstId &&
          block.type == TimeBlockType.ai &&
          block.reason != null) {
        return block.reason;
      }
    }
    return null;
  }

  VoidCallback? _taskTapFor(AgendaItem item) {
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty) return null;
    return () => beamToNamed('/tasks/$taskId');
  }
}

/// The day's leading finished items, folded into one row: the first one's
/// time, how many there are, and a chevron that unfolds them in place.
class _DoneRunRow extends StatelessWidget {
  const _DoneRunRow({
    required this.count,
    required this.first,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final int count;
  final DateTime? first;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final first = this.first;
    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded
          ? messages.dailyOsNextAgendaHideDone
          : messages.dailyOsNextAgendaShowDone,
      excludeSemantics: true,
      onTap: onToggle,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          child: DayRowScaffold(
            time: first == null ? '—' : formatClock(context, first),
            leading: Icon(
              LottiIcons.confirm,
              size: tokens.typography.size.caption,
              color: tokens.colors.alert.success.defaultColor,
            ),
            trailing: Icon(
              expanded ? LottiIcons.chevronUp : LottiIcons.chevronDown,
              size: tokens.typography.size.subtitle2,
              color: tokens.colors.text.lowEmphasis,
            ),
            child: Text(
              messages.dailyOsNextAgendaDoneRun(count),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An agenda row that follows its linked task: the task's live category and
/// title, or a visible fallback once the task is gone.
class _LiveAgendaRow extends ConsumerWidget {
  const _LiveAgendaRow({
    required this.item,
    required this.start,
    required this.plannedMinutes,
    required this.whyReason,
    required this.onTap,
    required this.onRename,
    super.key,
  });

  final AgendaItem item;
  final DateTime? start;
  final int? plannedMinutes;
  final String? whyReason;
  final VoidCallback? onTap;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTask = watchLiveTaskMetadata(ref, item.taskId);
    return DayAgendaRow(
      item: item.copyWith(category: liveTask.categoryOr(item.category)),
      start: start,
      plannedMinutes: plannedMinutes,
      displayTitle: liveTask.missing
          ? context.messages.conflictDetailEntryNotFoundTitle
          : liveTask.title,
      whyReason: whyReason,
      onTap: onTap,
      onRename: onRename,
    );
  }
}

/// A day without a plan, on the Agenda: one row on the page's grid saying
/// so, which starts the check-in when tapped. The recorded sessions are the
/// Activity tab's, and the footer carries the filled action.
class _AgendaEmptyState extends StatelessWidget {
  const _AgendaEmptyState({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onTap = this.onTap;
    final row = DayRowScaffold(
      time: '—',
      leading: Icon(
        LottiIcons.twilight,
        size: tokens.typography.size.caption,
        color: tokens.colors.text.lowEmphasis,
      ),
      trailing: onTap == null
          ? null
          : Icon(
              LottiIcons.chevronRight,
              size: tokens.typography.size.subtitle2,
              color: tokens.colors.text.lowEmphasis,
            ),
      child: Text(
        context.messages.dailyOsNextAgendaNoPlanTitle,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
    return DsRowsCard(
      rows: [
        if (onTap == null)
          row
        else
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('daily_os_agenda_start_check_in'),
              onTap: onTap,
              child: row,
            ),
          ),
      ],
    );
  }
}
