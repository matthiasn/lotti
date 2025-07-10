import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_details_page.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:showcaseview/showcaseview.dart';

class CreateMeasurablePage extends StatelessWidget {
  CreateMeasurablePage({super.key});

  final _measurableDataType = MeasurableDataType(
    id: uuid.v1(),
    displayName: '',
    version: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    unitName: '',
    description: '',
    vectorClock: null,
  );

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (builder) => MeasurableDetailsPage(
        dataType: _measurableDataType,
      ),
    );
  }
}
