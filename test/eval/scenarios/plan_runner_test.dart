// Level 2 dry-run entrypoint.
//
// This previews the exact scenario x profile x prompt variant x trial matrix,
// provider/model bindings, and artifact paths without creating a run directory
// or making live model calls.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../harness/eval_harness.dart';
import '../harness/live_eval_target.dart';
import 'eval_scenario_catalog.dart';

const _runId = String.fromEnvironment('EVAL_RUN');
const _scenarioCatalogPath = String.fromEnvironment(
  kEvalScenarioCatalogPathEnv,
);
const _scenarioCatalogMode = String.fromEnvironment(
  kEvalScenarioCatalogModeEnv,
);
const _scenarioIds = String.fromEnvironment(kEvalScenarioIdsEnv);
const _profileCatalogValue = String.fromEnvironment(kEvalProfilesPathEnv);
const _profileNames = String.fromEnvironment(kEvalProfileNamesEnv);
const _promptVariantCatalogValue = String.fromEnvironment(
  kEvalPromptVariantsPathEnv,
);
const _promptVariantNames = String.fromEnvironment(kEvalPromptVariantNamesEnv);
const _runsRootPath = String.fromEnvironment('EVAL_RUNS_ROOT');
const _protectedTraceAck = String.fromEnvironment(
  'LOTTI_EVAL_PROTECTED_TRACE_ACK',
);
const _promotionPlanPath = String.fromEnvironment('EVAL_PROMOTION_PLAN');
const _pairwiseReadinessIntentPath = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_INTENT',
);
const _pairwiseReadinessPlanPath = String.fromEnvironment(
  'EVAL_PAIRWISE_READINESS_PLAN',
);
const _requiredCapabilities = String.fromEnvironment(
  'EVAL_REQUIRED_CAPABILITIES',
);
const _useCaseRunWorkOrderPath = String.fromEnvironment(
  'EVAL_USE_CASE_RUN_WORK_ORDER',
);
const _useCaseRunWorkOrderBatchRefs = String.fromEnvironment(
  'EVAL_USE_CASE_RUN_WORK_ORDER_BATCH_REFS',
);

void main() {
  final settings = LiveEvalSettings.fromEnvironment(Platform.environment);

  test(
    'renders eval matrix plan',
    () {
      final profileCatalog = _loadProfileCatalog();
      final promptVariantCatalog = _loadPromptVariantCatalog();
      final catalog = _loadScenarioCatalog();
      final runsRoot = _runsRoot();
      _guardProtectedTraceOutput(catalog, runsRoot);
      final target = LiveEvalTarget(settings: settings);
      addTearDown(target.dispose);
      final promotionPlan = _readPromotionPlanFromDefine();
      final pairwiseReadinessIntent = _readPairwiseReadinessIntentFromDefine();
      final pairwiseReadinessPlan = _readPairwiseReadinessPlanFromDefine();
      final requiredPrimaryCapabilityIds =
          _requiredPrimaryCapabilityIdsFromDefine();
      final workOrderLaunchEvidence = _readWorkOrderLaunchEvidenceFromDefine(
        requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
        promptVariants: promptVariantCatalog.variants,
      );

      final plan =
          EvalMatrixRunner(
            target: target,
            writer: TraceWriter(runsRoot: runsRoot),
          ).plan(
            runId: _runId,
            scenarios: catalog.scenarios,
            profiles: profileCatalog.profiles,
            agentDirectiveVariants: promptVariantCatalog.variants,
            scenarioCatalogEvidence: catalog.evidence,
            promotionPlan: promotionPlan,
            pairwiseReadinessIntent: pairwiseReadinessIntent,
            pairwiseReadinessPlan: pairwiseReadinessPlan,
            requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
            useCaseWorkOrderLaunchEvidence: workOrderLaunchEvidence,
          );

      // ignore: avoid_print
      print(
        EvalMatrixPlanRenderer.render(
          plan,
          scenarioSourceLabel: catalog.sourceDescription,
          profileSourceLabel: profileCatalog.sourceLabel,
          promptVariantSourceLabel: promptVariantCatalog.sourceLabel,
        ),
      );

      expect(plan.cells, isNotEmpty);
      expect(plan.manifestFile.existsSync(), isFalse);
      expect(
        plan.cells.every((cell) => !cell.traceFile.existsSync()),
        isTrue,
      );
    },
    tags: 'eval-report',
    skip: _runId.isEmpty
        ? 'Set EVAL_RUN=<runId> to preview an eval matrix.'
        : false,
  );

  test('protected plan output inside repo requires ack', () {
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
    final catalog = EvalScenarioCatalog(
      scenarios: const [],
      evidence: evidence,
      sourceDescription: 'private_scenarios.json',
    );

    expect(
      () => _guardProtectedTraceOutput(
        catalog,
        'eval/runs',
        protectedTraceAck: '0',
      ),
      throwsStateError,
    );
    expect(
      () => _guardProtectedTraceOutput(
        catalog,
        'eval/runs',
        protectedTraceAck: '1',
      ),
      returnsNormally,
    );
  });

  test('use-case run work-order read errors omit private paths', () {
    final tempDir = Directory.systemTemp.createTempSync(
      'lotti-plan-work-order-',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final nonObjectFile = File('${tempDir.path}/work-order.json')
      ..writeAsStringSync('[]');
    final missingFile = File('${tempDir.path}/missing-work-order.json');

    expect(
      () => _readWorkOrderLaunchEvidenceFromFile(
        missingFile,
        requiredPrimaryCapabilityIds: const {'task.workflow'},
        promptVariants: const [EvalAgentDirectiveVariant()],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf([
            contains('Missing use-case run work order'),
            isNot(contains(missingFile.path)),
          ]),
        ),
      ),
    );
    expect(
      () => _readWorkOrderLaunchEvidenceFromFile(
        nonObjectFile,
        requiredPrimaryCapabilityIds: const {'task.workflow'},
        promptVariants: const [EvalAgentDirectiveVariant()],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf([
            contains('Use-case run work order JSON must be an object'),
            isNot(contains(nonObjectFile.path)),
          ]),
        ),
      ),
    );
  });
}

EvalScenarioCatalog _loadScenarioCatalog() {
  return EvalScenarioCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefinePath: _scenarioCatalogPathFromDefine(),
    dartDefineMode: _scenarioCatalogModeFromDefine(),
    dartDefineScenarioIds: _scenarioIdsFromDefine(),
  );
}

EvalProfileCatalog _loadProfileCatalog() {
  return EvalProfileCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: _profileCatalogValueFromDefine(),
    dartDefineProfileNames: _profileNamesFromDefine(),
  );
}

EvalAgentDirectiveVariantCatalog _loadPromptVariantCatalog() {
  return EvalAgentDirectiveVariantCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: _promptVariantCatalogValueFromDefine(),
    dartDefineVariantNames: _promptVariantNamesFromDefine(),
  );
}

String _scenarioCatalogPathFromDefine() => _scenarioCatalogPath;

String _scenarioCatalogModeFromDefine() => _scenarioCatalogMode;

String _scenarioIdsFromDefine() => _scenarioIds;

String _profileCatalogValueFromDefine() => _profileCatalogValue;

String _profileNamesFromDefine() => _profileNames;

String _promptVariantCatalogValueFromDefine() => _promptVariantCatalogValue;

String _promptVariantNamesFromDefine() => _promptVariantNames;

String _runsRoot() {
  final fromDefine = _runsRootPath.trim();
  if (fromDefine.isNotEmpty) return fromDefine;
  final fromEnvironment = Platform.environment['EVAL_RUNS_ROOT']?.trim();
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  return 'eval/runs';
}

EvalPromotionPlan? _readPromotionPlanFromDefine() {
  final path = _promotionPlanPath.trim();
  if (path.isEmpty) return null;
  final file = File(path);
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

EvalPairwiseReadinessIntent? _readPairwiseReadinessIntentFromDefine() {
  final path = _pairwiseReadinessIntentPath.trim();
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

EvalPairwiseReadinessPlan? _readPairwiseReadinessPlanFromDefine() {
  final path = _pairwiseReadinessPlanPath.trim();
  if (path.isEmpty) return null;
  final file = File(path);
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

EvalUseCaseWorkOrderLaunchEvidence? _readWorkOrderLaunchEvidenceFromDefine({
  required Set<String> requiredPrimaryCapabilityIds,
  required List<EvalAgentDirectiveVariant> promptVariants,
}) {
  final path = _useCaseRunWorkOrderPath.trim();
  if (path.isEmpty) return null;
  return _readWorkOrderLaunchEvidenceFromFile(
    File(path),
    requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
    promptVariants: promptVariants,
  );
}

EvalUseCaseWorkOrderLaunchEvidence _readWorkOrderLaunchEvidenceFromFile(
  File file, {
  required Set<String> requiredPrimaryCapabilityIds,
  required List<EvalAgentDirectiveVariant> promptVariants,
}) {
  if (!file.existsSync()) {
    throw StateError('Missing use-case run work order.');
  }
  final decoded = _readJsonWithoutPath(file);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Use-case run work order JSON must be an object.');
  }
  return EvalUseCaseNextRunWorkOrder.launchEvidenceForRun(
    workOrder: decoded,
    requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
    promptVariantNames: [for (final variant in promptVariants) variant.name],
    workOrderBatchRefs: _csv(_useCaseRunWorkOrderBatchRefs),
  );
}

Object? _readJsonWithoutPath(File file) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FileSystemException catch (error) {
    throw StateError(
      'Unable to read use-case run work order: ${error.message}.',
    );
  } on FormatException catch (error) {
    throw StateError('Invalid use-case run work order JSON: ${error.message}');
  }
}

Set<String> _requiredPrimaryCapabilityIdsFromDefine({
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

List<String> _csv(String value) => [
  for (final part in value.split(',').map((part) => part.trim()))
    if (part.isNotEmpty) part,
];

void _guardProtectedTraceOutput(
  EvalScenarioCatalog catalog,
  String runsRoot, {
  String? protectedTraceAck,
}) {
  if (!catalog.evidence.hasProtectedHoldoutEvidence) return;
  final ackFromDefine = _protectedTraceAck.trim();
  final ack =
      protectedTraceAck ??
      (ackFromDefine.isNotEmpty
          ? ackFromDefine
          : Platform.environment['LOTTI_EVAL_PROTECTED_TRACE_ACK']);
  if (ack == '1') return;
  final repoPath = Directory.current.absolute.path;
  final rootDirectory = Directory(runsRoot);
  final rootPath = rootDirectory.isAbsolute
      ? rootDirectory.absolute.path
      : Directory('$repoPath/$runsRoot').absolute.path;
  final insideRepo = rootPath == repoPath || rootPath.startsWith('$repoPath/');
  if (!insideRepo) return;
  throw StateError(
    'Protected eval scenarios write raw scenario content into trace files. '
    'Set EVAL_RUNS_ROOT to an absolute path outside the repo or set '
    'LOTTI_EVAL_PROTECTED_TRACE_ACK=1 to acknowledge this.',
  );
}
