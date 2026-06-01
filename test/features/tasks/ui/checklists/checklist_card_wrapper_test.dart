import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/services/checklist_completion_service.dart';
import 'package:lotti/features/checklist/services/correction_capture_service.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/correction_undo_snackbar.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/services/share_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _now = DateTime(2025, 3, 15);

Metadata _makeMeta(String id) => Metadata(
  id: id,
  createdAt: _now,
  updatedAt: _now,
  dateFrom: _now,
  dateTo: _now,
);

Checklist _makeChecklist({
  String id = 'checklist-1',
  String title = 'Test Checklist',
  List<String> linkedItems = const ['item-1', 'item-2'],
}) =>
    JournalEntity.checklist(
          meta: _makeMeta(id),
          data: ChecklistData(
            title: title,
            linkedChecklistItems: linkedItems,
            linkedTasks: const ['task-1'],
          ),
        )
        as Checklist;

ChecklistItem _makeItem({
  String id = 'item-1',
  String title = 'Buy milk',
  bool isChecked = false,
}) =>
    JournalEntity.checklistItem(
          meta: _makeMeta(id),
          data: ChecklistItemData(
            title: title,
            isChecked: isChecked,
            linkedChecklists: const ['checklist-1'],
          ),
        )
        as ChecklistItem;

// ---------------------------------------------------------------------------
// Fake controllers
// ---------------------------------------------------------------------------

class _FakeChecklistController extends ChecklistController {
  _FakeChecklistController(this._checklist)
    : super(const (id: 'fake', taskId: null));

  final Checklist? _checklist;

  String? lastUpdatedTitle;
  String? lastCreatedItemTitle;
  String? lastCreatedItemCategoryId;
  bool? lastCreatedItemIsChecked;

  @override
  Future<Checklist?> build() async => _checklist;

  @override
  Future<void> updateTitle(String? title) async {
    lastUpdatedTitle = title;
  }

  @override
  Future<String?> createChecklistItem(
    String? title, {
    required String? categoryId,
    required bool isChecked,
  }) async {
    lastCreatedItemTitle = title;
    lastCreatedItemCategoryId = categoryId;
    lastCreatedItemIsChecked = isChecked;
    return 'new-item';
  }

  @override
  Future<void> updateItemOrder(List<String> linkedChecklistItems) async {}

  @override
  Future<bool> delete() async => true;

  @override
  Future<void> dropChecklistItem(
    Object? localData, {
    String? categoryId,
    int? targetIndex,
    String? targetItemId,
  }) async {}
}

/// An item controller that throws on [build], exercising the
/// [ChecklistCardWrapper._resolveItems] error handler (lines 66-67, 69).
class _ThrowingChecklistItemController extends ChecklistItemController {
  _ThrowingChecklistItemController() : super(const (id: 'fake', taskId: null));

  @override
  Future<ChecklistItem?> build() async =>
      throw Exception('item provider exploded');
}

class _FakeChecklistItemController extends ChecklistItemController {
  _FakeChecklistItemController(this._item)
    : super(const (id: 'fake', taskId: null));

  final ChecklistItem? _item;

  @override
  Future<ChecklistItem?> build() async => _item;
}

class _FakeCompletionRateController extends ChecklistCompletionRateController {
  _FakeCompletionRateController(this._rate)
    : super(const (id: 'fake', taskId: null));

  final double _rate;

  @override
  Future<double> build() async => _rate;
}

class _FakeCompletionController extends ChecklistCompletionController {
  _FakeCompletionController(this._state)
    : super(const (id: 'fake', taskId: null));

  final ChecklistCompletionState _state;

  @override
  Future<ChecklistCompletionState> build() async => _state;
}

class _FakeCompletionService extends ChecklistCompletionService {
  @override
  FutureOr<List<ChecklistCompletionSuggestion>> build() async => [];
}

class _FakeCorrectionCaptureNotifier extends CorrectionCaptureNotifier {
  @override
  PendingCorrection? build() => null;

  bool cancelCalled = false;

  // ignore: use_setters_to_change_properties
  void emit(PendingCorrection pending) {
    state = pending;
  }

  @override
  bool cancel() {
    cancelCalled = true;
    state = null;
    return true;
  }
}

/// A [ShareService] spy that records calls to [shareText].
class _ShareServiceSpy extends ShareService {
  String? lastText;
  String? lastSubject;
  bool shouldThrow = false;

  @override
  Future<void> shareText({required String text, String? subject}) async {
    if (shouldThrow) throw Exception('share failed');
    lastText = text;
    lastSubject = subject;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Tracks clipboard writes for assertions.
class _ClipboardSpy {
  String? lastWritten;
  Future<void> writePlainText(String text) async {
    lastWritten = text;
  }
}

/// Pumps the [ChecklistCardWrapper] with the given configuration.
///
/// Returns a `({_ClipboardSpy clip, _FakeChecklistController controller})`
/// so callers can inspect recorded controller calls.
Future<({_ClipboardSpy clip, _FakeChecklistController controller})> _pump(
  WidgetTester tester, {
  Checklist? checklist,
  List<ChecklistItem> items = const [],
  double completionRate = 0.0,
  ChecklistCompletionState completionCounts = const (
    completedCount: 0,
    totalCount: 2,
  ),
  _FakeCorrectionCaptureNotifier? correctionNotifier,

  /// Extra item-level overrides appended after the standard ones. Use this
  /// to inject a throwing controller for a specific item id.
  List<Override> extraItemOverrides = const [],
  String? categoryId,
  bool? initiallyExpanded,
  // ignore: avoid_positional_boolean_parameters
  void Function(String, bool)? onExpansionChanged,
}) async {
  final cl = checklist ?? _makeChecklist();
  final clipSpy = _ClipboardSpy();
  final controller = _FakeChecklistController(cl);

  final corrNotifier = correctionNotifier ?? _FakeCorrectionCaptureNotifier();

  // Build item overrides for each linked item.
  final itemOverrides = <Override>[];
  for (final itemId in cl.data.linkedChecklistItems) {
    final matchingItem = items.cast<ChecklistItem?>().firstWhere(
      (i) => i?.id == itemId,
      orElse: () => null,
    );
    itemOverrides.add(
      checklistItemControllerProvider((
        id: itemId,
        taskId: 'task-1',
      )).overrideWith(() => _FakeChecklistItemController(matchingItem)),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        checklistControllerProvider((
          id: cl.id,
          taskId: 'task-1',
        )).overrideWith(() => controller),
        checklistCompletionRateControllerProvider(
          (id: cl.id, taskId: 'task-1'),
        ).overrideWith(() => _FakeCompletionRateController(completionRate)),
        checklistCompletionControllerProvider(
          (id: cl.id, taskId: 'task-1'),
        ).overrideWith(() => _FakeCompletionController(completionCounts)),
        appClipboardProvider.overrideWithValue(
          AppClipboard(writePlainText: clipSpy.writePlainText),
        ),
        correctionCaptureProvider.overrideWith(() => corrNotifier),
        checklistCompletionServiceProvider.overrideWith(
          _FakeCompletionService.new,
        ),
        ...itemOverrides,
        ...extraItemOverrides,
      ],
      child: WidgetTestBench(
        child: ChecklistCardWrapper(
          entryId: cl.id,
          taskId: 'task-1',
          categoryId: categoryId,
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
        ),
      ),
    ),
  );
  // Two pumps: resolve async providers then rebuild.
  await tester.pump();
  await tester.pump();

  return (clip: clipSpy, controller: controller);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChecklistCardWrapper', () {
    setUpAll(setUpTestGetIt);
    tearDownAll(tearDownTestGetIt);

    // ── Basic rendering ───────────────────────────────────────────────────

    testWidgets('renders ChecklistCard when data is available', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(ChecklistCard), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when checklist is null', (
      tester,
    ) async {
      final clipSpy = _ClipboardSpy();
      final corrNotifier = _FakeCorrectionCaptureNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider((
              id: 'missing',
              taskId: 'task-1',
            )).overrideWith(
              () => _FakeChecklistController(null),
            ),
            checklistCompletionRateControllerProvider(
              (id: 'missing', taskId: 'task-1'),
            ).overrideWith(() => _FakeCompletionRateController(0)),
            checklistCompletionControllerProvider(
              (id: 'missing', taskId: 'task-1'),
            ).overrideWith(
              () => _FakeCompletionController(
                const (completedCount: 0, totalCount: 0),
              ),
            ),
            appClipboardProvider.overrideWithValue(
              AppClipboard(writePlainText: clipSpy.writePlainText),
            ),
            correctionCaptureProvider.overrideWith(() => corrNotifier),
            checklistCompletionServiceProvider.overrideWith(
              _FakeCompletionService.new,
            ),
          ],
          child: const WidgetTestBench(
            child: ChecklistCardWrapper(
              entryId: 'missing',
              taskId: 'task-1',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(ChecklistCard), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    // ── Export markdown ────────────────────────────────────────────────────

    testWidgets('export markdown copies to clipboard and shows snackbar', (
      tester,
    ) async {
      final item1 = _makeItem(title: 'Task A');
      final item2 = _makeItem(id: 'item-2', title: 'Task B', isChecked: true);

      final result = await _pump(tester, items: [item1, item2]);
      final clip = result.clip;

      // Open the popup menu (the "more_vert" icon).
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap the export option.
      await tester.tap(find.byIcon(MdiIcons.exportVariant));
      await tester.pumpAndSettle();

      expect(clip.lastWritten, isNotNull);
      expect(clip.lastWritten, contains('Task A'));
      expect(clip.lastWritten, contains('Task B'));
      // Snackbar should appear with "copied" message.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'export markdown shows nothing-to-export snackbar for empty checklist',
      (tester) async {
        final cl = _makeChecklist(linkedItems: []);
        await _pump(
          tester,
          checklist: cl,
          completionCounts: const (completedCount: 0, totalCount: 0),
        );

        // Open the popup menu.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap export.
        await tester.tap(find.byIcon(MdiIcons.exportVariant));
        await tester.pumpAndSettle();

        // Should show the "nothing to export" snackbar.
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'export markdown shows error snackbar when clipboard throws',
      (tester) async {
        final item1 = _makeItem(title: 'Task A');

        final cl = _makeChecklist(linkedItems: ['item-1']);
        final corrNotifier = _FakeCorrectionCaptureNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checklistControllerProvider((
                id: cl.id,
                taskId: 'task-1',
              )).overrideWith(() => _FakeChecklistController(cl)),
              checklistCompletionRateControllerProvider(
                (id: cl.id, taskId: 'task-1'),
              ).overrideWith(() => _FakeCompletionRateController(0)),
              checklistCompletionControllerProvider(
                (id: cl.id, taskId: 'task-1'),
              ).overrideWith(
                () => _FakeCompletionController(
                  const (completedCount: 0, totalCount: 1),
                ),
              ),
              appClipboardProvider.overrideWithValue(
                AppClipboard(
                  writePlainText: (_) => throw Exception('clipboard error'),
                ),
              ),
              correctionCaptureProvider.overrideWith(() => corrNotifier),
              checklistCompletionServiceProvider.overrideWith(
                _FakeCompletionService.new,
              ),
              checklistItemControllerProvider(
                (id: 'item-1', taskId: 'task-1'),
              ).overrideWith(() => _FakeChecklistItemController(item1)),
            ],
            child: WidgetTestBench(
              child: ChecklistCardWrapper(
                entryId: cl.id,
                taskId: 'task-1',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Open menu and tap export.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(MdiIcons.exportVariant));
        await tester.pumpAndSettle();

        // Should show the error snackbar.
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    // ── Correction capture snackbar ────────────────────────────────────────

    testWidgets('shows correction undo snackbar on pending correction', (
      tester,
    ) async {
      final corrNotifier = _FakeCorrectionCaptureNotifier();
      await _pump(tester, correctionNotifier: corrNotifier);

      // Emit a pending correction.
      corrNotifier.emit(
        PendingCorrection(
          before: 'old text',
          after: 'new text',
          categoryId: 'cat-1',
          categoryName: 'Test Category',
          createdAt: _now,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorrectionUndoSnackbarContent), findsOneWidget);
      expect(find.textContaining('old text'), findsOneWidget);
      expect(find.textContaining('new text'), findsOneWidget);
    });

    // ── Completion rate and counts passed through ──────────────────────────

    testWidgets('passes completion counts to ChecklistCard', (tester) async {
      await _pump(
        tester,
        completionRate: 0.5,
        completionCounts: const (completedCount: 3, totalCount: 6),
      );

      final card = tester.widget<ChecklistCard>(find.byType(ChecklistCard));
      expect(card.completionRate, 0.5);
      expect(card.completedCount, 3);
      expect(card.totalCount, 6);
    });

    // ── Title and itemIds forwarded ────────────────────────────────────────

    testWidgets('forwards title and itemIds from checklist to card', (
      tester,
    ) async {
      final cl = _makeChecklist(
        title: 'My List',
        linkedItems: ['a', 'b', 'c'],
      );
      // Need item overrides for a, b, c
      final corrNotifier = _FakeCorrectionCaptureNotifier();
      final clipSpy = _ClipboardSpy();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checklistControllerProvider((
              id: cl.id,
              taskId: 'task-1',
            )).overrideWith(() => _FakeChecklistController(cl)),
            checklistCompletionRateControllerProvider(
              (id: cl.id, taskId: 'task-1'),
            ).overrideWith(() => _FakeCompletionRateController(0)),
            checklistCompletionControllerProvider(
              (id: cl.id, taskId: 'task-1'),
            ).overrideWith(
              () => _FakeCompletionController(
                const (completedCount: 0, totalCount: 3),
              ),
            ),
            appClipboardProvider.overrideWithValue(
              AppClipboard(writePlainText: clipSpy.writePlainText),
            ),
            correctionCaptureProvider.overrideWith(() => corrNotifier),
            checklistCompletionServiceProvider.overrideWith(
              _FakeCompletionService.new,
            ),
            for (final itemId in ['a', 'b', 'c'])
              checklistItemControllerProvider((
                id: itemId,
                taskId: 'task-1',
              )).overrideWith(() => _FakeChecklistItemController(null)),
          ],
          child: WidgetTestBench(
            child: ChecklistCardWrapper(
              entryId: cl.id,
              taskId: 'task-1',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final card = tester.widget<ChecklistCard>(find.byType(ChecklistCard));
      expect(card.title, 'My List');
      expect(card.itemIds, ['a', 'b', 'c']);
    });

    // ── onTitleSave wiring ─────────────────────────────────────────────────

    testWidgets('onTitleSave invokes notifier.updateTitle with new text', (
      tester,
    ) async {
      final cl = _makeChecklist(title: 'Old Title');
      final result = await _pump(
        tester,
        checklist: cl,
        initiallyExpanded: true,
      );

      // Tap the title text to enter edit mode.
      final titleText = find.text('Old Title');
      await tester.ensureVisible(titleText);
      await tester.tap(titleText);
      await tester.pump();

      // There should now be a TitleTextField for editing.
      expect(find.byType(TitleTextField), findsOneWidget);

      // Enter a new title and submit via Enter key.
      final titleField = find.byType(TitleTextField);
      await tester.enterText(titleField, 'New Title');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // The wrapper must have wired onTitleSave → notifier.updateTitle.
      expect(result.controller.lastUpdatedTitle, 'New Title');
    });

    // ── onCreateItem wiring ────────────────────────────────────────────────

    testWidgets(
      'onCreateItem invokes notifier.createChecklistItem with correct params',
      (tester) async {
        final cl = _makeChecklist(
          linkedItems: ['item-1'],
          title: 'My Checklist',
        );
        // Give the checklist a categoryId via the meta.
        final clWithCat =
            JournalEntity.checklist(
                  meta: _makeMeta(cl.id).copyWith(categoryId: 'cat-42'),
                  data: cl.data,
                )
                as Checklist;

        final result = await _pump(
          tester,
          checklist: clWithCat,
          items: [_makeItem()],
          initiallyExpanded: true,
        );

        // The add-item field is keyed as 'add-input-<checklistId>'.
        // Use enterText directly (it focuses the field internally) rather
        // than tapping first, since the field may be partially off-screen in
        // the constrained test viewport.
        final addFieldFinder = find.byKey(
          ValueKey('add-input-${clWithCat.id}'),
        );
        await tester.enterText(addFieldFinder, 'Buy bread');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump();

        // Verify the controller received the correct call.
        expect(result.controller.lastCreatedItemTitle, 'Buy bread');
        expect(result.controller.lastCreatedItemCategoryId, 'cat-42');
        expect(result.controller.lastCreatedItemIsChecked, isFalse);
      },
    );

    // ── _resolveItems error handler ────────────────────────────────────────

    testWidgets(
      '_resolveItems logs and recovers when an item provider throws',
      (tester) async {
        // A checklist with one item whose provider will throw.
        // completionRate = 1.0 causes the "All Done" empty state so that
        // ChecklistItemRow is never rendered — avoids ErrorWidget in the
        // widget tree while still exercising the catchError branch in
        // _resolveItems (lines 65–74) during the export flow.
        final cl = _makeChecklist(linkedItems: ['item-error']);
        final corrNotifier = _FakeCorrectionCaptureNotifier();
        final clipSpy = _ClipboardSpy();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checklistControllerProvider((
                id: cl.id,
                taskId: 'task-1',
              )).overrideWith(() => _FakeChecklistController(cl)),
              checklistCompletionRateControllerProvider(
                (id: cl.id, taskId: 'task-1'),
              ).overrideWith(() => _FakeCompletionRateController(1)),
              checklistCompletionControllerProvider(
                (id: cl.id, taskId: 'task-1'),
              ).overrideWith(
                () => _FakeCompletionController(
                  const (completedCount: 1, totalCount: 1),
                ),
              ),
              appClipboardProvider.overrideWithValue(
                AppClipboard(writePlainText: clipSpy.writePlainText),
              ),
              correctionCaptureProvider.overrideWith(() => corrNotifier),
              checklistCompletionServiceProvider.overrideWith(
                _FakeCompletionService.new,
              ),
              // The item provider throws to exercise the catchError branch.
              // With completionRate=1, the "All Done" empty state is shown
              // instead of ChecklistItemRow, so ErrorWidget is never built.
              checklistItemControllerProvider((
                id: 'item-error',
                taskId: 'task-1',
              )).overrideWith(_ThrowingChecklistItemController.new),
            ],
            child: WidgetTestBench(
              child: ChecklistCardWrapper(
                entryId: cl.id,
                taskId: 'task-1',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Open the popup menu and trigger export.  The export calls
        // _resolveItems which hits the catchError branch (lines 65–74).
        // After recovering, the resolved list is empty → "nothing to export".
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(MdiIcons.exportVariant));
        await tester.pumpAndSettle();

        // A snackbar (warning: nothing to export) is shown — confirming the
        // error branch was traversed without crashing the widget.
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    // ── Correction snackbar Undo button ───────────────────────────────────

    testWidgets('tapping Undo in correction snackbar calls cancel()', (
      tester,
    ) async {
      final corrNotifier = _FakeCorrectionCaptureNotifier();
      await _pump(tester, correctionNotifier: corrNotifier);

      // Emit a pending correction to trigger the snackbar.
      corrNotifier.emit(
        PendingCorrection(
          before: 'wrong',
          after: 'right',
          categoryId: 'cat-1',
          categoryName: 'Category',
          createdAt: DateTime.now(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CorrectionUndoSnackbarContent), findsOneWidget);

      // Invoke the onUndo callback directly from the widget — the snackbar
      // floats in an overlay layer and the hit-test offset won't reach it via
      // a normal tap(), so we extract the callback from the widget tree and
      // call it programmatically.
      final content = tester.widget<CorrectionUndoSnackbarContent>(
        find.byType(CorrectionUndoSnackbarContent),
      );
      content.onUndo();
      await tester.pump();

      // The fake cancel() should have been called.
      expect(corrNotifier.cancelCalled, isTrue);
    });

    // ── onExpansionChanged wiring ─────────────────────────────────────────

    testWidgets(
      'onExpansionChanged forwards checklist id and expansion state',
      (tester) async {
        final cl = _makeChecklist(id: 'cl-xyz', title: 'Expanding');

        final calls = <(String, bool)>[];
        await _pump(
          tester,
          checklist: cl,
          initiallyExpanded: true,
          onExpansionChanged: (id, expanded) => calls.add((id, expanded)),
        );

        // The initial post-frame callback fires with isExpanded = true.
        await tester.pump();
        expect(calls.any((c) => c.$1 == 'cl-xyz'), isTrue);

        // Tap the chevron to collapse.
        final chevron = find.byIcon(Icons.expand_more);
        await tester.ensureVisible(chevron);
        await tester.tap(chevron);
        await tester.pump();

        // After collapse, the last call should be (id, false).
        expect(calls.last, ('cl-xyz', false));
      },
    );

    // ── onShareMarkdown happy path ─────────────────────────────────────────

    testWidgets('onShareMarkdown shares emoji list for populated checklist', (
      tester,
    ) async {
      final spy = _ShareServiceSpy();
      final originalInstance = ShareService.instance;
      ShareService.instance = spy;
      addTearDown(() => ShareService.instance = originalInstance);

      final item1 = _makeItem(title: 'Buy apples');
      final item2 = _makeItem(
        id: 'item-2',
        title: 'Buy oranges',
        isChecked: true,
      );

      await _pump(tester, items: [item1, item2]);

      // Open the popup menu and tap Share.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.ios_share));
      await tester.pumpAndSettle();

      expect(spy.lastText, isNotNull);
      expect(spy.lastText, contains('Buy apples'));
      expect(spy.lastText, contains('Buy oranges'));
      expect(spy.lastSubject, equals('Test Checklist'));
    });

    testWidgets(
      'onShareMarkdown skips share when all items resolve to null',
      (tester) async {
        final spy = _ShareServiceSpy();
        final originalInstance = ShareService.instance;
        ShareService.instance = spy;
        addTearDown(() => ShareService.instance = originalInstance);

        // Checklist with no items → resolved list is empty → early return.
        final cl = _makeChecklist(linkedItems: []);
        await _pump(
          tester,
          checklist: cl,
          completionCounts: const (completedCount: 0, totalCount: 0),
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.ios_share));
        await tester.pumpAndSettle();

        // Share was never called because shareText is empty.
        expect(spy.lastText, isNull);
      },
    );

    testWidgets(
      'onShareMarkdown logs error when ShareService.shareText throws',
      (tester) async {
        final spy = _ShareServiceSpy()..shouldThrow = true;
        final originalInstance = ShareService.instance;
        ShareService.instance = spy;
        addTearDown(() => ShareService.instance = originalInstance);

        final item1 = _makeItem(title: 'Task X');
        await _pump(tester, items: [item1]);

        // Open the popup menu and tap Share — this will throw inside
        // onShareMarkdown; the catch block (lines 238-246) should log via
        // DomainLogger without propagating the exception.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.ios_share));
        await tester.pumpAndSettle();

        // No snackbar — the error is logged silently, not shown to the user.
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    // ── Export markdown with share-hint path ─────────────────────────────

    testWidgets(
      'export shows share-hint message when not yet seen (non-test env)',
      (tester) async {
        // Initialize SharedPreferences with no stored values so that
        // getBool('seen_checklist_share_hint') returns null → seen = false.
        SharedPreferences.setMockInitialValues({});

        // Temporarily pretend we are not in the test environment so that
        // shouldShowShareHint = !isTestEnv && !seen evaluates to true
        // (lines 201–206).
        isTestEnv = false;
        addTearDown(() => isTestEnv = true);

        final item1 = _makeItem(title: 'Task H');
        final result = await _pump(tester, items: [item1]);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(MdiIcons.exportVariant));
        await tester.pumpAndSettle();

        // Clipboard should still be written.
        expect(result.clip.lastWritten, isNotNull);
        expect(result.clip.lastWritten, contains('Task H'));
        // A snackbar should appear (with the share-hint appended to the
        // copied message, exercising the shouldShowShareHint = true branch).
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}
