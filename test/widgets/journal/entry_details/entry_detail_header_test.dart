import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/entry_detail_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('EntryDetailHeader', () {
    final entryCubit = MockEntryCubit();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService());

      when(() => entryCubit.showMap).thenAnswer((_) => false);

      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
        ),
      );
    });

    testWidgets('tap star icon', (WidgetTester tester) async {
      when(entryCubit.toggleStarred).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final starIconActiveFinder =
          find.byKey(Key(styleConfig().cardStarIconActive));
      expect(starIconActiveFinder, findsOneWidget);

      await tester.tap(starIconActiveFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.toggleStarred).called(1);
    });

    testWidgets('tap flagged icon', (WidgetTester tester) async {
      when(entryCubit.toggleFlagged).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final flagIconFinder = find.byKey(Key(styleConfig().cardFlagIcon));
      expect(flagIconFinder, findsOneWidget);

      await tester.tap(flagIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.toggleFlagged).called(1);
    });

    testWidgets('tap private icon', (WidgetTester tester) async {
      when(entryCubit.togglePrivate).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shieldIconFinder = find.byKey(Key(styleConfig().cardShieldIcon));

      expect(shieldIconFinder, findsOneWidget);

      await tester.tap(shieldIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.togglePrivate).called(1);
    });

    testWidgets('save button invisible when saved/clean',
        (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.saved(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.text('SAVE');
      expect(saveButtonFinder, findsNothing);
    });

    testWidgets('save button tappable when unsaved/dirty',
        (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
        ),
      );

      when(entryCubit.save).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.text('Save');
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.save).called(1);
    });

    testWidgets('map icon invisible when no geolocation exists for entry',
        (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry.copyWith(geolocation: null),
          showMap: false,
        ),
      );

      when(entryCubit.save).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapIconFinder = find.byIcon(MdiIcons.mapOutline);
      expect(mapIconFinder, findsNothing);
    });

    testWidgets('map icon tappable when geolocation exists for entry',
        (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
        ),
      );

      when(entryCubit.toggleMapVisible).thenAnswer((_) async {});

      when(entryCubit.save).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const EntryDetailHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapIconFinder = find.byKey(Key(styleConfig().cardMapIcon));
      expect(mapIconFinder, findsOneWidget);

      await tester.tap(mapIconFinder);
      await tester.pumpAndSettle();

      verify(entryCubit.toggleMapVisible).called(1);
    });
  });
}
