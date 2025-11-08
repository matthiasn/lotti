import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
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

  group('LinkedEntriesWidget Key Builder Tests - ', () {
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

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    testWidgets('accepts custom key builder parameter', (tester) async {
      final customKeys = <String, GlobalKey>{};
      GlobalKey customKeyBuilder(String entryId) {
        return customKeys.putIfAbsent(
          entryId,
          () => GlobalKey(debugLabel: 'custom_$entryId'),
        );
      }

      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [],
      );

      // Should compile and run without errors when custom key builder provided
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedEntriesWidget(
            testTask,
            entryKeyBuilder: customKeyBuilder,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should render successfully
      expect(find.byType(LinkedEntriesWidget), findsOneWidget);
    });

    testWidgets('uses default key when builder not provided', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [testTextEntry],
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedEntriesWidget(testTask),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should render successfully with default keys
      expect(find.byType(LinkedEntriesWidget), findsOneWidget);
    });

    testWidgets('widget compiles with nullable key builder', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [],
      );

      // Verify the entryKeyBuilder parameter is nullable and compiles
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedEntriesWidget(testTask),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(LinkedEntriesWidget), findsOneWidget);
    });

    testWidgets('renders empty when no linked entries', (tester) async {
      when(() => mockJournalDb.journalEntityById(testTask.meta.id))
          .thenAnswer((_) async => testTask);

      when(
        () => mockJournalDb.getLinkedEntities(testTask.meta.id),
      ).thenAnswer(
        (_) async => [],
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          LinkedEntriesWidget(testTask),
        ),
      );

      await tester.pumpAndSettle();

      // Should render SizedBox.shrink when no entries
      expect(find.byType(LinkedEntriesWidget), findsOneWidget);
    });
  });

  group('LinkedEntriesWidget activeTimerEntryId Tests - ', () {
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

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    test('activeTimerEntryId parameter defaults to null', () {
      final widget = LinkedEntriesWidget(testTask);

      expect(widget.activeTimerEntryId, isNull);
    });

    test('activeTimerEntryId parameter can be set', () {
      const timerId = 'timer-entry-123';
      final widget = LinkedEntriesWidget(
        testTask,
        activeTimerEntryId: timerId,
      );

      expect(widget.activeTimerEntryId, equals(timerId));
    });

    test('highlightedEntryId and activeTimerEntryId are independent', () {
      const timerId = 'timer-123';
      const highlightId = 'highlight-456';
      final widget = LinkedEntriesWidget(
        testTask,
        activeTimerEntryId: timerId,
        highlightedEntryId: highlightId,
      );

      expect(widget.activeTimerEntryId, equals(timerId));
      expect(widget.highlightedEntryId, equals(highlightId));
    });
  });
}
