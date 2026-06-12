// Level 2 live-run entrypoint.
//
// This file is intentionally a Flutter test so the real workflows can run under
// the same binding and mocks as the deterministic benches. It is tagged and
// self-skipping so default eval/CI runs never make network/model calls.

@Tags(['eval-live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/time_service.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart' show MockPersistenceLogic;
import '../../widget_test_utils.dart';
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
const _runsRootPath = String.fromEnvironment('EVAL_RUNS_ROOT');
const _protectedTraceAck = String.fromEnvironment(
  'LOTTI_EVAL_PROTECTED_TRACE_ACK',
);
const _promotionPlanPath = String.fromEnvironment('EVAL_PROMOTION_PLAN');

void main() {
  final settings = LiveEvalSettings.fromEnvironment(Platform.environment);

  setUpAll(() async {
    registerAllFallbackValues();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(TimeService());
      },
    );
  });

  tearDownAll(tearDownTestGetIt);

  test(
    'produces complete live trace matrix',
    () async {
      final profileCatalog = _loadProfileCatalog();
      final profiles = profileCatalog.profiles;
      settings.validateProfiles(profiles);
      final catalog = EvalScenarioCatalogLoader.fromEnvironment(
        Platform.environment,
        dartDefinePath: _scenarioCatalogPathFromDefine(),
        dartDefineMode: _scenarioCatalogModeFromDefine(),
        dartDefineScenarioIds: _scenarioIdsFromDefine(),
      );
      final runsRoot = _runsRoot();
      _guardProtectedTraceOutput(catalog, runsRoot);
      final target = LiveEvalTarget(settings: settings);
      addTearDown(target.dispose);
      final promotionPlan = _readPromotionPlanFromDefine();

      final result =
          await EvalMatrixRunner(
            target: target,
            writer: TraceWriter(runsRoot: runsRoot),
          ).run(
            runId: _runId,
            scenarios: catalog.scenarios,
            profiles: profiles,
            scenarioCatalogEvidence: catalog.evidence,
            promotionPlan: promotionPlan,
          );

      final expectedTraceCount =
          catalog.scenarios.length *
          profiles.fold<int>(
            0,
            (sum, profile) => sum + profile.trialCount,
          );
      expect(result.traces, hasLength(expectedTraceCount));
      expect(
        result.traces.map((trace) => trace.runId).toSet(),
        equals({_runId}),
      );
      expect(
        result.manifest.scenarioCatalogEvidence?.toJson(),
        catalog.evidence.toJson(),
      );
      if (promotionPlan != null) {
        expect(
          result.manifest.promotionPlanEvidence?.promotionPlanSubjectDigest,
          EvalProvenance.promotionPlanSubjectDigest(promotionPlan),
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 45)),
    skip: _liveRunnerSkip(settings),
  );
}

Object? _liveRunnerSkip(LiveEvalSettings settings) {
  if (!settings.enabled) {
    return 'Set LOTTI_EVAL_LIVE=1 plus provider credentials to run Level 2.';
  }
  if (_runId.isEmpty) {
    return 'Set --dart-define=EVAL_RUN=<runId> to write trace artifacts.';
  }
  return false;
}

String _scenarioCatalogPathFromDefine() => _scenarioCatalogPath;

EvalProfileCatalog _loadProfileCatalog() {
  return EvalProfileCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: _profileCatalogValueFromDefine(),
    dartDefineProfileNames: _profileNamesFromDefine(),
  );
}

String _profileCatalogValueFromDefine() => _profileCatalogValue;

String _profileNamesFromDefine() => _profileNames;

String _scenarioCatalogModeFromDefine() => _scenarioCatalogMode;

String _scenarioIdsFromDefine() => _scenarioIds;

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

void _guardProtectedTraceOutput(
  EvalScenarioCatalog catalog,
  String runsRoot,
) {
  if (!catalog.evidence.hasProtectedHoldoutEvidence) return;
  final ackFromDefine = _protectedTraceAck.trim();
  final ack = ackFromDefine.isNotEmpty
      ? ackFromDefine
      : Platform.environment['LOTTI_EVAL_PROTECTED_TRACE_ACK'];
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
