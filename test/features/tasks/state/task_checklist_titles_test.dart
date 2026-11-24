import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/state/task_checklist_titles.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_entry_controller.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

Metadata _meta(String id, {DateTime? deletedAt}) => Metadata(
  id: id,
  createdAt: DateTime(2026, 11, 20),
  updatedAt: DateTime(2026, 11, 20),
  dateFrom: DateTime(2026, 11, 20),
  dateTo: DateTime(2026, 11, 20),
  deletedAt: deletedAt,
);

ChecklistItem _item(
  String id,
  String title, {
  bool archived = false,
  DateTime? deletedAt,
}) => ChecklistItem(
  meta: _meta(id, deletedAt: deletedAt),
  data: ChecklistItemData(
    title: title,
    isChecked: false,
    isArchived: archived,
    linkedChecklists: const ['cl-1'],
  ),
);

class _FakeChecklist extends ChecklistController {
  _FakeChecklist(this._checklist) : super(const (id: 'cl-1', taskId: null));
  final Checklist? _checklist;
  @override
  Future<Checklist?> build() async => _checklist;
}

/// A checklist item still loading until [gate] completes.
class _LoadingItem extends ChecklistItemController {
  _LoadingItem(this.gate, this._item) : super(const (id: 'fake', taskId: null));
  final Completer<void> gate;
  final ChecklistItem _item;
  @override
  Future<ChecklistItem?> build() async {
    await gate.future;
    return _item;
  }
}

class _FakeItem extends ChecklistItemController {
  _FakeItem(this._item) : super(const (id: 'fake', taskId: null));
  final ChecklistItem? _item;
  @override
  Future<ChecklistItem?> build() async => _item;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ChecklistItemData(
        title: '',
        isChecked: false,
        linkedChecklists: [],
      ),
    );
  });

  final task = testTask.copyWith(
    meta: testTask.meta.copyWith(categoryId: 'colony'),
    data: testTask.data.copyWith(checklistIds: ['cl-1', 'cl-2']),
  );

  group('titles', () {
    test('a report row becomes a plain one-line title', () {
      expect(
        plainChecklistTitle(
          'Read **the** [spec](https://example.com)\n  and `run` it',
        ),
        'Read the spec and run it',
      );
    });

    test('only paired marks go: identifiers and code text stay', () {
      expect(
        plainChecklistTitle('Run `flutter_test` now'),
        'Run flutter_test now',
      );
      expect(plainChecklistTitle('Check foo_bar'), 'Check foo_bar');
      expect(
        plainChecklistTitle('Read [Spec](https://example.org/guide_(v2)) now'),
        'Read Spec now',
      );
      // Emphasis across a line break comes out too.
      expect(plainChecklistTitle('**Review\nspec**'), 'Review spec');
      expect(
        checklistTitleKey(plainChecklistTitle('**Review\nspec**')),
        checklistTitleKey('**Review\nspec**'),
      );
      // Nested emphasis comes out whole, so the stored title keys the same.
      expect(
        plainChecklistTitle('Run the **__feeder__** test'),
        'Run the feeder test',
      );
      expect(
        checklistTitleKey(plainChecklistTitle('Run the **__feeder__** test')),
        checklistTitleKey('Run the **__feeder__** test'),
      );
      expect(plainChecklistTitle('Rate it 4 * 5'), 'Rate it 4 * 5');
      expect(
        checklistTitleKey('Check foo_bar'),
        isNot(checklistTitleKey('Check foobar')),
      );
    });

    test('the same to-do matches however it is cased or closed', () {
      expect(
        checklistTitleKey('Run the *feeder* test.'),
        checklistTitleKey('run the feeder test'),
      );
      expect(
        checklistTitleKey('Run the feeder test'),
        isNot(checklistTitleKey('Run the feeder')),
      );
    });
  });

  group('addTodoToTaskChecklist', () {
    late MockChecklistRepository repository;
    setUp(() => repository = MockChecklistRepository());

    test("adds an open item to the task's first checklist", () async {
      when(
        () => repository.addItemToChecklist(
          checklistId: any(named: 'checklistId'),
          title: any(named: 'title'),
          isChecked: any(named: 'isChecked'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => _item('new', 'Run the feeder test'));

      final added = await addTodoToTaskChecklist(
        repository,
        task: task,
        text: 'Run the **feeder** test',
      );

      expect(added, isTrue);
      verify(
        () => repository.addItemToChecklist(
          checklistId: 'cl-1',
          title: 'Run the feeder test',
          isChecked: false,
          categoryId: 'colony',
        ),
      ).called(1);
    });

    test('a task without a checklist gets one holding the item', () async {
      when(
        () => repository.createChecklist(
          taskId: any(named: 'taskId'),
          items: any(named: 'items'),
        ),
      ).thenAnswer(
        (_) async => (
          checklist: Checklist(
            meta: _meta('cl-new'),
            data: const ChecklistData(
              title: 'Checklist',
              linkedChecklistItems: [],
              linkedTasks: [],
            ),
          ),
          createdItems: const [
            (id: 'new', title: 'Run the feeder test', isChecked: false),
          ],
        ),
      );

      final added = await addTodoToTaskChecklist(
        repository,
        task: testTask,
        text: 'Run the feeder test',
      );

      expect(added, isTrue);
      final items =
          verify(
                () => repository.createChecklist(
                  taskId: testTask.id,
                  items: captureAny(named: 'items'),
                ),
              ).captured.single
              as List<ChecklistItemData>;
      expect(items.single.title, 'Run the feeder test');
      expect(items.single.isChecked, isFalse);
    });

    test('a new checklist without the item is not an add', () async {
      when(
        () => repository.createChecklist(
          taskId: any(named: 'taskId'),
          items: any(named: 'items'),
        ),
      ).thenAnswer(
        (_) async => (
          checklist: Checklist(
            meta: _meta('cl-new'),
            data: const ChecklistData(
              title: 'Checklist',
              linkedChecklistItems: [],
              linkedTasks: [],
            ),
          ),
          createdItems: <({String id, String title, bool isChecked})>[],
        ),
      );

      expect(
        await addTodoToTaskChecklist(
          repository,
          task: testTask,
          text: 'Run the feeder test',
        ),
        isFalse,
      );
    });

    test('a row with no words adds nothing', () async {
      expect(
        await addTodoToTaskChecklist(repository, task: task, text: '  \n '),
        isFalse,
      );
      verifyZeroInteractions(repository);
    });
  });

  test("the task's active item titles, live from its controllers", () async {
    // The fake entry controller still reaches the editor state service.
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<EditorStateService>(
        MockEditorStateService(),
      ),
    );
    addTearDown(tearDownTestGetIt);
    // The fake entry controller still reaches the editor state service.
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<EditorStateService>(
        MockEditorStateService(),
      ),
    );
    addTearDown(tearDownTestGetIt);
    final container = ProviderContainer(
      overrides: [
        entryControllerProvider(
          task.id,
        ).overrideWith(() => FakeEntryController(task)),
        checklistControllerProvider((id: 'cl-1', taskId: task.id)).overrideWith(
          () => _FakeChecklist(
            Checklist(
              meta: _meta('cl-1'),
              data: const ChecklistData(
                title: 'Pre-launch',
                linkedChecklistItems: ['i1', 'i2', 'i3'],
                linkedTasks: [],
              ),
            ),
          ),
        ),
        checklistControllerProvider((
          id: 'cl-2',
          taskId: task.id,
        )).overrideWith(() => _FakeChecklist(null)),
        checklistItemControllerProvider((
          id: 'i1',
          taskId: task.id,
        )).overrideWith(() => _FakeItem(_item('i1', 'Run the feeder test.'))),
        checklistItemControllerProvider((
          id: 'i2',
          taskId: task.id,
        )).overrideWith(
          () => _FakeItem(_item('i2', 'Archived one', archived: true)),
        ),
        checklistItemControllerProvider((
          id: 'i3',
          taskId: task.id,
        )).overrideWith(
          () => _FakeItem(
            _item('i3', 'Deleted one', deletedAt: DateTime(2026, 11, 21)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      taskChecklistTitleKeysProvider(task.id),
      (_, _) {},
    );
    addTearDown(subscription.close);

    // Let every controller the provider watches finish loading.
    for (final id in ['cl-1', 'cl-2']) {
      await container.read(
        checklistControllerProvider((id: id, taskId: task.id)).future,
      );
    }
    for (final id in ['i1', 'i2', 'i3']) {
      await container.read(
        checklistItemControllerProvider((id: id, taskId: task.id)).future,
      );
    }

    expect(subscription.read(), {'run the feeder test'});
  });

  test('nothing until every checklist item has loaded', () async {
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<EditorStateService>(
        MockEditorStateService(),
      ),
    );
    addTearDown(tearDownTestGetIt);
    final gate = Completer<void>();
    final single = task.copyWith(
      data: task.data.copyWith(checklistIds: ['cl-1']),
    );
    final container = ProviderContainer(
      overrides: [
        entryControllerProvider(
          single.id,
        ).overrideWith(() => FakeEntryController(single)),
        checklistControllerProvider((
          id: 'cl-1',
          taskId: single.id,
        )).overrideWith(
          () => _FakeChecklist(
            Checklist(
              meta: _meta('cl-1'),
              data: const ChecklistData(
                title: 'Pre-launch',
                linkedChecklistItems: ['i1'],
                linkedTasks: [],
              ),
            ),
          ),
        ),
        checklistItemControllerProvider((
          id: 'i1',
          taskId: single.id,
        )).overrideWith(
          () => _LoadingItem(gate, _item('i1', 'Run the feeder test')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      taskChecklistTitleKeysProvider(single.id),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(
      checklistControllerProvider((id: 'cl-1', taskId: single.id)).future,
    );

    // The item is still loading: no partial set that would offer to add it.
    expect(subscription.read(), isNull);

    gate.complete();
    await container.read(
      checklistItemControllerProvider((id: 'i1', taskId: single.id)).future,
    );
    expect(subscription.read(), {'run the feeder test'});
  });
}
