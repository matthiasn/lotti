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
      Map<String, dynamic>? targetBase,
      String? taskId,
    }) => f.dispatcher.dispatch(
      tool,
      ChangeEffect(key: key, base: base, targetBase: targetBase).addTo(args),
      taskId ?? f.task.meta.id,
    );

    Future<Task> storedTask([String? id]) async =>
        (await f.db.journalEntityById(id ?? f.task.meta.id))! as Task;

    /// The user edits the task on this device.
    Future<void> userEdit(TaskData Function(TaskData data) edit) async {
      final current = await storedTask();
      await buildJournalRepository().updateJournalEntity(
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

    Future<ChecklistItem> storedItem(String id) async =>
        (await f.db.journalEntityById(id))! as ChecklistItem;

    /// A new unchecked item in the task's checklist.
    Future<String> newItem(String title) async =>
        (await ChecklistRepository(
              journalRepository: buildJournalRepository(),
            ).addItemToChecklist(
              checklistId: f.checklistId,
              title: title,
              isChecked: false,
              categoryId: f.task.meta.categoryId,
            ))!
            .meta
            .id;

    /// The user edits the checklist item [id] on this device.
    Future<void> userEditsItem(
      String id,
      ChecklistItemData Function(ChecklistItemData data) edit,
    ) async {
      final written =
          await ChecklistRepository(
            journalRepository: buildJournalRepository(),
          ).updateChecklistItem(
            checklistItemId: id,
            change: edit,
            taskId: f.task.meta.id,
          );
      expect(written, isNotNull);
    }

    /// The `targetBase` an `update_checklist_item` proposal with [args]
    /// records, read from the item as it is now.
    Future<Map<String, dynamic>?> itemBase(Map<String, dynamic> args) async =>
        targetBaseFor(
          args,
          checklistItemFields((await storedItem(args['id'] as String)).data),
        );

    /// A time entry linked from the task, holding [text].
    Future<String> newTimeEntry(String id, String text) async {
      when(() => getIt<TimeService>().getCurrent()).thenReturn(null);
      await getIt<PersistenceLogic>().createDbEntity(
        testTextEntryNoGeo.copyWith(
          meta: testTextEntryNoGeo.meta.copyWith(
            id: id,
            categoryId: f.task.meta.categoryId,
            dateFrom: DateTime(2026, 3, 17, 9),
            dateTo: DateTime(2026, 3, 17, 10),
          ),
          entryText: EntryText(plainText: text),
        ),
        linkedId: f.task.meta.id,
      );
      return id;
    }

    Future<String?> entryText(String id) async =>
        ((await f.db.journalEntityById(id))! as JournalEntry)
            .entryText
            ?.plainText;

    /// The user rewrites the time entry [id] on this device.
    Future<void> userEditsEntry(String id, String text) async {
      expect(
        await getIt<PersistenceLogic>().updateJournalEntry(
          journalEntityId: id,
          entryText: EntryText(plainText: text),
        ),
        isTrue,
      );
    }

    Future<Map<String, dynamic>?> entryBase(Map<String, dynamic> args) async =>
        targetBaseFor(
          args,
          timeEntryFields(
            (await f.db.journalEntityById(args['entryId'] as String))!,
          ),
        );

    /// A global label definition.
    Future<String> newLabel(String id) async {
      await getIt<PersistenceLogic>().upsertEntityDefinition(
        testLabelDefinition1.copyWith(id: id, name: 'Label $id'),
      );
      return id;
    }

    Future<List<String>> taskLabels() async =>
        (await storedTask()).meta.labelIds ?? const [];

    /// The user takes [labelId] off the task in the label editor.
    Future<void> userRemovesLabel(String labelId) async {
      expect(
        await f.dispatcher.labelsRepository.updateLabels(
          journalEntityId: f.task.meta.id,
          removed: {labelId},
        ),
        isTrue,
      );
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
        expect(
          (await f.db.conflictsForEntry(ours.meta.id)).firstOrNull,
          isNotNull,
        );
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

      for (final itemDeleted in [false, true]) {
        test(
          'makes no new checklist when the item '
          '${itemDeleted ? 'was deleted' : 'already exists'}, though the '
          'user deleted its checklist since',
          () async {
            final taskId = await bareTask('bare-task');
            const args = {'title': 'Book the pen test'};
            await apply(
              TaskAgentToolNames.addChecklistItem,
              args,
              taskId: taskId,
            );
            final itemId = (await idsOf(
              'ChecklistItem',
              'Book the pen test',
            )).single;
            if (itemDeleted) {
              // Its tombstone counts as the item existing: the replay
              // neither brings it back nor gives it a new checklist.
              expect(
                await buildJournalRepository().deleteJournalEntity(itemId),
                isTrue,
              );
            }
            final derived = MetadataService.deterministicId(input);
            // The user deletes the checklist, which also takes it off the task.
            expect(
              await buildJournalRepository().deleteJournalEntity(derived),
              isTrue,
            );
            final withChecklist = await storedTask(taskId);
            await buildJournalRepository().updateJournalEntity(
              withChecklist.copyWith(
                data: withChecklist.data.copyWith(checklistIds: const []),
              ),
            );
            expect(await idsOf('Checklist', 'bare-task'), isEmpty);

            final late = await apply(
              TaskAgentToolNames.addChecklistItem,
              args,
              taskId: taskId,
            );

            expect(late.success, isTrue);
            expect(await idsOf('Checklist', 'bare-task'), isEmpty);
            expect(
              await f.db.journalEntityById(
                MetadataService.deterministicId('$input:1'),
              ),
              isNull,
            );
            expect(
              await idsOf('ChecklistItem', 'Book the pen test'),
              itemDeleted ? isEmpty : [itemId],
            );
          },
        );
      }

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
        await ChecklistRepository(
          journalRepository: buildJournalRepository(),
        ).updateChecklistItem(
          checklistItemId: f.checklistItemId,
          change: (stored) => stored.copyWith(isArchived: false),
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
      'set_task_title leaves the base title the user restored after the '
      'first application — the value alone cannot tell it from an untouched '
      'field (ADR 0098)',
      () async {
        final base = baseFor(TaskAgentToolNames.setTaskTitle, f.task);
        const args = {'title': 'Rotate the signing certificate'};

        await apply(TaskAgentToolNames.setTaskTitle, args, base: base);
        expect(
          (await storedTask()).data.appliedChangeEffects,
          {'set-1:0'},
        );
        await userEdit((data) => data.copyWith(title: f.task.data.title));

        final late = await apply(
          TaskAgentToolNames.setTaskTitle,
          args,
          base: base,
        );

        expect(late.success, isTrue);
        expect(late.output, contains('applied to the task already'));
        expect((await storedTask()).data.title, f.task.data.title);
      },
    );

    test(
      'a different change proposed against the restored base still applies',
      () async {
        final base = baseFor(TaskAgentToolNames.setTaskTitle, f.task);

        await apply(TaskAgentToolNames.setTaskTitle, {
          'title': 'Rotate the signing certificate',
        }, base: base);
        await userEdit((data) => data.copyWith(title: f.task.data.title));

        final next = await apply(
          TaskAgentToolNames.setTaskTitle,
          {'title': 'Renew the signing certificate'},
          key: 'set-2:0',
          base: base,
        );

        expect(next.success, isTrue, reason: next.output);
        final task = await storedTask();
        expect(task.data.title, 'Renew the signing certificate');
        expect(task.data.appliedChangeEffects, {'set-1:0', 'set-2:0'});
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

    group('tools that edit an entity other than the task (ADR 0097)', () {
      test(
        'update_checklist_item leaves a title the user edited after the '
        'first application',
        () async {
          final itemId = await newItem('Draft release notes');
          final args = {'id': itemId, 'title': 'Draft the release notes'};
          final base = await itemBase(args);

          await apply(
            TaskAgentToolNames.updateChecklistItem,
            args,
            targetBase: base,
          );
          expect((await storedItem(itemId)).data.title, args['title']);
          await userEditsItem(
            itemId,
            (data) => data.copyWith(title: 'Release notes by Friday'),
          );

          final late = await apply(
            TaskAgentToolNames.updateChecklistItem,
            args,
            targetBase: base,
          );

          expect(late.success, isTrue);
          expect(late.output, contains('Nothing applied'));
          expect(
            (await storedItem(itemId)).data.title,
            'Release notes by Friday',
          );
        },
      );

      test(
        'update_checklist_item leaves a check the user took back — though '
        'the item is unchecked again, as the proposal found it',
        () async {
          final itemId = await newItem('Book the venue');
          final args = {
            'id': itemId,
            'isChecked': true,
            // Enough to override a state the user set, as the late device's
            // dispatch would.
            'reason': 'The log of 2026-03-17 says the venue is booked',
          };
          final base = await itemBase(args);

          await apply(
            TaskAgentToolNames.updateChecklistItem,
            args,
            targetBase: base,
          );
          expect((await storedItem(itemId)).data.isChecked, isTrue);
          // The user unchecks it, as the checklist row does: a new stamp.
          await userEditsItem(
            itemId,
            (data) => data.copyWith(
              isChecked: false,
              checkedBy: ChangeSource.user,
              checkedAt: DateTime(2026, 3, 17, 16),
            ),
          );

          final late = await apply(
            TaskAgentToolNames.updateChecklistItem,
            args,
            targetBase: base,
          );

          expect(late.success, isTrue);
          expect(late.output, contains('Nothing applied'));
          expect((await storedItem(itemId)).data.isChecked, isFalse);
        },
      );

      test(
        'update_checklist_item leaves an item the user restored after the '
        'first application archived it',
        () async {
          final itemId = await newItem('Old venue shortlist');
          final args = {'id': itemId, 'isArchived': true};
          final base = await itemBase(args);

          await apply(
            TaskAgentToolNames.updateChecklistItem,
            args,
            targetBase: base,
          );
          expect((await storedItem(itemId)).data.isArchived, isTrue);
          await userEditsItem(
            itemId,
            (data) => data.copyWith(isArchived: false),
          );

          final late = await apply(
            TaskAgentToolNames.updateChecklistItem,
            args,
            targetBase: base,
          );

          expect(late.success, isTrue);
          expect(late.output, contains('Nothing applied'));
          expect((await storedItem(itemId)).data.isArchived, isFalse);
        },
      );

      test(
        'update_checklist_item without a recorded base applies as before',
        () async {
          final itemId = await newItem('Order the banners');
          await userEditsItem(
            itemId,
            (data) => data.copyWith(title: 'Order two banners'),
          );

          final result = await apply(TaskAgentToolNames.updateChecklistItem, {
            'id': itemId,
            'title': 'Order the banners',
          });

          expect(result.success, isTrue, reason: result.output);
          expect((await storedItem(itemId)).data.title, 'Order the banners');
        },
      );

      test(
        'update_time_entry leaves text the user wrote after the first '
        'application',
        () async {
          final entryId = await newTimeEntry('entry-1', 'Worked on it');
          final args = {'entryId': entryId, 'summary': 'Rotated the keys'};
          final base = await entryBase(args);

          final first = await apply(
            TaskAgentToolNames.updateTimeEntry,
            args,
            targetBase: base,
          );
          expect(first.success, isTrue, reason: first.output);
          expect(await entryText(entryId), 'Rotated the keys [generated]');
          await userEditsEntry(entryId, 'Rotated the keys, then the certs');

          final late = await apply(
            TaskAgentToolNames.updateTimeEntry,
            args,
            targetBase: base,
          );

          expect(late.success, isTrue);
          expect(late.output, contains('Nothing applied'));
          expect(await entryText(entryId), 'Rotated the keys, then the certs');
        },
      );

      test(
        'update_time_entry leaves a range the user moved after the first '
        'application',
        () async {
          final entryId = await newTimeEntry('entry-2', 'Pairing');
          final args = {
            'entryId': entryId,
            'startTime': '2026-03-17T09:30:00',
            'endTime': '2026-03-17T10:30:00',
          };
          final base = await entryBase(args);

          await apply(
            TaskAgentToolNames.updateTimeEntry,
            args,
            targetBase: base,
          );
          await getIt<PersistenceLogic>().updateJournalEntry(
            journalEntityId: entryId,
            dateFrom: DateTime(2026, 3, 17, 11),
            dateTo: DateTime(2026, 3, 17, 12),
          );

          final late = await apply(
            TaskAgentToolNames.updateTimeEntry,
            args,
            targetBase: base,
          );

          expect(late.success, isTrue);
          final entry = (await f.db.journalEntityById(entryId))!;
          expect(entry.meta.dateFrom, DateTime(2026, 3, 17, 11));
          expect(entry.meta.dateTo, DateTime(2026, 3, 17, 12));
        },
      );

      test(
        'assign_task_label does not bring back a label the user removed '
        'after the first application',
        () async {
          final labelId = await newLabel('label-release');
          const confidence = 'very_high';
          final args = {'id': labelId, 'confidence': confidence};

          await apply(TaskAgentToolNames.assignTaskLabel, args);
          expect(await taskLabels(), contains(labelId));
          await userRemovesLabel(labelId);
          expect(await taskLabels(), isNot(contains(labelId)));

          final late = await apply(TaskAgentToolNames.assignTaskLabel, args);

          // Not a failure: that would revert or retract the item.
          expect(late.success, isTrue);
          expect(await taskLabels(), isNot(contains(labelId)));
          expect(
            (await storedTask()).data.aiSuppressedLabelIds,
            contains(labelId),
          );
        },
      );
    });

    group("the project agent's tools (ADR 0097)", () {
      late ProjectRepository repository;
      late ProjectToolDispatcher projects;
      late ProjectEntry project;

      setUp(() async {
        repository = ProjectRepository(
          journalDb: f.db,
          entitiesCacheService: getIt<EntitiesCacheService>(),
          persistenceLogic: getIt<PersistenceLogic>(),
          updateNotifications: getIt<UpdateNotifications>(),
          vectorClockService: getIt<VectorClockService>(),
        );
        project = makeTestProject(
          id: 'project-1',
          categoryId: f.task.meta.categoryId,
        );
        await getIt<PersistenceLogic>().createDbEntity(project);
        projects = ProjectToolDispatcher(
          projectRepository: repository,
          persistenceLogic: getIt<PersistenceLogic>(),
          entitiesCacheService: getIt<EntitiesCacheService>(),
          journalDb: f.db,
        );
      });

      Future<ToolExecutionResult> applyToProject(
        String tool,
        Map<String, dynamic> args, {
        String key = 'project-set:0',
        Map<String, dynamic>? targetBase,
      }) => projects.dispatch(
        tool,
        ChangeEffect(key: key, targetBase: targetBase).addTo(args),
        project.meta.id,
      );

      Future<ProjectStatus> projectStatus() async =>
          (await repository.getProjectById(project.meta.id))!.data.status;

      /// The user sets the project's status on this device.
      Future<void> userSetsStatus(ProjectStatus status) async {
        final current = (await repository.getProjectById(project.meta.id))!;
        expect(
          await repository.updateProject(
            current.copyWith(data: current.data.copyWith(status: status)),
          ),
          isTrue,
        );
      }

      test('create_task creates one task, in the project', () async {
        const args = {'title': 'Write the migration guide'};

        final first = await applyToProject(
          ProjectAgentToolNames.createTask,
          args,
        );
        final second = await applyToProject(
          ProjectAgentToolNames.createTask,
          args,
        );

        expect(first.success, isTrue, reason: first.output);
        expect(second.success, isTrue, reason: second.output);
        expect(second.mutatedEntityId, first.mutatedEntityId);
        expect(await idsOf('Task', 'Write the migration guide'), [
          first.mutatedEntityId,
        ]);
        expect(
          (await repository.getProjectForTask(first.mutatedEntityId!))?.meta.id,
          project.meta.id,
        );
      });

      test('create_task does not bring back a task the user deleted', () async {
        const args = {'title': 'Retire the legacy importer'};
        final first = await applyToProject(
          ProjectAgentToolNames.createTask,
          args,
        );
        expect(
          await buildJournalRepository().deleteJournalEntity(
            first.mutatedEntityId!,
          ),
          isTrue,
        );

        final late = await applyToProject(
          ProjectAgentToolNames.createTask,
          args,
        );

        expect(late.success, isTrue);
        expect(await idsOf('Task', 'Retire the legacy importer'), isEmpty);
      });

      test(
        'create_task confirmed again after an Undo creates the task anew, '
        'under the key the Undo gave the item',
        () async {
          const args = {'title': 'Draft the rollout plan'};
          const item = ChangeItem(
            toolName: ProjectAgentToolNames.createTask,
            args: args,
            humanSummary: 'Create task: Draft the rollout plan',
            revision: 1,
          );
          final first = await applyToProject(
            ProjectAgentToolNames.createTask,
            args,
            key: item.effectKeyIn('project-set', 0),
          );
          // The Undo removes the task and reopens the item under a new key.
          expect(
            await buildJournalRepository().deleteJournalEntity(
              first.mutatedEntityId!,
            ),
            isTrue,
          );
          final reopened = item.undoneIn('project-set', 0);

          final again = await applyToProject(
            ProjectAgentToolNames.createTask,
            args,
            key: reopened.effectKeyIn('project-set', 0),
          );

          expect(again.success, isTrue, reason: again.output);
          expect(again.mutatedEntityId, isNot(first.mutatedEntityId));
          expect(await idsOf('Task', 'Draft the rollout plan'), [
            again.mutatedEntityId,
          ]);
        },
      );

      for (final restoresBase in [false, true]) {
        test(
          'update_project_status leaves a status the user set after the '
          'first application${restoresBase ? ' — even the one the proposal '
                    'found, set again' : ''}',
          () async {
            const args = {'status': 'active'};
            final base = targetBaseFor(
              args,
              projectFields(await projectStatus()),
            );

            await applyToProject(
              ProjectAgentToolNames.updateProjectStatus,
              args,
              targetBase: base,
            );
            expect(await projectStatus(), isA<ProjectActive>());
            final userStatus = restoresBase
                ? ProjectStatus.open(
                    id: 'user-status',
                    createdAt: DateTime(2026, 3, 17, 16),
                    utcOffset: 0,
                  )
                : ProjectStatus.monitoring(
                    id: 'user-status',
                    createdAt: DateTime(2026, 3, 17, 16),
                    utcOffset: 0,
                  );
            await userSetsStatus(userStatus);

            final late = await applyToProject(
              ProjectAgentToolNames.updateProjectStatus,
              args,
              targetBase: base,
            );

            expect(late.success, isTrue);
            expect(late.output, contains('Nothing applied'));
            expect(await projectStatus(), userStatus);
          },
        );
      }
    });

    // An application that stopped after its first write — the app died
    // before the link, the project or the agent — is finished by the dispatch
    // run again at the next start, or by the other device's, and a further
    // run writes nothing more (`specs/tla/ChangeDispatchRecovery.tla`,
    // TailOnRerun).
    group('a dispatch run again after the app died mid-way', () {
      late ProjectRepository repository;
      late ProjectEntry project;

      setUp(() async {
        repository = ProjectRepository(
          journalDb: f.db,
          entitiesCacheService: getIt<EntitiesCacheService>(),
          persistenceLogic: getIt<PersistenceLogic>(),
          updateNotifications: getIt<UpdateNotifications>(),
          vectorClockService: getIt<VectorClockService>(),
        );
        project = makeTestProject(
          id: 'project-1',
          categoryId: f.task.meta.categoryId,
        );
        await getIt<PersistenceLogic>().createDbEntity(project);
      });

      /// The task an earlier application of the item [key] got as far as
      /// creating, under the id that item derives.
      Future<String> onlyTaskOf(String key, String title) async =>
          (await getIt<PersistenceLogic>().createTaskEntry(
            data: f.task.data.copyWith(title: title, checklistIds: null),
            entryText: const EntryText(plainText: ''),
            categoryId: f.task.meta.categoryId,
            uuidV5Input: ChangeEffect(key: key).entityInput('task'),
          ))!.meta.id;

      /// Live links from [fromId] to [toId].
      Future<int> liveLinks(String fromId, String toId) async =>
          (await f.db.linksBetween(
            fromId,
            toId,
          )).where((link) => link.deletedAt == null).length;

      test('create_follow_up_task links the task it finds and files it in '
          "the source's project", () async {
        expect(
          await repository.linkTaskToProject(
            projectId: project.meta.id,
            taskId: f.task.meta.id,
          ),
          isTrue,
        );
        final dispatcher = TaskToolDispatcher(
          journalDb: f.db,
          journalRepository: buildJournalRepository(),
          checklistRepository: ChecklistRepository(
            journalRepository: buildJournalRepository(),
          ),
          labelsRepository: f.dispatcher.labelsRepository,
          persistenceLogic: getIt<PersistenceLogic>(),
          timeService: getIt<TimeService>(),
          projectRepository: repository,
        );
        final taskId = await onlyTaskOf('set-1:0', 'Renew the certificate');
        Future<ToolExecutionResult> rerun() => dispatcher.dispatch(
          TaskAgentToolNames.createFollowUpTask,
          const ChangeEffect(
            key: 'set-1:0',
          ).addTo({'title': 'Renew the certificate'}),
          f.task.meta.id,
        );

        final resumed = await rerun();

        expect(resumed.success, isTrue, reason: resumed.output);
        expect(resumed.mutatedEntityId, taskId);
        expect(await liveLinks(f.task.meta.id, taskId), 1);
        expect(
          (await repository.getProjectForTask(taskId))?.meta.id,
          project.meta.id,
        );

        // The user files the task elsewhere; a further run leaves it there.
        final elsewhere = makeTestProject(
          id: 'project-2',
          categoryId: f.task.meta.categoryId,
        );
        await getIt<PersistenceLogic>().createDbEntity(elsewhere);
        expect(
          await repository.linkTaskToProject(
            projectId: elsewhere.meta.id,
            taskId: taskId,
          ),
          isTrue,
        );

        final again = await rerun();

        expect(again.success, isTrue, reason: again.output);
        expect(await liveLinks(f.task.meta.id, taskId), 1);
        expect(
          (await repository.getProjectForTask(taskId))?.meta.id,
          elsewhere.meta.id,
        );
        expect(await idsOf('Task', 'Renew the certificate'), [taskId]);
      });

      test('create_task files the task it finds in the project', () async {
        final projects = ProjectToolDispatcher(
          projectRepository: repository,
          persistenceLogic: getIt<PersistenceLogic>(),
          entitiesCacheService: getIt<EntitiesCacheService>(),
          journalDb: f.db,
        );
        final taskId = await onlyTaskOf('project-set:0', 'Write the guide');

        final resumed = await projects.dispatch(
          ProjectAgentToolNames.createTask,
          const ChangeEffect(
            key: 'project-set:0',
          ).addTo({'title': 'Write the guide'}),
          project.meta.id,
        );

        expect(resumed.success, isTrue, reason: resumed.output);
        expect(resumed.mutatedEntityId, taskId);
        expect(
          (await repository.getProjectForTask(taskId))?.meta.id,
          project.meta.id,
        );
        expect(await idsOf('Task', 'Write the guide'), [taskId]);
      });

      test('create_time_entry links the entry it finds to the task', () async {
        const args = {
          'startTime': '2026-03-17T14:00:00',
          'endTime': '2026-03-17T15:00:00',
          'summary': 'Paired on the rotation script',
        };
        when(() => getIt<TimeService>().getCurrent()).thenReturn(null);
        // The earlier application wrote the entry, not its link.
        const effect = ChangeEffect(key: 'set-1:0');
        final entry = JournalEntity.journalEntry(
          entryText: const EntryText(plainText: 'Paired [generated]'),
          meta: await getIt<PersistenceLogic>().createMetadata(
            dateFrom: DateTime(2026, 3, 17, 14),
            dateTo: DateTime(2026, 3, 17, 15),
            categoryId: f.task.meta.categoryId,
            uuidV5Input: effect.entityInput('time-entry'),
          ),
        );
        expect(await getIt<PersistenceLogic>().createDbEntity(entry), isTrue);
        expect(await liveLinks(f.task.meta.id, entry.meta.id), 0);

        final resumed = await apply(TaskAgentToolNames.createTimeEntry, args);

        expect(resumed.success, isTrue, reason: resumed.output);
        expect(resumed.mutatedEntityId, entry.meta.id);
        expect(await liveLinks(f.task.meta.id, entry.meta.id), 1);
        await apply(TaskAgentToolNames.createTimeEntry, args);
        expect(await liveLinks(f.task.meta.id, entry.meta.id), 1);
      });
    });

    // Every tool twice or more, on a replica that holds the other device's
    // writes, with the user editing in between — restoring a field to the
    // proposal's base included: the journal must equal applying each item
    // once, and no edit may be overwritten (ADR 0075, ADR 0098).
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
        // The entities the other three edit, new for this run.
        final itemId = await newItem('Row base $r');
        final itemArgs = {'id': itemId, 'title': 'Row agent $r'};
        final itemTargetBase = await itemBase(itemArgs);
        final entryId = await newTimeEntry('entry-run-$r', 'Log base $r');
        final entryArgs = {'entryId': entryId, 'summary': 'Log agent $r'};
        final entryTargetBase = await entryBase(entryArgs);
        final labelId = await newLabel('label-run-$r');
        final creates = <int, (String, String)>{
          0: ('Task', 'Follow-up $r'),
          1: ('JournalEntry', 'Session $r'),
          2: ('ChecklistItem', 'Item $r'),
        };
        final applied = List.filled(8, 0);
        const baseEstimate = Duration(minutes: 30);
        final baseTitle = 'Base title $r';
        // The fields as applying each change once must leave them: a change
        // takes effect over its base value, once — never again after it
        // landed, whatever the user wrote since.
        var title = baseTitle;
        var estimate = baseEstimate;
        var titleLanded = false;
        var estimateLanded = false;
        String? userItemTitle;
        String? userEntryText;
        var userRemovedLabel = false;

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
            4 => await apply(
              TaskAgentToolNames.updateTaskEstimate,
              {'minutes': 90},
              key: key,
              base: baseFor(TaskAgentToolNames.updateTaskEstimate, baseTask),
            ),
            5 => await apply(
              TaskAgentToolNames.updateChecklistItem,
              itemArgs,
              key: key,
              targetBase: itemTargetBase,
            ),
            6 => await apply(
              TaskAgentToolNames.updateTimeEntry,
              entryArgs,
              key: key,
              targetBase: entryTargetBase,
            ),
            _ => await apply(TaskAgentToolNames.assignTaskLabel, {
              'id': labelId,
              'confidence': 'very_high',
            }, key: key),
          };
          expect(result.success, isTrue, reason: '$trace: ${result.output}');
          applied[item]++;
          if (item == 3 && !titleLanded && title == baseTitle) {
            title = 'Agent title $r';
            titleLanded = true;
          }
          if (item == 4 && !estimateLanded && estimate == baseEstimate) {
            estimate = const Duration(minutes: 90);
            estimateLanded = true;
          }
        }

        for (final (step, op) in trace.indexed) {
          switch (op) {
            case < 8:
              await applyItem(op);
            case 8:
              final edited = title = 'User title $r.$step';
              await userEdit((data) => data.copyWith(title: edited));
            case 9:
              final edited = estimate = Duration(minutes: 7 + step);
              await userEdit((data) => data.copyWith(estimate: edited));
            case 10:
              title = baseTitle;
              await userEdit((data) => data.copyWith(title: baseTitle));
            case 11:
              estimate = baseEstimate;
              await userEdit((data) => data.copyWith(estimate: baseEstimate));
            case 12:
              final edited = userItemTitle = 'Row user $r.$step';
              await userEditsItem(
                itemId,
                (data) => data.copyWith(title: edited),
              );
            case 13:
              final text = userEntryText = 'Log user $r.$step';
              await userEditsEntry(entryId, text);
            default:
              // Only a label on the task can be taken off it.
              if ((await taskLabels()).contains(labelId)) {
                await userRemovesLabel(labelId);
                userRemovedLabel = true;
              }
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
          expect(task.data.title, title, reason: 'NoClobber title: $trace');
          expect(
            task.data.estimate,
            estimate,
            reason: 'NoClobber estimate: $trace',
          );
          expect(
            (await storedItem(itemId)).data.title,
            userItemTitle ?? (applied[5] > 0 ? 'Row agent $r' : 'Row base $r'),
            reason: 'NoClobber checklist item: $trace',
          );
          expect(
            await entryText(entryId),
            userEntryText ??
                (applied[6] > 0 ? 'Log agent $r [generated]' : 'Log base $r'),
            reason: 'NoClobber time entry: $trace',
          );
          expect(
            (await taskLabels()).contains(labelId),
            applied[7] > 0 && !userRemovedLabel,
            reason: 'NoResurrect label: $trace',
          );
        }
      },
      tags: 'glados',
    );

    // The field's ABA on its own (ChangeSetLifecycleRaceRestore): one title
    // change applied any number of times while the user edits the title and
    // puts it back to the proposal's base. The change lands at most once,
    // and only over the base; nothing the user wrote after it landed is
    // overwritten (ADR 0098).
    var abaRun = 0;
    glados.Glados(
      glados.any.fieldAbaTrace,
      glados.ExploreConfig(numRuns: 25),
    ).test(
      'generated applications of one field change never overwrite the base '
      'the user restored after it landed',
      (trace) async {
        final r = abaRun++;
        final baseTitle = 'ABA base $r';
        await userEdit((data) => data.copyWith(title: baseTitle));
        final base = baseFor(
          TaskAgentToolNames.setTaskTitle,
          await storedTask(),
        );
        var title = baseTitle;
        var landed = false;

        for (final (step, op) in trace.indexed) {
          switch (op) {
            case 0:
              final result = await apply(
                TaskAgentToolNames.setTaskTitle,
                {'title': 'ABA agent $r'},
                key: 'aba-$r:0',
                base: base,
              );
              expect(
                result.success,
                isTrue,
                reason: '$trace: ${result.output}',
              );
              if (!landed && title == baseTitle) {
                title = 'ABA agent $r';
                landed = true;
              }
            case 1:
              final edited = title = 'ABA user $r.$step';
              await userEdit((data) => data.copyWith(title: edited));
            default:
              title = baseTitle;
              await userEdit((data) => data.copyWith(title: baseTitle));
          }
          expect(
            (await storedTask()).data.title,
            title,
            reason: 'NoClobber: $trace',
          );
        }
      },
      tags: 'glados',
    );
  });
}

extension _AnyIdempotencyTrace on glados.Any {
  /// 0 applies one confirmed title change, 1 is the user editing the title
  /// and 2 the user putting it back to the value the change was proposed
  /// against.
  glados.Generator<List<int>> get fieldAbaTrace => glados.ListAnys(
    this,
  ).listWithLengthInRange(1, 8, glados.IntAnys(this).intInRange(0, 3));

  /// Operations 0–7 apply one of eight confirmed items — a follow-up task, a
  /// time entry, a checklist item, a title, an estimate, a checklist item's
  /// new title, a time entry's new text and a label; 8 and 9 are the user
  /// editing the title and the estimate, 10 and 11 the user putting either
  /// back to the value its proposal was made against, 12 and 13 the user
  /// editing the checklist item's title and the time entry's text, and 14
  /// the user taking the label off the task.
  glados.Generator<List<int>> get idempotencyTrace => glados.ListAnys(
    this,
  ).listWithLengthInRange(1, 14, glados.IntAnys(this).intInRange(0, 15));
}
