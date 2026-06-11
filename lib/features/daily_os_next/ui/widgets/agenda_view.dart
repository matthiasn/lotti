import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_donut.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/time_spent_card.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';

/// Intent-first projection of the [DraftPlan]. One [AgendaCard] per
/// task, top stat strip with capacity donut + summary + category mix.
///
/// With no plan ([hasPlan] false) the strip stays honest — "No plan
/// yet" eyebrow, tracked-time summary, neutral donut — and the body
/// shows a dashed hint card plus the [TimeSpentCard] instead of a dead
/// empty state (handoff v2 item 2).
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
      padding: EdgeInsets.all(tokens.spacing.step6),
      // A reading-width column on desktop instead of a stretched phone
      // list; phones are unaffected.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatStrip(
                draft: draft,
                actualBlocks: actualBlocks,
                hasPlan: hasPlan,
              ),
              SizedBox(height: tokens.spacing.step4),
              for (final (index, item) in draft.agendaItems.indexed) ...[
                _LiveAgendaCard(
                  index: index + 1,
                  item: item,
                  whyReason: _whyReasonFor(item),
                  onTap: _taskTapFor(item),
                  onRename: onRenameItem == null
                      ? null
                      : (title) => onRenameItem(item, title),
                ),
                SizedBox(height: tokens.spacing.step3),
              ],
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

class _LiveAgendaCard extends ConsumerWidget {
  const _LiveAgendaCard({
    required this.index,
    required this.item,
    required this.whyReason,
    required this.onTap,
    required this.onRename,
  });

  final int index;
  final AgendaItem item;
  final String? whyReason;
  final VoidCallback? onTap;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskId = item.taskId;
    final task = taskId == null || !_canResolveLiveTaskTitles()
        ? null
        : ref.watch(taskLiveDataProvider(taskId)).value;
    final liveTitle = task?.data.title.trim();
    final coverArtId = task?.data.coverArtId?.trim();
    return AgendaCard(
      index: index,
      item: item,
      displayTitle: liveTitle == null || liveTitle.isEmpty ? null : liveTitle,
      whyReason: whyReason,
      coverArtId: coverArtId == null || coverArtId.isEmpty ? null : coverArtId,
      coverArtCropX: task?.data.coverArtCropX ?? 0.5,
      onTap: onTap,
      onRename: onRename,
    );
  }

  bool _canResolveLiveTaskTitles() {
    return getIt.isRegistered<JournalDb>() &&
        getIt.isRegistered<UpdateNotifications>();
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.draft,
    required this.actualBlocks,
    required this.hasPlan,
  });

  final DraftPlan draft;
  final List<TimeBlock> actualBlocks;
  final bool hasPlan;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final trackedMinutes = actualBlocks.totalMinutes;
    // One source of truth: the same per-category totals drive the legend,
    // the donut ring, and the headline minutes, so the three can never
    // tell different numerical stories (stored scheduledMinutes can drift
    // from the rendered blocks).
    final categoryTotals = categoryTotalsFor(draft);
    final committedMinutes = categoryTotals.fold<int>(
      0,
      (sum, entry) => sum + entry.minutes,
    );
    final ratio = CapacityDonut.ratioFor(
      committedMinutes,
      draft.capacityMinutes,
    );
    final overline = !hasPlan
        ? messages.dailyOsNextAgendaCapacityNoPlan
        : ratio < 0.9
        ? messages.dailyOsNextAgendaCapacityComfortable
        : ratio <= 1.0
        ? messages.dailyOsNextAgendaCapacityNearFull
        : messages.dailyOsNextAgendaCapacityOver;
    final summary = hasPlan
        ? messages.dailyOsNextAgendaSummary(
            formatMinutesCompact(committedMinutes),
            formatMinutesCompact(draft.capacityMinutes),
          )
        : messages.dailyOsNextAgendaNoPlanSummary(
            formatMinutesCompact(trackedMinutes),
          );

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Row(
        children: [
          CapacityDonut(
            scheduledMinutes: hasPlan ? committedMinutes : trackedMinutes,
            capacityMinutes: draft.capacityMinutes,
            neutral: !hasPlan,
            segments: [
              if (hasPlan)
                for (final entry in categoryTotals)
                  CapacityDonutSegment(
                    color: categoryColorFromHex(entry.category.colorHex),
                    minutes: entry.minutes,
                  ),
            ],
          ),
          SizedBox(width: tokens.spacing.step5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overline, style: calmEyebrowStyle(tokens)),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  summary,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step3),
                if (hasPlan)
                  _CategoryMix(entries: categoryTotals)
                else
                  _TrackedLegend(blocks: actualBlocks),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single neutral-teal legend chip for the no-plan strip: how much is
/// tracked and how much of it is done.
class _TrackedLegend extends StatelessWidget {
  const _TrackedLegend({required this.blocks});

  final List<TimeBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: tokens.spacing.step2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.interactive.enabled,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            context.messages.dailyOsNextAgendaTrackedLegend(
              formatMinutesCompact(blocks.totalMinutes),
              blocks.completedCount,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Per-category planned minutes (dropped blocks excluded), largest first —
/// drives both the legend rows and the donut's stacked ring so they can't
/// disagree.
List<({DayAgentCategory category, int minutes})> categoryTotalsFor(
  DraftPlan draft,
) {
  final totals = <String, ({DayAgentCategory category, int minutes})>{};
  for (final block in draft.blocks) {
    if (block.state == TimeBlockState.dropped) continue;
    final key = block.category.id;
    final existing = totals[key];
    totals[key] = (
      category: block.category,
      minutes: (existing?.minutes ?? 0) + block.duration.inMinutes,
    );
  }
  return totals.values.toList()..sort((a, b) => b.minutes.compareTo(a.minutes));
}

class _CategoryMix extends StatelessWidget {
  const _CategoryMix({required this.entries});

  /// Shared with the donut by the stat strip so legend and ring cannot
  /// disagree (and the per-build aggregation runs once, not twice).
  final List<({DayAgentCategory category, int minutes})> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final entry in entries)
          _CategoryLegend(category: entry.category, minutes: entry.minutes),
      ],
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.category, required this.minutes});

  final DayAgentCategory category;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = categoryColorFromHex(category.colorHex);
    // Bare dot + caption: the legend is reference information, not a set
    // of actions, so pill containers only added bulk to the stat card.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: tokens.spacing.step2,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        // Flexible + ellipsis so long category names survive large
        // accessibility text sizes inside the Wrap.
        // The duration is the data — protect it; the category label is
        // what truncates at large text scales.
        Flexible(
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
        Text(
          ' · ${formatMinutesCompact(minutes)}',
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
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
                  Icons.wb_twilight_rounded,
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
