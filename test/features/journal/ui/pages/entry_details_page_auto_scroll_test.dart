import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
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

  group('EntryDetailPage Auto-Scroll Tests - ', () {
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
        () => mockHealthImport
            .fetchHealthDataDelta(testWeightEntry.data.dataType),
      ).thenAnswer((_) async {});

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

      when(
        () => mockJournalDb.getMeasurableDataTypeById(any()),
      ).thenAnswer((_) async => measurableWater);
    });
    tearDown(getIt.reset);

    testWidgets('consumes pre-existing focus intent on first build',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      // Create a container with pre-existing focus intent
      final container = ProviderContainer();
      final focusProvider =
          journalFocusControllerProvider(id: testTextEntry.meta.id);

      // Set focus intent before building widget
      container.read(focusProvider.notifier).publishJournalFocus(
            entryId: 'test-linked-entry-id',
            alignment: 0.3,
          );

      // Verify intent is set
      expect(container.read(focusProvider), isNotNull);

      // Use a tree without an inner ProviderScope to ensure our container is used
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidget2(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Allow initial timer to trigger
      await tester.pump(const Duration(milliseconds: 1));

      // Allow scroll retry/backoff to reach success/terminal outcome over multiple frames
      // In debug mode: maxScrollRetries=5, scrollRetryDelay=50ms
      for (var i = 0; i < 10 && container.read(focusProvider) != null; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // Verify intent was cleared after consumption
      expect(container.read(focusProvider), isNull);

      container.dispose();
    });

    testWidgets('creates GlobalKeys for entries with entryKeyBuilder',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget is rendered (indirect test that key builder is used)
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });

    testWidgets('scroll offset listener is triggered on scroll',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailsPage(itemId: testTextEntry.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      // Find the CustomScrollView widget
      final scrollView = find.byType(CustomScrollView);
      expect(scrollView, findsOneWidget);

      // Trigger scroll to invoke the offset listener
      await tester.drag(scrollView, const Offset(0, -100));
      await tester.pumpAndSettle();

      // The scroll offset listener should have been called (line 48-49)
      // We verify this indirectly by checking the widget still renders correctly
      expect(find.byType(EntryDetailsPage), findsOneWidget);
    });

    testWidgets('successfully scrolls to entry when context exists',
        (tester) async {
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      final container = ProviderContainer();
      final focusProvider =
          journalFocusControllerProvider(id: testTextEntry.meta.id);

      // Set focus intent that would trigger scroll
      container.read(focusProvider.notifier).publishJournalFocus(
            entryId: testTextEntry.meta.id,
            alignment: 0.5,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: makeTestableWidgetWithScaffold(
            EntryDetailsPage(itemId: testTextEntry.meta.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widget rendered successfully (scroll would have been attempted)
      // Line 71 would be executed if context exists
      expect(find.byType(EntryDetailsPage), findsOneWidget);

      container.dispose();
    });
  });
}
