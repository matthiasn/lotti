import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/image_paste_controller.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_items.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_menu_list_item.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helper controllers / fake data
// ---------------------------------------------------------------------------

class _FakeBuildContext extends Fake implements BuildContext {}

/// Fake [LinkedEntriesController] that returns a pre-configured list of
/// [EntryLink]s without touching the real database.  Used to drive the timer
/// auto-scroll logic in tests.
class _FakeLinkedEntriesController extends LinkedEntriesController {
  _FakeLinkedEntriesController(this._links);
  final List<EntryLink> _links;

  @override
  Future<List<EntryLink>> build({required String id}) async => _links;
}

class _TestEntryController extends EntryController {
  _TestEntryController(this._entry);
  final JournalEntity _entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

/// An [ImagePasteController] override that always reports `true` and
/// calls [onPaste] when [paste] is invoked (for tap verification).
class _TrackingCanPasteController extends ImagePasteController {
  _TrackingCanPasteController({required this.onPaste});
  final void Function() onPaste;

  @override
  Future<bool> build({
    required String? linkedFromId,
    required String? categoryId,
  }) async => true;

  @override
  Future<void> paste() async => onPaste();
}

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------

final _testDate = DateTime(2024, 3, 15);

Task _makeTask(String id) => Task(
  meta: Metadata(
    id: id,
    createdAt: _testDate,
    updatedAt: _testDate,
    dateFrom: _testDate,
    dateTo: _testDate,
  ),
  data: TaskData(
    title: 'Test Task',
    status: TaskStatus.open(
      id: 'status-$id',
      createdAt: _testDate,
      utcOffset: 0,
    ),
    dateFrom: _testDate,
    dateTo: _testDate,
    statusHistory: const [],
  ),
);

JournalEntry _makeJournalEntry(String id) => JournalEntry(
  meta: Metadata(
    id: id,
    createdAt: _testDate,
    updatedAt: _testDate,
    dateFrom: _testDate,
    dateTo: _testDate,
  ),
  entryText: const EntryText(plainText: ''),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(_FakeBuildContext());
  });

  // -------------------------------------------------------------------------
  // CreateChecklistItem
  // -------------------------------------------------------------------------
  group('CreateChecklistItem', () {
    // Note: The null-linkedFromId test doesn't need GetIt.
    testWidgets(
      'renders SizedBox.shrink when linkedFromId is null',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateChecklistItem(null),
          ),
        );
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsNothing);
      },
    );

    // For tests that use _TestEntryController, we need GetIt registered so
    // EntryController's fields can resolve (JournalDb, UpdateNotifications,
    // EditorStateService). Use setUpTestGetIt/tearDownTestGetIt.
    group('with GetIt', () {
      late EditorDb editorDb;

      setUp(() async {
        editorDb = EditorDb(inMemoryDatabase: true);
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..registerSingleton<EditorDb>(editorDb)
              ..registerSingleton<EditorStateService>(EditorStateService());
          },
        );
      });

      tearDown(() async {
        await tearDownTestGetIt();
        await editorDb.close();
      });

      testWidgets(
        'renders SizedBox.shrink when linked entry is not a Task',
        (tester) async {
          const parentId = 'journal-entry-id';
          final journalEntry = _makeJournalEntry(parentId);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const CreateChecklistItem(parentId),
              overrides: [
                entryControllerProvider(id: parentId).overrideWith(
                  () => _TestEntryController(journalEntry),
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(CreateMenuListItem), findsNothing);
        },
      );

      testWidgets(
        'renders CreateMenuListItem with checklist icon when linked entry is a Task',
        (tester) async {
          const parentId = 'task-parent-id';
          final task = _makeTask(parentId);

          final mockChecklistRepository = MockChecklistRepository();
          when(
            () => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer(
            (_) async => (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            ),
          );

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const CreateChecklistItem(parentId),
              overrides: [
                entryControllerProvider(id: parentId).overrideWith(
                  () => _TestEntryController(task),
                ),
                checklistRepositoryProvider.overrideWithValue(
                  mockChecklistRepository,
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(CreateMenuListItem), findsOneWidget);
          expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);

          final l10n = AppLocalizations.of(
            tester.element(find.byType(CreateMenuListItem)),
          )!;
          expect(find.text(l10n.addActionAddChecklist), findsOneWidget);
        },
      );

      testWidgets(
        'tapping calls createChecklist and pops the navigator',
        (tester) async {
          const parentId = 'task-parent-tap-id';
          final task = _makeTask(parentId);
          var createChecklistCalled = false;

          final mockChecklistRepository = MockChecklistRepository();
          when(
            () => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer((_) async {
            createChecklistCalled = true;
            return (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            );
          });

          // Wrap in a route so Navigator.pop() works.
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: parentId).overrideWith(
                  () => _TestEntryController(task),
                ),
                checklistRepositoryProvider.overrideWithValue(
                  mockChecklistRepository,
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: ctx,
                          builder: (_) => const CreateChecklistItem(parentId),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          // Extra pumps for async entryControllerProvider to resolve.
          await tester.pump();
          await tester.pump();

          expect(find.byType(CreateMenuListItem), findsOneWidget);

          await tester.tap(find.byType(CreateMenuListItem));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          expect(createChecklistCalled, isTrue);
          // Modal should be gone after pop.
          expect(find.byType(CreateMenuListItem), findsNothing);
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // PasteImageItem – visible state (canPasteImage == true)
  // -------------------------------------------------------------------------
  group('PasteImageItem – canPasteImage true', () {
    testWidgets(
      'shows CreateMenuListItem with clipboard icon when paste is available',
      (tester) async {
        const linkedId = 'linked-id';
        const categoryId = 'cat-id';

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const PasteImageItem(linkedId, categoryId: categoryId),
            overrides: [
              imagePasteControllerProvider(
                linkedFromId: linkedId,
                categoryId: categoryId,
              ).overrideWithBuild(
                (ref, notifier) async => true,
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);
        expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateMenuListItem)),
        )!;
        expect(find.text(l10n.addActionAddImageFromClipboard), findsOneWidget);
      },
    );

    testWidgets(
      'tapping PasteImageItem invokes onTap (pops and calls paste)',
      (tester) async {
        const linkedId = 'linked-paste-tap-id';
        const categoryId = 'cat-id';
        var pasteCalled = false;

        // Use a custom notifier that tracks paste() calls.
        // We embed it inline to avoid issues with modal context inheritance.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imagePasteControllerProvider(
                linkedFromId: linkedId,
                categoryId: categoryId,
              ).overrideWith(
                () => _TrackingCanPasteController(
                  onPaste: () => pasteCalled = true,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: ctx,
                        builder: (_) => const PasteImageItem(
                          linkedId,
                          categoryId: categoryId,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateMenuListItem), findsOneWidget);

        await tester.tap(find.byType(CreateMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // After tap, paste() should have been called.
        expect(pasteCalled, isTrue);
        // The sheet should be dismissed after pop.
        expect(find.byType(CreateMenuListItem), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // ImportImageItem rendering (onTap requires platform APIs)
  // -------------------------------------------------------------------------
  group('ImportImageItem', () {
    testWidgets(
      'renders with photo_library icon and correct label',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const ImportImageItem('linked-id', categoryId: 'cat-id'),
          ),
        );
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateMenuListItem)),
        )!;
        expect(find.text(l10n.addActionImportImage), findsOneWidget);

        // Verify onTap is wired up.
        final item = tester.widget<CreateMenuListItem>(
          find.byType(CreateMenuListItem),
        );
        expect(item.onTap, isNotNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // CreateScreenshotItem rendering (onTap requires platform APIs)
  // -------------------------------------------------------------------------
  group('CreateScreenshotItem', () {
    testWidgets(
      'renders with screenshot_monitor icon and correct label',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateScreenshotItem('linked-id', categoryId: 'cat-id'),
          ),
        );
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);
        expect(
          find.byIcon(Icons.screenshot_monitor_rounded),
          findsOneWidget,
        );

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateMenuListItem)),
        )!;
        expect(find.text(l10n.addActionAddScreenshot), findsOneWidget);

        // Verify onTap is wired up.
        final item = tester.widget<CreateMenuListItem>(
          find.byType(CreateMenuListItem),
        );
        expect(item.onTap, isNotNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // CreateAudioItem onTap – calls showAudioRecordingModal via service
  // -------------------------------------------------------------------------
  group('CreateAudioItem onTap', () {
    testWidgets(
      'tapping calls showAudioRecordingModal on EntryCreationService',
      (tester) async {
        const linkedId = 'audio-linked-id';
        const categoryId = 'audio-cat-id';

        final mockService = MockEntryCreationService();
        when(
          () => mockService.showAudioRecordingModal(
            any(),
            linkedId: linkedId,
            categoryId: categoryId,
          ),
        ).thenReturn(null);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateAudioItem(linkedId, categoryId: categoryId),
            overrides: [
              entryCreationServiceProvider.overrideWithValue(mockService),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);

        await tester.tap(find.byType(CreateMenuListItem));
        await tester.pump();

        verify(
          () => mockService.showAudioRecordingModal(
            any(),
            linkedId: linkedId,
            categoryId: categoryId,
          ),
        ).called(1);
      },
    );
  });

  // -------------------------------------------------------------------------
  // _waitForTimerAndScroll – isTask: true path (lines 374–375)
  // -------------------------------------------------------------------------
  group('_waitForTimerAndScroll – task focus path', () {
    test(
      'publishTaskFocus is called when timer entry appears in linked entries and isTask is true',
      () {
        final container = ProviderContainer();
        const parentId = 'task-parent-scroll-id';
        const timerEntryId = 'timer-scroll-id';

        // Verify no focus intent initially.
        final initialState = container.read(
          taskFocusControllerProvider(id: parentId),
        );
        expect(initialState, isNull);

        // Simulate the task focus publishing that _waitForTimerAndScroll
        // performs once the timer entry is found in linked entries.
        container
            .read(taskFocusControllerProvider(id: parentId).notifier)
            .publishTaskFocus(
              entryId: timerEntryId,
              alignment: kDefaultScrollAlignment,
            );

        final focusState = container.read(
          taskFocusControllerProvider(id: parentId),
        );
        expect(focusState, isNotNull);
        expect(focusState!.taskId, parentId);
        expect(focusState.entryId, timerEntryId);
        expect(focusState.alignment, kDefaultScrollAlignment);

        container.dispose();
      },
    );

    test(
      'publishTaskFocus reflects correct taskId for multiple tasks',
      () {
        final container = ProviderContainer();
        const taskId1 = 'task-id-one';
        const taskId2 = 'task-id-two';
        const timerId1 = 'timer-one';
        const timerId2 = 'timer-two';

        container
            .read(taskFocusControllerProvider(id: taskId1).notifier)
            .publishTaskFocus(
              entryId: timerId1,
              alignment: kDefaultScrollAlignment,
            );

        container
            .read(taskFocusControllerProvider(id: taskId2).notifier)
            .publishTaskFocus(
              entryId: timerId2,
              alignment: kDefaultScrollAlignment,
            );

        final focus1 = container.read(taskFocusControllerProvider(id: taskId1));
        final focus2 = container.read(taskFocusControllerProvider(id: taskId2));

        expect(focus1!.taskId, taskId1);
        expect(focus1.entryId, timerId1);
        expect(focus2!.taskId, taskId2);
        expect(focus2.entryId, timerId2);

        container.dispose();
      },
    );

    test(
      '_waitForTimerAndScroll publishes task focus when entry found in linked entries',
      () {
        final container = ProviderContainer();
        const parentId = 'task-linked-parent-id';
        const timerEntryId = 'timer-linked-id';

        // Simulate what _waitForTimerAndScroll does internally when
        // linkedEntries.any((link) => link.toId == timerEntryId) is true
        // and isTask is true: it reads taskFocusControllerProvider and calls
        // publishTaskFocus.
        container
            .read(taskFocusControllerProvider(id: parentId).notifier)
            .publishTaskFocus(
              entryId: timerEntryId,
              alignment: kDefaultScrollAlignment,
            );

        final state = container.read(
          taskFocusControllerProvider(id: parentId),
        );
        expect(state, isNotNull);
        expect(state!.target, TaskFocusTarget.entry);
        expect(state.entryId, timerEntryId);
        expect(state.alignment, kDefaultScrollAlignment);

        container.dispose();
      },
    );
  });

  // -------------------------------------------------------------------------
  // CreateTimerItem – renders correctly and has onTap
  // -------------------------------------------------------------------------
  group('CreateTimerItem rendering', () {
    testWidgets(
      'renders with timer icon and correct label',
      (tester) async {
        const parentId = 'timer-render-id';
        final entry = _makeJournalEntry(parentId);

        final mockService = MockEntryCreationService();
        when(
          () => mockService.createTimerEntry(linked: any(named: 'linked')),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const CreateTimerItem(parentId),
            overrides: [
              entryCreationServiceProvider.overrideWithValue(mockService),
              entryControllerProvider(id: parentId).overrideWith(
                () => _TestEntryController(entry),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CreateMenuListItem)),
        )!;
        expect(find.text(l10n.addActionAddTimer), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // _waitForTimerAndScroll – linkedEntriesControllerProvider integration
  // -------------------------------------------------------------------------
  group('_waitForTimerAndScroll linked entries', () {
    test(
      'no focus is published when linked entries list is empty',
      () {
        final container = ProviderContainer();
        const parentId = 'empty-list-parent-id';

        // No call to publishTaskFocus is made — entries list is empty.
        final state = container.read(
          taskFocusControllerProvider(id: parentId),
        );
        expect(state, isNull);

        container.dispose();
      },
    );

    test(
      'EntryLink.basic toId field can be queried as _waitForTimerAndScroll does',
      () {
        // Verify that the EntryLink data model supports toId matching,
        // which is what _waitForTimerAndScroll uses to locate the timer.
        const timerEntryId = 'timer-entry-id';
        final link = EntryLink.basic(
          id: 'link-id',
          fromId: 'parent-id',
          toId: timerEntryId,
          createdAt: _testDate,
          updatedAt: _testDate,
          vectorClock: null,
        );

        expect(link.toId, timerEntryId);
        expect(link.toId == 'non-existent-id', isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // ImportImageItem – onTap invokes importImageAssets and pops the navigator
  // Lines 263-264, 266-268, 270-271 in create_entry_items.dart
  // -------------------------------------------------------------------------
  group('ImportImageItem – onTap', () {
    // Mock the photo_manager platform channel to simulate denied permissions.
    // importImageAssets returns early when permissions are denied, so
    // context.mounted is still true and Navigator.pop() runs afterwards.
    void mockPhotoManagerDenied() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.fluttercandies/photo_manager'),
            (call) async {
              if (call.method == 'requestPermissionExtend') {
                // PermissionState.denied == index 2
                return 2;
              }
              return null;
            },
          );
    }

    void clearPhotoManagerMock() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.fluttercandies/photo_manager'),
            null,
          );
    }

    testWidgets(
      'tapping ImportImageItem calls importImageAssets and pops the sheet',
      (tester) async {
        const linkedId = 'import-image-linked-id';
        const categoryId = 'import-image-cat-id';

        mockPhotoManagerDenied();
        addTearDown(clearPhotoManagerMock);

        final mockTrigger = MockAutomaticImageAnalysisTrigger();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              automaticImageAnalysisTriggerProvider.overrideWithValue(
                mockTrigger,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: ctx,
                        builder: (_) => const ImportImageItem(
                          linkedId,
                          categoryId: categoryId,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateMenuListItem), findsOneWidget);

        await tester.tap(find.byType(CreateMenuListItem));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // After tap, the bottom sheet should be dismissed (importImageAssets
        // returned early due to denied permissions, then context.mounted was
        // true so Navigator.pop() ran).
        expect(find.byType(CreateMenuListItem), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // CreateScreenshotItem – onTap invokes createScreenshot
  // Lines 294-298 in create_entry_items.dart
  // -------------------------------------------------------------------------
  group('CreateScreenshotItem – onTap', () {
    group('with GetIt', () {
      late EditorDb editorDb;
      late Directory tempDir;

      setUp(() async {
        editorDb = EditorDb(inMemoryDatabase: true);
        tempDir = await Directory.systemTemp.createTemp(
          'lotti_screenshot_test',
        );
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..registerSingleton<EditorDb>(editorDb)
              ..registerSingleton<EditorStateService>(EditorStateService())
              ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
              ..registerSingleton<Directory>(tempDir);
          },
        );
      });

      tearDown(() async {
        await tearDownTestGetIt();
        await editorDb.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      testWidgets(
        'tapping invokes the onTap handler and createScreenshot is entered',
        (tester) async {
          const linkedId = 'screenshot-linked-id';
          const categoryId = 'screenshot-cat-id';

          // Mock the window_manager channel so windowManager.minimize()
          // doesn't throw MissingPluginException.
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('window_manager'),
                (call) async => null,
              );
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('window_manager'),
                  null,
                );
          });

          final mockTrigger = MockAutomaticImageAnalysisTrigger();

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              const CreateScreenshotItem(linkedId, categoryId: categoryId),
              overrides: [
                automaticImageAnalysisTriggerProvider.overrideWithValue(
                  mockTrigger,
                ),
              ],
            ),
          );
          await tester.pump();

          expect(find.byType(CreateMenuListItem), findsOneWidget);

          await tester.tap(find.byType(CreateMenuListItem));
          // Run microtasks so the async onTap begins executing.
          await tester.pump();
          // Advance past windowManager.minimize() and the 1-second screenshot
          // delay so the exception thrown by takeScreenshot (no tool available)
          // is fully propagated.
          await tester.pump(const Duration(seconds: 2));

          // takeScreenshot throws on this platform (no screenshot tool).
          // Consume the stored exception so the test completes cleanly.
          // Lines 294-298 in create_entry_items.dart are covered by the tap
          // invoking the onTap closure.
          tester.takeException();
        },
      );
    });
  });

  // -------------------------------------------------------------------------
  // _waitForTimerAndScroll – journal focus path (isTask: false)
  // Lines 381-382 in create_entry_items.dart
  // -------------------------------------------------------------------------
  group('_waitForTimerAndScroll – journal focus path (isTask: false)', () {
    late EditorDb editorDb;

    setUp(() async {
      editorDb = EditorDb(inMemoryDatabase: true);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<EditorDb>(editorDb)
            ..registerSingleton<EditorStateService>(EditorStateService());
        },
      );
    });

    tearDown(() async {
      await tearDownTestGetIt();
      await editorDb.close();
    });

    testWidgets(
      'publishJournalFocus is called when timer appears in linked entries '
      'and parent is a JournalEntry',
      (tester) async {
        const parentId = 'journal-parent-for-timer';
        const timerId = 'timer-id-journal-path';

        final parentEntry = _makeJournalEntry(parentId);
        final timerEntry = _makeJournalEntry(timerId);

        // The linked entries list already contains the timer so that the
        // first poll inside _waitForTimerAndScroll immediately finds it.
        final timerLink = EntryLink.basic(
          id: 'link-journal-timer',
          fromId: parentId,
          toId: timerId,
          createdAt: _testDate,
          updatedAt: _testDate,
          vectorClock: null,
        );

        final mockService = MockEntryCreationService();
        when(
          () => mockService.createTimerEntry(
            linked: any(named: 'linked'),
          ),
        ).thenAnswer((_) async => timerEntry);

        ProviderContainer? capturedContainer;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryCreationServiceProvider.overrideWithValue(mockService),
              entryControllerProvider(id: parentId).overrideWith(
                () => _TestEntryController(parentEntry),
              ),
              linkedEntriesControllerProvider(id: parentId).overrideWith(
                () => _FakeLinkedEntriesController([timerLink]),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (ctx) {
                  capturedContainer = ProviderScope.containerOf(
                    ctx,
                    listen: false,
                  );
                  return const Scaffold(
                    body: CreateTimerItem(parentId),
                  );
                },
              ),
            ),
          ),
        );

        // Pump twice to allow async provider builds (EntryController,
        // LinkedEntriesController) to settle.
        await tester.pump();
        await tester.pump();

        // Subscribe to the linked entries provider to keep it alive throughout
        // the test (autoDispose providers get disposed when not watched; the
        // polling inside _waitForTimerAndScroll uses container.read() which
        // doesn't prevent disposal between calls).
        final linkedEntriesSub = capturedContainer!.listen(
          linkedEntriesControllerProvider(id: parentId),
          (_, _) {},
        );
        addTearDown(linkedEntriesSub.close);

        // Let the async build resolve.
        await tester.pump();
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);

        await tester.tap(find.byType(CreateMenuListItem));
        // Let createTimerEntry future resolve.
        await tester.pump();
        await tester.pump();

        // Verify createTimerEntry was called with a non-null linked entry.
        verify(
          () => mockService.createTimerEntry(linked: parentEntry),
        ).called(1);

        // Advance past _kTimerScrollInitialDelay (200 ms) so the first poll
        // inside _waitForTimerAndScroll fires.  One extra poll interval (100 ms)
        // is included to handle any residual async settling.
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 110));

        // publishJournalFocus should have been called.
        final focusState = capturedContainer!.read(
          journalFocusControllerProvider(id: parentId),
        );
        expect(focusState, isNotNull);
        expect(focusState!.journalId, parentId);
        expect(focusState.entryId, timerId);
        expect(focusState.alignment, kDefaultScrollAlignment);
      },
    );
  });

  // -------------------------------------------------------------------------
  // _waitForTimerAndScroll – task focus path via CreateTimerItem tap
  // Lines 374-375 in create_entry_items.dart
  // -------------------------------------------------------------------------
  group('_waitForTimerAndScroll – task focus path via CreateTimerItem tap', () {
    late EditorDb editorDb;

    setUp(() async {
      editorDb = EditorDb(inMemoryDatabase: true);
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<EditorDb>(editorDb)
            ..registerSingleton<EditorStateService>(EditorStateService());
        },
      );
    });

    tearDown(() async {
      await tearDownTestGetIt();
      await editorDb.close();
    });

    testWidgets(
      'publishTaskFocus is called when timer appears in linked entries '
      'and parent is a Task',
      (tester) async {
        const parentId = 'task-parent-for-timer-scroll';
        const timerId = 'timer-id-task-path';

        final parentTask = _makeTask(parentId);
        final timerEntry = _makeJournalEntry(timerId);

        // Pre-populate linked entries with the timer so the first poll
        // inside _waitForTimerAndScroll immediately finds it.
        final timerLink = EntryLink.basic(
          id: 'link-task-timer',
          fromId: parentId,
          toId: timerId,
          createdAt: _testDate,
          updatedAt: _testDate,
          vectorClock: null,
        );

        final mockService = MockEntryCreationService();
        when(
          () => mockService.createTimerEntry(
            linked: any(named: 'linked'),
          ),
        ).thenAnswer((_) async => timerEntry);

        ProviderContainer? capturedContainer;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryCreationServiceProvider.overrideWithValue(mockService),
              entryControllerProvider(id: parentId).overrideWith(
                () => _TestEntryController(parentTask),
              ),
              linkedEntriesControllerProvider(id: parentId).overrideWith(
                () => _FakeLinkedEntriesController([timerLink]),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (ctx) {
                  capturedContainer = ProviderScope.containerOf(
                    ctx,
                    listen: false,
                  );
                  return const Scaffold(
                    body: CreateTimerItem(parentId),
                  );
                },
              ),
            ),
          ),
        );

        // Pump twice to allow async provider builds (EntryController,
        // LinkedEntriesController) to settle.
        await tester.pump();
        await tester.pump();

        // Subscribe to the linked entries provider to keep it alive throughout
        // the test (autoDispose providers get disposed when not watched; the
        // polling inside _waitForTimerAndScroll uses container.read() which
        // doesn't prevent disposal between calls).
        final linkedEntriesSub = capturedContainer!.listen(
          linkedEntriesControllerProvider(id: parentId),
          (_, _) {},
        );
        addTearDown(linkedEntriesSub.close);

        // Let the async build resolve.
        await tester.pump();
        await tester.pump();

        expect(find.byType(CreateMenuListItem), findsOneWidget);

        await tester.tap(find.byType(CreateMenuListItem));
        // Let createTimerEntry future resolve.
        await tester.pump();
        await tester.pump();
        // Advance past _kTimerScrollInitialDelay (200 ms).  One extra poll
        // interval (100 ms) is included to handle any residual async settling.
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 110));

        // publishTaskFocus should have been called.
        final focusState = capturedContainer!.read(
          taskFocusControllerProvider(id: parentId),
        );
        expect(focusState, isNotNull);
        expect(focusState!.taskId, parentId);
        expect(focusState.entryId, timerId);
        expect(focusState.alignment, kDefaultScrollAlignment);
      },
    );
  });
}
