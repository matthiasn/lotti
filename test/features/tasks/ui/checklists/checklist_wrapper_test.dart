import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_wrapper.dart';
import 'package:lotti/services/share_service.dart';

import '../../../../test_helper.dart';

class _MockChecklistController extends ChecklistController {
  _MockChecklistController(this.value);

  final Checklist? value;

  @override
  Future<Checklist?> build({
    required String id,
    required String? taskId,
  }) async =>
      value;
}

class _MockChecklistItemController extends ChecklistItemController {
  _MockChecklistItemController(this.value);
  final ChecklistItem? value;

  @override
  Future<ChecklistItem?> build({
    required String id,
    required String? taskId,
  }) async =>
      value;
}

// Note: no need for a null-item controller in current tests

void main() {
  const desktopMq = MediaQueryData(size: Size(1280, 1000));

  group('ChecklistWrapper', () {
    testWidgets('copies markdown and shows success SnackBar', (tester) async {
      const checklistId = 'cl1';
      const taskId = 't1';
      const itemId1 = 'i1';
      const itemId2 = 'i2';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'My Checklist',
          linkedChecklistItems: [itemId1, itemId2],
          linkedTasks: [],
        ),
      );

      final item1 = ChecklistItem(
        meta: Metadata(
          id: itemId1,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'First',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final item2 = ChecklistItem(
        meta: Metadata(
          id: itemId2,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Second',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      var copied = '';
      final fakeClipboard = AppClipboard(writePlainText: (text) async {
        copied = text;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appClipboardProvider.overrideWithValue(fakeClipboard),
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
            checklistItemControllerProvider(id: itemId1, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item1)),
            checklistItemControllerProvider(id: itemId2, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item2)),
          ],
          child: const WidgetTestBench(
            mediaQueryData: desktopMq,
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open overflow and choose Export
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export checklist as Markdown'));
      await tester.pumpAndSettle();

      expect(copied, '- [ ] First\n- [x] Second');
      expect(find.text('Checklist copied as Markdown'), findsOneWidget);
    });

    testWidgets('overflow Share triggers emoji list', (tester) async {
      const checklistId = 'cl2';
      const taskId = 't2';
      const itemId1 = 'a1';
      const itemId2 = 'a2';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Share Me',
          linkedChecklistItems: [itemId1, itemId2],
          linkedTasks: [],
        ),
      );

      final item1 = ChecklistItem(
        meta: Metadata(
          id: itemId1,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'One',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final item2 = ChecklistItem(
        meta: Metadata(
          id: itemId2,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Two',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      String? sharedText;
      String? sharedSubject;
      final oldShare = ShareService.instance;
      ShareService.instance = _FakeShareService(
        onShare: (text, subject) async {
          sharedText = text;
          sharedSubject = subject;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
            checklistItemControllerProvider(id: itemId1, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item1)),
            checklistItemControllerProvider(id: itemId2, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item2)),
          ],
          child: const WidgetTestBench(
            mediaQueryData: desktopMq,
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open overflow and choose Share
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(sharedSubject, 'Share Me');
      expect(sharedText, '⬜ One\n✅ Two');

      ShareService.instance = oldShare;
    });

    testWidgets('shows "No items to export" when checklist has no items',
        (tester) async {
      const checklistId = 'empty-1';
      const taskId = 't-empty';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Empty',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
          ],
          child: const WidgetTestBench(
            mediaQueryData: desktopMq,
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export checklist as Markdown'));
      await tester.pumpAndSettle();

      expect(find.text('No items to export'), findsOneWidget);
    });

    testWidgets('share does nothing for empty checklist', (tester) async {
      const checklistId = 'empty-2';
      const taskId = 't-empty-2';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Empty',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      );

      var called = false;
      final oldShare = ShareService.instance;
      ShareService.instance = _FakeShareService(
        onShare: (text, subject) async {
          called = true;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
          ],
          child: const WidgetTestBench(
            mediaQueryData: desktopMq,
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      ShareService.instance = oldShare;
    });

    testWidgets('share errors are suppressed', (tester) async {
      const checklistId = 'share-err-1';
      const taskId = 't-share-err-1';
      const itemId1 = 's1';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Share Err',
          linkedChecklistItems: [itemId1],
          linkedTasks: [],
        ),
      );

      final item1 = ChecklistItem(
        meta: Metadata(
          id: itemId1,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'One',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final oldShare = ShareService.instance;
      ShareService.instance = _FakeShareService(
        onShare: (text, subject) async {
          throw Exception('share failed');
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
            checklistItemControllerProvider(id: itemId1, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item1)),
          ],
          child: const WidgetTestBench(
            mediaQueryData: desktopMq,
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));

      // If exceptions leaked, the test would fail. Reaching here implies they
      // were caught and suppressed.
      await tester.pumpAndSettle();
      ShareService.instance = oldShare;
    });

    testWidgets('copy failure shows Export failed SnackBar', (tester) async {
      const checklistId = 'cl3';
      const taskId = 't3';
      const itemId1 = 'b1';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Copy Fail',
          linkedChecklistItems: [itemId1],
          linkedTasks: [],
        ),
      );

      final item1 = ChecklistItem(
        meta: Metadata(
          id: itemId1,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Oops',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      final throwingClipboard = AppClipboard(writePlainText: (text) async {
        throw Exception('copy failed');
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appClipboardProvider.overrideWithValue(throwingClipboard),
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
            checklistItemControllerProvider(id: itemId1, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item1)),
          ],
          child: const WidgetTestBench(
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export checklist as Markdown'));
      await tester.pumpAndSettle();

      expect(find.text('Export failed'), findsOneWidget);
    });

    testWidgets('returns nothing when checklist is null', (tester) async {
      const checklistId = 'null-checklist';
      const taskId = 't4';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(null)),
          ],
          child: const WidgetTestBench(
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(ChecklistWrapper), findsOneWidget);
      // No ChecklistWidget renders inside
      expect(find.byType(ChecklistWidget), findsNothing);
    });

    testWidgets('shows snackbar when correction capture event is emitted',
        (tester) async {
      const checklistId = 'correction-1';
      const taskId = 't-correction';
      const itemId1 = 'c1';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Correction Test',
          linkedChecklistItems: [itemId1],
          linkedTasks: [],
        ),
      );

      final item1 = ChecklistItem(
        meta: Metadata(
          id: itemId1,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Item',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
            checklistItemControllerProvider(id: itemId1, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item1)),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const WidgetTestBench(
                child: ChecklistWrapper(
                  entryId: checklistId,
                  taskId: taskId,
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Set a pending correction to trigger snackbar
      container.read(correctionCaptureNotifierProvider.notifier).setPending(
            pending: PendingCorrection(
              before: 'test flight',
              after: 'TestFlight',
              categoryId: 'cat-1',
              categoryName: 'Dev',
              createdAt: DateTime.now(),
            ),
            onSave: () async {},
          );

      await tester.pump();

      // Snackbar should appear with pending correction UI
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('cancel button in snackbar clears pending and hides snackbar',
        (tester) async {
      const checklistId = 'correction-2';
      const taskId = 't-correction-2';
      const itemId1 = 'c2';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Cancel Test',
          linkedChecklistItems: [itemId1],
          linkedTasks: [],
        ),
      );

      final item1 = ChecklistItem(
        meta: Metadata(
          id: itemId1,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistItemData(
          title: 'Item',
          isChecked: false,
          linkedChecklists: [],
        ),
      );

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
            checklistItemControllerProvider(id: itemId1, taskId: taskId)
                .overrideWith(() => _MockChecklistItemController(item1)),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const WidgetTestBench(
                child: ChecklistWrapper(
                  entryId: checklistId,
                  taskId: taskId,
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Set a pending correction to trigger snackbar
      container.read(correctionCaptureNotifierProvider.notifier).setPending(
            pending: PendingCorrection(
              before: 'test flight',
              after: 'TestFlight',
              categoryId: 'cat-1',
              categoryName: 'Dev',
              createdAt: DateTime.now(),
            ),
            onSave: () async {},
          );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Snackbar should be visible
      expect(find.byType(SnackBar), findsOneWidget);

      // Pending correction should exist
      expect(
        container.read(correctionCaptureNotifierProvider),
        isNotNull,
      );

      // Tap the CANCEL button (use warnIfMissed: false for floating snackbar)
      await tester.tap(find.text('CANCEL'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Pending correction should be cleared
      expect(
        container.read(correctionCaptureNotifierProvider),
        isNull,
      );
    });

    /* Skipped: loading-state null branch is transient and racey in tests.
    testWidgets('returns nothing while completionRate is loading', (tester) async {
      const checklistId = 'null-rate';
      const taskId = 't5';

      // Create a checklist but override completion rate provider to never complete,
      // so .value remains null
      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
        data: const ChecklistData(
          title: 'Rate Pending',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider(
              id: checklistId,
              taskId: taskId,
            ).overrideWith(() => _MockChecklistController(checklist)),
          ],
          child: const WidgetTestBench(
            child: ChecklistWrapper(
              entryId: checklistId,
              taskId: taskId,
            ),
          ),
        ),
      );

      // On initial build, completion rate provider is loading, so .value is null
      await tester.pump();
      expect(find.byType(ChecklistWidget), findsNothing);
    });*/
  });
}

class _FakeShareService extends ShareService {
  _FakeShareService({required this.onShare});
  final Future<void> Function(String text, String? subject) onShare;

  @override
  Future<void> shareText({required String text, String? subject}) =>
      onShare(text, subject);
}
