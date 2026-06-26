import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/fake_linked_entries_controller.dart';
import '../../../../../../mocks/mocks.dart';
import '../../../../../../widget_test_utils.dart';
import 'initial_modal_page_content_test_helpers.dart';

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockLinkService linkService;
  late ValueNotifier<int> pageIndexNotifier;

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    linkService = MockLinkService();
    pageIndexNotifier = ValueNotifier<int>(0);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(cacheService)
          ..registerSingleton<EditorStateService>(editorStateService)
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(journalDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(updateNotifications)
          ..registerSingleton<LinkService>(linkService);
      },
    );

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(any())).thenReturn(null);
  });

  tearDown(() async {
    pageIndexNotifier.dispose();
    await tearDownTestGetIt();
  });

  group('InitialModalPageContent set cover art for image linked to task', () {
    JournalImage imageEntry() {
      final now = DateTime(2023);
      return JournalImage(
        meta: Metadata(
          id: 'image-123',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: ImageData(
          imageId: 'img-uuid',
          imageFile: 'test.jpg',
          imageDirectory: '/tmp',
          capturedAt: now,
        ),
      );
    }

    ProviderScope buildImageLinkedWrapper({
      required JournalImage image,
      required JournalEntity linkedParent,
    }) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(image.id).overrideWith(
            () => TestEntryController(image),
          ),
          entryControllerProvider(linkedParent.id).overrideWith(
            () => TestEntryController(linkedParent),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value([]),
          ),
        ],
        child: makeTestableWidgetWithScaffold(
          InitialModalPageContent(
            entryId: image.id,
            linkedFromId: linkedParent.id,
            inLinkedEntries: true,
            link: null,
            pageIndexNotifier: pageIndexNotifier,
          ),
        ),
      );
    }

    testWidgets('shows set cover art item when image linked to a task', (
      tester,
    ) async {
      final image = imageEntry();
      final task = taskEntry();

      await tester.pumpWidget(
        buildImageLinkedWrapper(image: image, linkedParent: task),
      );
      await tester.pump();

      expect(find.text('Set cover'), findsOneWidget);
    });

    testWidgets('hides set cover art item when image linked to a non-task', (
      tester,
    ) async {
      final image = imageEntry();
      final parent = textEntry();

      await tester.pumpWidget(
        buildImageLinkedWrapper(image: image, linkedParent: parent),
      );
      await tester.pump();

      expect(find.text('Set cover'), findsNothing);
    });

    testWidgets('hides set cover art item when image has no linkedFromId', (
      tester,
    ) async {
      final image = imageEntry();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(image.id).overrideWith(
              () => TestEntryController(image),
            ),
            labelsStreamProvider.overrideWith(
              (ref) => Stream<List<LabelDefinition>>.value([]),
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            InitialModalPageContent(
              entryId: image.id,
              linkedFromId: null,
              inLinkedEntries: false,
              link: null,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Set cover'), findsNothing);
    });
  });

  group('InitialModalPageContent with geolocation', () {
    JournalEntry entryWithGeolocation() {
      final now = DateTime(2023);
      return JournalEntry(
        meta: Metadata(
          id: 'geo-entry-123',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        geolocation: Geolocation(
          createdAt: now,
          latitude: 52.52,
          longitude: 13.405,
          geohashString: 'u33dc0',
        ),
      );
    }

    ProviderScope buildGeoWrapper(JournalEntry entry) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(entry.id).overrideWith(
            () => TestEntryController(entry),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value([]),
          ),
        ],
        child: makeTestableWidgetWithScaffold(
          InitialModalPageContent(
            entryId: entry.id,
            linkedFromId: null,
            inLinkedEntries: false,
            link: null,
            pageIndexNotifier: pageIndexNotifier,
          ),
        ),
      );
    }

    testWidgets('shows map toggle item for entry with geolocation', (
      tester,
    ) async {
      final entry = entryWithGeolocation();

      await tester.pumpWidget(buildGeoWrapper(entry));
      await tester.pump();

      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });
  });

  group('InitialModalPageContent with linked context', () {
    ProviderScope buildLinkedWrapper({
      required JournalEntity entry,
      String? linkedFromId,
      EntryLink? link,
    }) {
      final baseOverrides = [
        entryControllerProvider(entry.id).overrideWith(
          () => TestEntryController(entry),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value([]),
        ),
      ];

      final allOverrides = [
        ...baseOverrides,
        if (linkedFromId != null) ...[
          entryControllerProvider(linkedFromId).overrideWith(
            () => TestEntryController(textEntry()),
          ),
          linkedEntriesControllerProvider(linkedFromId).overrideWith(
            FakeLinkedEntriesController.new,
          ),
        ],
      ];

      return ProviderScope(
        overrides: allOverrides,
        child: makeTestableWidgetWithScaffold(
          InitialModalPageContent(
            entryId: entry.id,
            linkedFromId: linkedFromId,
            inLinkedEntries: linkedFromId != null,
            link: link,
            pageIndexNotifier: pageIndexNotifier,
          ),
        ),
      );
    }

    testWidgets('shows unlink item when linkedFromId is provided', (
      tester,
    ) async {
      final entry = textEntry();

      await tester.pumpWidget(
        buildLinkedWrapper(entry: entry, linkedFromId: 'parent-123'),
      );
      await tester.pump();

      expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    });

    testWidgets('shows toggle hidden item when link is provided', (
      tester,
    ) async {
      final entry = textEntry();
      final now = DateTime(2023);
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'parent-123',
        toId: entry.id,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
        hidden: false,
      );

      await tester.pumpWidget(
        buildLinkedWrapper(
          entry: entry,
          linkedFromId: 'parent-123',
          link: link,
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });
  });
}
