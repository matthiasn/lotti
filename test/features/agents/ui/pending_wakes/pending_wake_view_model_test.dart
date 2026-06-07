import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/pending_wakes/pending_wake_view_model.dart';

import '../../test_utils.dart';

enum _GeneratedPendingWakeTypeSlot { pending, scheduled }

enum _GeneratedPendingWakeSubjectSlot { none, task, day, project, both }

enum _GeneratedPendingWakeTitleSlot {
  nullTitle,
  empty,
  whitespace,
  sameAsAgent,
  subject,
  paddedSubject,
}

enum _GeneratedPendingWakeKindSlot {
  taskAgent,
  dayAgent,
  projectAgent,
  templateImprover,
  unknown,
}

PendingWakeType _generatedPendingWakeType(
  _GeneratedPendingWakeTypeSlot slot,
) {
  return switch (slot) {
    _GeneratedPendingWakeTypeSlot.pending => PendingWakeType.pending,
    _GeneratedPendingWakeTypeSlot.scheduled => PendingWakeType.scheduled,
  };
}

String _generatedPendingWakeKind(_GeneratedPendingWakeKindSlot slot) {
  return switch (slot) {
    _GeneratedPendingWakeKindSlot.taskAgent => AgentKinds.taskAgent,
    _GeneratedPendingWakeKindSlot.dayAgent => AgentKinds.dayAgent,
    _GeneratedPendingWakeKindSlot.projectAgent => AgentKinds.projectAgent,
    _GeneratedPendingWakeKindSlot.templateImprover =>
      AgentKinds.templateImprover,
    _GeneratedPendingWakeKindSlot.unknown => 'unknown_kind',
  };
}

String? _rawSubjectTitle({
  required _GeneratedPendingWakeTitleSlot slot,
  required String agentName,
  required int index,
}) {
  return switch (slot) {
    _GeneratedPendingWakeTitleSlot.nullTitle => null,
    _GeneratedPendingWakeTitleSlot.empty => '',
    _GeneratedPendingWakeTitleSlot.whitespace => '   ',
    _GeneratedPendingWakeTitleSlot.sameAsAgent => agentName,
    _GeneratedPendingWakeTitleSlot.subject => 'Subject $index',
    _GeneratedPendingWakeTitleSlot.paddedSubject => '  Subject $index  ',
  };
}

AgentSlots _generatedPendingWakeSlots(
  _GeneratedPendingWakeSubjectSlot slot,
  int index,
) {
  return switch (slot) {
    _GeneratedPendingWakeSubjectSlot.none => const AgentSlots(),
    _GeneratedPendingWakeSubjectSlot.task => AgentSlots(
      activeTaskId: _taskId(index),
    ),
    _GeneratedPendingWakeSubjectSlot.day => AgentSlots(
      activeDayId: _dayId(index),
    ),
    _GeneratedPendingWakeSubjectSlot.project => AgentSlots(
      activeProjectId: _projectId(index),
    ),
    _GeneratedPendingWakeSubjectSlot.both => AgentSlots(
      activeTaskId: _taskId(index),
      activeProjectId: _projectId(index),
    ),
  };
}

String? _expectedSubjectId(_GeneratedPendingWakeSubjectSlot slot, int index) {
  return switch (slot) {
    _GeneratedPendingWakeSubjectSlot.none => null,
    _GeneratedPendingWakeSubjectSlot.task => _taskId(index),
    _GeneratedPendingWakeSubjectSlot.day => _dayId(index),
    _GeneratedPendingWakeSubjectSlot.project => _projectId(index),
    _GeneratedPendingWakeSubjectSlot.both => _taskId(index),
  };
}

String _taskId(int index) => 'task-$index';

String _dayId(int index) =>
    'dayplan-2026-05-${index.toString().padLeft(2, '0')}';

String _projectId(int index) => 'project-$index';

class _GeneratedPendingWakeRowSpec {
  const _GeneratedPendingWakeRowSpec({
    required this.typeSlot,
    required this.subjectSlot,
    required this.titleSlot,
    required this.kindSlot,
    required this.lifecycle,
  });

  final _GeneratedPendingWakeTypeSlot typeSlot;
  final _GeneratedPendingWakeSubjectSlot subjectSlot;
  final _GeneratedPendingWakeTitleSlot titleSlot;
  final _GeneratedPendingWakeKindSlot kindSlot;
  final AgentLifecycle lifecycle;

  @override
  String toString() {
    return '_GeneratedPendingWakeRowSpec('
        'typeSlot: $typeSlot, subjectSlot: $subjectSlot, '
        'titleSlot: $titleSlot, kindSlot: $kindSlot, '
        'lifecycle: $lifecycle)';
  }
}

class _GeneratedPendingWakeRowsScenario {
  const _GeneratedPendingWakeRowsScenario({required this.specs});

  final List<_GeneratedPendingWakeRowSpec> specs;

  @override
  String toString() {
    return '_GeneratedPendingWakeRowsScenario(specs: $specs)';
  }
}

extension _AnyGeneratedPendingWakeRowsScenario on glados.Any {
  glados.Generator<_GeneratedPendingWakeTypeSlot> get pendingWakeTypeSlot =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeTypeSlot.values);

  glados.Generator<_GeneratedPendingWakeSubjectSlot>
  get pendingWakeSubjectSlot =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeSubjectSlot.values);

  glados.Generator<_GeneratedPendingWakeTitleSlot> get pendingWakeTitleSlot =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeTitleSlot.values);

  glados.Generator<_GeneratedPendingWakeKindSlot> get pendingWakeKindSlot =>
      glados.AnyUtils(this).choose(_GeneratedPendingWakeKindSlot.values);

  glados.Generator<AgentLifecycle> get agentLifecycle =>
      glados.AnyUtils(this).choose(AgentLifecycle.values);

  glados.Generator<_GeneratedPendingWakeRowSpec> get pendingWakeRowSpec =>
      glados.CombinableAny(this).combine5(
        pendingWakeTypeSlot,
        pendingWakeSubjectSlot,
        pendingWakeTitleSlot,
        pendingWakeKindSlot,
        agentLifecycle,
        (
          _GeneratedPendingWakeTypeSlot typeSlot,
          _GeneratedPendingWakeSubjectSlot subjectSlot,
          _GeneratedPendingWakeTitleSlot titleSlot,
          _GeneratedPendingWakeKindSlot kindSlot,
          AgentLifecycle lifecycle,
        ) => _GeneratedPendingWakeRowSpec(
          typeSlot: typeSlot,
          subjectSlot: subjectSlot,
          titleSlot: titleSlot,
          kindSlot: kindSlot,
          lifecycle: lifecycle,
        ),
      );

  glados.Generator<_GeneratedPendingWakeRowsScenario>
  get pendingWakeRowsScenario => glados.ListAnys(this)
      .listWithLengthInRange(0, 35, pendingWakeRowSpec)
      .map((specs) => _GeneratedPendingWakeRowsScenario(specs: specs));
}

void main() {
  group('agentPendingWakeRowVmsProvider', () {
    glados.Glados(
      glados.any.pendingWakeRowsScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'maps generated pending wake rows with title fallback semantics',
      (
        scenario,
      ) async {
        final records = <PendingWakeRecord>[];
        final subjectTitles = <String?, String?>{};

        for (final (index, spec) in scenario.specs.indexed) {
          final agentId = 'agent-$index';
          final agentName = 'Agent $index';
          final type = _generatedPendingWakeType(spec.typeSlot);
          final dueAt = DateTime(2026, 4, 3, index % 24, index % 60);
          final subjectId = _expectedSubjectId(spec.subjectSlot, index);
          subjectTitles[subjectId] = _rawSubjectTitle(
            slot: spec.titleSlot,
            agentName: agentName,
            index: index,
          );

          records.add(
            PendingWakeRecord(
              agent: makeTestIdentity(
                id: agentId,
                agentId: agentId,
                kind: _generatedPendingWakeKind(spec.kindSlot),
                displayName: agentName,
                lifecycle: spec.lifecycle,
              ),
              state: makeTestState(
                id: 'state-$index',
                agentId: agentId,
                slots: _generatedPendingWakeSlots(spec.subjectSlot, index),
              ),
              type: type,
              dueAt: dueAt,
            ),
          );
        }

        final vms = await _readPendingWakeVms(
          records: records,
          subjectTitles: subjectTitles,
        );

        expect(vms, hasLength(records.length), reason: '$scenario');
        for (final (index, vm) in vms.indexed) {
          final spec = scenario.specs[index];
          final record = records[index];
          final reason = '$scenario (index $index)';
          final agentName = 'Agent $index';
          final subjectTitle =
              subjectTitles[_expectedSubjectId(spec.subjectSlot, index)]
                  ?.trim();
          final hasSubject =
              subjectTitle != null &&
              subjectTitle.isNotEmpty &&
              subjectTitle != agentName;

          expect(vm.id, record.id, reason: reason);
          expect(vm.agentId, 'agent-$index', reason: reason);
          expect(
            vm.title,
            hasSubject ? subjectTitle : agentName,
            reason: reason,
          );
          expect(vm.subtitle, hasSubject ? agentName : null, reason: reason);
          expect(
            vm.kind,
            _generatedPendingWakeKind(spec.kindSlot),
            reason: reason,
          );
          expect(vm.lifecycle, spec.lifecycle, reason: reason);
          expect(
            vm.type,
            _generatedPendingWakeType(spec.typeSlot),
            reason: reason,
          );
          expect(vm.dueAt, record.dueAt, reason: reason);
        }
      },
      tags: 'glados',
    );

    test('returns an empty list when no pending wake records exist', () async {
      final vms = await _readPendingWakeVms(
        records: const [],
        subjectTitles: const {},
      );

      expect(vms, isEmpty);
    });

    test(
      'resolves the title from the task slot when both task and project '
      'slots are set',
      () async {
        // Worked example of the slot-priority rule in `_subjectEntryId`:
        // activeTaskId is consulted before activeProjectId, so the title
        // comes from the task subject even when a project subject also has
        // a (different) title. Without the priority rule this would resolve
        // to the project title instead.
        final record = PendingWakeRecord(
          agent: makeTestIdentity(
            id: 'agent-both',
            agentId: 'agent-both',
            displayName: 'Both Slots Agent',
          ),
          state: makeTestState(
            id: 'state-both',
            agentId: 'agent-both',
            slots: const AgentSlots(
              activeTaskId: 'task-both',
              activeProjectId: 'project-both',
            ),
          ),
          type: PendingWakeType.pending,
          dueAt: DateTime(2026, 4, 3, 10),
        );

        final vms = await _readPendingWakeVms(
          records: [record],
          subjectTitles: const {
            'task-both': 'Task Title Wins',
            'project-both': 'Project Title Loses',
          },
        );

        expect(vms, hasLength(1));
        // Task slot title becomes the row title; agent name drops to subtitle.
        expect(vms.single.title, 'Task Title Wins');
        expect(vms.single.subtitle, 'Both Slots Agent');
      },
    );
  });
}

Future<List<PendingWakeVm>> _readPendingWakeVms({
  required List<PendingWakeRecord> records,
  required Map<String?, String?> subjectTitles,
}) async {
  final container = ProviderContainer(
    overrides: [
      pendingWakeRecordsProvider.overrideWith((ref) async => records),
      pendingWakeTargetTitleProvider.overrideWith(
        (ref, entryId) async => subjectTitles[entryId],
      ),
    ],
  );

  try {
    return await container.read(agentPendingWakeRowVmsProvider.future);
  } finally {
    container.dispose();
  }
}
