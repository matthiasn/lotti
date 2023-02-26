import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/tags/tag_add.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagAddIconWidget Tests -', () {
    final mockNavService = MockNavService();
    final mockTagsService = mockTagsServiceWithTags([testStoryTag1]);
    final entryCubit = MockEntryCubit();

    when(() => mockTagsService.stream).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [testStoryTag1]
      ]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [testStoryTag1]
      ]),
    );

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<TagsService>(mockTagsService);
    });

    testWidgets('Icon tap opens modal', (tester) async {
      when(() => entryCubit.state).thenAnswer(
        (_) => EntryState.dirty(
          entryId: testTextEntry.meta.id,
          entry: testTextEntry,
          showMap: false,
          isFocused: false,
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
      final tagAddIconFinder = find.byKey(Key(styleConfig().cardTagIcon));

      expect(tagAddIconFinder, findsOneWidget);

      await tester.tap(tagAddIconFinder);
      await tester.pumpAndSettle();
    });
  });
}
