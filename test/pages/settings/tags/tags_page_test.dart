import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/tags/tags_page.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TagsPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeTagEntity());
    });

    setUp(() {
      final mockTagsService = mockTagsServiceWithTags([]);
      final mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      final mockPersistenceLogic = MockPersistenceLogic();
      final settingsDb = SettingsDb(inMemoryDatabase: true);
      final secureStorageMock = MockSecureStorage();

      getIt
        ..registerSingleton<SecureStorage>(secureStorageMock)
        ..registerSingleton<SettingsDb>(settingsDb)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<NavService>(NavService())
        ..registerSingleton<TagsService>(mockTagsService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => secureStorageMock.readValue(lastRouteKey))
          .thenAnswer((_) async => '/settings');

      when(() => secureStorageMock.writeValue(lastRouteKey, any()))
          .thenAnswer((_) async {});

      when(mockJournalDb.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [
            testStoryTag1,
            testPersonTag1,
            testTag1,
          ]
        ]),
      );

      when(() => mockPersistenceLogic.upsertTagEntity(any()))
          .thenAnswer((_) async => 1);
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
              child: const TagsPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final genericTagFinder = find.text('SomeGenericTag');
        expect(genericTagFinder, findsOneWidget);

        final storyTagFinder = find.text('Reading');
        expect(storyTagFinder, findsOneWidget);

        final personTagFinder = find.text('Jane Doe');
        expect(personTagFinder, findsOneWidget);

        await tester.tap(genericTagFinder);
        await tester.pumpAndSettle();
      },
    );
  });
}
