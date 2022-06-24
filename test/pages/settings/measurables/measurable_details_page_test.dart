import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/measurables/measurable_details_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data.dart';
import '../../../widget_test_utils.dart';
import '../dashboards/dashboard_definition_test_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('MeasurableDetailsPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets('measurable details page is displayed with type water',
        (tester) async {
      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: MeasurableDetailsPage(dataType: measurableWater),
          ),
        ),
      );

      await tester.pumpAndSettle();
    });
  });
}
