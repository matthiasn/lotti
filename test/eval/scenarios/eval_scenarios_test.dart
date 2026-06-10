import 'package:flutter_test/flutter_test.dart';

import '../harness/eval_harness.dart';
import 'eval_scenarios.dart';

void main() {
  test('catalog exposes unique scenario ids across both agents', () {
    final ids = [for (final scenario in allEvalScenarios) scenario.id];

    expect(ids.toSet(), hasLength(ids.length));
    expect(planningEvalScenarios, hasLength(6));
    expect(taskEvalScenarios, hasLength(9));
    expect(
      allEvalScenarios.every(
        (scenario) => scenario.userInput.triggerTokens.isNotEmpty,
      ),
      isTrue,
      reason: 'runner needs concrete wake trigger tokens for every scenario',
    );
    expect(
      allEvalScenarios.every(
        (scenario) => scenario.metadata.capabilityIds.isNotEmpty,
      ),
      isTrue,
      reason: 'reporting by capability needs every scenario classified',
    );
    expect(
      allEvalScenarios
          .where((scenario) => scenario.metadata.isAdversarial)
          .every(
            (scenario) =>
                scenario.metadata.source == EvalScenarioSource.adversarial ||
                scenario.metadata.tags.contains('adversarial'),
          ),
      isTrue,
      reason: 'adversarial scenarios need an auditable source/tag',
    );
  });

  test('public adversarial scenarios cover the readiness stress taxonomy', () {
    final adversarial = allEvalScenarios
        .where((scenario) => scenario.metadata.isAdversarial)
        .toList();
    final tags = {
      for (final scenario in adversarial) ...scenario.metadata.tags,
    };

    expect(
      adversarial.where(
        (scenario) => scenario.agentKind == AgentKind.taskAgent,
      ),
      isNotEmpty,
    );
    expect(
      adversarial.where(
        (scenario) => scenario.agentKind == AgentKind.planningAgent,
      ),
      isNotEmpty,
    );
    expect(tags, containsAll(kDefaultAdversarialStressTags));
    expect(
      adversarial.every(
        (scenario) => scenario.metadata.tags
            .intersection(kDefaultAdversarialStressTags)
            .isNotEmpty,
      ),
      isTrue,
      reason:
          'public adversarial cases must map to at least one tuning stress tag',
    );
    expect(
      adversarial.every((scenario) {
        final review = scenario.metadata.review;
        return review != null &&
            {
              EvalScenarioReviewStatus.reviewed,
              EvalScenarioReviewStatus.adjudicated,
            }.contains(review.status) &&
            review.subjectDigest ==
                EvalProvenance.scenarioReviewSubjectDigest(scenario);
      }),
      isTrue,
      reason: 'public adversarial cases must carry completed review metadata',
    );
  });

  test('public adversarial workflow scenarios have durable oracles', () {
    final workflowAdversarial = allEvalScenarios.where(
      (scenario) =>
          scenario.metadata.isAdversarial &&
          scenario.metadata.tags.contains('workflow'),
    );

    expect(workflowAdversarial, isNotEmpty);
    expect(
      workflowAdversarial.every(
        (scenario) => !scenario.expectations.durableState.isEmpty,
      ),
      isTrue,
      reason:
          'workflow adversarial cases need committed durable-state oracles so '
          'Level 2 live runs see the same hard checks as scripted tests',
    );
  });

  test('synthetic adversarial scenarios require source provenance', () {
    final syntheticAdversarial = allEvalScenarios.where(
      (scenario) =>
          scenario.metadata.isAdversarial &&
          scenario.metadata.source == EvalScenarioSource.synthetic,
    );

    expect(
      syntheticAdversarial.every((scenario) {
        final review = scenario.metadata.review;
        final sourceDigest = review?.sourceDigest;
        return review != null &&
            sourceDigest != null &&
            EvalProvenance.isDigest(sourceDigest) &&
            ((review.sourceLabel?.trim().isNotEmpty ?? false) ||
                (review.generator?.trim().isNotEmpty ?? false)) &&
            review.subjectDigest ==
                EvalProvenance.scenarioReviewSubjectDigest(scenario);
      }),
      isTrue,
      reason:
          'synthetic adversarial evidence needs review source provenance before '
          'it can count toward tuning-readiness gates',
    );
  });

  test(
    'catalog scenarios round-trip through JSON without app entity types',
    () {
      for (final scenario in allEvalScenarios) {
        final roundTripped = EvalScenario.fromJson(scenario.toJson());

        expect(roundTripped.id, scenario.id);
        expect(roundTripped.agentKind, scenario.agentKind);
        expect(
          roundTripped.metadata.capabilityIds,
          scenario.metadata.capabilityIds,
        );
        expect(roundTripped.metadata.split, scenario.metadata.split);
        expect(roundTripped.metadata.source, scenario.metadata.source);
        expect(
          roundTripped.metadata.isAdversarial,
          scenario.metadata.isAdversarial,
        );
        expect(roundTripped.metadata.tags, scenario.metadata.tags);
        expect(
          roundTripped.metadata.review?.toJson(),
          scenario.metadata.review?.toJson(),
        );
        expect(
          roundTripped.expectations.toJson(),
          scenario.expectations.toJson(),
        );
        expect(
          roundTripped.userInput.transcript,
          scenario.userInput.transcript,
        );
        expect(
          roundTripped.appState.knownTaskIds,
          scenario.appState.knownTaskIds,
        );
        expect(
          roundTripped.appState.allowedCategoryIds,
          scenario.appState.allowedCategoryIds,
        );
        expect(
          roundTripped.appState.categories.map((category) {
            return (
              category.id,
              category.name,
              category.correctionExamples
                  .map(
                    (example) =>
                        '${example.before}|${example.after}|${example.capturedAt?.toIso8601String()}',
                  )
                  .join('\n'),
            );
          }),
          scenario.appState.categories.map((category) {
            return (
              category.id,
              category.name,
              category.correctionExamples
                  .map(
                    (example) =>
                        '${example.before}|${example.after}|${example.capturedAt?.toIso8601String()}',
                  )
                  .join('\n'),
            );
          }),
        );
        expect(
          roundTripped.appState.labels.map((label) {
            return (
              label.id,
              label.name,
              label.applicableCategoryIds?.join(','),
              label.deletedAt,
            );
          }),
          scenario.appState.labels.map((label) {
            return (
              label.id,
              label.name,
              label.applicableCategoryIds?.join(','),
              label.deletedAt,
            );
          }),
        );
        expect(
          roundTripped.appState.tasks.map((task) {
            return (
              task.id,
              task.labelIds.join(','),
              (task.aiSuppressedLabelIds.toList()..sort()).join(','),
            );
          }),
          scenario.appState.tasks.map((task) {
            return (
              task.id,
              task.labelIds.join(','),
              (task.aiSuppressedLabelIds.toList()..sort()).join(','),
            );
          }),
        );
        expect(
          roundTripped.appState.captures.map((capture) {
            return (
              capture.id,
              capture.dayId,
              capture.transcript,
              capture.parsedItems
                  .map(
                    (item) =>
                        '${item.id}|${item.kind}|${item.confidence}|'
                        '${item.title}|${item.matchedTaskId}|'
                        '${item.estimateMinutes}|${item.timeAnchor}',
                  )
                  .join('\n'),
            );
          }),
          scenario.appState.captures.map((capture) {
            return (
              capture.id,
              capture.dayId,
              capture.transcript,
              capture.parsedItems
                  .map(
                    (item) =>
                        '${item.id}|${item.kind}|${item.confidence}|'
                        '${item.title}|${item.matchedTaskId}|'
                        '${item.estimateMinutes}|${item.timeAnchor}',
                  )
                  .join('\n'),
            );
          }),
        );
        expect(
          roundTripped.appState.existingBlocks.map((block) {
            return (
              block.id,
              block.categoryId,
              block.taskId,
              block.title,
              block.type,
              block.state,
              block.reason,
              block.note,
            );
          }),
          scenario.appState.existingBlocks.map((block) {
            return (
              block.id,
              block.categoryId,
              block.taskId,
              block.title,
              block.type,
              block.state,
              block.reason,
              block.note,
            );
          }),
        );
        expect(
          roundTripped.appState.proposalSets.map((set) => set.id),
          scenario.appState.proposalSets.map((set) => set.id),
        );
        expect(
          roundTripped.appState.proposalDecisions.map((decision) {
            return (decision.id, decision.verdict, decision.args);
          }),
          scenario.appState.proposalDecisions.map((decision) {
            return (decision.id, decision.verdict, decision.args);
          }),
        );
      }
    },
  );
}
