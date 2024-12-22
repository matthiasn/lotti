import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence/persistence_logic.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../utils/measurable_utils_test.dart';
import '../../widget_test_utils.dart';

class MeasurementMock extends Mock {
  Future<void> saveMeasurement({
    required MeasurableDataType measurableDataType,
    required DateTime measurementTime,
    num? value,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(FakeMeasurementData());
  final mock = MeasurementMock();

  group(' - ', () {
    final mockJournalDb = MockJournalDb();
    final mockPersistenceLogic = MockPersistenceLogic();

    when(
      () => mockJournalDb.watchMeasurementsByType(
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
        type: measurableWater.id,
      ),
    ).thenAnswer(
      (_) => Stream<List<JournalEntity>>.fromIterable([
        testMeasurements(
          <num>[111, 500, 250, 500, 250, 500, 250, 500, 100, 100, 50],
        ),
      ]),
    );

    Future<void> mockSaveMeasurement() => mock.saveMeasurement(
          measurableDataType: measurableWater,
          measurementTime: any(
            named: 'measurementTime',
            that: const TypeMatcher<DateTime>(),
          ),
          value: 500,
        );
    when(mockSaveMeasurement).thenAnswer((_) async => true);

    setUp(() async {
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets(
      '',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MeasurementSuggestions(
              measurableDataType: measurableWater,
              saveMeasurement: mock.saveMeasurement,
              measurementTime: DateTime.now(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('500'), findsOneWidget);
        expect(find.text('250'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);

        await tester.tap(find.text('500'));
        await tester.pumpAndSettle();

        verify(mockSaveMeasurement).called(1);
      },
    );
  });
}
