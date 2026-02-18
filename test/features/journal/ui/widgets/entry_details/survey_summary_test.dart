import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('SurveySummary', () {
    late MockJournalDb mockJournalDb;
    late SurveyEntry testSurveyEntry;

    setUpAll(() {
      final file = File('test_resources/cfq11.test.json');
      final json = file.readAsStringSync();
      testSurveyEntry = SurveyEntry.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    });

    setUp(() {
      mockJournalDb = MockJournalDb();
      getIt.registerSingleton<JournalDb>(mockJournalDb);

      when(
        () => mockJournalDb.getSurveyCompletionsByType(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => [testSurveyEntry]);
    });

    tearDown(getIt.reset);

    testWidgets('displays score key and value from calculatedScores',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(SurveySummary(testSurveyEntry)),
      );
      await tester.pumpAndSettle();

      // calculatedScores has {"CFQ11": 11} — verify both key and value
      expect(find.text('CFQ11:'), findsOneWidget);
      expect(find.text(' 11'), findsOneWidget);
    });

    testWidgets('shows DashboardSurveyChart when showChart is true (default)',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(SurveySummary(testSurveyEntry)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardSurveyChart), findsOneWidget);
    });

    testWidgets('hides DashboardSurveyChart when showChart is false',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SurveySummary(testSurveyEntry, showChart: false),
        ),
      );
      await tester.pumpAndSettle();

      // Score should still display
      expect(find.text('CFQ11:'), findsOneWidget);
      // Chart should not
      expect(find.byType(DashboardSurveyChart), findsNothing);
    });
  });
}
