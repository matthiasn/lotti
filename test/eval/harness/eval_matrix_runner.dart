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

class EvalMatrixPlan {
  const EvalMatrixPlan({
    required this.manifest,
    required this.manifestFile,
    required this.scenarios,
    required this.profiles,
    required this.cells,
  });

  final EvalRunManifest manifest;
  final File manifestFile;
  final List<EvalScenario> scenarios;
  final List<EvalProfile> profiles;
  final List<EvalMatrixPlanCell> cells;

  int get traceCount => cells.length;

  Map<String, int> get trialCountByProfile {
    final counts = <String, int>{};
    for (final profile in profiles) {
      counts[profile.name] = profile.trialCount;
    }
    return Map.unmodifiable(counts);
  }
}

class EvalMatrixPlanCell {
  const EvalMatrixPlanCell({
    required this.scenarioIndex,
    required this.profileIndex,
    required this.trialIndex,
    required this.scenario,
    required this.profile,
    required this.traceFile,
    required this.verdictFile,
  });

  final int scenarioIndex;
  final int profileIndex;
  final int trialIndex;
  final EvalScenario scenario;
  final EvalProfile profile;
  final File traceFile;
  final File verdictFile;

  String get scenarioId => scenario.id;
  String get profileName => profile.name;
}

abstract final class EvalMatrixPlanRenderer {
  static String render(
    EvalMatrixPlan plan, {
    String? scenarioSourceLabel,
    String? profileSourceLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln('Eval matrix plan')
      ..writeln('runId: ${plan.manifest.runId}')
      ..writeln(
        'target: ${plan.manifest.targetKind}/${plan.manifest.targetName}',
      )
      ..writeln('outputDir: ${plan.manifestFile.parent.path}')
      ..writeln('previewManifestDigest: ${plan.manifest.manifestDigest}')
      ..writeln('scenarioSetDigest: ${plan.manifest.scenarioSetDigest}')
      ..writeln('profileSetDigest: ${plan.manifest.profileSetDigest}')
      ..writeln(
        'profileBindingSetDigest: ${plan.manifest.profileBindingSetDigest}',
      )
      ..writeln('promptDigest: ${plan.manifest.promptDigest}')
      ..writeln('toolSchemaDigest: ${plan.manifest.toolSchemaDigest}')
      ..writeln('codeRevision: ${plan.manifest.codeRevision}')
      ..writeln(
        'note: previewManifestDigest is not a run reservation; the live run '
        'writes the authoritative manifest when it executes.',
      )
      ..writeln()
      ..writeln('Sources')
      ..writeln(
        '- scenarios: ${scenarioSourceLabel ?? 'loaded scenario catalog'}',
      )
      ..writeln('- profiles: ${profileSourceLabel ?? 'loaded profile catalog'}')
      ..writeln()
      ..writeln('Counts')
      ..writeln('- scenarios: ${plan.scenarios.length}')
      ..writeln('- profiles: ${plan.profiles.length}')
      ..writeln('- trace cells: ${plan.traceCount}');

    final splitCounts = _countsBy(
      plan.scenarios.map((scenario) => scenario.metadata.split.name),
    );
    final agentCounts = _countsBy(
      plan.scenarios.map((scenario) => scenario.agentKind.name),
    );
    final capabilityCounts = _countsBy(
      plan.scenarios.map(
        (scenario) => scenario.metadata.primaryCapabilityId ?? '<missing>',
      ),
    );
    if (splitCounts.isNotEmpty) {
      buffer.writeln('- splits: ${_formatCounts(splitCounts)}');
    }
    if (agentCounts.isNotEmpty) {
      buffer.writeln('- agents: ${_formatCounts(agentCounts)}');
    }
    if (capabilityCounts.isNotEmpty) {
      buffer.writeln('- capabilities: ${_formatCounts(capabilityCounts)}');
    }
    final adversarialCount = plan.scenarios
        .where((scenario) => scenario.metadata.isAdversarial)
        .length;
    buffer
      ..writeln('- adversarial scenarios: $adversarialCount')
      ..writeln();

    final evidence = plan.manifest.scenarioCatalogEvidence;
    if (evidence != null) {
      buffer
        ..writeln('Scenario Catalog Evidence')
        ..writeln('- publicScenarioCount: ${evidence.publicScenarioCount}')
        ..writeln('- externalScenarioCount: ${evidence.externalScenarioCount}')
        ..writeln('- protectedHoldout: ${evidence.protectedHoldout}');
      if (evidence.externalCatalogId != null) {
        buffer.writeln('- externalCatalogId: ${evidence.externalCatalogId}');
      }
      if (evidence.externalCatalogDigest != null) {
        buffer.writeln(
          '- externalCatalogDigest: ${evidence.externalCatalogDigest}',
        );
      }
      if (evidence.protectedScenarioIds.isNotEmpty) {
        buffer.writeln(
          '- protectedScenarioIds: ${evidence.protectedScenarioIds.join(', ')}',
        );
      }
      if (evidence.protectedHoldoutScenarioIds.isNotEmpty) {
        buffer.writeln(
          '- protectedHoldoutScenarioIds: '
          '${evidence.protectedHoldoutScenarioIds.join(', ')}',
        );
      }
      buffer.writeln();
    }

    final promotionEvidence = plan.manifest.promotionPlanEvidence;
    if (promotionEvidence != null) {
      buffer
        ..writeln('Promotion Plan Evidence')
        ..writeln('- planId: ${promotionEvidence.planId}')
        ..writeln(
          '- comparison: ${promotionEvidence.candidateProfileName} vs '
          '${promotionEvidence.baselineProfileName}',
        )
        ..writeln('- policyDigest: ${promotionEvidence.policyDigest}')
        ..writeln(
          '- subjectDigest: '
          '${promotionEvidence.promotionPlanSubjectDigest}',
        )
        ..writeln();
    }

    buffer.writeln('Profiles');
    final bindingByProfileName = {
      for (final binding in plan.manifest.profileExecutionBindings)
        binding.profileName: binding,
    };
    for (final profile in plan.profiles) {
      final binding = bindingByProfileName[profile.name];
      buffer
        ..writeln(
          '- ${profile.name}: class=${profile.modelClass.name} '
          'local=${profile.isLocal} trials=${profile.trialCount} '
          'budget=${profile.tokenBudget}',
        )
        ..writeln(
          '  profileModelId=${profile.modelId} '
          'maxCompletionTokens=${profile.maxCompletionTokens ?? '<default>'}',
        );
      if (profile.usesWeightedTokenCosts) {
        buffer.writeln(
          '  tokenCostWeights=${profile.tokenCostWeights}',
        );
      }
      if (binding != null) {
        buffer.writeln(
          '  binding provider=${binding.providerType} '
          'providerModelId=${binding.providerModelId} '
          'endpointOrigin=${binding.providerEndpointOrigin} '
          'baseUrlDigest=${binding.providerBaseUrlDigest} '
          'requestTemperature=${binding.providerRequestTemperature}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('Scenarios');
    for (final scenario in plan.scenarios) {
      final metadata = scenario.metadata;
      buffer.writeln(
        '- ${scenario.id}: ${scenario.title} '
        'agent=${scenario.agentKind.name} split=${metadata.split.name} '
        'source=${metadata.source.name} '
        'capabilities=${metadata.capabilityIds.join(', ')} '
        'adversarial=${metadata.isAdversarial} '
        'tags=${(metadata.tags.toList()..sort()).join(', ')}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Cells');
    for (final cell in plan.cells) {
      buffer
        ..writeln(
          '- ${cell.scenarioId} x ${cell.profileName} '
          'trial=${cell.trialIndex}',
        )
        ..writeln('  trace=${cell.traceFile.path}')
        ..writeln('  verdict=${cell.verdictFile.path}');
    }
    return buffer.toString();
  }

  static Map<String, int> _countsBy(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      counts.update(value, (count) => count + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(counts);
  }

  static String _formatCounts(Map<String, int> counts) {
    final keys = counts.keys.toList()..sort();
    return [
      for (final key in keys) '$key=${counts[key]}',
    ].join(', ');
  }
}

class EvalMatrixRunner {
  const EvalMatrixRunner({
    required this.target,
    this.writer = const TraceWriter(),
  });

  final EvalTarget target;
  final TraceWriter writer;

  EvalMatrixPlan plan({
    required String runId,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    EvalPromotionPlan? promotionPlan,
    bool overwrite = false,
    bool deleteVerdictOnOverwrite = false,
  }) {
    _validateInputs(scenarios, profiles);
    _preflightArtifacts(
      runId: runId,
      scenarios: scenarios,
      profiles: profiles,
      overwrite: overwrite,
      deleteVerdictOnOverwrite: deleteVerdictOnOverwrite,
    );

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
    final cells = <EvalMatrixPlanCell>[];
    for (
      var scenarioIndex = 0;
      scenarioIndex < canonicalScenarios.length;
      scenarioIndex++
    ) {
      final scenario = canonicalScenarios[scenarioIndex];
      for (
        var profileIndex = 0;
        profileIndex < canonicalProfiles.length;
        profileIndex++
      ) {
        final profile = canonicalProfiles[profileIndex];
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
          cells.add(
            EvalMatrixPlanCell(
              scenarioIndex: scenarioIndex,
              profileIndex: profileIndex,
              trialIndex: trialIndex,
              scenario: scenario,
              profile: profile,
              traceFile: traceFile,
              verdictFile: writer.verdictFileForTrace(traceFile),
            ),
          );
        }
      }
    }

    return EvalMatrixPlan(
      manifest: manifest,
      manifestFile: writer.manifestFileFor(runId),
      scenarios: List.unmodifiable(canonicalScenarios),
      profiles: List.unmodifiable(canonicalProfiles),
      cells: List.unmodifiable(cells),
    );
  }

  Future<EvalMatrixRunResult> run({
    required String runId,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    EvalPromotionPlan? promotionPlan,
    bool overwrite = false,
    bool deleteVerdictOnOverwrite = false,
  }) async {
    final planned = plan(
      runId: runId,
      scenarios: scenarios,
      profiles: profiles,
      scenarioCatalogEvidence: scenarioCatalogEvidence,
      promotionPlan: promotionPlan,
      overwrite: overwrite,
      deleteVerdictOnOverwrite: deleteVerdictOnOverwrite,
    );

    final traces = <EvalTrace>[];
    final files = <File>[];
    final manifestFile = await writer.writeManifest(
      planned.manifest,
      overwrite: overwrite,
    );
    final manifestDigest = planned.manifest.manifestDigest!;

    for (final cell in planned.cells) {
      final scenario = scenarios[cell.scenarioIndex];
      final profile = profiles[cell.profileIndex];
      final context = EvalTargetRunContext(
        runId: runId,
        scenarioId: scenario.id,
        profileName: profile.name,
        trialIndex: cell.trialIndex,
      );
      final output = await _runTarget(scenario, profile, context);
      final trace = EvalTrace(
        runId: runId,
        scenario: cell.scenario,
        profile: cell.profile,
        provenance: EvalProvenance.capture(
          scenario: cell.scenario,
          profile: cell.profile,
          manifestDigest: manifestDigest,
        ),
        trialIndex: cell.trialIndex,
        output: output,
        level1Checks: runLevel1(
          cell.scenario,
          output,
          profile: cell.profile,
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

    EvalRunVerifier.verify(
      runId: runId,
      traces: traces,
      scenarios: planned.scenarios,
      profiles: planned.profiles,
      manifest: planned.manifest,
      artifactNames: _artifactNames(runId),
      requireVerdicts: false,
    ).throwIfFailed();

    return EvalMatrixRunResult(
      manifest: planned.manifest,
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
