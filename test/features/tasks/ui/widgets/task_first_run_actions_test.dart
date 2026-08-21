import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/features/tasks/ui/widgets/task_first_run_actions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/create/entry_creation_service.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_linked_entries_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

class _MockEntryCreationService extends Mock implements EntryCreationService {}

/// Prototype for mocktail's `any<BuildContext>()`; never interacted with.
class _FakeBuildContext extends Fake implements BuildContext {}

/// Resolves to no entry, so the assign flow takes its early return instead of
/// reaching a picker. `EntryController`'s own field initializer still resolves
/// `EditorStateService` from getIt even when the class is overridden, which is
/// why the test registers one.
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build() async => null;
}

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
    registerFallbackValue(_FakeBuildContext());
    // `createChecklist` takes a Task, so mocktail needs a fallback for the
    // `any(named: 'task')` matcher below.
    registerFallbackValue(buildTask());
  });

  setUp(() async {
    // The shared harness rather than a hand-rolled graph: the assign flow
    // resolves `entryControllerProvider`, whose base-class initializers reach
    // into getIt for the editor state service and the journal DB even when the
    // controller itself is overridden.
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<EditorStateService>(
        MockEditorStateService(),
      ),
    );
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
    when(
      () => creation.showAudioRecordingModal(
        any(),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) {});
  });

  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    required Task task,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          entryCreationServiceProvider.overrideWithValue(creation),
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

  group('watchTaskFirstRunState', () {
    /// Renders a probe that records the state on every build, so a test can
    /// assert on what the surfaces branching on it would have seen — including
    /// the frames before the database answered.
    Future<List<TaskFirstRunState>> pumpProbe(
      WidgetTester tester, {
      required Task task,
      required Future<AgentDomainEntity?> agent,
    }) async {
      final seen = <TaskFirstRunState>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            entryCreationServiceProvider.overrideWithValue(creation),
            linkedEntriesControllerProvider(
              task.meta.id,
            ).overrideWith(FakeLinkedEntriesController.new),
            taskAgentProvider.overrideWith((ref, id) => agent),
          ],
          child: WidgetTestBench(
            child: Consumer(
              builder: (context, ref, _) {
                seen.add(watchTaskFirstRunState(ref, task));
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return seen;
    }

    testWidgets(
      'an outstanding agent lookup reads as unresolved, not as established — '
      'guessing either way is what reflowed a new task after it painted',
      (tester) async {
        final pending = Completer<AgentDomainEntity?>();
        addTearDown(() => pending.complete(null));

        final seen = await pumpProbe(
          tester,
          task: buildTask(),
          agent: pending.future,
        );

        expect(seen, everyElement(TaskFirstRunState.unresolved));
      },
    );

    testWidgets('a blank task with nothing attached settles on first-run', (
      tester,
    ) async {
      final seen = await pumpProbe(
        tester,
        task: buildTask(),
        agent: Future<AgentDomainEntity?>.value(),
      );

      await tester.pumpAndSettle();
      expect(seen.last, TaskFirstRunState.firstRun);
    });

    testWidgets(
      'a task carrying its own content answers established immediately, '
      'without waiting on a lookup that can only ever add content',
      (tester) async {
        final pending = Completer<AgentDomainEntity?>();
        addTearDown(() => pending.complete(null));

        final seen = await pumpProbe(
          tester,
          task: buildTask(checklistIds: const ['c1']),
          agent: pending.future,
        );

        expect(seen, everyElement(TaskFirstRunState.established));
      },
    );

    testWidgets(
      'a failed lookup resolves as established rather than holding the page '
      'on its shell forever',
      (tester) async {
        // Completed after the provider is listening, so the failure lands on
        // Riverpod rather than on the test's zone.
        final failing = Completer<AgentDomainEntity?>();
        final seen = await pumpProbe(
          tester,
          task: buildTask(),
          agent: failing.future,
        );
        failing.completeError(Exception('no agents'));
        await tester.pumpAndSettle();

        expect(seen.last, TaskFirstRunState.established);
      },
    );

    testWidgets('watchTaskIsFirstRun reads unresolved as not-first-run', (
      tester,
    ) async {
      final pending = Completer<AgentDomainEntity?>();
      addTearDown(() => pending.complete(null));
      var isFirstRun = true;
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            linkedEntriesControllerProvider(
              task.meta.id,
            ).overrideWith(FakeLinkedEntriesController.new),
            taskAgentProvider.overrideWith((ref, id) => pending.future),
          ],
          child: WidgetTestBench(
            child: Consumer(
              builder: (context, ref, _) {
                isFirstRun = watchTaskIsFirstRun(ref, task);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(isFirstRun, isFalse);
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
      'the note row creates a text entry linked to this task AND scrolls to '
      'it — a linked entry does not navigate on its own, so without the focus '
      'intent the row looked like a dead button that silently made empty notes',
      (tester) async {
        final container = ProviderContainer(
          overrides: <Override>[
            entryCreationServiceProvider.overrideWithValue(creation),
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

    testWidgets(
      'a second tap is dropped while the write is in flight AND after it '
      'succeeds — the block retires on a provider rebuild some frames later, '
      'so re-arming on completion left a second window to double-tap through',
      (tester) async {
        final pending = Completer<JournalEntity?>();
        when(
          () => creation.createTextEntry(
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) => pending.future);

        await pump(tester, task: buildTask(categoryId: 'cat-1'));

        await tester.tap(find.text('Write a note'));
        await tester.pump();
        await tester.tap(find.text('Write a note'));
        await tester.pump();

        verify(
          () => creation.createTextEntry(
            linkedId: 'task-1',
            categoryId: 'cat-1',
          ),
        ).called(1);

        // The write lands. The row has done its job and stays inert — the
        // block is on its way out, but not for several more frames.
        pending.complete(buildNote('note-1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Write a note'));
        await tester.pump();

        verifyNever(
          () => creation.createTextEntry(
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
      },
    );

    testWidgets(
      'a write that produced nothing re-arms the row — a failure must not '
      'leave the only path to a note permanently dead',
      (tester) async {
        final pending = Completer<JournalEntity?>();
        when(
          () => creation.createTextEntry(
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) => pending.future);

        await pump(tester, task: buildTask(categoryId: 'cat-1'));

        await tester.tap(find.text('Write a note'));
        await tester.pump();
        pending.complete(null);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Write a note'));
        await tester.pump();

        verify(
          () => creation.createTextEntry(
            linkedId: 'task-1',
            categoryId: 'cat-1',
          ),
        ).called(2);
      },
    );

    testWidgets('the voice-note row opens the audio recording modal', (
      tester,
    ) async {
      await pump(tester, task: buildTask(categoryId: 'cat-1'));

      await tester.tap(find.text('Record a voice note'));
      await tester.pump();

      verify(
        () => creation.showAudioRecordingModal(
          any(),
          linkedId: 'task-1',
          categoryId: 'cat-1',
        ),
      ).called(1);
    });

    testWidgets(
      'the agent row runs the assign flow — it short-circuits when the entry '
      'is not a task, which is the guard that keeps a stale id harmless',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              entryCreationServiceProvider.overrideWithValue(creation),
              entryControllerProvider(
                'task-1',
              ).overrideWith(_NullEntryController.new),
            ],
            child: WidgetTestBench(
              child: TaskFirstRunActions(task: buildTask()),
            ),
          ),
        );
        await tester.pump();

        // The entry resolves to nothing, so the flow returns before any
        // picker. What matters is that the row is wired to the shared flow at
        // all and survives the miss.
        await tester.tap(find.text('Assign an agent'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
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
        expect(glyphFor('Write a note'), LottiIcons.add);
        expect(glyphFor('Add a checklist'), LottiIcons.add);
        expect(glyphFor('Record a voice note'), LottiIcons.chevronRight);
        expect(glyphFor('Assign an agent'), LottiIcons.chevronRight);
      },
    );

    testWidgets(
      'every row carries a one-line explanation — a subtitle on only the '
      'agent row bottom-weighted the card and read as that row mattering '
      'most, when order (not bulk) is what carries priority',
      (tester) async {
        await pump(tester, task: buildTask());

        final subtitles = tester
            .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
            .map((row) => row.subtitle)
            .toList();

        expect(subtitles, [
          'Adds a linked note for details and thoughts.',
          'Adds a list of checkable steps.',
          // Answers the fear low-vision and novice reviewers voiced verbatim:
          // tapping does NOT start recording — it opens the recorder sheet.
          'Opens the recorder without starting to record.',
          // Names the AI plainly: "agent" alone was a jargon wall for
          // non-technical readers.
          'Drafts steps and summaries with built-in AI.',
        ]);
      },
    );
  });
}
