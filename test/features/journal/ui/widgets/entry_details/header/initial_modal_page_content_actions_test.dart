import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:material_ui/material_ui.dart';
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

      expect(find.byIcon(LottiIcons.map), findsOneWidget);
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

      expect(find.byIcon(LottiIcons.linkOff), findsOneWidget);
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

      expect(find.byIcon(LottiIcons.visible), findsOneWidget);
    });
  });

  group(
    'InitialModalPageContent generate cover art for audio linked to task',
    () {
      JournalAudio audioEntry() {
        final now = DateTime(2023);
        return JournalAudio(
          meta: Metadata(
            id: 'audio-123',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          data: AudioData(
            audioFile: 'test.m4a',
            audioDirectory: '/tmp',
            dateFrom: now,
            dateTo: now,
            duration: const Duration(seconds: 30),
          ),
        );
      }

      ProviderScope buildAudioLinkedWrapper({
        required JournalAudio audio,
        required JournalEntity linkedParent,
      }) {
        return ProviderScope(
          overrides: [
            entryControllerProvider(audio.meta.id).overrideWith(
              () => TestEntryController(audio),
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
              entryId: audio.meta.id,
              linkedFromId: linkedParent.id,
              inLinkedEntries: true,
              link: null,
              pageIndexNotifier: pageIndexNotifier,
            ),
          ),
        );
      }

      testWidgets('offers cover-art generation when audio hangs off a task', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildAudioLinkedWrapper(
            audio: audioEntry(),
            linkedParent: taskEntry(),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(InitialModalPageContent));
        expect(find.text(context.messages.generateCoverArt), findsOneWidget);
        // Runs in place rather than opening a surface, so no trailing glyph.
        final row = tester.widget<DsActionRow>(
          find.ancestor(
            of: find.text(context.messages.generateCoverArt),
            matching: find.byType(DsActionRow),
          ),
        );
        expect(row.trailing, DsActionRowTrailing.none);
      });

      testWidgets('withholds it when the audio hangs off a non-task', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildAudioLinkedWrapper(
            audio: audioEntry(),
            linkedParent: textEntry(),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(InitialModalPageContent));
        expect(find.text(context.messages.generateCoverArt), findsNothing);
      });
    },
  );

  group('InitialModalPageContent rate session', () {
    ProviderScope buildRatingWrapper({
      required bool inLinkedEntries,
      required bool ratingsEnabled,
    }) {
      final entry = textEntry();
      return ProviderScope(
        overrides: [
          entryControllerProvider(entry.id).overrideWith(
            () => TestEntryController(entry),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value([]),
          ),
          configFlagProvider.overrideWith(
            (ref, flagName) => Stream.value(ratingsEnabled),
          ),
          ratingControllerProvider(
            targetId: entry.id,
          ).overrideWith(_NoRatingController.new),
        ],
        child: makeTestableWidgetWithScaffold(
          InitialModalPageContent(
            entryId: entry.id,
            linkedFromId: null,
            inLinkedEntries: inLinkedEntries,
            link: null,
            pageIndexNotifier: pageIndexNotifier,
          ),
        ),
      );
    }

    testWidgets('offers the rating row for a time entry read from its task', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildRatingWrapper(inLinkedEntries: true, ratingsEnabled: true),
      );
      await tester.pump();

      final context = tester.element(find.byType(InitialModalPageContent));
      expect(
        find.text(context.messages.sessionRatingRateAction),
        findsOneWidget,
      );
    });

    testWidgets('withholds it with the flag off', (tester) async {
      await tester.pumpWidget(
        buildRatingWrapper(inLinkedEntries: true, ratingsEnabled: false),
      );
      await tester.pump();

      final context = tester.element(find.byType(InitialModalPageContent));
      expect(find.text(context.messages.sessionRatingRateAction), findsNothing);
    });

    testWidgets('withholds it outside a linked context', (tester) async {
      await tester.pumpWidget(
        buildRatingWrapper(inLinkedEntries: false, ratingsEnabled: true),
      );
      await tester.pump();

      final context = tester.element(find.byType(InitialModalPageContent));
      expect(find.text(context.messages.sessionRatingRateAction), findsNothing);
    });
  });
}

/// A rating controller that reports no rating yet, so the row reads "Rate
/// Session" rather than "View Rating".
class _NoRatingController extends RatingController {
  @override
  Future<JournalEntity?> build() async {
    state = const AsyncData(null);
    return null;
  }
}
