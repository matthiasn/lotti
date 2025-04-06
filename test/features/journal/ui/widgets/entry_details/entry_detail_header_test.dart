import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('EntryDetailHeader', () {
    registerFallbackValue(FakeJournalEntity());
    registerFallbackValue(FakeMetadata());
    final mockJournalDb = MockJournalDb();
    final mockEditorDb = MockEditorDb();
    final mockEditorStateService = MockEditorStateService();
    final mockEntitiesCacheService = MockEntitiesCacheService();

    setUpAll(() {
      registerFallbackValue(FakeEntryText());
      registerFallbackValue(FakeQuillController());

      final mockUpdateNotifications = MockUpdateNotifications();
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockTagsService = mockTagsServiceWithTags([]);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorDb>(mockEditorDb)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<TagsService>(mockTagsService);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
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

      when(() => mockPersistenceLogic.updateJournalEntity(any(), any()))
          .thenAnswer(
        (_) async => true,
      );

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    testWidgets('tap star icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();
      final starIconActiveFinder = find.byIcon(Icons.star_rounded);
      expect(starIconActiveFinder, findsOneWidget);

      await tester.tap(starIconActiveFinder);
      await tester.pumpAndSettle();

      // TODO: check that provider method is called instead
      // verify(() => mockJournalDb.updateJournalEntity(any())).called(1);
    });

    testWidgets('tap flagged icon', (WidgetTester tester) async {
      // Create a copy of testTextEntry with flag set to EntryFlag.import
      final flaggedTextEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(flag: EntryFlag.import),
      );

      // Mock the database to return the flagged entry
      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => flaggedTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      // Now the flag icon should be visible
      final flagIconFinder = find.byIcon(Icons.flag);
      expect(flagIconFinder, findsOneWidget);

      await tester.tap(flagIconFinder);
      await tester.pumpAndSettle();

      // TODO: check that provider method is called instead
      // verify(entryCubit.toggleFlagged).called(1);
    });

    testWidgets('tap private icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(
            entryId: testTextEntry.meta.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      await tester.pumpAndSettle();

      final shieldIconFinder = find.byIcon(Icons.shield_outlined);

      expect(shieldIconFinder, findsOneWidget);

      await tester.tap(shieldIconFinder);
      await tester.pumpAndSettle();

      // TODO: check that provider method is called instead
      // verify(entryCubit.togglePrivate).called(1);
    });

    testWidgets('save button invisible when saved/clean',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.text('SAVE');
      expect(saveButtonFinder, findsNothing);
    });

    testWidgets('save button tappable when unsaved/dirty', skip: true,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.text('Save');
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // TODO: check that provider method is called instead
      // verify(entryCubit.save).called(1);
    });

    testWidgets('map icon invisible when no geolocation exists for entry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      await tester.pumpAndSettle();

      final mapIconFinder = find.byIcon(MdiIcons.mapOutline);
      expect(mapIconFinder, findsNothing);
    });

    testWidgets('map icon tappable when geolocation exists for entry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDetailHeader(entryId: testTextEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();

      final moreHorizIconFinder = find.byIcon(Icons.more_horiz);
      await tester.tap(moreHorizIconFinder);
      await tester.pumpAndSettle();

      final mapIconFinder = find.byIcon(Icons.map_outlined);
      expect(mapIconFinder, findsOneWidget);

      await tester.tap(mapIconFinder);
      await tester.pumpAndSettle();

      // TODO: check that provider method is called instead
      // verify(entryCubit.toggleMapVisible).called(1);
    });
  });

  testWidgets('entry date is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        EntryDetailHeader(
          entryId: testTextEntry.meta.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final entryDateFromFinder =
        find.text(dfShorter.format(testTextEntry.meta.dateFrom));
    expect(entryDateFromFinder, findsOneWidget);
  });
}
