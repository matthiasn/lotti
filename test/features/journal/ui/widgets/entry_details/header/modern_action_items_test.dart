import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/action_menu_list_item.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../helpers/fake_entry_controller.dart';
import '../../../../../../test_helper.dart';

class MockEditorStateService extends Mock implements EditorStateService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockLinkService extends Mock implements LinkService {}

void main() {
  final now = DateTime(2025, 12, 31, 12);

  late MockEditorStateService mockEditorStateService;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockLinkService mockLinkService;

  setUpAll(() {
    mockEditorStateService = MockEditorStateService();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockLinkService = MockLinkService();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<LinkService>(mockLinkService);
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  JournalEntry buildTextEntry({
    String id = 'entry-1',
    bool starred = false,
    bool private = false,
    EntryFlag? flag,
  }) {
    return JournalEntry(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        starred: starred,
        private: private,
        flag: flag,
      ),
    );
  }

  JournalImage buildImageEntry({String id = 'image-1'}) {
    return JournalImage(
      meta: Metadata(
        id: id,
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

  JournalAudio buildAudioEntry({String id = 'audio-1'}) {
    return JournalAudio(
      meta: Metadata(
        id: id,
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

  JournalEntry buildTextEntryWithGeolocation({String id = 'geo-entry-1'}) {
    return JournalEntry(
      meta: Metadata(
        id: id,
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

  group('ModernToggleStarredItem', () {
    testWidgets('renders with star outline icon when not starred',
        (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleStarredItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('renders with filled star icon when starred', (tester) async {
      final entry = buildTextEntry(starred: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleStarredItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('calls toggleStarred on tap', (tester) async {
      final entry = buildTextEntry();
      final (override, tracker) =
          createEntryControllerOverrideWithTracker(entry);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleStarredItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(tracker.toggleStarredCalls, contains('entry-1'));
    });
  });

  group('ModernTogglePrivateItem', () {
    testWidgets('renders with lock open icon when not private', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernTogglePrivateItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
    });

    testWidgets('renders with locked icon when private', (tester) async {
      final entry = buildTextEntry(private: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernTogglePrivateItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('calls togglePrivate on tap', (tester) async {
      final entry = buildTextEntry();
      final (override, tracker) =
          createEntryControllerOverrideWithTracker(entry);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernTogglePrivateItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(tracker.togglePrivateCalls, contains('entry-1'));
    });
  });

  group('ModernToggleFlaggedItem', () {
    testWidgets('renders with flag outline icon when not flagged',
        (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleFlaggedItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('renders with filled flag icon when flagged', (tester) async {
      final entry = buildTextEntry(flag: EntryFlag.import);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleFlaggedItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    });

    testWidgets('calls toggleFlagged on tap', (tester) async {
      final entry = buildTextEntry();
      final (override, tracker) =
          createEntryControllerOverrideWithTracker(entry);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleFlaggedItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(tracker.toggleFlaggedCalls, contains('entry-1'));
    });
  });

  group('ModernDeleteItem', () {
    testWidgets('renders with delete icon and destructive styling',
        (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernDeleteItem(entryId: 'entry-1', beamBack: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });
  });

  group('ModernSpeechItem', () {
    testWidgets('hidden for non-audio entries', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernSpeechItem(
            entryId: 'entry-1',
            pageIndexNotifier: ValueNotifier(0),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows for audio entries', (tester) async {
      final entry = buildAudioEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernSpeechItem(
            entryId: 'audio-1',
            pageIndexNotifier: ValueNotifier(0),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.transcribe_rounded), findsOneWidget);
    });

    testWidgets('sets pageIndexNotifier to 2 on tap', (tester) async {
      final entry = buildAudioEntry();
      final pageIndexNotifier = ValueNotifier(0);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernSpeechItem(
            entryId: 'audio-1',
            pageIndexNotifier: pageIndexNotifier,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, equals(2));
    });
  });

  group('ModernShareItem', () {
    testWidgets('hidden for text entries', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShareItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows for image entries', (tester) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShareItem(entryId: 'image-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('shows for audio entries', (tester) async {
      final entry = buildAudioEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShareItem(entryId: 'audio-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
    });
  });

  group('ModernTagAddItem', () {
    testWidgets('renders with label icon', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTagAddItem(pageIndexNotifier: ValueNotifier(0)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.label_outline_rounded), findsOneWidget);
    });

    testWidgets('sets pageIndexNotifier to 1 on tap', (tester) async {
      final pageIndexNotifier = ValueNotifier(0);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: ModernTagAddItem(pageIndexNotifier: pageIndexNotifier),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, equals(1));
    });
  });

  group('ModernCopyImageItem', () {
    testWidgets('hidden for non-image entries', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernCopyImageItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows for image entries', (tester) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernCopyImageItem(entryId: 'image-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(MdiIcons.contentCopy), findsOneWidget);
    });
  });

  group('ModernLinkFromItem', () {
    testWidgets('renders with add link icon', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: ModernLinkFromItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsOneWidget);
    });
  });

  group('ModernLinkToItem', () {
    testWidgets('renders with target icon', (tester) async {
      await tester.pumpWidget(
        const RiverpodWidgetTestBench(
          child: ModernLinkToItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(MdiIcons.target), findsOneWidget);
    });
  });

  group('ModernUnlinkItem', () {
    testWidgets('renders with unlink icon', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernUnlinkItem(
            entryId: 'entry-1',
            linkedFromId: 'parent-1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.link_off_rounded), findsOneWidget);
    });
  });

  group('ModernToggleHiddenItem', () {
    testWidgets('renders with visibility icon when not hidden', (tester) async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'parent-1',
        toId: 'entry-1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
        hidden: false,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            linkedEntriesControllerProvider(id: 'parent-1')
                .overrideWith(_FakeLinkedEntriesController.new),
          ],
          child: ModernToggleHiddenItem(link: link),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      expect(find.text('Hide link'), findsOneWidget);
    });

    testWidgets('renders with visibility_off icon when hidden', (tester) async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'parent-1',
        toId: 'entry-1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
        hidden: true,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            linkedEntriesControllerProvider(id: 'parent-1')
                .overrideWith(_FakeLinkedEntriesController.new),
          ],
          child: ModernToggleHiddenItem(link: link),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      expect(find.text('Show link'), findsOneWidget);
    });

    testWidgets('calls updateLink with toggled hidden on tap', (tester) async {
      final link = EntryLink.basic(
        id: 'link-1',
        fromId: 'parent-1',
        toId: 'entry-1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
        hidden: false,
      );

      final controller = _TrackingLinkedEntriesController();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            linkedEntriesControllerProvider(id: 'parent-1')
                .overrideWith(() => controller),
          ],
          child: ModernToggleHiddenItem(link: link),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(controller.updateLinkCalls, hasLength(1));
      expect(controller.updateLinkCalls.first.hidden, isTrue);
    });
  });

  group('ModernToggleMapItem', () {
    testWidgets('hidden when no geolocation', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleMapItem(entryId: 'entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows map_outlined icon when map not shown', (tester) async {
      final entry = buildTextEntryWithGeolocation();
      final (override, _) = createEntryControllerOverrideWithTracker(entry);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleMapItem(entryId: 'geo-entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('shows map_rounded icon when map shown', (tester) async {
      final entry = buildTextEntryWithGeolocation();
      final (override, _) =
          createEntryControllerOverrideWithTracker(entry, showMap: true);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleMapItem(entryId: 'geo-entry-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
    });

    testWidgets('calls toggleMapVisible on tap', (tester) async {
      final entry = buildTextEntryWithGeolocation();
      final (override, tracker) =
          createEntryControllerOverrideWithTracker(entry);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleMapItem(entryId: 'geo-entry-1'),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(tracker.toggleMapVisibleCalls, contains('geo-entry-1'));
    });
  });
}

class _FakeLinkedEntriesController extends LinkedEntriesController {
  @override
  Future<List<EntryLink>> build({required String id}) async => [];

  @override
  Future<void> updateLink(EntryLink link) async {}

  @override
  Future<void> removeLink({required String toId}) async {}
}

class _TrackingLinkedEntriesController extends LinkedEntriesController {
  final List<EntryLink> updateLinkCalls = [];

  @override
  Future<List<EntryLink>> build({required String id}) async => [];

  @override
  Future<void> updateLink(EntryLink link) async {
    updateLinkCalls.add(link);
  }

  @override
  Future<void> removeLink({required String toId}) async {}
}
