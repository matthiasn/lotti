import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';

const _taskId = 'census';

AgentReportEntity _report({String? oneLiner, String? tldr}) =>
    AgentReportEntity(
      id: 'report-1',
      agentId: 'agent-1',
      scope: 'current',
      createdAt: testFixedDate,
      vectorClock: null,
      content: 'Full report',
      oneLiner: oneLiner,
      tldr: tldr,
    );

void main() {
  late MockJournalDb db;
  late MockAgentRepository agents;
  late StreamController<Set<String>> updates;
  late ProviderContainer container;

  setUp(() {
    db = MockJournalDb();
    agents = MockAgentRepository();
    updates = StreamController<Set<String>>.broadcast();
    addTearDown(updates.close);
    final notifications = MockUpdateNotifications();
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    container = ProviderContainer(
      overrides: [
        journalDbProvider.overrideWithValue(db),
        agentRepositoryProvider.overrideWithValue(agents),
        updateNotificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
  });

  void stubTask(JournalEntity? entity) =>
      when(() => db.journalEntityById(_taskId)).thenAnswer((_) async => entity);

  void stubReport(AgentReportEntity? report) => when(
    () => agents.getLatestTaskReportsForTaskIds([_taskId]),
  ).thenAnswer((_) async => {_taskId: ?report});

  Future<TaskPreview?> read() {
    final sub = container.listen(taskPreviewProvider(_taskId), (_, _) {});
    addTearDown(sub.close);
    return container.read(taskPreviewProvider(_taskId).future);
  }

  test("reads the task and its agent's one-liner and TL;DR, trimmed", () async {
    final task = TestTaskFactory.create(
      id: _taskId,
      title: 'Colony census export',
      plainText: '  Export the roll call.  ',
    );
    stubTask(task);
    stubReport(
      _report(oneLiner: ' Waiting on the relay ', tldr: '\n- 37 counted\n'),
    );

    final preview = await read();

    expect(preview?.task, task);
    expect(preview?.oneLiner, 'Waiting on the relay');
    expect(preview?.tldr, '- 37 counted');
    expect(preview?.notes, 'Export the roll call.');
  });

  test('a missing report, or blank fields in one, read as nothing', () async {
    stubTask(TestTaskFactory.create(id: _taskId));
    for (final report in [null, _report(oneLiner: '  ', tldr: '')]) {
      stubReport(report);
      container.invalidate(taskPreviewProvider(_taskId));

      final preview = await read();

      expect(preview?.oneLiner, isNull, reason: '$report');
      expect(preview?.tldr, isNull, reason: '$report');
      expect(preview?.notes, isNull, reason: 'the task has no notes');
    }
  });

  test(
    'a deleted task, or an entry that is not a task, has no preview',
    () async {
      stubReport(null);
      final deleted = TestTaskFactory.create(id: _taskId);
      for (final entity in <JournalEntity?>[
        deleted.copyWith(meta: deleted.meta.copyWith(deletedAt: testFixedDate)),
        JournalEntry(
          meta: TestMetadataFactory.create(id: _taskId),
          entryText: const EntryText(plainText: 'a note'),
        ),
        null,
      ]) {
        stubTask(entity);
        container.invalidate(taskPreviewProvider(_taskId));

        expect(await read(), isNull, reason: '$entity');
      }
      verifyNever(() => agents.getLatestTaskReportsForTaskIds(any()));
    },
  );

  test('reads again when a notification names the task', () async {
    stubTask(TestTaskFactory.create(id: _taskId, title: 'Before'));
    stubReport(null);
    await read();

    stubTask(TestTaskFactory.create(id: _taskId, title: 'After'));
    updates.add({_taskId});
    await pumpEventQueue();

    expect(
      (await container.read(
        taskPreviewProvider(_taskId).future,
      ))?.task.data.title,
      'After',
    );
  });

  test('is a value', () {
    final task = TestTaskFactory.create(id: _taskId);
    expect(
      TaskPreview(task: task, tldr: 'a'),
      TaskPreview(task: task, tldr: 'a'),
    );
    expect(
      TaskPreview(task: task, tldr: 'a').hashCode,
      TaskPreview(task: task, tldr: 'a').hashCode,
    );
    expect(TaskPreview(task: task, tldr: 'a'), isNot(TaskPreview(task: task)));
  });
}
