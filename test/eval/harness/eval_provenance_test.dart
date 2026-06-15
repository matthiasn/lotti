import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';

void main() {
  test('scenario and profile set digests are order independent', () {
    final scenarios = [
      taskReleaseNotesScenario,
      plannerMorningCapacityScenario,
    ];
    const profiles = [kFrontierFastProfile, kLocalSmallProfile];

    expect(
      EvalProvenance.scenarioSetDigest(scenarios),
      EvalProvenance.scenarioSetDigest(scenarios.reversed.toList()),
    );
    expect(
      EvalProvenance.profileSetDigest(profiles),
      EvalProvenance.profileSetDigest(profiles.reversed.toList()),
    );
  });

  test('manifest digest excludes the manifestDigest field itself', () {
    final manifest = _manifest();
    final digest = EvalProvenance.manifestDigest(manifest);

    expect(manifest.manifestDigest, digest);
    expect(
      EvalProvenance.manifestDigest(
        manifest.withManifestDigest(
          'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        ),
      ),
      digest,
    );
  });

  test('manifest env provenance records presence without secret values', () {
    final manifest = EvalProvenance.captureRunManifest(
      runId: 'run-secret',
      targetName: 'provenance-test',
      targetKind: 'test',
      scenarios: [taskReleaseNotesScenario],
      profiles: [kFrontierFastProfile],
      createdAt: DateTime(2026, 6, 10, 12),
      command:
          'LOTTI_EVAL_LIVE=1 OPENAI_API_KEY=secret-value '
          '--dart-define=EVAL_SCENARIOS=/private/path/protected_scenarios.json '
          '--dart-define=EVAL_PROFILES=/private/path/profiles.json '
          '--dart-define=EVAL_PROMOTION_PLAN=/private/path/promotion_plan.json '
          '--dart-define=EVAL_USE_CASE_RUN_WORK_ORDER=/private/path/work_order.json '
          'run',
      environment: const {
        'LOTTI_EVAL_LIVE': '1',
        'OPENAI_API_KEY': 'secret-value',
        'EVAL_SCENARIOS': '/private/path/protected_scenarios.json',
        'EVAL_SCENARIOS_MODE': 'replace',
        'EVAL_SCENARIO_IDS': 'private_task_holdout',
        'EVAL_PROFILES': '/private/path/profiles.json',
        'EVAL_PROFILE_NAMES': 'frontier-gemini',
        'EVAL_PROMOTION_PLAN': '/private/path/promotion_plan.json',
        'EVAL_USE_CASE_RUN_WORK_ORDER': '/private/path/work_order.json',
      },
    );
    final json = jsonEncode(manifest.toJson());

    expect(manifest.envPresence['LOTTI_EVAL_LIVE'], isTrue);
    expect(manifest.envPresence['OPENAI_API_KEY'], isTrue);
    expect(manifest.envPresence['EVAL_SCENARIOS'], isTrue);
    expect(manifest.envPresence['EVAL_SCENARIOS_MODE'], isTrue);
    expect(manifest.envPresence['EVAL_SCENARIO_IDS'], isTrue);
    expect(manifest.envPresence['EVAL_PROFILES'], isTrue);
    expect(manifest.envPresence['EVAL_PROFILE_NAMES'], isTrue);
    expect(manifest.envPresence['EVAL_PROMOTION_PLAN'], isTrue);
    expect(manifest.envPresence['EVAL_USE_CASE_RUN_WORK_ORDER'], isTrue);
    expect(json, isNot(contains('secret-value')));
    expect(json, isNot(contains('/private/path/protected_scenarios.json')));
    expect(json, isNot(contains('/private/path/profiles.json')));
    expect(json, isNot(contains('/private/path/promotion_plan.json')));
    expect(json, isNot(contains('/private/path/work_order.json')));
    expect(manifest.command, contains('OPENAI_API_KEY=<redacted>'));
    expect(manifest.command, contains('EVAL_SCENARIOS=<redacted>'));
    expect(manifest.command, contains('EVAL_PROFILES=<redacted>'));
    expect(manifest.command, contains('EVAL_PROMOTION_PLAN=<redacted>'));
    expect(
      manifest.command,
      contains('EVAL_USE_CASE_RUN_WORK_ORDER=<redacted>'),
    );
  });

  test('manifest records non-secret scenario catalog evidence', () {
    final evidence = EvalScenarioCatalogEvidence(
      scenarioSetDigest: EvalProvenance.scenarioSetDigest(
        [taskReleaseNotesScenario],
      ),
      publicScenarioCount: 1,
      externalScenarioCount: 1,
      externalCatalogDigest: EvalProvenance.digestText('private-catalog'),
      externalCatalogId: 'private-production-replay-v1',
      externalSourceLabel: 'protected_scenarios.json',
      protectedHoldout: true,
      protectedScenarioIds: const ['task_release_notes'],
      protectedHoldoutScenarioIds: const ['task_release_notes'],
    );

    final manifest = EvalProvenance.captureRunManifest(
      runId: 'run-catalog',
      targetName: 'provenance-test',
      targetKind: 'live',
      scenarios: [taskReleaseNotesScenario],
      profiles: [kFrontierFastProfile],
      scenarioCatalogEvidence: evidence,
      createdAt: DateTime(2026, 6, 10, 12),
      command: 'provenance-test',
      environment: const <String, String>{},
    );

    expect(
      manifest.scenarioCatalogEvidence?.toJson(),
      evidence.toJson(),
    );
    expect(manifest.manifestDigest, EvalProvenance.manifestDigest(manifest));
    expect(
      jsonEncode(manifest.toJson()),
      contains('private-production-replay-v1'),
    );
  });

  test('promotion plan subject digest ignores only display-only fields', () {
    final scenarioSetDigest = EvalProvenance.scenarioSetDigest([
      taskReleaseNotesScenario,
    ]);
    const profiles = [kFrontierFastProfile, kLocalSmallProfile];
    final profileSetDigest = EvalProvenance.profileSetDigest(profiles);
    final policyDigest = EvalProvenance.digestText('promotion-policy');
    final draftPlan = EvalPromotionPlan(
      planId: 'frontier-fast-vs-local-small',
      candidateProfileName: kFrontierFastProfile.name,
      baselineProfileName: kLocalSmallProfile.name,
      scenarioSetDigest: scenarioSetDigest,
      profileSetDigest: profileSetDigest,
      policyDigest: policyDigest,
      createdAt: '2026-06-10T00:00:00Z',
      notes: 'display-only rationale',
    );
    final finalizedPlan = EvalPromotionPlan(
      planId: draftPlan.planId,
      candidateProfileName: draftPlan.candidateProfileName,
      baselineProfileName: draftPlan.baselineProfileName,
      scenarioSetDigest: draftPlan.scenarioSetDigest,
      profileSetDigest: draftPlan.profileSetDigest,
      policyDigest: draftPlan.policyDigest,
      manifestDigest: EvalProvenance.digestText('manifest'),
      createdAt: '2026-06-11T00:00:00Z',
      notes: 'updated display-only rationale',
    );
    final changedCandidatePlan = EvalPromotionPlan(
      planId: draftPlan.planId,
      candidateProfileName: kLocalSmallProfile.name,
      baselineProfileName: draftPlan.baselineProfileName,
      scenarioSetDigest: draftPlan.scenarioSetDigest,
      profileSetDigest: draftPlan.profileSetDigest,
      policyDigest: draftPlan.policyDigest,
    );

    expect(
      EvalProvenance.promotionPlanSubjectDigest(finalizedPlan),
      EvalProvenance.promotionPlanSubjectDigest(draftPlan),
    );
    expect(
      EvalProvenance.promotionPlanSubjectDigest(changedCandidatePlan),
      isNot(EvalProvenance.promotionPlanSubjectDigest(draftPlan)),
    );
  });

  test('scenario review subject digest ignores only review metadata', () {
    final base = taskWorkflowReportRecoveryScenario;
    final subjectDigest = EvalProvenance.scenarioReviewSubjectDigest(base);
    final reviewJson = base.toJson();
    final metadata = <String, dynamic>{
      ...(reviewJson['metadata'] as Map<String, dynamic>),
      'review': EvalScenarioReview(
        status: EvalScenarioReviewStatus.reviewed,
        reviewer: 'another-reviewer',
        reviewedAt: '2026-06-11T12:00:00.000Z',
        subjectDigest: subjectDigest,
        rationale: 'Changing review metadata must not change the subject.',
      ).toJson(),
    };
    reviewJson['metadata'] = metadata;
    final reviewChanged = EvalScenario.fromJson(reviewJson);
    final scenarioChangedJson = base.toJson()
      ..['title'] = 'Changed scenario title';
    final scenarioChanged = EvalScenario.fromJson(scenarioChangedJson);

    expect(
      EvalProvenance.scenarioReviewSubjectDigest(reviewChanged),
      subjectDigest,
    );
    expect(
      EvalProvenance.scenarioReviewSubjectDigest(scenarioChanged),
      isNot(subjectDigest),
    );
  });
}

EvalRunManifest _manifest() => EvalProvenance.captureRunManifest(
  runId: 'run-1',
  targetName: 'provenance-test',
  targetKind: 'test',
  scenarios: [taskReleaseNotesScenario],
  profiles: [kFrontierFastProfile],
  createdAt: DateTime(2026, 6, 10, 12),
  command: 'provenance-test',
  environment: const <String, String>{},
);
