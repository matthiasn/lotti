import 'dart:core';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class MeasurablesChartInfoWidget extends StatelessWidget {
  const MeasurablesChartInfoWidget(
    this.measurableDataType, {
    required this.aggregationType,
    required this.enableCreate,
    super.key,
  });

  final MeasurableDataType measurableDataType;
  final AggregationType aggregationType;
  final bool enableCreate;

  Widget _buildModalTitle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          measurableDataType.displayName,
          style: context.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        if (measurableDataType.description.isNotEmpty)
          Text(
            measurableDataType.description,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<void> captureData() async {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        titleWidget: _buildModalTitle(context),
        builder: (_) {
          return MeasurementDialog(
            measurableId: measurableDataType.id,
          );
        },
      );
    }

    return Positioned(
      top: 0,
      left: 20,
      child: SizedBox(
        width: max(MediaQuery.of(context).size.width, 300) - 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${measurableDataType.displayName}'
                    '${aggregationType != AggregationType.none ? ' ' : ''}'
                    '${aggregationLabel(aggregationType)}',
                    style: chartTitleStyle,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  if (measurableDataType.description.isNotEmpty)
                    Text(
                      measurableDataType.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            const Spacer(),
            if (enableCreate)
              IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: captureData,
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

String aggregationLabel(AggregationType? aggregationType) {
  if (aggregationType == null) {
    return '';
  }
  return aggregationType != AggregationType.none
      ? '[${EnumToString.convertToString(aggregationType)}]'
      : '';
}
