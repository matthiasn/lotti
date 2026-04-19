import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/suggestion_row.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Single consolidated section on the task detail page: the running-state
/// header and narrative report (via [TaskAgentReportSection]) plus the
/// unified list of open proposals the user can confirm or reject inline.
class AgentSuggestionsPanel extends ConsumerWidget {
  const AgentSuggestionsPanel({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(unifiedSuggestionListProvider(taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskAgentReportSection(taskId: taskId),
        listAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list.open.isNotEmpty) _OpenSuggestionsList(open: list.open),
              if (list.activity.isNotEmpty)
                _RecentActivityStrip(activity: list.activity),
            ],
          ),
          error: (_, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OpenSuggestionsList extends ConsumerStatefulWidget {
  const _OpenSuggestionsList({required this.open});

  final List<PendingSuggestion> open;

  @override
  ConsumerState<_OpenSuggestionsList> createState() =>
      _OpenSuggestionsListState();
}

class _OpenSuggestionsListState extends ConsumerState<_OpenSuggestionsList> {
  bool _confirmAllBusy = false;

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ModernBaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.changeSetCardTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _PendingBadge(count: open.length),
                if (open.length > 1) ...[
                  const SizedBox(width: 8),
                  _ConfirmAllButton(
                    busy: _confirmAllBusy,
                    onPressed: _confirmAllBusy ? null : _confirmAll,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            for (final suggestion in open)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: SuggestionRow(suggestion: suggestion),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAll() async {
    if (_confirmAllBusy) return;
    setState(() => _confirmAllBusy = true);

    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);

    // Group by change set so we issue one confirmAll per set even when
    // multiple items on the same set appear in the unified open list.
    final distinctSets = <String, ChangeSetEntity>{
      for (final s in widget.open) s.changeSet.id: s.changeSet,
    };
    final agentIds = {for (final cs in distinctSets.values) cs.agentId};

    var anyFailed = false;
    try {
      for (final cs in distinctSets.values) {
        final results = await service.confirmAll(cs);
        if (results.any((r) => !r.success)) anyFailed = true;
      }
      notifier.notify(agentIds);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                anyFailed
                    ? context.messages.changeSetConfirmError
                    : context.messages.changeSetItemConfirmed,
              ),
            ),
          );
      }
    } catch (e) {
      developer.log('confirmAll failed: $e', name: 'AgentSuggestionsPanel');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(context.messages.changeSetConfirmError),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _confirmAllBusy = false);
    }
  }
}

class _ConfirmAllButton extends StatelessWidget {
  const _ConfirmAllButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.done_all, size: 16),
      label: Text(context.messages.changeSetConfirmAll),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.messages.changeSetPendingCount(count),
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Collapsed strip that shows the most recent resolved ledger entries so
/// the user can see what the agent has already confirmed, rejected, or
/// retracted without leaving the task detail.
///
/// Source order is authoritative: `activity` is produced by
/// [unifiedSuggestionListProvider] as the ledger's `resolved` list, which
/// is already newest-first — so the first three entries are the most
/// recent. When there are more than three resolved entries the strip
/// collapses to the top three with a "Show all" toggle to reveal the
/// full history; a long ledger stays readable without pushing the rest
/// of the task detail off-screen.
class _RecentActivityStrip extends StatefulWidget {
  const _RecentActivityStrip({required this.activity});

  final List<LedgerEntry> activity;

  static const int collapsedRowLimit = 3;

  @override
  State<_RecentActivityStrip> createState() => _RecentActivityStripState();
}

class _RecentActivityStripState extends State<_RecentActivityStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final total = activity.length;
    final canExpand = total > _RecentActivityStrip.collapsedRowLimit;
    final visible = _expanded
        ? activity
        : activity
              .take(_RecentActivityStrip.collapsedRowLimit)
              .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ModernBaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: canExpand
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 20,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.messages.agentSuggestionsActivityTitle,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (canExpand) ...[
                      Text(
                        _expanded
                            ? context.messages
                                  .agentSuggestionsActivityCountTotal(total)
                            : context.messages
                                  .agentSuggestionsActivityCountVisible(
                                    _RecentActivityStrip.collapsedRowLimit,
                                    total,
                                  ),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final entry in visible) _ActivityRow(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final reason = entry.reason?.trim();
    final hasReason = reason != null && reason.isNotEmpty;
    final verdictIcon = _verdictIcon(entry.status);
    final verdictColor = _verdictColor(context, entry.status);
    final verdictTooltip = _verdictTooltip(context, entry.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: verdictTooltip,
            child: Icon(verdictIcon, size: 18, color: verdictColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.humanSummary,
              style: context.textTheme.bodyMedium,
            ),
          ),
          if (hasReason) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: reason,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 4),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _verdictIcon(ChangeItemStatus status) => switch (status) {
    ChangeItemStatus.confirmed => Icons.check,
    ChangeItemStatus.rejected => Icons.close,
    ChangeItemStatus.retracted => Icons.undo,
    _ => Icons.history,
  };

  static Color _verdictColor(BuildContext context, ChangeItemStatus status) =>
      switch (status) {
        ChangeItemStatus.confirmed => Colors.green.shade700,
        ChangeItemStatus.rejected => context.colorScheme.error,
        ChangeItemStatus.retracted => context.colorScheme.primary,
        _ => context.colorScheme.onSurfaceVariant,
      };

  static String _verdictTooltip(
    BuildContext context,
    ChangeItemStatus status,
  ) => switch (status) {
    ChangeItemStatus.confirmed =>
      context.messages.agentSuggestionsActivityVerdictConfirmed,
    ChangeItemStatus.rejected =>
      context.messages.agentSuggestionsActivityVerdictRejected,
    ChangeItemStatus.retracted =>
      context.messages.agentSuggestionsActivityVerdictRetracted,
    _ => '',
  };
}
