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

  @override
  Widget build(BuildContext context) {
    Future<void> captureData() async {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        builder: (_) {
          return MeasurementDialog(
            measurableId: measurableDataType.id,
          );
        },
        padding: EdgeInsets.zero,
        navBarHeight: 5,
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
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width / 2,
              ),
              child: Text(
                '${measurableDataType.displayName}'
                '${aggregationType != AggregationType.none ? ' ' : ''}'
                '${aggregationLabel(aggregationType)}',
                style: chartTitleStyle,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
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
