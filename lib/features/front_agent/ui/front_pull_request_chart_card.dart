import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card_charts.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/state/front_pull_request_providers.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity;
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the chart counts per day: pull requests opened, or their lines.
enum FrontPullRequestMetric { opened, additions, deletions }

/// The charts under her answer to a pull request question: one bar per day
/// of what was opened — the pull requests, or the lines they added or
/// deleted — or the running total of it, the AI consumption dashboard's
/// bars and area, so they read as that page's siblings. A tap on a bar or
/// a point reads out its day and value.
///
/// Drawn from [chart] when shown, never from figures the reply stored; the
/// height is held while it reads so her bubble does not jump, and nothing
/// is drawn once no pull request it counted is left.
class FrontPullRequestChartCard extends ConsumerStatefulWidget {
  const FrontPullRequestChartCard({required this.chart, super.key});

  final FrontPullRequestChart chart;

  @override
  ConsumerState<FrontPullRequestChartCard> createState() =>
      _FrontPullRequestChartCardState();
}

class _FrontPullRequestChartCardState
    extends ConsumerState<FrontPullRequestChartCard> {
  FrontPullRequestMetric _metric = FrontPullRequestMetric.opened;
  bool _cumulative = false;

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(frontPullRequestChartProvider(widget.chart)).value;
    if (days == null) return const SizedBox(height: ChartSizes.inline);
    if (days.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final messages = context.messages;
    final labels = {
      FrontPullRequestMetric.opened: messages.githubPullRequestsTitle,
      FrontPullRequestMetric.additions: messages.frontPullRequestsLinesAdded,
      FrontPullRequestMetric.deletions: messages.frontPullRequestsLinesDeleted,
    };
    // Each metric is its own series, keyed by its label so a tooltip names
    // it, and keeps its own colour whichever is shown.
    final resolver = PaletteSeriesResolver(
      orderedKeys: [for (final metric in labels.keys) labels[metric]!],
      unknownLabel: labels[_metric]!,
      otherLabel: labels[_metric]!,
    );
    final data = ImpactChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: days.days,
      seriesKeys: [labels[_metric]],
      values: [
        [
          for (final value in switch (_metric) {
            FrontPullRequestMetric.opened => days.opened,
            FrontPullRequestMetric.additions => days.additions,
            FrontPullRequestMetric.deletions => days.deletions,
          })
            value.toDouble(),
        ],
      ],
    );
    // A running total needs two days that have begun to draw a line.
    final canAccumulate = elapsedImpactBucketCount(data) >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.spacing.step3,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DsSegmentedToggle<FrontPullRequestMetric>(
            selected: _metric,
            onChanged: (metric) => setState(() => _metric = metric),
            segments: [
              for (final MapEntry(key: metric, value: label) in labels.entries)
                DsSegment(metric, label),
            ],
          ),
        ),
        SizedBox(
          height: ChartSizes.inline,
          child: _cumulative && canAccumulate
              ? ImpactStackedArea(
                  data: data,
                  resolver: resolver,
                  metric: ConsumptionMetric.requests,
                )
              : ImpactStackedBars(
                  data: data,
                  resolver: resolver,
                  metric: ConsumptionMetric.requests,
                ),
        ),
        if (canAccumulate)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DsSegmentedToggle<bool>(
              selected: _cumulative,
              onChanged: (cumulative) =>
                  setState(() => _cumulative = cumulative),
              segments: [
                DsSegment(false, messages.insightsChartPerDay),
                DsSegment(true, messages.insightsChartRunningTotal),
              ],
            ),
          ),
      ],
    );
  }
}
