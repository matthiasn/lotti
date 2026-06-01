import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/linked_from_checklist_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------

final _itemMeta = Metadata(
  id: 'item-1',
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  dateFrom: DateTime(2024, 3, 15),
  dateTo: DateTime(2024, 3, 15),
);

ChecklistItem _makeItem({List<String> linkedChecklists = const []}) =>
    ChecklistItem(
      meta: _itemMeta,
      data: ChecklistItemData(
        title: 'My Task Item',
        isChecked: false,
        linkedChecklists: linkedChecklists,
      ),
    );

// ---------------------------------------------------------------------------
// Fake ChecklistController
// ---------------------------------------------------------------------------

class _FakeChecklistController extends ChecklistController {
  _FakeChecklistController(this._checklist)
    : super(const (id: 'cl', taskId: null));

  final Checklist? _checklist;

  @override
  Future<Checklist?> build() async => _checklist;
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pump(
  WidgetTester tester,
  ChecklistItem item, {
  Map<String, Checklist?> checklistMap = const {},
}) async {
  final overrides = <Override>[
    for (final entry in checklistMap.entries)
      checklistControllerProvider((
        id: entry.key,
        taskId: item.id,
      )).overrideWith(() => _FakeChecklistController(entry.value)),
  ];

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      LinkedFromChecklistWidget(item),
      overrides: overrides,
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);
        when(() => mockCache.showPrivateEntries).thenReturn(true);
        getIt.registerSingleton<EntitiesCacheService>(mockCache);
      },
    );
  });
  tearDownAll(tearDownTestGetIt);

  group('LinkedFromChecklistWidget', () {
    testWidgets(
      'renders nothing when linkedChecklists is empty',
      (tester) async {
        await _pump(tester, _makeItem());

        expect(find.textContaining('Linked from'), findsNothing);
        expect(find.byType(LinkedFromChecklistWidget), findsOneWidget);
      },
    );

    testWidgets(
      'shows "Linked from" label when linkedChecklists is not empty',
      (tester) async {
        const checklistId = 'cl-xyz';
        final checklist = Checklist(
          meta: Metadata(
            id: checklistId,
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: const ChecklistData(
            title: 'Parent Checklist',
            linkedChecklistItems: [],
            linkedTasks: [],
          ),
        );

        await _pump(
          tester,
          _makeItem(linkedChecklists: [checklistId]),
          checklistMap: {checklistId: checklist},
        );

        expect(find.textContaining('Linked from'), findsOneWidget);
      },
    );

    testWidgets(
      'renders label but no card when checklist is null for a given ID',
      (tester) async {
        await _pump(
          tester,
          _makeItem(linkedChecklists: ['missing-cl']),
          checklistMap: {'missing-cl': null},
        );

        // Label still appears because linkedChecklists is non-empty
        expect(find.textContaining('Linked from'), findsOneWidget);
        // No crash — widget tree is valid
        expect(find.byType(LinkedFromChecklistWidget), findsOneWidget);
      },
    );
  });
}
