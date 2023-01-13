import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('EditorWidget', () {
    final entryCubit = MockEntryCubit();
    final mockTimeService = MockTimeService();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true))
        ..registerSingleton<VectorClockService>(MockVectorClockService())
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<TagsService>(TagsService())
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<EditorStateService>(EditorStateService());

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    testWidgets('editor toolbar is visible with autofocus',
        (WidgetTester tester) async {
      when(entryCubit.togglePrivate).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: EntryCubit(
              entryId: testTextEntry.meta.id,
              entry: testTextEntry,
            ),
            child: const EditorWidget(
              autoFocus: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boldIconFinder = find.byIcon(Icons.format_bold);
      expect(boldIconFinder, findsOneWidget);
    });

    testWidgets('editor toolbar is invisible without autofocus',
        (WidgetTester tester) async {
      when(entryCubit.togglePrivate).thenAnswer((_) async => true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: EntryCubit(
              entryId: testTextEntry.meta.id,
              entry: testTextEntry,
            ),
            child: const EditorWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boldIconFinder = find.byIcon(Icons.format_bold);
      expect(boldIconFinder, findsNothing);
    });
  });
}
