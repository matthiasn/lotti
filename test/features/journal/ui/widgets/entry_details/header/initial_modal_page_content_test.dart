import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';
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

  ProviderScope buildWrapper(JournalEntity? entry) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: entry?.id ?? 'entry-123').overrideWith(
          () => TestEntryController(entry),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value([
            testLabelDefinition1,
            testLabelDefinition2,
          ]),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        InitialModalPageContent(
          entryId: entry?.id ?? 'entry-123',
          linkedFromId: null,
          inLinkedEntries: false,
          link: null,
          pageIndexNotifier: pageIndexNotifier,
        ),
      ),
    );
  }

  group('InitialModalPageContent ModernLabelsItem integration', () {
    testWidgets('shows Labels icon, text, and subtitle for non-task entries', (
      tester,
    ) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pump();

      expect(find.byIcon(MdiIcons.labelOutline), findsOneWidget);
      expect(find.text('Labels'), findsOneWidget);
      expect(
        find.text('Assign labels to organize this entry'),
        findsOneWidget,
      );
    });

    testWidgets('hides Labels action item for Task entries', (tester) async {
      await tester.pumpWidget(buildWrapper(taskEntry()));
      await tester.pump();
      expect(find.byIcon(MdiIcons.labelOutline), findsNothing);
    });

    testWidgets('hides Labels action item when entry is null', (tester) async {
      await tester.pumpWidget(buildWrapper(null));
      await tester.pump();
      expect(find.byIcon(MdiIcons.labelOutline), findsNothing);
    });
  });

  group('InitialModalPageContent ModernSetTaskLanguageItem integration', () {
    testWidgets('shows Set language action for tasks', (tester) async {
      await tester.pumpWidget(buildWrapper(taskEntry()));
      await tester.pump();

      expect(find.text('Set language'), findsOneWidget);
      expect(find.byIcon(Icons.language), findsOneWidget);
    });

    testWidgets(
      'renders a country flag when task has a language code set',
      (tester) async {
        await tester.pumpWidget(buildWrapper(taskEntry(languageCode: 'en')));
        await tester.pump();

        expect(find.text('Set language'), findsOneWidget);
        expect(find.byKey(const ValueKey('action-flag-en')), findsOneWidget);
        expect(find.byIcon(Icons.language), findsNothing);
      },
    );

    testWidgets('hides Set language action for non-task entries', (
      tester,
    ) async {
      await tester.pumpWidget(buildWrapper(textEntry()));
      await tester.pump();

      expect(find.text('Set language'), findsNothing);
    });
  });

  group('InitialModalPageContent link actions', () {
    testWidgets('renders both Link from and Link to items', (tester) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pump();

      expect(find.text('Link from'), findsOneWidget);
      expect(find.text('Link to'), findsOneWidget);
    });

    testWidgets(
      'a non-null link surfaces the toggle-hidden item; null hides it',
      (tester) async {
        final entry = textEntry();
        final link = EntryLink.basic(
          id: 'link-1',
          fromId: 'parent-1',
          toId: entry.id,
          createdAt: DateTime(2023),
          updatedAt: DateTime(2023),
          vectorClock: null,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryControllerProvider(id: entry.id).overrideWith(
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
                link: link,
                pageIndexNotifier: pageIndexNotifier,
              ),
            ),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(InitialModalPageContent));
        // A visible (non-hidden) link offers the hide action.
        expect(
          find.text(context.messages.journalHideLinkHint),
          findsOneWidget,
        );
      },
    );

    testWidgets('no toggle-hidden item without a link', (tester) async {
      await tester.pumpWidget(buildWrapper(textEntry()));
      await tester.pump();

      final context = tester.element(find.byType(InitialModalPageContent));
      expect(find.text(context.messages.journalHideLinkHint), findsNothing);
      expect(find.text(context.messages.journalShowLinkHint), findsNothing);
    });
  });

  group('InitialModalPageContent with audio entry', () {
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

    ProviderScope buildAudioWrapper(JournalAudio entry) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(id: entry.id).overrideWith(
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

    testWidgets('shows transcription, reveal, and share items for audio', (
      tester,
    ) async {
      final entry = audioEntry();

      await tester.pumpWidget(buildAudioWrapper(entry));
      await tester.pump();

      expect(find.byIcon(Icons.transcribe_rounded), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });
  });

  group('InitialModalPageContent with image entry', () {
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

    ProviderScope buildImageWrapper(JournalImage entry) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(id: entry.id).overrideWith(
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

    testWidgets('shows reveal, share, and copy items for image', (
      tester,
    ) async {
      final entry = imageEntry();

      await tester.pumpWidget(buildImageWrapper(entry));
      await tester.pump();

      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
      expect(find.byIcon(MdiIcons.contentCopy), findsOneWidget);
    });
  });
}
