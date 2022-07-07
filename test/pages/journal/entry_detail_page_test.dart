import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal/journal_page.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../data/test_data.dart';
import '../../test_data.dart';
import '../../widget_test_utils.dart';
import '../settings/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  var mockAppRouter = MockAppRouter();

  group('EntryDetailPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeMeasurementData());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      mockAppRouter = MockAppRouter();
      when(mockAppRouter.pop).thenAnswer((invocation) async => true);

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<AppRouter>(mockAppRouter);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(
        () => mockJournalDb.watchTags(),
      ).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          }
        ]),
      );

      when(
        () => mockJournalDb.watchJournalEntities(
          types: defaultTypes.toList(),
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
        () => mockEditorStateService.getUnsavedStream(
          testTextEntry.meta.id,
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          testTask.meta.id,
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

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
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: EntryDetailPage(
              itemId: testTextEntry.meta.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test entry displays expected date
      expect(
        find.text(df.format(testTextEntry.meta.dateFrom)),
        findsOneWidget,
      );

      // test entry displays duration of one hour
      expect(
        find.text('1:00:00'),
        findsOneWidget,
      );

      // test text entry is starred
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.star)) as Icon).color,
        darkTheme.starredGold,
      );
    });

    testWidgets('Task Entry is rendered', (tester) async {
      Future<MeasurementEntry?> mockCreateMeasurementEntry() {
        return mockPersistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
        );
      }

      when(mockCreateMeasurementEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: EntryDetailPage(
              itemId: testTask.meta.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test entry displays expected date
      expect(
        find.text(df.format(testTask.meta.dateFrom)),
        findsOneWidget,
      );

      // test task displays progress bar with 2 hours progress and 3 hours total
      final progressBar =
          tester.firstWidget(find.byType(ProgressBar)) as ProgressBar;
      expect(progressBar, isNotNull);
      expect(progressBar.progress, const Duration(hours: 2));
      expect(progressBar.total, const Duration(hours: 3));

      // test task title is displayed
      expect(
        find.text(testTask.data.title),
        findsNWidgets(2),
      );

      // task entry duration is rendered
      expect(
        find.text('2:00:00'),
        findsOneWidget,
      );

      // test task is starred
      expect(
        (tester.firstWidget(find.byIcon(MdiIcons.star)) as Icon).color,
        darkTheme.starredGold,
      );
    });
  });
}
