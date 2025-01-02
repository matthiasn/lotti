import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tags_modal.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../mocks/sync_config_test_mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsModal Widget Tests -', () {
    final mockTagsService = MockTagsService();
    final mockEditorStateService = MockEditorStateService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockTagsService.stream).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [
          testStoryTag1,
          testPersonTag1,
        ]
      ]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [
          testStoryTag1,
          testPersonTag1,
        ]
      ]),
    );

    when(mockTagsService.getClipboard).thenAnswer(
      (_) async => [
        testStoryTag1.id,
        testPersonTag1.id,
      ],
    );

    when(() => mockTagsService.getTagById(testTag1.id))
        .thenAnswer((_) => testTag1);

    when(() => mockTagsService.getTagById(testPersonTag1.id))
        .thenAnswer((_) => testPersonTag1);

    when(() => mockTagsService.getTagById(testStoryTag1.id))
        .thenAnswer((_) => testStoryTag1);

    when(() => mockTagsService.getMatchingTags(any()))
        .thenAnswer((_) async => [testTag1]);

    setUpAll(() {
      registerFallbackValue(FakeTagEntity());
      registerFallbackValue(FakeSyncMessage());
      registerFallbackValue(FakeJournalEntity());

      final mockOutboxService = MockOutboxService();
      final mockVectorClockService = MockVectorClockService();

      getIt
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<LoggingService>(LoggingService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<VectorClockService>(mockVectorClockService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorStateService>(mockEditorStateService);

      when(
        () => mockJournalDb.upsertTagEntity(any()),
      ).thenAnswer((invocation) async => 1);

      when(
        () => mockVectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((invocation) async => const VectorClock({}));

      when(
        () => mockPersistenceLogic.updateDbEntity(any()),
      ).thenAnswer((invocation) async => true);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(() => mockJournalDb.journalEntityById(testTextEntryWithTags.meta.id))
          .thenAnswer((_) async => testTextEntryWithTags);
    });

    testWidgets('tag copy and paste', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagsModal(
            entryId: testTextEntryWithTags.meta.id,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final copyIconFinder = find.byIcon(MdiIcons.contentCopy);
      final pasteIconFinder = find.byIcon(MdiIcons.contentPaste);

      expect(copyIconFinder, findsOneWidget);
      expect(pasteIconFinder, findsOneWidget);

      await tester.tap(copyIconFinder);
      await tester.pumpAndSettle();

      await tester.tap(pasteIconFinder);
      await tester.pumpAndSettle();
      verify(mockTagsService.getClipboard).called(1);
    });

    testWidgets('select existing tag', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagsModal(entryId: testTextEntryWithTags.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      final searchFieldFinder = find.byType(CupertinoTextField);
      await tester.enterText(searchFieldFinder, 'some');
      await tester.pumpAndSettle();

      final tagFinder = find.text(testTag1.tag);
      expect(tagFinder, findsOneWidget);
      await tester.tap(tagFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('add new tag', (tester) async {
      const newTagId = 'new-tag-id';

      final newTag = GenericTag(
        id: newTagId,
        tag: 'new tag',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      );

      when(() => mockTagsService.getTagById(newTagId))
          .thenAnswer((_) => newTag);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [
            testStoryTag1,
            testPersonTag1,
            testTag1,
            newTag,
          ]
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagsModal(entryId: testTextEntryWithTags.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      final searchFieldFinder = find.byType(CupertinoTextField);
      await tester.enterText(searchFieldFinder, newTag.tag);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('remove tag', (tester) async {
      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [
            testStoryTag1,
            testPersonTag1,
            testTag1,
          ]
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagsModal(entryId: testTextEntryWithTags.meta.id),
        ),
      );

      await tester.pumpAndSettle();

      final closeIconFinder = find.byIcon(Icons.close_rounded);
      expect(closeIconFinder, findsNWidgets(2));

      await tester.tap(closeIconFinder.first);
    });
  });
}
