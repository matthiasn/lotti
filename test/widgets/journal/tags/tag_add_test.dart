import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/tags/tag_add.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../journal_test_data/test_data.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../entry_details/delete_icon_widget_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagAddIconWidget Tests -', () {
    final mockTagsService = mockTagsServiceWithTags([testStoryTagReading]);
    final entryCubit = MockEntryCubit();

    when(() => mockTagsService.stream).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [testStoryTagReading]
      ]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [testStoryTagReading]
      ]),
    );

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<TagsService>(mockTagsService);
    });

    testWidgets('Icon tap opens modal', (tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
        ),
      );

      when(() => entryCubit.entry).thenAnswer((_) => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: TagAddIconWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // icon is visible
      final tagAddIconFinder = find.byIcon(MdiIcons.tagPlusOutline);
      expect(tagAddIconFinder, findsOneWidget);

      await tester.tap(tagAddIconFinder);
      await tester.pumpAndSettle();

      expect(find.text('Tags:'), findsOneWidget);
    });
  });
}
