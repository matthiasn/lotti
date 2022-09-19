import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/charts/stories/wildcard_story_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WildcardStoryChart Widget Tests - ', () {
    setUp(() {
      final mockJournalDb = MockJournalDb();
      final mockTagsService = mockTagsServiceWithTags([]);

      getIt
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb);

      when(
        () => mockJournalDb.watchJournalByTagIds(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
          match: 'Lotti',
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );
    });
    tearDown(getIt.reset);

    testWidgets('story time chart is rendered', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          WildcardStoryChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: WildcardStoryTimeItem(
              color: '#00FF00',
              storySubstring: 'Lotti',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(find.text('Lotti'), findsOneWidget);
    });
  });

  group('WildcardStoryWeeklyChart Widget Tests - ', () {
    setUp(() {
      final mockJournalDb = MockJournalDb();
      final mockTagsService = mockTagsServiceWithTags([]);

      getIt
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb);

      when(
        () => mockJournalDb.watchJournalByTagIds(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
          match: 'Lotti',
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );
    });
    tearDown(getIt.reset);

    testWidgets('weekly story time chart is rendered', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          WildcardStoryWeeklyChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: WildcardStoryTimeItem(
              color: '#00FF00',
              storySubstring: 'Lotti',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(find.text('Lotti [weekly]'), findsOneWidget);
    });
  });
}
