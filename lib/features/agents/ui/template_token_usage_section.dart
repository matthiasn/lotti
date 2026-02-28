import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays aggregate token usage statistics for a template across all
/// instances, plus a per-instance breakdown with expansion tiles.
class TemplateTokenUsageSection extends ConsumerWidget {
  const TemplateTokenUsageSection({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync =
        ref.watch(templateTokenUsageSummariesProvider(templateId));
    final breakdownAsync =
        ref.watch(templateInstanceTokenBreakdownProvider(templateId));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AggregateSection(summariesAsync: summariesAsync),
          const SizedBox(height: AppTheme.cardPadding),
          _InstanceBreakdownSection(breakdownAsync: breakdownAsync),
        ],
      ),
    );
  }
}

class _AggregateSection extends StatelessWidget {
  const _AggregateSection({required this.summariesAsync});

  final AsyncValue<List<AgentTokenUsageSummary>> summariesAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateAggregateTokenUsageHeading,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        summariesAsync.when(
          loading: () => const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, _) => Text(
            context.messages.agentTokenUsageErrorLoading(error.toString()),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
          data: (summaries) {
            if (summaries.isEmpty) {
              return Text(
                context.messages.agentTokenUsageEmpty,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return TokenUsageTable(summaries: summaries);
          },
        ),
      ],
    );
  }
}

class _InstanceBreakdownSection extends StatelessWidget {
  const _InstanceBreakdownSection({required this.breakdownAsync});

  final AsyncValue<List<InstanceTokenBreakdown>> breakdownAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentTemplateInstanceBreakdownHeading,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        breakdownAsync.when(
          loading: () => const SizedBox(
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, _) => Text(
            context.messages.agentTokenUsageErrorLoading(error.toString()),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
          data: (breakdowns) {
            if (breakdowns.isEmpty) {
              return Text(
                context.messages.agentTokenUsageEmpty,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: [
                for (final breakdown in breakdowns)
                  _InstanceExpansionTile(breakdown: breakdown),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InstanceExpansionTile extends StatelessWidget {
  const _InstanceExpansionTile({required this.breakdown});

  final InstanceTokenBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor) = switch (breakdown.lifecycle) {
      AgentLifecycle.created => (
          context.messages.agentLifecycleCreated,
          context.colorScheme.outline,
        ),
      AgentLifecycle.active => (
          context.messages.agentLifecycleActive,
          context.colorScheme.primary,
        ),
      AgentLifecycle.dormant => (
          context.messages.agentLifecycleDormant,
          context.colorScheme.tertiary,
        ),
      AgentLifecycle.destroyed => (
          context.messages.agentLifecycleDestroyed,
          context.colorScheme.error,
        ),
    };

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      title: Row(
        children: [
          Expanded(
            child: Text(
              breakdown.displayName,
              style: context.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.spacingXSmall),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badgeLabel,
              style: context.textTheme.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      children: [
        if (breakdown.summaries.isEmpty)
          Text(
            context.messages.agentTokenUsageEmpty,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          )
        else
          TokenUsageTable(summaries: breakdown.summaries),
      ],
    );
  }
}
