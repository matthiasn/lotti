import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/journal_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../utils/utils.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var mockJournalDb = MockJournalDb();

  group('JournalCard Widget Tests - ', () {
    setFakeDocumentsPath();

    setUp(() async {
      ensureMpvInitialized();

      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      final mockTagsService = mockTagsServiceWithTags([]);
      final mockTimeService = MockTimeService();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<LoggingDb>(MockLoggingDb())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([[]]),
      );

      when(mockTimeService.getStream)
          .thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });
    tearDown(getIt.reset);

    testWidgets('Render card for text entry', (tester) async {
      when(
        () => mockJournalDb.watchEntityById(testTextEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testTextEntry]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: JournalCard(item: testTextEntry),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dateFinder = find.text('2022-07-07 13:00');
      expect(dateFinder, findsOneWidget);
    });

    testWidgets('Render card for image entry', (tester) async {
      when(
        () => mockJournalDb.watchEntityById(testImageEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testImageEntry]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: JournalImageCard(item: testImageEntry),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dateFinder = find.text('2022-07-07 13:00');
      expect(dateFinder, findsOneWidget);
    });

    testWidgets('Render card for audio entry', (tester) async {
      when(
        () => mockJournalDb.watchEntityById(testAudioEntry.meta.id),
      ).thenAnswer(
        (_) => Stream<JournalEntity>.fromIterable([testAudioEntry]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<AudioPlayerCubit>(
            create: (BuildContext context) => AudioPlayerCubit(),
            lazy: false,
            child: JournalCard(item: testAudioEntry),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dateFinder = find.text('2022-07-07 13:00');
      expect(dateFinder, findsOneWidget);
    });
  });
}
