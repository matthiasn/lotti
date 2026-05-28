import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/capacity_meter.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';

/// Intent-first projection of the [DraftPlan]. One [AgendaCard] per
/// task, top stat strip with capacity meter + summary + category mix.
class AgendaView extends StatelessWidget {
  const AgendaView({required this.draft, super.key});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatStrip(draft: draft),
          SizedBox(height: tokens.spacing.step4),
          for (final (index, item) in draft.agendaItems.indexed) ...[
            _LiveAgendaCard(
              index: index + 1,
              item: item,
              whyReason: _whyReasonFor(item),
              onTap: _taskTapFor(item),
            ),
            SizedBox(height: tokens.spacing.step3),
          ],
          if (draft.agendaItems.isEmpty) const _AgendaEmptyState(),
        ],
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
  });

  final int index;
  final AgendaItem item;
  final String? whyReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskId = item.taskId;
    final task = taskId == null || !_canResolveLiveTaskTitles()
        ? null
        : ref.watch(taskLiveDataProvider(taskId)).value;
    final liveTitle = task?.data.title.trim();
    return AgendaCard(
      index: index,
      item: item,
      displayTitle: liveTitle == null || liveTitle.isEmpty ? null : liveTitle,
      whyReason: whyReason,
      onTap: onTap,
    );
  }

  bool _canResolveLiveTaskTitles() {
    return getIt.isRegistered<JournalDb>() &&
        getIt.isRegistered<UpdateNotifications>();
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ratio = draft.capacityMinutes == 0
        ? 0.0
        : draft.scheduledMinutes / draft.capacityMinutes;
    final overline = ratio < 0.9
        ? context.messages.dailyOsNextAgendaCapacityComfortable
        : ratio <= 1.0
        ? context.messages.dailyOsNextAgendaCapacityNearFull
        : context.messages.dailyOsNextAgendaCapacityOver;

    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            overline,
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            context.messages.dailyOsNextAgendaSummary(
              _formatHours(draft.scheduledMinutes),
              _formatHours(draft.capacityMinutes),
            ),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          CapacityMeter(
            scheduledMinutes: draft.scheduledMinutes,
            capacityMinutes: draft.capacityMinutes,
          ),
          SizedBox(height: tokens.spacing.step3),
          _CategoryMix(draft: draft),
        ],
      ),
    );
  }

  String _formatHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _CategoryMix extends StatelessWidget {
  const _CategoryMix({required this.draft});

  final DraftPlan draft;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
    if (totals.isEmpty) return const SizedBox.shrink();
    final entries = totals.values.toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
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
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final duration = m == 0 ? '${h}h' : '${h}h ${m}m';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spacing.step2),
        Text(
          '${category.name} · $duration',
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

class _AgendaEmptyState extends StatelessWidget {
  const _AgendaEmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step6),
      child: Text(
        context.messages.dailyOsNextAgendaEmpty,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
