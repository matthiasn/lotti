// Level 2 report/verify entrypoint.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:path/path.dart' as p;

import '../harness/eval_harness.dart';
import '../harness/eval_profile_config.dart';
import 'eval_scenario_catalog.dart';
import 'eval_scenarios.dart';

const _runId = String.fromEnvironment('EVAL_RUN');
const _calibrationPath = String.fromEnvironment('EVAL_CALIBRATION');
const _calibrationTemplatePath = String.fromEnvironment(
  'EVAL_CALIBRATION_TEMPLATE',
);
const _calibrationTemplateVersion = String.fromEnvironment(
  'EVAL_CALIBRATION_VERSION',
  defaultValue: 'human-gold-v1',
);
const _calibrationTemplateOverwrite = String.fromEnvironment(
  'EVAL_CALIBRATION_TEMPLATE_OVERWRITE',
);
const _calibrationTemplateMaxRows = String.fromEnvironment(
  'EVAL_CALIBRATION_TEMPLATE_MAX_ROWS',
);
const _promotionCandidateProfile = String.fromEnvironment(
  'EVAL_PROMOTION_CANDIDATE_PROFILE',
);
const _promotionBaselineProfile = String.fromEnvironment(
  'EVAL_PROMOTION_BASELINE_PROFILE',
);
const _promotionPlanPath = String.fromEnvironment('EVAL_PROMOTION_PLAN');
const _protectedTraceAck = String.fromEnvironment(
  'LOTTI_EVAL_PROTECTED_TRACE_ACK',
);
const _scenarioCatalogPath = String.fromEnvironment(
  kEvalScenarioCatalogPathEnv,
);
const _scenarioCatalogMode = String.fromEnvironment(
  kEvalScenarioCatalogModeEnv,
);
const _scenarioIds = String.fromEnvironment(kEvalScenarioIdsEnv);
const _profileCatalogValue = String.fromEnvironment(kEvalProfilesPathEnv);
const _profileNames = String.fromEnvironment(kEvalProfileNamesEnv);
const _runsRootPath = String.fromEnvironment('EVAL_RUNS_ROOT');

void main() {
  test(
    'verifies complete trace/verdict matrix for an eval run',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );
    },
    tags: 'eval-report',
    skip: _runId.isEmpty
        ? 'Set EVAL_RUN=<runId> to verify an eval run.'
        : false,
  );

  test(
    'renders eval run summary',
    () async {
      final run = await TraceWriter(runsRoot: _runsRoot()).readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      expect(run.traces, isNotEmpty, reason: 'EVAL_RUN=$_runId has no traces');
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );
      final calibrationSet = await _readCalibrationSet(
        run: run,
        catalog: catalog,
      );
      final calibrationReport = calibrationSet == null
          ? null
          : EvalJudgeCalibration.evaluate(
              traces: run.traces,
              calibrationSet: calibrationSet,
            );
      final readiness = EvalTuningReadiness.assess(
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: run.manifest,
        scenarioCatalogEvidence: catalog.evidence,
        policy: const EvalTuningPolicy.modelClassTuning(),
        calibrationSet: calibrationSet,
      );
      // ignore: avoid_print
      print(EvalTuningReadiness.render(readiness));
      if (calibrationReport != null) {
        // ignore: avoid_print
        print(EvalJudgeCalibration.render(calibrationReport));
      }
      final promotionDecision = _profilePromotionDecisionFromConfig(
        traces: run.traces,
        readinessReport: readiness,
        manifest: run.manifest,
      );
      final promotionReport = promotionDecision == null
          ? null
          : EvalReporter.renderProfilePromotion(promotionDecision);
      if (promotionReport != null) {
        // ignore: avoid_print
        print(promotionReport);
      }
      // ignore: avoid_print
      print(
        EvalReporter.render(
          run.traces,
          context: EvalReportContext(
            scenarios: catalog.scenarios,
            profiles: profiles,
            manifest: run.manifest,
          ),
        ),
      );
      if (promotionDecision != null && _promotionPlanPath.trim().isNotEmpty) {
        expect(
          promotionDecision.status,
          ProfilePromotionStatus.promote,
          reason: promotionReport,
        );
      }
    },
    tags: 'eval-report',
    skip: _runId.isEmpty
        ? 'Set EVAL_RUN=<runId> to report an eval run.'
        : false,
  );

  test(
    'renders scenario catalog preflight',
    () {
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final catalogPath = _scenarioCatalogPathValue();
      if (catalogPath != null) {
        _guardScenarioCatalogPreflightInput(
          evidence: catalog.evidence,
          file: File(catalogPath),
        );
      }
      final report = EvalTuningReadiness.assessScenarioCatalog(
        scenarios: catalog.scenarios,
        profiles: profiles,
        scenarioCatalogEvidence: catalog.evidence,
      );
      final rendered = EvalTuningReadiness.renderScenarioCatalogPreflight(
        report,
      );
      // ignore: avoid_print
      print(rendered);
      expect(report.ready, isTrue, reason: rendered);
    },
    tags: 'eval-report',
    skip: _hasExternalScenarioCatalog()
        ? false
        : 'Set EVAL_SCENARIOS=<json> to preflight a private catalog.',
  );

  test(
    'writes judge calibration label template',
    () async {
      final run = await TraceWriter(runsRoot: _runsRoot()).readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );

      final template = EvalJudgeCalibration.labelTemplateJson(
        version: _calibrationTemplateVersion,
        traces: run.traces,
        manifest: run.manifest,
        maxRows: _calibrationTemplateMaxRowsValue(),
      );
      final file = File(_calibrationTemplatePath);
      _guardCalibrationTemplatePath(file);
      _guardCalibrationTemplateOutput(
        manifestEvidence: run.manifest.scenarioCatalogEvidence,
        loadedEvidence: catalog.evidence,
        file: file,
      );
      if (file.existsSync() && _calibrationTemplateOverwrite != '1') {
        throw StateError(
          'Refusing to overwrite existing calibration template: '
          '${file.path}. Set EVAL_CALIBRATION_TEMPLATE_OVERWRITE=1.',
        );
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(template),
      );
      // ignore: avoid_print
      print('Wrote judge calibration label template: ${file.path}');
    },
    tags: 'eval-report',
    skip: _runId.isEmpty || _calibrationTemplatePath.isEmpty
        ? 'Set EVAL_RUN=<runId> and EVAL_CALIBRATION_TEMPLATE=<json> '
              'to write a human-label template.'
        : false,
  );

  test(
    'calibration template path must not look like a completed label file',
    () {
      expect(
        () => _guardCalibrationTemplatePath(
          File('eval/calibration/judge_gold_v1.json'),
        ),
        throwsStateError,
      );
      expect(
        () => _guardCalibrationTemplatePath(
          File('eval/calibration/judge_gold_v1.template.json'),
        ),
        returnsNormally,
      );
    },
  );

  test('calibration template max row config validates positive integers', () {
    expect(_calibrationTemplateMaxRowsValue(value: '   '), isNull);
    expect(_calibrationTemplateMaxRowsValue(value: '12'), 12);
    expect(
      () => _calibrationTemplateMaxRowsValue(value: '0'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('EVAL_CALIBRATION_TEMPLATE_MAX_ROWS must be a positive'),
        ),
      ),
    );
    expect(
      () => _calibrationTemplateMaxRowsValue(value: 'twelve'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('EVAL_CALIBRATION_TEMPLATE_MAX_ROWS must be a positive'),
        ),
      ),
    );
  });

  test('external calibration templates inside repo require ack', () {
    final evidence = EvalScenarioCatalogEvidence(
      scenarioSetDigest: EvalProvenance.digestText('external-scenarios'),
      publicScenarioCount: 0,
      externalScenarioCount: 1,
      externalCatalogDigest: EvalProvenance.digestText('external-catalog'),
      externalCatalogId: 'private-production-replay-v1',
      externalSourceLabel: 'private_scenarios.json',
      protectedHoldout: false,
      protectedScenarioIds: const [],
      protectedHoldoutScenarioIds: const [],
    );
    final file = File('eval/calibration/judge_gold_v1.template.json');

    expect(
      () => _guardCalibrationTemplateOutput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        file: file,
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardCalibrationTemplateOutput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        file: file,
        protectedTraceAck: '1',
      ),
      returnsNormally,
    );
  });

  test('external completed calibration files inside repo require ack', () {
    final evidence = EvalScenarioCatalogEvidence(
      scenarioSetDigest: EvalProvenance.digestText('external-scenarios'),
      publicScenarioCount: 0,
      externalScenarioCount: 1,
      externalCatalogDigest: EvalProvenance.digestText('external-catalog'),
      externalCatalogId: 'private-production-replay-v1',
      externalSourceLabel: 'private_scenarios.json',
      protectedHoldout: false,
      protectedScenarioIds: const [],
      protectedHoldoutScenarioIds: const [],
    );
    final file = File('eval/calibration/judge_gold_v1.json');

    expect(
      () => _guardCalibrationFileInput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        file: file,
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardCalibrationFileInput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        file: file,
        protectedTraceAck: '1',
      ),
      returnsNormally,
    );
  });

  test('protected catalog preflight input inside repo is rejected', () {
    final evidence = EvalScenarioCatalogEvidence(
      scenarioSetDigest: EvalProvenance.digestText('external-scenarios'),
      publicScenarioCount: 0,
      externalScenarioCount: 1,
      externalCatalogDigest: EvalProvenance.digestText('external-catalog'),
      externalCatalogId: 'private-production-replay-v1',
      externalSourceLabel: 'private_scenarios.json',
      protectedHoldout: true,
      protectedScenarioIds: const ['private_task_holdout'],
      protectedHoldoutScenarioIds: const ['private_task_holdout'],
    );

    expect(
      () => _guardScenarioCatalogPreflightInput(
        evidence: evidence,
        file: File('eval/private_scenarios.json'),
      ),
      throwsStateError,
    );
  });

  test('profile promotion config is optional but must be paired', () {
    expect(
      _profilePromotionPolicyFromConfig(),
      isNull,
    );
    expect(
      () => _profilePromotionPolicyFromConfig(
        candidateProfileName: 'frontier-gemini',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Set both EVAL_PROMOTION_CANDIDATE_PROFILE and '
            'EVAL_PROMOTION_BASELINE_PROFILE, or neither.',
          ),
        ),
      ),
    );
    expect(
      () => _profilePromotionPolicyFromConfig(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-gemini',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('must differ'),
        ),
      ),
    );
  });

  test('profile promotion config validates profile names', () {
    expect(
      () => _profilePromotionPolicyFromConfig(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
      ),
      returnsNormally,
    );
    expect(
      () => _profilePromotionPolicyFromConfig(
        candidateProfileName: 'gpt-5-mini',
        baselineProfileName: 'frontier-fast',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('Unknown promotion candidate profile "gpt-5-mini"'),
            contains(
              'Available profiles: frontier-fast, frontier-gemini, '
              'local-ollama, local-small',
            ),
          ),
        ),
      ),
    );
  });

  test('profile promotion config validates trace profiles', () {
    final traces = [
      _promotionTraceForProfile(kFrontierFastProfile),
    ];

    expect(
      () => _profilePromotionPolicyFromConfig(
        traces: traces,
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Promotion candidate profile "frontier-gemini" is not present '
            'in run traces.',
          ),
        ),
      ),
    );
  });

  test('profile promotion plan supplies profiles and validates digests', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
      ),
    );
    final traces = [
      _promotionTraceForProfile(kFrontierProfile),
      _promotionTraceForProfile(kFrontierFastProfile),
    ];

    final policy = _profilePromotionPolicyFromConfig(
      traces: traces,
      manifest: manifest,
      promotionPlanPath: planFile.path,
    );

    expect(policy, isNotNull);
    expect(policy!.candidateProfileName, 'frontier-gemini');
    expect(policy.baselineProfileName, 'frontier-fast');

    final matchingPolicy = _profilePromotionPolicyFromConfig(
      traces: traces,
      manifest: manifest,
      promotionPlanPath: planFile.path,
      candidateProfileName: 'frontier-gemini',
      baselineProfileName: 'frontier-fast',
    );
    expect(matchingPolicy?.candidateProfileName, 'frontier-gemini');
  });

  test('profile promotion plan rejects direct env mismatches', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
        candidateProfileName: 'local-small',
        baselineProfileName: 'frontier-fast',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Promotion plan candidateProfileName "frontier-gemini" does not '
            'match EVAL_PROMOTION_CANDIDATE_PROFILE "local-small"',
          ),
        ),
      ),
    );
  });

  test('profile promotion plan rejects digest drift', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
        scenarioSetDigest: EvalProvenance.digestText('stale-scenarios'),
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan scenarioSetDigest'),
        ),
      ),
    );
  });

  test('profile promotion plan requires manifest digest', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
        includeManifestDigest: false,
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan manifestDigest is required'),
        ),
      ),
    );
  });

  test('profile promotion plan rejects manifest digest drift', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
        manifestDigest: EvalProvenance.digestText('stale-manifest'),
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan manifestDigest'),
        ),
      ),
    );
  });

  test('profile promotion plan requires run-manifest plan evidence', () {
    final manifest = _promotionManifest(includePromotionPlanEvidence: false);
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan was not recorded in the run manifest'),
        ),
      ),
    );
  });

  test('profile promotion plan rejects post-run subject changes', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'local-small',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan subject digest'),
        ),
      ),
    );
  });

  test('profile promotion plan rejects policy digest drift', () {
    final manifest = _promotionManifest();
    final planFile = _writePromotionPlan(
      _promotionPlanJson(
        candidateProfileName: 'frontier-gemini',
        baselineProfileName: 'frontier-fast',
        manifest: manifest,
        policyDigest: EvalProvenance.digestText('stale-policy'),
      ),
    );

    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        promotionPlanPath: planFile.path,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Promotion plan policyDigest'),
        ),
      ),
    );
  });

  test('profile promotion gate blocks when readiness is not ready', () {
    final traces = [
      _promotionTraceForProfile(kFrontierProfile),
      _promotionTraceForProfile(kFrontierFastProfile),
    ];
    final readiness = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      policy: const EvalTuningPolicy.modelClassTuning(),
    );

    final decision = _profilePromotionDecisionFromConfig(
      traces: traces,
      readinessReport: readiness,
      candidateProfileName: 'frontier-gemini',
      baselineProfileName: 'frontier-fast',
    );

    expect(decision, isNotNull);
    expect(decision!.status, ProfilePromotionStatus.blocked);
    expect(
      decision.failures,
      contains('promotion blocked: tuning readiness is not ready'),
    );
    expect(
      EvalReporter.renderProfilePromotion(decision),
      contains('policy: requireReady=true minPaired=12'),
    );
  });

  test(
    'renders judge calibration report',
    () async {
      final run = await TraceWriter(runsRoot: _runsRoot()).readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );
      final calibrationSet = await _readCalibrationSet(
        run: run,
        catalog: catalog,
        requireConfigured: true,
      );
      final report = EvalJudgeCalibration.evaluate(
        traces: run.traces,
        calibrationSet: calibrationSet!,
      );
      // ignore: avoid_print
      print(EvalJudgeCalibration.render(report));
    },
    tags: 'eval-report',
    skip: _runId.isEmpty || _calibrationPath.isEmpty
        ? 'Set EVAL_RUN=<runId> and EVAL_CALIBRATION=<json> to calibrate.'
        : false,
  );
}

ProfilePromotionDecision? _profilePromotionDecisionFromConfig({
  required List<EvalTrace> traces,
  required EvalTuningReadinessReport readinessReport,
  EvalRunManifest? manifest,
  String candidateProfileName = _promotionCandidateProfile,
  String baselineProfileName = _promotionBaselineProfile,
  String promotionPlanPath = _promotionPlanPath,
}) {
  final policy = _profilePromotionPolicyFromConfig(
    traces: traces,
    manifest: manifest,
    candidateProfileName: candidateProfileName,
    baselineProfileName: baselineProfileName,
    promotionPlanPath: promotionPlanPath,
  );
  if (policy == null) return null;
  return EvalReporter.evaluateProfilePromotion(
    traces: traces,
    policy: policy,
    readinessReport: readinessReport,
  );
}

ProfilePromotionPolicy? _profilePromotionPolicyFromConfig({
  List<EvalTrace> traces = const <EvalTrace>[],
  EvalRunManifest? manifest,
  String candidateProfileName = _promotionCandidateProfile,
  String baselineProfileName = _promotionBaselineProfile,
  String promotionPlanPath = _promotionPlanPath,
}) {
  var candidate = candidateProfileName.trim();
  var baseline = baselineProfileName.trim();
  final planPath = promotionPlanPath.trim();
  final plan = planPath.isEmpty ? null : _readPromotionPlan(File(planPath));
  if (plan == null && candidate.isEmpty && baseline.isEmpty) return null;
  if (candidate.isEmpty != baseline.isEmpty) {
    throw StateError(
      'Set both EVAL_PROMOTION_CANDIDATE_PROFILE and '
      'EVAL_PROMOTION_BASELINE_PROFILE, or neither.',
    );
  }
  if (plan != null) {
    if (candidate.isNotEmpty && candidate != plan.candidateProfileName) {
      throw StateError(
        'Promotion plan candidateProfileName "${plan.candidateProfileName}" '
        'does not match EVAL_PROMOTION_CANDIDATE_PROFILE "$candidate".',
      );
    }
    if (baseline.isNotEmpty && baseline != plan.baselineProfileName) {
      throw StateError(
        'Promotion plan baselineProfileName "${plan.baselineProfileName}" '
        'does not match EVAL_PROMOTION_BASELINE_PROFILE "$baseline".',
      );
    }
    candidate = plan.candidateProfileName;
    baseline = plan.baselineProfileName;
  }
  if (candidate == baseline) {
    throw StateError(
      'Promotion candidate and baseline profile names must differ: $candidate',
    );
  }
  _validateConfiguredProfile(
    role: 'candidate',
    profileName: candidate,
    traces: traces,
  );
  _validateConfiguredProfile(
    role: 'baseline',
    profileName: baseline,
    traces: traces,
  );
  final policy = ProfilePromotionPolicy(
    candidateProfileName: candidate,
    baselineProfileName: baseline,
  );
  if (plan != null) {
    _validatePromotionPlan(
      plan: plan,
      policy: policy,
      manifest: manifest,
    );
  }
  return policy;
}

EvalPromotionPlan _readPromotionPlan(File file) {
  if (!file.existsSync()) {
    throw StateError('Missing promotion plan: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Promotion plan JSON must be an object: ${file.path}');
  }
  try {
    return EvalPromotionPlan.fromJson(decoded);
  } on FormatException catch (error) {
    throw StateError('Invalid promotion plan ${file.path}: ${error.message}');
  }
}

void _validatePromotionPlan({
  required EvalPromotionPlan plan,
  required ProfilePromotionPolicy policy,
  required EvalRunManifest? manifest,
}) {
  if (manifest == null) {
    throw StateError(
      'EVAL_PROMOTION_PLAN requires a verified run manifest for digest checks.',
    );
  }
  if (plan.scenarioSetDigest != manifest.scenarioSetDigest) {
    throw StateError(
      'Promotion plan scenarioSetDigest "${plan.scenarioSetDigest}" does not '
      'match run manifest "${manifest.scenarioSetDigest}".',
    );
  }
  if (plan.profileSetDigest != manifest.profileSetDigest) {
    throw StateError(
      'Promotion plan profileSetDigest "${plan.profileSetDigest}" does not '
      'match run manifest "${manifest.profileSetDigest}".',
    );
  }
  final expectedPolicyDigest = _promotionPolicyDigest(policy);
  if (plan.policyDigest != expectedPolicyDigest) {
    throw StateError(
      'Promotion plan policyDigest "${plan.policyDigest}" does not match '
      'current policy "$expectedPolicyDigest".',
    );
  }
  final expectedManifestDigest = plan.manifestDigest;
  if (expectedManifestDigest == null) {
    throw StateError(
      'Promotion plan manifestDigest is required for assertion-gated '
      'promotion reports.',
    );
  }
  if (expectedManifestDigest != manifest.manifestDigest) {
    throw StateError(
      'Promotion plan manifestDigest "$expectedManifestDigest" does not match '
      'run manifest "${manifest.manifestDigest}".',
    );
  }
  final manifestPlanEvidence = manifest.promotionPlanEvidence;
  if (manifestPlanEvidence == null) {
    throw StateError(
      'Promotion plan was not recorded in the run manifest; pass '
      'EVAL_PROMOTION_PLAN during eval/run_level2.sh run before using it as '
      'an assertion gate.',
    );
  }
  final expectedSubjectDigest = EvalProvenance.promotionPlanSubjectDigest(plan);
  if (manifestPlanEvidence.promotionPlanSubjectDigest !=
      expectedSubjectDigest) {
    throw StateError(
      'Promotion plan subject digest "$expectedSubjectDigest" does not match '
      'run manifest evidence '
      '"${manifestPlanEvidence.promotionPlanSubjectDigest}".',
    );
  }
}

String _promotionPolicyDigest(ProfilePromotionPolicy policy) {
  return EvalProvenance.digestJson(EvalReporter.promotionPolicyJson(policy));
}

void _validateConfiguredProfile({
  required String role,
  required String profileName,
  required List<EvalTrace> traces,
}) {
  final configuredProfiles = _configuredProfileNames();
  if (!configuredProfiles.contains(profileName)) {
    throw StateError(
      'Unknown promotion $role profile "$profileName". '
      'Available profiles: ${configuredProfiles.join(', ')}',
    );
  }
  if (traces.isEmpty) return;
  final traceProfiles = _traceProfileNames(traces);
  if (!traceProfiles.contains(profileName)) {
    throw StateError(
      'Promotion $role profile "$profileName" is not present in run traces. '
      'Trace profiles: ${traceProfiles.join(', ')}',
    );
  }
}

List<String> _configuredProfileNames() {
  return [
    for (final profile in _loadProfiles()) profile.name,
  ]..sort();
}

List<String> _traceProfileNames(List<EvalTrace> traces) {
  return {
    for (final trace in traces) trace.profile.name,
  }.toList()..sort();
}

EvalTrace _promotionTraceForProfile(EvalProfile profile) {
  return EvalTrace(
    runId: 'promotion-config-test',
    scenario: taskReleaseNotesScenario,
    profile: profile,
    provenance: EvalProvenance.capture(
      scenario: taskReleaseNotesScenario,
      profile: profile,
    ),
    output: const AgentRunOutput(
      success: true,
      usage: InferenceUsage(inputTokens: 100, outputTokens: 50),
    ),
    level1Checks: const [
      EvalCheck(name: 'level1', passed: true),
    ],
  );
}

EvalRunManifest _promotionManifest({
  bool includePromotionPlanEvidence = true,
}) {
  final scenarioSetDigest = EvalProvenance.scenarioSetDigest([
    taskReleaseNotesScenario,
  ]);
  final profileSetDigest = EvalProvenance.profileSetDigest(kDefaultProfiles);
  final profileExecutionBindings = [
    for (final profile in kDefaultProfiles)
      evalProfileConfig(profile).toExecutionBinding(),
  ];
  const promotionPolicy = ProfilePromotionPolicy(
    candidateProfileName: 'frontier-gemini',
    baselineProfileName: 'frontier-fast',
  );
  final promotionPlan = EvalPromotionPlan(
    planId: 'promotion-plan-test',
    candidateProfileName: 'frontier-gemini',
    baselineProfileName: 'frontier-fast',
    scenarioSetDigest: scenarioSetDigest,
    profileSetDigest: profileSetDigest,
    policyDigest: _promotionPolicyDigest(promotionPolicy),
    createdAt: '2026-06-10T00:00:00Z',
    notes: 'test fixture',
  );
  final manifest = EvalRunManifest(
    runId: 'promotion-plan-test',
    traceSchemaVersion: EvalTrace.schemaVersion,
    targetName: 'test-target',
    targetKind: 'fixture',
    createdAt: DateTime.utc(2026, 6, 10),
    command: 'promotion plan test',
    scenarioSetDigest: scenarioSetDigest,
    profileSetDigest: profileSetDigest,
    profileBindingSetDigest: EvalProvenance.profileBindingSetDigest(
      profileExecutionBindings,
    ),
    profileExecutionBindings: profileExecutionBindings,
    promptDigest: EvalProvenance.digestText('prompt'),
    toolSchemaDigest: EvalProvenance.digestText('tool-schema'),
    codeRevision: 'test-revision',
    gitDirty: false,
    envPresence: const {},
    promotionPlanEvidence: includePromotionPlanEvidence
        ? EvalProvenance.promotionPlanEvidence(promotionPlan)
        : null,
  );
  return manifest.withManifestDigest(EvalProvenance.manifestDigest(manifest));
}

Map<String, dynamic> _promotionPlanJson({
  required String candidateProfileName,
  required String baselineProfileName,
  required EvalRunManifest manifest,
  String? scenarioSetDigest,
  String? profileSetDigest,
  String? policyDigest,
  String? manifestDigest,
  bool includeManifestDigest = true,
}) {
  final policy = ProfilePromotionPolicy(
    candidateProfileName: candidateProfileName,
    baselineProfileName: baselineProfileName,
  );
  final resolvedManifestDigest = includeManifestDigest
      ? manifestDigest ?? manifest.manifestDigest
      : manifestDigest;
  return <String, dynamic>{
    'schemaVersion': 1,
    'planId': 'promotion-plan-test',
    'createdAt': '2026-06-10T00:00:00Z',
    'candidateProfileName': candidateProfileName,
    'baselineProfileName': baselineProfileName,
    'scenarioSetDigest': scenarioSetDigest ?? manifest.scenarioSetDigest,
    'profileSetDigest': profileSetDigest ?? manifest.profileSetDigest,
    'policyDigest': policyDigest ?? _promotionPolicyDigest(policy),
    // ignore: use_null_aware_elements
    if (resolvedManifestDigest case final digest?) 'manifestDigest': digest,
    'notes': 'test fixture',
  };
}

File _writePromotionPlan(Map<String, dynamic> planJson) {
  final directory = Directory.systemTemp.createTempSync(
    'lotti_eval_promotion_plan_',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return File(p.join(directory.path, 'promotion_plan.json'))
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(planJson));
}

EvalScenarioCatalog _loadScenarioCatalog() {
  return EvalScenarioCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefinePath: _scenarioCatalogPathFromDefine(),
    dartDefineMode: _scenarioCatalogModeFromDefine(),
    dartDefineScenarioIds: _scenarioIdsFromDefine(),
  );
}

List<EvalProfile> _loadProfiles() {
  return EvalProfileCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: _profileCatalogValueFromDefine(),
    dartDefineProfileNames: _profileNamesFromDefine(),
  ).profiles;
}

String _scenarioCatalogPathFromDefine() => _scenarioCatalogPath;

String _scenarioCatalogModeFromDefine() => _scenarioCatalogMode;

String _scenarioIdsFromDefine() => _scenarioIds;

String _profileCatalogValueFromDefine() => _profileCatalogValue;

String _profileNamesFromDefine() => _profileNames;

bool _hasExternalScenarioCatalog() {
  return _scenarioCatalogPathValue() != null;
}

String? _scenarioCatalogPathValue() {
  final fromDefine = _scenarioCatalogPathFromDefine().trim();
  if (fromDefine.isNotEmpty) return fromDefine;
  final fromEnvironment = Platform.environment[kEvalScenarioCatalogPathEnv]
      ?.trim();
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  return null;
}

String _runsRoot() {
  final fromDefine = _runsRootPath.trim();
  if (fromDefine.isNotEmpty) return fromDefine;
  final fromEnvironment = Platform.environment['EVAL_RUNS_ROOT']?.trim();
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  return 'eval/runs';
}

Future<JudgeCalibrationSet?> _readCalibrationSet({
  required EvalRunArtifacts run,
  required EvalScenarioCatalog catalog,
  bool requireConfigured = false,
}) async {
  if (_calibrationPath.isEmpty) {
    if (requireConfigured) {
      throw StateError('Set EVAL_CALIBRATION=<json> to calibrate.');
    }
    return null;
  }
  final calibrationFile = File(_calibrationPath);
  _guardCalibrationFileInput(
    manifestEvidence: run.manifest.scenarioCatalogEvidence,
    loadedEvidence: catalog.evidence,
    file: calibrationFile,
  );
  final calibrationJson =
      jsonDecode(await calibrationFile.readAsString()) as Map<String, dynamic>;
  return JudgeCalibrationSet.fromJson(calibrationJson);
}

void _guardCalibrationTemplatePath(File file) {
  if (file.path.endsWith('.template.json')) return;
  throw StateError(
    'Calibration template output must end with .template.json to avoid '
    'overwriting a completed calibration label set: ${file.path}',
  );
}

int? _calibrationTemplateMaxRowsValue({
  String value = _calibrationTemplateMaxRows,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed < 1) {
    throw StateError(
      'EVAL_CALIBRATION_TEMPLATE_MAX_ROWS must be a positive integer: '
      '$value',
    );
  }
  return parsed;
}

void _guardCalibrationTemplateOutput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required File file,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: file,
    artifactDescription: 'calibration templates',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardCalibrationFileInput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required File file,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: file,
    artifactDescription: 'calibration files',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardScenarioCatalogPreflightInput({
  required EvalScenarioCatalogEvidence evidence,
  required File file,
}) {
  if (!evidence.protectedHoldout) return;
  if (!_isInsideCurrentRepo(file)) return;
  throw StateError(
    'Protected eval scenario catalogs must live outside the repo before they '
    'can satisfy catalog preflight: ${file.path}',
  );
}

void _guardExternalCatalogRepoPath({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required File file,
  required String artifactDescription,
  String? protectedTraceAck,
}) {
  final usesExternalCatalog =
      (manifestEvidence?.usesExternalCatalog ?? false) ||
      loadedEvidence.usesExternalCatalog;
  if (!usesExternalCatalog) return;
  final ack = protectedTraceAck ?? _protectedTraceAckValue();
  if (ack == '1') return;
  if (!_isInsideCurrentRepo(file)) return;
  throw StateError(
    'External eval $artifactDescription include scenario ids. '
    'Keep the file outside the repo or set '
    'LOTTI_EVAL_PROTECTED_TRACE_ACK=1 to acknowledge this.',
  );
}

String? _protectedTraceAckValue() {
  final ackFromDefine = _protectedTraceAck.trim();
  if (ackFromDefine.isNotEmpty) return ackFromDefine;
  return Platform.environment['LOTTI_EVAL_PROTECTED_TRACE_ACK'];
}

bool _isInsideCurrentRepo(File file) {
  final repoPath = Directory.current.absolute.resolveSymbolicLinksSync();
  final templatePath = _canonicalTargetPath(file);
  return templatePath == repoPath || p.isWithin(repoPath, templatePath);
}

String _canonicalTargetPath(File file) {
  final absolute = file.absolute;
  if (absolute.existsSync()) return absolute.resolveSymbolicLinksSync();

  var existingParent = absolute.parent;
  while (!existingParent.existsSync()) {
    final next = existingParent.parent;
    if (next.path == existingParent.path) break;
    existingParent = next;
  }
  final canonicalParent = existingParent.absolute.resolveSymbolicLinksSync();
  final tail = p.relative(absolute.path, from: existingParent.absolute.path);
  return p.normalize(p.join(canonicalParent, tail));
}

EvalScenarioCatalogEvidence _publicCatalogEvidence() {
  return EvalScenarioCatalogEvidence(
    scenarioSetDigest: EvalProvenance.digestText('public-scenarios'),
    publicScenarioCount: 1,
    externalScenarioCount: 0,
    protectedHoldout: false,
    protectedScenarioIds: const [],
    protectedHoldoutScenarioIds: const [],
  );
}
