import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_footer.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('EntryDetailFooter', () {
    final mockTimeService = MockTimeService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockEditorDb = MockEditorDb();
    final mockEditorStateService = MockEditorStateService();
    final mockJournalDb = MockJournalDb();
    final mockTagsService = mockTagsServiceWithTags([]);

    setUpAll(() {
      final mockUpdateNotifications = MockUpdateNotifications();
      registerFallbackValue(FakeEntryText());
      registerFallbackValue(FakeQuillController());

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [testStoryTag1],
        ]),
      );

      when(
        () => mockEditorStateService.entryWasSaved(
          id: any(named: 'id'),
          lastSaved: any(named: 'lastSaved'),
          controller: any(named: 'controller'),
        ),
      ).thenAnswer(
        (_) async {},
      );

      when(
        () => mockPersistenceLogic.updateJournalEntityText(
          any(),
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) async => true,
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    testWidgets('entry date is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryDateFromFinder =
          find.text(dfShorter.format(testTextEntry.meta.dateFrom));
      expect(entryDateFromFinder, findsOneWidget);
    });

    testWidgets('map is invisible when not set in cubit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsNothing);
    });

    testWidgets('time record button is not shown for older entry',
        (WidgetTester tester) async {
      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      expect(recordIconFinder, findsNothing);
    });

    testWidgets('time record button is tappable', (WidgetTester tester) async {
      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      final now = DateTime.now();

      final testEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          dateFrom: now,
          dateTo: now,
        ),
      );

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testEntry);

      Future<void> mockStartTimer() => mockTimeService.start(testEntry, null);
      when(mockStartTimer).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      final stopIconFinder = find.byIcon(Icons.stop);
      expect(recordIconFinder, findsOneWidget);
      expect(stopIconFinder, findsNothing);

      final durationZeroFinder = find.text('00:00:00');
      expect(durationZeroFinder, findsOneWidget);

      await tester.tap(recordIconFinder);
      await tester.pumpAndSettle();

      verify(mockStartTimer).called(1);
    });

    testWidgets('time record stop button is tappable',
        (WidgetTester tester) async {
      final now = DateTime.now();

      final testEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(
          dateFrom: now.subtract(const Duration(seconds: 5)),
          dateTo: now,
        ),
      );

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testEntry);

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([testEntry]));

      Future<void> mockStopTimer() => mockTimeService.stop();
      when(mockStopTimer).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailFooter(
            entryId: testTextEntry.meta.id,
            linkedFrom: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      final stopIconFinder = find.byIcon(Icons.stop);
      expect(recordIconFinder, findsNothing);
      expect(stopIconFinder, findsOneWidget);

      final durationZeroFinder = find.text('00:00:05');
      expect(durationZeroFinder, findsOneWidget);

      await tester.tap(stopIconFinder);
      await tester.pumpAndSettle();

      verify(mockStopTimer).called(1);

      // TODO: check that provider method is called instead
      // verify(entryCubit.save).called(1);
    });
  });
}
