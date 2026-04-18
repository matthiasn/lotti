import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/suggestion_row.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Single consolidated section on the task detail page that surfaces
/// everything the agent has to say about a task: the running-state header
/// and narrative report (via [TaskAgentReportSection]), plus the unified
/// list of open proposals the user can confirm or reject inline.
///
/// Replaces the pre-consolidation layout where `TaskAgentReportSection`
/// and `ChangeSetSummaryCard` rendered as two adjacent but disconnected
/// cards. The user now sees a single, cohesive section driven by the
/// proposal ledger.
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
          data: (list) => list.open.isEmpty
              ? const SizedBox.shrink()
              : _OpenSuggestionsList(open: list.open),
          error: (_, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OpenSuggestionsList extends StatelessWidget {
  const _OpenSuggestionsList({required this.open});

  final List<PendingSuggestion> open;

  @override
  Widget build(BuildContext context) {
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
