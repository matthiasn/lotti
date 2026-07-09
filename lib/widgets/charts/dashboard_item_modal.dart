import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/aggregation_label.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class DashboardItemModal extends StatelessWidget {
  const DashboardItemModal({
    required this.index,
    required this.item,
    required this.updateItemFn,
    required this.chartTitle,
    super.key,
  });

  final DashboardMeasurementItem item;
  final int index;
  final String chartTitle;
  final void Function(DashboardItem item, int index) updateItemFn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          chartTitle,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: spacing.step2),
        Text(
          context.messages.dashboardAggregationApplyImmediately,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: spacing.step4),
        Wrap(
          spacing: spacing.step2,
          runSpacing: spacing.step2,
          children: AggregationType.values.map((aggregationType) {
            return DesignSystemChip(
              label: aggregationTypeLabel(context.messages, aggregationType),
              selected: aggregationType == item.aggregationType,
              size: DesignSystemChipSize.touch,
              onPressed: () {
                updateItemFn(
                  item.copyWith(aggregationType: aggregationType),
                  index,
                );
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
