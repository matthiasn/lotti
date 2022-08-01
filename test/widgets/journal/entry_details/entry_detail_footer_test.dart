import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_footer.dart';
import 'package:mocktail/mocktail.dart';

import '../../../journal_test_data/test_data.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockEntryCubit extends MockBloc<EntryCubit, EntryState>
    implements EntryCubit {}

void main() {
  group('EntryDetailFooter', () {
    final entryCubit = MockEntryCubit();
    final mockAppRouter = MockAppRouter();
    final mockTimeService = MockTimeService();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<AppRouter>(mockAppRouter);

      when(mockAppRouter.pop).thenAnswer((_) async => true);

      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
        ),
      );
    });

    testWidgets('tap map icon toggles map display',
        (WidgetTester tester) async {
      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailFooter(
              itemId: testTextEntry.meta.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lonLatFinder = find.text('📍 52.51, 13.43');
      expect(lonLatFinder, findsOneWidget);

      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsNothing);

      await tester.tap(lonLatFinder);
      await tester.pumpAndSettle();

      expect(mapFinder, findsOneWidget);
    });

    testWidgets('time record button is not shown for older entry',
        (WidgetTester tester) async {
      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailFooter(
              itemId: testTextEntry.meta.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recordIconFinder = find.byIcon(Icons.fiber_manual_record_sharp);
      expect(recordIconFinder, findsNothing);

      final durationFinder = find.text('01:00:00');
      expect(durationFinder, findsNothing);
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

      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testEntry.meta.id,
          entry: testEntry,
        ),
      );
      Future<void> mockStartTimer() => mockTimeService.start(testEntry);
      when(mockStartTimer).thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailFooter(
              itemId: testTextEntry.meta.id,
            ),
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

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([testEntry]));

      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testEntry.meta.id,
          entry: testEntry,
        ),
      );

      Future<void> mockStopTimer() => mockTimeService.stop();
      when(mockStopTimer).thenAnswer((_) async {});

      when(entryCubit.save).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailFooter(
              itemId: testTextEntry.meta.id,
            ),
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
      verify(entryCubit.save).called(1);
    });
  });
}
