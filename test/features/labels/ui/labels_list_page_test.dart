import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';

import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

Widget _buildPage({
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

void main() {
  testWidgets('renders labels with usage stats', (tester) async {
    await tester.pumpWidget(
      _buildPage(
        labels: [testLabelDefinition1, testLabelDefinition2],
        usageCounts: {'label-1': 3, 'label-2': 1},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Urgent'), findsWidgets);
    expect(find.text('Backlog'), findsWidgets);
    expect(find.textContaining('Used on 3 tasks'), findsOneWidget);
    expect(find.textContaining('Used on 1 task'), findsOneWidget);
  });

  testWidgets('filters list based on search query', (tester) async {
    await tester.pumpWidget(
      _buildPage(labels: [testLabelDefinition1, testLabelDefinition2]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField, skipOffstage: false).first,
      'backlog',
    );
    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsWidgets);
    expect(find.text('Urgent'), findsNothing);
  });
}
