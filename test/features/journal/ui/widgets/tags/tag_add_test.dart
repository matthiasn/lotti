import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tag_add.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagAddIconWidget Tests -', () {
    final mockNavService = MockNavService();
    final mockTagsService = mockTagsServiceWithTags([testStoryTag1]);
    final mockEditorStateService = MockEditorStateService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockTagsService.stream).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [testStoryTag1],
      ]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([
        [testStoryTag1],
      ]),
    );

    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );

    when(() => mockJournalDb.journalEntityById(testTextEntry.meta.id))
        .thenAnswer((_) async => testTextEntry);

    when(
      () => mockEditorStateService.getUnsavedStream(
        any(),
        any(),
      ),
    ).thenAnswer(
      (_) => Stream<bool>.fromIterable([false]),
    );

    setUpAll(() {
      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EditorStateService>(mockEditorStateService);
    });

    testWidgets('Icon tap opens modal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          TagAddListTile(
            entryId: testTextEntry.meta.id,
            pageIndexNotifier: ValueNotifier(0),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // icon is visible
      final tagAddIconFinder = find.byIcon(MdiIcons.tag);

      expect(tagAddIconFinder, findsOneWidget);

      await tester.tap(tagAddIconFinder);
      await tester.pumpAndSettle();
    });
  });
}
