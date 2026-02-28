import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Displays aggregated token usage statistics for an agent, grouped by model.
class AgentTokenUsageSection extends ConsumerWidget {
  const AgentTokenUsageSection({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(agentTokenUsageSummariesProvider(agentId));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentTokenUsageHeading,
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
              return _TokenUsageTable(summaries: summaries);
            },
          ),
        ],
      ),
    );
  }
}

class _TokenUsageTable extends StatelessWidget {
  const _TokenUsageTable({required this.summaries});

  final List<AgentTokenUsageSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final numberFormat = NumberFormat.decimalPattern(locale);
    final messages = context.messages;
    final headerStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = context.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final modelStyle = context.textTheme.bodySmall;

    // Compute grand totals.
    final grandTotal = summaries.fold<AgentTokenUsageSummary>(
      const AgentTokenUsageSummary(modelId: ''),
      (acc, s) => AgentTokenUsageSummary(
        modelId: '',
        inputTokens: acc.inputTokens + s.inputTokens,
        outputTokens: acc.outputTokens + s.outputTokens,
        thoughtsTokens: acc.thoughtsTokens + s.thoughtsTokens,
        cachedInputTokens: acc.cachedInputTokens + s.cachedInputTokens,
        wakeCount: acc.wakeCount + s.wakeCount,
      ),
    );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
        5: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Header row
        TableRow(
          children: [
            _cell(messages.agentTokenUsageModel, headerStyle),
            _cell(messages.agentTokenUsageInputTokens, headerStyle),
            _cell(messages.agentTokenUsageOutputTokens, headerStyle),
            _cell(messages.agentTokenUsageThoughtsTokens, headerStyle),
            _cell(messages.agentTokenUsageCachedTokens, headerStyle),
            _cell(messages.agentTokenUsageWakeCount, headerStyle),
          ],
        ),
        // Model rows
        for (final summary in summaries)
          TableRow(
            children: [
              _cell(_shortModelName(summary.modelId), modelStyle),
              _cell(numberFormat.format(summary.inputTokens), valueStyle),
              _cell(numberFormat.format(summary.outputTokens), valueStyle),
              _cell(numberFormat.format(summary.thoughtsTokens), valueStyle),
              _cell(numberFormat.format(summary.cachedInputTokens), valueStyle),
              _cell(summary.wakeCount.toString(), valueStyle),
            ],
          ),
        // Grand total row (only if multiple models)
        if (summaries.length > 1)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colorScheme.outlineVariant),
              ),
            ),
            children: [
              _cell(messages.agentTokenUsageTotalTokens, headerStyle),
              _cell(numberFormat.format(grandTotal.inputTokens), valueStyle),
              _cell(numberFormat.format(grandTotal.outputTokens), valueStyle),
              _cell(numberFormat.format(grandTotal.thoughtsTokens), valueStyle),
              _cell(numberFormat.format(grandTotal.cachedInputTokens),
                  valueStyle),
              _cell(grandTotal.wakeCount.toString(), valueStyle),
            ],
          ),
      ],
    );
  }

  Widget _cell(String text, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Text(text, style: style),
    );
  }

  /// Shorten model IDs like "models/gemini-2.5-pro" to "gemini-2.5-pro".
  String _shortModelName(String modelId) {
    final lastSlash = modelId.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < modelId.length - 1) {
      return modelId.substring(lastSlash + 1);
    }
    return modelId;
  }
}
