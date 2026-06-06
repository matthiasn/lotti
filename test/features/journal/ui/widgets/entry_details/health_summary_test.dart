import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/health_summary.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockHealthImport mockHealthImport;

  setUp(() async {
    mockJournalDb = MockJournalDb();
    mockHealthImport = MockHealthImport();

    when(
      () => mockJournalDb.getQuantitativeByType(
        type: testWeightEntry.data.dataType,
        rangeEnd: any(named: 'rangeEnd'),
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => [testWeightEntry]);
    when(
      () => mockHealthImport.fetchHealthDataDelta(
        testWeightEntry.data.dataType,
      ),
    ).thenAnswer((_) async {});

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<HealthImport>(mockHealthImport);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('HealthSummary', () {
    testWidgets(
      'renders chart with healthType forwarded from the entry plus info text',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(HealthSummary(testWeightEntry)),
        );
        await tester.pump();

        final chart = tester.widget<DashboardHealthChart>(
          find.byType(DashboardHealthChart),
        );
        expect(chart.chartConfig.healthType, testWeightEntry.data.dataType);

        // Info line shows the formatted quantitative value.
        expect(
          find.text(entryTextForQuant(testWeightEntry)),
          findsOneWidget,
        );
      },
    );

    testWidgets('hides the chart when showChart is false', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HealthSummary(testWeightEntry, showChart: false),
        ),
      );
      await tester.pump();

      expect(find.byType(DashboardHealthChart), findsNothing);
      // The info text still renders.
      expect(find.byType(InfoText), findsOneWidget);
      expect(
        find.text(entryTextForQuant(testWeightEntry)),
        findsOneWidget,
      );
    });
  });
}
