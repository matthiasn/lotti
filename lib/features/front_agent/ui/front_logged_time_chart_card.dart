import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/state/front_logged_time_providers.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card_charts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Low enough to keep her reply a reply; the expanded view has room.
const double _inlineChartHeight = 140;

/// The chart under her answer to a time question: the Insights page's
/// stacked bars — one per day, or per hour for a single day — each split
/// into the categories' colours, a tap on a bar reading out every category
/// and its time. The expand action opens the Insights chart card over the
/// conversation.
///
/// Drawn from [chart] when shown, never from figures the reply stored; the
/// height is held while it reads so her bubble does not jump, and nothing
/// is drawn once the time it charted is gone.
class FrontLoggedTimeChartCard extends ConsumerWidget {
  const FrontLoggedTimeChartCard({required this.chart, super.key});

  final FrontLoggedTimeChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(frontLoggedTimeChartProvider(chart)).value;
    if (data == null) return const SizedBox(height: _inlineChartHeight);
    if (data.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final resolver = _resolver(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _inlineChartHeight,
          child: StackedBarChart(chartData: data, resolver: resolver),
        ),
        SizedBox(height: tokens.spacing.step3),
        Row(
          children: [
            Expanded(
              // One category is named by its colour and her words already.
              child: data.seriesKeys.length > 1
                  ? ChartLegend(
                      seriesKeys: data.seriesKeys,
                      rolledUpCount: data.rolledUpCount,
                      resolver: resolver,
                    )
                  : const SizedBox.shrink(),
            ),
            DesignSystemIconAction(
              icon: LottiIcons.expandFull,
              tooltip: context.messages.frontLoggedTimeExpand,
              onPressed: () => ModalUtils.showSinglePageModal<void>(
                context: context,
                title: _rangeLabel(context, chart),
                builder: (_) => _ExpandedChart(chart: chart),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The Insights chart card, with its per-day and running-total views, for
/// the same days.
class _ExpandedChart extends ConsumerWidget {
  const _ExpandedChart({required this.chart});

  final FrontLoggedTimeChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(frontLoggedTimeChartProvider(chart)).value;
    if (data == null) return const SizedBox.shrink();
    return InsightsChartCard(
      chartData: data,
      resolver: _resolver(context, ref),
    );
  }
}

/// Names and colours as the Insights page resolves them.
InsightsCategoryResolver _resolver(BuildContext context, WidgetRef ref) {
  final messages = context.messages;
  final categories =
      ref.watch(categoriesStreamProvider).value ?? const <CategoryDefinition>[];
  return InsightsCategoryResolver(
    categoriesById: {for (final c in categories) c.id: c},
    uncategorizedLabel: messages.insightsUncategorized,
    otherLabel: messages.insightsOtherCategories,
    deletedLabel: messages.insightsDeletedCategory,
  );
}

/// `Nov 2 – Nov 8`, or the one day, in the device's locale.
String _rangeLabel(BuildContext context, FrontLoggedTimeChart chart) {
  final format = DateFormat.MMMd(Localizations.localeOf(context).toString());
  final from = format.format(dayStart(chart.range.startDay));
  final through = format.format(dayStart(chart.range.endDayExclusive - 1));
  return from == through ? from : '$from – $through';
}
