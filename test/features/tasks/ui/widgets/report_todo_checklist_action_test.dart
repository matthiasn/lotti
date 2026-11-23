import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/tasks/state/task_checklist_titles.dart';
import 'package:lotti/features/tasks/ui/widgets/report_todo_checklist_action.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/checklist_repository.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final task = testTask.copyWith(
    data: testTask.data.copyWith(checklistIds: ['cl-1']),
  );
  late MockChecklistRepository repository;

  setUp(() async {
    repository = MockChecklistRepository();
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<EditorStateService>(
        MockEditorStateService(),
      ),
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(WidgetTester tester, Set<String>? keys) =>
      tester.pumpWidget(
        makeTestableWidgetNoScroll(
          // A Scaffold, so the error toast has somewhere to show.
          Scaffold(
            body: ReportTodoChecklistAction(
              taskId: task.id,
              text: 'Run the **feeder** test',
            ),
          ),
          overrides: [
            createEntryControllerOverride(task),
            taskChecklistTitleKeysProvider(task.id).overrideWithValue(keys),
            checklistRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

  testWidgets('draws nothing until the task has loaded', (tester) async {
    await pump(tester, null);
    expect(find.byType(DesignSystemIconAction), findsNothing);
    expect(find.byTooltip('On the checklist'), findsNothing);
  });

  testWidgets('a to-do the checklist holds is marked, not offered', (
    tester,
  ) async {
    await pump(tester, {'run the feeder test'});
    expect(find.byTooltip('On the checklist'), findsOneWidget);
    expect(find.byType(DesignSystemIconAction), findsNothing);
  });

  testWidgets('any other to-do is added, as plain words, on a tap', (
    tester,
  ) async {
    when(
      () => repository.addItemToChecklist(
        checklistId: any(named: 'checklistId'),
        title: any(named: 'title'),
        isChecked: any(named: 'isChecked'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer(
      (_) async => ChecklistItem(
        meta: task.meta,
        data: const ChecklistItemData(
          title: 'Run the feeder test',
          isChecked: false,
          linkedChecklists: ['cl-1'],
        ),
      ),
    );
    await pump(tester, {'something else'});

    await tester.tap(find.byTooltip('Add to checklist'));
    await tester.pump();

    verify(
      () => repository.addItemToChecklist(
        checklistId: 'cl-1',
        title: 'Run the feeder test',
        isChecked: false,
        categoryId: task.meta.categoryId,
      ),
    ).called(1);
  });

  testWidgets('a failed add says so and keeps the button for another try', (
    tester,
  ) async {
    var calls = 0;
    when(
      () => repository.addItemToChecklist(
        checklistId: any(named: 'checklistId'),
        title: any(named: 'title'),
        isChecked: any(named: 'isChecked'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async {
      calls++;
      // The first write fails quietly, the second throws.
      if (calls == 2) throw StateError('write failed');
      return null;
    });
    await pump(tester, {'something else'});

    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.byTooltip('Add to checklist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text("Couldn't add it to the checklist"), findsOneWidget);
      expect(find.byTooltip('Add to checklist'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    }
    expect(calls, 2);
  });

  testWidgets('the task page builder gives the action for its task', (
    tester,
  ) async {
    final widget = reportTodoChecklistActionFor(task.id)('Ship it');
    expect(widget, isA<ReportTodoChecklistAction>());
    expect((widget as ReportTodoChecklistAction).taskId, task.id);
    expect(widget.text, 'Ship it');
  });
}
