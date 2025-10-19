import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/app_clipboard_service.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_wrapper.dart';

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

void main() {
  testWidgets('copies markdown and shows snackbar', (tester) async {
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
          checklistItemControllerProvider(
            id: itemId1,
            taskId: taskId,
          ).overrideWith(() => _MockChecklistItemController(item1)),
          checklistItemControllerProvider(
            id: itemId2,
            taskId: taskId,
          ).overrideWith(() => _MockChecklistItemController(item2)),
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

    // Tap the export icon (via tooltip for stability)
    final exportButton = find.byTooltip('Export checklist as Markdown');
    expect(exportButton, findsOneWidget);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    // Assert clipboard content
    expect(copied, '- [ ] First\n- [x] Second');

    // Assert snackbar shown with success message
    expect(find.text('Checklist copied as Markdown'), findsOneWidget);
  });
}
