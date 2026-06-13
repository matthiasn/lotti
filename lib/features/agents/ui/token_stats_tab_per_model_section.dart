import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/ui/agent_token_usage_section.dart';
import 'package:lotti/features/agents/ui/token_stats_tab.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class PerModelChartsSection extends StatelessWidget {
  const PerModelChartsSection({required this.byModelAsync, super.key});

  final AsyncValue<Map<String, List<DailyTokenUsage>>> byModelAsync;

  @override
  Widget build(BuildContext context) {
    final byModel = byModelAsync.value;
    if (byModel == null || byModel.length <= 1) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in byModel.entries) ...[
            _ModelChartCard(modelId: entry.key, days: entry.value),
            SizedBox(height: tokens.spacing.step3),
          ],
        ],
      ),
    );
  }
}

class _ModelChartCard extends StatefulWidget {
  const _ModelChartCard({
    required this.modelId,
    required this.days,
  });

  final String modelId;
  final List<DailyTokenUsage> days;

  @override
  State<_ModelChartCard> createState() => _ModelChartCardState();
}

class _ModelChartCardState extends State<_ModelChartCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final totalTokens = widget.days.fold<int>(0, (s, d) => s + d.totalTokens);

    final shortName = shortModelName(widget.modelId);

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortName,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatTokenCount(totalTokens),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: tokens.spacing.step1),
              Text(
                context.messages.agentStatsTokensUnit,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          InteractiveWeeklyChart(
            days: widget.days,
            selectedIndex: _selectedIndex,
            onBarTap: (i) => setState(
              () => _selectedIndex = _selectedIndex == i ? null : i,
            ),
          ),
          if (_selectedIndex != null && _selectedIndex! < widget.days.length)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step3),
              child: SelectedDayDetail(
                day: widget.days[_selectedIndex!],
              ),
            ),
        ],
      ),
    );
  }
}
