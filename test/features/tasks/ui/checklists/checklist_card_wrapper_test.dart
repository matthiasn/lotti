import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

  @override
  Future<Checklist?> build() async => _checklist;

  @override
  Future<void> updateTitle(String? title) async {}

  @override
  Future<String?> createChecklistItem(
    String? title, {
    required String? categoryId,
    required bool isChecked,
  }) async => 'new-item';

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

  // ignore: use_setters_to_change_properties
  void emit(PendingCorrection pending) {
    state = pending;
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

Future<_ClipboardSpy> _pump(
  WidgetTester tester, {
  Checklist? checklist,
  List<ChecklistItem> items = const [],
  double completionRate = 0.0,
  ChecklistCompletionState completionCounts = const (
    completedCount: 0,
    totalCount: 2,
  ),
  _FakeCorrectionCaptureNotifier? correctionNotifier,
}) async {
  final cl = checklist ?? _makeChecklist();
  final clipSpy = _ClipboardSpy();

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
        )).overrideWith(() => _FakeChecklistController(cl)),
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
      ],
      child: WidgetTestBench(
        child: ChecklistCardWrapper(
          entryId: cl.id,
          taskId: 'task-1',
        ),
      ),
    ),
  );
  // Two pumps: resolve async providers then rebuild.
  await tester.pump();
  await tester.pump();

  return clipSpy;
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

      final clipSpy = await _pump(
        tester,
        items: [item1, item2],
      );

      // Open the popup menu (the "more_vert" icon).
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap the export option.
      await tester.tap(find.byIcon(MdiIcons.exportVariant));
      await tester.pumpAndSettle();

      expect(clipSpy.lastWritten, isNotNull);
      expect(clipSpy.lastWritten, contains('Task A'));
      expect(clipSpy.lastWritten, contains('Task B'));
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
  });
}
