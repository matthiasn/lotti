// Matrix execution for Level 2 eval runs (ADR 0029).
//
// Runs the same scenario catalog across every configured profile and trial,
// writes one trace per cell, and records target exceptions as failed traces so
// reporting/verifier steps still see a complete matrix.

import 'dart:io';

import 'package:lotti/features/ai/model/inference_usage.dart';

import 'eval_assertions.dart';
import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_run_verifier.dart';
import 'eval_target.dart';
import 'trace_writer.dart';

class EvalMatrixRunResult {
  const EvalMatrixRunResult({
    required this.manifest,
    required this.manifestFile,
    required this.traces,
    required this.traceFiles,
  });

  final EvalRunManifest manifest;
  final File manifestFile;
  final List<EvalTrace> traces;
  final List<File> traceFiles;
}

class EvalMatrixRunner {
  const EvalMatrixRunner({
    required this.target,
    this.writer = const TraceWriter(),
  });

  final EvalTarget target;
  final TraceWriter writer;

  Future<EvalMatrixRunResult> run({
    required String runId,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    EvalPromotionPlan? promotionPlan,
    bool overwrite = false,
    bool deleteVerdictOnOverwrite = false,
  }) async {
    _validateInputs(scenarios, profiles);
    _preflightArtifacts(
      runId: runId,
      scenarios: scenarios,
      profiles: profiles,
      overwrite: overwrite,
      deleteVerdictOnOverwrite: deleteVerdictOnOverwrite,
    );

    final traces = <EvalTrace>[];
    final files = <File>[];
    final canonicalScenarios = _snapshotScenarios(scenarios);
    final canonicalProfiles = _snapshotProfiles(profiles);
    final profileExecutionBindings = profileExecutionBindingsForTarget(
      target,
      canonicalProfiles,
    );
    _validatePromotionPlanForRun(
      promotionPlan,
      scenarios: canonicalScenarios,
      profiles: canonicalProfiles,
    );
    final manifest = EvalProvenance.captureRunManifest(
      runId: runId,
      targetName: target.profileName,
      targetKind: target.targetKind,
      scenarios: canonicalScenarios,
      profiles: canonicalProfiles,
      scenarioCatalogEvidence: scenarioCatalogEvidence,
      promotionPlan: promotionPlan,
      profileExecutionBindings: profileExecutionBindings,
    );
    final manifestFile = await writer.writeManifest(
      manifest,
      overwrite: overwrite,
    );
    final manifestDigest = manifest.manifestDigest!;

    for (
      var scenarioIndex = 0;
      scenarioIndex < scenarios.length;
      scenarioIndex++
    ) {
      final scenario = scenarios[scenarioIndex];
      final canonicalScenario = canonicalScenarios[scenarioIndex];
      for (
        var profileIndex = 0;
        profileIndex < profiles.length;
        profileIndex++
      ) {
        final profile = profiles[profileIndex];
        final canonicalProfile = canonicalProfiles[profileIndex];
        for (
          var trialIndex = 0;
          trialIndex < profile.trialCount;
          trialIndex++
        ) {
          final context = EvalTargetRunContext(
            runId: runId,
            scenarioId: scenario.id,
            profileName: profile.name,
            trialIndex: trialIndex,
          );
          final output = await _runTarget(scenario, profile, context);
          final trace = EvalTrace(
            runId: runId,
            scenario: canonicalScenario,
            profile: canonicalProfile,
            provenance: EvalProvenance.capture(
              scenario: canonicalScenario,
              profile: canonicalProfile,
              manifestDigest: manifestDigest,
            ),
            trialIndex: trialIndex,
            output: output,
            level1Checks: runLevel1(
              canonicalScenario,
              output,
              profile: canonicalProfile,
            ),
          );
          files.add(
            await writer.writeTrace(
              trace,
              overwrite: overwrite,
              deleteVerdictOnOverwrite: deleteVerdictOnOverwrite,
            ),
          );
          traces.add(trace);
        }
      }
    }

    EvalRunVerifier.verify(
      runId: runId,
      traces: traces,
      scenarios: canonicalScenarios,
      profiles: canonicalProfiles,
      manifest: manifest,
      artifactNames: _artifactNames(runId),
      requireVerdicts: false,
    ).throwIfFailed();

    return EvalMatrixRunResult(
      manifest: manifest,
      manifestFile: manifestFile,
      traces: traces,
      traceFiles: files,
    );
  }

  void _validateInputs(
    List<EvalScenario> scenarios,
    List<EvalProfile> profiles,
  ) {
    if (scenarios.isEmpty) {
      throw ArgumentError.value(scenarios, 'scenarios', 'must not be empty');
    }
    if (profiles.isEmpty) {
      throw ArgumentError.value(profiles, 'profiles', 'must not be empty');
    }
    final scenarioIds = <String>{};
    for (final scenario in scenarios) {
      if (!scenarioIds.add(scenario.id)) {
        throw ArgumentError('duplicate scenario id: ${scenario.id}');
      }
      _validateScenarioMetadata(scenario);
    }
    final profileNames = <String>{};
    for (final profile in profiles) {
      if (!profileNames.add(profile.name)) {
        throw ArgumentError('duplicate profile name: ${profile.name}');
      }
      if (profile.trialCount < 1) {
        throw ArgumentError(
          'profile ${profile.name} trialCount must be at least 1',
        );
      }
      if (profile.tokenBudget < 1) {
        throw ArgumentError(
          'profile ${profile.name} tokenBudget must be at least 1',
        );
      }
      for (final entry in profile.tokenCostWeights.entries) {
        if (entry.value < 1) {
          throw ArgumentError(
            'profile ${profile.name} ${entry.key} must be at least 1',
          );
        }
      }
    }
  }

  void _validateScenarioMetadata(EvalScenario scenario) {
    if (scenario.metadata.capabilityIds.isEmpty) {
      throw ArgumentError(
        'scenario ${scenario.id} must declare at least one capability id',
      );
    }
    for (final capabilityId in scenario.metadata.capabilityIds) {
      if (!_capabilityIdPattern.hasMatch(capabilityId)) {
        throw ArgumentError(
          'scenario ${scenario.id} has invalid capability id: $capabilityId',
        );
      }
    }
  }

  void _preflightArtifacts({
    required String runId,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required bool overwrite,
    required bool deleteVerdictOnOverwrite,
  }) {
    final manifestFile = writer.manifestFileFor(runId);
    if (manifestFile.existsSync() && !overwrite) {
      throw StateError('Manifest already exists: ${manifestFile.path}');
    }
    final tracePaths = <String>{};
    for (final scenario in scenarios) {
      for (final profile in profiles) {
        for (
          var trialIndex = 0;
          trialIndex < profile.trialCount;
          trialIndex++
        ) {
          final traceFile = writer.traceFileFor(
            runId: runId,
            scenarioId: scenario.id,
            profileName: profile.name,
            trialIndex: trialIndex,
          );
          if (!tracePaths.add(traceFile.path)) {
            throw StateError(
              'Trace artifact name collision for ${traceFile.path}; '
              'scenario and profile ids must produce unique filenames.',
            );
          }
          if (traceFile.existsSync() && !overwrite) {
            throw StateError('Trace already exists: ${traceFile.path}');
          }
          final verdictFile = writer.verdictFileForTrace(traceFile);
          if (verdictFile.existsSync() &&
              (!overwrite || !deleteVerdictOnOverwrite)) {
            throw StateError(
              'Refusing to overwrite trace with existing verdict: '
              '${traceFile.path}',
            );
          }
        }
      }
    }
  }

  Future<AgentRunOutput> _runTarget(
    EvalScenario scenario,
    EvalProfile profile,
    EvalTargetRunContext context,
  ) async {
    try {
      return await target.run(scenario, profile, context: context);
    } catch (error, stackTrace) {
      return AgentRunOutput(
        success: false,
        error: _sanitizeTraceError('$error\n$stackTrace'),
        usage: InferenceUsage.empty,
      );
    }
  }

  String _sanitizeTraceError(String rawError) {
    var sanitized = rawError
        .replaceAllMapped(
          RegExp(
            r'(authorization\s*[:=]\s*bearer\s+)[^\s,;}]+',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}<redacted>',
        )
        .replaceAllMapped(
          RegExp(
            r'((?:api[_-]?key|token|secret|password)\s*[:=]\s*)'
            r'''["']?[^"',;\s}]+''',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}<redacted>',
        )
        .replaceAllMapped(
          RegExp(r'/(?:private|Users)/[^\s,;)\]}]+'),
          (_) => '<redacted-path>',
        );
    for (final label in [
      'prompt',
      'systemPrompt',
      'userPrompt',
      'messages',
      'content',
      'transcript',
    ]) {
      sanitized = sanitized.replaceAllMapped(
        RegExp(
          '($label\\s*[:=]\\s*)[^\\n\\r]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}<redacted-content>',
      );
    }
    const maxLength = 4000;
    if (sanitized.length <= maxLength) return sanitized;
    return '${sanitized.substring(0, maxLength)}\n<truncated>';
  }

  List<String> _artifactNames(String runId) {
    final dir = Directory(writer.runDir(runId));
    if (!dir.existsSync()) return const <String>[];
    final names = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is File) {
        names.add(entity.uri.pathSegments.last);
      }
    }
    names.sort();
    return names;
  }

  void _validatePromotionPlanForRun(
    EvalPromotionPlan? promotionPlan, {
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
  }) {
    if (promotionPlan == null) return;
    final scenarioSetDigest = EvalProvenance.scenarioSetDigest(scenarios);
    if (promotionPlan.scenarioSetDigest != scenarioSetDigest) {
      throw StateError(
        'Promotion plan scenarioSetDigest ${promotionPlan.scenarioSetDigest} '
        'does not match planned run $scenarioSetDigest',
      );
    }
    final profileSetDigest = EvalProvenance.profileSetDigest(profiles);
    if (promotionPlan.profileSetDigest != profileSetDigest) {
      throw StateError(
        'Promotion plan profileSetDigest ${promotionPlan.profileSetDigest} '
        'does not match planned run $profileSetDigest',
      );
    }
  }

  List<EvalScenario> _snapshotScenarios(List<EvalScenario> scenarios) {
    return [
      for (final scenario in scenarios)
        EvalScenario.fromJson(scenario.toJson()),
    ];
  }

  List<EvalProfile> _snapshotProfiles(List<EvalProfile> profiles) {
    return [
      for (final profile in profiles) EvalProfile.fromJson(profile.toJson()),
    ];
  }

  static final _capabilityIdPattern = RegExp(
    r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$',
  );
}
