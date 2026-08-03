import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class _MockEntryCreationService extends Mock implements EntryCreationService {}

void main() {
  final now = DateTime(2026, 8, 3, 13);

  Task buildTask({
    List<String>? checklistIds,
    EntryText? entryText,
    String? categoryId,
  }) {
    return Task(
      meta: Metadata(
        id: 'task-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: '',
        checklistIds: checklistIds,
      ),
      entryText: entryText,
    );
  }

  JournalEntry buildNote(String id) => JournalEntry(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    entryText: const EntryText(plainText: ''),
  );

  late _MockEntryCreationService creation;

  setUpAll(() {
    // `createChecklist` takes a Task, so mocktail needs a fallback for the
    // `any(named: 'task')` matcher below.
    registerFallbackValue(buildTask());
  });

  setUp(() {
    creation = _MockEntryCreationService();
    when(
      () => creation.createTextEntry(
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => creation.createChecklist(task: any(named: 'task')),
    ).thenAnswer((_) async => null);
  });

  Future<void> pump(
    WidgetTester tester, {
    required Task task,
    bool templatesExist = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          entryCreationServiceProvider.overrideWithValue(creation),
          taskAgentTemplatesExistProvider.overrideWith(
            (ref) async => templatesExist,
          ),
        ],
        child: WidgetTestBench(child: TaskFirstRunActions(task: task)),
      ),
    );
    await tester.pump();
  }

  group('TaskFirstRunActions.isBlank', () {
    test('a bare task with no agent is blank', () {
      expect(TaskFirstRunActions.isBlank(buildTask(), hasAgent: false), isTrue);
    });

    test('an attached agent means the task is already doing something', () {
      expect(TaskFirstRunActions.isBlank(buildTask(), hasAgent: true), isFalse);
    });

    test('one checklist is enough content to retire the block', () {
      expect(
        TaskFirstRunActions.isBlank(
          buildTask(checklistIds: const ['c1']),
          hasAgent: false,
        ),
        isFalse,
      );
    });

    test(
      'a linked entry retires the block — that is where "Write a note" puts '
      'its note, so without this the row kept offering itself after use',
      () {
        expect(
          TaskFirstRunActions.isBlank(
            buildTask(),
            hasAgent: false,
            hasLinkedEntries: true,
          ),
          isFalse,
        );
      },
    );

    test('body text retires the block; whitespace-only text does not', () {
      expect(
        TaskFirstRunActions.isBlank(
          buildTask(entryText: const EntryText(plainText: 'notes')),
          hasAgent: false,
        ),
        isFalse,
      );
      expect(
        TaskFirstRunActions.isBlank(
          buildTask(entryText: const EntryText(plainText: '   \n ')),
          hasAgent: false,
        ),
        isTrue,
      );
    });
  });

  group('TaskFirstRunActions rendering', () {
    testWidgets('offers writing FIRST — the act the app exists for', (
      tester,
    ) async {
      await pump(tester, task: buildTask());

      final titles = tester
          .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
          .map((row) => row.title)
          .toList();

      expect(titles, [
        'Write a note',
        'Add a checklist',
        'Record a voice note',
        'Assign an agent',
      ]);
    });

    testWidgets(
      'without a single task-agent template the agent row is absent — the '
      'picker would dead-end on a warning toast',
      (tester) async {
        await pump(tester, task: buildTask(), templatesExist: false);

        expect(find.text('Assign an agent'), findsNothing);
        expect(find.text('Write a note'), findsOneWidget);
        expect(find.byType(DesignSystemListItem), findsNWidgets(3));
      },
    );

    testWidgets(
      'the note row creates a text entry linked to this task AND scrolls to '
      'it — a linked entry does not navigate on its own, so without the focus '
      'intent the row looked like a dead button that silently made empty notes',
      (tester) async {
        final container = ProviderContainer(
          overrides: <Override>[
            entryCreationServiceProvider.overrideWithValue(creation),
            taskAgentTemplatesExistProvider.overrideWith((ref) async => true),
          ],
        );
        addTearDown(container.dispose);

        when(
          () => creation.createTextEntry(
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => buildNote('note-1'));

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: WidgetTestBench(
              child: TaskFirstRunActions(task: buildTask(categoryId: 'cat-1')),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Write a note'));
        await tester.pumpAndSettle();

        verify(
          () => creation.createTextEntry(
            linkedId: 'task-1',
            categoryId: 'cat-1',
          ),
        ).called(1);

        final intent = container.read(taskFocusControllerProvider('task-1'));
        expect(intent, isNotNull);
        expect(intent!.entryId, 'note-1');
      },
    );

    testWidgets('the checklist row creates a checklist on this task', (
      tester,
    ) async {
      final task = buildTask();
      await pump(tester, task: task);

      await tester.tap(find.text('Add a checklist'));
      await tester.pump();

      verify(() => creation.createChecklist(task: task)).called(1);
    });

    testWidgets(
      'trailing glyph says what the tap does: + creates in place, chevron '
      'opens a picker',
      (tester) async {
        await pump(tester, task: buildTask());

        IconData glyphFor(String label) {
          final row = find.ancestor(
            of: find.text(label),
            matching: find.byType(DesignSystemListItem),
          );
          return tester
              .widget<Icon>(
                find.descendant(of: row, matching: find.byType(Icon)).last,
              )
              .icon!;
        }

        // Four identical chevrons over four different behaviours told the
        // user nothing — and two of these rows retire the whole card from
        // under the finger.
        expect(glyphFor('Write a note'), Icons.add_rounded);
        expect(glyphFor('Add a checklist'), Icons.add_rounded);
        expect(glyphFor('Record a voice note'), Icons.arrow_forward_ios);
        expect(glyphFor('Assign an agent'), Icons.arrow_forward_ios);
      },
    );

    testWidgets(
      'only the agent row carries an explanation — three worded verbs need '
      'none, and a subtitle on each would make the block a paragraph',
      (tester) async {
        await pump(tester, task: buildTask());

        final subtitles = tester
            .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
            .map((row) => row.subtitle)
            .toList();

        expect(subtitles.whereType<String>(), hasLength(1));
        expect(
          subtitles.last,
          'Let an agent draft steps and summaries.',
          reason:
              'one short sentence describing what the tap does — it used to '
              'describe the category-default screen instead, which made the '
              "card's most optional row its largest",
        );
      },
    );
  });
}
