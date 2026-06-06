import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill_localizations;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/action_menu_list_item.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/media_file_actions.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
// SharePlatform is only re-exported from share_plus with a `show` clause that
// omits it, so the platform interface package is imported directly here to
// install a fake instance. It is a transitive dependency of share_plus.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart'
    show SharePlatform;

import '../../../../../../helpers/fake_entry_controller.dart';
import '../../../../../../helpers/fake_linked_entries_controller.dart';
import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';
import '../../../../../../test_helper.dart';
import '../../../../../../widget_test_utils.dart';

/// Builds a widget wrapped in a pushed Navigator route so that
/// Navigator.of(context).pop() can be exercised during tests.
Widget _buildWithRoute({
  required Widget child,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          // Immediately push a route containing the child widget,
          // so Navigator.pop() has a route to dismiss.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(body: child),
              ),
            );
          });
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
}

void main() {
  final now = DateTime(2025, 12, 31, 12);

  late Directory documentsDirectory;
  late _FakeSharePlatform fakeSharePlatform;

  setUpAll(() async {
    documentsDirectory = Directory.systemTemp.createTempSync(
      'modern_action_items_test_',
    );

    // Install a fake share platform before `SharePlus.instance` is first
    // accessed, so its lazily-initialized singleton captures this fake.
    // The production `ModernShareItem` calls `SharePlus.instance.share(...)`.
    fakeSharePlatform = _FakeSharePlatform();
    SharePlatform.instance = fakeSharePlatform;

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<LinkService>(MockLinkService())
          ..registerSingleton<Directory>(documentsDirectory);
      },
    );
  });

  tearDownAll(() async {
    await tearDownTestGetIt();
    if (documentsDirectory.existsSync()) {
      documentsDirectory.deleteSync(recursive: true);
    }
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
        imageDirectory: '/images/',
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
        audioDirectory: '/audio/',
        dateFrom: now,
        dateTo: now,
        duration: const Duration(seconds: 30),
      ),
    );
  }

  Task buildTaskEntry({String id = 'task-1', String? languageCode}) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
        title: 'Test Task',
        languageCode: languageCode,
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
    testWidgets('renders with star outline icon when not starred', (
      tester,
    ) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleStarredItem(entryId: 'entry-1'),
        ),
      );

      await tester.pump();

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

      await tester.pump();

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('calls toggleStarred on tap', (tester) async {
      final entry = buildTextEntry();
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        entry,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleStarredItem(entryId: 'entry-1'),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

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

      await tester.pump();

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

      await tester.pump();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('calls togglePrivate on tap', (tester) async {
      final entry = buildTextEntry();
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        entry,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernTogglePrivateItem(entryId: 'entry-1'),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(tracker.togglePrivateCalls, contains('entry-1'));
    });
  });

  group('ModernToggleFlaggedItem', () {
    testWidgets('renders with flag outline icon when not flagged', (
      tester,
    ) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernToggleFlaggedItem(entryId: 'entry-1'),
        ),
      );

      await tester.pump();

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

      await tester.pump();

      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    });

    testWidgets('calls toggleFlagged on tap', (tester) async {
      final entry = buildTextEntry();
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        entry,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleFlaggedItem(entryId: 'entry-1'),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(tracker.toggleFlaggedCalls, contains('entry-1'));
    });
  });

  group('ModernDeleteItem', () {
    testWidgets('renders with delete icon and destructive styling', (
      tester,
    ) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernDeleteItem(entryId: 'entry-1', beamBack: true),
        ),
      );

      await tester.pump();

      final item = tester.widget<ActionMenuListItem>(
        find.byType(ActionMenuListItem),
      );
      expect(item.isDestructive, isTrue);
      expect(item.title, 'Delete entry');
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

      await tester.pump();

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

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.transcribe_rounded), findsOneWidget);
    });

    testWidgets('sets pageIndexNotifier to the speech page on tap', (
      tester,
    ) async {
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

      await tester.pump();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(pageIndexNotifier.value, equals(1));
    });
  });

  group('ModernShowInFileManagerItem', () {
    testWidgets('hidden for text entries', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShowInFileManagerItem(entryId: 'entry-1'),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('hidden on unsupported platforms', (tester) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShowInFileManagerItem(
            entryId: 'image-1',
            platform: MediaFilePlatform.unsupported,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('uses Finder wording on macOS', (tester) async {
      final entry = buildAudioEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShowInFileManagerItem(
            entryId: 'audio-1',
            platform: MediaFilePlatform.macos,
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      expect(find.text('Show in Finder'), findsOneWidget);
    });

    testWidgets('uses File Explorer wording on Windows', (tester) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShowInFileManagerItem(
            entryId: 'image-1',
            platform: MediaFilePlatform.windows,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Show in File Explorer'), findsOneWidget);
    });

    testWidgets('uses Files wording on Linux', (tester) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShowInFileManagerItem(
            entryId: 'image-1',
            platform: MediaFilePlatform.linux,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Show in Files'), findsOneWidget);
    });

    testWidgets('uses MediaFileActions when no callback is injected', (
      tester,
    ) async {
      final entry = buildImageEntry();
      final runner = _RecordingProcessRunner();

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernShowInFileManagerItem(
            entryId: 'image-1',
            fileActions: MediaFileActions(processRunner: runner.call),
            platform: MediaFilePlatform.windows,
          ),
        ),
      );

      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(runner.calls, [
        _ProcessCall(
          'explorer.exe',
          ['/select,"${documentsDirectory.path}/images/test.jpg"'],
        ),
      ]);
    });

    testWidgets('reveals image file path on tap', (tester) async {
      final entry = buildImageEntry();
      String? revealedPath;

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernShowInFileManagerItem(
            entryId: 'image-1',
            platform: MediaFilePlatform.macos,
            onShowInFileManager: (filePath) async {
              revealedPath = filePath;
            },
          ),
        ),
      );

      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(revealedPath, '${documentsDirectory.path}/images/test.jpg');
    });

    testWidgets('reveals audio file path on tap', (tester) async {
      final entry = buildAudioEntry();
      String? revealedPath;

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernShowInFileManagerItem(
            entryId: 'audio-1',
            platform: MediaFilePlatform.macos,
            onShowInFileManager: (filePath) async {
              revealedPath = filePath;
            },
          ),
        ),
      );

      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(revealedPath, '${documentsDirectory.path}/audio/test.m4a');
    });

    testWidgets('captures reveal failures without bubbling to the widget', (
      tester,
    ) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [createEntryControllerOverride(entry)],
          child: ModernShowInFileManagerItem(
            entryId: 'image-1',
            platform: MediaFilePlatform.macos,
            onShowInFileManager: (_) async => throw StateError('boom'),
          ),
        ),
      );

      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(tester.takeException(), isNull);
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

      await tester.pump();

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

      await tester.pump();

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

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
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

      await tester.pump();

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

      await tester.pump();

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

      await tester.pump();

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

      await tester.pump();

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

      await tester.pump();

      final item = tester.widget<ActionMenuListItem>(
        find.byType(ActionMenuListItem),
      );
      expect(item.title, 'Unlink');
      // Unlinking is reversible — the row itself is not styled destructive
      // (the confirmation modal carries the destructive action instead).
      expect(item.isDestructive, isFalse);
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
            linkedEntriesControllerProvider(
              id: 'parent-1',
            ).overrideWith(FakeLinkedEntriesController.new),
          ],
          child: ModernToggleHiddenItem(link: link),
        ),
      );

      await tester.pump();

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
            linkedEntriesControllerProvider(
              id: 'parent-1',
            ).overrideWith(FakeLinkedEntriesController.new),
          ],
          child: ModernToggleHiddenItem(link: link),
        ),
      );

      await tester.pump();

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

      final controller = FakeLinkedEntriesController();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            linkedEntriesControllerProvider(
              id: 'parent-1',
            ).overrideWith(() => controller),
          ],
          child: ModernToggleHiddenItem(link: link),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(controller.updateLinkCalls, hasLength(1));
      expect(controller.updateLinkCalls.first.hidden, isTrue);
    });
  });

  Task buildTask({String? coverArtId, String id = 'task-1'}) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
        coverArtId: coverArtId,
      ),
    );
  }

  group('ModernSetCoverArtItem', () {
    testWidgets('hidden when parent is not a Task', (tester) async {
      final textEntry = buildTextEntry(id: 'parent-1');

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(textEntry)],
          child: const ModernSetCoverArtItem(
            entryId: 'image-1',
            linkedFromId: 'parent-1',
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows outlined image icon when not current cover', (
      tester,
    ) async {
      final task = buildTask();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(task)],
          child: const ModernSetCoverArtItem(
            entryId: 'image-1',
            linkedFromId: 'task-1',
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('Set cover'), findsOneWidget);
    });

    testWidgets('shows filled image icon when image is current cover', (
      tester,
    ) async {
      final task = buildTask(coverArtId: 'image-1');

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(task)],
          child: const ModernSetCoverArtItem(
            entryId: 'image-1',
            linkedFromId: 'task-1',
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
    });

    testWidgets('calls setCoverArt with entryId and pops navigator', (
      tester,
    ) async {
      final task = buildTask();
      final (override, tracker) = createTrackingEntryControllerOverride(task);

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [override],
          child: const ModernSetCoverArtItem(
            entryId: 'image-1',
            linkedFromId: 'task-1',
          ),
        ),
      );

      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      // Verify we're on the pushed route
      expect(find.byType(ActionMenuListItem), findsOneWidget);

      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(tracker.calls, contains('image-1'));
      // Navigator.pop should have dismissed the route
      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('calls setCoverArt with null and pops navigator', (
      tester,
    ) async {
      final task = buildTask(coverArtId: 'image-1');
      final (override, tracker) = createTrackingEntryControllerOverride(task);

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [override],
          child: const ModernSetCoverArtItem(
            entryId: 'image-1',
            linkedFromId: 'task-1',
          ),
        ),
      );

      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      expect(tracker.calls, contains(null));
      // Navigator.pop should have dismissed the route
      expect(find.byType(ActionMenuListItem), findsNothing);
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

      await tester.pump();

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

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    });

    testWidgets('shows map_rounded icon when map shown', (tester) async {
      final entry = buildTextEntryWithGeolocation();
      final (override, _) = createEntryControllerOverrideWithTracker(
        entry,
        showMap: true,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleMapItem(entryId: 'geo-entry-1'),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
    });

    testWidgets('calls toggleMapVisible on tap', (tester) async {
      final entry = buildTextEntryWithGeolocation();
      final (override, tracker) = createEntryControllerOverrideWithTracker(
        entry,
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [override],
          child: const ModernToggleMapItem(entryId: 'geo-entry-1'),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pump();

      expect(tracker.toggleMapVisibleCalls, contains('geo-entry-1'));
    });
  });

  group('ModernSetTaskLanguageItem', () {
    testWidgets('renders nothing for non-task entries', (tester) async {
      final entry = buildTextEntry();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernSetTaskLanguageItem(entryId: 'entry-1'),
        ),
      );
      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets(
      'renders a generic language icon when the task has no language code',
      (tester) async {
        final task = buildTaskEntry();

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [createEntryControllerOverride(task)],
            child: const ModernSetTaskLanguageItem(entryId: 'task-1'),
          ),
        );
        await tester.pump();

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        expect(find.byIcon(Icons.language), findsOneWidget);
      },
    );

    testWidgets(
      'renders a country flag when a language code is set',
      (tester) async {
        final task = buildTaskEntry(languageCode: 'de');

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [createEntryControllerOverride(task)],
            child: const ModernSetTaskLanguageItem(entryId: 'task-1'),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('action-flag-de')), findsOneWidget);
        expect(find.byIcon(Icons.language), findsNothing);
      },
    );

    testWidgets(
      'tapping the row opens the language selection modal and persists the choice',
      (tester) async {
        final task = buildTaskEntry();
        final (override, tracker) = createEntryControllerOverrideWithTracker(
          task,
        );

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [override],
            child: const ModernSetTaskLanguageItem(entryId: 'task-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Language modal is open. Arabic sorts first alphabetically when no
        // language is currently selected, so it's visible without scrolling.
        final arabic = find.text('Arabic');
        expect(arabic, findsOneWidget);
        await tester.tap(arabic);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tracker.updateTaskLanguageCalls, equals(['ar']));
      },
    );

    testWidgets(
      'tapping Clear in the modal persists null',
      (tester) async {
        final task = buildTaskEntry(languageCode: 'de');
        final (override, tracker) = createEntryControllerOverrideWithTracker(
          task,
        );

        // Use a large test surface so the Clear row at the bottom of the
        // modal is not clipped off-screen and we don't have to drive the
        // scrollable to reach it.
        await tester.binding.setSurfaceSize(const Size(800, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [override],
            child: const ModernSetTaskLanguageItem(entryId: 'task-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Clear'), findsOneWidget);
        await tester.tap(find.text('Clear'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tracker.updateTaskLanguageCalls, equals([null]));
      },
    );
  });

  group('ModernDeleteItem — modal interaction', () {
    testWidgets(
      'confirming delete calls notifier.delete and dismisses route',
      (tester) async {
        final entry = buildTextEntry();
        final controller = _DeletingFakeEntryController(entry);

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              entryControllerProvider(
                id: 'entry-1',
              ).overrideWith(() => controller),
            ],
            child: const ModernDeleteItem(entryId: 'entry-1', beamBack: false),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The confirmation modal is visible.
        expect(find.text('YES, DELETE THIS ENTRY'), findsOneWidget);
        await tester.tap(find.text('YES, DELETE THIS ENTRY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.deleteCalls, equals(1));
      },
    );

    testWidgets(
      'dismissing the modal without confirming does not call delete',
      (tester) async {
        final entry = buildTextEntry();
        final controller = _DeletingFakeEntryController(entry);

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              entryControllerProvider(
                id: 'entry-1',
              ).overrideWith(() => controller),
            ],
            child: const ModernDeleteItem(entryId: 'entry-1', beamBack: false),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dismiss modal by tapping the barrier.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.deleteCalls, equals(0));
      },
    );
  });

  group('ModernUnlinkItem — modal interaction', () {
    testWidgets(
      'confirming unlink calls removeLink with the correct entry id',
      (tester) async {
        final controller = _RemoveLinkTrackingController();

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              linkedEntriesControllerProvider(
                id: 'parent-1',
              ).overrideWith(() => controller),
            ],
            child: const ModernUnlinkItem(
              entryId: 'entry-1',
              linkedFromId: 'parent-1',
            ),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pumpAndSettle();

        // Confirmation modal is shown.
        expect(find.text('YES, UNLINK ENTRY'), findsOneWidget);
        await tester.tap(find.text('YES, UNLINK ENTRY'));
        await tester.pumpAndSettle();

        expect(controller.removeLinkCalls, contains('entry-1'));
        // After confirming, the route is dismissed.
        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );

    testWidgets(
      'dismissing unlink modal without confirming skips removeLink',
      (tester) async {
        final controller = _RemoveLinkTrackingController();

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              linkedEntriesControllerProvider(
                id: 'parent-1',
              ).overrideWith(() => controller),
            ],
            child: const ModernUnlinkItem(
              entryId: 'entry-1',
              linkedFromId: 'parent-1',
            ),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dismiss without confirming.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.removeLinkCalls, isEmpty);
      },
    );
  });

  group('ModernCopyImageItem — tap behavior', () {
    testWidgets(
      'tapping calls copyImage on the notifier and pops the route',
      (tester) async {
        final entry = buildImageEntry();
        final controller = _CopyImageFakeEntryController(entry);

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              entryControllerProvider(
                id: 'image-1',
              ).overrideWith(() => controller),
            ],
            child: const ModernCopyImageItem(entryId: 'image-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pumpAndSettle();

        expect(controller.copyImageCalls, equals(1));
        // Navigator.pop should have dismissed the route.
        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );
  });

  group('ModernLinkFromItem — tap behavior', () {
    testWidgets('tapping calls linkFrom and pops the route', (tester) async {
      final mockLinkService = getIt<LinkService>() as MockLinkService;
      when(
        () => mockLinkService.linkFrom(any()),
      ).thenReturn(null);

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [],
          child: const ModernLinkFromItem(entryId: 'entry-42'),
        ),
      );
      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      verify(() => mockLinkService.linkFrom('entry-42')).called(1);
      // Route is dismissed after tap.
      expect(find.byType(ActionMenuListItem), findsNothing);
    });
  });

  group('ModernLinkToItem — tap behavior', () {
    testWidgets('tapping calls linkTo and pops the route', (tester) async {
      final mockLinkService = getIt<LinkService>() as MockLinkService;
      when(
        () => mockLinkService.linkTo(any()),
      ).thenReturn(null);

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [],
          child: const ModernLinkToItem(entryId: 'entry-99'),
        ),
      );
      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ActionMenuListItem), findsOneWidget);
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      verify(() => mockLinkService.linkTo('entry-99')).called(1);
      expect(find.byType(ActionMenuListItem), findsNothing);
    });
  });

  group('ModernRateSessionItem — tap behavior', () {
    testWidgets(
      'tapping opens the rating bottom sheet when enabled and no rating exists',
      (tester) async {
        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              ratingControllerProvider(
                targetId: 'entry-1',
              ).overrideWith(_FakeNoRatingController.new),
            ],
            child: const ModernRateSessionItem(entryId: 'entry-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pumpAndSettle();

        // The rating modal shows up — route is dismissed and modal appears.
        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );

    testWidgets(
      'tapping with existing rating also opens the rating modal',
      (tester) async {
        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              ratingControllerProvider(
                targetId: 'entry-1',
              ).overrideWith(_FakeHasRatingController.new),
            ],
            child: const ModernRateSessionItem(entryId: 'entry-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pumpAndSettle();

        // After tap, the action item route is dismissed.
        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );
  });

  group('ModernShareItem — onTap navigator pop', () {
    testWidgets(
      'tapping share item for image pops the route',
      (tester) async {
        final entry = buildImageEntry();

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [createEntryControllerOverride(entry)],
            child: const ModernShareItem(entryId: 'image-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pumpAndSettle();

        // Navigator.pop was called, route is dismissed.
        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );

    testWidgets(
      'tapping share item for audio pops the route',
      (tester) async {
        final entry = buildAudioEntry();

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [createEntryControllerOverride(entry)],
            child: const ModernShareItem(entryId: 'audio-1'),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        await tester.pumpAndSettle();

        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );
  });

  group('ModernGenerateCoverArtItem — tap behavior', () {
    testWidgets(
      'tapping pops the current route when audio is linked to a task',
      (tester) async {
        final audio = buildAudioEntry();
        final task = buildTaskEntry();

        await tester.pumpWidget(
          _buildWithRoute(
            overrides: [
              createEntryControllerOverride(audio),
              createEntryControllerOverride(task),
            ],
            child: const ModernGenerateCoverArtItem(
              entryId: 'audio-1',
              linkedFromId: 'task-1',
            ),
          ),
        );
        // One frame fires the post-frame route push; the second advances
        // past the MaterialPageRoute transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ActionMenuListItem), findsOneWidget);
        await tester.tap(find.byType(ActionMenuListItem));
        // Allow the pop animation to complete; stop before the
        // CoverArtSkillModal needs a full AI-config setup.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // The original route is gone (Navigator.pop() ran).
        expect(find.byType(ActionMenuListItem), findsNothing);
      },
    );
  });

  group('ModernShareItem — onTap shares the media file', () {
    // On Linux/Windows the production handler returns before reaching the
    // share call (lines 363-365). Force the non-Linux/Windows branch so the
    // `JournalImage` / `JournalAudio` share blocks (lines 367-373) execute.
    setUp(() {
      final prevIsLinux = platform.isLinux;
      final prevIsWindows = platform.isWindows;
      platform.isLinux = false;
      platform.isWindows = false;
      fakeSharePlatform.reset();
      addTearDown(() {
        platform.isLinux = prevIsLinux;
        platform.isWindows = prevIsWindows;
      });
    });

    testWidgets('shares the full image path for image entries', (tester) async {
      final entry = buildImageEntry();

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShareItem(entryId: 'image-1'),
        ),
      );
      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      final expectedPath = '${getDocumentsDirectory().path}/images/test.jpg';
      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, isNotNull);
      expect(params.files!.map((f) => f.path), [expectedPath]);
      // The route is also dismissed (Navigator.pop ran first).
      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shares the full audio path for audio entries', (tester) async {
      final entry = buildAudioEntry();

      await tester.pumpWidget(
        _buildWithRoute(
          overrides: [createEntryControllerOverride(entry)],
          child: const ModernShareItem(entryId: 'audio-1'),
        ),
      );
      // One frame fires the post-frame route push; the second advances
      // past the MaterialPageRoute transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      final expectedPath = '${getDocumentsDirectory().path}/audio/test.m4a';
      final params = fakeSharePlatform.lastParams;
      expect(params, isNotNull);
      expect(params!.files, isNotNull);
      expect(params.files!.map((f) => f.path), [expectedPath]);
      expect(find.byType(ActionMenuListItem), findsNothing);
    });
  });

  group('ModernGenerateCoverArtItem - Satellite Tests', () {
    final now = DateTime(2025, 12, 31, 12);

    late MockEditorStateService mockEditorStateServiceSrc;
    late MockPersistenceLogic mockPersistenceLogicSrc;
    late MockJournalDb mockJournalDbSrc;
    late MockUpdateNotifications mockUpdateNotificationsSrc;

    setUpAll(() {
      mockEditorStateServiceSrc = MockEditorStateService();
      mockPersistenceLogicSrc = MockPersistenceLogic();
      mockJournalDbSrc = MockJournalDb();
      mockUpdateNotificationsSrc = MockUpdateNotifications();

      when(
        () => mockUpdateNotificationsSrc.updateStream,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());

      getIt.allowReassignment = true;
      getIt
        ..registerSingleton<EditorStateService>(mockEditorStateServiceSrc)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogicSrc)
        ..registerSingleton<JournalDb>(mockJournalDbSrc)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotificationsSrc);
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    JournalAudio buildAudioEntrySrc({String id = 'audio-1'}) {
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

    Task buildTaskSrc({String id = 'task-1'}) {
      return Task(
        meta: Metadata(
          id: id,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          categoryId: 'category-1',
        ),
        data: TaskData(
          title: 'Test Task',
          checklistIds: const [],
          status: TaskStatus.open(
            id: 'status',
            createdAt: now,
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: now,
          dateTo: now,
        ),
      );
    }

    JournalImage buildImageEntrySrc({String id = 'image-1'}) {
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

    testWidgets('shows SizedBox.shrink for non-audio entry', (tester) async {
      final imageEntry = buildImageEntrySrc();
      final task = buildTaskSrc();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(imageEntry),
            createEntryControllerOverride(task),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'image-1',
              linkedFromId: 'task-1',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows SizedBox.shrink when linkedFromId is null', (
      tester,
    ) async {
      final audioEntry = buildAudioEntrySrc();

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(audioEntry),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'audio-1',
              linkedFromId: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows SizedBox.shrink when linked entry is not a Task', (
      tester,
    ) async {
      final audioEntry = buildAudioEntrySrc();
      final linkedImage = buildImageEntrySrc(id: 'linked-image');

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            createEntryControllerOverride(audioEntry),
            createEntryControllerOverride(linkedImage),
          ],
          child: const Scaffold(
            body: ModernGenerateCoverArtItem(
              entryId: 'audio-1',
              linkedFromId: 'linked-image',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('renders action item when audio linked to task', (
      tester,
    ) async {
      final audioEntry = buildAudioEntrySrc();
      final task = buildTaskSrc();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(audioEntry),
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernGenerateCoverArtItem(
                entryId: 'audio-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(ModernGenerateCoverArtItem), findsOneWidget);
      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    });

    testWidgets('action item displays correct labels', (tester) async {
      final audioEntry = buildAudioEntrySrc();
      final task = buildTaskSrc();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(audioEntry),
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ModernGenerateCoverArtItem(
                entryId: 'audio-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Generate Cover Art'), findsOneWidget);
      expect(find.text('Create image from voice description'), findsOneWidget);
    });

    test('requires entryId parameter', () {
      const widget = ModernGenerateCoverArtItem(
        entryId: 'audio-1',
        linkedFromId: 'task-1',
      );

      expect(widget.entryId, 'audio-1');
      expect(widget.linkedFromId, 'task-1');
    });

    test('linkedFromId can be null', () {
      const widget = ModernGenerateCoverArtItem(
        entryId: 'audio-1',
        linkedFromId: null,
      );

      expect(widget.entryId, 'audio-1');
      expect(widget.linkedFromId, isNull);
    });
  });

  group('ModernLabelsItem - Satellite Tests', () {
    late MockEntitiesCacheService cacheService;
    late MockEditorStateService editorStateService;
    late MockJournalDb journalDb;
    late MockUpdateNotifications updateNotifications;
    late _MockLabelsRepository repository;

    setUpAll(() {
      registerFallbackValue(testLabelDefinition1);
    });

    setUp(() async {
      cacheService = MockEntitiesCacheService();
      editorStateService = MockEditorStateService();
      journalDb = MockJournalDb();
      updateNotifications = MockUpdateNotifications();
      repository = _MockLabelsRepository();

      await getIt.reset();
      getIt
        ..registerSingleton<EntitiesCacheService>(cacheService)
        ..registerSingleton<EditorStateService>(editorStateService)
        ..registerSingleton<JournalDb>(journalDb)
        ..registerSingleton<UpdateNotifications>(updateNotifications);

      when(() => cacheService.showPrivateEntries).thenReturn(true);
      when(
        () => cacheService.filterLabelsForCategory(any(), any()),
      ).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as List<LabelDefinition>,
      );
      when(
        () => cacheService.getLabelById(testLabelDefinition1.id),
      ).thenReturn(testLabelDefinition1);
      when(
        () => cacheService.getLabelById(testLabelDefinition2.id),
      ).thenReturn(testLabelDefinition2);
      when(
        () => cacheService.sortedLabels,
      ).thenReturn([testLabelDefinition1, testLabelDefinition2]);
    });

    tearDown(() async {
      await getIt.reset();
    });

    /// Builds a widget tree that properly handles the Navigator.pop() call
    /// that ModernLabelsItem makes when opening the labels modal.
    ProviderScope buildWrapper(JournalEntity entry) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(id: entry.id).overrideWith(
            () => _TestEntryController(entry),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(
              [testLabelDefinition1, testLabelDefinition2],
            ),
          ),
          labelsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FormBuilderLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        child: SingleChildScrollView(
                          child: ModernLabelsItem(entryId: entry.id),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Simple wrapper for testing widget visibility only (no modal interaction)
    ProviderScope buildSimpleWrapper(JournalEntity entry) {
      return ProviderScope(
        overrides: [
          entryControllerProvider(id: entry.id).overrideWith(
            () => _TestEntryController(entry),
          ),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(
              [testLabelDefinition1, testLabelDefinition2],
            ),
          ),
          labelsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FormBuilderLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ModernLabelsItem(entryId: entry.id),
              ),
            ),
          ),
        ),
      );
    }

    JournalEntity textEntryWithLabels(List<String> labelIds) {
      final testDate = DateTime(2023);
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: 'entry-123',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          labelIds: labelIds,
        ),
      );
    }

    JournalEntity taskWithLabels(List<String> labelIds) {
      final testDate = DateTime(2023);
      return JournalEntity.task(
        meta: Metadata(
          id: 'task-123',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          labelIds: labelIds,
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: testDate.timeZoneOffset.inMinutes,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Sample task',
        ),
      );
    }

    group('ModernLabelsItem visibility', () {
      testWidgets('shows for non-task entries', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildSimpleWrapper(entry));
        await tester.pump();

        expect(find.text('Labels'), findsOneWidget);
      });

      testWidgets('is hidden for Task entries', (tester) async {
        final task = taskWithLabels(const []);

        await tester.pumpWidget(buildSimpleWrapper(task));
        await tester.pump();

        expect(find.text('Labels'), findsNothing);
      });

      testWidgets('shows subtitle text', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildSimpleWrapper(entry));
        await tester.pump();

        expect(
          find.text('Assign labels to organize this entry'),
          findsOneWidget,
        );
      });

      testWidgets('shows label icon', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildSimpleWrapper(entry));
        await tester.pump();

        expect(find.byType(Icon), findsWidgets);
      });
    });

    group('Labels modal opening', () {
      testWidgets('tapping opens labels modal', (tester) async {
        final entry = textEntryWithLabels(['label-1']);
        when(
          () => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
      });

      testWidgets('modal shows search bar', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('passes entry categoryId to selector', (tester) async {
        final entry = textEntryWithLabels(const []).copyWith(
          meta: textEntryWithLabels(const []).meta.copyWith(categoryId: 'work'),
        );

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final content = tester.widget<LabelSelectionSliverContent>(
          find.byType(LabelSelectionSliverContent),
        );
        expect(content.categoryId, equals('work'));
      });

      testWidgets('passes null categoryId when entry has none', (tester) async {
        final entry = textEntryWithLabels(const []).copyWith(
          meta: textEntryWithLabels(const []).meta.copyWith(categoryId: null),
        );

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final content = tester.widget<LabelSelectionSliverContent>(
          find.byType(LabelSelectionSliverContent),
        );
        expect(content.categoryId, isNull);
      });
    });

    group('Modal actions', () {
      testWidgets('modal shows cancel button', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      });

      testWidgets('apply button saves labels and closes modal', (tester) async {
        final entry = textEntryWithLabels(const []);
        when(
          () => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Urgent'));
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => repository.setLabels(
            journalEntityId: 'entry-123',
            labelIds: any(named: 'labelIds'),
          ),
        ).called(1);

        expect(find.widgetWithText(FilledButton, 'Apply'), findsNothing);
      });

      testWidgets('shows error snackbar when apply fails', (tester) async {
        final entry = textEntryWithLabels(const []);
        when(
          () => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Failed to update labels'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
      });
    });

    group('Search functionality', () {
      testWidgets('search filters labels', (tester) async {
        final entry = textEntryWithLabels(const []);
        when(
          () => repository.setLabels(
            journalEntityId: any(named: 'journalEntityId'),
            labelIds: any(named: 'labelIds'),
          ),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchField = find.descendant(
          of: find.byType(TextField),
          matching: find.byType(EditableText),
        );
        await tester.enterText(searchField, 'Urgent');
        await tester.pump();

        expect(find.byType(CheckboxListTile), findsOneWidget);
      });

      testWidgets('clearing search shows all labels', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchField = find.descendant(
          of: find.byType(TextField),
          matching: find.byType(EditableText),
        );
        await tester.enterText(searchField, 'test');
        await tester.pump();

        await tester.enterText(searchField, '');
        await tester.pump();

        expect(find.text('Urgent'), findsOneWidget);
        expect(find.text('Backlog'), findsOneWidget);
      });
    });

    group('Label selection', () {
      testWidgets('shows initially selected labels as checked', (tester) async {
        final entry = textEntryWithLabels(['label-1']);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final checkbox = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('Urgent'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        expect(checkbox.value, isTrue);
      });

      testWidgets('toggles label selection on tap', (tester) async {
        final entry = textEntryWithLabels(const []);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        var checkbox = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('Urgent'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        expect(checkbox.value, isFalse);

        await tester.tap(find.text('Urgent'));
        await tester.pump();

        checkbox = tester.widget<CheckboxListTile>(
          find.ancestor(
            of: find.text('Urgent'),
            matching: find.byType(CheckboxListTile),
          ),
        );
        expect(checkbox.value, isTrue);
      });
    });

    group('Entry with existing labels', () {
      testWidgets('passes existing labelIds to selector', (tester) async {
        final entry = textEntryWithLabels(['label-1', 'label-2']);

        await tester.pumpWidget(buildWrapper(entry));
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Labels'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final content = tester.widget<LabelSelectionSliverContent>(
          find.byType(LabelSelectionSliverContent),
        );
        expect(content.initialLabelIds, containsAll(['label-1', 'label-2']));
      });
    });
  });

  group('ModernRateSessionItem - Satellite Tests', () {
    const entryId = 'time-entry-1';

    testWidgets(
      'shows "Rate Session" with outline icon when no rating exists',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              ratingControllerProvider(
                targetId: entryId,
              ).overrideWith(_FakeNoRatingController.new),
            ],
            child: const ModernRateSessionItem(entryId: entryId),
          ),
        );

        await tester.pump();

        final context = tester.element(find.byType(ModernRateSessionItem));
        expect(find.byType(ActionMenuListItem), findsOneWidget);
        expect(find.byIcon(Icons.star_rate_outlined), findsOneWidget);
        expect(
          find.text(context.messages.sessionRatingRateAction),
          findsOneWidget,
        );
      },
    );

    testWidgets('hidden when feature flag is disabled', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(false),
            ),
            ratingControllerProvider(
              targetId: entryId,
            ).overrideWith(_FakeNoRatingController.new),
          ],
          child: const ModernRateSessionItem(entryId: entryId),
        ),
      );

      await tester.pump();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets(
      'shows "View Rating" with filled icon when rating exists',
      (tester) async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(true),
              ),
              ratingControllerProvider(
                targetId: entryId,
              ).overrideWith(_FakeHasRatingController.new),
            ],
            child: const ModernRateSessionItem(entryId: entryId),
          ),
        );

        await tester.pump();

        final context = tester.element(find.byType(ModernRateSessionItem));
        expect(find.byType(ActionMenuListItem), findsOneWidget);
        expect(find.byIcon(Icons.star_rate_rounded), findsOneWidget);
        expect(
          find.text(context.messages.sessionRatingViewAction),
          findsOneWidget,
        );
      },
    );
  });

  group('ModernCopyEntryTextItem - ', () {
    setUpAll(() async {
      getIt.allowReassignment = true;
      getIt
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
        ..registerSingleton<UpdateNotifications>(UpdateNotifications())
        ..registerSingleton<EditorStateService>(EditorStateService());
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    testWidgets('Copy as text triggers copy', (tester) async {
      final controller = _CopyTextEntryController(initialText: 'Hello');
      String? last;
      final fakeClipboard = AppClipboard(
        writePlainText: (t) async {
          last = t;
        },
      );

      await tester.pumpWidget(
        _wrapWithCopyApp(
          const Column(
            children: [
              ModernCopyEntryTextItem(entryId: 'e1', markdown: false),
            ],
          ),
          overrides: [
            entryControllerProvider(id: 'e1').overrideWith(() => controller),
            appClipboardProvider.overrideWithValue(fakeClipboard),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Copy as text'), findsOneWidget);

      await tester.tap(find.text('Copy as text'));
      await tester.pump();

      expect(controller.plainCalled, isTrue);
      expect(last, 'Hello\n');
    });

    testWidgets('Copy as Markdown triggers copy', (tester) async {
      final controller = _CopyTextEntryController(initialText: 'Hello');
      String? last;
      final fakeClipboard = AppClipboard(
        writePlainText: (t) async {
          last = t;
        },
      );

      await tester.pumpWidget(
        _wrapWithCopyApp(
          const Column(
            children: [
              ModernCopyEntryTextItem(entryId: 'e1', markdown: true),
            ],
          ),
          overrides: [
            entryControllerProvider(id: 'e1').overrideWith(() => controller),
            appClipboardProvider.overrideWithValue(fakeClipboard),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Copy as Markdown'), findsOneWidget);

      await tester.tap(find.text('Copy as Markdown'));
      await tester.pump();

      expect(controller.markdownCalled, isTrue);
      expect(last, 'Hello');
    });

    testWidgets('Copy actions hidden when no text', (tester) async {
      final controller = _CopyTextEntryController();

      await tester.pumpWidget(
        _wrapWithCopyApp(
          const Column(
            children: [
              ModernCopyEntryTextItem(entryId: 'e2', markdown: false),
              ModernCopyEntryTextItem(entryId: 'e2', markdown: true),
            ],
          ),
          overrides: [
            entryControllerProvider(id: 'e2').overrideWith(() => controller),
          ],
        ),
      );

      await tester.pump();

      expect(find.text('Copy as text'), findsNothing);
      expect(find.text('Copy as Markdown'), findsNothing);
    });

    testWidgets('Editor toolbar builds (coverage)', (tester) async {
      final controller = _CopyTextEntryController(initialText: 'Toolbar');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'e3').overrideWith(() => controller),
          ],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill_localizations.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: EditorWidget(entryId: 'e3'),
            ),
          ),
        ),
      );

      // The Quill editor schedules several follow-up frames before the
      // toolbar appears — a genuine settle case.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
    });

    testWidgets('InitialModalPageContent includes copy actions', (
      tester,
    ) async {
      final controller = _CopyTextEntryController(initialText: 'Hello');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entryControllerProvider(id: 'e4').overrideWith(() => controller),
          ],
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              ...AppLocalizations.localizationsDelegates,
              quill_localizations.FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: InitialModalPageContent(
                  entryId: 'e4',
                  linkedFromId: null,
                  inLinkedEntries: false,
                  link: null,
                  pageIndexNotifier: ValueNotifier(0),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Copy as text'), findsOneWidget);
      expect(find.text('Copy as Markdown'), findsOneWidget);
    });
  });
}

/// Fake [SharePlatform] that records the [ShareParams] passed to [share]
/// instead of invoking a real platform channel.
class _FakeSharePlatform extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  void reset() => lastParams = null;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult('shared', ShareResultStatus.success);
  }
}

/// Fake EntryController that tracks [delete] calls.
class _DeletingFakeEntryController extends FakeEntryController {
  // ignore: use_super_parameters
  _DeletingFakeEntryController(JournalEntity entity) : super(entity);

  int deleteCalls = 0;

  @override
  Future<bool> delete({required bool beamBack}) async {
    deleteCalls++;
    return true;
  }
}

/// Fake EntryController that tracks [copyImage] calls.
class _CopyImageFakeEntryController extends FakeEntryController {
  // ignore: use_super_parameters
  _CopyImageFakeEntryController(JournalEntity entity) : super(entity);

  int copyImageCalls = 0;

  @override
  Future<void> copyImage() async {
    copyImageCalls++;
  }
}

/// LinkedEntriesController that tracks [removeLink] calls.
class _RemoveLinkTrackingController extends LinkedEntriesController {
  final List<String> removeLinkCalls = [];

  @override
  Future<List<EntryLink>> build({required String id}) async => [];

  @override
  Future<void> updateLink(EntryLink link) async {}

  @override
  Future<void> removeLink({required String toId}) async {
    removeLinkCalls.add(toId);
  }
}

/// Fake RatingController that returns null (no existing rating).
class _FakeNoRatingController extends RatingController {
  @override
  Future<JournalEntity?> build({
    required String targetId,
    String catalogId = 'session',
  }) async {
    state = const AsyncData(null);
    return null;
  }
}

/// Fake RatingController that returns an existing rating.
class _FakeHasRatingController extends RatingController {
  @override
  Future<JournalEntity?> build({
    required String targetId,
    String catalogId = 'session',
  }) async {
    final testDate = DateTime(2025, 12, 31, 12);
    final entity = RatingEntry(
      meta: Metadata(
        id: 'rating-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: RatingData(
        targetId: targetId,
        dimensions: const [
          RatingDimension(key: 'productivity', value: 0.8),
          RatingDimension(key: 'energy', value: 0.6),
          RatingDimension(key: 'focus', value: 0.9),
          RatingDimension(key: 'challenge_skill', value: 0.5),
        ],
      ),
    );
    state = AsyncData(entity);
    return entity;
  }
}

class _RecordingProcessRunner {
  final calls = <_ProcessCall>[];

  Future<ProcessResult> call(
    String executable,
    List<String> arguments,
  ) async {
    calls.add(_ProcessCall(executable, List<String>.from(arguments)));
    return ProcessResult(calls.length - 1, 0, '', '');
  }
}

@immutable
class _ProcessCall {
  const _ProcessCall(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  @override
  bool operator ==(Object other) =>
      other is _ProcessCall &&
      other.executable == executable &&
      _listEquals(other.arguments, arguments);

  @override
  int get hashCode => Object.hash(executable, Object.hashAll(arguments));

  @override
  String toString() => '_ProcessCall($executable, $arguments)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }

  return true;
}

/// EntryController that returns a fixed entry (used by ModernLabelsItem tests).
class _TestEntryController extends EntryController {
  _TestEntryController(this.entry);

  final JournalEntity entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

class _MockLabelsRepository extends Mock implements LabelsRepository {}

// A lightweight test controller that returns a minimal entry state and
// exposes the base copy methods via super.* for coverage.
class _CopyTextEntryController extends EntryController {
  _CopyTextEntryController({this.initialText = ''});

  final String initialText;

  bool plainCalled = false;
  bool markdownCalled = false;

  @override
  Future<EntryState?> build({required String id}) async {
    // Initialize controller with initial text
    controller = QuillController.basic();
    if (initialText.isNotEmpty) {
      controller.document.insert(0, initialText);
    }

    final fixed = DateTime.utc(2023);
    final entry = JournalEntity.journalEntry(
      meta: Metadata(
        id: id,
        createdAt: fixed,
        updatedAt: fixed,
        dateFrom: fixed,
        dateTo: fixed,
      ),
    );

    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: true,
    );
  }

  @override
  Future<void> copyEntryTextPlain() async {
    plainCalled = true;
    await super.copyEntryTextPlain();
  }

  @override
  Future<void> copyEntryTextMarkdown() async {
    markdownCalled = true;
    await super.copyEntryTextMarkdown();
  }
}

Widget _wrapWithCopyApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: resolveTestTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(body: child),
        ),
      ),
    ),
  );
}
