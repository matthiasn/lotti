import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_table_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart'
    show formatShare;
import 'package:lotti/l10n/app_localizations_context.dart';

/// Environmental impact by serving location.
///
/// Rows come from provider-reported data-centre ids. The left column shows the
/// inferred country code when the id starts with an ISO-3166-like prefix, and
/// keeps the raw data-centre id as the detail line when it is more specific.
class ImpactLocationTable extends StatelessWidget {
  const ImpactLocationTable({required this.entries, super.key});

  final List<MapEntry<ConsumptionLocationKey, ConsumptionLocationMetrics>>
  entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final messages = context.messages;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showCarbon = constraints.maxWidth >= 400;
        final showRenewable = constraints.maxWidth >= 300;

        return ImpactTableCard(
          title: messages.aiImpactLocationTitle,
          childrenBuilder: (context, headerStyle, numberStyle) => [
            _LocationTableRowLayout(
              showCarbon: showCarbon,
              showRenewable: showRenewable,
              location: Text(
                messages.aiImpactLocationColumn,
                style: headerStyle,
              ),
              energy: Text(
                messages.aiImpactKpiEnergy,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              carbon: Text(
                messages.aiImpactKpiCarbon,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              renewable: Text(
                messages.aiImpactRenewableColumn,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
            ),
            Divider(height: 1, color: tokens.colors.decorative.level01),
            for (final entry in entries)
              _LocationRow(
                entry: entry,
                numberStyle: numberStyle,
                showCarbon: showCarbon,
                showRenewable: showRenewable,
              ),
          ],
        );
      },
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.entry,
    required this.numberStyle,
    required this.showCarbon,
    required this.showRenewable,
  });

  final MapEntry<ConsumptionLocationKey, ConsumptionLocationMetrics> entry;
  final TextStyle numberStyle;
  final bool showCarbon;
  final bool showRenewable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final country = entry.key.countryCode ?? messages.aiImpactLocationUnknown;
    final dataCenter = entry.key.dataCenter;
    final renewablePercent = entry.value.renewablePercent;

    return _LocationTableRowLayout(
      showCarbon: showCarbon,
      showRenewable: showRenewable,
      location: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            country,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (dataCenter != country) ...[
            SizedBox(height: tokens.spacing.step1),
            Text(
              dataCenter,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      energy: Text(
        formatEnergyKwh(entry.value.metrics.energyKwh),
        style: numberStyle,
        textAlign: TextAlign.right,
      ),
      carbon: Text(
        formatCarbonGrams(entry.value.metrics.carbonGCo2),
        style: numberStyle,
        textAlign: TextAlign.right,
      ),
      renewable: Text(
        renewablePercent == null
            ? messages.aiConsumptionMetricsNotReported
            : formatShare(renewablePercent / 100),
        style: numberStyle.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
      ),
    );
  }
}

/// Fixed columns shared by the header and rows:
/// location · energy · [carbon] · [renewable].
class _LocationTableRowLayout extends StatelessWidget {
  const _LocationTableRowLayout({
    required this.location,
    required this.energy,
    required this.carbon,
    required this.renewable,
    required this.showCarbon,
    required this.showRenewable,
  });

  final Widget location;
  final Widget energy;
  final Widget carbon;
  final Widget renewable;
  final bool showCarbon;
  final bool showRenewable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final numberColumnWidth = tokens.spacing.step10;
    final renewableColumnWidth = tokens.spacing.step12;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Row(
        children: [
          Expanded(child: location),
          SizedBox(width: numberColumnWidth, child: energy),
          if (showCarbon) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: carbon),
          ],
          if (showRenewable) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: renewableColumnWidth, child: renewable),
          ],
        ],
      ),
    );
  }
}
