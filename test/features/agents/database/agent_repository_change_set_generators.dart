/// Glados generator scaffolding for `agent_repository_change_set_test.dart`.
///
/// Extracted from the test file so the scenario classes, enums, and `Any`
/// extensions no longer dwarf the test logic. This is a helper library, not
/// a test file (no `main()`), so the one-test-file-per-source rule is
/// unaffected.
library;

import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';

enum GeneratedChangeAgentSlot { target, other }

enum GeneratedChangeTaskSlot { target, other }

enum GeneratedChangeTemplateSlot { target, other }

final generatedChangeBase = DateTime(2026, 5, 15, 12);
final generatedChangeSince = DateTime(2026, 5, 15, 12);

const String generatedChangeTargetAgentId = 'generated-change-agent-target';
const String generatedChangeOtherAgentId = 'generated-change-agent-other';
const String generatedChangeTargetTaskId = 'generated-change-task-target';
const String generatedChangeOtherTaskId = 'generated-change-task-other';
const String generatedChangeTargetTemplateId =
    'generated-change-template-target';
const String generatedChangeOtherTemplateId = 'generated-change-template-other';

class GeneratedChangeSetSpec {
  const GeneratedChangeSetSpec({
    required this.agentSlot,
    required this.taskSlot,
    required this.status,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final GeneratedChangeAgentSlot agentSlot;
  final GeneratedChangeTaskSlot taskSlot;
  final ChangeSetStatus status;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-change-set-$index-$seed';

  String get agentId => switch (agentSlot) {
    GeneratedChangeAgentSlot.target => generatedChangeTargetAgentId,
    GeneratedChangeAgentSlot.other => generatedChangeOtherAgentId,
  };

  String get taskId => switch (taskSlot) {
    GeneratedChangeTaskSlot.target => generatedChangeTargetTaskId,
    GeneratedChangeTaskSlot.other => generatedChangeOtherTaskId,
  };

  bool get isPendingLike {
    return status == ChangeSetStatus.pending ||
        status == ChangeSetStatus.partiallyResolved;
  }

  DateTime createdAt(int index) {
    return generatedChangeBase.add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedChangeSetSpec('
        'agentSlot: $agentSlot, taskSlot: $taskSlot, status: $status, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class GeneratedChangeDecisionSpec {
  const GeneratedChangeDecisionSpec({
    required this.agentSlot,
    required this.taskSlot,
    required this.verdict,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final GeneratedChangeAgentSlot agentSlot;
  final GeneratedChangeTaskSlot taskSlot;
  final ChangeDecisionVerdict verdict;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-change-decision-$index-$seed';

  String get agentId => switch (agentSlot) {
    GeneratedChangeAgentSlot.target => generatedChangeTargetAgentId,
    GeneratedChangeAgentSlot.other => generatedChangeOtherAgentId,
  };

  String get taskId => switch (taskSlot) {
    GeneratedChangeTaskSlot.target => generatedChangeTargetTaskId,
    GeneratedChangeTaskSlot.other => generatedChangeOtherTaskId,
  };

  DateTime createdAt(int index) {
    return generatedChangeBase.add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedChangeDecisionSpec('
        'agentSlot: $agentSlot, taskSlot: $taskSlot, verdict: $verdict, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class GeneratedChangeTemplateAssignmentSpec {
  const GeneratedChangeTemplateAssignmentSpec({
    required this.templateSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedChangeTemplateSlot templateSlot;
  final GeneratedChangeAgentSlot agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-change-assignment-${templateSlot.name}-${agentSlot.name}';

  String get templateId => switch (templateSlot) {
    GeneratedChangeTemplateSlot.target => generatedChangeTargetTemplateId,
    GeneratedChangeTemplateSlot.other => generatedChangeOtherTemplateId,
  };

  String get agentId => switch (agentSlot) {
    GeneratedChangeAgentSlot.target => generatedChangeTargetAgentId,
    GeneratedChangeAgentSlot.other => generatedChangeOtherAgentId,
  };

  DateTime get createdAt {
    return generatedChangeBase.add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return 'GeneratedChangeTemplateAssignmentSpec('
        'templateSlot: $templateSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedChangeQueryScenario {
  const GeneratedChangeQueryScenario({
    required this.changeSets,
    required this.decisions,
    required this.assignments,
    required this.pendingLimit,
    required this.decisionLimit,
    required this.templateDecisionLimit,
  });

  final List<GeneratedChangeSetSpec> changeSets;
  final List<GeneratedChangeDecisionSpec> decisions;
  final List<GeneratedChangeTemplateAssignmentSpec> assignments;
  final int pendingLimit;
  final int decisionLimit;
  final int templateDecisionLimit;

  Iterable<GeneratedChangeAgentSlot> get _targetTemplateAgentSlots {
    final finalAssignmentsByNaturalKey =
        <String, GeneratedChangeTemplateAssignmentSpec>{};
    for (final assignment in assignments) {
      final key =
          '${assignment.templateSlot.name}:${assignment.agentSlot.name}';
      finalAssignmentsByNaturalKey[key] = assignment;
    }

    return finalAssignmentsByNaturalKey.values
        .where(
          (assignment) =>
              assignment.templateSlot == GeneratedChangeTemplateSlot.target &&
              !assignment.deleted,
        )
        .map((assignment) => assignment.agentSlot);
  }

  List<int> _sortedChangeSetIndexes(Iterable<int> indexes) {
    return indexes.toList()..sort(
      (a, b) => changeSets[b]
          .createdAt(b)
          .compareTo(
            changeSets[a].createdAt(a),
          ),
    );
  }

  List<int> _sortedDecisionIndexes(Iterable<int> indexes) {
    return indexes.toList()..sort(
      (a, b) => decisions[b]
          .createdAt(b)
          .compareTo(
            decisions[a].createdAt(a),
          ),
    );
  }

  List<String> expectedPendingIds({required int limit}) {
    return _sortedChangeSetIndexes(
      Iterable<int>.generate(changeSets.length).where(
        (index) =>
            changeSets[index].agentSlot == GeneratedChangeAgentSlot.target &&
            changeSets[index].taskSlot == GeneratedChangeTaskSlot.target &&
            changeSets[index].isPendingLike &&
            !changeSets[index].deleted,
      ),
    ).take(limit).map((index) => changeSets[index].idAt(index)).toList();
  }

  List<String> expectedRecentDecisionIds({required int limit}) {
    return _sortedDecisionIndexes(
      Iterable<int>.generate(decisions.length).where(
        (index) =>
            decisions[index].agentSlot == GeneratedChangeAgentSlot.target &&
            decisions[index].taskSlot == GeneratedChangeTaskSlot.target &&
            !decisions[index].deleted,
      ),
    ).take(limit).map((index) => decisions[index].idAt(index)).toList();
  }

  List<String> expectedTemplateDecisionIds({required int limit}) {
    final activeAgentSlots = _targetTemplateAgentSlots.toSet();
    return _sortedDecisionIndexes(
      Iterable<int>.generate(decisions.length).where(
        (index) =>
            activeAgentSlots.contains(decisions[index].agentSlot) &&
            !decisions[index].deleted &&
            !decisions[index].createdAt(index).isBefore(generatedChangeSince),
      ),
    ).take(limit).map((index) => decisions[index].idAt(index)).toList();
  }

  @override
  String toString() {
    return 'GeneratedChangeQueryScenario('
        'pendingLimit: $pendingLimit, decisionLimit: $decisionLimit, '
        'templateDecisionLimit: $templateDecisionLimit, '
        'changeSets: $changeSets, decisions: $decisions, '
        'assignments: $assignments)';
  }
}

extension AnyGeneratedChangeQueryScenario on glados.Any {
  glados.Generator<GeneratedChangeAgentSlot> get changeAgentSlot =>
      glados.AnyUtils(this).choose(GeneratedChangeAgentSlot.values);

  glados.Generator<GeneratedChangeTaskSlot> get changeTaskSlot =>
      glados.AnyUtils(this).choose(GeneratedChangeTaskSlot.values);

  glados.Generator<GeneratedChangeTemplateSlot> get changeTemplateSlot =>
      glados.AnyUtils(this).choose(GeneratedChangeTemplateSlot.values);

  glados.Generator<ChangeSetStatus> get changeSetStatus =>
      glados.AnyUtils(this).choose(ChangeSetStatus.values);

  glados.Generator<ChangeDecisionVerdict> get changeDecisionVerdict =>
      glados.AnyUtils(this).choose(ChangeDecisionVerdict.values);

  glados.Generator<GeneratedChangeSetSpec> get changeSetSpec =>
      glados.CombinableAny(this).combine6(
        changeAgentSlot,
        changeTaskSlot,
        changeSetStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedChangeAgentSlot agentSlot,
          GeneratedChangeTaskSlot taskSlot,
          ChangeSetStatus status,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => GeneratedChangeSetSpec(
          agentSlot: agentSlot,
          taskSlot: taskSlot,
          status: status,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedChangeDecisionSpec> get changeDecisionSpec =>
      glados.CombinableAny(this).combine6(
        changeAgentSlot,
        changeTaskSlot,
        changeDecisionVerdict,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedChangeAgentSlot agentSlot,
          GeneratedChangeTaskSlot taskSlot,
          ChangeDecisionVerdict verdict,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => GeneratedChangeDecisionSpec(
          agentSlot: agentSlot,
          taskSlot: taskSlot,
          verdict: verdict,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedChangeTemplateAssignmentSpec>
  get changeTemplateAssignmentSpec => glados.CombinableAny(this).combine4(
    changeTemplateSlot,
    changeAgentSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-4, 4),
    (
      GeneratedChangeTemplateSlot templateSlot,
      GeneratedChangeAgentSlot agentSlot,
      bool deleted,
      int createdMinuteOffset,
    ) => GeneratedChangeTemplateAssignmentSpec(
      templateSlot: templateSlot,
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
    ),
  );

  glados.Generator<GeneratedChangeQueryScenario> get changeQueryScenario =>
      glados.CombinableAny(this).combine6(
        glados.ListAnys(this).listWithLengthInRange(0, 8, changeSetSpec),
        glados.ListAnys(this).listWithLengthInRange(0, 8, changeDecisionSpec),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 6, changeTemplateAssignmentSpec),
        glados.IntAnys(this).intInRange(1, 4),
        glados.IntAnys(this).intInRange(1, 4),
        glados.IntAnys(this).intInRange(1, 4),
        (
          List<GeneratedChangeSetSpec> changeSets,
          List<GeneratedChangeDecisionSpec> decisions,
          List<GeneratedChangeTemplateAssignmentSpec> assignments,
          int pendingLimit,
          int decisionLimit,
          int templateDecisionLimit,
        ) => GeneratedChangeQueryScenario(
          changeSets: changeSets,
          decisions: decisions,
          assignments: assignments,
          pendingLimit: pendingLimit,
          decisionLimit: decisionLimit,
          templateDecisionLimit: templateDecisionLimit,
        ),
      );
}
