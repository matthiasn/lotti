part of 'task_tool_dispatcher_db_test.dart';

// One confirmed change item applied twice — what two devices do when both
// confirm it before they sync — changes the journal once
// (docs/adr/0075-idempotent-change-set-tools.md, specs/tla/ChangeSetLifecycle.tla:
// `NoDuplicateEffects`, `NoClobber`). Both devices run this code; a replica
// that already holds the first device's writes is this database after the
// first dispatch, so a second dispatch here is the late device's.

typedef _Db = ({
  JournalDb db,
  TaskToolDispatcher dispatcher,
  Task task,
  String checklistId,
  String checklistItemId,
});

void _registerIdempotency(_Db Function() fixture) {
  group('one confirmed item applied twice (ADR 0075)', () {
    late _Db f;
    setUp(() => f = fixture());

    /// Live journal rows of [type] whose payload mentions [marker].
    Future<List<String>> idsOf(String type, String marker) async => [
      for (final row
          in await f.db
              .customSelect(
                'SELECT id FROM journal '
                'WHERE type = ? AND deleted = 0 AND serialized LIKE ?',
                variables: [
                  Variable.withString(type),
                  Variable.withString('%$marker%'),
                ],
              )
              .get())
        row.read<String>('id'),
    ];

    Future<ToolExecutionResult> apply(
      String tool,
      Map<String, dynamic> args, {
      String key = 'set-1:0',
      Map<String, dynamic>? base,
      String? taskId,
    }) => f.dispatcher.dispatch(
      tool,
      ChangeEffect(key: key, base: base).addTo(args),
      taskId ?? f.task.meta.id,
    );

    Future<Task> storedTask([String? id]) async =>
        (await f.db.journalEntityById(id ?? f.task.meta.id))! as Task;

    /// The user edits the task on this device.
    Future<void> userEdit(TaskData Function(TaskData data) edit) async {
      final current = await storedTask();
      await JournalRepository().updateJournalEntity(
        current.copyWith(data: edit(current.data)),
      );
    }

    Map<String, dynamic>? baseFor(String tool, Task task) =>
        ChangeProposalFilter.proposalBase(
          tool,
          ChangeProposalFilter.taskMetadataOf(task),
        );

    Future<String> bareTask(String id) async {
      await getIt<PersistenceLogic>().createDbEntity(
        f.task.copyWith(
          meta: f.task.meta.copyWith(id: id),
          data: f.task.data.copyWith(checklistIds: null, title: 'Bare $id'),
        ),
      );
      return id;
    }

    test('create_follow_up_task creates one task', () async {
      const args = {'title': 'Renew the staging certificate'};

      final first = await apply(TaskAgentToolNames.createFollowUpTask, args);
      final second = await apply(TaskAgentToolNames.createFollowUpTask, args);

      expect(first.success, isTrue, reason: first.output);
      expect(second.success, isTrue, reason: second.output);
      // The migrations of the late device resolve to the same task.
      expect(second.mutatedEntityId, first.mutatedEntityId);
      expect(await idsOf('Task', 'Renew the staging certificate'), [
        first.mutatedEntityId,
      ]);
    });

    test(
      'two devices creating the task before they sync hold one id — and '
      "the journal parks the other device's version as a conflict",
      () async {
        final created = await apply(
          TaskAgentToolNames.createFollowUpTask,
          const {'title': 'Audit the key rotation'},
        );
        final ours = await storedTask(created.mutatedEntityId);
        // The other device created the same task, a moment later, under its
        // own clock.
        final theirs = ours.copyWith(
          meta: ours.meta.copyWith(
            createdAt: ours.meta.createdAt.add(const Duration(seconds: 1)),
            vectorClock: const VectorClock({'other-device': 1}),
          ),
        );

        final received = await f.db.updateJournalEntity(theirs);

        expect(received.applied, isFalse);
        expect(received.skipReason, JournalUpdateSkipReason.conflict);
        expect(await f.db.conflictById(ours.meta.id), isNotNull);
        expect(await idsOf('Task', 'Audit the key rotation'), [ours.meta.id]);
      },
    );

    test('create_time_entry records one session', () async {
      const args = {
        'startTime': '2026-03-17T14:00:00',
        'endTime': '2026-03-17T15:00:00',
        'summary': 'Paired on the rotation script',
      };

      final first = await apply(TaskAgentToolNames.createTimeEntry, args);
      final second = await apply(TaskAgentToolNames.createTimeEntry, args);

      expect(first.success, isTrue, reason: first.output);
      expect(second.success, isTrue, reason: second.output);
      expect(second.mutatedEntityId, first.mutatedEntityId);
      expect(await idsOf('JournalEntry', 'Paired on the rotation script'), [
        first.mutatedEntityId,
      ]);
    });

    test('add_checklist_item adds one item to the checklist', () async {
      const args = {'title': 'Revoke the old certificate'};

      await apply(TaskAgentToolNames.addChecklistItem, args);
      final second = await apply(TaskAgentToolNames.addChecklistItem, args);

      expect(second.success, isTrue, reason: second.output);
      final items = await idsOf('ChecklistItem', 'Revoke the old certificate');
      expect(items, hasLength(1));
      final checklist = (await f.db.journalEntityById(f.checklistId))!;
      expect(
        (checklist as Checklist).data.linkedChecklistItems.where(
          (id) => id == items.single,
        ),
        hasLength(1),
      );
    });

    test(
      'add_checklist_item gives a task without a checklist one checklist',
      () async {
        final taskId = await bareTask('bare-task');
        const args = {'title': 'Book the pen test'};

        await apply(
          TaskAgentToolNames.addChecklistItem,
          args,
          taskId: taskId,
        );
        await apply(
          TaskAgentToolNames.addChecklistItem,
          args,
          taskId: taskId,
        );

        expect((await storedTask(taskId)).data.checklistIds, hasLength(1));
        expect(await idsOf('ChecklistItem', 'Book the pen test'), hasLength(1));
      },
    );

    test(
      'replaying a deleted batch does not recreate an empty checklist',
      () async {
        final taskId = await bareTask('deleted-batch-task');
        const args = {'title': 'Retired checklist entry'};
        final first = await apply(
          TaskAgentToolNames.addChecklistItem,
          args,
          taskId: taskId,
        );
        expect(first.success, isTrue, reason: first.output);
        final itemId = (await idsOf(
          'ChecklistItem',
          'Retired checklist entry',
        )).single;
        final checklistId = (await storedTask(
          taskId,
        )).data.checklistIds!.single;
        final journal = JournalRepository();
        expect(await journal.deleteJournalEntity(itemId), isTrue);
        expect(await journal.deleteJournalEntity(checklistId), isTrue);
        final current = await storedTask(taskId);
        expect(
          await journal.updateJournalEntity(
            current.copyWith(
              data: current.data.copyWith(checklistIds: const []),
            ),
          ),
          isTrue,
        );

        final replay = await apply(
          TaskAgentToolNames.addChecklistItem,
          args,
          taskId: taskId,
        );

        expect(replay.success, isTrue, reason: replay.output);
        expect((await storedTask(taskId)).data.checklistIds, isEmpty);
        expect(await idsOf('Checklist', taskId), isEmpty);
        expect(
          await idsOf('ChecklistItem', 'Retired checklist entry'),
          isEmpty,
        );
      },
    );

    group('the derived checklist of a task without one', () {
      const key = 'set-1:0';
      final input = const ChangeEffect(key: key).entityInput('checklist');

      /// A checklist under [id], as sync delivers the other device's —
      /// without the task update that lists it.
      Future<void> deliverChecklist(
        String id,
        String taskId, {
        bool? deleted,
      }) => getIt<PersistenceLogic>().createDbEntity(
        Checklist(
          meta: f.task.meta.copyWith(
            id: id,
            deletedAt: deleted == true ? DateTime(2026, 3, 17) : null,
          ),
          data: ChecklistData(
            title: 'Todos',
            linkedChecklistItems: const [],
            linkedTasks: [taskId],
          ),
        ),
      );

      test(
        "reuses the other device's checklist that arrived before the task "
        'update listing it, and lists it',
        () async {
          final taskId = await bareTask('bare-task');
          final derived = MetadataService.deterministicId(input);
          await deliverChecklist(derived, taskId);

          final result = await apply(
            TaskAgentToolNames.addChecklistItem,
            const {'title': 'Book the pen test'},
            taskId: taskId,
          );

          expect(result.success, isTrue, reason: result.output);
          expect((await storedTask(taskId)).data.checklistIds, [derived]);
          final checklist = (await f.db.journalEntityById(derived))!;
          expect(
            (checklist as Checklist).data.linkedChecklistItems,
            hasLength(1),
          );
        },
      );

      test(
        'moves on to the next derived id past a checklist the user deleted, '
        'the same one on every device',
        () async {
          final taskId = await bareTask('bare-task');
          await deliverChecklist(
            MetadataService.deterministicId(input),
            taskId,
            deleted: true,
          );

          await apply(
            TaskAgentToolNames.addChecklistItem,
            const {'title': 'Book the pen test'},
            taskId: taskId,
          );

          expect((await storedTask(taskId)).data.checklistIds, [
            MetadataService.deterministicId('$input:1'),
          ]);
        },
      );
    });

    test(
      'migrate_checklist_item copies once when the other device copied '
      'before its archive of the source arrived',
      () async {
        final target = await bareTask('target-task');
        final args = {'id': f.checklistItemId, 'targetTaskId': target};

        final first = await apply(
          TaskAgentToolNames.migrateChecklistItem,
          args,
        );
        expect(first.success, isTrue, reason: first.output);
        // Sync delivers the copy before the source's archive: the source
        // reads unarchived on the late device.
        final source =
            (await f.db.journalEntityById(f.checklistItemId))! as ChecklistItem;
        await ChecklistRepository().updateChecklistItem(
          checklistItemId: f.checklistItemId,
          data: source.data.copyWith(isArchived: false),
          taskId: f.task.meta.id,
        );

        final second = await apply(
          TaskAgentToolNames.migrateChecklistItem,
          args,
        );

        expect(second.success, isTrue, reason: second.output);
        // The source and one copy.
        expect(
          await idsOf('ChecklistItem', 'Interview five customers'),
          hasLength(2),
        );
        expect((await storedTask(target)).data.checklistIds, hasLength(1));
        final archived =
            (await f.db.journalEntityById(f.checklistItemId))! as ChecklistItem;
        expect(archived.data.isArchived, isTrue);
      },
    );

    test(
      'set_task_title leaves an edit made after the first application',
      () async {
        final base = baseFor(TaskAgentToolNames.setTaskTitle, f.task);
        const args = {'title': 'Rotate the signing certificate'};

        await apply(TaskAgentToolNames.setTaskTitle, args, base: base);
        expect(
          (await storedTask()).data.title,
          'Rotate the signing certificate',
        );
        await userEdit((data) => data.copyWith(title: 'Rotate before Friday'));

        final late = await apply(
          TaskAgentToolNames.setTaskTitle,
          args,
          base: base,
        );

        // Not a failure: that would revert or retract the item.
        expect(late.success, isTrue);
        expect(late.output, contains('Nothing applied'));
        expect((await storedTask()).data.title, 'Rotate before Friday');
      },
    );

    test(
      'set_task_status leaves a status the user chose after the first '
      'application',
      () async {
        final base = baseFor(TaskAgentToolNames.setTaskStatus, f.task);
        const args = {'status': 'IN PROGRESS'};

        await apply(TaskAgentToolNames.setTaskStatus, args, base: base);
        expect((await storedTask()).data.status, isA<TaskInProgress>());
        await userEdit(
          (data) => data.copyWith(
            status: TaskStatus.groomed(
              id: 'user-status',
              createdAt: DateTime(2026, 3, 17, 16),
              utcOffset: 0,
            ),
          ),
        );

        final late = await apply(
          TaskAgentToolNames.setTaskStatus,
          args,
          base: base,
        );

        expect(late.success, isTrue);
        expect((await storedTask()).data.status, isA<TaskGroomed>());
      },
    );

    // Every tool twice or more, on a replica that holds the other device's
    // writes, with the user editing in between: the journal must equal
    // applying each item once, and no edit may be overwritten.
    var run = 0;
    glados.Glados(
      glados.any.idempotencyTrace,
      glados.ExploreConfig(numRuns: 25),
    ).test(
      'generated repeated applications with interleaved edits equal one '
      'application each',
      (trace) async {
        final r = run++;
        // A fresh base for this run: the same task carries every run.
        await userEdit(
          (data) => data.copyWith(
            title: 'Base title $r',
            estimate: const Duration(minutes: 30),
          ),
        );
        final baseTask = await storedTask();
        final creates = <int, (String, String)>{
          0: ('Task', 'Follow-up $r'),
          1: ('JournalEntry', 'Session $r'),
          2: ('ChecklistItem', 'Item $r'),
        };
        final applied = List.filled(5, 0);
        String? userTitle;
        Duration? userEstimate;

        Future<void> applyItem(int item) async {
          final key = 'run-$r:$item';
          final result = switch (item) {
            0 => await apply(
              TaskAgentToolNames.createFollowUpTask,
              {'title': 'Follow-up $r'},
              key: key,
            ),
            1 => await apply(TaskAgentToolNames.createTimeEntry, {
              'startTime': '2026-03-17T09:00:00',
              'endTime': '2026-03-17T10:00:00',
              'summary': 'Session $r',
            }, key: key),
            2 => await apply(TaskAgentToolNames.addChecklistItem, {
              'title': 'Item $r',
            }, key: key),
            3 => await apply(
              TaskAgentToolNames.setTaskTitle,
              {'title': 'Agent title $r'},
              key: key,
              base: baseFor(TaskAgentToolNames.setTaskTitle, baseTask),
            ),
            _ => await apply(
              TaskAgentToolNames.updateTaskEstimate,
              {'minutes': 90},
              key: key,
              base: baseFor(TaskAgentToolNames.updateTaskEstimate, baseTask),
            ),
          };
          expect(result.success, isTrue, reason: '$trace: ${result.output}');
          applied[item]++;
        }

        for (final (step, op) in trace.indexed) {
          switch (op) {
            case < 5:
              await applyItem(op);
            case 5:
              final title = userTitle = 'User title $r.$step';
              await userEdit((data) => data.copyWith(title: title));
            default:
              userEstimate = Duration(minutes: 7 + step);
              await userEdit(
                (data) => data.copyWith(estimate: userEstimate),
              );
          }

          for (final MapEntry(key: item, value: (type, marker))
              in creates.entries) {
            expect(
              await idsOf(type, marker),
              hasLength(applied[item] > 0 ? 1 : 0),
              reason: 'NoDuplicateEffects $item: $trace',
            );
          }
          final task = await storedTask();
          expect(
            task.data.title,
            userTitle ?? (applied[3] > 0 ? 'Agent title $r' : 'Base title $r'),
            reason: 'NoClobber title: $trace',
          );
          expect(
            task.data.estimate,
            userEstimate ?? Duration(minutes: applied[4] > 0 ? 90 : 30),
            reason: 'NoClobber estimate: $trace',
          );
        }
      },
      tags: 'glados',
    );
  });
}

extension _AnyIdempotencyTrace on glados.Any {
  /// Operations 0–4 apply one of five confirmed items — a follow-up task, a
  /// time entry, a checklist item, a title and an estimate — and 5 and 6 are
  /// the user editing the title and the estimate.
  glados.Generator<List<int>> get idempotencyTrace => glados.ListAnys(
    this,
  ).listWithLengthInRange(1, 10, glados.IntAnys(this).intInRange(0, 7));
}
