import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/tasks/tasks_page.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';
import '../../test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  var mockAppRouter = MockAppRouter();

  group('JournalPage Widget Tests - ', () {
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

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<AppRouter>(mockAppRouter);

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
        () => mockJournalDb.watchTasks(
          starredStatuses: [true, false],
          taskStatuses: ['OPEN', 'GROOMED', 'IN PROGRESS'],
        ),
      ).thenAnswer((_) {
        return Stream<List<JournalEntity>>.fromIterable([
          [
            testTask,
          ]
        ]);
      });

      when(
        () => mockJournalDb.watchTaskCount(any()),
      ).thenAnswer((_) {
        return Stream<int>.fromIterable([0]);
      });

      when(
        () => mockJournalDb.watchEntityById(testTask.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testTask]),
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
    });
    tearDown(getIt.reset);

    testWidgets('page is rendered with text and task entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: const TasksPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // task entry displays expected date
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
        findsOneWidget,
      );
    });
  });
}
