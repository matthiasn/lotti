import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateMeasurablePage extends StatefulWidget {
  const CreateMeasurablePage({
    Key? key,
  }) : super(key: key);

  @override
  State<CreateMeasurablePage> createState() => _CreateMeasurablePageState();
}

class _CreateMeasurablePageState extends State<CreateMeasurablePage> {
  MeasurableDataType? _measurableDataType;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _measurableDataType = MeasurableDataType(
      id: uuid.v1(),
      displayName: '',
      version: 0,
      createdAt: now,
      updatedAt: now,
      unitName: '',
      description: '',
      vectorClock: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_measurableDataType == null) {
      return const SizedBox.shrink();
    }

    return MeasurableDetailsPage(dataType: _measurableDataType!);
  }
}
