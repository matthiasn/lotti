import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  setUp(() {
    if (!getIt.isRegistered<EntitiesCacheService>()) {
      getIt
          .registerSingleton<EntitiesCacheService>(_MockEntitiesCacheService());
    }
  });

  tearDown(() async {
    if (getIt.isRegistered<EntitiesCacheService>()) {
      await getIt.reset(dispose: false);
    }
  });
  testWidgets('list shows no actions menu; chevron present', (tester) async {
    await tester.pumpWidget(_buildPage(
      labels: [testLabelDefinition1],
      controllerFactory: _NoopLabelsListController.new,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
  });

  testWidgets('list does not trigger delete dialog', (tester) async {
    await tester.pumpWidget(_buildPage(
      labels: [testLabelDefinition1],
      controllerFactory: _ThrowingLabelsListController.new,
    ));
    await tester.pumpAndSettle();

    // There is no delete affordance on the list anymore; ensure no dialog is shown.
    expect(find.byType(AlertDialog), findsNothing);
  });
}
