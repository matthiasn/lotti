import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('MeasurementSummary Widget Tests -', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<HealthImport>(mockHealthImport);

      when(
        () => mockEntitiesCacheService.getDataTypeById(
          measurableCoverage.id,
        ),
      ).thenAnswer((_) => measurableCoverage);
    });
    tearDown(getIt.reset);

    testWidgets('summary is rendered with title', (tester) async {
      when(
        () => mockJournalDb.watchMeasurableDataTypeById(measurableCoverage.id),
      ).thenAnswer(
        (_) => Stream<MeasurableDataType>.fromIterable([
          measurableCoverage,
        ]),
      );

      when(
        () => mockJournalDb.watchMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: measurableCoverage.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testMeasuredCoverageEntry],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasuredCoverageEntry),
        ),
      );

      await tester.pumpAndSettle();

      // charts display expected titles
      expect(find.text('Coverage'), findsOneWidget);

      // entry value is displayed
      expect(find.text('Coverage: 55 %'), findsOneWidget);
    });
  });
}
