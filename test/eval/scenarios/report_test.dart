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
const _blindedExportPath = String.fromEnvironment('EVAL_BLINDED_EXPORT');
const _blindedExportOverwrite = String.fromEnvironment(
  'EVAL_BLINDED_EXPORT_OVERWRITE',
);
const _blindedExportSeed = String.fromEnvironment('EVAL_BLINDED_EXPORT_SEED');
const _blindedImportPath = String.fromEnvironment('EVAL_BLINDED_IMPORT');
const _blindedImportOverwrite = String.fromEnvironment(
  'EVAL_BLINDED_IMPORT_OVERWRITE',
);
const _pairwisePairsPath = String.fromEnvironment('EVAL_PAIRWISE_PAIRS');
const _pairwiseBlindedExportPath = String.fromEnvironment(
  'EVAL_PAIRWISE_BLINDED_EXPORT',
);
const _pairwiseBlindedExportOverwrite = String.fromEnvironment(
  'EVAL_PAIRWISE_BLINDED_EXPORT_OVERWRITE',
);
const _pairwiseBlindedExportSeed = String.fromEnvironment(
  'EVAL_PAIRWISE_BLINDED_EXPORT_SEED',
);
const _pairwiseBlindedImportPath = String.fromEnvironment(
  'EVAL_PAIRWISE_BLINDED_IMPORT',
);
const _pairwiseBlindedImportOverwrite = String.fromEnvironment(
  'EVAL_PAIRWISE_BLINDED_IMPORT_OVERWRITE',
);
const _pairwiseReadinessIntentPath = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_INTENT',
);
const _pairwiseReadinessPlanPath = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_PLAN',
);
const _pairwiseReadinessPlanId = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_PLAN_ID',
);
const _pairwiseReadinessMinDecisions = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_MIN_DECISIONS',
);
const _pairwiseReadinessMinVotes = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_MIN_VOTES',
);
const _pairwiseReadinessQuorumFraction = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_QUORUM_FRACTION',
);
const _pairwiseReadinessReviewerKind = String.fromEnvironment(
  'EVAL_PAIRWISE_REVIEWER_KIND',
);
const _pairwiseReadinessReviewerModel = String.fromEnvironment(
  'EVAL_PAIRWISE_REVIEWER_MODEL',
);
const _pairwiseReadinessReviewPromptDigest = String.fromEnvironment(
  'EVAL_PAIRWISE_REVIEW_PROMPT_DIGEST',
);
const _pairwiseReadinessReviewCalibrationSetVersion = String.fromEnvironment(
  'EVAL_PAIRWISE_REVIEW_CALIBRATION_SET_VERSION',
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
const _requiredCapabilities = String.fromEnvironment(
  'EVAL_REQUIRED_CAPABILITIES',
);
const _profileCatalogValue = String.fromEnvironment(kEvalProfilesPathEnv);
const _profileNames = String.fromEnvironment(kEvalProfileNamesEnv);
const _promptVariantCatalogValue = String.fromEnvironment(
  kEvalPromptVariantsPathEnv,
);
const _promptVariantNames = String.fromEnvironment(kEvalPromptVariantNamesEnv);
const _runsRootPath = String.fromEnvironment('EVAL_RUNS_ROOT');
const _tuningReportPath = String.fromEnvironment('EVAL_TUNING_REPORT');
const _tuningReportOverwrite = String.fromEnvironment(
  'EVAL_TUNING_REPORT_OVERWRITE',
);
const _catalogPreflightReportPath = String.fromEnvironment(
  'EVAL_CATALOG_PREFLIGHT_REPORT',
);
const _catalogPreflightReportOverwrite = String.fromEnvironment(
  'EVAL_CATALOG_PREFLIGHT_REPORT_OVERWRITE',
);

void main() {
  test(
    'verifies complete trace/verdict matrix for an eval run',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
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
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      expect(run.traces, isNotEmpty, reason: 'EVAL_RUN=$_runId has no traces');
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
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
              scenarioCatalogEvidence: run.manifest.scenarioCatalogEvidence,
            );
      final pairwiseReadinessPlan = await _pairwiseReadinessPlanFromConfig(
        manifest: run.manifest,
        writer: writer,
      );
      final pairwisePreferenceArtifacts = pairwiseReadinessPlan == null
          ? null
          : await writer.readPairwisePreferenceArtifacts(
              run.manifest.runId,
              traces: run.traces,
            );
      final pairwisePreferenceVotes =
          pairwisePreferenceArtifacts?.votes ??
          const <EvalPairwisePreferenceVote>[];
      final pairwiseTraceRefsByKey =
          pairwisePreferenceArtifacts?.traceRefsByKey ??
          const <String, EvalPairwiseTraceRef>{};
      if (pairwiseReadinessPlan != null) {
        _validatePairwiseReadinessPlanVotes(
          plan: pairwiseReadinessPlan,
          votes: pairwisePreferenceVotes,
        );
      }
      final readiness = EvalTuningReadiness.assess(
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        manifest: run.manifest,
        scenarioCatalogEvidence: catalog.evidence,
        policy: _readinessPolicyFromConfig(
          pairwiseReadinessPlan,
          manifest: run.manifest,
        ),
        calibrationSet: calibrationSet,
        pairwisePreferenceVotes: pairwisePreferenceVotes,
        pairwiseTraceRefsByKey: pairwiseTraceRefsByKey,
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
      final pairwisePreferenceReport = await _pairwisePreferenceReport(
        writer: writer,
        run: run,
      );
      if (pairwisePreferenceReport != null) {
        // ignore: avoid_print
        print(pairwisePreferenceReport);
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
    'renders eval run diagnostics',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      expect(run.traces, isNotEmpty, reason: 'EVAL_RUN=$_runId has no traces');
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
        requireVerdicts: false,
      );
      // ignore: avoid_print
      print(
        EvalReporter.renderLevel1Diagnostics(
          run.traces,
          verificationErrors: verification.errors,
        ),
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );
    },
    tags: 'eval-report',
    skip: _runId.isEmpty
        ? 'Set EVAL_RUN=<runId> to diagnose an eval run.'
        : false,
  );

  test(
    'writes machine-readable tuning report',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final file = await _writeTuningReportForRun(
        writer: writer,
        runId: _runId,
        tuningReportPath: _tuningReportPath,
        overwrite: _tuningReportOverwrite == '1',
      );
      // ignore: avoid_print
      print('Wrote tuning report: ${file.path}');
    },
    tags: 'eval-report',
    skip: _runId.isEmpty || _tuningReportPath.isEmpty
        ? 'Set EVAL_RUN=<runId> and EVAL_TUNING_REPORT=<json> to write a '
              'machine-readable tuning report.'
        : false,
  );

  test(
    'renders scenario catalog preflight',
    () async {
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
    'writes machine-readable scenario catalog preflight report',
    () async {
      final file = await _writeScenarioCatalogPreflightReport(
        preflightReportPath: _catalogPreflightReportPath,
        overwrite: _catalogPreflightReportOverwrite == '1',
        protectedTraceAck: _protectedTraceAckValue(),
      );
      // ignore: avoid_print
      print('Wrote scenario catalog preflight report: ${file.path}');
    },
    tags: 'eval-report',
    skip: _catalogPreflightReportPath.isEmpty
        ? 'Set EVAL_CATALOG_PREFLIGHT_REPORT=<json> to write a '
              'machine-readable scenario catalog preflight report.'
        : false,
  );

  test(
    'writes judge calibration label template',
    () async {
      final run = await TraceWriter(runsRoot: _runsRoot()).readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
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
    'writes blinded judge trace export',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
        requireVerdicts: false,
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );

      final outputDir = Directory(_blindedExportPath);
      _guardBlindedExportOutput(
        manifestEvidence: run.manifest.scenarioCatalogEvidence,
        loadedEvidence: catalog.evidence,
        directory: outputDir,
      );
      final result = await EvalBlindedTraceExporter.writeRun(
        run: run,
        writer: writer,
        outputDir: outputDir,
        // ignore: avoid_redundant_argument_values
        overwrite: _blindedExportOverwrite == '1',
        exportSeed: _blindedExportSeedValue(),
      );
      // ignore: avoid_print
      print('Wrote blinded judge export: ${result.judgeDir.path}');
      // ignore: avoid_print
      print('Wrote private blinded export key: ${result.privateKeyFile.path}');
    },
    tags: 'eval-report',
    skip: _runId.isEmpty || _blindedExportPath.isEmpty
        ? 'Set EVAL_RUN=<runId> and EVAL_BLINDED_EXPORT=<dir> to write '
              'a blinded judge trace export.'
        : false,
  );

  test(
    'imports blinded judge verdicts',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final preImportVerification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
        requireVerdicts: false,
      );
      expect(
        preImportVerification.errors,
        isEmpty,
        reason: preImportVerification.errors.join('\n'),
      );

      final importDir = Directory(_blindedImportPath);
      _guardBlindedImportInput(
        manifestEvidence: run.manifest.scenarioCatalogEvidence,
        loadedEvidence: catalog.evidence,
        directory: importDir,
      );
      final result = await EvalBlindedVerdictImporter.importRun(
        run: run,
        writer: writer,
        exportDir: importDir,
        // ignore: avoid_redundant_argument_values
        overwrite: _blindedImportOverwrite == '1',
      );
      // ignore: avoid_print
      print(
        'Imported ${result.importedCount} blinded judge verdict(s) from '
        '${importDir.path}',
      );

      final importedRun = await writer.readRun(_runId);
      final postImportVerification = EvalRunVerifier.verify(
        runId: _runId,
        traces: importedRun.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        manifest: importedRun.manifest,
        artifactNames: importedRun.artifactNames,
      );
      expect(
        postImportVerification.errors,
        isEmpty,
        reason: postImportVerification.errors.join('\n'),
      );
    },
    tags: 'eval-report',
    skip: _runId.isEmpty || _blindedImportPath.isEmpty
        ? 'Set EVAL_RUN=<runId> and EVAL_BLINDED_IMPORT=<dir> to import '
              'blinded judge verdicts.'
        : false,
  );

  test(
    'writes blinded pairwise preference export',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
        requireVerdicts: false,
      );
      expect(
        verification.errors,
        isEmpty,
        reason: verification.errors.join('\n'),
      );

      final readinessIntent = _readPairwiseReadinessIntentFromConfig();
      final pairs = _pairwisePairsPath.isEmpty
          ? await _pairwiseReviewPairsFromIntent(
              intent: readinessIntent,
              run: run,
              writer: writer,
            )
          : await () async {
              final pairsFile = File(_pairwisePairsPath);
              _guardPairwisePairsInput(
                manifestEvidence: run.manifest.scenarioCatalogEvidence,
                loadedEvidence: catalog.evidence,
                file: pairsFile,
              );
              return _readPairwiseReviewPairs(
                file: pairsFile,
                run: run,
                writer: writer,
              );
            }();
      final outputDir = Directory(_pairwiseBlindedExportPath);
      _guardPairwiseBlindedExportOutput(
        manifestEvidence: run.manifest.scenarioCatalogEvidence,
        loadedEvidence: catalog.evidence,
        directory: outputDir,
      );
      final result = await EvalBlindedPairwisePreference.writePairs(
        run: run,
        writer: writer,
        outputDir: outputDir,
        pairs: pairs,
        // ignore: avoid_redundant_argument_values
        overwrite: _pairwiseBlindedExportOverwrite == '1',
        exportSeed: _pairwiseBlindedExportSeedValue(),
        readinessPlanId:
            _pairwiseReadinessPlanIdValue() ?? readinessIntent?.planId,
        readinessIntent: readinessIntent,
        readinessReviewProtocol:
            _pairwiseReadinessReviewProtocolFromConfig() ??
            readinessIntent?.reviewProtocol,
        readinessMinBlindedPairwisePreferenceDecisions:
            _pairwiseReadinessMinDecisionsValue() ??
            readinessIntent?.minBlindedPairwisePreferenceDecisions,
        readinessMinVotes:
            _pairwiseReadinessMinVotesValue() ?? readinessIntent?.minVotes ?? 1,
        readinessQuorumFraction:
            _pairwiseReadinessQuorumFractionValue() ??
            readinessIntent?.quorumFraction ??
            1,
      );
      // ignore: avoid_print
      print('Wrote blinded pairwise export: ${result.judgeDir.path}');
      // ignore: avoid_print
      print(
        'Wrote private blinded pairwise key: ${result.privateKeyFile.path}',
      );
      // ignore: avoid_print
      print(
        'Wrote pairwise readiness plan: ${result.readinessPlanFile.path}',
      );
      // ignore: avoid_print
      print(
        'Registered pairwise readiness plan: '
        '${result.readinessPlanRegistrationFile.path}',
      );
    },
    tags: 'eval-report',
    skip:
        _runId.isEmpty ||
            (_pairwisePairsPath.isEmpty &&
                _pairwiseReadinessIntentPath.isEmpty) ||
            _pairwiseBlindedExportPath.isEmpty
        ? 'Set EVAL_RUN=<runId>, EVAL_PAIRWISE_PAIRS=<json> or '
              'EVAL_PAIRWISE_READINESS_INTENT=<json>, and '
              'EVAL_PAIRWISE_BLINDED_EXPORT=<dir> to write a blinded '
              'pairwise export.'
        : false,
  );

  test(
    'imports blinded pairwise preferences',
    () async {
      final writer = TraceWriter(runsRoot: _runsRoot());
      final run = await writer.readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final preImportVerification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        manifest: run.manifest,
        artifactNames: run.artifactNames,
        requireVerdicts: false,
      );
      expect(
        preImportVerification.errors,
        isEmpty,
        reason: preImportVerification.errors.join('\n'),
      );

      final importDir = Directory(_pairwiseBlindedImportPath);
      _guardPairwiseBlindedImportInput(
        manifestEvidence: run.manifest.scenarioCatalogEvidence,
        loadedEvidence: catalog.evidence,
        directory: importDir,
      );
      final result = await EvalBlindedPairwisePreference.importVotes(
        run: run,
        writer: writer,
        exportDir: importDir,
        // ignore: avoid_redundant_argument_values
        overwrite: _pairwiseBlindedImportOverwrite == '1',
      );
      // ignore: avoid_print
      print(
        'Imported ${result.importedCount} blinded pairwise preference '
        'vote(s) from ${importDir.path}',
      );
    },
    tags: 'eval-report',
    skip: _runId.isEmpty || _pairwiseBlindedImportPath.isEmpty
        ? 'Set EVAL_RUN=<runId> and EVAL_PAIRWISE_BLINDED_IMPORT=<dir> '
              'to import blinded pairwise preferences.'
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

  test('pairwise readiness export config validates tuning knobs', () {
    final promptDigest = EvalProvenance.digestText('llm-pairwise-prompt-v2');

    expect(_pairwiseReadinessPlanIdValue(value: '  gate-v2  '), 'gate-v2');
    expect(_pairwiseReadinessMinDecisionsValue(value: '3'), 3);
    expect(_pairwiseReadinessMinVotesValue(value: '2'), 2);
    expect(_pairwiseReadinessQuorumFractionValue(value: '0.75'), 0.75);

    final protocol = _pairwiseReadinessReviewProtocolFromConfig(
      reviewerKind: 'llmJudge',
      reviewerModel: 'gpt-5.4',
      promptDigest: promptDigest,
      calibrationSetVersion: 'pairwise-llm-gold-v2',
    );
    expect(protocol, isNotNull);
    expect(protocol!.reviewerKind, EvalPairwiseReviewerKind.llmJudge);
    expect(protocol.reviewerModel, 'gpt-5.4');
    expect(protocol.promptDigest, promptDigest);
    expect(protocol.calibrationSetVersion, 'pairwise-llm-gold-v2');
    expect(_pairwiseReadinessReviewProtocolFromConfig(), isNull);
  });

  test('pairwise readiness export config rejects weak knobs', () {
    expect(
      () => _pairwiseReadinessMinDecisionsValue(value: '0'),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessMinVotesValue(value: '0'),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessQuorumFractionValue(value: '0'),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessQuorumFractionValue(value: '1.5'),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessReviewProtocolFromConfig(
        reviewerKind: 'human',
        reviewerModel: 'gpt-5.4',
      ),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessReviewProtocolFromConfig(
        reviewerKind: 'llmJudge',
      ),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessReviewProtocolFromConfig(
        reviewerModel: 'gpt-5.4',
      ),
      throwsStateError,
    );
    expect(
      () => _pairwiseReadinessReviewProtocolFromConfig(
        promptDigest: 'not-a-digest',
      ),
      throwsStateError,
    );
  });

  test('required capability config flows into readiness policy', () async {
    expect(
      _requiredPrimaryCapabilityIdsFromConfig(
        value: ' task.tuning.ready, planner.tuning.ready ',
      ),
      {'task.tuning.ready', 'planner.tuning.ready'},
    );
    expect(
      () => _requiredPrimaryCapabilityIdsFromConfig(
        value: 'task.tuning.ready,,planner.tuning.ready',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('EVAL_REQUIRED_CAPABILITIES'),
        ),
      ),
    );

    final plainPolicy = _readinessPolicyFromConfig(
      null,
      requiredPrimaryCapabilityIds: const {'task.tuning.ready'},
    );
    final pairwisePlan = EvalPairwiseReadinessPlan.fromJson(
      _pairwiseReadinessPlanJson(
        manifest: _promotionManifest(),
        requiredComparisonKeys: const ['profile::registered-pair'],
      ),
    );
    final pairwisePolicy = _readinessPolicyFromConfig(
      pairwisePlan,
      requiredPrimaryCapabilityIds: const {'planner.tuning.ready'},
    );
    final contractEvidence = EvalProvenance.tuningReadinessContractEvidence(
      scenarioSetDigest: EvalProvenance.scenarioSetDigest([
        taskReleaseNotesScenario,
      ]),
      requiredPrimaryCapabilityIds: const {'task.tuning.ready'},
    );
    final contractManifest = _promotionManifest(
      tuningReadinessContractEvidence: contractEvidence,
    );
    final exactPolicy = EvalTuningPolicy.modelClassTuning(
      requiredPrimaryCapabilityIds:
          contractEvidence.requiredPrimaryCapabilityIds,
    );
    final policyManifest = _promotionManifest(
      tuningReadinessContractEvidence: contractEvidence,
      tuningReadinessPolicyEvidence: EvalTuningReadinessPolicyEvidence(
        policyName: exactPolicy.name,
        policyDigest: exactPolicy.policyDigest,
      ),
    );
    final driftedPolicyManifest = _promotionManifest(
      tuningReadinessContractEvidence: contractEvidence,
      tuningReadinessPolicyEvidence: EvalTuningReadinessPolicyEvidence(
        policyName: exactPolicy.name,
        policyDigest: EvalProvenance.digestText('stale-readiness-policy'),
      ),
    );
    final pairwiseManifest = _promotionManifest(
      pairwiseReadinessPlanEvidence: pairwisePlan.toManifestEvidence(),
    );
    final exactManifestPolicy = _readinessPolicyFromConfig(
      null,
      manifest: policyManifest,
    );
    final matchingManifestPolicy = _readinessPolicyFromConfig(
      null,
      manifest: policyManifest,
      requiredCapabilitiesValue: ' task.tuning.ready ',
    );

    expect(plainPolicy.requiredPrimaryCapabilityIds, {'task.tuning.ready'});
    expect(pairwisePolicy.requiredPrimaryCapabilityIds, {
      'planner.tuning.ready',
    });
    expect(matchingManifestPolicy.requiredPrimaryCapabilityIds, {
      'task.tuning.ready',
    });
    expect(exactManifestPolicy.policyDigest, exactPolicy.policyDigest);
    expect(
      () => _readinessPolicyFromConfig(
        null,
        manifest: contractManifest,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('tuningReadinessPolicyEvidence is required'),
        ),
      ),
    );
    expect(
      () => _readinessPolicyFromConfig(
        null,
        manifest: policyManifest,
        requiredCapabilitiesValue: 'planner.tuning.ready',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('does not match run manifest readiness contract'),
        ),
      ),
    );
    expect(
      () => _readinessPolicyFromConfig(
        null,
        manifest: driftedPolicyManifest,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Tuning readiness policyDigest'),
        ),
      ),
    );
    expect(
      () => _readinessPolicyFromConfig(null, manifest: pairwiseManifest),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('EVAL_PAIRWISE_READINESS_PLAN'),
        ),
      ),
    );
    await expectLater(
      _pairwiseReadinessPlanFromConfig(manifest: pairwiseManifest),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('EVAL_PAIRWISE_READINESS_PLAN'),
        ),
      ),
    );
    expect(pairwisePolicy.minBlindedPairwisePreferenceDecisions, 1);
    expect(
      pairwisePolicy.requiredBlindedPairwisePreferenceComparisonKeys,
      {'profile::registered-pair'},
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

  test('external tuning reports inside repo require ack', () {
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
    final file = File('eval/tuning/private-report.json');

    expect(
      () => _guardTuningReportOutput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        file: file,
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardTuningReportOutput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        file: file,
        protectedTraceAck: '1',
      ),
      returnsNormally,
    );
  });

  test('external catalog preflight reports inside repo require ack', () {
    final evidence = EvalScenarioCatalogEvidence(
      scenarioSetDigest: EvalProvenance.digestText('external-scenarios'),
      publicScenarioCount: 0,
      externalScenarioCount: 1,
      externalCatalogDigest: EvalProvenance.digestText('external-catalog'),
      externalCatalogId: 'private-production-replay-v1',
      protectedHoldout: true,
      protectedScenarioIds: const ['private_task_holdout'],
      protectedHoldoutScenarioIds: const ['private_task_holdout'],
    );
    final file = File('eval/catalog_preflight.json');

    expect(
      () => _guardScenarioCatalogPreflightReportOutput(
        evidence: evidence,
        file: file,
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardScenarioCatalogPreflightReportOutput(
        evidence: evidence,
        file: file,
        protectedTraceAck: '1',
      ),
      returnsNormally,
    );
  });

  test('external blinded trace exports inside repo require ack', () {
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
    final directory = Directory('eval/blinded/private-run');

    expect(
      () => _guardBlindedExportOutput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        directory: directory,
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardBlindedExportOutput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        directory: directory,
        protectedTraceAck: '1',
      ),
      returnsNormally,
    );
  });

  test('external blinded verdict imports inside repo require ack', () {
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
    final directory = Directory('eval/blinded/private-run');

    expect(
      () => _guardBlindedImportInput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        directory: directory,
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardBlindedImportInput(
        manifestEvidence: evidence,
        loadedEvidence: _publicCatalogEvidence(),
        directory: directory,
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

  test('profile promotion manifest evidence requires plan file', () {
    final manifest = _promotionManifest();

    expect(
      () => _profilePromotionPolicyFromConfig(manifest: manifest),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('EVAL_PROMOTION_PLAN'),
        ),
      ),
    );
    expect(
      () => _profilePromotionPolicyFromConfig(
        manifest: manifest,
        candidateProfileName: 'local-small',
        baselineProfileName: 'frontier-fast',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('promotion plan evidence'),
            contains('registered promotion gate'),
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

  test(
    'pairwise readiness plan supplies strict policy and validates digests',
    () async {
      final boundPlan = _manifestBoundPairwiseReadinessPlanJson(
        requiredComparisonKeys: const ['profile::registered-pair'],
        minVotes: 2,
        quorumFraction: 0.75,
      );
      final planFile = _writePairwiseReadinessPlan(
        boundPlan.planJson,
      );

      final plan = await _pairwiseReadinessPlanFromConfig(
        manifest: boundPlan.manifest,
        pairwiseReadinessPlanPath: planFile.path,
      );
      final policy = _readinessPolicyFromConfig(plan);

      expect(plan, isNotNull);
      expect(plan!.requiredComparisonKeys, {'profile::registered-pair'});
      expect(policy.minBlindedPairwisePreferenceDecisions, 1);
      expect(
        policy.requiredBlindedPairwisePreferenceComparisonKeys,
        {'profile::registered-pair'},
      );
      expect(policy.blindedPairwisePreferencePolicy.minVotes, 2);
      expect(policy.blindedPairwisePreferencePolicy.quorumFraction, 0.75);
      expect(
        policy.blindedPairwisePreferencePolicy.requireBlindedImport,
        isTrue,
      );
      expect(
        policy.blindedPairwisePreferencePolicy.requireTraceOrderRandomized,
        isTrue,
      );
    },
  );

  test(
    'pairwise readiness plan rejects sidecar-only registration evidence',
    () async {
      final manifest = _promotionManifest();
      final planJson = _pairwiseReadinessPlanJson(
        manifest: manifest,
        requiredComparisonKeys: const ['profile::registered-pair'],
        minVotes: 2,
        quorumFraction: 0.75,
      );
      final planFile = _writePairwiseReadinessPlan(planJson);
      final writer = await _writerWithPairwiseReadinessRegistration(
        manifest: manifest,
        planJson: planJson,
      );

      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          writer: writer,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('EVAL_PAIRWISE_READINESS_PLAN'),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          writer: writer,
          pairwiseReadinessPlanPath: planFile.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Pairwise readiness plan was not recorded in the run manifest',
            ),
          ),
        ),
      );
    },
  );

  test(
    'pairwise readiness plan rejects manifest drift and weak plans',
    () async {
      final boundPlan = _manifestBoundPairwiseReadinessPlanJson(
        requiredComparisonKeys: const ['profile::registered-pair'],
      );
      final manifest = boundPlan.manifest;
      final driftedPlan = _writePairwiseReadinessPlan(
        {
          ...boundPlan.planJson,
          'manifestDigest': EvalProvenance.digestText('wrong-manifest'),
        },
      );
      final weakPlan = _writePairwiseReadinessPlan(
        _pairwiseReadinessPlanJson(
          manifest: manifest,
          requiredComparisonKeys: const [],
        ),
      );
      final legacyPlan = _writePairwiseReadinessPlan(
        _pairwiseReadinessPlanJson(
            manifest: manifest,
            requiredComparisonKeys: const ['profile::registered-pair'],
          )
          ..['preferencePolicy'] = <String, dynamic>{
            'minVotes': 1,
            'quorumFraction': 1,
          },
      );
      final weakBlindingPlan = _writePairwiseReadinessPlan(
        _pairwiseReadinessPlanJson(
            manifest: manifest,
            requiredComparisonKeys: const ['profile::registered-pair'],
          )
          ..['blindedPairwisePreferencePolicy'] = <String, dynamic>{
            'minVotes': 1,
            'quorumFraction': 1,
            'requireModelIdentityBlind': true,
            'requireProfileBlind': true,
            'requirePeerVoteBlind': true,
            'requireTraceOrderRandomized': true,
            'requireBlindedImport': false,
          },
      );
      final unblindedProtocolPlanJson = _pairwiseReadinessPlanJson(
        manifest: manifest,
        requiredComparisonKeys: const ['profile::registered-pair'],
      );
      (unblindedProtocolPlanJson['reviewProtocol']
              as Map<String, dynamic>)['profileVisible'] =
          true;
      final unblindedProtocolPlan = _writePairwiseReadinessPlan(
        unblindedProtocolPlanJson,
      );
      final unregisteredAtRunPlan = _writePairwiseReadinessPlan(
        _pairwiseReadinessPlanJson(
          manifest: _promotionManifest(),
          requiredComparisonKeys: const ['profile::registered-pair'],
        ),
      );
      final subjectDriftPlanJson = <String, dynamic>{...boundPlan.planJson};
      (subjectDriftPlanJson['reviewProtocol']
          as Map<String, dynamic>)['promptDigest'] = EvalProvenance.digestText(
        'post-run-pairwise-prompt',
      );
      final subjectDriftPlan = _writePairwiseReadinessPlan(
        subjectDriftPlanJson,
      );

      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          pairwiseReadinessPlanPath: driftedPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Pairwise readiness plan manifestDigest'),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          pairwiseReadinessPlanPath: weakPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('comparisons must not be empty'),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          pairwiseReadinessPlanPath: legacyPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('unsupported field preferencePolicy'),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          pairwiseReadinessPlanPath: weakBlindingPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('requireBlindedImport must be true'),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          pairwiseReadinessPlanPath: unblindedProtocolPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('reviewProtocol profileVisible must be false'),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: _promotionManifest(),
          pairwiseReadinessPlanPath: unregisteredAtRunPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Pairwise readiness plan was not recorded in the run manifest',
            ),
          ),
        ),
      );
      await expectLater(
        _pairwiseReadinessPlanFromConfig(
          manifest: manifest,
          pairwiseReadinessPlanPath: subjectDriftPlan.path,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Pairwise readiness plan subject digest'),
          ),
        ),
      );
    },
  );

  test('pairwise readiness plan binds vote protocol and import digests', () {
    final manifest = _promotionManifest();
    final vote = _pairwiseReadinessVote(manifest: manifest);
    final plan = EvalPairwiseReadinessPlan.fromJson(
      _pairwiseReadinessPlanJson(
        manifest: manifest,
        requiredComparisonKeys: [vote.comparisonKey],
        reviewPayloadDigests: {
          vote.comparisonKey: vote.blindedImport!.reviewPayloadDigest,
        },
        judgeManifestDigest: vote.blindedImport!.judgeManifestDigest,
        privateKeyDigest: vote.blindedImport!.privateKeyDigest,
      ),
    );
    final protocolMismatch = _pairwiseReadinessVote(
      manifest: manifest,
      promptDigest: EvalProvenance.digestText('different-pairwise-prompt'),
    );
    final privateKeyMismatch = _pairwiseReadinessVote(
      manifest: manifest,
      privateKeyDigest: EvalProvenance.digestText('different-private-key'),
    );

    expect(
      () => _validatePairwiseReadinessPlanVotes(plan: plan, votes: [vote]),
      returnsNormally,
    );
    expect(
      () => _validatePairwiseReadinessPlanVotes(
        plan: plan,
        votes: [protocolMismatch],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('review protocol fingerprint'),
        ),
      ),
    );
    expect(
      () => _validatePairwiseReadinessPlanVotes(
        plan: plan,
        votes: [privateKeyMismatch],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('privateKeyDigest'),
        ),
      ),
    );
  });

  test('pairwise readiness plan rejects embedded intent remaps', () {
    final manifest = _promotionManifest();
    final vote = _pairwiseReadinessVote(manifest: manifest);
    final intendedOptionA = _pairwiseRef(
      _promotionTraceForProfile(kFrontierFastProfile),
    );
    final intendedOptionB = _pairwiseRef(
      _promotionTraceForProfile(kLocalSmallProfile),
    );
    const intentKey = 'profile::frontier-fast-vs-local-small';
    final intent = EvalPairwiseReadinessIntent(
      planId: 'intent-bound-pairwise-plan',
      baseReadinessPolicy: 'modelClassTuning',
      scenarioSetDigest: manifest.scenarioSetDigest,
      profileSetDigest: manifest.profileSetDigest,
      profileBindingSetDigest: manifest.profileBindingSetDigest,
      agentDirectiveVariantSetDigest: manifest.agentDirectiveVariantSetDigest,
      minBlindedPairwisePreferenceDecisions: 1,
      comparisons: [
        EvalPairwiseReadinessIntentComparison(
          pairId: 'frontier-fast-vs-local-small',
          intentKey: intentKey,
          axis: EvalPairwiseComparisonAxis.profile,
          scenarioId: intendedOptionA.scenarioId,
          scenarioDigest: intendedOptionA.scenarioDigest,
          agentKind: intendedOptionA.agentKind,
          capabilityId: intendedOptionA.capabilityId,
          trialIndex: intendedOptionA.trialIndex,
          optionA: _pairwiseIntentOptionFor(intendedOptionA),
          optionB: _pairwiseIntentOptionFor(intendedOptionB),
          preferredOption: EvalPairwiseReadinessPreferredOption.optionA,
          outcomeRequirement:
              EvalPairwiseReadinessOutcomeRequirement.mustNotLose,
        ),
      ],
      reviewProtocol: EvalPairwiseReadinessReviewProtocol(
        reviewerKind: EvalPairwiseReviewerKind.human,
        reviewerModel: null,
        promptDigest: _pairwiseReadinessPromptDigest,
        calibrationSetVersion: _pairwiseReadinessCalibrationSetVersion,
        profileVisible: false,
        modelIdentityVisible: false,
        peerVotesVisible: false,
        traceOrderRandomized: true,
      ),
      minVotes: 1,
      quorumFraction: 1,
    );
    final forgedPlan = EvalPairwiseReadinessPlan(
      planId: intent.planId,
      baseReadinessPolicy: intent.baseReadinessPolicy,
      scenarioSetDigest: intent.scenarioSetDigest,
      profileSetDigest: intent.profileSetDigest,
      profileBindingSetDigest: intent.profileBindingSetDigest,
      manifestDigest: manifest.manifestDigest,
      minBlindedPairwisePreferenceDecisions:
          intent.minBlindedPairwisePreferenceDecisions,
      comparisons: [
        EvalPairwiseReadinessComparison(
          comparisonKey: vote.comparisonKey,
          intentKey: intentKey,
          reviewPayloadDigest: vote.blindedImport!.reviewPayloadDigest,
          outcomeExpectation: intent.comparisons.single.outcomeExpectation,
        ),
      ],
      intent: intent,
      reviewProtocol: intent.reviewProtocol,
      importBinding: EvalPairwiseReadinessImportBinding(
        judgeManifestDigest: vote.blindedImport!.judgeManifestDigest,
        privateKeyDigest: vote.blindedImport!.privateKeyDigest,
      ),
      minVotes: intent.minVotes,
      quorumFraction: intent.quorumFraction,
    );

    expect(
      forgedPlan.toManifestEvidence().toJson(),
      intent.toManifestEvidence().toJson(),
      reason: 'the forged plan keeps the manifest-bound intent subject digest',
    );
    expect(
      () => _validatePairwiseReadinessPlanVotes(
        plan: forgedPlan,
        votes: [vote],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('does not refine embedded intent'),
        ),
      ),
    );
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

  test('tuning report json exposes structured gates and recommendations', () {
    final traces = [
      _promotionTraceForProfile(
        kFrontierProfile,
        verdict: _promotionVerdict(
          pass: false,
          goalAttainment: 2,
          quality: 2,
          efficiency: 2,
        ),
      ),
      _promotionTraceForProfile(
        kFrontierFastProfile,
        verdict: _promotionVerdict(
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
      ),
    ];
    const policy = EvalTuningPolicy(
      name: 'reportContractTest',
      requireAllVerdicts: true,
      requireAllLevel1Passed: true,
      requireAllJudgePasses: true,
      requireOutcomeSliceThresholds: true,
      minJudgePassRate: 1,
      minJudgePassRateLowerBound: 0.7,
      minMeanGoalAttainment: 4,
      minMeanQuality: 4,
      minMeanEfficiency: 3,
      maxMeanTokensPerTraceBudgetRatio: 1,
    );
    final readiness = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      policy: policy,
    );
    final report = _tuningReportJson(
      run: EvalRunArtifacts(
        manifest: _promotionManifest(includePromotionPlanEvidence: false),
        traces: traces,
        artifactNames: const [
          'manifest.json',
          'task_release_notes__frontier-fast.trace.json',
          'task_release_notes__frontier-fast.verdict.json',
          'tuning_report.json',
          'operator-notes.md',
        ],
      ),
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      promptVariants: const [EvalAgentDirectiveVariant()],
      readiness: readiness,
      calibrationReport: null,
      pairwiseReadinessPlan: null,
      pairwisePreferenceVotes: const [],
      promotionDecision: null,
    );

    expect(report['schemaVersion'], 1);
    expect(report['kind'], 'lotti.evalTuningReport');
    expect(EvalTuningReportContract.validate(report), isEmpty);
    expect(report['policy'], isA<Map<String, dynamic>>());
    expect(report['status'], containsPair('ready', false));
    expect(report['calibration'], containsPair('present', false));
    expect(report['promotion'], containsPair('status', 'notRequested'));
    final runJson = report['run'] as Map<String, dynamic>;
    final artifactSnapshot =
        runJson['artifactSnapshot'] as Map<String, dynamic>;
    expect(artifactSnapshot['artifactCount'], 5);
    expect(artifactSnapshot['traceCount'], 2);
    expect(artifactSnapshot['judgedTraceCount'], 2);
    expect(
      EvalProvenance.isDigest(
        artifactSnapshot['ownedArtifactRefsDigest'] as String,
      ),
      isTrue,
    );
    expect(
      EvalProvenance.isDigest(
        artifactSnapshot['loadedTraceContentDigest'] as String,
      ),
      isTrue,
    );

    final sidecarOnlyReport = _tuningReportJson(
      run: EvalRunArtifacts(
        manifest: _promotionManifest(includePromotionPlanEvidence: false),
        traces: traces,
        artifactNames: const [
          'tuning_report.json',
          'sidecar-a.json',
          'sidecar-b.txt',
        ],
      ),
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      promptVariants: const [EvalAgentDirectiveVariant()],
      readiness: readiness,
      calibrationReport: null,
      pairwiseReadinessPlan: null,
      pairwisePreferenceVotes: const [],
      promotionDecision: null,
    );
    expect(
      (sidecarOnlyReport['run'] as Map<String, dynamic>)['artifactSnapshot'],
      artifactSnapshot,
    );

    final driftedTraces = [
      traces.first,
      _promotionTraceForProfile(
        kFrontierFastProfile,
        verdict: _promotionVerdict(
          goalAttainment: 5,
          quality: 4,
          efficiency: 4,
        ),
      ),
    ];
    final driftedReadiness = EvalTuningReadiness.assess(
      traces: driftedTraces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      policy: policy,
    );
    final driftedReport = _tuningReportJson(
      run: EvalRunArtifacts(
        manifest: _promotionManifest(includePromotionPlanEvidence: false),
        traces: driftedTraces,
        artifactNames: const [],
      ),
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      promptVariants: const [EvalAgentDirectiveVariant()],
      readiness: driftedReadiness,
      calibrationReport: null,
      pairwiseReadinessPlan: null,
      pairwisePreferenceVotes: const [],
      promotionDecision: null,
    );
    final driftedSnapshot =
        (driftedReport['run'] as Map<String, dynamic>)['artifactSnapshot']
            as Map<String, dynamic>;
    expect(
      driftedSnapshot['ownedArtifactRefsDigest'],
      artifactSnapshot['ownedArtifactRefsDigest'],
    );
    expect(
      driftedSnapshot['loadedTraceContentDigest'],
      isNot(artifactSnapshot['loadedTraceContentDigest']),
    );

    final contentDriftedTraces = [
      traces.first,
      _promotionTraceForProfile(
        kFrontierFastProfile,
        verdict: _promotionVerdict(
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
        ),
        output: const AgentRunOutput(
          success: true,
          usage: InferenceUsage(inputTokens: 100, outputTokens: 50),
          report: AgentReportRecord(
            oneLiner: 'Done differently',
            tldr: 'Task was handled differently.',
            content: 'Handled differently.',
          ),
        ),
      ),
    ];
    final contentDriftedReadiness = EvalTuningReadiness.assess(
      traces: contentDriftedTraces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      policy: policy,
    );
    final contentDriftedReport = _tuningReportJson(
      run: EvalRunArtifacts(
        manifest: _promotionManifest(includePromotionPlanEvidence: false),
        traces: contentDriftedTraces,
        artifactNames: const [],
      ),
      scenarios: [taskReleaseNotesScenario],
      profiles: const [kFrontierProfile, kFrontierFastProfile],
      promptVariants: const [EvalAgentDirectiveVariant()],
      readiness: contentDriftedReadiness,
      calibrationReport: null,
      pairwiseReadinessPlan: null,
      pairwisePreferenceVotes: const [],
      promotionDecision: null,
    );
    final contentDriftedSnapshot =
        (contentDriftedReport['run']
                as Map<String, dynamic>)['artifactSnapshot']
            as Map<String, dynamic>;
    expect(
      contentDriftedSnapshot['ownedArtifactRefsDigest'],
      artifactSnapshot['ownedArtifactRefsDigest'],
    );
    expect(
      contentDriftedSnapshot['loadedTraceContentDigest'],
      isNot(artifactSnapshot['loadedTraceContentDigest']),
    );

    final gates = (report['gates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      gates,
      contains(
        isA<Map<String, dynamic>>()
            .having(
              (gate) => gate['id'],
              'id',
              'outcome.slice.judge_pass_rate',
            )
            .having((gate) => gate['status'], 'status', 'fail')
            .having(
              (gate) => (gate['scope'] as Map<String, dynamic>)['modelClass'],
              'modelClass',
              kFrontierProfile.modelClass.name,
            ),
      ),
    );

    final slices = (report['useCaseModelSlices'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final failingSlice = slices.singleWhere(
      (slice) => slice['modelClass'] == kFrontierProfile.modelClass.name,
    );
    expect(failingSlice['recommendation'], 'improveOutcome');
    expect(
      failingSlice['blockingReasons'],
      contains('outcome.passRateLow'),
    );

    final blockedReasons = (report['blockedReasons'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      blockedReasons,
      contains(
        isA<Map<String, dynamic>>()
            .having((reason) => reason['code'], 'code', 'outcome.passRateLow')
            .having(
              (reason) => reason['nextAction'],
              'nextAction',
              'tunePromptOrModel',
            ),
      ),
    );

    final recommendations = (report['recommendations'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      recommendations,
      contains(
        isA<Map<String, dynamic>>()
            .having(
              (recommendation) => recommendation['action'],
              'action',
              'improveOutcome',
            )
            .having(
              (recommendation) =>
                  (recommendation['scope']
                      as Map<String, dynamic>)['modelClass'],
              'modelClass',
              kFrontierProfile.modelClass.name,
            ),
      ),
    );

    final nextExperimentPlan =
        report['nextExperimentPlan'] as Map<String, dynamic>;
    expect(nextExperimentPlan['status'], 'blocked');
    expect(
      nextExperimentPlan['recommendedCommands'],
      contains(
        isA<Map<String, dynamic>>().having(
          (command) => command['mode'],
          'mode',
          'tune',
        ),
      ),
    );
    expect(
      const JsonEncoder().convert(report),
      contains('lotti.evalTuningReport'),
    );
  });

  test('tuning report json redacts protected ids from every string', () {
    const protectedId = 'private_task_holdout';
    final privateScenario = EvalScenario(
      id: protectedId,
      title: 'Private holdout task',
      agentKind: taskReleaseNotesScenario.agentKind,
      appState: taskReleaseNotesScenario.appState,
      userInput: taskReleaseNotesScenario.userInput,
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.private.holdout'],
        split: EvalScenarioSplit.holdout,
        source: EvalScenarioSource.productionReplay,
        tags: {'private', 'holdout'},
      ),
    );
    final catalogEvidence = EvalScenarioCatalogEvidence(
      scenarioSetDigest: EvalProvenance.scenarioSetDigest([privateScenario]),
      publicScenarioCount: 0,
      externalScenarioCount: 1,
      externalCatalogDigest: EvalProvenance.digestText('private-catalog'),
      externalCatalogId: 'private-redaction-fixture',
      externalSourceLabel: 'private_scenarios.json',
      protectedHoldout: true,
      protectedScenarioIds: const [protectedId],
      protectedHoldoutScenarioIds: const [protectedId],
    );
    const policy = EvalTuningPolicy(
      name: 'redactionPolicy',
      requireAllVerdicts: true,
      requireAllLevel1Passed: true,
      minProtectedHoldoutScenarios: 1,
    );
    final manifest = EvalProvenance.captureRunManifest(
      runId: 'private-redaction-run',
      targetName: 'private-redaction-fixture',
      targetKind: 'test',
      scenarios: [privateScenario],
      profiles: const [kFrontierProfile],
      scenarioCatalogEvidence: catalogEvidence,
      createdAt: DateTime.utc(2026, 6, 10, 12),
      command: 'private redaction fixture',
      environment: const <String, String>{},
    );
    final trace = EvalTrace(
      runId: manifest.runId,
      scenario: privateScenario,
      profile: kFrontierProfile,
      provenance: EvalProvenance.capture(
        scenario: privateScenario,
        profile: kFrontierProfile,
        manifestDigest: manifest.manifestDigest!,
      ),
      output: _promotionOutputForProfile(kFrontierProfile),
      level1Checks: const [
        EvalCheck(
          name: 'private_task_holdout_level1',
          passed: false,
          detail: 'private_task_holdout',
        ),
      ],
    );
    final readiness = EvalTuningReadiness.assess(
      traces: [trace],
      scenarios: [privateScenario],
      profiles: const [kFrontierProfile],
      manifest: manifest,
      scenarioCatalogEvidence: catalogEvidence,
      policy: policy,
    );

    final report = _tuningReportJson(
      run: EvalRunArtifacts(
        manifest: manifest,
        traces: [trace],
        artifactNames: const [],
      ),
      scenarios: [privateScenario],
      profiles: const [kFrontierProfile],
      promptVariants: const [EvalAgentDirectiveVariant()],
      readiness: readiness,
      calibrationReport: null,
      pairwiseReadinessPlan: null,
      pairwisePreferenceVotes: const [],
      promotionDecision: null,
    );
    final encoded = const JsonEncoder().convert(report);

    expect(readiness.failures.join('\n'), contains(protectedId));
    expect(encoded, isNot(contains(protectedId)));
    expect(encoded, isNot(contains('$protectedId::')));
    expect(encoded, contains('<redacted-scenario-001>'));
    expect(
      (report['run'] as Map<String, dynamic>)['protectedIdsRedacted'],
      isTrue,
    );

    final loadedOnlyManifest = EvalProvenance.captureRunManifest(
      runId: 'private-redaction-loaded-catalog-run',
      targetName: 'private-redaction-fixture',
      targetKind: 'test',
      scenarios: [privateScenario],
      profiles: const [kFrontierProfile],
      createdAt: DateTime.utc(2026, 6, 10, 12),
      command: 'private redaction loaded-catalog fixture',
      environment: const <String, String>{},
    );
    final loadedOnlyTrace = EvalTrace(
      runId: loadedOnlyManifest.runId,
      scenario: privateScenario,
      profile: kFrontierProfile,
      provenance: EvalProvenance.capture(
        scenario: privateScenario,
        profile: kFrontierProfile,
        manifestDigest: loadedOnlyManifest.manifestDigest!,
      ),
      output: _promotionOutputForProfile(kFrontierProfile),
      level1Checks: const [
        EvalCheck(
          name: 'private_task_holdout_level1',
          passed: false,
          detail: 'private_task_holdout',
        ),
      ],
    );
    final loadedOnlyReadiness = EvalTuningReadiness.assess(
      traces: [loadedOnlyTrace],
      scenarios: [privateScenario],
      profiles: const [kFrontierProfile],
      manifest: loadedOnlyManifest,
      scenarioCatalogEvidence: catalogEvidence,
      policy: policy,
    );
    final loadedOnlyReport = _tuningReportJson(
      run: EvalRunArtifacts(
        manifest: loadedOnlyManifest,
        traces: [loadedOnlyTrace],
        artifactNames: const [],
      ),
      scenarios: [privateScenario],
      profiles: const [kFrontierProfile],
      promptVariants: const [EvalAgentDirectiveVariant()],
      readiness: loadedOnlyReadiness,
      calibrationReport: null,
      pairwiseReadinessPlan: null,
      pairwisePreferenceVotes: const [],
      promotionDecision: null,
      catalogEvidence: catalogEvidence,
    );
    final loadedOnlyEncoded = const JsonEncoder().convert(loadedOnlyReport);

    expect(loadedOnlyEncoded, isNot(contains(protectedId)));
    expect(loadedOnlyEncoded, contains('<redacted-scenario-001>'));
    expect(
      (loadedOnlyReport['run'] as Map<String, dynamic>)['protectedIdsRedacted'],
      isTrue,
    );
  });

  test(
    'tuning report writer persists verified run report and guards overwrite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_tuning_report_writer_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final writer = TraceWriter(runsRoot: p.join(directory.path, 'runs'));
      const policy = EvalTuningPolicy.modelClassTuning();
      final manifest = EvalProvenance.captureRunManifest(
        runId: 'tuning-report-writer-test',
        targetName: 'tuning-report-writer-fixture',
        targetKind: 'test',
        scenarios: [taskReleaseNotesScenario],
        profiles: kDefaultProfiles,
        createdAt: DateTime.utc(2026, 6, 10, 12),
        command: 'tuning report writer fixture',
        environment: const <String, String>{},
        tuningReadinessPolicyEvidence: EvalTuningReadinessPolicyEvidence(
          policyName: policy.name,
          policyDigest: policy.policyDigest,
        ),
      );
      await writer.writeManifest(manifest);
      for (final profile in kDefaultProfiles) {
        for (
          var trialIndex = 0;
          trialIndex < profile.trialCount;
          trialIndex++
        ) {
          final traceFile = await writer.writeTrace(
            _promotionTraceForProfile(
              profile,
              runId: manifest.runId,
              trialIndex: trialIndex,
              manifestDigest: manifest.manifestDigest,
              output: _promotionOutputForProfile(profile),
            ),
          );
          await writer.writeVerdict(
            traceFile,
            _promotionVerdict(
              goalAttainment: 5,
              quality: 5,
              efficiency: 4,
            ),
          );
        }
      }
      final catalog = EvalScenarioCatalog(
        scenarios: [taskReleaseNotesScenario],
        evidence: EvalScenarioCatalogEvidence(
          scenarioSetDigest: manifest.scenarioSetDigest,
          publicScenarioCount: 1,
          externalScenarioCount: 0,
          protectedHoldout: false,
          protectedScenarioIds: const [],
          protectedHoldoutScenarioIds: const [],
        ),
        sourceDescription: 'tuning report writer fixture',
      );
      final outputPath = p.join(
        writer.runDir(manifest.runId),
        'tuning_report.json',
      );

      final file = await _writeTuningReportForRun(
        writer: writer,
        runId: manifest.runId,
        tuningReportPath: outputPath,
        overwrite: false,
        catalog: catalog,
        profiles: kDefaultProfiles,
        promptVariants: const [EvalAgentDirectiveVariant()],
      );
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      expect(decoded['kind'], 'lotti.evalTuningReport');
      expect(decoded['run'], containsPair('runId', manifest.runId));
      expect(decoded['policy'], containsPair('digest', policy.policyDigest));
      expect(decoded['nextExperimentPlan'], isA<Map<String, dynamic>>());
      final firstSnapshot =
          (decoded['run'] as Map<String, dynamic>)['artifactSnapshot']
              as Map<String, dynamic>;

      final contentsBeforeOverwriteAttempt = await file.readAsString();
      await expectLater(
        _writeTuningReportForRun(
          writer: writer,
          runId: manifest.runId,
          tuningReportPath: outputPath,
          overwrite: false,
          catalog: catalog,
          profiles: kDefaultProfiles,
          promptVariants: const [EvalAgentDirectiveVariant()],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Refusing to overwrite existing tuning report'),
          ),
        ),
      );
      expect(await file.readAsString(), contentsBeforeOverwriteAttempt);
      await File(
        p.join(writer.runDir(manifest.runId), 'operator-notes.md'),
      ).writeAsString('sidecar notes');

      final firstOverwrite = await _writeTuningReportForRun(
        writer: writer,
        runId: manifest.runId,
        tuningReportPath: outputPath,
        overwrite: true,
        catalog: catalog,
        profiles: kDefaultProfiles,
        promptVariants: const [EvalAgentDirectiveVariant()],
      );
      final firstOverwriteJson =
          jsonDecode(await firstOverwrite.readAsString())
              as Map<String, dynamic>;
      final firstOverwriteSnapshot =
          (firstOverwriteJson['run']
                  as Map<String, dynamic>)['artifactSnapshot']
              as Map<String, dynamic>;
      expect(firstOverwriteSnapshot, firstSnapshot);

      final secondOverwrite = await _writeTuningReportForRun(
        writer: writer,
        runId: manifest.runId,
        tuningReportPath: outputPath,
        overwrite: true,
        catalog: catalog,
        profiles: kDefaultProfiles,
        promptVariants: const [EvalAgentDirectiveVariant()],
      );
      final secondOverwriteJson =
          jsonDecode(await secondOverwrite.readAsString())
              as Map<String, dynamic>;
      expect(
        (secondOverwriteJson['run']
            as Map<String, dynamic>)['artifactSnapshot'],
        firstOverwriteSnapshot,
      );
    },
  );

  test(
    'catalog preflight writer persists contract report and guards overwrite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_catalog_preflight_writer_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final scenarios = [taskReleaseNotesScenario];
      final catalog = EvalScenarioCatalog(
        scenarios: scenarios,
        evidence: EvalScenarioCatalogEvidence(
          scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
          publicScenarioCount: scenarios.length,
          externalScenarioCount: 0,
          protectedHoldout: false,
          protectedScenarioIds: const [],
          protectedHoldoutScenarioIds: const [],
        ),
        sourceDescription: 'catalog preflight writer fixture',
      );
      final outputPath = p.join(directory.path, 'catalog_preflight.json');

      final file = await _writeScenarioCatalogPreflightReport(
        preflightReportPath: outputPath,
        overwrite: false,
        catalog: catalog,
        profiles: kDefaultProfiles,
        catalogMode: 'append',
        selectedSubset: false,
      );
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      expect(decoded['kind'], EvalScenarioCatalogPreflight.kind);
      expect(decoded['nextExperimentPlan'], isA<Map<String, dynamic>>());
      expect(EvalScenarioCatalogPreflight.validate(decoded), isEmpty);

      final contentsBeforeOverwriteAttempt = await file.readAsString();
      await expectLater(
        _writeScenarioCatalogPreflightReport(
          preflightReportPath: outputPath,
          overwrite: false,
          catalog: catalog,
          profiles: kDefaultProfiles,
          catalogMode: 'append',
          selectedSubset: false,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Refusing to overwrite existing scenario catalog preflight '
              'report',
            ),
          ),
        ),
      );
      expect(await file.readAsString(), contentsBeforeOverwriteAttempt);

      final overwritten = await _writeScenarioCatalogPreflightReport(
        preflightReportPath: outputPath,
        overwrite: true,
        catalog: catalog,
        profiles: kDefaultProfiles,
        catalogMode: 'append',
        selectedSubset: true,
      );
      final overwrittenJson =
          jsonDecode(await overwritten.readAsString()) as Map<String, dynamic>;
      expect(
        (overwrittenJson['selection']
            as Map<String, dynamic>)['selectedSubset'],
        isTrue,
      );
    },
  );

  test(
    'tuning report writer applies protected output guard before writing',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_tuning_report_guard_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final writer = TraceWriter(runsRoot: p.join(directory.path, 'runs'));
      final scenario = _privateHoldoutScenario('private_writer_holdout');
      final catalogEvidence = EvalScenarioCatalogEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        publicScenarioCount: 0,
        externalScenarioCount: 1,
        externalCatalogDigest: EvalProvenance.digestText(
          'private-writer-catalog',
        ),
        externalCatalogId: 'private-writer-fixture',
        externalSourceLabel: 'private_writer_scenarios.json',
        protectedHoldout: true,
        protectedScenarioIds: [scenario.id],
        protectedHoldoutScenarioIds: [scenario.id],
      );
      const policy = EvalTuningPolicy.modelClassTuning();
      final manifest = EvalProvenance.captureRunManifest(
        runId: 'private-writer-run',
        targetName: 'private-writer-fixture',
        targetKind: 'test',
        scenarios: [scenario],
        profiles: const [kFrontierProfile],
        scenarioCatalogEvidence: catalogEvidence,
        createdAt: DateTime.utc(2026, 6, 10, 12),
        command: 'private writer fixture',
        environment: const <String, String>{},
        tuningReadinessPolicyEvidence: EvalTuningReadinessPolicyEvidence(
          policyName: policy.name,
          policyDigest: policy.policyDigest,
        ),
      );
      await writer.writeManifest(manifest);
      for (
        var trialIndex = 0;
        trialIndex < kFrontierProfile.trialCount;
        trialIndex++
      ) {
        final traceFile = await writer.writeTrace(
          _promotionTraceForProfile(
            kFrontierProfile,
            scenario: scenario,
            runId: manifest.runId,
            trialIndex: trialIndex,
            manifestDigest: manifest.manifestDigest,
            output: _promotionOutputForProfile(kFrontierProfile),
          ),
        );
        await writer.writeVerdict(
          traceFile,
          _promotionVerdict(
            goalAttainment: 5,
            quality: 5,
            efficiency: 4,
          ),
        );
      }
      final catalog = EvalScenarioCatalog(
        scenarios: [scenario],
        evidence: catalogEvidence,
        sourceDescription: 'private writer fixture',
      );
      final inRepoFile = File(
        p.join(
          Directory.current.path,
          '.dart_tool',
          'lotti_eval_tuning_report_guard_fixture.json',
        ),
      );
      if (inRepoFile.existsSync()) {
        inRepoFile.deleteSync();
      }
      addTearDown(() {
        if (inRepoFile.existsSync()) inRepoFile.deleteSync();
      });

      await expectLater(
        _writeTuningReportForRun(
          writer: writer,
          runId: manifest.runId,
          tuningReportPath: inRepoFile.path,
          overwrite: false,
          catalog: catalog,
          profiles: const [kFrontierProfile],
          promptVariants: const [EvalAgentDirectiveVariant()],
          protectedTraceAck: '0',
        ),
        throwsStateError,
      );
      expect(inRepoFile.existsSync(), isFalse);

      final file = await _writeTuningReportForRun(
        writer: writer,
        runId: manifest.runId,
        tuningReportPath: inRepoFile.path,
        overwrite: false,
        catalog: catalog,
        profiles: const [kFrontierProfile],
        promptVariants: const [EvalAgentDirectiveVariant()],
        protectedTraceAck: '1',
      );
      final encoded = await file.readAsString();

      expect(encoded, isNot(contains(scenario.id)));
      expect(encoded, contains('<redacted-scenario-001>'));
    },
  );

  test(
    'run_level2 tune verifies before writing and forwards defines',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_tune_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'runs');
      final reportPath = p.join(directory.path, 'report.json');
      final calibrationPath = p.join(directory.path, 'calibration.json');
      final readinessPlanPath = p.join(directory.path, 'pairwise_plan.json');
      final scenarioCatalogPath = p.join(directory.path, 'scenarios.json');
      final profileCatalogPath = p.join(directory.path, 'profiles.json');
      final promptVariantCatalogPath = p.join(
        directory.path,
        'prompt_variants.json',
      );
      final promotionPlanPath = p.join(directory.path, 'promotion_plan.json');
      final baseEnvironment = <String, String>{
        'PATH':
            '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
        'FAKE_FVM_LOG': logFile.path,
        'EVAL_RUNS_ROOT': runsRoot,
        'EVAL_SCENARIOS': scenarioCatalogPath,
        'EVAL_SCENARIOS_MODE': 'replace',
        'EVAL_PROFILES': profileCatalogPath,
        'EVAL_PROMPT_VARIANTS': promptVariantCatalogPath,
        'EVAL_TUNING_REPORT': reportPath,
        'EVAL_TUNING_REPORT_OVERWRITE': '1',
        'EVAL_CALIBRATION': calibrationPath,
        'EVAL_PAIRWISE_READINESS_PLAN': readinessPlanPath,
        'EVAL_PROMOTION_PLAN': promotionPlanPath,
        'EVAL_PROMOTION_CANDIDATE_PROFILE': 'frontier-gemini',
        'EVAL_PROMOTION_BASELINE_PROFILE': 'frontier-fast',
        'EVAL_SCENARIO_IDS': 'task_workflow_structured_update',
        'EVAL_PROFILE_NAMES': 'frontier-gemini',
        'EVAL_PROMPT_VARIANT_NAMES': 'default',
        'LOTTI_EVAL_PROTECTED_TRACE_ACK': '1',
      };

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'tune', 'script-tune-run'],
        environment: baseEnvironment,
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(result.stdout.toString(), contains('tuning report: $reportPath'));
      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(2));
      expect(
        _plainNameFromFakeFvmCall(calls[0]),
        'verifies complete trace/verdict matrix for an eval run',
      );
      expect(
        _plainNameFromFakeFvmCall(calls[1]),
        'writes machine-readable tuning report',
      );
      final sharedDefineArgs = [
        '--dart-define=EVAL_RUN=script-tune-run',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
        '--dart-define=EVAL_SCENARIOS=$scenarioCatalogPath',
        '--dart-define=EVAL_SCENARIOS_MODE=replace',
        '--dart-define=EVAL_PROFILES=$profileCatalogPath',
        '--dart-define=EVAL_PROMPT_VARIANTS=$promptVariantCatalogPath',
        '--dart-define=EVAL_PROMOTION_PLAN=$promotionPlanPath',
        '--dart-define=EVAL_PAIRWISE_READINESS_PLAN=$readinessPlanPath',
        '--dart-define=EVAL_SCENARIO_IDS=task_workflow_structured_update',
        '--dart-define=EVAL_PROFILE_NAMES=frontier-gemini',
        '--dart-define=EVAL_PROMPT_VARIANT_NAMES=default',
        '--dart-define=LOTTI_EVAL_PROTECTED_TRACE_ACK=1',
      ];
      _expectFakeFvmCallContains(calls[0], sharedDefineArgs);
      _expectFakeFvmCallContains(calls[1], [
        ...sharedDefineArgs,
        '--dart-define=EVAL_TUNING_REPORT=$reportPath',
        '--dart-define=EVAL_TUNING_REPORT_OVERWRITE=1',
        '--dart-define=EVAL_CALIBRATION=$calibrationPath',
        '--dart-define=EVAL_PROMOTION_CANDIDATE_PROFILE=frontier-gemini',
        '--dart-define=EVAL_PROMOTION_BASELINE_PROFILE=frontier-fast',
      ]);

      await logFile.writeAsString('');
      final failedResult = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'tune', 'script-tune-run'],
        environment: {
          ...baseEnvironment,
          'FAKE_VERIFY_FAIL': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(failedResult.exitCode, 42, reason: _processReason(failedResult));
      final failedCalls = await _readFakeFvmCalls(logFile);
      expect(failedCalls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(failedCalls.single),
        'verifies complete trace/verdict matrix for an eval run',
      );
    },
  );

  test(
    'run_level2 catalog can write machine-readable preflight report',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_catalog_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'runs');
      final scenarioCatalogPath = p.join(directory.path, 'scenarios.json');
      final profileCatalogPath = p.join(directory.path, 'profiles.json');
      final reportPath = p.join(directory.path, 'catalog_preflight.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'catalog'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_SCENARIOS': scenarioCatalogPath,
          'EVAL_SCENARIOS_MODE': 'replace',
          'EVAL_SCENARIO_IDS': 'task_workflow_structured_update',
          'EVAL_PROFILES': profileCatalogPath,
          'EVAL_CATALOG_PREFLIGHT_REPORT': reportPath,
          'EVAL_CATALOG_PREFLIGHT_REPORT_OVERWRITE': '1',
          'LOTTI_EVAL_PROTECTED_TRACE_ACK': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('catalog preflight report: set (path omitted)'),
      );
      expect(
        result.stdout.toString(),
        contains('scenario ids: set (omitted for external catalog safety)'),
      );
      expect(
        result.stdout.toString(),
        isNot(contains('task_workflow_structured_update')),
      );
      expect(result.stdout.toString(), isNot(contains(reportPath)));
      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(2));
      expect(
        _plainNameFromFakeFvmCall(calls[0]),
        'writes machine-readable scenario catalog preflight report',
      );
      expect(
        _plainNameFromFakeFvmCall(calls[1]),
        'renders scenario catalog preflight',
      );
      final expectedDefineArgs = [
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
        '--dart-define=EVAL_SCENARIOS=$scenarioCatalogPath',
        '--dart-define=EVAL_SCENARIOS_MODE=replace',
        '--dart-define=EVAL_SCENARIO_IDS=task_workflow_structured_update',
        '--dart-define=EVAL_PROFILES=$profileCatalogPath',
        '--dart-define=LOTTI_EVAL_PROTECTED_TRACE_ACK=1',
        '--dart-define=EVAL_CATALOG_PREFLIGHT_REPORT=$reportPath',
        '--dart-define=EVAL_CATALOG_PREFLIGHT_REPORT_OVERWRITE=1',
      ];
      _expectFakeFvmCallContains(calls[0], expectedDefineArgs);
      _expectFakeFvmCallContains(calls[1], expectedDefineArgs);
    },
  );

  test(
    'run_level2 evidence-intake forwards report inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_evidence_intake_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final inputA = p.join(directory.path, 'private-a.json');
      final inputB = p.join(directory.path, 'private-b.json');
      final intakePath = p.join(directory.path, 'evidence_intake.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'evidence-intake'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_TUNING_REPORTS': '$inputA,$inputB',
          'EVAL_TUNING_EVIDENCE_INTAKE_PLAN': intakePath,
          'EVAL_TUNING_EVIDENCE_INTAKE_PLAN_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('tuning evidence intake plan'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'tuning portfolio inputs: set (paths omitted)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'tuning evidence intake plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      for (final path in [inputA, inputB, intakePath]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes tuning evidence intake plan',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_TUNING_REPORTS=$inputA,$inputB',
        '--dart-define=EVAL_TUNING_EVIDENCE_INTAKE_PLAN=$intakePath',
        '--dart-define=EVAL_TUNING_EVIDENCE_INTAKE_PLAN_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 use-case-matrix forwards report inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_matrix_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final inputA = p.join(directory.path, 'private-a.json');
      final inputB = p.join(directory.path, 'private-b.json');
      final reportPath = p.join(directory.path, 'use_case_matrix.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'use-case-matrix'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_TUNING_REPORTS': '$inputA,$inputB',
          'EVAL_USE_CASE_MATRIX_REPORT': reportPath,
          'EVAL_USE_CASE_MATRIX_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(result.stdout.toString(), contains('use-case tuning matrix'));
      expect(
        result.stdout.toString(),
        contains('tuning portfolio inputs: set (paths omitted)'),
      );
      expect(
        result.stdout.toString(),
        contains('use-case matrix report: set (path omitted)'),
      );
      expect(result.stdout.toString(), isNot(contains(inputA)));
      expect(result.stdout.toString(), isNot(contains(inputB)));
      expect(result.stdout.toString(), isNot(contains(reportPath)));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning matrix report',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_TUNING_REPORTS=$inputA,$inputB',
        '--dart-define=EVAL_USE_CASE_MATRIX_REPORT=$reportPath',
        '--dart-define=EVAL_USE_CASE_MATRIX_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 experiment-plan forwards matrix input without stdout path',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_experiment_plan_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final inputPath = p.join(directory.path, 'private-use-case-matrix.json');
      final planPath = p.join(directory.path, 'use_case_experiment_plan.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'experiment-plan'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_USE_CASE_MATRIX_INPUT': inputPath,
          'EVAL_USE_CASE_EXPERIMENT_PLAN': planPath,
          'EVAL_USE_CASE_EXPERIMENT_PLAN_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(result.stdout.toString(), contains('use-case experiment plan'));
      expect(
        result.stdout.toString(),
        contains(
          'use-case matrix input: set (path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case experiment plan: set (path omitted for matrix privacy)',
        ),
      );
      expect(result.stdout.toString(), isNot(contains(inputPath)));
      expect(result.stdout.toString(), isNot(contains(planPath)));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case experiment plan',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_MATRIX_INPUT=$inputPath',
        '--dart-define=EVAL_USE_CASE_EXPERIMENT_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_EXPERIMENT_PLAN_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 next-run-work-order forwards plan input without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_next_run_work_order_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final inputPath = p.join(directory.path, 'private-experiment-plan.json');
      final workOrderPath = p.join(
        directory.path,
        'use_case_next_run_work_order.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'next-run-work-order'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_INPUT': inputPath,
          'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER': workOrderPath,
          'EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case next-run work order'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case next-run work order input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case next-run work order: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(result.stdout.toString(), isNot(contains(inputPath)));
      expect(result.stdout.toString(), isNot(contains(workOrderPath)));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case next-run work order',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_INPUT=$inputPath',
        '--dart-define=EVAL_USE_CASE_NEXT_RUN_WORK_ORDER=$workOrderPath',
        '--dart-define=EVAL_USE_CASE_NEXT_RUN_WORK_ORDER_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 model-class-evidence forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_model_class_evidence_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final workOrderPath = p.join(
        directory.path,
        'private-next-run-work-order.json',
      );
      final experimentPlanPath = p.join(
        directory.path,
        'private-experiment-plan.json',
      );
      final evidencePath = p.join(
        directory.path,
        'private-model-class-execution-evidence.json',
      );
      const runIds = 'private-run-a,private-run-b';

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'model-class-evidence'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_WORK_ORDER': workOrderPath,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN':
              experimentPlanPath,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS': runIds,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE': evidencePath,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case model-class execution evidence'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution work order: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution experiment plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution runs: set '
          '(ids omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution evidence: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(result.stdout.toString(), isNot(contains(workOrderPath)));
      expect(result.stdout.toString(), isNot(contains(experimentPlanPath)));
      expect(result.stdout.toString(), isNot(contains(evidencePath)));
      expect(result.stdout.toString(), isNot(contains('private-run-a')));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case model-class execution evidence',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_WORK_ORDER=$workOrderPath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN=$experimentPlanPath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS=$runIds',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE=$evidencePath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 model-class-coverage forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_model_class_coverage_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final workOrderPath = p.join(
        directory.path,
        'private-next-run-work-order.json',
      );
      final experimentPlanPath = p.join(
        directory.path,
        'private-experiment-plan.json',
      );
      final evidencePath = p.join(
        directory.path,
        'private-model-class-execution-evidence.json',
      );
      final coveragePath = p.join(
        directory.path,
        'use_case_model_class_coverage.json',
      );
      const runIds = 'private-run-a,private-run-b';

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'model-class-coverage'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER': workOrderPath,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN':
              experimentPlanPath,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS': runIds,
          'EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE': evidencePath,
          'EVAL_USE_CASE_MODEL_CLASS_COVERAGE': coveragePath,
          'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case model-class execution coverage'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class coverage work order: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution experiment plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution runs: set '
          '(ids omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution evidence: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution coverage: set '
          '(path omitted for matrix privacy)',
        ),
      );
      for (final path in [
        workOrderPath,
        experimentPlanPath,
        evidencePath,
        coveragePath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }
      expect(result.stdout.toString(), isNot(contains('private-run-a')));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case model-class execution coverage',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER=$workOrderPath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN=$experimentPlanPath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_EVIDENCE=$evidencePath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_EXECUTION_RUNS=$runIds',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_COVERAGE=$coveragePath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_COVERAGE_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 campaign forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_campaign_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final planPath = p.join(directory.path, 'private-experiment-plan.json');
      final reportA = p.join(directory.path, 'private-followup-a.json');
      final reportB = p.join(directory.path, 'private-followup-b.json');
      final coveragePath = p.join(
        directory.path,
        'private-model-class-coverage.json',
      );
      final coverageWorkOrderPath = p.join(
        directory.path,
        'private-model-class-work-order.json',
      );
      final campaignPath = p.join(directory.path, 'use_case_campaign.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'campaign'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_USE_CASE_EXPERIMENT_PLAN_INPUT': planPath,
          'EVAL_TUNING_REPORTS': '$reportA,$reportB',
          'EVAL_USE_CASE_MODEL_CLASS_COVERAGE': coveragePath,
          'EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER':
              coverageWorkOrderPath,
          'EVAL_USE_CASE_CAMPAIGN_REPORT': campaignPath,
          'EVAL_USE_CASE_CAMPAIGN_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(result.stdout.toString(), contains('use-case tuning campaign'));
      expect(
        result.stdout.toString(),
        contains(
          'use-case experiment plan input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains('tuning portfolio inputs: set (paths omitted)'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class coverage work order: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case model-class execution coverage: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case campaign report: set (path omitted for matrix privacy)',
        ),
      );
      expect(result.stdout.toString(), isNot(contains(planPath)));
      expect(result.stdout.toString(), isNot(contains(reportA)));
      expect(result.stdout.toString(), isNot(contains(reportB)));
      expect(result.stdout.toString(), isNot(contains(coveragePath)));
      expect(result.stdout.toString(), isNot(contains(coverageWorkOrderPath)));
      expect(result.stdout.toString(), isNot(contains(campaignPath)));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning campaign',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_EXPERIMENT_PLAN_INPUT=$planPath',
        '--dart-define=EVAL_TUNING_REPORTS=$reportA,$reportB',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_COVERAGE=$coveragePath',
        '--dart-define=EVAL_USE_CASE_MODEL_CLASS_COVERAGE_WORK_ORDER=$coverageWorkOrderPath',
        '--dart-define=EVAL_USE_CASE_CAMPAIGN_REPORT=$campaignPath',
        '--dart-define=EVAL_USE_CASE_CAMPAIGN_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 review-packet forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_review_packet_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final sourcePath = p.join(directory.path, 'private-campaign.json');
      final packetPath = p.join(directory.path, 'review_packet.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'review-packet'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_ADVERSARIAL_REVIEW_SOURCE': sourcePath,
          'EVAL_ADVERSARIAL_REVIEW_PACKET': packetPath,
          'EVAL_ADVERSARIAL_REVIEW_PACKET_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case adversarial review packet'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'adversarial review source: set (path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'adversarial review packet: set (path omitted for matrix privacy)',
        ),
      );
      expect(result.stdout.toString(), isNot(contains(sourcePath)));
      expect(result.stdout.toString(), isNot(contains(packetPath)));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case adversarial review packet',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_SOURCE=$sourcePath',
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_PACKET=$packetPath',
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_PACKET_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 import-review forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_import_review_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final sourcePath = p.join(directory.path, 'private-campaign.json');
      final inputPath = p.join(directory.path, 'private-completed-review.json');
      final attestationsPath = p.join(
        directory.path,
        'review_attestations.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'import-review'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_ADVERSARIAL_REVIEW_SOURCE': sourcePath,
          'EVAL_ADVERSARIAL_REVIEW_INPUT': inputPath,
          'EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS': attestationsPath,
          'EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case adversarial review import'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'adversarial review source: set (path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'adversarial review input: set (path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'adversarial review attestations: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(result.stdout.toString(), isNot(contains(sourcePath)));
      expect(result.stdout.toString(), isNot(contains(inputPath)));
      expect(result.stdout.toString(), isNot(contains(attestationsPath)));

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case adversarial review attestation bundle',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_SOURCE=$sourcePath',
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_INPUT=$inputPath',
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS=$attestationsPath',
        '--dart-define=EVAL_ADVERSARIAL_REVIEW_ATTESTATIONS_OVERWRITE=1',
      ]);
    },
  );

  test(
    'run_level2 decision-gate forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_decision_gate_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final matrixPath = p.join(
        directory.path,
        'private-refreshed-matrix.json',
      );
      final matrixReportAPath = p.join(
        directory.path,
        'private-matrix-report-a.json',
      );
      final matrixReportBPath = p.join(
        directory.path,
        'private-matrix-report-b.json',
      );
      final matrixReportPaths = '$matrixReportAPath,$matrixReportBPath';
      final campaignPath = p.join(directory.path, 'private-campaign.json');
      final campaignPlanPath = p.join(
        directory.path,
        'private-campaign-plan.json',
      );
      final campaignReportPath = p.join(
        directory.path,
        'private-campaign-report.json',
      );
      final previousPath = p.join(directory.path, 'private-previous.json');
      final reviewPath = p.join(directory.path, 'private-review.json');
      final ledgerPath = p.join(directory.path, 'decision_ledger.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'decision-gate'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_DECISION_MATRIX_INPUT': matrixPath,
          'EVAL_USE_CASE_DECISION_MATRIX_REPORTS': matrixReportPaths,
          'EVAL_USE_CASE_DECISION_CAMPAIGN_INPUT': campaignPath,
          'EVAL_USE_CASE_DECISION_CAMPAIGN_EXPERIMENT_PLAN_INPUT':
              campaignPlanPath,
          'EVAL_USE_CASE_DECISION_CAMPAIGN_REPORTS': campaignReportPath,
          'EVAL_USE_CASE_PREVIOUS_DECISION_LEDGER': previousPath,
          'EVAL_USE_CASE_DECISION_REVIEW_ATTESTATIONS': reviewPath,
          'EVAL_USE_CASE_DECISION_LEDGER': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case tuning decision gate'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision matrix input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision matrix source reports: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision campaign input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision campaign source reports: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'previous use-case decision ledger: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision review attestations: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger: set (path omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        matrixPath,
        matrixReportAPath,
        matrixReportBPath,
        campaignPath,
        campaignPlanPath,
        campaignReportPath,
        previousPath,
        reviewPath,
        ledgerPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning decision ledger',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_DECISION_MATRIX_INPUT=$matrixPath',
        '--dart-define=EVAL_USE_CASE_DECISION_MATRIX_REPORTS=$matrixReportPaths',
        '--dart-define=EVAL_USE_CASE_DECISION_CAMPAIGN_INPUT=$campaignPath',
        '--dart-define=EVAL_USE_CASE_DECISION_CAMPAIGN_EXPERIMENT_PLAN_INPUT=$campaignPlanPath',
        '--dart-define=EVAL_USE_CASE_DECISION_CAMPAIGN_REPORTS=$campaignReportPath',
        '--dart-define=EVAL_USE_CASE_DECISION_MODEL_CLASS_COVERAGE=',
        '--dart-define=EVAL_USE_CASE_DECISION_MODEL_CLASS_COVERAGE_WORK_ORDER=',
        '--dart-define=EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_EXPERIMENT_PLAN=',
        '--dart-define=EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_EVIDENCE=',
        '--dart-define=EVAL_USE_CASE_DECISION_MODEL_CLASS_EXECUTION_RUNS=',
        '--dart-define=EVAL_USE_CASE_PREVIOUS_DECISION_LEDGER=$previousPath',
        '--dart-define=EVAL_USE_CASE_DECISION_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 roadmap forwards ledgers without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_roadmap_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final ledgerA = p.join(directory.path, 'private-ledger-a.json');
      final ledgerB = p.join(directory.path, 'private-ledger-b.json');
      final manifestA = p.join(directory.path, 'private-ledger-a.sources.json');
      final manifestB = p.join(directory.path, 'private-ledger-b.sources.json');
      final manifestPaths = '$manifestA,$manifestB';
      final roadmapPath = p.join(directory.path, 'tuning_roadmap.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'roadmap'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_DECISION_LEDGERS': '$ledgerA,$ledgerB',
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': manifestPaths,
          'EVAL_USE_CASE_TUNING_ROADMAP': roadmapPath,
          'EVAL_USE_CASE_TUNING_ROADMAP_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case tuning roadmap'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledgers: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case tuning roadmap: set (path omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        ledgerA,
        ledgerB,
        manifestA,
        manifestB,
        roadmapPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning roadmap',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGERS=$ledgerA,$ledgerB',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$manifestPaths',
        '--dart-define=EVAL_USE_CASE_TUNING_ROADMAP=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_TUNING_ROADMAP_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 release-plan forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_release_plan_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerA = p.join(directory.path, 'private-ledger-a.json');
      final ledgerB = p.join(directory.path, 'private-ledger-b.json');
      final sourceManifestA = p.join(
        directory.path,
        'private-ledger-a.sources.json',
      );
      final sourceManifestB = p.join(
        directory.path,
        'private-ledger-b.sources.json',
      );
      final sourceManifestPaths = '$sourceManifestA,$sourceManifestB';
      final previousPath = p.join(directory.path, 'private-previous-plan.json');
      final runtimeLedgerPath = p.join(
        directory.path,
        'private-runtime-ledger.json',
      );
      final runtimeReleaseGatePath = p.join(
        directory.path,
        'private-runtime-release-gate.json',
      );
      final runtimeReleaseReviewPath = p.join(
        directory.path,
        'private-runtime-release-review.json',
      );
      final runtimeVerificationPath = p.join(
        directory.path,
        'private-runtime-verification.json',
      );
      final runtimeResolverSnapshotPath = p.join(
        directory.path,
        'private-runtime-resolver-snapshot.json',
      );
      final runtimeResolverPacketPath = p.join(
        directory.path,
        'private-runtime-resolver-packet.json',
      );
      final runtimeResolverInputPath = p.join(
        directory.path,
        'private-runtime-resolver-input.json',
      );
      final releasePlanPath = p.join(directory.path, 'release_plan.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'release-plan'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RELEASE_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RELEASE_DECISION_LEDGERS': '$ledgerA,$ledgerB',
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPaths,
          'EVAL_USE_CASE_PREVIOUS_RELEASE_PLAN': previousPath,
          'EVAL_USE_CASE_RUNTIME_ROLLOUT_LEDGERS': runtimeLedgerPath,
          'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RELEASE_GATES':
              runtimeReleaseGatePath,
          'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS':
              runtimeReleaseReviewPath,
          'EVAL_USE_CASE_RELEASE_RUNTIME_VERIFICATIONS':
              runtimeVerificationPath,
          'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS':
              runtimeResolverSnapshotPath,
          'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_PACKETS':
              runtimeResolverPacketPath,
          'EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_INPUTS':
              runtimeResolverInputPath,
          'EVAL_USE_CASE_RELEASE_PLAN': releasePlanPath,
          'EVAL_USE_CASE_RELEASE_PLAN_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case tuning release plan'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release roadmap input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release decision ledgers: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'previous use-case release plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime rollout ledgers: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release plan: set (path omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        roadmapPath,
        ledgerA,
        ledgerB,
        sourceManifestA,
        sourceManifestB,
        previousPath,
        runtimeLedgerPath,
        runtimeReleaseGatePath,
        runtimeReleaseReviewPath,
        runtimeVerificationPath,
        runtimeResolverSnapshotPath,
        runtimeResolverPacketPath,
        runtimeResolverInputPath,
        releasePlanPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning release plan',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RELEASE_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_DECISION_LEDGERS=$ledgerA,$ledgerB',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPaths',
        '--dart-define=EVAL_USE_CASE_PREVIOUS_RELEASE_PLAN=$previousPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_ROLLOUT_LEDGERS=$runtimeLedgerPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RELEASE_GATES=$runtimeReleaseGatePath',
        '--dart-define=EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS=$runtimeReleaseReviewPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_RUNTIME_VERIFICATIONS=$runtimeVerificationPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS=$runtimeResolverSnapshotPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_PACKETS=$runtimeResolverPacketPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_RUNTIME_LEDGER_RESOLVER_INPUTS=$runtimeResolverInputPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_PLAN=$releasePlanPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_PLAN_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 release-review-packet forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_release_review_packet_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final sourcePath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final packetPath = p.join(directory.path, 'release_review_packet.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'release-review-packet'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RELEASE_REVIEW_SOURCE': sourcePath,
          'EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_PACKET': packetPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_PACKET_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case tuning release review packet'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release review source: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release review packet: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        sourcePath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        packetPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning release review packet',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_SOURCE=$sourcePath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_PACKET=$packetPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_PACKET_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 import-release-review forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_release_review_import_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final sourcePath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final inputPath = p.join(directory.path, 'completed_review.json');
      final attestationsPath = p.join(
        directory.path,
        'release_review_attestations.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'import-release-review'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RELEASE_REVIEW_SOURCE': sourcePath,
          'EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_INPUT': inputPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS': attestationsPath,
          'EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case tuning release review import'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release review source: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release review input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release review attestations: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        sourcePath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        inputPath,
        attestationsPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning release review attestation bundle',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_SOURCE=$sourcePath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_INPUT=$inputPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS=$attestationsPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_REVIEW_ATTESTATIONS_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 release-gate forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_release_gate_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final attestationsA = p.join(
        directory.path,
        'private-release-review-a.json',
      );
      final attestationsB = p.join(
        directory.path,
        'private-release-review-b.json',
      );
      final gatePath = p.join(directory.path, 'release_gate.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'release-gate'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RELEASE_GATE_PLAN_INPUT': planPath,
          'EVAL_USE_CASE_RELEASE_GATE_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RELEASE_GATE_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RELEASE_GATE_REVIEW_ATTESTATIONS':
              '$attestationsA,$attestationsB',
          'EVAL_USE_CASE_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RELEASE_GATE_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case tuning release gate'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release gate plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release gate review attestations: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case release gate: set (path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        attestationsA,
        attestationsB,
        gatePath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case tuning release gate',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RELEASE_GATE_PLAN_INPUT=$planPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_GATE_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_GATE_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RELEASE_GATE_REVIEW_ATTESTATIONS=$attestationsA,$attestationsB',
        '--dart-define=EVAL_USE_CASE_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RELEASE_GATE_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 runtime-verify forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_runtime_verify_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final gatePath = p.join(directory.path, 'private-release-gate.json');
      final reviewPath = p.join(
        directory.path,
        'private-release-review.json',
      );
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final resolverPacketPath = p.join(
        directory.path,
        'private-runtime-resolver-packet.json',
      );
      final resolverInputPath = p.join(
        directory.path,
        'private-runtime-resolver-input.json',
      );
      final resolverSnapshotPath = p.join(
        directory.path,
        'private-runtime-resolver-snapshot.json',
      );
      final verificationPath = p.join(
        directory.path,
        'runtime_verification.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'runtime-verify'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_PLAN': planPath,
          'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_REVIEW_ATTESTATIONS':
              reviewPath,
          'EVAL_USE_CASE_RUNTIME_VERIFY_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RUNTIME_VERIFY_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET': resolverPacketPath,
          'EVAL_USE_CASE_RUNTIME_VERIFY_RESOLVER_INPUTS': resolverInputPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT': resolverSnapshotPath,
          'EVAL_USE_CASE_RUNTIME_VERIFICATION': verificationPath,
          'EVAL_USE_CASE_RUNTIME_VERIFICATION_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case runtime verification'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime verification release plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime verification release gate: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver snapshot: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime verification: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        gatePath,
        reviewPath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        resolverPacketPath,
        resolverInputPath,
        resolverSnapshotPath,
        verificationPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case runtime verification',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFY_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFY_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=$resolverPacketPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFY_RESOLVER_INPUTS=$resolverInputPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT=$resolverSnapshotPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFICATION=$verificationPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFICATION_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 runtime-ledger forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_runtime_ledger_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final gatePath = p.join(directory.path, 'private-release-gate.json');
      final reviewPath = p.join(
        directory.path,
        'private-release-review.json',
      );
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerSourcePath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final verificationA = p.join(
        directory.path,
        'runtime_verification_a.json',
      );
      final verificationB = p.join(
        directory.path,
        'runtime_verification_b.json',
      );
      final resolverSnapshotA = p.join(
        directory.path,
        'runtime_resolver_snapshot_a.json',
      );
      final resolverSnapshotB = p.join(
        directory.path,
        'runtime_resolver_snapshot_b.json',
      );
      final resolverPacketA = p.join(
        directory.path,
        'runtime_resolver_packet_a.json',
      );
      final resolverPacketB = p.join(
        directory.path,
        'runtime_resolver_packet_b.json',
      );
      final resolverInputPath = p.join(
        directory.path,
        'private-runtime-resolver-input.json',
      );
      final ledgerPath = p.join(directory.path, 'runtime_rollout_ledger.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'runtime-ledger'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_PLAN': planPath,
          'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS':
              reviewPath,
          'EVAL_USE_CASE_RUNTIME_LEDGER_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RUNTIME_LEDGER_DECISION_LEDGERS': ledgerSourcePath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RUNTIME_VERIFICATIONS':
              '$verificationA,$verificationB',
          'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS':
              '$resolverSnapshotA,$resolverSnapshotB',
          'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_PACKETS':
              '$resolverPacketA,$resolverPacketB',
          'EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_INPUTS': resolverInputPath,
          'EVAL_USE_CASE_RUNTIME_LEDGER': ledgerPath,
          'EVAL_USE_CASE_RUNTIME_LEDGER_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case runtime rollout ledger'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime ledger release plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime ledger release gate: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime verifications: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime ledger resolver snapshots: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime rollout ledger: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        gatePath,
        reviewPath,
        roadmapPath,
        ledgerSourcePath,
        sourceManifestPath,
        verificationA,
        verificationB,
        resolverSnapshotA,
        resolverSnapshotB,
        resolverPacketA,
        resolverPacketB,
        resolverInputPath,
        ledgerPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case runtime rollout ledger',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_RELEASE_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_DECISION_LEDGERS=$ledgerSourcePath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_VERIFICATIONS=$verificationA,$verificationB',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS=$resolverSnapshotA,$resolverSnapshotB',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_PACKETS=$resolverPacketA,$resolverPacketB',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_INPUTS=$resolverInputPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LEDGER_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 runtime-resolver-packet forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_runtime_resolver_packet_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final gatePath = p.join(directory.path, 'private-release-gate.json');
      final reviewPath = p.join(
        directory.path,
        'private-release-review.json',
      );
      final packetPath = p.join(directory.path, 'runtime_resolver_packet.json');

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'runtime-resolver-packet'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN': planPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS':
              reviewPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET': packetPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case runtime resolver packet'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver release plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver release gate: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver packet: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        gatePath,
        reviewPath,
        packetPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case runtime resolver packet',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=$packetPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 runtime-locator-packet forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_runtime_locator_packet_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final gatePath = p.join(directory.path, 'private-release-gate.json');
      final reviewPath = p.join(
        directory.path,
        'private-release-review.json',
      );
      final resolverPacketPath = p.join(
        directory.path,
        'runtime_resolver_packet.json',
      );
      final locatorInputPath = p.join(
        directory.path,
        'runtime_locator_rows.json',
      );
      final locatorPacketPath = p.join(
        directory.path,
        'runtime_locator_packet.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'runtime-locator-packet'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN': planPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS':
              reviewPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET': resolverPacketPath,
          'EVAL_USE_CASE_RUNTIME_LOCATOR_INPUT': locatorInputPath,
          'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET': locatorPacketPath,
          'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case runtime locator packet'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver packet: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime locator input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime locator packet: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        gatePath,
        reviewPath,
        resolverPacketPath,
        locatorInputPath,
        locatorPacketPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case runtime locator packet',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=$resolverPacketPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LOCATOR_INPUT=$locatorInputPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET=$locatorPacketPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 import-runtime-resolver forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_runtime_resolver_import_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final gatePath = p.join(directory.path, 'private-release-gate.json');
      final reviewPath = p.join(
        directory.path,
        'private-release-review.json',
      );
      final packetPath = p.join(
        directory.path,
        'runtime_resolver_packet.json',
      );
      final inputPath = p.join(directory.path, 'completed_bindings.json');
      final snapshotPath = p.join(
        directory.path,
        'runtime_resolver_snapshot.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'import-runtime-resolver'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN': planPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS':
              reviewPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET': packetPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_INPUT': inputPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT': snapshotPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('use-case runtime resolver import'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver release plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver release gate: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver snapshot: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        gatePath,
        reviewPath,
        packetPath,
        inputPath,
        snapshotPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case runtime resolver snapshot',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=$packetPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_INPUT=$inputPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT=$snapshotPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'run_level2 observe-runtime-state forwards inputs without stdout paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lotti_eval_runtime_state_observe_script_',
      );
      addTearDown(() async {
        if (directory.existsSync()) await directory.delete(recursive: true);
      });
      final fakeBin = Directory(p.join(directory.path, 'bin'))
        ..createSync(recursive: true);
      final logFile = File(p.join(directory.path, 'fvm_calls.log'));
      await logFile.create();
      await _writeFakeFvm(fakeBin);

      final runsRoot = p.join(directory.path, 'private-runs');
      final planPath = p.join(directory.path, 'private-release-plan.json');
      final roadmapPath = p.join(directory.path, 'private-roadmap.json');
      final ledgerPath = p.join(directory.path, 'private-ledger.json');
      final sourceManifestPath = p.join(
        directory.path,
        'private-ledger.sources.json',
      );
      final gatePath = p.join(directory.path, 'private-release-gate.json');
      final reviewPath = p.join(
        directory.path,
        'private-release-review.json',
      );
      final packetPath = p.join(
        directory.path,
        'runtime_resolver_packet.json',
      );
      final locatorPacketPath = p.join(
        directory.path,
        'runtime_locator_packet.json',
      );
      final runtimeStatePath = p.join(
        directory.path,
        'private_runtime_state.json',
      );
      final snapshotPath = p.join(
        directory.path,
        'runtime_resolver_snapshot.json',
      );

      final result = await Process.run(
        '/bin/bash',
        ['eval/run_level2.sh', 'observe-runtime-state'],
        environment: {
          'PATH':
              '${fakeBin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
          'FAKE_FVM_LOG': logFile.path,
          'EVAL_RUNS_ROOT': runsRoot,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN': planPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT': roadmapPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS': ledgerPath,
          'EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS': sourceManifestPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE': gatePath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS':
              reviewPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET': packetPath,
          'EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET': locatorPacketPath,
          'EVAL_USE_CASE_RUNTIME_STATE_INPUT': runtimeStatePath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT': snapshotPath,
          'EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT_OVERWRITE': '1',
        },
        workingDirectory: Directory.current.path,
      );

      expect(result.exitCode, 0, reason: _processReason(result));
      expect(
        result.stdout.toString(),
        contains('private use-case runtime state'),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver release plan: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver release gate: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver packet: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime locator packet: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime state input: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case runtime resolver snapshot: set '
          '(path omitted for matrix privacy)',
        ),
      );
      expect(
        result.stdout.toString(),
        contains(
          'use-case decision ledger source manifests: set '
          '(paths omitted for matrix privacy)',
        ),
      );
      for (final path in [
        runsRoot,
        planPath,
        roadmapPath,
        ledgerPath,
        sourceManifestPath,
        gatePath,
        reviewPath,
        packetPath,
        locatorPacketPath,
        runtimeStatePath,
        snapshotPath,
      ]) {
        expect(result.stdout.toString(), isNot(contains(path)));
      }

      final calls = await _readFakeFvmCalls(logFile);
      expect(calls, hasLength(1));
      expect(
        _plainNameFromFakeFvmCall(calls.single),
        'writes use-case runtime resolver snapshot from private runtime state',
      );
      _expectFakeFvmCallContains(calls.single, [
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_PLAN=$planPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_ROADMAP_INPUT=$roadmapPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_DECISION_LEDGERS=$ledgerPath',
        '--dart-define=EVAL_USE_CASE_DECISION_LEDGER_SOURCE_MANIFESTS=$sourceManifestPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_GATE=$gatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_RELEASE_REVIEW_ATTESTATIONS=$reviewPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_PACKET=$packetPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_LOCATOR_PACKET=$locatorPacketPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_STATE_INPUT=$runtimeStatePath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT=$snapshotPath',
        '--dart-define=EVAL_USE_CASE_RUNTIME_RESOLVER_SNAPSHOT_OVERWRITE=1',
        '--dart-define=EVAL_RUNS_ROOT=$runsRoot',
      ]);
    },
  );

  test(
    'renders judge calibration report',
    () async {
      final run = await TraceWriter(runsRoot: _runsRoot()).readRun(_runId);
      final catalog = _loadScenarioCatalog();
      final profiles = _loadProfiles();
      final promptVariants = _loadPromptVariants();
      final verification = EvalRunVerifier.verify(
        runId: _runId,
        traces: run.traces,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
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
        scenarioCatalogEvidence: run.manifest.scenarioCatalogEvidence,
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

Future<String?> _pairwisePreferenceReport({
  required TraceWriter writer,
  required EvalRunArtifacts run,
}) async {
  try {
    final votes = await writer.readPairwisePreferenceVotes(
      run.manifest.runId,
      traces: run.traces,
    );
    if (votes.isEmpty) return null;
    return EvalPairwisePreferenceReporter.render(
      EvalPairwisePreferenceReporter.summarize(votes),
    );
  } catch (error) {
    return 'Subjective A/B preference votes (diagnostic only) could not be '
        'loaded: $error';
  }
}

Future<File> _writeTuningReportForRun({
  required TraceWriter writer,
  required String runId,
  required String tuningReportPath,
  required bool overwrite,
  EvalScenarioCatalog? catalog,
  List<EvalProfile>? profiles,
  List<EvalAgentDirectiveVariant>? promptVariants,
  String? protectedTraceAck,
}) async {
  final run = await writer.readRun(runId);
  final resolvedCatalog = catalog ?? _loadScenarioCatalog();
  final resolvedProfiles = profiles ?? _loadProfiles();
  final resolvedPromptVariants = promptVariants ?? _loadPromptVariants();
  expect(run.traces, isNotEmpty, reason: 'EVAL_RUN=$runId has no traces');
  final verification = EvalRunVerifier.verify(
    runId: runId,
    traces: run.traces,
    scenarios: resolvedCatalog.scenarios,
    profiles: resolvedProfiles,
    agentDirectiveVariants: resolvedPromptVariants,
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
    catalog: resolvedCatalog,
  );
  final calibrationReport = calibrationSet == null
      ? null
      : EvalJudgeCalibration.evaluate(
          traces: run.traces,
          calibrationSet: calibrationSet,
          scenarioCatalogEvidence: run.manifest.scenarioCatalogEvidence,
        );
  final pairwiseReadinessPlan = await _pairwiseReadinessPlanFromConfig(
    manifest: run.manifest,
    writer: writer,
  );
  final pairwisePreferenceArtifacts = pairwiseReadinessPlan == null
      ? null
      : await writer.readPairwisePreferenceArtifacts(
          run.manifest.runId,
          traces: run.traces,
        );
  final pairwisePreferenceVotes =
      pairwisePreferenceArtifacts?.votes ??
      const <EvalPairwisePreferenceVote>[];
  final pairwiseTraceRefsByKey =
      pairwisePreferenceArtifacts?.traceRefsByKey ??
      const <String, EvalPairwiseTraceRef>{};
  if (pairwiseReadinessPlan != null) {
    _validatePairwiseReadinessPlanVotes(
      plan: pairwiseReadinessPlan,
      votes: pairwisePreferenceVotes,
    );
  }
  final readiness = EvalTuningReadiness.assess(
    traces: run.traces,
    scenarios: resolvedCatalog.scenarios,
    profiles: resolvedProfiles,
    manifest: run.manifest,
    scenarioCatalogEvidence: resolvedCatalog.evidence,
    policy: _readinessPolicyFromConfig(
      pairwiseReadinessPlan,
      manifest: run.manifest,
    ),
    calibrationSet: calibrationSet,
    pairwisePreferenceVotes: pairwisePreferenceVotes,
    pairwiseTraceRefsByKey: pairwiseTraceRefsByKey,
  );
  final promotionDecision = _profilePromotionDecisionFromConfig(
    traces: run.traces,
    readinessReport: readiness,
    manifest: run.manifest,
  );
  final report = _tuningReportJson(
    run: run,
    scenarios: resolvedCatalog.scenarios,
    profiles: resolvedProfiles,
    promptVariants: resolvedPromptVariants,
    readiness: readiness,
    calibrationReport: calibrationReport,
    pairwiseReadinessPlan: pairwiseReadinessPlan,
    pairwisePreferenceVotes: pairwisePreferenceVotes,
    promotionDecision: promotionDecision,
    catalogEvidence: resolvedCatalog.evidence,
    generatedAt: DateTime.now().toUtc(),
  );
  EvalTuningReportContract.assertValid(report);
  final file = File(tuningReportPath);
  _guardTuningReportOutput(
    manifestEvidence: run.manifest.scenarioCatalogEvidence,
    loadedEvidence: resolvedCatalog.evidence,
    file: file,
    protectedTraceAck: protectedTraceAck,
  );
  if (file.existsSync() && !overwrite) {
    throw StateError(
      'Refusing to overwrite existing tuning report: ${file.path}. '
      'Set EVAL_TUNING_REPORT_OVERWRITE=1.',
    );
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  return file;
}

Future<File> _writeScenarioCatalogPreflightReport({
  required String preflightReportPath,
  required bool overwrite,
  String? protectedTraceAck,
  EvalScenarioCatalog? catalog,
  List<EvalProfile>? profiles,
  String? catalogMode,
  bool? selectedSubset,
}) async {
  final resolvedCatalog = catalog ?? _loadScenarioCatalog();
  final resolvedProfiles = profiles ?? _loadProfiles();
  final catalogPath = _scenarioCatalogPathValue();
  if (catalog == null && catalogPath != null) {
    _guardScenarioCatalogPreflightInput(
      evidence: resolvedCatalog.evidence,
      file: File(catalogPath),
    );
  }
  final report = EvalTuningReadiness.assessScenarioCatalog(
    scenarios: resolvedCatalog.scenarios,
    profiles: resolvedProfiles,
    scenarioCatalogEvidence: resolvedCatalog.evidence,
  );
  final artifact = EvalScenarioCatalogPreflight.build(
    report: report,
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(
      resolvedCatalog.scenarios,
    ),
    profileSetDigest: EvalProvenance.profileSetDigest(resolvedProfiles),
    catalogMode: catalogMode ?? _scenarioCatalogModeValue(),
    selectedSubset: selectedSubset ?? _hasScenarioIdSelection(),
    generatedAt: DateTime.now().toUtc(),
  );
  EvalScenarioCatalogPreflight.assertValid(artifact);
  final file = File(preflightReportPath);
  _guardScenarioCatalogPreflightReportOutput(
    evidence: resolvedCatalog.evidence,
    file: file,
    protectedTraceAck: protectedTraceAck,
  );
  if (file.existsSync() && !overwrite) {
    throw StateError(
      'Refusing to overwrite existing scenario catalog preflight report: '
      '${file.path}. Set EVAL_CATALOG_PREFLIGHT_REPORT_OVERWRITE=1.',
    );
  }
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(artifact),
  );
  return file;
}

EvalTuningPolicy _readinessPolicyFromConfig(
  EvalPairwiseReadinessPlan? pairwisePlan, {
  EvalRunManifest? manifest,
  Set<String>? requiredPrimaryCapabilityIds,
  String requiredCapabilitiesValue = _requiredCapabilities,
}) {
  final configuredCapabilities =
      requiredPrimaryCapabilityIds ??
      _requiredPrimaryCapabilityIdsFromConfig(value: requiredCapabilitiesValue);
  final hasConfiguredCapabilities =
      requiredPrimaryCapabilityIds != null ||
      requiredCapabilitiesValue.trim().isNotEmpty;
  final manifestCapabilities =
      manifest?.tuningReadinessContractEvidence?.requiredPrimaryCapabilityIds;
  final requiredCapabilities = manifestCapabilities == null
      ? configuredCapabilities
      : _requiredCapabilitiesFromManifestContract(
          manifestCapabilities: manifestCapabilities,
          configuredCapabilities: configuredCapabilities,
          hasConfiguredCapabilities: hasConfiguredCapabilities,
        );
  if (pairwisePlan == null && manifest?.pairwiseReadinessPlanEvidence != null) {
    throw StateError(
      'Run manifest contains pairwise readiness plan evidence; set '
      'EVAL_PAIRWISE_READINESS_PLAN so report mode can apply the registered '
      'pairwise readiness gate.',
    );
  }
  final policy = pairwisePlan == null
      ? EvalTuningPolicy.modelClassTuning(
          requiredPrimaryCapabilityIds: requiredCapabilities,
        )
      : EvalTuningPolicy.modelClassTuning(
          requiredPrimaryCapabilityIds: requiredCapabilities,
          minBlindedPairwisePreferenceDecisions:
              pairwisePlan.minBlindedPairwisePreferenceDecisions,
          requiredBlindedPairwisePreferenceComparisonKeys:
              pairwisePlan.requiredComparisonKeys,
          requiredBlindedPairwisePreferenceIntentKeys:
              pairwisePlan.requiredComparisonIntentKeys,
          requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey:
              pairwisePlan.outcomeExpectationsByComparisonKey,
          requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey:
              pairwisePlan.outcomeExpectationsByIntentKey,
          blindedPairwisePreferencePolicy: pairwisePlan.preferencePolicy,
        );
  _validateManifestReadinessPolicy(policy: policy, manifest: manifest);
  return policy;
}

void _validateManifestReadinessPolicy({
  required EvalTuningPolicy policy,
  required EvalRunManifest? manifest,
}) {
  final evidence = manifest?.tuningReadinessPolicyEvidence;
  if (evidence == null) {
    if (manifest != null && policy.requireManifestPolicyEvidence) {
      throw StateError(
        'Run manifest tuningReadinessPolicyEvidence is required for '
        '${policy.name}. Re-run the eval with current harness policy evidence '
        'before using report mode for tuning readiness.',
      );
    }
    return;
  }
  if (evidence.policyName != policy.name) {
    throw StateError(
      'Tuning readiness policyName "${policy.name}" does not match run '
      'manifest "${evidence.policyName}".',
    );
  }
  if (evidence.policyDigest != policy.policyDigest) {
    throw StateError(
      'Tuning readiness policyDigest "${policy.policyDigest}" does not match '
      'run manifest "${evidence.policyDigest}".',
    );
  }
}

Set<String> _requiredCapabilitiesFromManifestContract({
  required Set<String> manifestCapabilities,
  required Set<String> configuredCapabilities,
  required bool hasConfiguredCapabilities,
}) {
  if (hasConfiguredCapabilities &&
      !_sameStringSet(configuredCapabilities, manifestCapabilities)) {
    throw StateError(
      'EVAL_REQUIRED_CAPABILITIES ${_formatStringSet(configuredCapabilities)} '
      'does not match run manifest readiness contract '
      '${_formatStringSet(manifestCapabilities)}.',
    );
  }
  return manifestCapabilities;
}

Set<String> _requiredPrimaryCapabilityIdsFromConfig({
  String value = _requiredCapabilities,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const <String>{};
  final ids = <String>{};
  for (final rawPart in value.split(',')) {
    final part = rawPart.trim();
    if (part.isEmpty) {
      throw StateError(
        'EVAL_REQUIRED_CAPABILITIES must contain non-empty comma-separated '
        'capability ids.',
      );
    }
    ids.add(part);
  }
  return Set.unmodifiable(ids);
}

bool _sameStringSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

String _formatStringSet(Set<String> values) {
  return '{${(values.toList()..sort()).join(', ')}}';
}

Future<EvalPairwiseReadinessPlan?> _pairwiseReadinessPlanFromConfig({
  required EvalRunManifest? manifest,
  TraceWriter? writer,
  String pairwiseReadinessPlanPath = _pairwiseReadinessPlanPath,
}) async {
  final planPath = pairwiseReadinessPlanPath.trim();
  if (planPath.isEmpty) {
    final registration = manifest == null || writer == null
        ? null
        : await writer.readPairwiseReadinessPlanRegistration(manifest.runId);
    if (manifest?.pairwiseReadinessPlanEvidence != null ||
        registration != null) {
      throw StateError(
        'Run contains pairwise readiness plan evidence; set '
        'EVAL_PAIRWISE_READINESS_PLAN so report mode can apply the registered '
        'pairwise readiness gate.',
      );
    }
    return null;
  }
  if (manifest == null) {
    throw StateError(
      'EVAL_PAIRWISE_READINESS_PLAN requires a verified run manifest for '
      'digest checks.',
    );
  }
  final plan = _readPairwiseReadinessPlan(File(planPath));
  final registration = writer == null
      ? null
      : await writer.readPairwiseReadinessPlanRegistration(manifest.runId);
  _validatePairwiseReadinessPlan(
    plan: plan,
    manifest: manifest,
    registration: registration,
  );
  return plan;
}

EvalPairwiseReadinessPlan _readPairwiseReadinessPlan(File file) {
  if (!file.existsSync()) {
    throw StateError('Missing pairwise readiness plan: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError(
      'Pairwise readiness plan JSON must be an object: ${file.path}',
    );
  }
  try {
    return EvalPairwiseReadinessPlan.fromJson(decoded);
  } on FormatException catch (error) {
    throw StateError(
      'Invalid pairwise readiness plan ${file.path}: ${error.message}',
    );
  }
}

void _validatePairwiseReadinessPlan({
  required EvalPairwiseReadinessPlan plan,
  required EvalRunManifest manifest,
  EvalPairwiseReadinessPlanRegistration? registration,
}) {
  if (plan.scenarioSetDigest != manifest.scenarioSetDigest) {
    throw StateError(
      'Pairwise readiness plan scenarioSetDigest "${plan.scenarioSetDigest}" '
      'does not match run manifest "${manifest.scenarioSetDigest}".',
    );
  }
  if (plan.profileSetDigest != manifest.profileSetDigest) {
    throw StateError(
      'Pairwise readiness plan profileSetDigest "${plan.profileSetDigest}" '
      'does not match run manifest "${manifest.profileSetDigest}".',
    );
  }
  if (plan.profileBindingSetDigest != manifest.profileBindingSetDigest) {
    throw StateError(
      'Pairwise readiness plan profileBindingSetDigest '
      '"${plan.profileBindingSetDigest}" does not match run manifest '
      '"${manifest.profileBindingSetDigest}".',
    );
  }
  final intent = plan.intent;
  if (intent != null &&
      intent.agentDirectiveVariantSetDigest !=
          manifest.agentDirectiveVariantSetDigest) {
    throw StateError(
      'Pairwise readiness intent agentDirectiveVariantSetDigest '
      '"${intent.agentDirectiveVariantSetDigest}" does not match run manifest '
      '"${manifest.agentDirectiveVariantSetDigest}".',
    );
  }
  if (intent != null &&
      intent.profileBindingSetDigest != manifest.profileBindingSetDigest) {
    throw StateError(
      'Pairwise readiness intent profileBindingSetDigest '
      '"${intent.profileBindingSetDigest}" does not match run manifest '
      '"${manifest.profileBindingSetDigest}".',
    );
  }
  final manifestDigest = manifest.manifestDigest;
  if (manifestDigest == null) {
    throw StateError(
      'Pairwise readiness plan requires a run manifestDigest.',
    );
  }
  if (plan.manifestDigest == null) {
    throw StateError(
      'Pairwise readiness plan requires manifestDigest for report mode.',
    );
  }
  if (plan.manifestDigest != manifestDigest) {
    throw StateError(
      'Pairwise readiness plan manifestDigest "${plan.manifestDigest}" does '
      'not match run manifest "$manifestDigest".',
    );
  }
  if (registration != null) {
    if (registration.runId != manifest.runId) {
      throw StateError(
        'Pairwise readiness plan registration runId "${registration.runId}" '
        'does not match run manifest "${manifest.runId}".',
      );
    }
    if (registration.sourceManifestDigest != manifestDigest) {
      throw StateError(
        'Pairwise readiness plan registration sourceManifestDigest '
        '"${registration.sourceManifestDigest}" does not match run manifest '
        '"$manifestDigest".',
      );
    }
    final expectedRegistrationEvidence = plan.toManifestEvidence();
    if (jsonEncode(registration.evidence.toJson()) !=
        jsonEncode(expectedRegistrationEvidence.toJson())) {
      throw StateError(
        'Pairwise readiness plan registration evidence does not match '
        'EVAL_PAIRWISE_READINESS_PLAN.',
      );
    }
  }
  final planEvidence = manifest.pairwiseReadinessPlanEvidence;
  if (planEvidence == null) {
    throw StateError(
      'Pairwise readiness plan was not recorded in the run manifest; '
      'run-side registration evidence is diagnostic only and cannot satisfy '
      'tuning readiness gates. Pass EVAL_PAIRWISE_READINESS_PLAN during '
      'eval/run_level2.sh run before using it as an assertion gate.',
    );
  }
  if (planEvidence.profileBindingSetDigest !=
      manifest.profileBindingSetDigest) {
    throw StateError(
      'Pairwise readiness plan evidence profileBindingSetDigest '
      '"${planEvidence.profileBindingSetDigest}" does not match run manifest '
      '"${manifest.profileBindingSetDigest}".',
    );
  }
  final expectedSubjectDigest = plan
      .toManifestEvidence()
      .pairwiseReadinessPlanSubjectDigest;
  if (planEvidence.pairwiseReadinessPlanSubjectDigest !=
      expectedSubjectDigest) {
    throw StateError(
      'Pairwise readiness plan subject digest "$expectedSubjectDigest" does '
      'not match run manifest evidence '
      '"${planEvidence.pairwiseReadinessPlanSubjectDigest}".',
    );
  }
}

void _validatePairwiseReadinessPlanVotes({
  required EvalPairwiseReadinessPlan plan,
  required List<EvalPairwisePreferenceVote> votes,
}) {
  final failures = <String>[];
  final comparisonsByKey = plan.comparisonsByComparisonKey;
  final intentComparisonsByKey =
      plan.intent?.comparisonsByIntentKey ??
      const <String, EvalPairwiseReadinessIntentComparison>{};
  for (final vote in votes) {
    final comparison = comparisonsByKey[vote.comparisonKey];
    if (comparison == null) continue;
    final expectedPayloadDigest = comparison.reviewPayloadDigest;
    final intentComparison = intentComparisonsByKey[comparison.intentKey];
    if (plan.intent != null && intentComparison == null) {
      failures.add(
        '${vote.voteId}: comparison intentKey ${comparison.intentKey} is not '
        'present in embedded intent',
      );
    } else if (intentComparison != null) {
      for (final issue in intentComparison.validateTraceRefs(
        optionA: vote.optionA,
        optionB: vote.optionB,
      )) {
        failures.add(
          '${vote.voteId}: comparison ${comparison.intentKey} does not refine '
          'embedded intent: $issue',
        );
      }
    }
    if (vote.reviewProtocolFingerprint != plan.reviewProtocolFingerprint) {
      failures.add(
        '${vote.voteId}: review protocol fingerprint '
        '${vote.reviewProtocolFingerprint} does not match plan '
        '${plan.reviewProtocolFingerprint}',
      );
    }
    final provenance = vote.blindedImport;
    if (provenance == null) {
      failures.add('${vote.voteId}: missing blinded import provenance');
      continue;
    }
    if (provenance.judgeManifestDigest !=
        plan.importBinding.judgeManifestDigest) {
      failures.add(
        '${vote.voteId}: judgeManifestDigest '
        '${provenance.judgeManifestDigest} does not match plan '
        '${plan.importBinding.judgeManifestDigest}',
      );
    }
    if (provenance.privateKeyDigest != plan.importBinding.privateKeyDigest) {
      failures.add(
        '${vote.voteId}: privateKeyDigest ${provenance.privateKeyDigest} '
        'does not match plan ${plan.importBinding.privateKeyDigest}',
      );
    }
    if (provenance.reviewPayloadDigest != expectedPayloadDigest) {
      failures.add(
        '${vote.voteId}: reviewPayloadDigest '
        '${provenance.reviewPayloadDigest} does not match plan '
        '$expectedPayloadDigest for ${vote.comparisonKey}',
      );
    }
  }
  if (failures.isNotEmpty) {
    throw StateError(
      'Pairwise readiness plan vote binding failed:\n'
      '${failures.join('\n')}',
    );
  }
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
  if (plan == null && manifest?.promotionPlanEvidence != null) {
    throw StateError(
      'Run manifest records promotion plan evidence; set '
      'EVAL_PROMOTION_PLAN so report mode applies the registered promotion '
      'gate.',
    );
  }
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

Map<String, dynamic> _tuningReportJson({
  required EvalRunArtifacts run,
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  required List<EvalAgentDirectiveVariant> promptVariants,
  required EvalTuningReadinessReport readiness,
  required JudgeCalibrationReport? calibrationReport,
  required EvalPairwiseReadinessPlan? pairwiseReadinessPlan,
  required List<EvalPairwisePreferenceVote> pairwisePreferenceVotes,
  required ProfilePromotionDecision? promotionDecision,
  EvalScenarioCatalogEvidence? catalogEvidence,
  DateTime? generatedAt,
}) {
  final effectiveCatalogEvidence = _effectiveTuningReportCatalogEvidence(
    manifestEvidence: run.manifest.scenarioCatalogEvidence,
    loadedEvidence: catalogEvidence,
  );
  final slices = _tuningUseCaseSlices(
    traces: run.traces,
    policy: readiness.policy,
    catalogEvidence: effectiveCatalogEvidence,
  );
  final sliceGates = [
    for (final slice in slices)
      ...(slice['gates'] as List<dynamic>).cast<Map<String, dynamic>>(),
  ];
  final coverageGates = _coverageGateJson(readiness);
  final outcomeGates = _outcomeGateJson(readiness.outcomeQualityEvidence);
  final pairwiseGates = _pairwiseGateJson(readiness.pairwisePreferenceEvidence);
  final calibrationGates = _calibrationGateJson(
    calibrationReport,
    policy: readiness.policy,
  );
  final promotionGates = _promotionGateJson(promotionDecision);
  final gates = [
    ...coverageGates,
    ...outcomeGates,
    ...sliceGates,
    ...pairwiseGates,
    ...calibrationGates,
    ...promotionGates,
  ];
  final blockedReasons = _dedupeBlockedReasons([
    for (final gate in gates)
      if (gate['status'] == 'fail') _blockedReasonForGate(gate),
    for (final failure in readiness.failures)
      _blockedReasonJson(failure, severity: 'blocking'),
    if (promotionDecision != null)
      for (final failure in promotionDecision.failures)
        _blockedReasonJson(failure, severity: 'blocking'),
  ]);
  final failingSlices = [
    for (final slice in slices)
      if (slice['recommendation'] != 'keep') slice,
  ];
  final suggestedCapabilities = _sortedStrings({
    for (final slice in failingSlices) slice['primaryCapabilityId'] as String,
    for (final id in readiness.evidence.missingRequiredPrimaryCapabilityIds) id,
  });
  final suggestedScenarioIds = _sortedStrings({
    for (final slice in failingSlices)
      ...(slice['scenarioIds'] as List<dynamic>).whereType<String>().where(
        (id) => !id.startsWith('<'),
      ),
  });
  final suggestedProfileNames = _sortedStrings({
    for (final slice in failingSlices)
      ...(slice['profileNames'] as List<dynamic>).whereType<String>(),
  });
  final suggestedPromptVariantNames = _sortedStrings({
    for (final slice in failingSlices) slice['promptVariantName'] as String,
  });
  final pairwiseEvidence = readiness.pairwisePreferenceEvidence;
  final requiredPairwiseIntentKeys = _sortedStrings(
    pairwiseReadinessPlan?.requiredComparisonIntentKeys ?? const <String>{},
  );
  final missingPairwiseKeys = _sortedStrings({
    if (pairwiseEvidence != null)
      ...pairwiseEvidence.missingRequiredComparisonKeys,
    if (pairwiseEvidence != null)
      ...pairwiseEvidence.failedOutcomeComparisonKeys,
  });
  final protectedIdsRedacted =
      effectiveCatalogEvidence?.usesExternalCatalog ?? false;
  final redactedScenarioIdCount = _tuningReportRedactedScenarioIds(
    scenarios: scenarios,
    catalogEvidence: effectiveCatalogEvidence,
  ).length;
  final recommendations = _tuningRecommendations(
    blockedReasons: blockedReasons,
    slices: slices,
    suggestedCapabilities: suggestedCapabilities,
    suggestedScenarioIds: suggestedScenarioIds,
    suggestedProfileNames: suggestedProfileNames,
    suggestedPromptVariantNames: suggestedPromptVariantNames,
    requiredPairwiseIntentKeys: requiredPairwiseIntentKeys,
    missingPairwiseKeys: missingPairwiseKeys,
  );
  final report = <String, dynamic>{
    'schemaVersion': 1,
    'kind': 'lotti.evalTuningReport',
    'generatedAt': (generatedAt ?? run.manifest.createdAt)
        .toUtc()
        .toIso8601String(),
    'run': <String, dynamic>{
      'runId': run.manifest.runId,
      'targetKind': run.manifest.targetKind,
      'manifestDigest': run.manifest.manifestDigest,
      'createdAt': run.manifest.createdAt.toUtc().toIso8601String(),
      'scenarioSetDigest': run.manifest.scenarioSetDigest,
      'profileSetDigest': run.manifest.profileSetDigest,
      'profileBindingSetDigest': run.manifest.profileBindingSetDigest,
      'agentDirectiveVariantSetDigest':
          run.manifest.agentDirectiveVariantSetDigest,
      'selectors': <String, dynamic>{
        'scenarioIds': protectedIdsRedacted
            ? const <String>[]
            : _sortedStrings(scenarios.map((scenario) => scenario.id)),
        'profileNames': _sortedStrings(
          profiles.map((profile) => profile.name),
        ),
        'promptVariantNames': _sortedStrings(
          promptVariants.map((variant) => variant.name),
        ),
        'requiredPrimaryCapabilityIds': _sortedStrings(
          readiness.policy.requiredPrimaryCapabilityIds,
        ),
      },
      'protectedIdsRedacted': protectedIdsRedacted,
      if (protectedIdsRedacted)
        'redactedScenarioIdCount': redactedScenarioIdCount,
      'artifactSnapshot': _tuningArtifactSnapshotJson(run),
    },
    'policy': <String, dynamic>{
      'name': readiness.policyName,
      'digest': readiness.policyDigest,
      'payload': readiness.policy.toJson(),
    },
    'status': <String, dynamic>{
      'ready': readiness.ready,
      'label': readiness.evidenceLabel,
      'failureCount': readiness.failures.length,
      'warningCount': readiness.warnings.length,
    },
    'gates': gates,
    'coverage': <String, dynamic>{
      'scenarioCount': readiness.scenarioCount,
      'profileCount': readiness.profileCount,
      'promptVariantCount': promptVariants.length,
      'expectedTraceCount': readiness.expectedTraceCount,
      'traceCount': readiness.traceCount,
      'judgedTraceCount': readiness.judgedTraceCount,
      'scenarioCountByAgentKind': _enumIntMapJson(
        readiness.evidence.scenarioCountByAgentKind,
      ),
      'scenarioCountBySplit': _enumIntMapJson(
        readiness.evidence.scenarioCountBySplit,
      ),
      'scenarioCountByPrimaryCapability': _stringIntMapJson(
        readiness.evidence.scenarioCountByPrimaryCapability,
      ),
      'missingRequiredPrimaryCapabilityIds': _sortedStrings(
        readiness.evidence.missingRequiredPrimaryCapabilityIds,
      ),
    },
    'readiness': <String, dynamic>{
      'ready': readiness.ready,
      'evidenceLabel': readiness.evidenceLabel,
      'policyName': readiness.policyName,
      'policyDigest': readiness.policyDigest,
      'expectedTraceCount': readiness.expectedTraceCount,
      'traceCount': readiness.traceCount,
      'judgedTraceCount': readiness.judgedTraceCount,
      'failures': readiness.failures,
      'warnings': readiness.warnings,
      'missingRequiredPrimaryCapabilityIds': _sortedStrings(
        readiness.evidence.missingRequiredPrimaryCapabilityIds,
      ),
    },
    'outcomes': <String, dynamic>{
      'aggregate': _outcomeQualityJson(readiness.outcomeQualityEvidence),
      'slices': slices,
      'failingTraceCount': run.traces
          .where(
            (trace) => !trace.isCascadeWake && trace.verdict?.pass == false,
          )
          .length,
    },
    'calibration': calibrationReport == null
        ? const <String, dynamic>{'present': false}
        : <String, dynamic>{
            'present': true,
            'metrics': _calibrationReportJson(calibrationReport),
            'findings': [
              for (final finding in calibrationReport.findings)
                _calibrationFindingJson(finding),
            ],
          },
    'pairwise': _pairwiseEvidenceJson(
      pairwiseEvidence,
      pairwiseReadinessPlan: pairwiseReadinessPlan,
      voteCount: pairwisePreferenceVotes.length,
    ),
    'promotion': promotionDecision == null
        ? const <String, dynamic>{
            'present': false,
            'status': 'notRequested',
            'evidencePlan': null,
          }
        : _promotionDecisionJson(promotionDecision),
    'useCaseModelSlices': slices,
    'blockedReasons': blockedReasons,
    'recommendations': recommendations,
    'nextExperimentPlan': <String, dynamic>{
      'schemaVersion': 1,
      'kind': 'lotti.evalTuningNextExperimentPlan',
      'baseRunId': run.manifest.runId,
      'objective': readiness.ready
          ? 'readyForPromotionReview'
          : 'closeReadinessGaps',
      'status': readiness.ready ? 'ready' : 'blocked',
      'blockedReasonCodes': _sortedStrings({
        for (final reason in blockedReasons) reason['code'] as String,
      }),
      'requiredCapabilities': _sortedStrings(
        readiness.policy.requiredPrimaryCapabilityIds,
      ),
      'suggestedCapabilities': suggestedCapabilities,
      'suggestedScenarioIds': suggestedScenarioIds,
      'suggestedProfileNames': suggestedProfileNames,
      'suggestedPromptVariantNames': suggestedPromptVariantNames,
      'requiredPairwiseIntentKeys': requiredPairwiseIntentKeys,
      'missingOrFailedPairwiseKeys': missingPairwiseKeys,
      'nextRunEnv': <String, dynamic>{
        if (suggestedCapabilities.isNotEmpty)
          'EVAL_REQUIRED_CAPABILITIES': suggestedCapabilities.join(','),
        if (suggestedScenarioIds.isNotEmpty)
          'EVAL_SCENARIO_IDS': suggestedScenarioIds.join(','),
        if (suggestedProfileNames.isNotEmpty)
          'EVAL_PROFILE_NAMES': suggestedProfileNames.join(','),
        if (suggestedPromptVariantNames.isNotEmpty)
          'EVAL_PROMPT_VARIANT_NAMES': suggestedPromptVariantNames.join(','),
        if (requiredPairwiseIntentKeys.isNotEmpty)
          'EVAL_PAIRWISE_READINESS_PLAN':
              '<path-to-generated-pairwise-readiness-plan>',
      },
      'recommendedCommands': [
        <String, dynamic>{
          'mode': 'plan',
          'command': 'eval/run_level2.sh plan <nextRunId>',
        },
        <String, dynamic>{
          'mode': 'run',
          'command': 'eval/run_level2.sh run <nextRunId>',
        },
        <String, dynamic>{
          'mode': 'tune',
          'command': 'eval/run_level2.sh tune <nextRunId>',
        },
      ],
    },
  };
  return _redactTuningReportJson(
    report,
    scenarios: scenarios,
    catalogEvidence: effectiveCatalogEvidence,
  );
}

EvalScenarioCatalogEvidence? _effectiveTuningReportCatalogEvidence({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence? loadedEvidence,
}) {
  if (loadedEvidence?.usesExternalCatalog ?? false) return loadedEvidence;
  if (manifestEvidence?.usesExternalCatalog ?? false) return manifestEvidence;
  return manifestEvidence ?? loadedEvidence;
}

Map<String, dynamic> _tuningArtifactSnapshotJson(EvalRunArtifacts run) {
  final traceSnapshots =
      [
        for (final trace in run.traces)
          <String, dynamic>{
            'scenarioDigest': trace.provenance.scenarioDigest,
            'profileDigest': trace.provenance.profileDigest,
            'agentDirectiveVariantDigest':
                trace.provenance.agentDirectiveVariantDigest,
            'trialIndex': trace.trialIndex,
            if (trace.cascadeWake != null)
              'cascadeWakeKey': trace.cascadeWake!.keySuffix,
            'hasVerdict': trace.verdict != null,
            'traceJsonDigest': EvalProvenance.digestJson(trace.toJson()),
          },
      ]..sort((a, b) {
        final scenario = (a['scenarioDigest'] as String).compareTo(
          b['scenarioDigest'] as String,
        );
        if (scenario != 0) return scenario;
        final profile = (a['profileDigest'] as String).compareTo(
          b['profileDigest'] as String,
        );
        if (profile != 0) return profile;
        final variant = (a['agentDirectiveVariantDigest'] as String).compareTo(
          b['agentDirectiveVariantDigest'] as String,
        );
        if (variant != 0) return variant;
        final trial = (a['trialIndex'] as int).compareTo(
          b['trialIndex'] as int,
        );
        if (trial != 0) return trial;
        return (a['cascadeWakeKey'] as String? ?? '').compareTo(
          b['cascadeWakeKey'] as String? ?? '',
        );
      });
  final manifestDigest =
      run.manifest.manifestDigest ??
      EvalProvenance.manifestDigest(run.manifest);
  final ownedArtifactRefs = <Map<String, dynamic>>[
    <String, dynamic>{
      'kind': 'manifest',
      'manifestDigest': manifestDigest,
    },
    for (final trace in traceSnapshots) ...[
      <String, dynamic>{
        'kind': 'trace',
        'scenarioDigest': trace['scenarioDigest'],
        'profileDigest': trace['profileDigest'],
        'agentDirectiveVariantDigest': trace['agentDirectiveVariantDigest'],
        'trialIndex': trace['trialIndex'],
        if (trace.containsKey('cascadeWakeKey'))
          'cascadeWakeKey': trace['cascadeWakeKey'],
      },
      if (trace['hasVerdict'] == true)
        <String, dynamic>{
          'kind': 'verdict',
          'scenarioDigest': trace['scenarioDigest'],
          'profileDigest': trace['profileDigest'],
          'agentDirectiveVariantDigest': trace['agentDirectiveVariantDigest'],
          'trialIndex': trace['trialIndex'],
          if (trace.containsKey('cascadeWakeKey'))
            'cascadeWakeKey': trace['cascadeWakeKey'],
        },
    ],
  ];

  return <String, dynamic>{
    'artifactCount': ownedArtifactRefs.length,
    'traceCount': run.traces.length,
    'judgedTraceCount': run.traces
        .where((trace) => trace.verdict != null)
        .length,
    'manifestDigest': manifestDigest,
    'ownedArtifactRefsDigest': EvalProvenance.digestJson(ownedArtifactRefs),
    'loadedTraceContentDigest': EvalProvenance.digestJson(traceSnapshots),
  };
}

Map<String, dynamic> _redactTuningReportJson(
  Map<String, dynamic> report, {
  required List<EvalScenario> scenarios,
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  if (catalogEvidence == null || !catalogEvidence.usesExternalCatalog) {
    return report;
  }
  final ids = _tuningReportRedactedScenarioIds(
    scenarios: scenarios,
    catalogEvidence: catalogEvidence,
  );
  if (ids.isEmpty) return report;
  final replacements = <String, String>{
    for (final indexed in ids.indexed)
      indexed.$2:
          '<redacted-scenario-${(indexed.$1 + 1).toString().padLeft(3, '0')}>',
  };
  final redacted = _redactTuningReportValue(report, replacements);
  if (redacted is! Map<String, dynamic>) {
    throw StateError('Tuning report redaction must preserve object root.');
  }
  return redacted;
}

List<String> _tuningReportRedactedScenarioIds({
  required List<EvalScenario> scenarios,
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  if (catalogEvidence == null || !catalogEvidence.usesExternalCatalog) {
    return const <String>[];
  }
  return _sortedStrings({
    ...catalogEvidence.protectedScenarioIds,
    ...catalogEvidence.protectedHoldoutScenarioIds,
    for (final scenario in scenarios) scenario.id,
  });
}

Object? _redactTuningReportValue(
  Object? value,
  Map<String, String> replacements,
) {
  if (value is String) return _redactTuningReportString(value, replacements);
  if (value is List) {
    return [
      for (final item in value) _redactTuningReportValue(item, replacements),
    ];
  }
  if (value is Map) {
    final redacted = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key is String
          ? _redactTuningReportString(entry.key as String, replacements)
          : entry.key.toString();
      redacted[key] = _redactTuningReportValue(entry.value, replacements);
    }
    return redacted;
  }
  return value;
}

String _redactTuningReportString(
  String value,
  Map<String, String> replacements,
) {
  var redacted = value;
  final ids = replacements.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final id in ids) {
    redacted = redacted.replaceAll(id, replacements[id]!);
  }
  return redacted;
}

List<Map<String, dynamic>> _tuningUseCaseSlices({
  required List<EvalTrace> traces,
  required EvalTuningPolicy policy,
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  final accumulators = <String, _TuningSliceAccumulator>{};
  for (final trace in traces) {
    if (trace.cascadeWake != null) continue;
    final capabilityId =
        trace.scenario.metadata.primaryCapabilityId ?? 'uncategorized';
    final key = [
      capabilityId,
      trace.scenario.agentKind.name,
      trace.profile.modelClass.name,
      trace.agentDirectiveVariant.name,
    ].join('|');
    accumulators
        .putIfAbsent(
          key,
          () => _TuningSliceAccumulator(
            primaryCapabilityId: capabilityId,
            agentKind: trace.scenario.agentKind.name,
            modelClass: trace.profile.modelClass.name,
            promptVariantName: trace.agentDirectiveVariant.name,
          ),
        )
        .add(
          trace,
          scenarioId: _scenarioIdForTuningReport(
            trace.scenario,
            catalogEvidence: catalogEvidence,
          ),
        );
  }
  return [
    for (final accumulator in accumulators.values) accumulator.toJson(policy),
  ]..sort(
    (a, b) => (a['sliceKey'] as String).compareTo(b['sliceKey'] as String),
  );
}

String _scenarioIdForTuningReport(
  EvalScenario scenario, {
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  if (catalogEvidence == null || !catalogEvidence.usesExternalCatalog) {
    return scenario.id;
  }
  return '<external-scenario>';
}

List<Map<String, dynamic>> _coverageGateJson(
  EvalTuningReadinessReport readiness,
) {
  final policy = readiness.policy;
  return [
    if (policy.requireCompleteTraceMatrix)
      _gateJson(
        id: 'coverage.trace_matrix.complete',
        status: readiness.traceCount == readiness.expectedTraceCount
            ? 'pass'
            : 'fail',
        actual: readiness.traceCount,
        required: readiness.expectedTraceCount,
        comparator: '==',
        blockerCode: 'coverage.traceMatrixIncomplete',
      ),
    if (policy.requireAllVerdicts)
      _gateJson(
        id: 'coverage.verdicts.complete',
        status: readiness.judgedTraceCount == readiness.traceCount
            ? 'pass'
            : 'fail',
        actual: readiness.judgedTraceCount,
        required: readiness.traceCount,
        comparator: '==',
        blockerCode: 'verdict.missing',
      ),
    if (policy.requiredPrimaryCapabilityIds.isNotEmpty)
      _gateJson(
        id: 'coverage.required_capabilities.present',
        status: readiness.evidence.missingRequiredPrimaryCapabilityIds.isEmpty
            ? 'pass'
            : 'fail',
        actual:
            policy.requiredPrimaryCapabilityIds.length -
            readiness.evidence.missingRequiredPrimaryCapabilityIds.length,
        required: policy.requiredPrimaryCapabilityIds.length,
        comparator: '==',
        blockerCode: 'coverage.capabilityMissing',
        scope: <String, dynamic>{
          'missingCapabilityIds': _sortedStrings(
            readiness.evidence.missingRequiredPrimaryCapabilityIds,
          ),
        },
      ),
  ];
}

List<Map<String, dynamic>> _outcomeGateJson(
  EvalOutcomeQualityEvidence? evidence,
) {
  if (evidence == null) return const <Map<String, dynamic>>[];
  return [
    _gateJson(
      id: 'outcome.aggregate.judge_pass_rate',
      status: _passAtLeast(
        evidence.passRateEstimate.rate,
        1,
      ),
      actual: evidence.passRateEstimate.rate,
      required: 1,
      comparator: '>=',
      blockerCode: 'outcome.passRateLow',
    ),
    _gateJson(
      id: 'outcome.aggregate.judge_pass_lower_bound',
      status: _passAtLeast(evidence.passRateEstimate.lowerBound, 0.7),
      actual: evidence.passRateEstimate.lowerBound,
      required: 0.7,
      comparator: '>=',
      blockerCode: 'outcome.passLowerBoundLow',
    ),
    _gateJson(
      id: 'outcome.aggregate.mean_goal_attainment',
      status: _passAtLeast(evidence.meanGoalAttainment, 4),
      actual: evidence.meanGoalAttainment,
      required: 4,
      comparator: '>=',
      blockerCode: 'outcome.goalAttainmentLow',
    ),
    _gateJson(
      id: 'outcome.aggregate.mean_quality',
      status: _passAtLeast(evidence.meanQuality, 4),
      actual: evidence.meanQuality,
      required: 4,
      comparator: '>=',
      blockerCode: 'outcome.qualityLow',
    ),
    _gateJson(
      id: 'outcome.aggregate.mean_efficiency',
      status: _passAtLeast(evidence.meanEfficiency, 3),
      actual: evidence.meanEfficiency,
      required: 3,
      comparator: '>=',
      blockerCode: 'outcome.efficiencyLow',
    ),
  ];
}

List<Map<String, dynamic>> _pairwiseGateJson(
  EvalPairwisePreferenceReadinessEvidence? evidence,
) {
  if (evidence == null) return const <Map<String, dynamic>>[];
  return [
    _gateJson(
      id: 'pairwise.required_comparisons.present',
      status: evidence.missingRequiredComparisonKeys.isEmpty ? 'pass' : 'fail',
      actual:
          evidence.requiredComparisonKeys.length -
          evidence.missingRequiredComparisonKeys.length,
      required: evidence.requiredComparisonKeys.length,
      comparator: '==',
      blockerCode: 'pairwise.requiredComparisonMissing',
    ),
    _gateJson(
      id: 'pairwise.outcome_expectations.satisfied',
      status: evidence.failedOutcomeComparisonKeys.isEmpty ? 'pass' : 'fail',
      actual: evidence.satisfiedOutcomeCount,
      required: evidence.outcomeExpectationCount,
      comparator: '==',
      blockerCode: 'pairwise.outcomeExpectationFailed',
    ),
  ];
}

List<Map<String, dynamic>> _calibrationGateJson(
  JudgeCalibrationReport? report, {
  required EvalTuningPolicy policy,
}) {
  final gates = <Map<String, dynamic>>[];
  if (policy.requireCalibrationReport) {
    gates.add(
      _gateJson(
        id: 'calibration.report.present',
        status: report == null ? 'fail' : 'pass',
        actual: report == null ? 0 : 1,
        required: 1,
        comparator: '==',
        blockerCode: 'calibration.reportMissing',
      ),
    );
  }
  if (report == null) return gates;
  gates.addAll([
    _gateJson(
      id: 'calibration.evaluated_count',
      status: _passAtLeast(
        report.evaluatedCount,
        policy.minCalibrationEvaluatedCount,
      ),
      actual: report.evaluatedCount,
      required: policy.minCalibrationEvaluatedCount,
      comparator: '>=',
      blockerCode: 'calibration.evaluatedCountLow',
    ),
    _gateJson(
      id: 'calibration.pass_agreement_lower_bound',
      status: _passAtLeast(
        report.passAgreementEstimate.lowerBound,
        policy.minCalibrationPassAgreementLowerBound,
      ),
      actual: report.passAgreementEstimate.lowerBound,
      required: policy.minCalibrationPassAgreementLowerBound,
      comparator: '>=',
      blockerCode: 'calibration.passAgreementLow',
    ),
    _gateJson(
      id: 'calibration.score_agreement_lower_bound',
      status: _passAtLeast(
        report.scoreAgreementEstimate.lowerBound,
        policy.minCalibrationScoreAgreementLowerBound,
      ),
      actual: report.scoreAgreementEstimate.lowerBound,
      required: policy.minCalibrationScoreAgreementLowerBound,
      comparator: '>=',
      blockerCode: 'calibration.scoreAgreementLow',
    ),
  ]);
  return gates;
}

List<Map<String, dynamic>> _promotionGateJson(
  ProfilePromotionDecision? decision,
) {
  if (decision == null) return const <Map<String, dynamic>>[];
  return [
    _gateJson(
      id: 'promotion.status.promote',
      status: decision.promote ? 'pass' : 'fail',
      actual: decision.status.name,
      required: ProfilePromotionStatus.promote.name,
      comparator: '==',
      blockerCode: 'promotion.blocked',
      scope: <String, dynamic>{
        'candidateProfileName': decision.policy.candidateProfileName,
        'baselineProfileName': decision.policy.baselineProfileName,
      },
    ),
  ];
}

Map<String, dynamic> _gateJson({
  required String id,
  required String status,
  required Object? actual,
  required Object? required,
  required String comparator,
  required String blockerCode,
  Map<String, dynamic> scope = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'id': id,
    'status': status,
    'scope': scope,
    if (actual != null) 'actual': _jsonMetricValue(actual),
    if (required != null) 'required': _jsonMetricValue(required),
    'comparator': comparator,
    'evidenceRefs': const <String>[],
    'blockerCode': blockerCode,
  };
}

String _passAtLeast(num actual, num required) =>
    actual >= required ? 'pass' : 'fail';

Object _jsonMetricValue(Object value) {
  if (value case final double number) {
    if (!number.isFinite) {
      throw StateError('Tuning report metric must be finite: $number');
    }
    return number;
  }
  return value;
}

Map<String, dynamic> _blockedReasonForGate(Map<String, dynamic> gate) =>
    <String, dynamic>{
      'code': gate['blockerCode'] as String,
      'severity': 'blocking',
      'scope': gate['scope'] as Map<String, dynamic>,
      'message': 'Gate ${gate['id']} failed.',
      'nextAction': _nextActionForBlockerCode(gate['blockerCode'] as String),
    };

Map<String, dynamic> _blockedReasonJson(
  String message, {
  required String severity,
}) {
  final code = _blockedReasonCode(message);
  return <String, dynamic>{
    'code': code,
    'severity': severity,
    'scope': const <String, dynamic>{},
    'message': message,
    'nextAction': _nextActionForBlockerCode(code),
  };
}

String _blockedReasonCode(String message) {
  final value = message.toLowerCase();
  if (value.contains('missing judge verdict') ||
      value.contains('all verdicts') ||
      value.contains('verdict')) {
    return 'verdict.missing';
  }
  if (value.contains('level 1') || value.contains('level1')) {
    return 'level1.failed';
  }
  if (value.contains('pairwise readiness plan')) {
    return 'pairwise.planMissing';
  }
  if (value.contains('pairwise')) return 'pairwise.gateFailed';
  if (value.contains('calibration report') ||
      value.contains('calibration set')) {
    return 'calibration.reportMissing';
  }
  if (value.contains('calibration')) return 'calibration.gateFailed';
  if (value.contains('protected holdout')) {
    return 'coverage.protectedHoldoutMissing';
  }
  if (value.contains('capability')) return 'coverage.capabilityMissing';
  if (value.contains('promotion')) return 'promotion.blocked';
  if (value.contains('policydigest') || value.contains('policy digest')) {
    return 'policy.digestDrift';
  }
  if (value.contains('manifest') || value.contains('digest')) {
    return 'provenance.bindingInvalid';
  }
  if (value.contains('outcome')) return 'outcome.thresholdFailed';
  return 'readiness.failed';
}

String _nextActionForBlockerCode(String code) {
  if (code.startsWith('verdict.')) return 'gradeVerdicts';
  if (code.startsWith('level1.')) return 'repairLevel1';
  if (code.startsWith('calibration.')) return 'collectCalibrationLabels';
  if (code.startsWith('pairwise.')) return 'runPairwiseReview';
  if (code == 'coverage.capabilityMissing') return 'addCapabilityScenarios';
  if (code == 'coverage.protectedHoldoutMissing') {
    return 'addProtectedHoldouts';
  }
  if (code.startsWith('promotion.')) return 'collectPromotionEvidence';
  if (code.startsWith('policy.') || code.startsWith('provenance.')) {
    return 'rerunWithCurrentManifestBindings';
  }
  if (code.startsWith('outcome.')) return 'tunePromptOrModel';
  return 'inspectReadinessGate';
}

List<Map<String, dynamic>> _dedupeBlockedReasons(
  Iterable<Map<String, dynamic>> reasons,
) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final reason in reasons) {
    final scope = jsonEncode(reason['scope']);
    final key = '${reason['code']}::$scope::${reason['message']}';
    byKey.putIfAbsent(key, () => reason);
  }
  return byKey.values.toList()..sort(
    (a, b) => (a['code'] as String).compareTo(b['code'] as String),
  );
}

List<Map<String, dynamic>> _tuningRecommendations({
  required List<Map<String, dynamic>> blockedReasons,
  required List<Map<String, dynamic>> slices,
  required List<String> suggestedCapabilities,
  required List<String> suggestedScenarioIds,
  required List<String> suggestedProfileNames,
  required List<String> suggestedPromptVariantNames,
  required List<String> requiredPairwiseIntentKeys,
  required List<String> missingPairwiseKeys,
}) {
  final recommendations = <Map<String, dynamic>>[];
  void add({
    required String action,
    required Map<String, dynamic> scope,
    required Map<String, dynamic> selectors,
    required List<String> rationaleCodes,
    List<String> blockedBy = const <String>[],
  }) {
    final id = 'rec-${(recommendations.length + 1).toString().padLeft(3, '0')}';
    recommendations.add(
      <String, dynamic>{
        'id': id,
        'priority': recommendations.length + 1,
        'action': action,
        'status': 'recommended',
        'scope': scope,
        'selectors': selectors,
        'blockedBy': blockedBy,
        'rationaleCodes': _sortedStrings(rationaleCodes),
      },
    );
  }

  final blockerCodes = _sortedStrings(
    blockedReasons.map((reason) => reason['code'] as String),
  );
  if (blockerCodes.any((code) => code.startsWith('verdict.'))) {
    add(
      action: 'gradeVerdicts',
      scope: const <String, dynamic>{},
      selectors: const <String, dynamic>{},
      rationaleCodes: ['verdict.missing'],
    );
  }
  if (blockerCodes.any((code) => code.startsWith('calibration.'))) {
    add(
      action: 'collectCalibrationLabels',
      scope: const <String, dynamic>{},
      selectors: const <String, dynamic>{},
      rationaleCodes: [
        for (final code in blockerCodes)
          if (code.startsWith('calibration.')) code,
      ],
    );
  }
  if (blockerCodes.any((code) => code.startsWith('pairwise.'))) {
    add(
      action: 'runPairwiseReview',
      scope: const <String, dynamic>{},
      selectors: <String, dynamic>{
        'requiredPairwiseIntentKeys': requiredPairwiseIntentKeys,
        'missingOrFailedPairwiseKeys': missingPairwiseKeys,
      },
      rationaleCodes: [
        for (final code in blockerCodes)
          if (code.startsWith('pairwise.')) code,
      ],
    );
  }
  if (blockerCodes.contains('coverage.capabilityMissing')) {
    add(
      action: 'addCapabilityScenarios',
      scope: const <String, dynamic>{},
      selectors: <String, dynamic>{
        'capabilityIds': suggestedCapabilities,
      },
      rationaleCodes: ['coverage.capabilityMissing'],
    );
  }
  if (blockerCodes.contains('coverage.protectedHoldoutMissing')) {
    add(
      action: 'addProtectedHoldouts',
      scope: const <String, dynamic>{},
      selectors: const <String, dynamic>{},
      rationaleCodes: ['coverage.protectedHoldoutMissing'],
    );
  }
  for (final slice in slices) {
    final recommendation = slice['recommendation'] as String;
    if (recommendation == 'keep') continue;
    final blockingReasons = (slice['blockingReasons'] as List<dynamic>)
        .whereType<String>();
    add(
      action: recommendation,
      scope: _sliceScope(slice),
      selectors: <String, dynamic>{
        'scenarioIds': suggestedScenarioIds,
        'profileNames': suggestedProfileNames,
        'promptVariantNames': suggestedPromptVariantNames,
      },
      rationaleCodes: blockingReasons.toList(),
      blockedBy: blockerCodes,
    );
  }
  return recommendations;
}

Map<String, dynamic> _sliceScope(Map<String, dynamic> slice) =>
    <String, dynamic>{
      'capabilityId': slice['primaryCapabilityId'],
      'agentKind': slice['agentKind'],
      'modelClass': slice['modelClass'],
      'promptVariantName': slice['promptVariantName'],
    };

Map<String, dynamic>? _outcomeQualityJson(
  EvalOutcomeQualityEvidence? evidence,
) {
  if (evidence == null) return null;
  return <String, dynamic>{
    'expectedTraceCount': evidence.expectedTraceCount,
    'judgedTraceCount': evidence.judgedTraceCount,
    'passTraceCount': evidence.passTraceCount,
    'expectedSliceCount': evidence.expectedSliceCount,
    'judgedSliceCount': evidence.judgedSliceCount,
    'passRate': _finiteDouble(evidence.passRateEstimate.rate),
    'passRateLowerBound': _finiteDouble(evidence.passRateEstimate.lowerBound),
    'meanGoalAttainment': _finiteDouble(evidence.meanGoalAttainment),
    'meanQuality': _finiteDouble(evidence.meanQuality),
    'meanEfficiency': _finiteDouble(evidence.meanEfficiency),
    'meanTokenBudgetRatio': _finiteDouble(evidence.meanTokenBudgetRatio),
    'weightedCostTraceCount': evidence.weightedCostTraceCount,
    'missingWeightedCostTraceCount': evidence.missingWeightedCostTraceCount,
    'meanWeightedCostBudgetRatio': _finiteDouble(
      evidence.meanWeightedCostBudgetRatio,
    ),
  };
}

Map<String, dynamic> _pairwiseEvidenceJson(
  EvalPairwisePreferenceReadinessEvidence? evidence, {
  required EvalPairwiseReadinessPlan? pairwiseReadinessPlan,
  required int voteCount,
}) {
  return <String, dynamic>{
    'present':
        evidence != null || pairwiseReadinessPlan != null || voteCount > 0,
    'planId': pairwiseReadinessPlan?.planId,
    'requiredIntentKeys': _sortedStrings(
      pairwiseReadinessPlan?.requiredComparisonIntentKeys ?? const <String>{},
    ),
    'voteCount': evidence?.voteCount ?? voteCount,
    'pairCount': evidence?.pairCount ?? 0,
    'decisionCount': evidence?.decisionCount ?? 0,
    'outcomeExpectationCount': evidence?.outcomeExpectationCount ?? 0,
    'satisfiedOutcomeCount': evidence?.satisfiedOutcomeCount ?? 0,
    'missingRequiredComparisonKeys': _sortedStrings(
      evidence?.missingRequiredComparisonKeys ?? const <String>{},
    ),
    'failedOutcomeComparisonKeys': _sortedStrings(
      evidence?.failedOutcomeComparisonKeys ?? const <String>{},
    ),
    'unregisteredComparisonKeys': _sortedStrings(
      evidence?.unregisteredComparisonKeys ?? const <String>{},
    ),
    'reviewProtocolKeys': _sortedStrings(
      evidence?.reviewProtocolKeys ?? const <String>{},
    ),
  };
}

Map<String, dynamic> _calibrationReportJson(
  JudgeCalibrationReport report,
) => <String, dynamic>{
  'calibrationSetVersion': report.calibrationSetVersion,
  'judgeCalibrationSetVersion': report.judgeCalibrationSetVersion,
  'labelCount': report.labelCount,
  'judgedTraceCount': report.judgedTraceCount,
  'evaluatedCount': report.evaluatedCount,
  'goldCoverageRate': report.goldCoverageRate,
  'goldCoverageLowerBound': report.goldCoverageEstimate.lowerBound,
  'passAgreementRate': report.passAgreementRate,
  'passAgreementLowerBound': _finiteDouble(
    report.passAgreementEstimate.lowerBound,
  ),
  'scoreAgreementRate': report.scoreAgreementRate,
  'scoreAgreementLowerBound': _finiteDouble(
    report.scoreAgreementEstimate.lowerBound,
  ),
  'falsePassCount': report.falsePassCount,
  'falseFailCount': report.falseFailCount,
  'protectedHoldoutLabelCount': report.protectedHoldoutLabelCount,
  'protectedHoldoutEvaluatedCount': report.protectedHoldoutEvaluatedCount,
  'unresolvedHumanDisagreementCount': report.unresolvedHumanDisagreementCount,
  'findingCount': report.findings.length,
};

Map<String, dynamic> _calibrationFindingJson(
  JudgeCalibrationFinding finding,
) => <String, dynamic>{
  'kind': finding.kind.name,
  'key': finding.key,
  'detail': finding.detail,
};

Map<String, dynamic> _promotionDecisionJson(
  ProfilePromotionDecision decision,
) => <String, dynamic>{
  'present': true,
  'status': decision.status.name,
  'candidateProfileName': decision.policy.candidateProfileName,
  'baselineProfileName': decision.policy.baselineProfileName,
  'evidencePlan': decision.evidencePlan == null
      ? null
      : _promotionEvidencePlanJson(decision.evidencePlan!),
  'failures': decision.failures,
  'warnings': decision.warnings,
  if (decision.comparison != null)
    'comparison': <String, dynamic>{
      'pairedScenarioCount': decision.comparison!.pairedScenarioCount,
      'judgePassDelta': decision.comparison!.judgePassDelta,
      'judgePassDeltaLowerBound': decision.comparison!.judgePassDeltaLowerBound,
      'meanQualityDelta': decision.comparison!.meanQualityDelta,
      'meanEfficiencyDelta': decision.comparison!.meanEfficiencyDelta,
      'totalTokenRatio': decision.comparison!.totalTokenRatio,
      'estimatedCostRatio': decision.comparison!.estimatedCostRatio,
    },
};

Map<String, dynamic> _promotionEvidencePlanJson(
  ProfilePromotionEvidencePlan plan,
) => <String, dynamic>{
  'currentPairedScenarioCount': plan.currentPairedScenarioCount,
  'currentJudgePairedScenarioCount': plan.currentJudgePairedScenarioCount,
  'additionalPairedScenariosForMinCount':
      plan.additionalPairedScenariosForMinCount,
  'additionalJudgeScenariosForMinCount':
      plan.additionalJudgeScenariosForMinCount,
  'additionalJudgeScenariosForLowerBound':
      plan.additionalJudgeScenariosForLowerBound,
  'additionalJudgeScenariosForPairedSignTest':
      plan.additionalJudgeScenariosForPairedSignTest,
  'projectedJudgePairedScenarioCount': plan.projectedJudgePairedScenarioCount,
  'projectedJudgePassDeltaLowerBound': plan.projectedJudgePassDeltaLowerBound,
  'projectedJudgePairedSignTestPValue': plan.projectedJudgePairedSignTestPValue,
  'assumedCandidateJudgePassRate': plan.assumedCandidateJudgePassRate,
  'assumedBaselineJudgePassRate': plan.assumedBaselineJudgePassRate,
  'recommendedAdditionalJudgeScenarios':
      plan.recommendedAdditionalJudgeScenarios,
  'blockers': plan.blockers,
};

Map<String, int> _stringIntMapJson(Map<String, int> values) => <String, int>{
  for (final key in values.keys.toList()..sort()) key: values[key]!,
};

Map<String, int> _enumIntMapJson<K extends Enum>(Map<K, int> values) =>
    <String, int>{
      for (final key
          in values.keys.toList()..sort((a, b) => a.name.compareTo(b.name)))
        key.name: values[key]!,
    };

List<String> _sortedStrings(Iterable<String> values) =>
    values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();

double _finiteDouble(double value) {
  if (!value.isFinite) {
    throw StateError('Tuning report metric must be finite: $value');
  }
  return value;
}

class _TuningSliceAccumulator {
  _TuningSliceAccumulator({
    required this.primaryCapabilityId,
    required this.agentKind,
    required this.modelClass,
    required this.promptVariantName,
  });

  final String primaryCapabilityId;
  final String agentKind;
  final String modelClass;
  final String promptVariantName;
  final scenarioIds = <String>{};
  final profileNames = <String>{};
  final verdicts = <JudgeVerdict>[];
  final tokenBudgetRatios = <double>[];
  final weightedCostBudgetRatios = <double>[];
  int traceCount = 0;
  int level1PassCount = 0;
  int missingWeightedCostCount = 0;

  String get sliceKey =>
      '$primaryCapabilityId@$agentKind@$modelClass@$promptVariantName';

  int get judgedTraceCount => verdicts.length;

  int get passCount => verdicts.where((verdict) => verdict.pass).length;

  RateEstimate get passEstimate => RateEstimate.wilson(
    successes: passCount,
    total: judgedTraceCount,
  );

  double get passRate => _rate(passCount, judgedTraceCount);

  double get meanGoalAttainment => _mean(
    verdicts.map((verdict) => verdict.goalAttainment.toDouble()),
  );

  double get meanQuality => _mean(
    verdicts.map((verdict) => verdict.quality.toDouble()),
  );

  double get meanEfficiency => _mean(
    verdicts.map((verdict) => verdict.efficiency.toDouble()),
  );

  double get meanTokenBudgetRatio => _mean(tokenBudgetRatios);

  double get meanWeightedCostBudgetRatio => _mean(weightedCostBudgetRatios);

  void add(EvalTrace trace, {required String scenarioId}) {
    scenarioIds.add(scenarioId);
    profileNames.add(trace.profile.name);
    traceCount += 1;
    if (trace.level1Passed) {
      level1PassCount += 1;
    }
    final verdict = trace.verdict;
    if (verdict == null) return;
    verdicts.add(verdict);
    tokenBudgetRatios.add(
      _rate(trace.output.usage.totalTokens, trace.profile.tokenBudget),
    );
    final weightedCost = trace.profile.estimatedUsageCostMicrosOrNull(
      trace.output.usage,
      requireCoreTokenCounts: trace.profile.usesWeightedTokenCosts,
    );
    if (weightedCost == null) {
      if (trace.profile.usesWeightedTokenCosts) {
        missingWeightedCostCount += 1;
      }
      return;
    }
    weightedCostBudgetRatios.add(
      _rate(weightedCost, trace.profile.tokenBudget),
    );
  }

  Map<String, dynamic> toJson(EvalTuningPolicy policy) {
    final gates = _gates(policy);
    return <String, dynamic>{
      'sliceKey': sliceKey,
      'primaryCapabilityId': primaryCapabilityId,
      'agentKind': agentKind,
      'modelClass': modelClass,
      'promptVariantName': promptVariantName,
      'scenarioIds': _sortedStrings(scenarioIds),
      'profileNames': _sortedStrings(profileNames),
      'traceCount': traceCount,
      'judgedTraceCount': judgedTraceCount,
      'passCount': passCount,
      'level1PassCount': level1PassCount,
      'passRate': _finiteDouble(passRate),
      'passRateLowerBound': _finiteDouble(passEstimate.lowerBound),
      'meanGoalAttainment': _finiteDouble(meanGoalAttainment),
      'meanQuality': _finiteDouble(meanQuality),
      'meanEfficiency': _finiteDouble(meanEfficiency),
      'meanTokenBudgetRatio': _finiteDouble(meanTokenBudgetRatio),
      'weightedCostTraceCount': weightedCostBudgetRatios.length,
      'missingWeightedCostCount': missingWeightedCostCount,
      'meanWeightedCostBudgetRatio': _finiteDouble(
        meanWeightedCostBudgetRatio,
      ),
      'recommendation': _recommendation(policy),
      'blockingReasons': [
        for (final gate in gates)
          if (gate['status'] == 'fail') gate['blockerCode'] as String,
      ],
      'gates': gates,
    };
  }

  List<Map<String, dynamic>> _gates(EvalTuningPolicy policy) {
    final scope = <String, dynamic>{
      'capabilityId': primaryCapabilityId,
      'agentKind': agentKind,
      'modelClass': modelClass,
      'promptVariantName': promptVariantName,
    };
    return [
      if (policy.requireAllVerdicts)
        _gateJson(
          id: 'outcome.slice.verdict_coverage',
          status: judgedTraceCount == traceCount ? 'pass' : 'fail',
          actual: judgedTraceCount,
          required: traceCount,
          comparator: '==',
          blockerCode: 'verdict.missing',
          scope: scope,
        ),
      if (policy.requireAllLevel1Passed)
        _gateJson(
          id: 'outcome.slice.level1_all_passed',
          status: level1PassCount == traceCount ? 'pass' : 'fail',
          actual: level1PassCount,
          required: traceCount,
          comparator: '==',
          blockerCode: 'level1.failed',
          scope: scope,
        ),
      if (policy.minJudgePassRate > 0)
        _gateJson(
          id: 'outcome.slice.judge_pass_rate',
          status: _passAtLeast(passRate, policy.minJudgePassRate),
          actual: passRate,
          required: policy.minJudgePassRate,
          comparator: '>=',
          blockerCode: 'outcome.passRateLow',
          scope: scope,
        ),
      if (policy.minJudgePassRateLowerBound > 0)
        _gateJson(
          id: 'outcome.slice.judge_pass_lower_bound',
          status: _passAtLeast(
            passEstimate.lowerBound,
            policy.minJudgePassRateLowerBound,
          ),
          actual: passEstimate.lowerBound,
          required: policy.minJudgePassRateLowerBound,
          comparator: '>=',
          blockerCode: 'outcome.passLowerBoundLow',
          scope: scope,
        ),
      if (policy.minMeanGoalAttainment > 0)
        _gateJson(
          id: 'outcome.slice.mean_goal_attainment',
          status: _passAtLeast(
            meanGoalAttainment,
            policy.minMeanGoalAttainment,
          ),
          actual: meanGoalAttainment,
          required: policy.minMeanGoalAttainment,
          comparator: '>=',
          blockerCode: 'outcome.goalAttainmentLow',
          scope: scope,
        ),
      if (policy.minMeanQuality > 0)
        _gateJson(
          id: 'outcome.slice.mean_quality',
          status: _passAtLeast(meanQuality, policy.minMeanQuality),
          actual: meanQuality,
          required: policy.minMeanQuality,
          comparator: '>=',
          blockerCode: 'outcome.qualityLow',
          scope: scope,
        ),
      if (policy.minMeanEfficiency > 0)
        _gateJson(
          id: 'outcome.slice.mean_efficiency',
          status: _passAtLeast(meanEfficiency, policy.minMeanEfficiency),
          actual: meanEfficiency,
          required: policy.minMeanEfficiency,
          comparator: '>=',
          blockerCode: 'outcome.efficiencyLow',
          scope: scope,
        ),
      if (policy.maxMeanTokensPerTraceBudgetRatio case final maxTokens?)
        _gateJson(
          id: 'outcome.slice.mean_token_budget_ratio',
          status: meanTokenBudgetRatio <= maxTokens ? 'pass' : 'fail',
          actual: meanTokenBudgetRatio,
          required: maxTokens,
          comparator: '<=',
          blockerCode: 'outcome.tokenBudgetHigh',
          scope: scope,
        ),
      if (policy.requireWeightedCostEvidence)
        _gateJson(
          id: 'outcome.slice.weighted_cost_evidence',
          status: missingWeightedCostCount == 0 ? 'pass' : 'fail',
          actual: missingWeightedCostCount,
          required: 0,
          comparator: '==',
          blockerCode: 'outcome.weightedCostMissing',
          scope: scope,
        ),
      if (policy.maxMeanWeightedCostPerTraceBudgetRatio case final maxCost?)
        _gateJson(
          id: 'outcome.slice.mean_weighted_cost_budget_ratio',
          status: meanWeightedCostBudgetRatio <= maxCost ? 'pass' : 'fail',
          actual: meanWeightedCostBudgetRatio,
          required: maxCost,
          comparator: '<=',
          blockerCode: 'outcome.weightedCostBudgetHigh',
          scope: scope,
        ),
    ];
  }

  String _recommendation(EvalTuningPolicy policy) {
    if (policy.requireAllVerdicts && judgedTraceCount < traceCount) {
      return 'gradeVerdicts';
    }
    if (policy.requireAllLevel1Passed && level1PassCount < traceCount) {
      return 'repairLevel1';
    }
    if ((policy.requireAllJudgePasses && passCount < judgedTraceCount) ||
        passRate < policy.minJudgePassRate ||
        passEstimate.lowerBound < policy.minJudgePassRateLowerBound ||
        meanGoalAttainment < policy.minMeanGoalAttainment) {
      return 'improveOutcome';
    }
    if (meanQuality < policy.minMeanQuality) return 'improveQuality';
    if (meanEfficiency < policy.minMeanEfficiency) return 'improveEfficiency';
    final maxTokens = policy.maxMeanTokensPerTraceBudgetRatio;
    if (maxTokens != null && meanTokenBudgetRatio > maxTokens) {
      return 'reduceTokenBudget';
    }
    if (policy.requireWeightedCostEvidence && missingWeightedCostCount > 0) {
      return 'addCostEvidence';
    }
    final maxCost = policy.maxMeanWeightedCostPerTraceBudgetRatio;
    if (maxCost != null && meanWeightedCostBudgetRatio > maxCost) {
      return 'reduceWeightedCost';
    }
    return 'keep';
  }
}

double _rate(int count, int total) => total == 0 ? 0 : count / total;

double _mean(Iterable<double> values) {
  var count = 0;
  var sum = 0.0;
  for (final value in values) {
    count += 1;
    sum += value;
  }
  return count == 0 ? 0 : sum / count;
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

EvalTrace _promotionTraceForProfile(
  EvalProfile profile, {
  EvalScenario? scenario,
  JudgeVerdict? verdict,
  AgentRunOutput output = const AgentRunOutput(
    success: true,
    usage: InferenceUsage(inputTokens: 100, outputTokens: 50),
    report: AgentReportRecord(
      oneLiner: 'Done',
      tldr: 'Task was handled.',
      content: 'Handled.',
    ),
  ),
  List<EvalCheck>? level1Checks,
  int trialIndex = 0,
  String runId = 'promotion-config-test',
  String? manifestDigest,
}) {
  final resolvedScenario = scenario ?? taskReleaseNotesScenario;
  return EvalTrace(
    runId: runId,
    trialIndex: trialIndex,
    scenario: resolvedScenario,
    profile: profile,
    provenance: EvalProvenance.capture(
      scenario: resolvedScenario,
      profile: profile,
      manifestDigest: manifestDigest ?? EvalProvenance.unboundManifestDigest,
    ),
    output: output,
    level1Checks:
        level1Checks ?? runLevel1(resolvedScenario, output, profile: profile),
    verdict: verdict,
  );
}

EvalScenario _privateHoldoutScenario(String id) => EvalScenario(
  id: id,
  title: 'Private holdout task',
  agentKind: taskReleaseNotesScenario.agentKind,
  appState: taskReleaseNotesScenario.appState,
  userInput: taskReleaseNotesScenario.userInput,
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['task.private.holdout'],
    split: EvalScenarioSplit.holdout,
    source: EvalScenarioSource.productionReplay,
    tags: {'private', 'holdout'},
  ),
);

AgentRunOutput _promotionOutputForProfile(EvalProfile profile) {
  final profileConfig = evalProfileConfig(profile);
  return AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 50),
    report: const AgentReportRecord(
      oneLiner: 'Done',
      tldr: 'Task was handled.',
      content: 'Handled.',
    ),
    resolvedModel: profileConfig.toResolvedModelRecord(),
    providerDecision: profileConfig.toProviderDecisionRecord(),
  );
}

EvalRunManifest _promotionManifest({
  bool includePromotionPlanEvidence = true,
  EvalPairwiseReadinessPlanEvidence? pairwiseReadinessPlanEvidence,
  EvalTuningReadinessContractEvidence? tuningReadinessContractEvidence,
  EvalTuningReadinessPolicyEvidence? tuningReadinessPolicyEvidence,
  EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
}) {
  final scenarioSetDigest = EvalProvenance.scenarioSetDigest([
    taskReleaseNotesScenario,
  ]);
  final profileSetDigest = EvalProvenance.profileSetDigest(kDefaultProfiles);
  final profileExecutionBindings = [
    for (final profile in kDefaultProfiles)
      evalProfileConfig(profile).toExecutionBinding(),
  ];
  const agentDirectiveVariants = [EvalAgentDirectiveVariant()];
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
    agentDirectiveVariantSetDigest:
        EvalProvenance.agentDirectiveVariantSetDigest(agentDirectiveVariants),
    agentDirectiveVariants: agentDirectiveVariants,
    promptDigest: EvalProvenance.digestText('prompt'),
    toolSchemaDigest: EvalProvenance.digestText('tool-schema'),
    codeRevision: 'test-revision',
    gitDirty: false,
    envPresence: const {},
    scenarioCatalogEvidence: scenarioCatalogEvidence,
    promotionPlanEvidence: includePromotionPlanEvidence
        ? EvalProvenance.promotionPlanEvidence(promotionPlan)
        : null,
    pairwiseReadinessPlanEvidence: pairwiseReadinessPlanEvidence,
    tuningReadinessContractEvidence: tuningReadinessContractEvidence,
    tuningReadinessPolicyEvidence: tuningReadinessPolicyEvidence,
  );
  return manifest.withManifestDigest(EvalProvenance.manifestDigest(manifest));
}

JudgeVerdict _promotionVerdict({
  required int goalAttainment,
  required int quality,
  required int efficiency,
  bool pass = true,
}) {
  return JudgeVerdict(
    goalAttainment: goalAttainment,
    quality: quality,
    efficiency: efficiency,
    pass: pass,
    judge: JudgeProvenanceRecord(
      judgeName: 'fixture-judge',
      judgeModel: 'fixture-model',
      promptDigest: EvalProvenance.promptDigest(),
      calibrationSetVersion: 'fixture-gold-v1',
      profileVisible: true,
      modelIdentityVisible: true,
    ),
    rationale: 'Fixture verdict for tuning report tests.',
  );
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

Map<String, dynamic> _pairwiseReadinessPlanJson({
  required EvalRunManifest manifest,
  required List<String> requiredComparisonKeys,
  String planId = 'pairwise-readiness-plan-test',
  String? scenarioSetDigest,
  String? profileSetDigest,
  String? profileBindingSetDigest,
  String? manifestDigest,
  bool includeManifestDigest = true,
  String? promptDigest,
  String calibrationSetVersion = _pairwiseReadinessCalibrationSetVersion,
  String? judgeManifestDigest,
  String? privateKeyDigest,
  Map<String, String> reviewPayloadDigests = const {},
  int minDecisions = 1,
  int minVotes = 1,
  double quorumFraction = 1,
}) {
  final resolvedManifestDigest = includeManifestDigest
      ? manifestDigest ?? manifest.manifestDigest
      : manifestDigest;
  return <String, dynamic>{
    'schemaVersion': EvalPairwiseReadinessPlan.schemaVersionValue,
    'kind': EvalPairwiseReadinessPlan.kindValue,
    'planId': planId,
    'baseReadinessPolicy': 'modelClassTuning',
    'createdAt': '2026-06-10T00:00:00Z',
    'scenarioSetDigest': scenarioSetDigest ?? manifest.scenarioSetDigest,
    'profileSetDigest': profileSetDigest ?? manifest.profileSetDigest,
    'profileBindingSetDigest':
        profileBindingSetDigest ?? manifest.profileBindingSetDigest,
    // ignore: use_null_aware_elements
    if (resolvedManifestDigest != null)
      'manifestDigest': resolvedManifestDigest,
    'minBlindedPairwisePreferenceDecisions': minDecisions,
    'comparisons': [
      for (final key in requiredComparisonKeys)
        <String, dynamic>{
          'comparisonKey': key,
          'reviewPayloadDigest':
              reviewPayloadDigests[key] ??
              EvalProvenance.digestText('review-payload:$key'),
        },
    ],
    'reviewProtocol': <String, dynamic>{
      'reviewerKind': EvalPairwiseReviewerKind.human.name,
      'reviewerModel': null,
      'promptDigest': promptDigest ?? _pairwiseReadinessPromptDigest,
      'calibrationSetVersion': calibrationSetVersion,
      'profileVisible': false,
      'modelIdentityVisible': false,
      'peerVotesVisible': false,
      'traceOrderRandomized': true,
    },
    'importBinding': <String, dynamic>{
      'judgeManifestDigest':
          judgeManifestDigest ??
          EvalProvenance.digestText('pairwise-readiness-judge-manifest'),
      'privateKeyDigest':
          privateKeyDigest ??
          EvalProvenance.digestText('pairwise-readiness-private-key'),
    },
    'blindedPairwisePreferencePolicy': <String, dynamic>{
      'minVotes': minVotes,
      'quorumFraction': quorumFraction,
      'requireModelIdentityBlind': true,
      'requireProfileBlind': true,
      'requirePeerVoteBlind': true,
      'requireTraceOrderRandomized': true,
      'requireBlindedImport': true,
    },
    'notes': 'test fixture',
  };
}

({EvalRunManifest manifest, Map<String, dynamic> planJson})
_manifestBoundPairwiseReadinessPlanJson({
  required List<String> requiredComparisonKeys,
  String planId = 'pairwise-readiness-plan-test',
  int minDecisions = 1,
  int minVotes = 1,
  double quorumFraction = 1,
  String? promptDigest,
  String calibrationSetVersion = _pairwiseReadinessCalibrationSetVersion,
  String? judgeManifestDigest,
  String? privateKeyDigest,
  Map<String, String> reviewPayloadDigests = const {},
}) {
  final draftManifest = _promotionManifest();
  final draftPlanJson = _pairwiseReadinessPlanJson(
    manifest: draftManifest,
    requiredComparisonKeys: requiredComparisonKeys,
    planId: planId,
    includeManifestDigest: false,
    minDecisions: minDecisions,
    minVotes: minVotes,
    quorumFraction: quorumFraction,
    promptDigest: promptDigest,
    calibrationSetVersion: calibrationSetVersion,
    judgeManifestDigest: judgeManifestDigest,
    privateKeyDigest: privateKeyDigest,
    reviewPayloadDigests: reviewPayloadDigests,
  );
  final draftPlan = EvalPairwiseReadinessPlan.fromJson(draftPlanJson);
  final manifest = _promotionManifest(
    pairwiseReadinessPlanEvidence: draftPlan.toManifestEvidence(),
  );
  return (
    manifest: manifest,
    planJson: <String, dynamic>{
      ...draftPlanJson,
      'manifestDigest': manifest.manifestDigest,
    },
  );
}

const _pairwiseReadinessCalibrationSetVersion = 'pairwise-human-gold-v1';

final String _pairwiseReadinessPromptDigest = EvalProvenance.digestText(
  'pairwise-readiness-prompt',
);

EvalPairwisePreferenceVote _pairwiseReadinessVote({
  required EvalRunManifest manifest,
  String voteId = 'pairwise-readiness-vote',
  String reviewerId = 'pairwise-readiness-reviewer',
  String? promptDigest,
  String calibrationSetVersion = _pairwiseReadinessCalibrationSetVersion,
  String? reviewPayloadDigest,
  String? judgeManifestDigest,
  String? privateKeyDigest,
  EvalPairwisePreferenceChoice choice = EvalPairwisePreferenceChoice.optionA,
}) {
  final optionA = _pairwiseRef(_promotionTraceForProfile(kFrontierFastProfile));
  final optionB = _pairwiseRef(_promotionTraceForProfile(kFrontierProfile));
  return EvalPairwisePreferenceVote(
    voteId: voteId,
    optionA: optionA,
    optionB: optionB,
    reviewerId: reviewerId,
    reviewerKind: EvalPairwiseReviewerKind.human,
    promptDigest: promptDigest ?? _pairwiseReadinessPromptDigest,
    calibrationSetVersion: calibrationSetVersion,
    profileVisible: false,
    modelIdentityVisible: false,
    peerVotesVisible: false,
    traceOrderRandomized: true,
    choice: choice,
    rationale: 'Digest-bound readiness fixture.',
    blindedImport: BlindedPairwisePreferenceImportRecord(
      blindedPairId: EvalProvenance.digestText(
        'blind:${optionA.artifactKey}:${optionB.artifactKey}',
      ),
      reviewPayloadDigest:
          reviewPayloadDigest ??
          EvalProvenance.digestText(
            'review:${optionA.artifactKey}:${optionB.artifactKey}',
          ),
      judgeManifestDigest:
          judgeManifestDigest ??
          EvalProvenance.digestText('pairwise-readiness-judge-manifest'),
      privateKeyDigest:
          privateKeyDigest ??
          EvalProvenance.digestText('pairwise-readiness-private-key'),
      sourceManifestDigest: manifest.manifestDigest!,
      optionARawTraceDigest: optionA.traceDigest,
      optionBRawTraceDigest: optionB.traceDigest,
    ),
  );
}

EvalPairwiseTraceRef _pairwiseRef(EvalTrace trace) =>
    EvalPairwiseTraceRef.fromTrace(
      trace,
      traceDigest: EvalProvenance.digestJson(trace.toJson()),
    );

EvalPairwiseReadinessIntentOption _pairwiseIntentOptionFor(
  EvalPairwiseTraceRef ref,
) => EvalPairwiseReadinessIntentOption(
  profileName: ref.profileName,
  profileDigest: ref.profileDigest,
  modelClass: ref.modelClass,
  agentDirectiveVariantName: ref.agentDirectiveVariantName,
  agentDirectiveVariantDigest: ref.agentDirectiveVariantDigest,
);

File _writePairwiseReadinessPlan(Map<String, dynamic> planJson) {
  final directory = Directory.systemTemp.createTempSync(
    'lotti_eval_pairwise_readiness_plan_',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return File(p.join(directory.path, 'pairwise_readiness_plan.json'))
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(planJson));
}

Future<TraceWriter> _writerWithPairwiseReadinessRegistration({
  required EvalRunManifest manifest,
  required Map<String, dynamic> planJson,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'lotti_eval_pairwise_readiness_registration_',
  );
  addTearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });
  final writer = TraceWriter(runsRoot: p.join(directory.path, 'runs'));
  final plan = EvalPairwiseReadinessPlan.fromJson(planJson);
  await writer.writePairwiseReadinessPlanRegistration(
    EvalPairwiseReadinessPlanRegistration(
      runId: manifest.runId,
      sourceManifestDigest: manifest.manifestDigest!,
      evidence: plan.toManifestEvidence(),
    ),
  );
  return writer;
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

List<EvalAgentDirectiveVariant> _loadPromptVariants() {
  return EvalAgentDirectiveVariantCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: _promptVariantCatalogValueFromDefine(),
    dartDefineVariantNames: _promptVariantNamesFromDefine(),
  ).variants;
}

String _scenarioCatalogPathFromDefine() => _scenarioCatalogPath;

String _scenarioCatalogModeFromDefine() => _scenarioCatalogMode;

String _scenarioIdsFromDefine() => _scenarioIds;

String _profileCatalogValueFromDefine() => _profileCatalogValue;

String _profileNamesFromDefine() => _profileNames;

String _promptVariantCatalogValueFromDefine() => _promptVariantCatalogValue;

String _promptVariantNamesFromDefine() => _promptVariantNames;

bool _hasExternalScenarioCatalog() {
  return _scenarioCatalogPathValue() != null;
}

bool _hasScenarioIdSelection() {
  final fromDefine = _scenarioIdsFromDefine().trim();
  if (fromDefine.isNotEmpty) return true;
  final fromEnvironment = Platform.environment[kEvalScenarioIdsEnv]?.trim();
  return fromEnvironment != null && fromEnvironment.isNotEmpty;
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

String _scenarioCatalogModeValue() {
  final fromDefine = _scenarioCatalogModeFromDefine().trim();
  if (fromDefine.isNotEmpty) return fromDefine;
  final fromEnvironment = Platform.environment[kEvalScenarioCatalogModeEnv]
      ?.trim();
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  return 'append';
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

String? _blindedExportSeedValue({
  String value = _blindedExportSeed,
}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _pairwiseBlindedExportSeedValue({
  String value = _pairwiseBlindedExportSeed,
}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _pairwiseReadinessPlanIdValue({
  String value = _pairwiseReadinessPlanId,
}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _pairwiseReadinessMinDecisionsValue({
  String value = _pairwiseReadinessMinDecisions,
}) => _positiveOptionalInt(
  envName: 'EVAL_PAIRWISE_READINESS_MIN_DECISIONS',
  value: value,
);

int? _pairwiseReadinessMinVotesValue({
  String value = _pairwiseReadinessMinVotes,
}) => _positiveOptionalInt(
  envName: 'EVAL_PAIRWISE_READINESS_MIN_VOTES',
  value: value,
);

double? _pairwiseReadinessQuorumFractionValue({
  String value = _pairwiseReadinessQuorumFraction,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 1) {
    throw StateError(
      'EVAL_PAIRWISE_READINESS_QUORUM_FRACTION must be > 0 and <= 1: '
      '$value',
    );
  }
  return parsed;
}

EvalPairwiseReadinessReviewProtocol?
_pairwiseReadinessReviewProtocolFromConfig({
  String reviewerKind = _pairwiseReadinessReviewerKind,
  String reviewerModel = _pairwiseReadinessReviewerModel,
  String promptDigest = _pairwiseReadinessReviewPromptDigest,
  String calibrationSetVersion = _pairwiseReadinessReviewCalibrationSetVersion,
}) {
  final kindValue = reviewerKind.trim();
  final modelValue = reviewerModel.trim();
  final promptValue = promptDigest.trim();
  final calibrationValue = calibrationSetVersion.trim();
  if (kindValue.isEmpty &&
      modelValue.isEmpty &&
      promptValue.isEmpty &&
      calibrationValue.isEmpty) {
    return null;
  }

  final defaultProtocol =
      EvalBlindedPairwisePreference.defaultReadinessReviewProtocol();
  final kind = _pairwiseReadinessReviewerKindValue(
    kindValue: kindValue,
    modelValue: modelValue,
  );
  final model = modelValue.isEmpty ? null : modelValue;
  if (kind == EvalPairwiseReviewerKind.human && model != null) {
    throw StateError(
      'EVAL_PAIRWISE_REVIEWER_MODEL requires '
      'EVAL_PAIRWISE_REVIEWER_KIND=llmJudge.',
    );
  }
  if (kind == EvalPairwiseReviewerKind.llmJudge && model == null) {
    throw StateError(
      'EVAL_PAIRWISE_REVIEWER_KIND=llmJudge requires '
      'EVAL_PAIRWISE_REVIEWER_MODEL.',
    );
  }
  if (kind == EvalPairwiseReviewerKind.llmJudge && promptValue.isEmpty) {
    throw StateError(
      'EVAL_PAIRWISE_REVIEWER_KIND=llmJudge requires '
      'EVAL_PAIRWISE_REVIEW_PROMPT_DIGEST.',
    );
  }
  final resolvedPromptDigest = promptValue.isEmpty
      ? defaultProtocol.promptDigest
      : promptValue;
  if (!EvalProvenance.isDigest(resolvedPromptDigest)) {
    throw StateError(
      'EVAL_PAIRWISE_REVIEW_PROMPT_DIGEST must be a sha256 digest: '
      '$promptDigest',
    );
  }
  return EvalPairwiseReadinessReviewProtocol(
    reviewerKind: kind,
    reviewerModel: model,
    promptDigest: resolvedPromptDigest,
    calibrationSetVersion: calibrationValue.isEmpty
        ? defaultProtocol.calibrationSetVersion
        : calibrationValue,
    profileVisible: false,
    modelIdentityVisible: false,
    peerVotesVisible: false,
    traceOrderRandomized: true,
  );
}

EvalPairwiseReviewerKind _pairwiseReadinessReviewerKindValue({
  required String kindValue,
  required String modelValue,
}) {
  if (kindValue.isEmpty) {
    return modelValue.isEmpty
        ? EvalPairwiseReviewerKind.human
        : EvalPairwiseReviewerKind.llmJudge;
  }
  for (final kind in EvalPairwiseReviewerKind.values) {
    if (kind.name == kindValue) return kind;
  }
  throw StateError(
    'EVAL_PAIRWISE_REVIEWER_KIND must be one of '
    '${EvalPairwiseReviewerKind.values.map((kind) => kind.name).join(', ')}: '
    '$kindValue',
  );
}

int? _positiveOptionalInt({
  required String envName,
  required String value,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed < 1) {
    throw StateError('$envName must be a positive integer: $value');
  }
  return parsed;
}

Future<List<EvalPairwiseReviewPair>> _readPairwiseReviewPairs({
  required File file,
  required EvalRunArtifacts run,
  required TraceWriter writer,
}) async {
  if (!file.existsSync()) {
    throw StateError('Missing pairwise review pairs file: ${file.path}');
  }
  final decoded = jsonDecode(await file.readAsString());
  final entries = decoded is List
      ? decoded
      : decoded is Map<String, dynamic>
      ? decoded['pairs']
      : null;
  if (entries is! List) {
    throw StateError(
      'EVAL_PAIRWISE_PAIRS must be a JSON list or object with a pairs list.',
    );
  }
  return [
    for (final entry in entries)
      if (entry is Map<String, dynamic>)
        EvalPairwiseReviewPair(
          pairId: _requiredPairString(entry, 'pairId'),
          optionA: await _pairwiseTraceRefFromJson(
            json: _requiredPairObject(entry, 'optionA'),
            run: run,
            writer: writer,
          ),
          optionB: await _pairwiseTraceRefFromJson(
            json: _requiredPairObject(entry, 'optionB'),
            run: run,
            writer: writer,
          ),
        )
      else
        throw StateError('EVAL_PAIRWISE_PAIRS entries must be objects.'),
  ];
}

EvalPairwiseReadinessIntent? _readPairwiseReadinessIntentFromConfig({
  String pairwiseReadinessIntentPath = _pairwiseReadinessIntentPath,
}) {
  final path = pairwiseReadinessIntentPath.trim();
  if (path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Missing pairwise readiness intent: ${file.path}');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError(
      'Pairwise readiness intent JSON must be an object: ${file.path}',
    );
  }
  try {
    return EvalPairwiseReadinessIntent.fromJson(decoded);
  } on FormatException catch (error) {
    throw StateError(
      'Invalid pairwise readiness intent ${file.path}: ${error.message}',
    );
  }
}

Future<List<EvalPairwiseReviewPair>> _pairwiseReviewPairsFromIntent({
  required EvalPairwiseReadinessIntent? intent,
  required EvalRunArtifacts run,
  required TraceWriter writer,
}) async {
  if (intent == null) {
    throw StateError(
      'Set EVAL_PAIRWISE_PAIRS=<json> or '
      'EVAL_PAIRWISE_READINESS_INTENT=<json> for pairwise export.',
    );
  }
  return [
    for (final comparison in intent.comparisons)
      EvalPairwiseReviewPair(
        pairId: comparison.pairId,
        optionA: await _pairwiseTraceRefFromIntent(
          comparison: comparison,
          option: comparison.optionA,
          run: run,
          writer: writer,
        ),
        optionB: await _pairwiseTraceRefFromIntent(
          comparison: comparison,
          option: comparison.optionB,
          run: run,
          writer: writer,
        ),
      ),
  ];
}

Future<EvalPairwiseTraceRef> _pairwiseTraceRefFromIntent({
  required EvalPairwiseReadinessIntentComparison comparison,
  required EvalPairwiseReadinessIntentOption option,
  required EvalRunArtifacts run,
  required TraceWriter writer,
}) {
  return _pairwiseTraceRefFromJson(
    json: <String, dynamic>{
      'scenarioId': comparison.scenarioId,
      'profileName': option.profileName,
      'agentDirectiveVariantName': option.agentDirectiveVariantName,
      'trialIndex': comparison.trialIndex,
      if (comparison.cascadeWake != null)
        'cascadeWake': comparison.cascadeWake!.toJson(),
    },
    run: run,
    writer: writer,
  );
}

Future<EvalPairwiseTraceRef> _pairwiseTraceRefFromJson({
  required Map<String, dynamic> json,
  required EvalRunArtifacts run,
  required TraceWriter writer,
}) async {
  final scenarioId = _requiredPairString(json, 'scenarioId');
  final profileName = _requiredPairString(json, 'profileName');
  final variantName =
      (json['agentDirectiveVariantName'] as String?)?.trim().isNotEmpty == true
      ? json['agentDirectiveVariantName'] as String
      : 'default';
  final trialIndex = (json['trialIndex'] as num?)?.toInt() ?? 0;
  final cascadeWake = json['cascadeWake'] == null
      ? null
      : EvalTraceCascadeWake.fromJson(
          json['cascadeWake'] as Map<String, dynamic>,
        );
  final matches = [
    for (final trace in run.traces)
      if (trace.scenario.id == scenarioId &&
          trace.profile.name == profileName &&
          trace.agentDirectiveVariant.name == variantName &&
          trace.trialIndex == trialIndex &&
          _sameCascadeWake(trace.cascadeWake, cascadeWake))
        trace,
  ];
  if (matches.length != 1) {
    throw StateError(
      'Expected exactly one trace for pair ref '
      '$scenarioId/$profileName/$variantName/trial-$trialIndex, '
      'found ${matches.length}.',
    );
  }
  final trace = matches.single;
  final traceFile = writer.traceFileFor(
    runId: trace.runId,
    scenarioId: trace.scenario.id,
    profileName: trace.profile.name,
    agentDirectiveVariantName: trace.agentDirectiveVariant.name,
    trialIndex: trace.trialIndex,
    cascadeWake: trace.cascadeWake,
  );
  return EvalPairwiseTraceRef.fromTrace(
    trace,
    traceDigest: await writer.traceDigest(traceFile),
  );
}

bool _sameCascadeWake(
  EvalTraceCascadeWake? left,
  EvalTraceCascadeWake? right,
) {
  if (left == null || right == null) return left == null && right == null;
  return jsonEncode(left.toJson()) == jsonEncode(right.toJson());
}

String _requiredPairString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw StateError('Expected non-empty string "$key" in EVAL_PAIRWISE_PAIRS.');
}

Map<String, dynamic> _requiredPairObject(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw StateError('Expected object "$key" in EVAL_PAIRWISE_PAIRS.');
}

void _guardBlindedExportOutput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required Directory directory,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: File(directory.path),
    artifactDescription: 'blinded trace exports',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardPairwisePairsInput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required File file,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: file,
    artifactDescription: 'pairwise review pair files',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardPairwiseBlindedExportOutput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required Directory directory,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: File(directory.path),
    artifactDescription: 'blinded pairwise exports',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardPairwiseBlindedImportInput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required Directory directory,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: File(directory.path),
    artifactDescription: 'blinded pairwise imports',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardBlindedImportInput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required Directory directory,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: File(directory.path),
    artifactDescription: 'blinded verdict imports',
    protectedTraceAck: protectedTraceAck,
  );
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

void _guardTuningReportOutput({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence loadedEvidence,
  required File file,
  String? protectedTraceAck,
}) {
  _guardExternalCatalogRepoPath(
    manifestEvidence: manifestEvidence,
    loadedEvidence: loadedEvidence,
    file: file,
    artifactDescription: 'tuning reports',
    protectedTraceAck: protectedTraceAck,
  );
}

void _guardScenarioCatalogPreflightReportOutput({
  required EvalScenarioCatalogEvidence evidence,
  required File file,
  String? protectedTraceAck,
}) {
  if (!evidence.usesExternalCatalog && !evidence.protectedHoldout) return;
  final ack = protectedTraceAck ?? _protectedTraceAckValue();
  if (ack == '1') return;
  if (!_isInsideCurrentRepo(file)) return;
  throw StateError(
    'External eval catalog preflight reports bind private catalog digests and '
    'governance counts. Keep the file outside the repo or set '
    'LOTTI_EVAL_PROTECTED_TRACE_ACK=1 to acknowledge this.',
  );
}

Future<void> _writeFakeFvm(Directory fakeBin) async {
  const verifyPlainName =
      'verifies complete trace/verdict matrix for an eval run';
  final fvm = File(p.join(fakeBin.path, 'fvm'));
  await fvm.writeAsString(
    [
      '#!/usr/bin/env bash',
      'set -euo pipefail',
      '{',
      "  printf 'CALL'",
      r'  for arg in "$@"; do',
      r'''    printf '\t%s' "$arg"''',
      '  done',
      r"  printf '\n'",
      r'} >> "${FAKE_FVM_LOG}"',
      '',
      r'joined="$*"',
      r'if [[ "${FAKE_VERIFY_FAIL:-0}" == "1" ]]; then',
      '  if [[ "\$joined" == *"$verifyPlainName"* ]]; then',
      '    exit 42',
      '  fi',
      'fi',
      'exit 0',
      '',
    ].join('\n'),
  );
  final chmod = await Process.run('/bin/chmod', ['+x', fvm.path]);
  expect(chmod.exitCode, 0, reason: _processReason(chmod));
}

Future<List<List<String>>> _readFakeFvmCalls(File logFile) async {
  final contents = await logFile.readAsString();
  if (contents.trim().isEmpty) return const [];
  return contents
      .split('\n')
      .where((line) => line.isNotEmpty)
      .map((line) {
        final fields = line.split('\t');
        expect(fields.first, 'CALL', reason: line);
        return fields.skip(1).toList(growable: false);
      })
      .toList(growable: false);
}

String _plainNameFromFakeFvmCall(List<String> call) {
  final index = call.indexOf('--plain-name');
  expect(index, greaterThanOrEqualTo(0), reason: call.join('\n'));
  expect(index + 1, lessThan(call.length), reason: call.join('\n'));
  return call[index + 1];
}

void _expectFakeFvmCallContains(
  List<String> call,
  Iterable<String> expectedArgs,
) {
  for (final arg in expectedArgs) {
    expect(call, contains(arg), reason: call.join('\n'));
  }
}

String _processReason(ProcessResult result) {
  final stdout = result.stdout.toString();
  final stderr = result.stderr.toString();
  return [
    'exitCode=${result.exitCode}',
    if (stdout.isNotEmpty) 'stdout:\n$stdout',
    if (stderr.isNotEmpty) 'stderr:\n$stderr',
  ].join('\n');
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
