import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';

import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

class _NoopLabelsListController extends LabelsListController {
  @override
  AsyncValue<List<LabelDefinition>> build() {
    return const AsyncValue<List<LabelDefinition>>.data(<LabelDefinition>[]);
  }

  @override
  Future<void> deleteLabel(String id) async {
    // succeed
  }
}

class _ThrowingLabelsListController extends LabelsListController {
  @override
  AsyncValue<List<LabelDefinition>> build() {
    return const AsyncValue<List<LabelDefinition>>.data(<LabelDefinition>[]);
  }

  @override
  Future<void> deleteLabel(String id) async {
    throw Exception('Boom');
  }
}

Widget _buildPage({
  required List<LabelDefinition> labels,
  required LabelsListController Function() controllerFactory,
}) {
  return ProviderScope(
    overrides: [
      labelsStreamProvider.overrideWith((ref) => Stream.value(labels)),
      labelUsageStatsProvider
          .overrideWith((ref) => Stream.value(const <String, int>{})),
      labelsListControllerProvider.overrideWith(controllerFactory),
    ],
    child: makeTestableWidgetWithScaffold(const LabelsListPage()),
  );
}

void main() {
  testWidgets('shows actions menu and deletes label successfully',
      (tester) async {
    await tester.pumpWidget(_buildPage(
      labels: [testLabelDefinition1],
      controllerFactory: _NoopLabelsListController.new,
    ));
    await tester.pumpAndSettle();

    // Open actions menu via tooltip
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();

    // Tap Delete in the menu
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm deletion in dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Expect success snackbar text
    expect(find.textContaining('Label "Urgent" deleted'), findsOneWidget);
  });

  testWidgets('shows error snackbar when deletion fails', (tester) async {
    await tester.pumpWidget(_buildPage(
      labels: [testLabelDefinition1],
      controllerFactory: _ThrowingLabelsListController.new,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Expect error snackbar prefix (Error: …)
    expect(find.textContaining('Error:'), findsOneWidget);
  });
}
