import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/state/wake_run_chart_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_mttr_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_sparkline_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_version_chart.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/mini_charts/evolution_wake_bar_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A 2x2 grid of mini performance charts for the evolution dashboard.
///
/// Watches [templateWakeRunTimeSeriesProvider] for wake run data and
/// [templateTaskResolutionTimeSeriesProvider] for task resolution MTTR data.
class EvolutionChartsSection extends ConsumerWidget {
  const EvolutionChartsSection({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeSeriesAsync =
        ref.watch(templateWakeRunTimeSeriesProvider(templateId));
    final resolutionAsync =
        ref.watch(templateTaskResolutionTimeSeriesProvider(templateId));

    return timeSeriesAsync.when(
      data: (timeSeries) => _buildCharts(
        context,
        timeSeries,
        resolutionAsync.value,
      ),
      loading: SizedBox.shrink,
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCharts(
    BuildContext context,
    WakeRunTimeSeries timeSeries,
    TaskResolutionTimeSeries? resolution,
  ) {
    final daily = timeSeries.dailyBuckets;
    final versions = timeSeries.versionBuckets;
    final resolutionBuckets = resolution?.dailyBuckets ?? [];

    // Don't render anything if there's no data at all.
    if (daily.isEmpty && versions.isEmpty && resolutionBuckets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniChartCard(
                  label: context.messages.agentEvolutionChartSuccessRateTrend,
                  child: EvolutionSparklineChart(buckets: daily),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniChartCard(
                  label: context.messages.agentEvolutionChartWakeHistory,
                  child: EvolutionWakeBarChart(buckets: daily),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniChartCard(
                  label: context.messages.agentEvolutionChartVersionPerformance,
                  child: EvolutionVersionChart(buckets: versions),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniChartCard(
                  label: context.messages.agentEvolutionChartMttrTrend,
                  child: EvolutionMttrChart(buckets: resolutionBuckets),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lightweight card wrapper for a mini chart with a label.
class _MiniChartCard extends StatelessWidget {
  const _MiniChartCard({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
