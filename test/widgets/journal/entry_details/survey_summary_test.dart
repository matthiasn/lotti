import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/survey_summary.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();

  group('SurveySummary Widget Tests -', () {
    setUp(() {
      getIt.registerSingleton<JournalDb>(mockJournalDb);
    });
    tearDown(getIt.reset);

    testWidgets('summary is rendered', (tester) async {
      final file = File('test_resources/cfq11.test.json');
      final json = file.readAsStringSync();

      final testSurveyEntry = SurveyEntry.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );

      when(
        () => mockJournalDb.watchSurveysByType(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
          type: any(named: 'type'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testSurveyEntry],
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(SurveySummary(testSurveyEntry)),
      );

      await tester.pumpAndSettle();

      // charts display expected title
      expect(find.text('CFQ11:'), findsOneWidget);
    });
  });
}
