import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('EntryDetailPage Widget Tests - ', () {
    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [testStoryTag1]
        ]),
      );

      when(() => mockTagsService.stream).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          }
        ]),
      );

      when(
        () => mockJournalDb.watchJournalEntities(
          types: entryTypes.toList(),
          starredStatuses: [true, false],
          privateStatuses: [true, false],
          flaggedStatuses: [1, 0],
          ids: null,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [
            testTextEntry,
            testTask,
            testWeightEntry,
          ]
        ]),
      );

      when(
        () => mockJournalDb.watchLinkedEntityIds(testTextEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<List<String>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchLinkedEntityIds(testTask.meta.id),
      ).thenAnswer(
        (_) => Stream<List<String>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchLinkedEntityIds(testWeightEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<List<String>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchLinkedToEntities(
          linkedTo: testTextEntry.meta.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchLinkedToEntities(linkedTo: testTask.meta.id),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchLinkedToEntities(
          linkedTo: testWeightEntry.meta.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.watchEntityById(testTask.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testTask]),
      );

      when(
        () => mockJournalDb.watchEntityById(testTextEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testTextEntry]),
      );

      when(
        () => mockJournalDb.watchEntityById(testWeightEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testWeightEntry]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockHealthImport
            .fetchHealthDataDelta(testWeightEntry.data.dataType),
      ).thenAnswer((_) async {});

      when(
        () => mockJournalDb.watchQuantitativeByType(
          type: testWeightEntry.data.dataType,
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) => Stream<List<JournalEntity>>.fromIterable([]));

      when(
        () => mockJournalDb.watchLinkedTotalDuration(
          linkedFrom: testTask.meta.id,
        ),
      ).thenAnswer(
        (_) => Stream<Map<String, Duration>>.fromIterable([
          {testTask.meta.id: const Duration(hours: 1)}
        ]),
      );

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

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

    testWidgets('Text Entry is rendered', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test entry displays expected date
      expect(
        find.text(dfShorter.format(testTextEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test entry displays duration of one hour
      expect(
        find.text('1:00:00'),
        findsOneWidget,
      );

      // test text entry is starred
      expect(find.byKey(Key(styleConfig().cardStarIconActive)), findsOneWidget);
    });

    testWidgets('Task Entry is rendered', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailPage(itemId: testTask.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test entry displays expected date
      expect(
        find.text(dfShorter.format(testTask.meta.dateFrom)),
        findsOneWidget,
      );

      // test task displays progress bar with 2 hours progress and 3 hours total
      final progressBar =
          tester.firstWidget(find.byType(ProgressBar)) as ProgressBar;
      expect(progressBar, isNotNull);
      expect(progressBar.progress, const Duration(hours: 2));
      expect(progressBar.total, const Duration(hours: 3));

      // test task title is displayed
      expect(find.text(testTask.data.title), findsOneWidget);

      // task entry duration is rendered
      expect(
        find.text('2:00:00'),
        findsOneWidget,
      );

      // test task is starred
      expect(find.byKey(Key(styleConfig().cardStarIconActive)), findsOneWidget);
    });

    testWidgets('Weight Entry is rendered properly', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: false,
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailPage(itemId: testWeightEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      // test entry displays expected date
      expect(
        find.text(dfShorter.format(testWeightEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test weight entry is not starred
      expect(find.byKey(Key(styleConfig().cardStarIcon)), findsOneWidget);
    });
  });
}
