import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/ui/set_cover_art_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEditorStateService mockEditorStateService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(FakeEntryText());

    mockEditorStateService = MockEditorStateService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => mockPersistenceLogic.updateTask(
        journalEntityId: any(named: 'journalEntityId'),
        taskData: any(named: 'taskData'),
        categoryId: any(named: 'categoryId'),
        entryText: any(named: 'entryText'),
      ),
    ).thenAnswer((_) async => true);

    getIt
      ..registerSingleton<EditorStateService>(mockEditorStateService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDownAll(() async {
    await getIt.reset();
  });

  Task buildTask({String? coverArtId, String id = 'task-1'}) {
    final now = DateTime(2025, 12, 31, 12);
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

  group('SetCoverArtChip', () {
    testWidgets('renders nothing when linkedFromId is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink when linkedFromId is null
      expect(find.byType(SubtleActionChip), findsNothing);
    });

    testWidgets('renders nothing when parent is not a Task', (tester) async {
      final now = DateTime(2025, 12, 31, 12);
      final textEntry = JournalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: 'Not a task'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(textEntry),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'entry-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink when parent is not a Task
      expect(find.byType(SubtleActionChip), findsNothing);
    });

    testWidgets('shows "Set cover" label when image is not current cover',
        (tester) async {
      final task = buildTask(); // No coverArtId set

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Set cover" text
      expect(find.text('Set cover'), findsOneWidget);
      // Should show outlined icon
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('shows "Cover" label when image is current cover',
        (tester) async {
      final task = buildTask(coverArtId: 'image-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Cover" text (from coverArtChipActive)
      expect(find.text('Cover'), findsOneWidget);
      // Should show filled icon
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('tapping chip calls setCoverArt with imageId when not cover',
        (tester) async {
      final task = buildTask(); // No coverArtId set
      final (override, tracker) = createTrackingEntryControllerOverride(task);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [override],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state shows "Set cover"
      expect(find.text('Set cover'), findsOneWidget);

      // Tap the chip
      await tester.tap(find.byType(SetCoverArtChip));
      await tester.pumpAndSettle();

      // Verify setCoverArt was called with imageId
      expect(tracker.calls, ['image-1']);

      // Verify UI updated to show "Cover"
      expect(find.text('Cover'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('tapping chip calls setCoverArt with null when already cover',
        (tester) async {
      final task = buildTask(coverArtId: 'image-1');
      final (override, tracker) = createTrackingEntryControllerOverride(task);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [override],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state shows "Cover"
      expect(find.text('Cover'), findsOneWidget);

      // Tap the chip
      await tester.tap(find.byType(SetCoverArtChip));
      await tester.pumpAndSettle();

      // Verify setCoverArt was called with null to remove
      expect(tracker.calls, [null]);

      // Verify UI updated to show "Set cover"
      expect(find.text('Set cover'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('shows "Set cover" when different image is the cover',
        (tester) async {
      final task = buildTask(coverArtId: 'other-image');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Set cover" since this image is not the cover
      expect(find.text('Set cover'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('tapping replaces existing cover with new image',
        (tester) async {
      final task = buildTask(coverArtId: 'old-image');
      final (override, tracker) = createTrackingEntryControllerOverride(task);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [override],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'new-image',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state shows "Set cover" for different image
      expect(find.text('Set cover'), findsOneWidget);

      // Tap the chip to set this image as cover
      await tester.tap(find.byType(SetCoverArtChip));
      await tester.pumpAndSettle();

      // Verify setCoverArt was called with new imageId
      expect(tracker.calls, ['new-image']);

      // Verify UI updated to show "Cover"
      expect(find.text('Cover'), findsOneWidget);
    });
  });
}
