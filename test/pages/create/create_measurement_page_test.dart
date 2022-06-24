import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/create_measurement_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../test_data.dart';
import '../../widget_test_utils.dart';
import '../settings/dashboards/dashboard_definition_test_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('CreateMeasurementPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeMeasurementData());
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

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(
        () => mockJournalDb.watchMeasurableDataTypeById(
          '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableWater,
        ]),
      );

      when(
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);
    });
    tearDown(getIt.reset);

    testWidgets(
        'create measurement page is displayed with measurable type water, '
        'then data entry and tap save button (becomes visible after data entry)',
        (tester) async {
      Future<bool> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1500,
                maxWidth: 800,
              ),
              child: CreateMeasurementPage(
                selectedId: measurableWater.id,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(measurableWater.displayName),
        findsOneWidget,
      );

      final valueFieldFinder = find.byKey(const Key('measurement_value_field'));
      final saveButtonFinder = find.byKey(const Key('measurement_save'));

      expect(valueFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(valueFieldFinder, '1000');
      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      verify(mockCreateMeasurementEntry).called(1);
    });

    testWidgets(
        'create measurement page is displayed with empty measurable type',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1500,
                maxWidth: 800,
              ),
              child: const CreateMeasurementPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Select Measurement Type'),
        findsOneWidget,
      );
    });

    testWidgets(
        'create measurement page is displayed with selected measurable type '
        'if only one exists', (tester) async {
      when(mockJournalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          [measurableWater]
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 600,
              maxWidth: 800,
            ),
            child: const CreateMeasurementPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Water'),
        findsOneWidget,
      );
    });
  });
}
