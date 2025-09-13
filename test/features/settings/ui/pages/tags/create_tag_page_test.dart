import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/tags/create_tag_page.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockTagsService = MockTagsService();
  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('CreateTagPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(fallbackTagEntity);
      registerFallbackValue(fallbackSyncMessage);
    });

    setUp(() {
      mockTagsService = mockTagsServiceWithTags([]);
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      final mockOutboxService = MockOutboxService();

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
      'create generic tag, enter text then save button becomes visible',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const CreateTagPage(tagType: 'TAG'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('tag_name_field'));
        final saveButtonFinder = find.byKey(const Key('tag_save'));

        expect(nameFieldFinder, findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(nameFieldFinder, 'NewGenericTag');

        await tester.pumpAndSettle();

        expect(find.text('NewGenericTag'), findsOneWidget);

        // save button is visible as there are unsaved changes
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'create person tag, enter text then save button becomes visible',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const CreateTagPage(tagType: 'PERSON'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('tag_name_field'));
        final saveButtonFinder = find.byKey(const Key('tag_save'));

        expect(nameFieldFinder, findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(nameFieldFinder, 'NewPersonTag');

        await tester.pumpAndSettle();

        expect(find.text('NewPersonTag'), findsOneWidget);

        // save button is visible as there are unsaved changes
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'create story tag, enter text then save button becomes visible',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: const CreateTagPage(tagType: 'STORY'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final nameFieldFinder = find.byKey(const Key('tag_name_field'));
        final saveButtonFinder = find.byKey(const Key('tag_save'));

        expect(nameFieldFinder, findsOneWidget);

        // save button is invisible - no changes yet
        expect(saveButtonFinder, findsNothing);

        await tester.enterText(nameFieldFinder, 'NewStoryTag');

        await tester.pumpAndSettle();

        expect(find.text('NewStoryTag'), findsOneWidget);

        // save button is visible as there are unsaved changes
        expect(saveButtonFinder, findsOneWidget);

        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
      },
    );
  });
}
