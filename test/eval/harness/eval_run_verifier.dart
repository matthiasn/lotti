// Pure verification for Level 2 eval run artifacts.
//
// This validates the run as a complete matrix, not just the traces that happen
// to exist on disk. It is intentionally IO-free so the report entrypoint can
// pass file names from `eval/runs/<runId>` while unit tests exercise adversarial
// cases directly.

import 'package:collection/collection.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

import 'eval_assertions.dart';
import 'eval_judge_calibration.dart';
import 'eval_models.dart';
import 'eval_profile_config.dart';
import 'eval_provenance.dart';
import 'eval_scenario_validation.dart';
import 'eval_tuning_readiness.dart';

class EvalRunVerification {
  const EvalRunVerification(this.errors);

  final List<String> errors;

  bool get passed => errors.isEmpty;

  void throwIfFailed() {
    if (passed) return;
    throw StateError(errors.join('\n'));
  }
}

abstract final class EvalRunVerifier {
  static EvalRunVerification verify({
    required String runId,
    required List<EvalTrace> traces,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalRunManifest? manifest,
    Iterable<String> artifactNames = const <String>[],
    bool requireVerdicts = true,
    bool requireManifest = true,
    EvalTuningPolicy? tuningPolicy,
    JudgeCalibrationSet? calibrationSet,
    JudgeCalibrationReport? calibrationReport,
  }) {
    final errors = <String>[];
    final expectedKeys = _expectedKeys(scenarios, profiles);
    final scenarioById = {
      for (final scenario in scenarios) scenario.id: scenario,
    };
    final profileByName = {
      for (final profile in profiles) profile.name: profile,
    };
    final bindingByProfileName = {
      if (manifest != null)
        for (final binding in manifest.profileExecutionBindings)
          binding.profileName: binding,
    };
    final traceKeys = traces.map(_traceKey).toList(growable: false);
    final actualKeys = traceKeys.toSet();

    if (traces.isEmpty) {
      errors.add('run has no traces');
    }
    if (tuningPolicy != null) {
      final readiness = EvalTuningReadiness.assess(
        traces: traces,
        scenarios: scenarios,
        profiles: profiles,
        manifest: manifest,
        policy: tuningPolicy,
        calibrationSet: calibrationSet,
        calibrationReport: calibrationReport,
      );
      for (final failure in readiness.failures) {
        errors.add('tuning readiness failed: $failure');
      }
    }
    for (final issue in validateEvalScenarioCatalog(scenarios)) {
      errors.add('scenario catalog validation failed: $issue');
    }
    if (requireManifest && manifest == null) {
      errors.add('missing run manifest');
    }
    if (manifest != null) {
      _validateManifest(
        manifest: manifest,
        runId: runId,
        scenarios: scenarios,
        profiles: profiles,
        errors: errors,
      );
    }

    final duplicates = _duplicates(traceKeys);
    for (final key in duplicates) {
      errors.add('duplicate trace for $key');
    }

    for (final key in expectedKeys.difference(actualKeys).toList()..sort()) {
      errors.add('missing trace for $key');
    }
    for (final key in actualKeys.difference(expectedKeys).toList()..sort()) {
      errors.add('unexpected trace for $key');
    }

    if (artifactNames.isNotEmpty) {
      final traceStems = <String>{};
      final verdictStems = <String>{};
      for (final name in artifactNames) {
        if (name.endsWith('.trace.json')) {
          traceStems.add(_stripSuffix(name, '.trace.json'));
        } else if (name.endsWith('.verdict.json')) {
          verdictStems.add(_stripSuffix(name, '.verdict.json'));
        }
      }
      for (final stem in verdictStems.difference(traceStems).toList()..sort()) {
        errors.add('orphan verdict artifact for $stem');
      }
    }

    for (final trace in traces) {
      final key = _traceKey(trace);
      final canonicalScenario = scenarioById[trace.scenario.id];
      final canonicalProfile = profileByName[trace.profile.name];
      if (trace.runId != runId) {
        errors.add('$key has runId ${trace.runId}, expected $runId');
      }
      final profileBinding = bindingByProfileName[trace.profile.name];
      _validateWorkflowRun(trace, key, errors);
      _validateRuntimePrompt(trace, key, errors);
      _validateModelInvocations(
        trace,
        key,
        errors,
        profileBinding: profileBinding,
      );
      final requireLiveProviderEvidence =
          manifest?.targetKind == 'live' &&
          trace.output.providerDecision != null &&
          trace.output.resolvedModel != null &&
          trace.output.modelInvocations.isNotEmpty;
      _validateProviderRequests(
        trace,
        key,
        errors,
        profile: canonicalProfile ?? trace.profile,
        profileBinding: profileBinding,
        requireForLive: requireLiveProviderEvidence,
      );
      _validateProviderResponses(
        trace,
        key,
        errors,
        profileBinding: profileBinding,
        requireForLive: requireLiveProviderEvidence,
      );
      _validateCatalogPayloads(
        trace: trace,
        canonicalScenario: canonicalScenario,
        canonicalProfile: canonicalProfile,
        key: key,
        errors: errors,
      );
      _validateScenarioMetadata(
        trace.scenario,
        key,
        errors,
      );
      _validateProvenance(
        trace: trace,
        manifest: manifest,
        canonicalScenario: canonicalScenario,
        canonicalProfile: canonicalProfile,
        key: key,
        errors: errors,
      );
      _validateResolvedModel(
        trace,
        key,
        errors,
        profile: canonicalProfile ?? trace.profile,
        profileBinding: profileBinding,
      );
      _validateProviderDecision(
        trace,
        key,
        errors,
        profile: canonicalProfile ?? trace.profile,
        profileBinding: profileBinding,
      );
      final recomputedChecks = _validateLevel1(
        trace,
        key,
        errors,
        scenario: canonicalScenario ?? trace.scenario,
        profile: canonicalProfile ?? trace.profile,
      );
      final verdict = trace.verdict;
      if (requireVerdicts && verdict == null) {
        errors.add('missing verdict for $key');
        continue;
      }
      if (verdict == null) continue;
      _validateVerdict(trace, verdict, recomputedChecks, key, errors);
    }
    _validateJudgeConsistency(traces, errors);

    return EvalRunVerification(errors);
  }

  static Set<String> _expectedKeys(
    List<EvalScenario> scenarios,
    List<EvalProfile> profiles,
  ) {
    return {
      for (final scenario in scenarios)
        for (final profile in profiles)
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          )
            _key(scenario.id, profile.name, trialIndex),
    };
  }

  static Set<String> _duplicates(List<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) duplicates.add(value);
    }
    return duplicates;
  }

  static void _validateVerdict(
    EvalTrace trace,
    JudgeVerdict verdict,
    List<EvalCheck> recomputedChecks,
    String key,
    List<String> errors,
  ) {
    for (final dimension in [
      ('goalAttainment', verdict.goalAttainment),
      ('quality', verdict.quality),
      ('efficiency', verdict.efficiency),
    ]) {
      final (name, value) = dimension;
      if (value < 1 || value > 5) {
        errors.add('$key verdict $name is outside 1..5: $value');
      }
    }

    final minScore = [
      verdict.goalAttainment,
      verdict.quality,
      verdict.efficiency,
    ].reduce((a, b) => a < b ? a : b);
    if (verdict.pass && minScore < 3) {
      errors.add('$key verdict passes with a score below 3');
    }
    if (verdict.pass && recomputedChecks.any((check) => !check.passed)) {
      errors.add('$key verdict passes despite failed Level 1 checks');
    }
    if (!verdict.pass && verdict.issues.isEmpty) {
      errors.add('$key failing verdict must list at least one issue');
    }
    final traceDigest = verdict.traceDigest;
    if (traceDigest != null && !EvalProvenance.isDigest(traceDigest)) {
      errors.add('$key verdict traceDigest is not a sha256 digest');
    }
    _validateJudgeProvenance(trace, verdict.judge, key, errors);
  }

  static void _validateJudgeProvenance(
    EvalTrace trace,
    JudgeProvenanceRecord judge,
    String key,
    List<String> errors,
  ) {
    for (final field in [
      ('judgeName', judge.judgeName),
      ('judgeModel', judge.judgeModel),
      ('calibrationSetVersion', judge.calibrationSetVersion),
    ]) {
      final (name, value) = field;
      if (value.trim().isEmpty) {
        errors.add('$key verdict judge.$name is empty');
      }
    }
    if (!EvalProvenance.isDigest(judge.promptDigest)) {
      errors.add('$key verdict judge.promptDigest is not a sha256 digest');
    } else if (judge.promptDigest != trace.provenance.promptDigest) {
      errors.add(
        '$key verdict judge.promptDigest is ${judge.promptDigest}, '
        'expected ${trace.provenance.promptDigest}',
      );
    }
    if (!judge.profileVisible) {
      errors.add(
        '$key verdict judge.profileVisible must be true for profile-aware '
        'efficiency grading',
      );
    }
  }

  static void _validateJudgeConsistency(
    List<EvalTrace> traces,
    List<String> errors,
  ) {
    final judged = traces.where((trace) => trace.verdict != null).toList();
    if (judged.length < 2) return;

    final expectedSignature = _judgeSignature(judged.first.verdict!.judge);
    final expectedKey = _traceKey(judged.first);
    for (final trace in judged.skip(1)) {
      final signature = _judgeSignature(trace.verdict!.judge);
      if (signature == expectedSignature) continue;
      errors.add(
        '${_traceKey(trace)} verdict judge provenance differs from '
        '$expectedKey',
      );
    }
  }

  static String _judgeSignature(JudgeProvenanceRecord judge) => [
    judge.judgeName,
    judge.judgeModel,
    judge.promptDigest,
    judge.calibrationSetVersion,
    judge.profileVisible.toString(),
    judge.modelIdentityVisible.toString(),
  ].join('|');

  static void _validateCatalogPayloads({
    required EvalTrace trace,
    required EvalScenario? canonicalScenario,
    required EvalProfile? canonicalProfile,
    required String key,
    required List<String> errors,
  }) {
    const equality = DeepCollectionEquality();
    if (canonicalScenario != null &&
        !equality.equals(trace.scenario.toJson(), canonicalScenario.toJson())) {
      errors.add('$key scenario payload differs from catalog');
    }
    if (canonicalProfile != null &&
        !equality.equals(trace.profile.toJson(), canonicalProfile.toJson())) {
      errors.add('$key profile payload differs from configured profile');
    }
  }

  static void _validateScenarioMetadata(
    EvalScenario scenario,
    String key,
    List<String> errors,
  ) {
    if (scenario.metadata.capabilityIds.isEmpty) {
      errors.add('$key scenario metadata has no capability ids');
    }
    for (final capabilityId in scenario.metadata.capabilityIds) {
      if (!_capabilityIdPattern.hasMatch(capabilityId)) {
        errors.add(
          '$key scenario metadata has invalid capability $capabilityId',
        );
      }
    }
    if (scenario.metadata.isAdversarial &&
        scenario.metadata.source != EvalScenarioSource.adversarial &&
        !scenario.metadata.tags.contains('adversarial')) {
      errors.add(
        '$key adversarial scenario must use adversarial source or tag',
      );
    }
    if (scenario.metadata.isAdversarial &&
        scenario.metadata.tags
            .intersection(kDefaultAdversarialStressTags)
            .isEmpty) {
      errors.add(
        '$key adversarial scenario must use at least one default stress tag: '
        '${kDefaultAdversarialStressTags.join(', ')}',
      );
    }
    if (!scenario.metadata.isAdversarial &&
        scenario.metadata.source == EvalScenarioSource.adversarial) {
      errors.add(
        '$key scenario has adversarial source but isAdversarial is false',
      );
    }
    if (!scenario.metadata.isAdversarial &&
        scenario.metadata.tags.contains('adversarial')) {
      errors.add(
        '$key scenario has adversarial tag but isAdversarial is false',
      );
    }
  }

  static void _validateProvenance({
    required EvalTrace trace,
    required EvalRunManifest? manifest,
    required EvalScenario? canonicalScenario,
    required EvalProfile? canonicalProfile,
    required String key,
    required List<String> errors,
  }) {
    final expectedManifestDigest = manifest?.manifestDigest;
    if (expectedManifestDigest != null &&
        trace.provenance.manifestDigest != expectedManifestDigest) {
      errors.add(
        '$key provenance.manifestDigest is '
        '${trace.provenance.manifestDigest}, expected $expectedManifestDigest',
      );
    }

    final expectedScenarioDigest = EvalProvenance.digestJson(
      (canonicalScenario ?? trace.scenario).toJson(),
    );
    if (trace.provenance.scenarioDigest != expectedScenarioDigest) {
      errors.add(
        '$key provenance.scenarioDigest is ${trace.provenance.scenarioDigest}, '
        'expected $expectedScenarioDigest',
      );
    }

    final expectedProfileDigest = EvalProvenance.digestJson(
      (canonicalProfile ?? trace.profile).toJson(),
    );
    if (trace.provenance.profileDigest != expectedProfileDigest) {
      errors.add(
        '$key provenance.profileDigest is ${trace.provenance.profileDigest}, '
        'expected $expectedProfileDigest',
      );
    }

    final expectedPromptDigest = EvalProvenance.promptDigest();
    if (trace.provenance.promptDigest != expectedPromptDigest) {
      errors.add(
        '$key provenance.promptDigest is ${trace.provenance.promptDigest}, '
        'expected $expectedPromptDigest',
      );
    }

    final expectedToolSchemaDigest = EvalProvenance.toolSchemaDigest();
    if (trace.provenance.toolSchemaDigest != expectedToolSchemaDigest) {
      errors.add(
        '$key provenance.toolSchemaDigest is '
        '${trace.provenance.toolSchemaDigest}, expected $expectedToolSchemaDigest',
      );
    }

    for (final field in [
      ('manifestDigest', trace.provenance.manifestDigest),
      ('scenarioDigest', trace.provenance.scenarioDigest),
      ('profileDigest', trace.provenance.profileDigest),
      ('promptDigest', trace.provenance.promptDigest),
      ('toolSchemaDigest', trace.provenance.toolSchemaDigest),
    ]) {
      final (name, value) = field;
      if (!EvalProvenance.isDigest(value)) {
        errors.add('$key provenance.$name is not a sha256 digest');
      }
    }

    if (trace.provenance.codeRevision.trim().isEmpty) {
      errors.add('$key provenance.codeRevision must not be empty');
    }
  }

  static void _validateManifest({
    required EvalRunManifest manifest,
    required String runId,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required List<String> errors,
  }) {
    if (manifest.runId != runId) {
      errors.add('manifest has runId ${manifest.runId}, expected $runId');
    }
    if (manifest.traceSchemaVersion != EvalTrace.schemaVersion) {
      errors.add(
        'manifest traceSchemaVersion is ${manifest.traceSchemaVersion}, '
        'expected ${EvalTrace.schemaVersion}',
      );
    }
    final manifestDigest = manifest.manifestDigest;
    if (manifestDigest == null) {
      errors.add('manifest missing manifestDigest');
    } else {
      final expectedManifestDigest = EvalProvenance.manifestDigest(manifest);
      if (manifestDigest != expectedManifestDigest) {
        errors.add(
          'manifestDigest is $manifestDigest, expected $expectedManifestDigest',
        );
      }
      if (!EvalProvenance.isDigest(manifestDigest)) {
        errors.add('manifestDigest is not a sha256 digest');
      }
    }

    final expectedScenarioSetDigest = EvalProvenance.scenarioSetDigest(
      scenarios,
    );
    if (manifest.scenarioSetDigest != expectedScenarioSetDigest) {
      errors.add(
        'manifest scenarioSetDigest is ${manifest.scenarioSetDigest}, '
        'expected $expectedScenarioSetDigest',
      );
      if (manifest.scenarioCatalogEvidence?.usesExternalCatalog ?? false) {
        errors.add(
          'run was created with an external scenario catalog; set '
          'EVAL_SCENARIOS to the same catalog before verify/report',
        );
      }
    }

    final expectedProfileSetDigest = EvalProvenance.profileSetDigest(profiles);
    if (manifest.profileSetDigest != expectedProfileSetDigest) {
      errors.add(
        'manifest profileSetDigest is ${manifest.profileSetDigest}, '
        'expected $expectedProfileSetDigest',
      );
    }
    _validateManifestProfileBindings(
      manifest: manifest,
      profiles: profiles,
      errors: errors,
    );

    final expectedPromptDigest = EvalProvenance.promptDigest();
    if (manifest.promptDigest != expectedPromptDigest) {
      errors.add(
        'manifest promptDigest is ${manifest.promptDigest}, '
        'expected $expectedPromptDigest',
      );
    }

    final expectedToolSchemaDigest = EvalProvenance.toolSchemaDigest();
    if (manifest.toolSchemaDigest != expectedToolSchemaDigest) {
      errors.add(
        'manifest toolSchemaDigest is ${manifest.toolSchemaDigest}, '
        'expected $expectedToolSchemaDigest',
      );
    }

    if (manifest.codeRevision.trim().isEmpty) {
      errors.add('manifest codeRevision must not be empty');
    } else if (manifest.codeRevision == 'unknown') {
      errors.add('manifest codeRevision must not be unknown');
    }
    for (final field in [
      ('scenarioSetDigest', manifest.scenarioSetDigest),
      ('profileSetDigest', manifest.profileSetDigest),
      ('profileBindingSetDigest', manifest.profileBindingSetDigest),
      ('promptDigest', manifest.promptDigest),
      ('toolSchemaDigest', manifest.toolSchemaDigest),
    ]) {
      final (name, value) = field;
      if (!EvalProvenance.isDigest(value)) {
        errors.add('manifest $name is not a sha256 digest');
      }
    }
    if (manifest.gitDirty) {
      final dirtyDiffDigest = manifest.dirtyDiffDigest;
      if (dirtyDiffDigest == null || dirtyDiffDigest.isEmpty) {
        errors.add('manifest dirty git state must include dirtyDiffDigest');
      } else if (!EvalProvenance.isDigest(dirtyDiffDigest)) {
        errors.add('manifest dirtyDiffDigest is not a sha256 digest');
      }
    }
    for (final entry in manifest.envPresence.entries) {
      if (entry.key.trim().isEmpty) {
        errors.add('manifest envPresence contains an empty key');
      }
    }
    _validateScenarioCatalogEvidence(
      manifest.scenarioCatalogEvidence,
      manifest.scenarioSetDigest,
      errors,
    );
  }

  static void _validateManifestProfileBindings({
    required EvalRunManifest manifest,
    required List<EvalProfile> profiles,
    required List<String> errors,
  }) {
    final bindings = manifest.profileExecutionBindings;
    if (bindings.isEmpty) {
      errors.add('manifest profileExecutionBindings are missing');
    }
    final expectedBindingDigest = EvalProvenance.profileBindingSetDigest(
      bindings,
    );
    if (manifest.profileBindingSetDigest != expectedBindingDigest) {
      errors.add(
        'manifest profileBindingSetDigest is '
        '${manifest.profileBindingSetDigest}, expected '
        '$expectedBindingDigest',
      );
    }

    final expectedNames = profiles.map((profile) => profile.name).toSet();
    final actualNames = bindings.map((binding) => binding.profileName).toSet();
    for (final duplicate in _duplicates(
      bindings.map((binding) => binding.profileName).toList(),
    )) {
      errors.add('duplicate manifest profileExecutionBinding for $duplicate');
    }
    for (final missing
        in expectedNames.difference(actualNames).toList()..sort()) {
      errors.add('missing manifest profileExecutionBinding for $missing');
    }
    for (final unexpected
        in actualNames.difference(expectedNames).toList()..sort()) {
      errors.add('unexpected manifest profileExecutionBinding for $unexpected');
    }

    final profileByName = {
      for (final profile in profiles) profile.name: profile,
    };
    for (final binding in bindings) {
      final profile = profileByName[binding.profileName];
      final label = 'manifest profileExecutionBindings[${binding.profileName}]';
      if (profile == null) continue;
      _expectManifestBindingField(
        errors,
        label,
        'modelClass',
        binding.modelClass.name,
        profile.modelClass.name,
      );
      if (binding.isLocal != profile.isLocal) {
        errors.add(
          '$label isLocal is ${binding.isLocal}, expected ${profile.isLocal}',
        );
      }
      for (final field in [
        ('profileId', binding.profileId),
        ('modelConfigId', binding.modelConfigId),
        ('providerId', binding.providerId),
        ('providerType', binding.providerType),
        ('providerModelId', binding.providerModelId),
        ('providerEndpointOrigin', binding.providerEndpointOrigin),
        ('providerBaseUrlDigest', binding.providerBaseUrlDigest),
      ]) {
        final (name, value) = field;
        if (value.trim().isEmpty) {
          errors.add('$label $name is empty');
        }
      }
      if (!EvalProvenance.isDigest(binding.providerBaseUrlDigest)) {
        errors.add('$label providerBaseUrlDigest is not a sha256 digest');
      }
      if (binding.providerType.trim().isNotEmpty) {
        _validateProviderType(
          binding.providerType,
          '$label providerType',
          errors,
        );
      }
      if (profile.isLocal && binding.providerType != 'ollama') {
        errors.add(
          '$label providerType is ${binding.providerType}, '
          'expected ollama for local profile',
        );
      }
      if (!profile.isLocal && binding.providerType == 'ollama') {
        errors.add('$label providerType is ollama for frontier profile');
      }
      if (!binding.providerRequestTemperature.isFinite) {
        errors.add('$label providerRequestTemperature must be finite');
      } else {
        final expectedTemperature = _expectedProviderRequestTemperature(
          profile: profile,
          providerType: binding.providerType,
        );
        if (!_sameTemperature(
          binding.providerRequestTemperature,
          expectedTemperature,
        )) {
          errors.add(
            '$label providerRequestTemperature is '
            '${binding.providerRequestTemperature}, expected '
            '$expectedTemperature for providerType ${binding.providerType}',
          );
        }
      }
    }
  }

  static void _validateScenarioCatalogEvidence(
    EvalScenarioCatalogEvidence? evidence,
    String manifestScenarioSetDigest,
    List<String> errors,
  ) {
    if (evidence == null) {
      errors.add('manifest scenarioCatalogEvidence is missing');
      return;
    }
    if (evidence.scenarioSetDigest != manifestScenarioSetDigest) {
      errors.add(
        'manifest scenarioCatalogEvidence scenarioSetDigest is '
        '${evidence.scenarioSetDigest}, expected $manifestScenarioSetDigest',
      );
    }
    if (!EvalProvenance.isDigest(evidence.scenarioSetDigest)) {
      errors.add(
        'manifest scenarioCatalogEvidence scenarioSetDigest is not a '
        'sha256 digest',
      );
    }
    final externalDigest = evidence.externalCatalogDigest;
    if (externalDigest != null && !EvalProvenance.isDigest(externalDigest)) {
      errors.add(
        'manifest scenarioCatalogEvidence externalCatalogDigest is not a '
        'sha256 digest',
      );
    }
    if (evidence.publicScenarioCount < 0) {
      errors.add('manifest scenarioCatalogEvidence publicScenarioCount < 0');
    }
    if (evidence.externalScenarioCount < 0) {
      errors.add('manifest scenarioCatalogEvidence externalScenarioCount < 0');
    }
    if (evidence.usesExternalCatalog && externalDigest == null) {
      errors.add(
        'manifest scenarioCatalogEvidence external catalog digest is missing',
      );
    }
    if (evidence.protectedHoldout && !evidence.usesExternalCatalog) {
      errors.add(
        'manifest scenarioCatalogEvidence protectedHoldout requires an '
        'external catalog',
      );
    }
    if (evidence.protectedHoldout &&
        evidence.protectedHoldoutScenarioIds.isEmpty) {
      errors.add(
        'manifest scenarioCatalogEvidence protected holdout ids are missing',
      );
    }
    final protectedIds = evidence.protectedScenarioIds.toSet();
    for (final scenarioId in evidence.protectedHoldoutScenarioIds) {
      if (!protectedIds.contains(scenarioId)) {
        errors.add(
          'manifest scenarioCatalogEvidence holdout id $scenarioId is not '
          'listed as protected',
        );
      }
    }
  }

  static void _validateWorkflowRun(
    EvalTrace trace,
    String key,
    List<String> errors,
  ) {
    final workflowRun = trace.output.workflowRun;
    if (workflowRun == null) return;

    final expectedCellId =
        '${trace.runId}::${trace.scenario.id}::${trace.profile.name}::'
        '${trace.trialIndex}';
    final isBoundToExpectedCell = workflowRun.matrixCellId == expectedCellId;
    if (!isBoundToExpectedCell &&
        !workflowRun.runKey.contains(expectedCellId)) {
      errors.add(
        '$key workflow runKey is not bound to matrix cell $expectedCellId',
      );
    }
    if (!isBoundToExpectedCell &&
        !workflowRun.threadId.contains(expectedCellId)) {
      errors.add(
        '$key workflow threadId is not bound to matrix cell $expectedCellId',
      );
    }
  }

  static void _validateRuntimePrompt(
    EvalTrace trace,
    String key,
    List<String> errors,
  ) {
    final runtimePrompt = trace.output.runtimePrompt;
    if (runtimePrompt == null) return;
    _validateRuntimePromptRecord(runtimePrompt, '$key runtimePrompt', errors);
  }

  static void _validateRuntimePromptRecord(
    RuntimePromptRecord runtimePrompt,
    String label,
    List<String> errors,
  ) {
    for (final field in [
      ('systemDigest', runtimePrompt.systemDigest),
      ('userDigest', runtimePrompt.userDigest),
      ('toolSchemaDigest', runtimePrompt.toolSchemaDigest),
    ]) {
      final (name, value) = field;
      if (value != null && !EvalProvenance.isDigest(value)) {
        errors.add('$label.$name is not a sha256 digest');
      }
    }
    if (runtimePrompt.toolCount < 0) {
      errors.add('$label.toolCount must not be negative');
    }
    if (runtimePrompt.toolCount > 0 && runtimePrompt.toolSchemaDigest == null) {
      errors.add(
        '$label.toolSchemaDigest missing for '
        '${runtimePrompt.toolCount} tools',
      );
    }
  }

  static void _validateModelInvocations(
    EvalTrace trace,
    String key,
    List<String> errors, {
    EvalProfileExecutionBinding? profileBinding,
  }) {
    final invocations = trace.output.modelInvocations;
    if ((trace.output.runtimePrompt != null ||
            (trace.output.workflowRun != null &&
                trace.output.success &&
                trace.output.providerDecision != null &&
                trace.output.resolvedModel != null)) &&
        invocations.isEmpty) {
      errors.add('$key missing model invocation provenance');
    }
    if (invocations.isNotEmpty &&
        trace.output.turnCount != invocations.length) {
      errors.add(
        '$key turnCount ${trace.output.turnCount} does not match '
        'modelInvocations length ${invocations.length}',
      );
    }
    for (var index = 0; index < invocations.length; index++) {
      final invocation = invocations[index];
      final label = '$key modelInvocations[$index]';
      if (invocation.invocationIndex != index) {
        errors.add(
          '$label invocationIndex is ${invocation.invocationIndex}, '
          'expected $index',
        );
      }
      if (invocation.providerModelId.trim().isEmpty) {
        errors.add('$label providerModelId is empty');
      }
      if (invocation.providerId.trim().isEmpty) {
        errors.add('$label providerId is empty');
      }
      if (invocation.providerType.trim().isEmpty) {
        errors.add('$label providerType is empty');
      } else {
        _validateProviderType(
          invocation.providerType,
          '$label providerType',
          errors,
        );
      }
      if (profileBinding != null) {
        if (invocation.providerModelId != profileBinding.providerModelId) {
          errors.add(
            '$label providerModelId is ${invocation.providerModelId}, '
            'expected manifest binding ${profileBinding.providerModelId}',
          );
        }
        if (invocation.providerId != profileBinding.providerId) {
          errors.add(
            '$label providerId is ${invocation.providerId}, expected '
            'manifest binding ${profileBinding.providerId}',
          );
        }
        if (invocation.providerType != profileBinding.providerType) {
          errors.add(
            '$label providerType is ${invocation.providerType}, expected '
            'manifest binding ${profileBinding.providerType}',
          );
        }
        _expectBindingTraceField(
          errors,
          label,
          'providerEndpointOrigin',
          invocation.providerEndpointOrigin,
          profileBinding.providerEndpointOrigin,
        );
        _expectBindingTraceField(
          errors,
          label,
          'providerBaseUrlDigest',
          invocation.providerBaseUrlDigest,
          profileBinding.providerBaseUrlDigest,
        );
      }
      _validateRuntimePromptRecord(
        invocation.runtimePrompt,
        '$label.runtimePrompt',
        errors,
      );
      final forcedToolName = invocation.forcedToolName;
      if (forcedToolName != null &&
          !invocation.toolNames.contains(forcedToolName)) {
        errors.add(
          '$label forcedToolName $forcedToolName is not in toolNames',
        );
      }
    }

    final runtimePrompt = trace.output.runtimePrompt;
    if (runtimePrompt != null && invocations.isNotEmpty) {
      final lastPrompt = invocations.last.runtimePrompt;
      if (!_sameRuntimePrompt(runtimePrompt, lastPrompt)) {
        errors.add('$key runtimePrompt does not match last model invocation');
      }
    }

    final decision = trace.output.providerDecision;
    if (decision == null) return;
    for (var index = 0; index < invocations.length; index++) {
      final invocation = invocations[index];
      final label = '$key modelInvocations[$index]';
      if (invocation.providerModelId != decision.selectedProviderModelId) {
        errors.add(
          '$label providerModelId is ${invocation.providerModelId}, expected '
          '${decision.selectedProviderModelId}',
        );
      }
      if (invocation.providerId != decision.selectedProviderId) {
        errors.add(
          '$label providerId is ${invocation.providerId}, expected '
          '${decision.selectedProviderId}',
        );
      }
      if (invocation.providerType != decision.selectedProviderType) {
        errors.add(
          '$label providerType is ${invocation.providerType}, expected '
          '${decision.selectedProviderType}',
        );
      }
    }
  }

  static bool _sameRuntimePrompt(
    RuntimePromptRecord a,
    RuntimePromptRecord b,
  ) {
    return a.systemDigest == b.systemDigest &&
        a.userDigest == b.userDigest &&
        a.toolSchemaDigest == b.toolSchemaDigest &&
        a.toolCount == b.toolCount;
  }

  static void _validateProviderRequests(
    EvalTrace trace,
    String key,
    List<String> errors, {
    required EvalProfile profile,
    required bool requireForLive,
    EvalProfileExecutionBinding? profileBinding,
  }) {
    final requests = trace.output.providerRequests;
    if (requireForLive && requests.isEmpty) {
      errors.add('$key missing provider request provenance for live trace');
    }
    if (requests.isEmpty) return;

    final invocationByIndex = {
      for (final invocation in trace.output.modelInvocations)
        invocation.invocationIndex: invocation,
    };
    final invocationIndexes = invocationByIndex.keys.toSet();
    final byInvocation = <int, List<ProviderRequestRecord>>{};

    for (var index = 0; index < requests.length; index++) {
      final request = requests[index];
      final label = '$key providerRequests[$index]';
      byInvocation.putIfAbsent(request.invocationIndex, () => []).add(request);
      if (!invocationIndexes.contains(request.invocationIndex)) {
        errors.add(
          '$label invocationIndex ${request.invocationIndex} has no '
          'matching model invocation',
        );
      }
      final invocation = invocationByIndex[request.invocationIndex];
      if (invocation != null) {
        _validateProviderRequestMatchesInvocation(
          request: request,
          invocation: invocation,
          label: label,
          errors: errors,
        );
      }
      if (request.requestIndex < 0) {
        errors.add('$label requestIndex must not be negative');
      }
      if (request.turnIndex < 0) {
        errors.add('$label turnIndex must not be negative');
      }
      if (request.providerModelId.trim().isEmpty) {
        errors.add('$label providerModelId is empty');
      }
      if (request.providerId.trim().isEmpty) {
        errors.add('$label providerId is empty');
      }
      if (request.providerType.trim().isEmpty) {
        errors.add('$label providerType is empty');
      } else {
        _validateProviderType(
          request.providerType,
          '$label providerType',
          errors,
        );
      }
      if (profileBinding != null) {
        if (request.providerModelId != profileBinding.providerModelId) {
          errors.add(
            '$label providerModelId is ${request.providerModelId}, expected '
            'manifest binding ${profileBinding.providerModelId}',
          );
        }
        if (request.providerId != profileBinding.providerId) {
          errors.add(
            '$label providerId is ${request.providerId}, expected '
            'manifest binding ${profileBinding.providerId}',
          );
        }
        if (request.providerType != profileBinding.providerType) {
          errors.add(
            '$label providerType is ${request.providerType}, expected '
            'manifest binding ${profileBinding.providerType}',
          );
        }
        _expectBindingTraceField(
          errors,
          label,
          'providerEndpointOrigin',
          request.providerEndpointOrigin,
          profileBinding.providerEndpointOrigin,
        );
        _expectBindingTraceField(
          errors,
          label,
          'providerBaseUrlDigest',
          request.providerBaseUrlDigest,
          profileBinding.providerBaseUrlDigest,
        );
      }
      if (!EvalProvenance.isDigest(request.messageDigest)) {
        errors.add('$label messageDigest is not a sha256 digest');
      }
      if (!EvalProvenance.isDigest(request.toolSchemaDigest)) {
        errors.add('$label toolSchemaDigest is not a sha256 digest');
      }
      if (request.messageCount <= 0) {
        errors.add('$label messageCount must be positive');
      }
      if (request.toolCount < 0) {
        errors.add('$label toolCount must not be negative');
      }
      if (request.toolNames.length != request.toolCount) {
        errors.add(
          '$label toolCount ${request.toolCount} does not match '
          'toolNames length ${request.toolNames.length}',
        );
      }
      final forcedToolName = request.forcedToolName;
      if (forcedToolName != null &&
          !request.toolNames.contains(forcedToolName)) {
        errors.add(
          '$label forcedToolName $forcedToolName is not in toolNames',
        );
      }
      if (!request.temperature.isFinite) {
        errors.add('$label temperature must be finite');
      } else {
        final expectedTemperature =
            profileBinding?.providerRequestTemperature ??
            _expectedProviderRequestTemperature(
              profile: profile,
              providerType: request.providerType,
            );
        if (!_sameTemperature(request.temperature, expectedTemperature)) {
          errors.add(
            '$label temperature is ${request.temperature}, expected '
            '$expectedTemperature for providerType ${request.providerType}',
          );
        }
      }
      if (request.thoughtSignatureCount < 0) {
        errors.add('$label thoughtSignatureCount must not be negative');
      }
    }

    for (final invocationIndex in invocationIndexes.toList()..sort()) {
      if (!byInvocation.containsKey(invocationIndex)) {
        errors.add(
          '$key providerRequests missing request evidence for '
          'model invocation $invocationIndex',
        );
      }
    }

    for (final entry in byInvocation.entries) {
      final invocationRequests = entry.value
        ..sort((a, b) => a.requestIndex.compareTo(b.requestIndex));
      for (var index = 0; index < invocationRequests.length; index++) {
        final request = invocationRequests[index];
        if (request.requestIndex != index) {
          errors.add(
            '$key providerRequests invocation ${entry.key} requestIndex '
            '${request.requestIndex} expected $index',
          );
        }
      }
    }

    final decision = trace.output.providerDecision;
    if (decision == null) return;
    for (var index = 0; index < requests.length; index++) {
      final request = requests[index];
      final label = '$key providerRequests[$index]';
      if (request.providerModelId != decision.selectedProviderModelId) {
        errors.add(
          '$label providerModelId is ${request.providerModelId}, expected '
          '${decision.selectedProviderModelId}',
        );
      }
      if (request.providerId != decision.selectedProviderId) {
        errors.add(
          '$label providerId is ${request.providerId}, expected '
          '${decision.selectedProviderId}',
        );
      }
      if (request.providerType != decision.selectedProviderType) {
        errors.add(
          '$label providerType is ${request.providerType}, expected '
          '${decision.selectedProviderType}',
        );
      }
    }
  }

  static void _validateProviderResponses(
    EvalTrace trace,
    String key,
    List<String> errors, {
    required bool requireForLive,
    EvalProfileExecutionBinding? profileBinding,
  }) {
    final responses = trace.output.providerResponses;
    final requests = trace.output.providerRequests;
    if (requireForLive && requests.isNotEmpty && responses.isEmpty) {
      errors.add('$key missing provider response provenance for live trace');
      for (var index = 0; index < requests.length; index++) {
        errors.add(
          '$key providerResponses missing response evidence for '
          'providerRequests[$index]',
        );
      }
    }
    if (responses.isEmpty) return;

    final requestByKey = <String, ProviderRequestRecord>{};
    final requestLabels = <String, String>{};
    for (var index = 0; index < requests.length; index++) {
      final request = requests[index];
      final requestKey = _providerRequestKey(
        request.invocationIndex,
        request.requestIndex,
      );
      requestByKey[requestKey] = request;
      requestLabels[requestKey] = 'providerRequests[$index]';
    }

    final responseKeys = <String>[];
    final responseByKey = <String, ProviderResponseRecord>{};
    for (var index = 0; index < responses.length; index++) {
      final response = responses[index];
      final label = '$key providerResponses[$index]';
      final responseKey = _providerRequestKey(
        response.invocationIndex,
        response.requestIndex,
      );
      responseKeys.add(responseKey);
      responseByKey[responseKey] = response;

      if (response.invocationIndex < 0) {
        errors.add('$label invocationIndex must not be negative');
      }
      if (response.requestIndex < 0) {
        errors.add('$label requestIndex must not be negative');
      }
      if (response.turnIndex < 0) {
        errors.add('$label turnIndex must not be negative');
      }
      if (response.providerType.trim().isEmpty) {
        errors.add('$label providerType is empty');
      } else {
        _validateProviderType(
          response.providerType,
          '$label providerType',
          errors,
        );
      }
      if (response.chunkCount < 0) {
        errors.add('$label chunkCount must not be negative');
      }

      final request = requestByKey[responseKey];
      if (request == null) {
        errors.add(
          '$label has no matching provider request for invocationIndex '
          '${response.invocationIndex} requestIndex ${response.requestIndex}',
        );
      } else {
        _validateProviderResponseMatchesRequest(
          response: response,
          request: request,
          requestLabel: requestLabels[responseKey]!,
          label: label,
          errors: errors,
        );
      }

      _validateResponseMetadataList(
        response.responseModelIds,
        '$label responseModelIds',
        errors,
      );
      _validateResponseMetadataList(
        response.systemFingerprints,
        '$label systemFingerprints',
        errors,
      );
      _validateResponseMetadataList(
        response.providerNames,
        '$label providerNames',
        errors,
      );
      _validateResponseMetadataList(
        response.serviceTiers,
        '$label serviceTiers',
        errors,
      );

      final responseModelIds = _authoritativeResponseModelIds(
        response.responseModelIds,
      );
      final responseModelCount = responseModelIds.length;
      if (responseModelCount > 1) {
        errors.add(
          '$label responseModelIds are inconsistent: '
          '$responseModelIds',
        );
      } else if (responseModelCount == 1) {
        final responseModelId = responseModelIds.single;
        if (response.responseModelUnavailableReason != null) {
          errors.add(
            '$label responseModelUnavailableReason is set despite '
            'responseModelIds being present',
          );
        }
        if (request != null && responseModelId != request.providerModelId) {
          errors.add(
            '$label responseModelId is $responseModelId, expected '
            '${requestLabels[responseKey]}.providerModelId '
            '${request.providerModelId}',
          );
        }
        if (profileBinding != null &&
            responseModelId != profileBinding.providerModelId) {
          errors.add(
            '$label responseModelId is $responseModelId, expected manifest '
            'binding ${profileBinding.providerModelId}',
          );
        }
      } else {
        final unavailableReason = response.responseModelUnavailableReason;
        if (unavailableReason == null || unavailableReason.trim().isEmpty) {
          errors.add(
            '$label responseModelUnavailableReason is required when '
            'responseModelIds is empty',
          );
        }
        if (requireForLive &&
            _requiresProviderReportedResponseModel(response.providerType)) {
          errors.add(
            '$label missing provider-reported response model for providerType '
            '${response.providerType}',
          );
        }
      }

      if (response.systemFingerprints.length > 1) {
        errors.add(
          '$label systemFingerprints are inconsistent: '
          '${response.systemFingerprints}',
        );
      }
    }

    for (final duplicate in _duplicates(responseKeys)) {
      errors.add('$key duplicate providerResponses entry for $duplicate');
    }

    if (requireForLive) {
      for (var index = 0; index < requests.length; index++) {
        final request = requests[index];
        final requestKey = _providerRequestKey(
          request.invocationIndex,
          request.requestIndex,
        );
        if (!responseByKey.containsKey(requestKey)) {
          errors.add(
            '$key providerResponses missing response evidence for '
            'providerRequests[$index]',
          );
        }
      }
    }
  }

  static String _providerRequestKey(int invocationIndex, int requestIndex) =>
      'invocation:$invocationIndex/request:$requestIndex';

  static void _validateProviderResponseMatchesRequest({
    required ProviderResponseRecord response,
    required ProviderRequestRecord request,
    required String requestLabel,
    required String label,
    required List<String> errors,
  }) {
    if (response.turnIndex != request.turnIndex) {
      errors.add(
        '$label turnIndex is ${response.turnIndex}, expected '
        '$requestLabel.turnIndex ${request.turnIndex}',
      );
    }
    if (response.providerType != request.providerType) {
      errors.add(
        '$label providerType is ${response.providerType}, expected '
        '$requestLabel.providerType ${request.providerType}',
      );
    }
  }

  static List<String> _authoritativeResponseModelIds(
    List<String> responseModelIds,
  ) => [
    for (final modelId in responseModelIds)
      if (modelId.trim().toLowerCase() != 'keepalive') modelId,
  ];

  static void _validateResponseMetadataList(
    List<String> values,
    String label,
    List<String> errors,
  ) {
    for (final value in values) {
      if (value.trim().isEmpty) {
        errors.add('$label contains an empty value');
      }
    }
    for (final duplicate in _duplicates(values)) {
      errors.add('$label contains duplicate value $duplicate');
    }
  }

  static bool _requiresProviderReportedResponseModel(String providerType) {
    final parsed = _providerTypeByName(providerType);
    return parsed == InferenceProviderType.openAi ||
        parsed == InferenceProviderType.mistral ||
        parsed == InferenceProviderType.ollama;
  }

  static double _expectedProviderRequestTemperature({
    required EvalProfile profile,
    required String providerType,
  }) {
    if (_providerTypeByName(providerType) == InferenceProviderType.openAi) {
      return 1;
    }
    return profile.temperature;
  }

  static bool _sameTemperature(double actual, double expected) =>
      (actual - expected).abs() <= 0.000001;

  static InferenceProviderType? _providerTypeByName(String name) {
    for (final type in InferenceProviderType.values) {
      if (type.name == name) return type;
    }
    return null;
  }

  static void _validateProviderType(
    String providerType,
    String label,
    List<String> errors,
  ) {
    if (_providerTypeByName(providerType) != null) return;
    errors.add('$label is unknown: $providerType');
  }

  static void _validateProviderRequestMatchesInvocation({
    required ProviderRequestRecord request,
    required ModelInvocationRecord invocation,
    required String label,
    required List<String> errors,
  }) {
    final invocationLabel = 'modelInvocations[${invocation.invocationIndex}]';
    if (request.providerModelId != invocation.providerModelId) {
      errors.add(
        '$label providerModelId is ${request.providerModelId}, expected '
        '$invocationLabel.providerModelId ${invocation.providerModelId}',
      );
    }
    if (request.providerId != invocation.providerId) {
      errors.add(
        '$label providerId is ${request.providerId}, expected '
        '$invocationLabel.providerId ${invocation.providerId}',
      );
    }
    if (request.providerType != invocation.providerType) {
      errors.add(
        '$label providerType is ${request.providerType}, expected '
        '$invocationLabel.providerType ${invocation.providerType}',
      );
    }
    if (request.providerEndpointOrigin != invocation.providerEndpointOrigin) {
      errors.add(
        '$label providerEndpointOrigin is ${request.providerEndpointOrigin}, '
        'expected $invocationLabel.providerEndpointOrigin '
        '${invocation.providerEndpointOrigin}',
      );
    }
    if (request.providerBaseUrlDigest != invocation.providerBaseUrlDigest) {
      errors.add(
        '$label providerBaseUrlDigest is ${request.providerBaseUrlDigest}, '
        'expected $invocationLabel.providerBaseUrlDigest '
        '${invocation.providerBaseUrlDigest}',
      );
    }

    final expectedToolSchemaDigest = invocation.runtimePrompt.toolSchemaDigest;
    if (expectedToolSchemaDigest != null &&
        request.toolSchemaDigest != expectedToolSchemaDigest) {
      errors.add(
        '$label toolSchemaDigest is ${request.toolSchemaDigest}, expected '
        '$invocationLabel.runtimePrompt.toolSchemaDigest '
        '$expectedToolSchemaDigest',
      );
    }
    const listEquality = ListEquality<String>();
    if (!listEquality.equals(request.toolNames, invocation.toolNames)) {
      errors.add(
        '$label toolNames are ${request.toolNames}, expected '
        '$invocationLabel.toolNames ${invocation.toolNames}',
      );
    }
    if (request.forcedToolName != invocation.forcedToolName) {
      errors.add(
        '$label forcedToolName is ${request.forcedToolName}, expected '
        '$invocationLabel.forcedToolName ${invocation.forcedToolName}',
      );
    }
  }

  static void _validateResolvedModel(
    EvalTrace trace,
    String key,
    List<String> errors, {
    required EvalProfile profile,
    EvalProfileExecutionBinding? profileBinding,
  }) {
    final resolved = trace.output.resolvedModel;
    if (resolved == null) {
      errors.add('$key missing resolvedModel provenance');
      return;
    }

    final expected = evalProfileConfig(profile);
    final expectedProfileId = profileBinding?.profileId ?? expected.profileId;
    final expectedModelConfigId =
        profileBinding?.modelConfigId ?? expected.modelConfigId;
    _expectResolvedField(
      errors,
      key,
      'profileId',
      resolved.profileId,
      expectedProfileId,
    );
    _expectResolvedField(
      errors,
      key,
      'modelConfigId',
      resolved.modelConfigId,
      expectedModelConfigId,
    );
    if (profileBinding != null) {
      _expectResolvedField(
        errors,
        key,
        'providerModelId',
        resolved.providerModelId,
        profileBinding.providerModelId,
      );
      _expectResolvedField(
        errors,
        key,
        'providerId',
        resolved.providerId,
        profileBinding.providerId,
      );
      _expectResolvedField(
        errors,
        key,
        'providerType',
        resolved.providerType,
        profileBinding.providerType,
      );
      _expectResolvedBindingField(
        errors,
        key,
        'providerEndpointOrigin',
        resolved.providerEndpointOrigin,
        profileBinding.providerEndpointOrigin,
      );
      _expectResolvedBindingField(
        errors,
        key,
        'providerBaseUrlDigest',
        resolved.providerBaseUrlDigest,
        profileBinding.providerBaseUrlDigest,
      );
    }
    if (resolved.providerType.trim().isEmpty) {
      errors.add('$key resolvedModel.providerType is empty');
    } else {
      _validateProviderType(
        resolved.providerType,
        '$key resolvedModel.providerType',
        errors,
      );
    }
    final wakeRunResolvedModelId = resolved.wakeRunResolvedModelId;
    if (wakeRunResolvedModelId != null) {
      _expectResolvedField(
        errors,
        key,
        'wakeRunResolvedModelId',
        wakeRunResolvedModelId,
        resolved.providerModelId,
      );
    }
    final usageModelId = resolved.usageModelId;
    if (usageModelId != null) {
      _expectResolvedField(
        errors,
        key,
        'usageModelId',
        usageModelId,
        resolved.providerModelId,
      );
    }
  }

  static void _validateProviderDecision(
    EvalTrace trace,
    String key,
    List<String> errors, {
    required EvalProfile profile,
    EvalProfileExecutionBinding? profileBinding,
  }) {
    final decision = trace.output.providerDecision;
    if (decision == null) {
      errors.add('$key missing providerDecision provenance');
      return;
    }

    final expected = evalProfileConfig(profile);
    final expectedProfileId = profileBinding?.profileId ?? expected.profileId;
    final expectedModelConfigId =
        profileBinding?.modelConfigId ?? expected.modelConfigId;
    final expectedProviderId =
        profileBinding?.providerId ?? expected.providerId;
    final expectedProviderType =
        profileBinding?.providerType ?? expected.providerType;
    final expectedProviderModelId =
        profileBinding?.providerModelId ?? expected.providerModelId;
    final expectedProviderEndpointOrigin =
        profileBinding?.providerEndpointOrigin ??
        expected.providerEndpointOrigin;
    final expectedProviderBaseUrlDigest =
        profileBinding?.providerBaseUrlDigest ?? expected.providerBaseUrlDigest;
    _expectProviderDecisionField(
      errors,
      key,
      'profileName',
      decision.profileName,
      profile.name,
    );
    _expectProviderDecisionField(
      errors,
      key,
      'modelClass',
      decision.modelClass.name,
      profile.modelClass.name,
    );
    if (decision.isLocal != profile.isLocal) {
      errors.add(
        '$key providerDecision.isLocal is ${decision.isLocal}, '
        'expected ${profile.isLocal}',
      );
    }
    _expectProviderDecisionField(
      errors,
      key,
      'profileId',
      decision.profileId,
      expectedProfileId,
    );
    _expectProviderDecisionField(
      errors,
      key,
      'selectedModelConfigId',
      decision.selectedModelConfigId,
      expectedModelConfigId,
    );

    final candidateModelIds = decision.candidateModelConfigIds.toSet();
    if (!candidateModelIds.contains(decision.selectedModelConfigId)) {
      errors.add(
        '$key providerDecision.selectedModelConfigId '
        '${decision.selectedModelConfigId} is not in candidateModelConfigIds',
      );
    }
    final expectedCandidateIds = expected.modelRows
        .map((row) => row.id)
        .toSet();
    if (!const SetEquality<String>().equals(
      candidateModelIds,
      expectedCandidateIds,
    )) {
      errors.add(
        '$key providerDecision.candidateModelConfigIds are '
        '${_sorted(candidateModelIds)}, expected '
        '${_sorted(expectedCandidateIds)}',
      );
    }

    final decoyIds = decision.decoyModelConfigIds.toSet();
    final expectedDecoyIds = {expected.decoyDuplicateProviderNativeModel.id};
    if (!const SetEquality<String>().equals(decoyIds, expectedDecoyIds)) {
      errors.add(
        '$key providerDecision.decoyModelConfigIds are ${_sorted(decoyIds)}, '
        'expected ${_sorted(expectedDecoyIds)}',
      );
    }
    final legacyIds = decision.legacyModelConfigIds.toSet();
    final expectedLegacyIds = {
      expected.legacyVersionModel.id,
      expected.legacyTemplateModel.id,
    };
    if (!const SetEquality<String>().equals(legacyIds, expectedLegacyIds)) {
      errors.add(
        '$key providerDecision.legacyModelConfigIds are ${_sorted(legacyIds)}, '
        'expected ${_sorted(expectedLegacyIds)}',
      );
    }
    if (decoyIds.contains(decision.selectedModelConfigId)) {
      errors.add('$key providerDecision selected a decoy model row');
    }
    if (legacyIds.contains(decision.selectedModelConfigId)) {
      errors.add('$key providerDecision selected a legacy model row');
    }

    final providerIds = decision.candidateProviderIds.toSet();
    final expectedProviderIds = {
      expectedProviderId,
      expected.decoyProvider.id,
      expected.legacyProvider.id,
    };
    if (!const SetEquality<String>().equals(providerIds, expectedProviderIds)) {
      errors.add(
        '$key providerDecision.candidateProviderIds are '
        '${_sorted(providerIds)}, expected ${_sorted(expectedProviderIds)}',
      );
    }
    if (!providerIds.contains(decision.selectedProviderId)) {
      errors.add(
        '$key providerDecision.selectedProviderId '
        '${decision.selectedProviderId} is not in candidateProviderIds',
      );
    }
    _expectProviderDecisionField(
      errors,
      key,
      'selectedProviderId',
      decision.selectedProviderId,
      expectedProviderId,
    );
    if (profile.isLocal && decision.selectedProviderType != 'ollama') {
      errors.add(
        '$key providerDecision.selectedProviderType is '
        '${decision.selectedProviderType}, expected ollama for local profile',
      );
    }
    if (!profile.isLocal && decision.selectedProviderType == 'ollama') {
      errors.add(
        '$key providerDecision.selectedProviderType is ollama for frontier '
        'profile',
      );
    }
    _validateProviderType(
      decision.selectedProviderType,
      '$key providerDecision.selectedProviderType',
      errors,
    );
    _expectProviderDecisionField(
      errors,
      key,
      'selectedProviderType',
      decision.selectedProviderType,
      expectedProviderType,
    );
    if (decision.selectedProviderModelId.trim().isEmpty) {
      errors.add('$key providerDecision.selectedProviderModelId is empty');
    }
    _expectProviderDecisionField(
      errors,
      key,
      'selectedProviderModelId',
      decision.selectedProviderModelId,
      expectedProviderModelId,
    );
    _expectProviderDecisionBindingField(
      errors,
      key,
      'selectedProviderEndpointOrigin',
      decision.selectedProviderEndpointOrigin,
      expectedProviderEndpointOrigin,
    );
    _expectProviderDecisionBindingField(
      errors,
      key,
      'selectedProviderBaseUrlDigest',
      decision.selectedProviderBaseUrlDigest,
      expectedProviderBaseUrlDigest,
    );
    final selectedProviderBaseUrlDigest =
        decision.selectedProviderBaseUrlDigest;
    if (selectedProviderBaseUrlDigest != null &&
        !EvalProvenance.isDigest(selectedProviderBaseUrlDigest)) {
      errors.add(
        '$key providerDecision.selectedProviderBaseUrlDigest is not a '
        'sha256 digest',
      );
    }
    for (final envKey in decision.envPresence.keys) {
      if (envKey.trim().isEmpty) {
        errors.add('$key providerDecision.envPresence contains an empty key');
      }
    }

    final resolved = trace.output.resolvedModel;
    if (resolved == null) return;
    _expectResolvedField(
      errors,
      key,
      'profileId',
      resolved.profileId,
      decision.profileId,
    );
    _expectResolvedField(
      errors,
      key,
      'modelConfigId',
      resolved.modelConfigId,
      decision.selectedModelConfigId,
    );
    _expectResolvedField(
      errors,
      key,
      'providerModelId',
      resolved.providerModelId,
      decision.selectedProviderModelId,
    );
    _expectResolvedField(
      errors,
      key,
      'providerId',
      resolved.providerId,
      decision.selectedProviderId,
    );
    _expectResolvedField(
      errors,
      key,
      'providerType',
      resolved.providerType,
      decision.selectedProviderType,
    );
    _expectResolvedBindingField(
      errors,
      key,
      'providerEndpointOrigin',
      resolved.providerEndpointOrigin,
      decision.selectedProviderEndpointOrigin,
    );
    _expectResolvedBindingField(
      errors,
      key,
      'providerBaseUrlDigest',
      resolved.providerBaseUrlDigest,
      decision.selectedProviderBaseUrlDigest,
    );
  }

  static void _expectBindingTraceField(
    List<String> errors,
    String label,
    String field,
    String? actual,
    String expected,
  ) {
    if (actual == null || actual.trim().isEmpty) {
      errors.add('$label $field is missing');
      return;
    }
    if (field.endsWith('Digest') && !EvalProvenance.isDigest(actual)) {
      errors.add('$label $field is not a sha256 digest');
    }
    if (actual == expected) return;
    errors.add('$label $field is $actual, expected manifest binding $expected');
  }

  static void _expectResolvedBindingField(
    List<String> errors,
    String key,
    String field,
    String? actual,
    String? expected,
  ) {
    if (expected == null) return;
    if (actual == null || actual.trim().isEmpty) {
      errors.add('$key resolvedModel.$field is missing');
      return;
    }
    if (field.endsWith('Digest') && !EvalProvenance.isDigest(actual)) {
      errors.add('$key resolvedModel.$field is not a sha256 digest');
    }
    if (actual == expected) return;
    errors.add('$key resolvedModel.$field is $actual, expected $expected');
  }

  static void _expectProviderDecisionBindingField(
    List<String> errors,
    String key,
    String field,
    String? actual,
    String expected,
  ) {
    if (actual == null || actual.trim().isEmpty) {
      errors.add('$key providerDecision.$field is missing');
      return;
    }
    if (field.endsWith('Digest') && !EvalProvenance.isDigest(actual)) {
      errors.add('$key providerDecision.$field is not a sha256 digest');
    }
    if (actual == expected) return;
    errors.add('$key providerDecision.$field is $actual, expected $expected');
  }

  static void _expectResolvedField(
    List<String> errors,
    String key,
    String field,
    String actual,
    String expected,
  ) {
    if (actual == expected) return;
    errors.add('$key resolvedModel.$field is $actual, expected $expected');
  }

  static void _expectProviderDecisionField(
    List<String> errors,
    String key,
    String field,
    String actual,
    String expected,
  ) {
    if (actual == expected) return;
    errors.add(
      '$key providerDecision.$field is $actual, expected $expected',
    );
  }

  static void _expectManifestBindingField(
    List<String> errors,
    String label,
    String field,
    String actual,
    String expected,
  ) {
    if (actual == expected) return;
    errors.add('$label $field is $actual, expected $expected');
  }

  static String _sorted(Set<String> values) {
    return (values.toList()..sort()).join(', ');
  }

  static List<EvalCheck> _validateLevel1(
    EvalTrace trace,
    String key,
    List<String> errors, {
    required EvalScenario scenario,
    required EvalProfile profile,
  }) {
    final recomputed = runLevel1(
      scenario,
      trace.output,
      profile: profile,
    );
    final actual = trace.level1Checks;
    final duplicateNames = _duplicates(actual.map((c) => c.name).toList());
    for (final name in duplicateNames) {
      errors.add('$key has duplicate Level 1 check $name');
    }

    final expectedByName = <String, EvalCheck>{
      for (final check in recomputed) check.name: check,
    };
    final actualByName = <String, EvalCheck>{
      for (final check in actual) check.name: check,
    };
    for (final name in expectedByName.keys.toSet().difference(
      actualByName.keys.toSet(),
    )) {
      errors.add('$key missing Level 1 check $name');
    }
    for (final name in actualByName.keys.toSet().difference(
      expectedByName.keys.toSet(),
    )) {
      errors.add('$key has unexpected Level 1 check $name');
    }
    for (final name in expectedByName.keys) {
      final actualCheck = actualByName[name];
      if (actualCheck == null) continue;
      final expectedCheck = expectedByName[name]!;
      if (actualCheck.passed != expectedCheck.passed) {
        errors.add(
          '$key Level 1 check $name stored ${actualCheck.passed} '
          'but recomputed ${expectedCheck.passed}',
        );
      }
    }
    return recomputed;
  }

  static String _traceKey(EvalTrace trace) =>
      _key(trace.scenario.id, trace.profile.name, trace.trialIndex);

  static String _key(String scenarioId, String profileName, int trialIndex) =>
      '$scenarioId::$profileName::trial-$trialIndex';

  static String _stripSuffix(String value, String suffix) =>
      value.substring(0, value.length - suffix.length);

  static final _capabilityIdPattern = RegExp(
    r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$',
  );
}
