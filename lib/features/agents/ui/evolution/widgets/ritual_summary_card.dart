import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:material_ui/material_ui.dart';

/// What the agent has been doing since the last 1-on-1.
///
/// The heading names the window the numbers cover, which is the one thing a
/// reader needs to interpret them. It previously read *Performance* over a
/// subtitle that was printed verbatim a second time in the page's hero.
class RitualSummaryCard extends StatelessWidget {
  const RitualSummaryCard({
    required this.metrics,
    this.compact = false,
    super.key,
  });

  final RitualSummaryMetrics metrics;

  /// Tightens the internal rhythm for embedded placements.
  final bool compact;

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = compact ? tokens.spacing.step4 : tokens.spacing.step5;

    return ModernBaseCard(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentRitualSinceLastHeading,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: spacing),
          Wrap(
            spacing: tokens.spacing.step6,
            runSpacing: tokens.spacing.step5,
            children: [
              _Metric(
                label: context.messages.agentRitualSummaryWakesSinceLast,
                value: _numberFormat.format(metrics.wakesSinceLastSession),
              ),
              _Metric(
                label: context.messages.agentRitualSummaryTokensSinceLast,
                value: _numberFormat.format(
                  metrics.totalTokenUsageSinceLastSession,
                ),
              ),
              _Metric(
                label: context.messages.agentTemplateMetricsTotalWakes,
                value: _numberFormat.format(metrics.lifetimeWakeCount),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Text(
            context.messages.agentRitualSummaryWakeHistory30Days,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          EvolutionWakeActivityChart(
            buckets: metrics.dailyWakeCounts,
          ),
        ],
      ),
    );
  }
}

/// One figure over its label. Deliberately uncontained: three boxed tiles
/// inside a card read as three cards, and the middle label wrapped to two
/// lines while its neighbours did not, which is what made the row look ragged.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
