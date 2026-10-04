import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_wake_inputs.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_utils.dart';

VectorClock _vc(int counter) => VectorClock({'host-a': counter});

/// Writes by a second host, so a test can hold everything else while
/// missing them.
VectorClock _vcB(int counter) => VectorClock({'host-b': counter});

Metadata _meta(String id, {required VectorClock vc}) =>
    TestMetadataFactory.create(id: id).copyWith(vectorClock: vc);

EntryLink _link(
  String id,
  String fromId,
  String toId,
  VectorClock vc, {
  DateTime? deletedAt,
}) => EntryLink.basic(
  id: id,
  fromId: fromId,
  toId: toId,
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  vectorClock: vc,
  deletedAt: deletedAt,
);

/// One device's view of a task agent's inputs, served through a
/// [MockJournalDb] and a [MockAgentRepository] the way `taskWakeInputs`
/// queries them.
class _TaskWorld {
  final JournalEntity task =
      TestTaskFactory.create(
        id: 'task-1',
        checklistIds: ['checklist-1'],
      ).copyWith(
        meta: _meta('task-1', vc: _vc(1)).copyWith(
          categoryId: categoryMindfulness.id,
        ),
      );
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
      vc: _vcB(3),
    ).copyWith(deletedAt: DateTime(2024, 3, 16)),
  );
  AgentReportEntity linkedReport = makeTestReport(
    id: 'linked-report-1',
    agentId: 'linked-agent-1',
    vectorClock: _vc(10),
  );
  final AgentReportEntity projectReport = makeTestReport(
    id: 'project-report-1',
    agentId: 'project-agent-1',
    vectorClock: _vc(24),
  );
  bool showPrivate = false;
  List<LabelDefinition> labels = [testLabelDefinition1];

  /// The template's soul assignment; a test can replace it by its tombstone.
  AgentLink soulLink = makeTestSoulAssignmentLink(
    id: 'soul-link-1',
    fromId: 'template-1',
    toId: 'soul-1',
    vectorClock: _vc(30),
  );

  late final List<EntryLink> taskLinks = [
    _link('link-entry', 'task-1', 'entry-1', _vc(12)),
    _link('link-image', 'task-1', 'image-1', _vc(13)),
    _link('link-project', 'project-1', 'task-1', _vc(14)),
    _link('link-linked-task', 'task-1', 'linked-task-1', _vc(15)),
    _link(
      'link-removed',
      'task-1',
      'deleted-entry-1',
      _vcB(2),
      deletedAt: DateTime(2024, 3, 16),
    ),
  ];
  late final List<EntryLink> secondRingLinks = [
    taskLinks[1],
    taskLinks[3],
    _link('link-analysis', 'image-1', 'analysis-1', _vc(18)),
    _link('link-child', 'linked-task-1', 'child-entry-1', _vc(19)),
  ];

  MockAgentRepository agents() {
    final repository = MockAgentRepository();
    when(
      () => repository.getLinksTouchingIncludingDeleted(
        {'linked-task-1'},
        type: AgentLinkTypes.agentTask,
      ),
    ).thenAnswer(
      (_) async => [
        makeTestAgentTaskLink(
          id: 'agent-link-1',
          fromId: 'linked-agent-1',
          toId: 'linked-task-1',
          vectorClock: _vc(20),
        ),
      ],
    );
    when(
      () => repository.getLinksTouchingIncludingDeleted(
        {'project-1'},
        type: AgentLinkTypes.agentProject,
      ),
    ).thenAnswer(
      (_) async => [
        makeTestAgentProjectLink(
          id: 'project-agent-link-1',
          fromId: 'project-agent-1',
          toId: 'project-1',
          vectorClock: _vc(23),
        ),
      ],
    );
    when(
      () => repository.getLatestReportsByAgentIds(
        any(that: unorderedEquals(['linked-agent-1', 'project-agent-1'])),
        AgentReportScopes.current,
      ),
    ).thenAnswer(
      (_) async => {
        'linked-agent-1': linkedReport,
        'project-agent-1': projectReport,
      },
    );
    for (final (reportingAgentId, counter) in [
      ('linked-agent-1', 21),
      ('project-agent-1', 22),
    ]) {
      when(
        () => repository.getReportHead(
          reportingAgentId,
          AgentReportScopes.current,
        ),
      ).thenAnswer(
        (_) async => makeTestReportHead(
          id: 'head-$reportingAgentId',
          agentId: reportingAgentId,
          vectorClock: _vc(counter),
        ),
      );
    }
    when(
      () => repository.getChangeDecisions(
        'agent-1',
        taskId: 'task-1',
        limit: TaskAgentWorkflow.resolvedDecisionWindow,
      ),
    ).thenAnswer(
      (_) async => [
        makeTestChangeDecision(
          id: 'user-decision-1',
          agentId: 'agent-1',
          verdict: ChangeDecisionVerdict.rejected,
          taskId: 'task-1',
          vectorClock: _vc(25),
        ),
        // The agent retracting its own proposal: an output, not an input.
        makeTestChangeDecision(
          id: 'agent-retraction-1',
          agentId: 'agent-1',
          actor: DecisionActor.agent,
          taskId: 'task-1',
          vectorClock: _vc(98),
        ),
      ],
    );
    when(
      () => repository.getLinksTouchingIncludingDeleted(
        {'agent-1'},
        type: AgentLinkTypes.templateAssignment,
      ),
    ).thenAnswer(
      (_) async => [
        makeTestTemplateAssignmentLink(
          id: 'template-link-1',
          fromId: 'template-1',
          toId: 'agent-1',
          vectorClock: _vc(26),
        ),
      ],
    );
    when(() => repository.getEntity('template-1')).thenAnswer(
      (_) async => makeTestTemplate(
        id: 'template-1',
        agentId: 'template-1',
        vectorClock: _vc(27),
      ),
    );
    when(() => repository.getTemplateHead('template-1')).thenAnswer(
      (_) async => makeTestTemplateHead(
        id: 'template-head-1',
        agentId: 'template-1',
        vectorClock: _vc(28),
      ),
    );
    when(() => repository.getActiveTemplateVersion('template-1')).thenAnswer(
      (_) async => makeTestTemplateVersion(
        id: 'template-version-1',
        agentId: 'template-1',
        vectorClock: _vc(29),
      ),
    );
    when(
      () => repository.getLinksTouchingIncludingDeleted(
        {'template-1'},
        type: AgentLinkTypes.soulAssignment,
      ),
    ).thenAnswer((_) async => [soulLink]);
    when(() => repository.getSoulDocumentHead('soul-1')).thenAnswer(
      (_) async => makeTestSoulDocumentHead(
        id: 'soul-head-1',
        agentId: 'soul-1',
        vectorClock: _vc(31),
      ),
    );
    when(() => repository.getActiveSoulDocumentVersion('soul-1')).thenAnswer(
      (_) async => makeTestSoulDocumentVersion(
        id: 'soul-version-1',
        agentId: 'soul-1',
        vectorClock: _vc(32),
      ),
    );
    when(
      () => repository.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: 'task-1',
      ),
    ).thenAnswer(
      (_) async => [
        makeTestAttentionRequest(
          id: 'day-agent-request-1',
          agentId: 'day-agent-1',
          targetId: 'task-1',
          vectorClock: _vc(33),
        ),
        // This agent's own request: an output of its wakes.
        makeTestAttentionRequest(
          id: 'own-request-1',
          agentId: 'agent-1',
          targetId: 'task-1',
          vectorClock: _vc(97),
        ),
      ],
    );
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
    when(
      db.getAllLabelDefinitionsIncludingPrivate,
    ).thenAnswer((_) async => labels);
    when(
      () => db.getCategoryByIdForIntegrity(categoryMindfulness.id),
    ).thenAnswer((_) async => categoryMindfulness);
    return db;
  }

  Future<WakeInputs?> inputs() => taskWakeInputs(
    journalDb: db(),
    agentRepository: agents(),
    agentId: 'agent-1',
    taskId: 'task-1',
  );
}

void main() {
  test('holds the vector clock of every input row, removed rows included, '
      "and none of the agent's own outputs", () async {
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
      'entry:deleted-entry-1': _vcB(3),
      'link:link-entry': _vc(12),
      'link:link-image': _vc(13),
      'link:link-project': _vc(14),
      'link:link-linked-task': _vc(15),
      'link:link-removed': _vcB(2),
      'link:link-analysis': _vc(18),
      'link:link-child': _vc(19),
      // The linked task's agent and the parent project's agent, with their
      // current reports.
      'agentLink:agent-link-1': _vc(20),
      'report:linked-report-1': _vc(10),
      'reportHead:head-linked-agent-1': _vc(21),
      'agentLink:project-agent-link-1': _vc(23),
      'report:project-report-1': _vc(24),
      'reportHead:head-project-agent-1': _vc(22),
      // The user's decision; not the agent's retraction.
      'decision:user-decision-1': _vc(25),
      // The system prompt: template and soul.
      'agentLink:template-link-1': _vc(26),
      'template:template-1': _vc(27),
      'template:template-head-1': _vc(28),
      'template:template-version-1': _vc(29),
      'agentLink:soul-link-1': _vc(30),
      'soul:soul-head-1': _vc(31),
      'soul:soul-version-1': _vc(32),
      // Another agent's attention request; not this agent's own.
      'attention:day-agent-request-1': _vc(33),
    });
    expect(inputs.hosts, {'host-a', 'host-b'});
    expect(inputs.readsPrivate, isFalse);
  });

  test('a peer that has not seen the unlink does not cover the wake', () async {
    final inputs = (await _TaskWorld().inputs())!;

    // host-b's counter 2 removed a link and 3 deleted its entry.
    expect(
      WakeCoverage(
        watermark: const {'host-a': 40, 'host-b': 3},
        readsPrivate: false,
        definitions: inputs.definitions,
      ).uncovered(inputs),
      isNull,
    );
    expect(
      WakeCoverage(
        watermark: const {'host-a': 40, 'host-b': 1},
        readsPrivate: false,
        definitions: inputs.definitions,
      ).uncovered(inputs),
      'link [id:link-r] needs [id:host-b]:2, peer holds 1',
    );
  });

  test("a peer missing the project agent's newer report does not cover the "
      'wake', () async {
    final inputs = (await _TaskWorld().inputs())!;

    expect(
      WakeCoverage(
        watermark: const {'host-a': 23, 'host-b': 3},
        readsPrivate: false,
        definitions: inputs.definitions,
      ).uncovered(inputs),
      'report [id:projec] needs [id:host-a]:24, peer holds 23',
    );
  });

  test('digests every label definition and the task category', () async {
    final world = _TaskWorld();
    final inputs = (await world.inputs())!;

    expect(
      inputs.definitions,
      ContentDigest.of({
        'labels': {
          testLabelDefinition1.id: jsonDecode(jsonEncode(testLabelDefinition1)),
        },
        'category': jsonDecode(jsonEncode(categoryMindfulness)),
      }),
    );

    world.labels = [testLabelDefinition1, testLabelDefinition2];
    expect((await world.inputs())!.definitions, isNot(inputs.definitions));
  });

  test('a peer that has not seen a soul unassignment does not cover the '
      'wake', () async {
    final world = _TaskWorld()
      ..soulLink = makeTestSoulAssignmentLink(
        id: 'soul-link-1',
        fromId: 'template-1',
        toId: 'soul-1',
        vectorClock: _vcB(4),
      ).copyWith(deletedAt: DateTime(2024, 3, 16));

    final inputs = (await world.inputs())!;

    expect(inputs.clocks, containsPair('agentLink:soul-link-1', _vcB(4)));
    expect(
      WakeCoverage(
        watermark: const {'host-a': 40, 'host-b': 3},
        readsPrivate: false,
        definitions: inputs.definitions,
      ).uncovered(inputs),
      'agentLink [id:soul-l] needs [id:host-b]:4, peer holds 3',
    );
  });

  test('reads private entries as the device is configured to', () async {
    final inputs = await (_TaskWorld()..showPrivate = true).inputs();

    expect(inputs!.readsPrivate, isTrue);
  });

  test('a row without a vector clock is read, and covered by a peer run '
      'that read it too', () async {
    final world = _TaskWorld()
      ..linkedReport = makeTestReport(
        id: 'linked-report-1',
        agentId: 'linked-agent-1',
      );

    final inputs = (await world.inputs())!;

    expect(inputs.clocks, containsPair('report:linked-report-1', isNull));
    expect(inputs.clockless, {'report:linked-report-1'});
    expect(
      WakeCoverage(
        watermark: const {'host-a': 40, 'host-b': 4},
        readsPrivate: false,
        definitions: inputs.definitions,
        clockless: const {'report:linked-report-1'},
      ).uncovered(inputs),
      isNull,
    );
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
        agentId: 'agent-1',
        taskId: 'task-1',
      ),
      isNull,
    );
  });
}
