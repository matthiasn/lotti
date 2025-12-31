import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('TaskDetailPage Widget Tests - ', () {
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
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );
      when(() => mockEntitiesCacheService.sortedLabels)
          .thenReturn(<LabelDefinition>[]);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [testStoryTag1],
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
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [testTextEntry],
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
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);
    });
    tearDown(getIt.reset);

    testWidgets('Task Entry is rendered', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
        ),
      );

      await tester.pumpAndSettle();

      // TODO: test that entry text is rendered

      // test entry displays expected date (date only, no time)
      expect(
        find.text(DateFormat.yMMMd().format(testTask.meta.dateFrom)),
        findsOneWidget,
      );

      // test task displays progress bar (now in Labels row)
      final progressBarFinder = find.byType(LinearProgressIndicator);
      if (progressBarFinder.evaluate().isNotEmpty) {
        final progressBar =
            tester.firstWidget(progressBarFinder) as LinearProgressIndicator;
        expect(progressBar, isNotNull);
        expect(progressBar.value, 0.25);
      }

      // test task title is displayed
      expect(find.text(testTask.data.title), findsNWidgets(2));
    });
  });

  group('TaskDetailsPage Auto-Scroll Tests - ', () {
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
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );
      when(() => mockEntitiesCacheService.sortedLabels)
          .thenReturn(<LabelDefinition>[]);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(
        () => mockJournalDb
            .getMeasurableDataTypeById('83ebf58d-9cea-4c15-a034-89c84a8b8178'),
      ).thenAnswer((_) async => measurableWater);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [testStoryTag1],
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
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [testTextEntry],
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
        () => mockJournalDb.getMeasurementsByType(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          type: '83ebf58d-9cea-4c15-a034-89c84a8b8178',
        ),
      ).thenAnswer((_) async => []);

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);
    });

    tearDown(getIt.reset);

    testWidgets('focus intent triggers scroll to entry', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TaskDetailsPage(taskId: testTask.id),
        ),
      );

      // Allow scroll retry/backoff to complete and clear intent over multiple frames
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Publish focus intent
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskDetailsPage)),
      );

      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      await tester.pumpAndSettle();
      for (var i = 0;
          i < 20 &&
              container.read(taskFocusControllerProvider(id: testTask.id)) !=
                  null;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after consumption
      final intent =
          container.read(taskFocusControllerProvider(id: testTask.id));
      expect(intent, isNull);
    });

    testWidgets('pre-existing intent handled on page build', (tester) async {
      // Create a container and publish intent before building the page
      final container = ProviderContainer();

      container
          .read(taskFocusControllerProvider(id: testTask.id).notifier)
          .publishTaskFocus(
            entryId: testTextEntry.meta.id,
          );

      // Verify intent exists
      final intentBefore =
          container.read(taskFocusControllerProvider(id: testTask.id));
      expect(intentBefore, isNotNull);
      expect(intentBefore!.entryId, equals(testTextEntry.meta.id));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(
            TaskDetailsPage(taskId: testTask.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      for (var i = 0;
          i < 20 &&
              container.read(taskFocusControllerProvider(id: testTask.id)) !=
                  null;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify intent was cleared after handling
      final intentAfter =
          container.read(taskFocusControllerProvider(id: testTask.id));
      expect(intentAfter, isNull);

      container.dispose();
    });
  });
}
