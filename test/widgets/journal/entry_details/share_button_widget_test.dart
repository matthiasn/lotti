import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('ShareButtonWidget', () {
    final entryCubit = MockEntryCubit();

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService());
    });

    testWidgets('tap share icon on image', (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testImageEntry.meta.id,
          entry: testImageEntry,
          showMap: false,
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const ShareButtonWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shareIconFinder = find.byIcon(MdiIcons.shareOutline);
      expect(shareIconFinder, findsOneWidget);

      await tester.tap(shareIconFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('tap share icon on audio', (WidgetTester tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testAudioEntry.meta.id,
          entry: testAudioEntry,
          showMap: false,
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const ShareButtonWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shareIconFinder = find.byIcon(MdiIcons.shareOutline);
      expect(shareIconFinder, findsOneWidget);

      await tester.tap(shareIconFinder);
      await tester.pumpAndSettle();
    });
  });
}
