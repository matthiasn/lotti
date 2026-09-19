import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/journal_card.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_task_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
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
  Future<EntryState?> build() {
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
      entryControllerProvider(entry.key).overrideWith(
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
  setUpAll(
    () => setUpTestGetIt(
      additionalSetup: () {
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById(any())).thenReturn(null);
        when(() => cache.getLabelById(any())).thenReturn(null);
        when(() => cache.showPrivateEntries).thenReturn(true);
        // EntryController resolves the editor-state service when it is
        // constructed; without it the overridden controller fails to build
        // and no linked task ever resolves.
        final timeService = MockTimeService();
        when(timeService.getStream).thenAnswer((_) => const Stream.empty());
        when(timeService.getCurrent).thenReturn(null);
        getIt
          ..registerSingleton<TimeService>(timeService)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<EntitiesCacheService>(cache);
      },
    ),
  );
  tearDownAll(tearDownTestGetIt);

  group('LinkedFromTaskWidget', () {
    testWidgets(
      'renders nothing when linkedTasks is empty',
      (tester) async {
        await _pump(tester, _makeChecklist());

        // Widget should collapse to a SizedBox.shrink — no visible content
        expect(find.text('Linked from'), findsNothing);
        expect(find.byType(ModernJournalCard), findsNothing);
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
        final card = tester.widget<ModernJournalCard>(
          find.byType(ModernJournalCard),
        );
        expect(card.item.meta.id, taskId);
        expect(find.text('Linked Task'), findsOneWidget);
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
        // But no card is rendered since the entry is null.
        expect(find.byType(ModernJournalCard), findsNothing);
      },
    );
  });
}
