import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/tags/tags_modal.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

class TestCallbackClass {
  void onTapRemove() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsModal Widget Tests -', () {
    final mockTagsService = MockTagsService();
    final entryCubit = MockEntryCubit();

    when(() => mockTagsService.stream).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [
          testStoryTag1,
          testPersonTag1,
        ]
      ]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [
          testStoryTag1,
          testPersonTag1,
        ]
      ]),
    );

    when(mockTagsService.getClipboard).thenAnswer(
      (_) async => [
        testStoryTag1.id,
        testPersonTag1.id,
      ],
    );

    when(() => mockTagsService.getTagById(testTag1.id))
        .thenAnswer((_) => testTag1);

    when(() => mockTagsService.getTagById(testPersonTag1.id))
        .thenAnswer((_) => testPersonTag1);

    when(() => mockTagsService.getTagById(testStoryTag1.id))
        .thenAnswer((_) => testStoryTag1);

    when(() => mockTagsService.getMatchingTags(any()))
        .thenAnswer((_) async => [testTag1]);

    when(() => entryCubit.state).thenAnswer(
      (_) => EntryState.dirty(
        entryId: testTextEntryWithTags.meta.id,
        entry: testTextEntryWithTags,
        showMap: false,
        isFocused: false,
      ),
    );

    when(() => entryCubit.entry).thenAnswer((_) => testTextEntryWithTags);

    when(() => entryCubit.addTagIds(any())).thenAnswer((_) async {});

    setUpAll(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<TagsService>(mockTagsService);
    });

    testWidgets('tag copy and paste', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const TagsModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final copyIconFinder = find.byIcon(MdiIcons.contentCopy);
      final pasteIconFinder = find.byIcon(MdiIcons.contentPaste);

      expect(copyIconFinder, findsOneWidget);
      expect(pasteIconFinder, findsOneWidget);

      await tester.tap(copyIconFinder);
      await tester.pumpAndSettle();

      await tester.tap(pasteIconFinder);
      await tester.pumpAndSettle();
      verify(mockTagsService.getClipboard).called(1);
    });

    testWidgets('select existing tag', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const TagsModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchFieldFinder = find.byType(CupertinoTextField);
      await tester.enterText(searchFieldFinder, 'some');
      await tester.pumpAndSettle();

      final tagFinder = find.text(testTag1.tag);
      expect(tagFinder, findsOneWidget);
      await tester.tap(tagFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('add new tag', (tester) async {
      const newTagId = 'new-tag-id';

      final newTag = GenericTag(
        id: newTagId,
        tag: 'new tag',
        private: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
      );

      when(() => entryCubit.addTagDefinition(newTag.tag))
          .thenAnswer((_) async => newTagId);

      when(() => mockTagsService.getTagById(newTagId))
          .thenAnswer((_) => newTag);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [
            testStoryTag1,
            testPersonTag1,
            testTag1,
            newTag,
          ]
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const TagsModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchFieldFinder = find.byType(CupertinoTextField);
      await tester.enterText(searchFieldFinder, newTag.tag);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      verify(() => entryCubit.addTagDefinition(newTag.tag)).called(1);
    });

    testWidgets('remove tag', (tester) async {
      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [
            testStoryTag1,
            testPersonTag1,
            testTag1,
          ]
        ]),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<EntryCubit>.value(
            value: entryCubit,
            child: const TagsModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final closeIconFinder = find.byIcon(MdiIcons.close);
      expect(closeIconFinder, findsNWidgets(2));

      when(() => entryCubit.removeTagId(any())).thenAnswer((_) async {});

      await tester.tap(closeIconFinder.first);

      verify(() => entryCubit.removeTagId(any())).called(1);
    });
  });
}
