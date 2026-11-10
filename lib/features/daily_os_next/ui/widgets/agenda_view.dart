import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agenda_order.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agenda_row.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/design_system/components/cards/ds_rows_card.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Intent-first projection of the [DraftPlan]: its items as [DayAgendaRow]s
/// on one [DsRowsCard], in the order of the day.
/// How full the day is lives in the page's briefing strip above, shared with
/// the other tabs.
///
/// With no plan ([hasPlan] false) the body shows a dashed hint card plus the
/// [TimeSpentCard] instead of a dead empty state (handoff v2 item 2).
class AgendaView extends StatelessWidget {
  const AgendaView({
    required this.draft,
    this.actualBlocks = const [],
    this.hasPlan = true,
    this.onRenameItem,
    super.key,
  });

  final DraftPlan draft;

  /// Recorded sessions for the day — feeds the honest empty strip and
  /// the empty-state [TimeSpentCard].
  final List<TimeBlock> actualBlocks;

  /// False when the day has no drafted plan (the [draft] is a
  /// synthetic empty aggregate so the surface can still render).
  final bool hasPlan;

  /// Inline rename for standalone agenda items (handoff v2 item 3).
  final void Function(AgendaItem item, String title)? onRenameItem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onRenameItem = this.onRenameItem;
    return SingleChildScrollView(
      // step5 horizontal: the agenda shares the page's single left rail
      // with the masthead, toggle, and nudge chip. Extra bottom inset:
      // the host fades the last ~36px at the fold, so the final row must
      // be able to scroll fully clear of the band.
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step10,
      ),
      // A reading-width column on desktop instead of a stretched phone
      // list; phones are unaffected.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (draft.agendaItems.isNotEmpty)
                DsRowsCard(
                  rows: [
                    for (final (:item, :start) in agendaItemsByStart(draft))
                      _LiveAgendaRow(
                        key: ValueKey(item.id),
                        item: item,
                        start: start,
                        whyReason: _whyReasonFor(item),
                        onTap: _taskTapFor(item),
                        onRename: onRenameItem == null
                            ? null
                            : (title) => onRenameItem(item, title),
                      ),
                  ],
                ),
              // "No plan yet" copy only when there genuinely is no plan;
              // a real plan with zero agenda items keeps just the strip.
              if (draft.agendaItems.isEmpty && !hasPlan)
                _AgendaEmptyState(actualBlocks: actualBlocks),
            ],
          ),
        ),
      ),
    );
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

/// An agenda row that follows its linked task: the task's live category and
/// title, or a visible fallback once the task is gone.
class _LiveAgendaRow extends ConsumerWidget {
  const _LiveAgendaRow({
    required this.item,
    required this.start,
    required this.whyReason,
    required this.onTap,
    required this.onRename,
    super.key,
  });

  final AgendaItem item;
  final DateTime? start;
  final String? whyReason;
  final VoidCallback? onTap;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveTask = watchLiveTaskMetadata(ref, item.taskId);
    return DayAgendaRow(
      item: item.copyWith(category: liveTask.categoryOr(item.category)),
      start: start,
      displayTitle: liveTask.missing
          ? context.messages.conflictDetailEntryNotFoundTitle
          : liveTask.title,
      whyReason: whyReason,
      onTap: onTap,
      onRename: onRename,
    );
  }
}

/// Dashed "No plan yet" hint card + the tracked-time card — the agenda
/// tab is never a dead end on a day with recorded sessions.
class _AgendaEmptyState extends StatelessWidget {
  const _AgendaEmptyState({required this.actualBlocks});

  final List<TimeBlock> actualBlocks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsDashedBorder(
          color: tokens.colors.decorative.level02,
          radius: tokens.radii.l,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step6),
            child: Column(
              children: [
                Icon(
                  LottiIcons.twilight,
                  size: tokens.spacing.step6,
                  color: tokens.colors.text.lowEmphasis,
                ),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  context.messages.dailyOsNextAgendaNoPlanTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  context.messages.dailyOsNextAgendaNoPlanBody,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (actualBlocks.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step5),
          TimeSpentCard(blocks: actualBlocks),
        ],
      ],
    );
  }
}
