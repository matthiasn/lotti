import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/workflow/task_state_digest.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

VectorClock _vc(int counter) => VectorClock({'host-a': counter});

Metadata _meta(String id, {VectorClock? vc}) =>
    TestMetadataFactory.create(id: id).copyWith(vectorClock: vc);

/// One device's view of a task and everything its context reads, served
/// through a [MockJournalDb] the way `taskStateDigest` queries it.
class _TaskWorld {
  _TaskWorld() {
    task = TestTaskFactory.create(
      id: 'task-1',
      checklistIds: ['checklist-1'],
    ).copyWith(meta: _meta('task-1', vc: _vc(1)));
    entry = JournalEntity.journalEntry(meta: _meta('entry-1', vc: _vc(2)));
    image = TestImageFactory.create(
      id: 'image-1',
    ).copyWith(meta: _meta('image-1', vc: _vc(3)));
    project = TestProjectFactory.create(
      id: 'project-1',
    ).copyWith(meta: _meta('project-1', vc: _vc(4)));
    checklist = JournalEntity.checklist(
      meta: _meta('checklist-1', vc: _vc(5)),
      data: const ChecklistData(
        title: 'Steps',
        linkedChecklistItems: ['item-1'],
        linkedTasks: ['task-1'],
      ),
    );
    item = JournalEntity.checklistItem(
      meta: _meta('item-1', vc: _vc(6)),
      data: TestChecklistItemFactory.create(id: 'item-1'),
    );
    analysis = TestAiResponseFactory.create(
      id: 'analysis-1',
    ).copyWith(meta: _meta('analysis-1', vc: _vc(7)));
    linkedTask = TestTaskFactory.create(
      id: 'linked-task-1',
    ).copyWith(meta: _meta('linked-task-1', vc: _vc(8)));
    childEntry = JournalEntity.journalEntry(
      meta: _meta('child-entry-1', vc: _vc(9)),
    );
    linkedReport = makeTestReport(
      id: 'linked-report-1',
      agentId: 'linked-agent-1',
      vectorClock: _vc(10),
    );
  }

  late JournalEntity task;
  late JournalEntity entry;
  late JournalEntity image;
  late JournalEntity project;
  late JournalEntity checklist;
  late JournalEntity item;
  late JournalEntity analysis;
  late JournalEntity linkedTask;
  late JournalEntity childEntry;
  late AgentReportEntity linkedReport;

  /// Serves linked lists in reverse, as another device's query might.
  bool reversed = false;

  List<T> _order<T>(List<T> list) => reversed ? list.reversed.toList() : list;

  MockAgentRepository agents() {
    final repository = MockAgentRepository();
    when(
      () => repository.getLinksToMultiple([
        'linked-task-1',
      ], type: AgentLinkTypes.agentTask),
    ).thenAnswer(
      (_) async => {
        'linked-task-1': [
          makeTestAgentTaskLink(
            fromId: 'linked-agent-1',
            toId: 'linked-task-1',
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
    when(() => db.journalEntityById('task-1')).thenAnswer((_) async => task);
    when(
      () => db.getLinkedEntities('task-1'),
    ).thenAnswer((_) async => _order([entry, image, linkedTask]));
    when(
      () => db.getLinkedToEntities('task-1'),
    ).thenAnswer((_) async => [toDbEntity(project)]);
    when(
      () => db.getJournalEntitiesForIdsUnordered({'checklist-1'}),
    ).thenAnswer((_) async => [checklist]);
    when(
      () => db.getJournalEntitiesForIdsUnordered({'item-1'}),
    ).thenAnswer((_) async => [item]);
    when(() => db.getBulkLinkedEntities({'image-1'})).thenAnswer(
      (_) async => {
        'image-1': [analysis],
      },
    );
    when(() => db.getBulkLinkedEntities({'linked-task-1'})).thenAnswer(
      (_) async => {
        'linked-task-1': [childEntry],
      },
    );
    return db;
  }

  Future<String?> digest() => taskStateDigest(
    journalDb: db(),
    agentRepository: agents(),
    taskId: 'task-1',
  );
}

void main() {
  test(
    'is a content digest over the versions the task context reads',
    () async {
      final digest = await _TaskWorld().digest();

      expect(
        digest,
        ContentDigest.of({
          'task-1': {'host-a': 1},
          'entry-1': {'host-a': 2},
          'image-1': {'host-a': 3},
          'project-1': {'host-a': 4},
          'checklist-1': {'host-a': 5},
          'item-1': {'host-a': 6},
          'analysis-1': {'host-a': 7},
          'linked-task-1': {'host-a': 8},
          'child-entry-1': {'host-a': 9},
          'report:linked-report-1': {'host-a': 10},
        }),
      );
    },
  );

  test('two replicas holding the same versions agree, whatever the query '
      'order', () async {
    final a = _TaskWorld();
    final b = _TaskWorld()..reversed = true;

    expect(await a.digest(), await b.digest());
  });

  group('changes when an entity the context reads changes:', () {
    final edits = <String, void Function(_TaskWorld world)>{
      'the task': (w) => w.task = w.task.copyWith(
        meta: w.task.meta.copyWith(vectorClock: _vc(10)),
      ),
      'a linked log entry': (w) => w.entry = w.entry.copyWith(
        meta: w.entry.meta.copyWith(vectorClock: _vc(10)),
      ),
      'the project linking to it': (w) => w.project = w.project.copyWith(
        meta: w.project.meta.copyWith(vectorClock: _vc(10)),
      ),
      'a checklist': (w) => w.checklist = w.checklist.copyWith(
        meta: w.checklist.meta.copyWith(vectorClock: _vc(10)),
      ),
      'a checklist item': (w) => w.item = w.item.copyWith(
        meta: w.item.meta.copyWith(vectorClock: _vc(10)),
      ),
      "an image's AI analysis": (w) => w.analysis = w.analysis.copyWith(
        meta: w.analysis.meta.copyWith(vectorClock: _vc(10)),
      ),
      // The linked-task context sums a linked task's time from its entries
      // and summarises its agent's report.
      "a linked task's time entry": (w) => w.childEntry = w.childEntry.copyWith(
        meta: w.childEntry.meta.copyWith(vectorClock: _vc(20)),
      ),
      "a linked task's agent report": (w) =>
          w.linkedReport = w.linkedReport.copyWith(vectorClock: _vc(20)),
    };

    for (final MapEntry(key: name, value: edit) in edits.entries) {
      test(name, () async {
        final world = _TaskWorld();
        final before = await world.digest();

        edit(world);

        expect(await world.digest(), isNot(before));
      });
    }
  });

  test('an entity without a vector clock is versioned by updatedAt', () async {
    final world = _TaskWorld()
      ..entry = JournalEntity.journalEntry(meta: _meta('entry-1'));
    final before = await world.digest();

    world.entry = world.entry.copyWith(
      meta: world.entry.meta.copyWith(
        updatedAt: world.entry.meta.updatedAt.add(const Duration(minutes: 1)),
      ),
    );

    expect(await world.digest(), isNot(before));
  });

  test('a report without a vector clock is versioned by createdAt', () async {
    final world = _TaskWorld()
      ..linkedReport = makeTestReport(
        id: 'linked-report-1',
        agentId: 'linked-agent-1',
      );
    final before = await world.digest();

    world.linkedReport = world.linkedReport.copyWith(
      createdAt: world.linkedReport.createdAt.add(const Duration(minutes: 1)),
    );

    expect(await world.digest(), isNot(before));
  });

  test('is null for an id that is not a task', () async {
    final world = _TaskWorld()
      ..task = JournalEntity.journalEntry(meta: _meta('task-1', vc: _vc(1)));

    expect(await world.digest(), isNull);
  });
}
