import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/entry_datetime_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('EntryDetailFooter', () {
    final entryCubit = MockEntryCubit();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService());

      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
          isFocused: false,
        ),
      );
    });

    testWidgets('tap entry date', (WidgetTester tester) async {
      when(entryCubit.togglePrivate).thenAnswer((_) async => true);

      // ignore: unused_local_variable
      DateTime? modifiedDateTo;

      when(
        () => entryCubit.updateFromTo(
          dateFrom: testTextEntry.meta.dateFrom,
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((Invocation i) async {
        const dateTo = Symbol('dateTo');
        modifiedDateTo = i.namedArguments[dateTo] as DateTime;
        return true;
      });

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDatetimeWidget(),
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
