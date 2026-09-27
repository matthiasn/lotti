import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/agents/workflow/task_wake_inputs.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

VectorClock _vc(int counter) => VectorClock({'host-a': counter});

Metadata _meta(String id, {required VectorClock vc}) =>
    TestMetadataFactory.create(id: id).copyWith(vectorClock: vc);

EntryLink _link(
  String id,
  String fromId,
  String toId,
  int counter, {
  DateTime? deletedAt,
}) => EntryLink.basic(
  id: id,
  fromId: fromId,
  toId: toId,
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  vectorClock: _vc(counter),
  deletedAt: deletedAt,
);

/// One device's view of a task's neighbourhood, served through a
/// [MockJournalDb] the way `taskWakeInputs` queries it.
class _TaskWorld {
  final JournalEntity task = TestTaskFactory.create(
    id: 'task-1',
    checklistIds: ['checklist-1'],
  ).copyWith(meta: _meta('task-1', vc: _vc(1)));
  final entry = JournalEntity.journalEntry(
    meta: _meta('entry-1', vc: _vc(2)),
  );
  final JournalEntity image = TestImageFactory.create(
    id: 'image-1',
  ).copyWith(meta: _meta('image-1', vc: _vc(3)));
  final JournalEntity project = TestProjectFactory.create(
    id: 'project-1',
  ).copyWith(meta: _meta('project-1', vc: _vc(4)));
  final checklist = JournalEntity.checklist(
    meta: _meta('checklist-1', vc: _vc(5)),
    data: const ChecklistData(
      title: 'Steps',
      linkedChecklistItems: ['item-1'],
      linkedTasks: ['task-1'],
    ),
  );
  final item = JournalEntity.checklistItem(
    meta: _meta('item-1', vc: _vc(6)),
    data: TestChecklistItemFactory.create(id: 'item-1'),
  );
  final JournalEntity analysis = TestAiResponseFactory.create(
    id: 'analysis-1',
  ).copyWith(meta: _meta('analysis-1', vc: _vc(7)));
  final JournalEntity linkedTask = TestTaskFactory.create(
    id: 'linked-task-1',
  ).copyWith(meta: _meta('linked-task-1', vc: _vc(8)));
  final childEntry = JournalEntity.journalEntry(
    meta: _meta('child-entry-1', vc: _vc(9)),
  );

  /// An entry deleted, and unlinked, since it was written.
  final deletedEntry = JournalEntity.journalEntry(
    meta: _meta(
      'deleted-entry-1',
      vc: _vc(22),
    ).copyWith(deletedAt: DateTime(2024, 3, 16)),
  );
  AgentReportEntity linkedReport = makeTestReport(
    id: 'linked-report-1',
    agentId: 'linked-agent-1',
    vectorClock: _vc(10),
  );
  bool showPrivate = false;

  late final List<EntryLink> taskLinks = [
    _link('link-entry', 'task-1', 'entry-1', 12),
    _link('link-image', 'task-1', 'image-1', 13),
    _link('link-project', 'project-1', 'task-1', 14),
    _link('link-linked-task', 'task-1', 'linked-task-1', 15),
    _link(
      'link-removed',
      'task-1',
      'deleted-entry-1',
      21,
      deletedAt: DateTime(2024, 3, 16),
    ),
  ];
  late final List<EntryLink> secondRingLinks = [
    taskLinks[1],
    taskLinks[3],
    _link('link-analysis', 'image-1', 'analysis-1', 18),
    _link('link-child', 'linked-task-1', 'child-entry-1', 19),
  ];

  MockAgentRepository agents() {
    final repository = MockAgentRepository();
    when(
      () => repository.getLinksToMultiple(
        ['linked-task-1'],
        type: AgentLinkTypes.agentTask,
      ),
    ).thenAnswer(
      (_) async => {
        'linked-task-1': [
          makeTestAgentTaskLink(
            id: 'agent-link-1',
            fromId: 'linked-agent-1',
            toId: 'linked-task-1',
            vectorClock: _vc(20),
          ),
        ],
      },
    );
    when(
      () => repository.getLatestReportsByAgentIds([
        'linked-agent-1',
      ], AgentReportScopes.current),
    ).thenAnswer((_) async => {'linked-agent-1': linkedReport});
    return repository;
  }

  MockJournalDb db() {
    final db = MockJournalDb();
    void entities(List<JournalEntity> list) => when(
      () => db.journalEntityMapForIdsIncludingDeleted(
        any(that: unorderedEquals([for (final e in list) e.meta.id])),
      ),
    ).thenAnswer((_) async => {for (final e in list) e.meta.id: e});

    when(() => db.journalEntityById('task-1')).thenAnswer((_) async => task);
    when(
      () => db.linksForEntryIdsBidirectionalIncludingRemoved({'task-1'}),
    ).thenAnswer((_) async => taskLinks);
    entities([entry, image, project, linkedTask, deletedEntry]);
    entities([checklist]);
    entities([item]);
    when(
      () => db.linksForEntryIdsBidirectionalIncludingRemoved({
        'linked-task-1',
        'image-1',
      }),
    ).thenAnswer((_) async => secondRingLinks);
    entities([task, analysis, childEntry]);
    when(
      () => db.getConfigFlag('private'),
    ).thenAnswer((_) async => showPrivate);
    return db;
  }

  Future<WakeInputs?> inputs() => taskWakeInputs(
    journalDb: db(),
    agentRepository: agents(),
    taskId: 'task-1',
  );
}

void main() {
  test('holds the vector clock of every row in the task neighbourhood, '
      'removed rows included', () async {
    final inputs = await _TaskWorld().inputs();

    expect(inputs!.clocks, {
      'entry:task-1': _vc(1),
      'entry:entry-1': _vc(2),
      'entry:image-1': _vc(3),
      'entry:project-1': _vc(4),
      'entry:checklist-1': _vc(5),
      'entry:item-1': _vc(6),
      'entry:analysis-1': _vc(7),
      'entry:linked-task-1': _vc(8),
      'entry:child-entry-1': _vc(9),
      'entry:deleted-entry-1': _vc(22),
      'link:link-entry': _vc(12),
      'link:link-image': _vc(13),
      'link:link-project': _vc(14),
      'link:link-linked-task': _vc(15),
      'link:link-removed': _vc(21),
      'link:link-analysis': _vc(18),
      'link:link-child': _vc(19),
      'agentLink:agent-link-1': _vc(20),
      'report:linked-report-1': _vc(10),
    });
    expect(inputs.hosts, {'host-a'});
    expect(inputs.readsPrivate, isFalse);
  });

  test('a peer that has not seen the unlink does not cover the wake', () async {
    final inputs = (await _TaskWorld().inputs())!;

    // Counter 21 removed a link and 22 deleted its entry: the newest writes.
    expect(
      const WakeCoverage(
        watermark: {'host-a': 22},
        readsPrivate: false,
      ).uncovered(inputs),
      isNull,
    );
    expect(
      const WakeCoverage(
        watermark: {'host-a': 20},
        readsPrivate: false,
      ).uncovered(inputs),
      'link [id:link-r] needs [id:host-a]:21, peer holds 20',
    );
  });

  test('reads private entries as the device is configured to', () async {
    final inputs = await (_TaskWorld()..showPrivate = true).inputs();

    expect(inputs!.readsPrivate, isTrue);
  });

  test('a linked report without a vector clock is kept, uncovered', () async {
    final world = _TaskWorld()
      ..linkedReport = makeTestReport(
        id: 'linked-report-1',
        agentId: 'linked-agent-1',
      );

    final inputs = await world.inputs();

    expect(inputs!.clocks, containsPair('report:linked-report-1', isNull));
  });

  test('is null for an id that is not a task', () async {
    final world = _TaskWorld();
    final db = world.db();
    when(() => db.journalEntityById('task-1')).thenAnswer(
      (_) async =>
          JournalEntity.journalEntry(meta: _meta('task-1', vc: _vc(1))),
    );

    expect(
      await taskWakeInputs(
        journalDb: db,
        agentRepository: world.agents(),
        taskId: 'task-1',
      ),
      isNull,
    );
  });
}
