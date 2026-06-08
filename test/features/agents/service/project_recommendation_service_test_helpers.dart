import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';

import '../test_utils.dart';

enum GeneratedRecommendationRawStepsSlot { missing, nonList, list }

enum GeneratedRecommendationStepSlot {
  validTitleOnly,
  validWithRationale,
  validWithPriority,
  validWithEmptyMetadata,
  validWithWhitespaceMetadata,
  blankTitle,
  missingTitle,
  nonStringTitle,
  nonMap,
}

enum GeneratedRecommendationExistingSlot {
  activeSameProject,
  activeOtherProject,
  dismissedSameProject,
  resolvedSameProject,
  wrongType,
}

enum GeneratedRecommendationLookupSlot {
  missing,
  wrongType,
  active,
  resolved,
  dismissed,
  superseded,
}

enum GeneratedRecommendationTransitionOperation { resolve, dismiss }

final hGeneratedRecommendationNow = DateTime(2026, 5, 21, 12, 30);

class GeneratedRecommendationDraft {
  const GeneratedRecommendationDraft({
    required this.title,
    this.rationale,
    this.priority,
  });

  final String title;
  final String? rationale;
  final String? priority;
}

class GeneratedRecommendationRecordScenario {
  const GeneratedRecommendationRecordScenario({
    required this.rawStepsSlot,
    required this.stepSlots,
    required this.existingSlots,
  });

  final GeneratedRecommendationRawStepsSlot rawStepsSlot;
  final List<GeneratedRecommendationStepSlot> stepSlots;
  final List<GeneratedRecommendationExistingSlot> existingSlots;

  List<Object?> get rawStepValues {
    return [
      for (final (index, slot) in stepSlots.indexed) hRawStep(index, slot),
    ];
  }

  Map<String, dynamic>? get decisionArgs {
    return switch (rawStepsSlot) {
      GeneratedRecommendationRawStepsSlot.missing => const {},
      GeneratedRecommendationRawStepsSlot.nonList => const {'steps': 'nope'},
      GeneratedRecommendationRawStepsSlot.list => {'steps': rawStepValues},
    };
  }

  List<GeneratedRecommendationDraft> get validDrafts {
    if (rawStepsSlot != GeneratedRecommendationRawStepsSlot.list) {
      return const [];
    }
    return [
      for (final (index, slot) in stepSlots.indexed)
        if (hExpectedDraft(index, slot) != null) hExpectedDraft(index, slot)!,
    ];
  }

  List<AgentDomainEntity> get existingEntities {
    return [
      for (final (index, slot) in existingSlots.indexed)
        hExistingEntity(index, slot),
    ];
  }

  List<ProjectRecommendationEntity> get supersededRecommendations {
    return [
      for (final entity in existingEntities)
        if (entity is ProjectRecommendationEntity &&
            entity.projectId == 'generated-project' &&
            entity.status == ProjectRecommendationStatus.active)
          entity,
    ];
  }

  Object? hRawStep(int index, GeneratedRecommendationStepSlot slot) {
    return switch (slot) {
      GeneratedRecommendationStepSlot.validTitleOnly => {
        'title': '  Generated step $index  ',
      },
      GeneratedRecommendationStepSlot.validWithRationale => {
        'title': 'Generated rationale step $index',
        'rationale': '  Explain step $index  ',
      },
      GeneratedRecommendationStepSlot.validWithPriority => {
        'title': 'Generated priority step $index',
        'priority': ' high ',
      },
      GeneratedRecommendationStepSlot.validWithEmptyMetadata => {
        'title': 'Generated clean step $index',
        'rationale': '   ',
        'priority': '',
      },
      // Whitespace-only (but non-empty) rationale AND priority: forces the
      // `.trim().isNotEmpty` guard — not just `.isEmpty` — to drop both, and
      // ensures a blank priority is never passed through `.toUpperCase()`.
      GeneratedRecommendationStepSlot.validWithWhitespaceMetadata => {
        'title': 'Generated trimmed step $index',
        'rationale': ' \t ',
        'priority': '   ',
      },
      GeneratedRecommendationStepSlot.blankTitle => {'title': '   '},
      GeneratedRecommendationStepSlot.missingTitle => {
        'rationale': 'missing title',
      },
      GeneratedRecommendationStepSlot.nonStringTitle => {'title': index},
      GeneratedRecommendationStepSlot.nonMap => 'not-a-step-$index',
    };
  }

  GeneratedRecommendationDraft? hExpectedDraft(
    int index,
    GeneratedRecommendationStepSlot slot,
  ) {
    return switch (slot) {
      GeneratedRecommendationStepSlot.validTitleOnly =>
        GeneratedRecommendationDraft(title: 'Generated step $index'),
      GeneratedRecommendationStepSlot.validWithRationale =>
        GeneratedRecommendationDraft(
          title: 'Generated rationale step $index',
          rationale: 'Explain step $index',
        ),
      GeneratedRecommendationStepSlot.validWithPriority =>
        GeneratedRecommendationDraft(
          title: 'Generated priority step $index',
          priority: 'HIGH',
        ),
      GeneratedRecommendationStepSlot.validWithEmptyMetadata =>
        GeneratedRecommendationDraft(title: 'Generated clean step $index'),
      GeneratedRecommendationStepSlot.validWithWhitespaceMetadata =>
        GeneratedRecommendationDraft(title: 'Generated trimmed step $index'),
      GeneratedRecommendationStepSlot.blankTitle ||
      GeneratedRecommendationStepSlot.missingTitle ||
      GeneratedRecommendationStepSlot.nonStringTitle ||
      GeneratedRecommendationStepSlot.nonMap => null,
    };
  }

  AgentDomainEntity hExistingEntity(
    int index,
    GeneratedRecommendationExistingSlot slot,
  ) {
    return switch (slot) {
      GeneratedRecommendationExistingSlot.activeSameProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          title: 'Existing active $index',
        ),
      GeneratedRecommendationExistingSlot.activeOtherProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'other-project',
          title: 'Other active $index',
        ),
      GeneratedRecommendationExistingSlot.dismissedSameProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.dismissed,
          title: 'Dismissed $index',
        ),
      GeneratedRecommendationExistingSlot.resolvedSameProject =>
        makeTestProjectRecommendation(
          id: 'generated-existing-$index',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.resolved,
          title: 'Resolved $index',
        ),
      GeneratedRecommendationExistingSlot.wrongType => makeTestState(
        id: 'generated-state-$index',
        agentId: 'generated-agent',
      ),
    };
  }

  @override
  String toString() {
    return 'GeneratedRecommendationRecordScenario('
        'rawStepsSlot: $rawStepsSlot, stepSlots: $stepSlots, '
        'existingSlots: $existingSlots)';
  }
}

class GeneratedRecommendationTransitionScenario {
  const GeneratedRecommendationTransitionScenario({
    required this.lookupSlot,
    required this.operation,
  });

  final GeneratedRecommendationLookupSlot lookupSlot;
  final GeneratedRecommendationTransitionOperation operation;

  AgentDomainEntity? get lookupEntity {
    return switch (lookupSlot) {
      GeneratedRecommendationLookupSlot.missing => null,
      GeneratedRecommendationLookupSlot.wrongType => makeTestState(
        id: 'generated-rec',
        agentId: 'generated-agent',
      ),
      GeneratedRecommendationLookupSlot.active => makeTestProjectRecommendation(
        id: 'generated-rec',
        agentId: 'generated-agent',
        projectId: 'generated-project',
      ),
      GeneratedRecommendationLookupSlot.resolved =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.resolved,
          resolvedAt: DateTime(2026, 5, 20),
        ),
      GeneratedRecommendationLookupSlot.dismissed =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.dismissed,
          dismissedAt: DateTime(2026, 5, 20),
        ),
      GeneratedRecommendationLookupSlot.superseded =>
        makeTestProjectRecommendation(
          id: 'generated-rec',
          agentId: 'generated-agent',
          projectId: 'generated-project',
          status: ProjectRecommendationStatus.superseded,
          supersededAt: DateTime(2026, 5, 20),
        ),
    };
  }

  bool get expectsTransition =>
      lookupSlot == GeneratedRecommendationLookupSlot.active;

  ProjectRecommendationStatus get expectedStatus {
    return switch (operation) {
      GeneratedRecommendationTransitionOperation.resolve =>
        ProjectRecommendationStatus.resolved,
      GeneratedRecommendationTransitionOperation.dismiss =>
        ProjectRecommendationStatus.dismissed,
    };
  }

  Future<bool> run(ProjectRecommendationService service) {
    return switch (operation) {
      GeneratedRecommendationTransitionOperation.resolve =>
        service.markResolved('generated-rec'),
      GeneratedRecommendationTransitionOperation.dismiss =>
        service.dismissRecommendation('generated-rec'),
    };
  }

  @override
  String toString() {
    return 'GeneratedRecommendationTransitionScenario('
        'lookupSlot: $lookupSlot, operation: $operation)';
  }
}

extension AnyGeneratedProjectRecommendationScenario on glados.Any {
  glados.Generator<GeneratedRecommendationRawStepsSlot>
  get recommendationRawStepsSlot =>
      glados.AnyUtils(this).choose(GeneratedRecommendationRawStepsSlot.values);

  glados.Generator<GeneratedRecommendationStepSlot>
  get recommendationStepSlot =>
      glados.AnyUtils(this).choose(GeneratedRecommendationStepSlot.values);

  glados.Generator<GeneratedRecommendationExistingSlot>
  get recommendationExistingSlot =>
      glados.AnyUtils(this).choose(GeneratedRecommendationExistingSlot.values);

  glados.Generator<GeneratedRecommendationLookupSlot>
  get recommendationLookupSlot =>
      glados.AnyUtils(this).choose(GeneratedRecommendationLookupSlot.values);

  glados.Generator<GeneratedRecommendationTransitionOperation>
  get recommendationTransitionOperation => glados.AnyUtils(
    this,
  ).choose(GeneratedRecommendationTransitionOperation.values);

  glados.Generator<GeneratedRecommendationRecordScenario>
  get recommendationRecordScenario => glados.CombinableAny(this).combine3(
    recommendationRawStepsSlot,
    glados.ListAnys(this).listWithLengthInRange(0, 7, recommendationStepSlot),
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 5, recommendationExistingSlot),
    (
      GeneratedRecommendationRawStepsSlot rawStepsSlot,
      List<GeneratedRecommendationStepSlot> stepSlots,
      List<GeneratedRecommendationExistingSlot> existingSlots,
    ) => GeneratedRecommendationRecordScenario(
      rawStepsSlot: rawStepsSlot,
      stepSlots: stepSlots,
      existingSlots: existingSlots,
    ),
  );

  glados.Generator<GeneratedRecommendationTransitionScenario>
  get recommendationTransitionScenario => glados.CombinableAny(this).combine2(
    recommendationLookupSlot,
    recommendationTransitionOperation,
    (
      GeneratedRecommendationLookupSlot lookupSlot,
      GeneratedRecommendationTransitionOperation operation,
    ) => GeneratedRecommendationTransitionScenario(
      lookupSlot: lookupSlot,
      operation: operation,
    ),
  );
}
