import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('EntryDetailFooter', () {
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockTagsService = mockTagsServiceWithTags([]);
    final mockEditorStateService = MockEditorStateService();

    setUpAll(() {
      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<TagsService>(mockTagsService);

      when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
          .thenAnswer((_) async => testTextEntry);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    testWidgets('tap entry date', (WidgetTester tester) async {
      // ignore: unused_local_variable
      DateTime? modifiedDateTo;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          EntryDatetimeWidget(
            entryId: testTextEntry.meta.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryDateFromFinder =
          find.text(dfShorter.format(testTextEntry.meta.dateFrom));
      expect(entryDateFromFinder, findsOneWidget);

      await tester.tap(entryDateFromFinder);
      await tester.pumpAndSettle();

      final entryDateTimeFinder2 =
          find.text(dfShorter.format(testTextEntry.meta.dateFrom)).last;
      expect(entryDateTimeFinder2, findsOneWidget);

      // open and close dateTo selection
      final entryDateToFinder =
          find.text(dfShorter.format(testTextEntry.meta.dateTo));
      expect(entryDateToFinder, findsOneWidget);

      await tester.tap(entryDateToFinder);
      await tester.pumpAndSettle();

      final doneButtonFinder = find.text('Done');
      expect(doneButtonFinder, findsOneWidget);

      await tester.tap(doneButtonFinder);
      await tester.pumpAndSettle();

      // open and close dateFrom selection
      await tester.tap(entryDateTimeFinder2.last);
      await tester.pumpAndSettle();

      expect(doneButtonFinder, findsOneWidget);

      await tester.tap(doneButtonFinder);
      await tester.pumpAndSettle();

      // set dateTo to now() and save
      await tester.tap(entryDateTimeFinder2.last);
      await tester.pumpAndSettle();

      final nowButtonFinder = find.text('Now');
      expect(nowButtonFinder, findsOneWidget);

      await tester.tap(nowButtonFinder);

      // TODO: debug why SAVE button doesn't become visible
      // final saveButtonFinder = find.text('SAVE');
      // expect(saveButtonFinder, findsOneWidget);
      //
      // await tester.tap(saveButtonFinder);
      // await tester.pumpAndSettle();
      //
      // // updateFromTo called with recent dateTo after tapping now()
      // expect(modifiedDateTo?.difference(DateTime.now()).inSeconds, lessThan(2));
    });
  });
}
