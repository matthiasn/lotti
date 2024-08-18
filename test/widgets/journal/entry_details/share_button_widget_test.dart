import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/share_button_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('ShareButtonWidget', () {
    final mockEditorStateService = MockEditorStateService();
    final mockUpdateNotifications = MockUpdateNotifications();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockJournalDb = MockJournalDb();
    final mockTagsService = mockTagsServiceWithTags([]);

    setUpAll(() async {
      setFakeDocumentsPath();

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<TagsService>(mockTagsService);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [testStoryTag1],
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });

    testWidgets('tap share icon on image', (WidgetTester tester) async {
      when(() => mockJournalDb.journalEntityById(testImageEntry.meta.id))
          .thenAnswer((_) async => testImageEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ShareButtonWidget(entryId: testImageEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();
      final shareIconFinder = find.byIcon(MdiIcons.shareOutline);
      expect(shareIconFinder, findsOneWidget);

      await tester.tap(shareIconFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('tap share icon on audio', (WidgetTester tester) async {
      when(() => mockJournalDb.journalEntityById(testAudioEntry.meta.id))
          .thenAnswer((_) async => testAudioEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ShareButtonWidget(entryId: testAudioEntry.meta.id),
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
