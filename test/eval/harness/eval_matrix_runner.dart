// Matrix execution for Level 2 eval runs (ADR 0029).
//
// Runs the same scenario catalog across every configured profile, prompt
// variant, and trial, writes one trace per cell, and records target exceptions
// as failed traces so reporting/verifier steps still see a complete matrix.

import 'dart:io';

import 'package:lotti/features/ai/model/inference_usage.dart';

import 'eval_assertions.dart';
import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_run_verifier.dart';
import 'eval_target.dart';
import 'eval_tuning_readiness.dart';
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
    required this.agentDirectiveVariants,
    required this.cells,
  });

  final EvalRunManifest manifest;
  final File manifestFile;
  final List<EvalScenario> scenarios;
  final List<EvalProfile> profiles;
  final List<EvalAgentDirectiveVariant> agentDirectiveVariants;
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
    required this.agentDirectiveVariantIndex,
    required this.trialIndex,
    required this.scenario,
    required this.profile,
    required this.agentDirectiveVariant,
    required this.traceFile,
    required this.verdictFile,
  });

  final int scenarioIndex;
  final int profileIndex;
  final int agentDirectiveVariantIndex;
  final int trialIndex;
  final EvalScenario scenario;
  final EvalProfile profile;
  final EvalAgentDirectiveVariant agentDirectiveVariant;
  final File traceFile;
  final File verdictFile;

  String get scenarioId => scenario.id;
  String get profileName => profile.name;
  String get agentDirectiveVariantName => agentDirectiveVariant.name;
}

abstract final class EvalMatrixPlanRenderer {
  static String render(
    EvalMatrixPlan plan, {
    String? scenarioSourceLabel,
    String? profileSourceLabel,
    String? promptVariantSourceLabel,
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
      ..writeln(
        'agentDirectiveVariantSetDigest: '
        '${plan.manifest.agentDirectiveVariantSetDigest}',
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
      ..writeln(
        '- prompt variants: '
        '${promptVariantSourceLabel ?? 'loaded prompt variant catalog'}',
      )
      ..writeln()
      ..writeln('Counts')
      ..writeln('- scenarios: ${plan.scenarios.length}')
      ..writeln('- profiles: ${plan.profiles.length}')
      ..writeln('- prompt variants: ${plan.agentDirectiveVariants.length}')
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

    final pairwiseEvidence = plan.manifest.pairwiseReadinessPlanEvidence;
    if (pairwiseEvidence != null) {
      buffer
        ..writeln('Pairwise Readiness Plan Evidence')
        ..writeln('- planId: ${pairwiseEvidence.planId}')
        ..writeln('- basePolicy: ${pairwiseEvidence.baseReadinessPolicy}')
        ..writeln(
          '- profileBindingSetDigest: '
          '${pairwiseEvidence.profileBindingSetDigest}',
        )
        ..writeln(
          '- minDecisions: '
          '${pairwiseEvidence.minBlindedPairwisePreferenceDecisions}',
        )
        ..writeln('- comparisonCount: ${pairwiseEvidence.comparisonCount}')
        ..writeln(
          '- subjectDigest: '
          '${pairwiseEvidence.pairwiseReadinessPlanSubjectDigest}',
        )
        ..writeln();
    }

    final readinessContract = plan.manifest.tuningReadinessContractEvidence;
    if (readinessContract != null) {
      buffer
        ..writeln('Tuning Readiness Contract Evidence')
        ..writeln(
          '- requiredPrimaryCapabilityIds: '
          '${readinessContract.requiredPrimaryCapabilityIds.toList()..sort()}',
        )
        ..writeln(
          '- subjectDigest: '
          '${readinessContract.readinessContractSubjectDigest}',
        )
        ..writeln();
    }

    final readinessPolicy = plan.manifest.tuningReadinessPolicyEvidence;
    if (readinessPolicy != null) {
      buffer
        ..writeln('Tuning Readiness Policy Evidence')
        ..writeln('- policyName: ${readinessPolicy.policyName}')
        ..writeln('- policyDigest: ${readinessPolicy.policyDigest}')
        ..writeln();
    }

    final workOrderLaunch = plan.manifest.useCaseWorkOrderLaunchEvidence;
    if (workOrderLaunch != null) {
      buffer
        ..writeln('Use-Case Work-Order Launch Evidence')
        ..writeln('- workOrderRef: ${workOrderLaunch.workOrderRef}')
        ..writeln('- workOrderDigest: ${workOrderLaunch.workOrderDigest}')
        ..writeln(
          '- workOrderBatchRefs: '
          '${workOrderLaunch.workOrderBatchRefs.length}',
        )
        ..writeln(
          '- subjectDigest: '
          '${workOrderLaunch.workOrderLaunchSubjectDigest}',
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
      ..writeln('Prompt Variants');
    for (final variant in plan.agentDirectiveVariants) {
      buffer
        ..writeln('- ${variant.name}')
        ..writeln(
          '  digest=${EvalProvenance.agentDirectiveVariantDigest(variant)}',
        );
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
          '- ${cell.scenarioId} x ${cell.profileName} x '
          '${cell.agentDirectiveVariantName} '
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
    List<EvalAgentDirectiveVariant> agentDirectiveVariants = const [
      EvalAgentDirectiveVariant(),
    ],
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    EvalPromotionPlan? promotionPlan,
    EvalPairwiseReadinessIntent? pairwiseReadinessIntent,
    EvalPairwiseReadinessPlan? pairwiseReadinessPlan,
    EvalPairwiseReadinessPlanEvidence? pairwiseReadinessPlanEvidence,
    Set<String> requiredPrimaryCapabilityIds = const <String>{},
    EvalUseCaseWorkOrderLaunchEvidence? useCaseWorkOrderLaunchEvidence,
    bool overwrite = false,
    bool deleteVerdictOnOverwrite = false,
  }) {
    _validateInputs(scenarios, profiles, agentDirectiveVariants);
    _preflightArtifacts(
      runId: runId,
      scenarios: scenarios,
      profiles: profiles,
      agentDirectiveVariants: agentDirectiveVariants,
      overwrite: overwrite,
      deleteVerdictOnOverwrite: deleteVerdictOnOverwrite,
    );

    final canonicalScenarios = _snapshotScenarios(scenarios);
    final canonicalProfiles = _snapshotProfiles(profiles);
    final canonicalAgentDirectiveVariants = _snapshotAgentDirectiveVariants(
      agentDirectiveVariants,
    );
    final profileExecutionBindings = profileExecutionBindingsForTarget(
      target,
      canonicalProfiles,
    );
    _validatePromotionPlanForRun(
      promotionPlan,
      scenarios: canonicalScenarios,
      profiles: canonicalProfiles,
    );
    final resolvedPairwiseEvidence = _resolvePairwiseReadinessPlanEvidence(
      pairwiseReadinessIntent: pairwiseReadinessIntent,
      pairwiseReadinessPlan: pairwiseReadinessPlan,
      pairwiseReadinessPlanEvidence: pairwiseReadinessPlanEvidence,
    );
    _validatePairwiseReadinessPlanEvidenceForRun(
      resolvedPairwiseEvidence,
      scenarios: canonicalScenarios,
      profiles: canonicalProfiles,
      agentDirectiveVariants: canonicalAgentDirectiveVariants,
      pairwiseReadinessIntent: pairwiseReadinessIntent,
    );
    _validateRequiredPrimaryCapabilities(
      requiredPrimaryCapabilityIds,
      scenarios: canonicalScenarios,
    );
    final tuningReadinessContractEvidence = requiredPrimaryCapabilityIds.isEmpty
        ? null
        : EvalProvenance.tuningReadinessContractEvidence(
            scenarioSetDigest: EvalProvenance.scenarioSetDigest(
              canonicalScenarios,
            ),
            requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
          );
    final tuningReadinessPolicyEvidence = _tuningReadinessPolicyEvidence(
      requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
      pairwiseReadinessIntent: pairwiseReadinessIntent,
      pairwiseReadinessPlan: pairwiseReadinessPlan,
    );
    final manifest = EvalProvenance.captureRunManifest(
      runId: runId,
      targetName: target.profileName,
      targetKind: target.targetKind,
      scenarios: canonicalScenarios,
      profiles: canonicalProfiles,
      scenarioCatalogEvidence: scenarioCatalogEvidence,
      promotionPlan: promotionPlan,
      pairwiseReadinessPlanEvidence: resolvedPairwiseEvidence,
      tuningReadinessContractEvidence: tuningReadinessContractEvidence,
      tuningReadinessPolicyEvidence: tuningReadinessPolicyEvidence,
      useCaseWorkOrderLaunchEvidence: useCaseWorkOrderLaunchEvidence,
      profileExecutionBindings: profileExecutionBindings,
      agentDirectiveVariants: canonicalAgentDirectiveVariants,
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
          var variantIndex = 0;
          variantIndex < canonicalAgentDirectiveVariants.length;
          variantIndex++
        ) {
          final variant = canonicalAgentDirectiveVariants[variantIndex];
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          ) {
            final traceFile = writer.traceFileFor(
              runId: runId,
              scenarioId: scenario.id,
              profileName: profile.name,
              agentDirectiveVariantName: variant.name,
              trialIndex: trialIndex,
            );
            cells.add(
              EvalMatrixPlanCell(
                scenarioIndex: scenarioIndex,
                profileIndex: profileIndex,
                agentDirectiveVariantIndex: variantIndex,
                trialIndex: trialIndex,
                scenario: scenario,
                profile: profile,
                agentDirectiveVariant: variant,
                traceFile: traceFile,
                verdictFile: writer.verdictFileForTrace(traceFile),
              ),
            );
          }
        }
      }
    }

    return EvalMatrixPlan(
      manifest: manifest,
      manifestFile: writer.manifestFileFor(runId),
      scenarios: List.unmodifiable(canonicalScenarios),
      profiles: List.unmodifiable(canonicalProfiles),
      agentDirectiveVariants: List.unmodifiable(
        canonicalAgentDirectiveVariants,
      ),
      cells: List.unmodifiable(cells),
    );
  }

  Future<EvalMatrixRunResult> run({
    required String runId,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    List<EvalAgentDirectiveVariant> agentDirectiveVariants = const [
      EvalAgentDirectiveVariant(),
    ],
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    EvalPromotionPlan? promotionPlan,
    EvalPairwiseReadinessIntent? pairwiseReadinessIntent,
    EvalPairwiseReadinessPlan? pairwiseReadinessPlan,
    EvalPairwiseReadinessPlanEvidence? pairwiseReadinessPlanEvidence,
    Set<String> requiredPrimaryCapabilityIds = const <String>{},
    EvalUseCaseWorkOrderLaunchEvidence? useCaseWorkOrderLaunchEvidence,
    bool overwrite = false,
    bool deleteVerdictOnOverwrite = false,
  }) async {
    final planned = plan(
      runId: runId,
      scenarios: scenarios,
      profiles: profiles,
      agentDirectiveVariants: agentDirectiveVariants,
      scenarioCatalogEvidence: scenarioCatalogEvidence,
      promotionPlan: promotionPlan,
      pairwiseReadinessIntent: pairwiseReadinessIntent,
      pairwiseReadinessPlan: pairwiseReadinessPlan,
      pairwiseReadinessPlanEvidence: pairwiseReadinessPlanEvidence,
      requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
      useCaseWorkOrderLaunchEvidence: useCaseWorkOrderLaunchEvidence,
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
        agentDirectiveVariant: cell.agentDirectiveVariant,
        trialIndex: cell.trialIndex,
      );
      final output = await _runTarget(scenario, profile, context);
      final trace = EvalTrace(
        runId: runId,
        scenario: cell.scenario,
        profile: cell.profile,
        agentDirectiveVariant: cell.agentDirectiveVariant,
        provenance: EvalProvenance.capture(
          scenario: cell.scenario,
          profile: cell.profile,
          agentDirectiveVariant: cell.agentDirectiveVariant,
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

    final verification = EvalRunVerifier.verify(
      runId: runId,
      traces: traces,
      scenarios: planned.scenarios,
      profiles: planned.profiles,
      agentDirectiveVariants: planned.agentDirectiveVariants,
      manifest: planned.manifest,
      artifactNames: _artifactNames(runId),
      requireVerdicts: false,
    );
    final errors = [
      ..._failedLevel1CheckErrors(traces),
      ...verification.errors,
    ];
    if (errors.isNotEmpty) {
      throw StateError(errors.join('\n'));
    }

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
    List<EvalAgentDirectiveVariant> agentDirectiveVariants,
  ) {
    if (scenarios.isEmpty) {
      throw ArgumentError.value(scenarios, 'scenarios', 'must not be empty');
    }
    if (profiles.isEmpty) {
      throw ArgumentError.value(profiles, 'profiles', 'must not be empty');
    }
    if (agentDirectiveVariants.isEmpty) {
      throw ArgumentError.value(
        agentDirectiveVariants,
        'agentDirectiveVariants',
        'must not be empty',
      );
    }
    final scenarioIds = <String>{};
    for (final scenario in scenarios) {
      if (!scenarioIds.add(scenario.id)) {
        throw ArgumentError('duplicate scenario id: ${scenario.id}');
      }
      _validateScenarioMetadata(scenario);
    }
    final variantNames = <String>{};
    for (final variant in agentDirectiveVariants) {
      if (variant.name.trim().isEmpty) {
        throw ArgumentError('agent directive variant name must not be empty');
      }
      if (!variantNames.add(variant.name)) {
        throw ArgumentError(
          'duplicate agent directive variant name: ${variant.name}',
        );
      }
      if (variant.name != 'default' &&
          variant.generalDirective.trim().isEmpty &&
          variant.reportDirective.trim().isEmpty) {
        throw ArgumentError(
          'agent directive variant ${variant.name} has no directives',
        );
      }
      for (final scenario in scenarios) {
        final text = variant.combinedDirectiveText;
        if (text.isNotEmpty && text.contains(scenario.id)) {
          throw ArgumentError(
            'agent directive variant ${variant.name} mentions scenario id '
            '${scenario.id}; variants must stay scenario-agnostic',
          );
        }
      }
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
    required List<EvalAgentDirectiveVariant> agentDirectiveVariants,
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
        for (final variant in agentDirectiveVariants) {
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          ) {
            final traceFile = writer.traceFileFor(
              runId: runId,
              scenarioId: scenario.id,
              profileName: profile.name,
              agentDirectiveVariantName: variant.name,
              trialIndex: trialIndex,
            );
            if (!tracePaths.add(traceFile.path)) {
              throw StateError(
                'Trace artifact name collision for ${traceFile.path}; '
                'scenario, profile, prompt variant, and trial ids must '
                'produce unique filenames.',
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

  List<String> _failedLevel1CheckErrors(List<EvalTrace> traces) {
    final errors = <String>[];
    for (final trace in traces) {
      final wake = trace.cascadeWake;
      final label = [
        trace.scenario.id,
        trace.profile.name,
        'trial-${trace.trialIndex}',
        if (wake != null) 'wake-${wake.wakeIndex}',
      ].join('::');
      for (final check in trace.level1Checks.where((check) => !check.passed)) {
        errors.add('$label ${check.name}: ${check.detail}');
      }
    }
    return errors;
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

  void _validatePairwiseReadinessPlanEvidenceForRun(
    EvalPairwiseReadinessPlanEvidence? evidence, {
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required List<EvalAgentDirectiveVariant> agentDirectiveVariants,
    required EvalPairwiseReadinessIntent? pairwiseReadinessIntent,
  }) {
    if (evidence == null) return;
    final scenarioSetDigest = EvalProvenance.scenarioSetDigest(scenarios);
    if (evidence.scenarioSetDigest != scenarioSetDigest) {
      throw StateError(
        'Pairwise readiness plan scenarioSetDigest '
        '${evidence.scenarioSetDigest} does not match planned run '
        '$scenarioSetDigest',
      );
    }
    final profileSetDigest = EvalProvenance.profileSetDigest(profiles);
    if (evidence.profileSetDigest != profileSetDigest) {
      throw StateError(
        'Pairwise readiness plan profileSetDigest '
        '${evidence.profileSetDigest} does not match planned run '
        '$profileSetDigest',
      );
    }
    final profileBindingSetDigest = EvalProvenance.profileBindingSetDigest(
      profileExecutionBindingsForTarget(target, profiles),
    );
    if (evidence.profileBindingSetDigest != profileBindingSetDigest) {
      throw StateError(
        'Pairwise readiness plan profileBindingSetDigest '
        '${evidence.profileBindingSetDigest} does not match planned run '
        '$profileBindingSetDigest',
      );
    }
    if (pairwiseReadinessIntent != null) {
      final intentFailures = pairwiseReadinessIntent.validate();
      if (intentFailures.isNotEmpty) {
        throw StateError(
          'Invalid pairwise readiness intent: ${intentFailures.join('; ')}',
        );
      }
      final variantSetDigest = EvalProvenance.agentDirectiveVariantSetDigest(
        agentDirectiveVariants,
      );
      if (pairwiseReadinessIntent.agentDirectiveVariantSetDigest !=
          variantSetDigest) {
        throw StateError(
          'Pairwise readiness intent agentDirectiveVariantSetDigest '
          '${pairwiseReadinessIntent.agentDirectiveVariantSetDigest} does '
          'not match planned run $variantSetDigest',
        );
      }
      if (pairwiseReadinessIntent.profileBindingSetDigest !=
          profileBindingSetDigest) {
        throw StateError(
          'Pairwise readiness intent profileBindingSetDigest '
          '${pairwiseReadinessIntent.profileBindingSetDigest} does not match '
          'planned run $profileBindingSetDigest',
        );
      }
      final scenariosById = {
        for (final scenario in scenarios) scenario.id: scenario,
      };
      final profilesByName = {
        for (final profile in profiles) profile.name: profile,
      };
      final variantsByName = {
        for (final variant in agentDirectiveVariants) variant.name: variant,
      };
      for (final comparison in pairwiseReadinessIntent.comparisons) {
        final scenario = scenariosById[comparison.scenarioId];
        if (scenario == null) {
          throw StateError(
            'Pairwise readiness intent scenario ${comparison.scenarioId} is '
            'not in the planned run.',
          );
        }
        final capabilityId = scenario.metadata.primaryCapabilityId;
        final scenarioDigest = EvalProvenance.capture(
          scenario: scenario,
          profile: profiles.first,
        ).scenarioDigest;
        if (scenario.agentKind != comparison.agentKind ||
            capabilityId != comparison.capabilityId ||
            scenarioDigest != comparison.scenarioDigest) {
          throw StateError(
            'Pairwise readiness intent comparison ${comparison.intentKey} '
            'does not match scenario ${scenario.id}.',
          );
        }
        for (final option in [comparison.optionA, comparison.optionB]) {
          final profile = profilesByName[option.profileName];
          final profileDigest = profile == null
              ? null
              : EvalProvenance.capture(
                  scenario: scenario,
                  profile: profile,
                ).profileDigest;
          if (profile == null ||
              profile.modelClass != option.modelClass ||
              profileDigest != option.profileDigest) {
            throw StateError(
              'Pairwise readiness intent comparison ${comparison.intentKey} '
              'references profile ${option.profileName} outside the planned '
              'run.',
            );
          }
          final variant = variantsByName[option.agentDirectiveVariantName];
          if (variant == null ||
              EvalProvenance.agentDirectiveVariantDigest(variant) !=
                  option.agentDirectiveVariantDigest) {
            throw StateError(
              'Pairwise readiness intent comparison ${comparison.intentKey} '
              'references prompt variant '
              '${option.agentDirectiveVariantName} outside the planned run.',
            );
          }
        }
      }
    }
  }

  EvalPairwiseReadinessPlanEvidence? _resolvePairwiseReadinessPlanEvidence({
    required EvalPairwiseReadinessIntent? pairwiseReadinessIntent,
    required EvalPairwiseReadinessPlan? pairwiseReadinessPlan,
    required EvalPairwiseReadinessPlanEvidence? pairwiseReadinessPlanEvidence,
  }) {
    final intentEvidence = pairwiseReadinessIntent?.toManifestEvidence();
    final planEvidence = pairwiseReadinessPlan?.toManifestEvidence();
    if (intentEvidence != null &&
        planEvidence != null &&
        intentEvidence.pairwiseReadinessPlanSubjectDigest !=
            planEvidence.pairwiseReadinessPlanSubjectDigest) {
      throw StateError(
        'Pairwise readiness plan does not refine the supplied readiness intent.',
      );
    }
    final resolved = intentEvidence ?? planEvidence;
    if (resolved == null || pairwiseReadinessPlanEvidence == null) {
      return resolved ?? pairwiseReadinessPlanEvidence;
    }
    if (resolved.pairwiseReadinessPlanSubjectDigest !=
        pairwiseReadinessPlanEvidence.pairwiseReadinessPlanSubjectDigest) {
      throw StateError(
        'Pairwise readiness plan evidence does not match the supplied '
        'pairwise readiness intent or plan.',
      );
    }
    return resolved;
  }

  EvalTuningReadinessPolicyEvidence _tuningReadinessPolicyEvidence({
    required Set<String> requiredPrimaryCapabilityIds,
    required EvalPairwiseReadinessIntent? pairwiseReadinessIntent,
    required EvalPairwiseReadinessPlan? pairwiseReadinessPlan,
  }) {
    final pairwiseIntentKeys =
        pairwiseReadinessIntent?.requiredComparisonIntentKeys ??
        pairwiseReadinessPlan?.requiredComparisonIntentKeys ??
        const <String>{};
    final pairwiseDecisionCount =
        pairwiseReadinessIntent?.minBlindedPairwisePreferenceDecisions ??
        pairwiseReadinessPlan?.minBlindedPairwisePreferenceDecisions ??
        0;
    final pairwisePolicy =
        pairwiseReadinessIntent?.preferencePolicy ??
        pairwiseReadinessPlan?.preferencePolicy;
    final pairwiseOutcomeExpectationsByIntentKey =
        pairwiseReadinessIntent?.outcomeExpectationsByIntentKey ??
        pairwiseReadinessPlan?.outcomeExpectationsByIntentKey ??
        const <String, EvalPairwiseReadinessOutcomeExpectation>{};
    final pairwiseOutcomeExpectationsByComparisonKey =
        pairwiseReadinessPlan?.outcomeExpectationsByComparisonKey ??
        const <String, EvalPairwiseReadinessOutcomeExpectation>{};
    final policy = pairwiseIntentKeys.isEmpty
        ? EvalTuningPolicy.modelClassTuning(
            requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
          )
        : EvalTuningPolicy.modelClassTuning(
            requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
            minBlindedPairwisePreferenceDecisions: pairwiseDecisionCount,
            requiredBlindedPairwisePreferenceComparisonKeys: pairwiseIntentKeys,
            requiredBlindedPairwisePreferenceIntentKeys: pairwiseIntentKeys,
            requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey:
                pairwiseOutcomeExpectationsByComparisonKey,
            requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey:
                pairwiseOutcomeExpectationsByIntentKey,
            blindedPairwisePreferencePolicy: pairwisePolicy!,
          );
    return EvalTuningReadinessPolicyEvidence(
      policyName: policy.name,
      policyDigest: policy.policyDigest,
    );
  }

  void _validateRequiredPrimaryCapabilities(
    Set<String> requiredPrimaryCapabilityIds, {
    required List<EvalScenario> scenarios,
  }) {
    final primaryCapabilityIds = {
      for (final scenario in scenarios) ?scenario.metadata.primaryCapabilityId,
    };
    for (final capabilityId in requiredPrimaryCapabilityIds) {
      if (!_capabilityIdPattern.hasMatch(capabilityId)) {
        throw ArgumentError(
          'required primary capability id is invalid: $capabilityId',
        );
      }
      if (!primaryCapabilityIds.contains(capabilityId)) {
        throw StateError(
          'Required primary capability $capabilityId is missing from '
          'planned scenarios',
        );
      }
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

  List<EvalAgentDirectiveVariant> _snapshotAgentDirectiveVariants(
    List<EvalAgentDirectiveVariant> variants,
  ) {
    return [
      for (final variant in variants)
        EvalAgentDirectiveVariant.fromJson(variant.toJson()),
    ];
  }

  static final _capabilityIdPattern = RegExp(
    r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$',
  );
}
