import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../journal_test_data/test_data.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockEntryCubit extends MockBloc<EntryCubit, EntryState>
    implements EntryCubit {}

void main() {
  group('EntryDetailHeader', () {
    final entryCubit = MockEntryCubit();
    final mockAppRouter = MockAppRouter();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<AppRouter>(mockAppRouter);

      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
        ),
      );
    });

    testWidgets('tap star icon', (WidgetTester tester) async {
      when(entryCubit.toggleStarred).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailHeader(itemId: testTextEntry.meta.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final starIconFinder = find.byIcon(MdiIcons.star);
      expect(starIconFinder, findsOneWidget);

      await tester.tap(starIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.toggleStarred).called(1);
    });

    testWidgets('tap flagged icon', (WidgetTester tester) async {
      when(entryCubit.toggleFlagged).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailHeader(itemId: testTextEntry.meta.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final starIconFinder = find.byIcon(MdiIcons.flag);
      expect(starIconFinder, findsOneWidget);

      await tester.tap(starIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.toggleFlagged).called(1);
    });

    testWidgets('tap private icon', (WidgetTester tester) async {
      when(entryCubit.togglePrivate).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: EntryDetailHeader(itemId: testTextEntry.meta.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final starIconFinder = find.byIcon(MdiIcons.security);
      expect(starIconFinder, findsOneWidget);

      await tester.tap(starIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.togglePrivate).called(1);
    });
  });
}
