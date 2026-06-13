import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';

import '../../../../widget_test_utils.dart';

Widget hBuildPage({
  required List<LabelDefinition> labels,
  Map<String, int> usageCounts = const {},
}) {
  return ProviderScope(
    overrides: [
      labelsStreamProvider.overrideWith((ref) => Stream.value(labels)),
      labelUsageStatsProvider.overrideWith((ref) => Stream.value(usageCounts)),
    ],
    child: makeTestableWidgetWithScaffold(const LabelsListPage()),
  );
}
