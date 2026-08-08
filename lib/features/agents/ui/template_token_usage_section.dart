import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Aggregate token usage for a template, across every instance.
///
/// The per-instance breakdown that used to sit under this was a `Column` of
/// expansion tiles built eagerly for every instance a template has ever
/// spawned — one per task — showing the template's own name on each row and
/// nothing that identified the instance. The instance list below it replaces
/// that: same totals, lazily built, keyed by the task the agent is bound to.
class TemplateTokenUsageSection extends ConsumerWidget {
  const TemplateTokenUsageSection({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(
      templateTokenUsageSummariesProvider(templateId),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.spacingSmall,
      ),
      child: _AggregateSection(summariesAsync: summariesAsync),
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
