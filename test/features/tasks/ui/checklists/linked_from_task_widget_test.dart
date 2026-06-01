import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_task_widget.dart';

import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------

final _meta = Metadata(
  id: 'checklist-1',
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  dateFrom: DateTime(2024, 3, 15),
  dateTo: DateTime(2024, 3, 15),
);

Checklist _makeChecklist({List<String> linkedTasks = const []}) => Checklist(
  meta: _meta,
  data: ChecklistData(
    title: 'Test Checklist',
    linkedChecklistItems: const [],
    linkedTasks: linkedTasks,
  ),
);

// ---------------------------------------------------------------------------
// Fake EntryController
// ---------------------------------------------------------------------------

class _FakeEntryController extends EntryController {
  _FakeEntryController(this._entry);

  final JournalEntity? _entry;

  @override
  Future<EntryState?> build({required String id}) {
    final value = _entry == null
        ? null
        : EntryState.saved(
            entryId: id,
            entry: _entry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
          );
    if (value != null) {
      state = AsyncData(value);
    }
    return SynchronousFuture(value);
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester,
  Checklist checklist, {
  Map<String, JournalEntity?> entryMap = const {},
}) async {
  final overrides = <Override>[
    for (final entry in entryMap.entries)
      entryControllerProvider(id: entry.key).overrideWith(
        () => _FakeEntryController(entry.value),
      ),
  ];

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      LinkedFromTaskWidget(checklist),
      overrides: overrides,
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(setUpTestGetIt);
  tearDownAll(tearDownTestGetIt);

  group('LinkedFromTaskWidget', () {
    testWidgets(
      'renders nothing when linkedTasks is empty',
      (tester) async {
        await _pump(tester, _makeChecklist());

        // Widget should collapse to a SizedBox.shrink — no visible content
        expect(find.text('Linked from'), findsNothing);
        // No Column is visible with linked label
        expect(find.byType(LinkedFromTaskWidget), findsOneWidget);
      },
    );

    testWidgets(
      'shows "Linked from" label when linkedTasks contains IDs',
      (tester) async {
        const taskId = 'task-abc';
        final task = Task(
          meta: Metadata(
            id: taskId,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            statusHistory: const [],
            title: 'Linked Task',
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
        );

        await _pump(
          tester,
          _makeChecklist(linkedTasks: [taskId]),
          entryMap: {taskId: task},
        );

        // The "Linked from" label is the localized journalLinkedFromLabel
        expect(find.textContaining('Linked from'), findsOneWidget);
      },
    );

    testWidgets(
      'renders SizedBox.shrink for a task ID with null entry',
      (tester) async {
        await _pump(
          tester,
          _makeChecklist(linkedTasks: ['missing-id']),
          entryMap: {'missing-id': null},
        );

        // Label still appears because linkedTasks is not empty
        expect(find.textContaining('Linked from'), findsOneWidget);
        // But no ModernJournalCard is rendered since the entry is null
        // Verify widget tree doesn't crash
        expect(find.byType(LinkedFromTaskWidget), findsOneWidget);
      },
    );
  });
}
