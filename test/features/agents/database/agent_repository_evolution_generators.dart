/// Glados generator scaffolding for `agent_repository_evolution_test.dart`.
///
/// Extracted from the test file so the scenario classes, enums, and `Any`
/// extensions no longer dwarf the test logic. This is a helper library, not
/// a test file (no `main()`), so the one-test-file-per-source rule is
/// unaffected.
library;

import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';

enum GeneratedEvolutionTemplateSlot { target, other, missing }

enum GeneratedEvolutionAssignableTemplateSlot { target, other }

enum GeneratedEvolutionAgentSlot { first, second, other }

const generatedEvolutionTargetTemplateId =
    'generated-evolution-template-target';
const generatedEvolutionOtherTemplateId = 'generated-evolution-template-other';
const generatedEvolutionMissingTemplateId =
    'generated-evolution-template-missing';

final generatedEvolutionBase = DateTime(2026, 5, 16, 12);
final generatedEvolutionSince = DateTime(2026, 5, 16, 12);

String generatedEvolutionTemplateId(
  GeneratedEvolutionTemplateSlot slot,
) => switch (slot) {
  GeneratedEvolutionTemplateSlot.target => generatedEvolutionTargetTemplateId,
  GeneratedEvolutionTemplateSlot.other => generatedEvolutionOtherTemplateId,
  GeneratedEvolutionTemplateSlot.missing => generatedEvolutionMissingTemplateId,
};

String generatedEvolutionAssignableTemplateId(
  GeneratedEvolutionAssignableTemplateSlot slot,
) => switch (slot) {
  GeneratedEvolutionAssignableTemplateSlot.target =>
    generatedEvolutionTargetTemplateId,
  GeneratedEvolutionAssignableTemplateSlot.other =>
    generatedEvolutionOtherTemplateId,
};

String generatedEvolutionAgentId(GeneratedEvolutionAgentSlot slot) =>
    'generated-evolution-agent-${slot.name}';

class GeneratedEvolutionTemplateSpec {
  const GeneratedEvolutionTemplateSpec({
    required this.slot,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedEvolutionAssignableTemplateSlot slot;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String get id => generatedEvolutionAssignableTemplateId(slot);

  String get displayName => 'Generated evolution template ${slot.name} $seed';

  DateTime get createdAt => generatedEvolutionBase;

  DateTime get updatedAt =>
      generatedEvolutionBase.add(Duration(minutes: updatedMinuteOffset));

  DateTime? get deletedAt =>
      deleted ? updatedAt.add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return 'GeneratedEvolutionTemplateSpec('
        'slot: $slot, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedEvolutionSessionSpec {
  const GeneratedEvolutionSessionSpec({
    required this.slot,
    required this.status,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedEvolutionTemplateSlot slot;
  final EvolutionSessionStatus status;
  final bool deleted;
  final int createdMinuteOffset;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-evolution-session-$index-$seed';

  String get templateId => generatedEvolutionTemplateId(slot);

  DateTime createdAt(int index) => generatedEvolutionBase.add(
    Duration(minutes: createdMinuteOffset, seconds: index),
  );

  DateTime updatedAt(int index) => generatedEvolutionBase.add(
    Duration(minutes: updatedMinuteOffset, seconds: index),
  );

  DateTime? deletedAt(int index) =>
      deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return 'GeneratedEvolutionSessionSpec('
        'slot: $slot, status: $status, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedEvolutionNoteSpec {
  const GeneratedEvolutionNoteSpec({
    required this.slot,
    required this.kind,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final GeneratedEvolutionTemplateSlot slot;
  final EvolutionNoteKind kind;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-evolution-note-$index-$seed';

  String sessionIdAt(int index) => 'generated-evolution-note-session-$index';

  String get templateId => generatedEvolutionTemplateId(slot);

  String contentAt(int index) => 'Generated evolution note $index seed $seed';

  DateTime createdAt(int index) => generatedEvolutionBase.add(
    Duration(minutes: createdMinuteOffset, seconds: index),
  );

  DateTime? deletedAt(int index) =>
      deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return 'GeneratedEvolutionNoteSpec('
        'slot: $slot, kind: $kind, deleted: $deleted, '
        'createdMinuteOffset: $createdMinuteOffset, seed: $seed)';
  }
}

class GeneratedEvolutionAssignmentSpec {
  const GeneratedEvolutionAssignmentSpec({
    required this.templateSlot,
    required this.agentSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedEvolutionAssignableTemplateSlot templateSlot;
  final GeneratedEvolutionAgentSlot agentSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-evolution-assignment-${templateSlot.name}-${agentSlot.name}';

  String get fromId => generatedEvolutionAssignableTemplateId(templateSlot);

  String get toId => generatedEvolutionAgentId(agentSlot);

  DateTime get createdAt =>
      generatedEvolutionBase.add(Duration(minutes: createdMinuteOffset));

  DateTime? get deletedAt =>
      deleted ? createdAt.add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return 'GeneratedEvolutionAssignmentSpec('
        'templateSlot: $templateSlot, agentSlot: $agentSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedEvolutionChangedEntitySpec {
  const GeneratedEvolutionChangedEntitySpec({
    required this.agentSlot,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedEvolutionAgentSlot agentSlot;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-evolution-changed-$index-$seed';

  String get agentId => generatedEvolutionAgentId(agentSlot);

  DateTime updatedAt(int index) => generatedEvolutionBase.add(
    Duration(minutes: updatedMinuteOffset, seconds: index),
  );

  DateTime? deletedAt(int index) =>
      deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;

  @override
  String toString() {
    return 'GeneratedEvolutionChangedEntitySpec('
        'agentSlot: $agentSlot, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedEvolutionQueryScenario {
  const GeneratedEvolutionQueryScenario({
    required this.templates,
    required this.sessions,
    required this.notes,
    required this.assignments,
    required this.changedEntities,
    required this.sessionLimit,
    required this.noteLimit,
  });

  final List<GeneratedEvolutionTemplateSpec> templates;
  final List<GeneratedEvolutionSessionSpec> sessions;
  final List<GeneratedEvolutionNoteSpec> notes;
  final List<GeneratedEvolutionAssignmentSpec> assignments;
  final List<GeneratedEvolutionChangedEntitySpec> changedEntities;
  final int sessionLimit;
  final int noteLimit;

  List<String> expectedTemplateSessionIds() {
    final indexed =
        sessions.indexed
            .where(
              (entry) =>
                  entry.$2.slot == GeneratedEvolutionTemplateSlot.target &&
                  !entry.$2.deleted,
            )
            .toList()
          ..sort(
            (a, b) => b.$2.createdAt(b.$1).compareTo(a.$2.createdAt(a.$1)),
          );
    return indexed
        .take(sessionLimit)
        .map((entry) => entry.$2.idAt(entry.$1))
        .toList();
  }

  List<String> expectedAllSessionIds() {
    final activeTemplates = _activeTemplateSlots();
    final indexed =
        sessions.indexed.where((entry) {
          final slot = _assignableSlotFor(entry.$2.slot);
          return !entry.$2.deleted &&
              slot != null &&
              activeTemplates.contains(slot);
        }).toList()..sort(
          (a, b) => b.$2.updatedAt(b.$1).compareTo(a.$2.updatedAt(a.$1)),
        );
    return indexed.map((entry) => entry.$2.idAt(entry.$1)).toList();
  }

  List<String> expectedNoteIds() {
    final indexed =
        notes.indexed
            .where(
              (entry) =>
                  entry.$2.slot == GeneratedEvolutionTemplateSlot.target &&
                  !entry.$2.deleted,
            )
            .toList()
          ..sort(
            (a, b) => b.$2.createdAt(b.$1).compareTo(a.$2.createdAt(a.$1)),
          );
    return indexed
        .take(noteLimit)
        .map((entry) => entry.$2.idAt(entry.$1))
        .toList();
  }

  int get expectedChangedCount {
    final targetAssignedAgents = _activeTargetAssignmentAgentSlots();
    return changedEntities.indexed
        .where(
          (entry) =>
              !entry.$2.deleted &&
              targetAssignedAgents.contains(entry.$2.agentSlot) &&
              entry.$2.updatedAt(entry.$1).isAfter(generatedEvolutionSince),
        )
        .length;
  }

  Set<GeneratedEvolutionAssignableTemplateSlot> _activeTemplateSlots() {
    final bySlot =
        <
          GeneratedEvolutionAssignableTemplateSlot,
          GeneratedEvolutionTemplateSpec
        >{};
    for (final template in templates) {
      bySlot[template.slot] = template;
    }
    return bySlot.entries
        .where((entry) => !entry.value.deleted)
        .map((entry) => entry.key)
        .toSet();
  }

  Set<GeneratedEvolutionAgentSlot> _activeTargetAssignmentAgentSlots() {
    final byNaturalKey =
        <
          (
            GeneratedEvolutionAssignableTemplateSlot,
            GeneratedEvolutionAgentSlot,
          ),
          GeneratedEvolutionAssignmentSpec
        >{};
    for (final assignment in assignments) {
      byNaturalKey[(assignment.templateSlot, assignment.agentSlot)] =
          assignment;
    }
    return byNaturalKey.values
        .where(
          (assignment) =>
              assignment.templateSlot ==
                  GeneratedEvolutionAssignableTemplateSlot.target &&
              !assignment.deleted,
        )
        .map((assignment) => assignment.agentSlot)
        .toSet();
  }

  GeneratedEvolutionAssignableTemplateSlot? _assignableSlotFor(
    GeneratedEvolutionTemplateSlot slot,
  ) => switch (slot) {
    GeneratedEvolutionTemplateSlot.target =>
      GeneratedEvolutionAssignableTemplateSlot.target,
    GeneratedEvolutionTemplateSlot.other =>
      GeneratedEvolutionAssignableTemplateSlot.other,
    GeneratedEvolutionTemplateSlot.missing => null,
  };

  @override
  String toString() {
    return 'GeneratedEvolutionQueryScenario('
        'templates: $templates, sessions: $sessions, notes: $notes, '
        'assignments: $assignments, changedEntities: $changedEntities, '
        'sessionLimit: $sessionLimit, noteLimit: $noteLimit)';
  }
}

extension AnyGeneratedEvolutionQueryScenario on glados.Any {
  glados.Generator<GeneratedEvolutionAssignableTemplateSlot>
  get evolutionAssignableTemplateSlot => glados.AnyUtils(this).choose(
    GeneratedEvolutionAssignableTemplateSlot.values,
  );

  glados.Generator<GeneratedEvolutionTemplateSlot> get evolutionTemplateSlot =>
      glados.AnyUtils(this).choose(GeneratedEvolutionTemplateSlot.values);

  glados.Generator<GeneratedEvolutionAgentSlot> get evolutionAgentSlot =>
      glados.AnyUtils(this).choose(GeneratedEvolutionAgentSlot.values);

  glados.Generator<EvolutionSessionStatus> get evolutionSessionStatus =>
      glados.AnyUtils(this).choose(EvolutionSessionStatus.values);

  glados.Generator<EvolutionNoteKind> get evolutionNoteKind =>
      glados.AnyUtils(this).choose(EvolutionNoteKind.values);

  glados.Generator<GeneratedEvolutionTemplateSpec> get evolutionTemplateSpec =>
      glados.CombinableAny(this).combine4(
        evolutionAssignableTemplateSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-3, 3),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedEvolutionAssignableTemplateSlot slot,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => GeneratedEvolutionTemplateSpec(
          slot: slot,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedEvolutionSessionSpec> get evolutionSessionSpec =>
      glados.CombinableAny(this).combine6(
        evolutionTemplateSlot,
        evolutionSessionStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedEvolutionTemplateSlot slot,
          EvolutionSessionStatus status,
          bool deleted,
          int createdMinuteOffset,
          int updatedMinuteOffset,
          int seed,
        ) => GeneratedEvolutionSessionSpec(
          slot: slot,
          status: status,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedEvolutionNoteSpec> get evolutionNoteSpec =>
      glados.CombinableAny(this).combine5(
        evolutionTemplateSlot,
        evolutionNoteKind,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-5, 5),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedEvolutionTemplateSlot slot,
          EvolutionNoteKind kind,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => GeneratedEvolutionNoteSpec(
          slot: slot,
          kind: kind,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedEvolutionAssignmentSpec>
  get evolutionAssignmentSpec => glados.CombinableAny(this).combine4(
    evolutionAssignableTemplateSlot,
    evolutionAgentSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-5, 5),
    (
      GeneratedEvolutionAssignableTemplateSlot templateSlot,
      GeneratedEvolutionAgentSlot agentSlot,
      bool deleted,
      int createdMinuteOffset,
    ) => GeneratedEvolutionAssignmentSpec(
      templateSlot: templateSlot,
      agentSlot: agentSlot,
      deleted: deleted,
      createdMinuteOffset: createdMinuteOffset,
    ),
  );

  glados.Generator<GeneratedEvolutionChangedEntitySpec>
  get evolutionChangedEntitySpec => glados.CombinableAny(this).combine4(
    evolutionAgentSlot,
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(-5, 5),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      GeneratedEvolutionAgentSlot agentSlot,
      bool deleted,
      int updatedMinuteOffset,
      int seed,
    ) => GeneratedEvolutionChangedEntitySpec(
      agentSlot: agentSlot,
      deleted: deleted,
      updatedMinuteOffset: updatedMinuteOffset,
      seed: seed,
    ),
  );

  glados.Generator<GeneratedEvolutionQueryScenario>
  get evolutionQueryScenario => glados.CombinableAny(this).combine7(
    glados.ListAnys(this).listWithLengthInRange(
      0,
      5,
      evolutionTemplateSpec,
    ),
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      evolutionSessionSpec,
    ),
    glados.ListAnys(this).listWithLengthInRange(0, 8, evolutionNoteSpec),
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      evolutionAssignmentSpec,
    ),
    glados.ListAnys(this).listWithLengthInRange(
      0,
      8,
      evolutionChangedEntitySpec,
    ),
    glados.IntAnys(this).intInRange(1, 4),
    glados.IntAnys(this).intInRange(1, 4),
    (
      List<GeneratedEvolutionTemplateSpec> templates,
      List<GeneratedEvolutionSessionSpec> sessions,
      List<GeneratedEvolutionNoteSpec> notes,
      List<GeneratedEvolutionAssignmentSpec> assignments,
      List<GeneratedEvolutionChangedEntitySpec> changedEntities,
      int sessionLimit,
      int noteLimit,
    ) => GeneratedEvolutionQueryScenario(
      templates: templates,
      sessions: sessions,
      notes: notes,
      assignments: assignments,
      changedEntities: changedEntities,
      sessionLimit: sessionLimit,
      noteLimit: noteLimit,
    ),
  );
}
