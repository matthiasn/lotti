import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/tags/tag_edit_page.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockTagsService = MockTagsService();
  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('TagEditPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeTagEntity());
      registerFallbackValue(FakeSyncMessage());
    });

    setUp(() {
      mockTagsService = mockTagsServiceWithTags([]);
      final mockOutboxService = MockOutboxService();
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<OutboxService>(mockOutboxService)
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockJournalDb.upsertTagEntity(any()))
          .thenAnswer((_) async => 1);

      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});
    });
    tearDown(getIt.reset);

    testWidgets(
      'tag definition page is displayed with test item, '
      'then save button becomes visible editing tag name ',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: TagEditPage(
                tagEntity: testTag1,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('tag_name_field'));
        final saveButtonFinder = find.byKey(const Key('tag_save'));

        expect(nameFieldFinder, findsOneWidget);
        expect(find.text('SomeGenericTag'), findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(nameFieldFinder, 'EditedTag');
        await tester.pumpAndSettle();

        // save button is visible as there are unsaved changes
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'story tag definition page is displayed with test item, '
      'then save button becomes visible editing tag name ',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: TagEditPage(
                tagEntity: testStoryTag1,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('tag_name_field'));
        final saveButtonFinder = find.byKey(const Key('tag_save'));

        expect(nameFieldFinder, findsOneWidget);
        expect(find.text('Reading'), findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(nameFieldFinder, 'EditedTag');
        await tester.pumpAndSettle();

        // save button is visible as there are unsaved changes
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'person tag definition page is displayed with test tag, '
      'then save button becomes visible editing tag name ',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: TagEditPage(
                tagEntity: testPersonTag1,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('tag_name_field'));
        final saveButtonFinder = find.byKey(const Key('tag_save'));

        expect(nameFieldFinder, findsOneWidget);
        expect(find.text('Jane Doe'), findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(nameFieldFinder, 'EditedTag');
        await tester.pumpAndSettle();

        // save button is visible as there are unsaved changes
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
      },
    );
  });
}
