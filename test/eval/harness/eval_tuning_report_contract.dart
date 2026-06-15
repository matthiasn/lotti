import 'eval_provenance.dart';

abstract final class EvalTuningReportContract {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalTuningReport';
  static const nextExperimentPlanKind = 'lotti.evalTuningNextExperimentPlan';

  static void assertValid(Map<String, dynamic> report) {
    final issues = validate(report);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid tuning report contract:\n${issues.join('\n')}',
    );
  }

  static List<String> validate(Map<String, dynamic> report) {
    final issues = <String>[];
    _expectEquals(
      issues,
      report['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, report['kind'], kind, 'kind');
    _expectIsoDate(issues, report['generatedAt'], 'generatedAt');

    final run = _expectMap(issues, report['run'], 'run');
    final policy = _expectMap(issues, report['policy'], 'policy');
    final status = _expectMap(issues, report['status'], 'status');
    final coverage = _expectMap(issues, report['coverage'], 'coverage');
    final readiness = _expectMap(issues, report['readiness'], 'readiness');
    final outcomes = _expectMap(issues, report['outcomes'], 'outcomes');
    final calibration = _expectMap(
      issues,
      report['calibration'],
      'calibration',
    );
    final pairwise = _expectMap(issues, report['pairwise'], 'pairwise');
    final promotion = _expectMap(issues, report['promotion'], 'promotion');
    final nextPlan = _expectMap(
      issues,
      report['nextExperimentPlan'],
      'nextExperimentPlan',
    );

    _validateRun(issues, run);
    _validatePolicy(
      issues,
      policy,
      allowRedactedPayload: run?['protectedIdsRedacted'] == true,
    );
    _validateStatus(issues, status);
    _validateCoverage(issues, coverage);
    _validateReadiness(issues, readiness, policy);
    _validatePresenceSection(issues, calibration, 'calibration');
    _validatePresenceSection(issues, pairwise, 'pairwise');
    _validatePresenceSection(issues, promotion, 'promotion');
    _validateOutcomes(issues, outcomes);
    _validateGates(issues, report['gates']);
    _validateBlockedReasons(issues, report['blockedReasons']);
    _validateRecommendations(issues, report['recommendations']);
    _validateSlices(issues, report['useCaseModelSlices']);
    _validateNextPlan(issues, nextPlan, run);
    _validateSummaryConsistency(
      issues,
      status: status,
      coverage: coverage,
      readiness: readiness,
      nextPlan: nextPlan,
    );
    return issues;
  }

  static void _validateRun(List<String> issues, Map<String, dynamic>? run) {
    if (run == null) return;
    _expectNonEmptyString(issues, run['runId'], 'run.runId');
    _expectNonEmptyString(issues, run['targetKind'], 'run.targetKind');
    final manifestDigest = _expectDigest(
      issues,
      run['manifestDigest'],
      'run.manifestDigest',
    );
    _expectIsoDate(issues, run['createdAt'], 'run.createdAt');
    _expectDigest(issues, run['scenarioSetDigest'], 'run.scenarioSetDigest');
    _expectDigest(issues, run['profileSetDigest'], 'run.profileSetDigest');
    _expectDigest(
      issues,
      run['profileBindingSetDigest'],
      'run.profileBindingSetDigest',
    );
    _expectDigest(
      issues,
      run['agentDirectiveVariantSetDigest'],
      'run.agentDirectiveVariantSetDigest',
    );
    _expectBool(
      issues,
      run['protectedIdsRedacted'],
      'run.protectedIdsRedacted',
    );

    final selectors = _expectMap(issues, run['selectors'], 'run.selectors');
    if (selectors != null) {
      _expectStringList(
        issues,
        selectors['scenarioIds'],
        'run.selectors.scenarioIds',
      );
      _expectStringList(
        issues,
        selectors['profileNames'],
        'run.selectors.profileNames',
      );
      _expectStringList(
        issues,
        selectors['promptVariantNames'],
        'run.selectors.promptVariantNames',
      );
      _expectStringList(
        issues,
        selectors['requiredPrimaryCapabilityIds'],
        'run.selectors.requiredPrimaryCapabilityIds',
      );
    }

    final snapshot = _expectMap(
      issues,
      run['artifactSnapshot'],
      'run.artifactSnapshot',
    );
    if (snapshot == null) return;
    final artifactCount = _expectNonNegativeInt(
      issues,
      snapshot['artifactCount'],
      'run.artifactSnapshot.artifactCount',
    );
    final traceCount = _expectNonNegativeInt(
      issues,
      snapshot['traceCount'],
      'run.artifactSnapshot.traceCount',
    );
    final judgedTraceCount = _expectNonNegativeInt(
      issues,
      snapshot['judgedTraceCount'],
      'run.artifactSnapshot.judgedTraceCount',
    );
    final snapshotManifestDigest = _expectDigest(
      issues,
      snapshot['manifestDigest'],
      'run.artifactSnapshot.manifestDigest',
    );
    _expectDigest(
      issues,
      snapshot['ownedArtifactRefsDigest'],
      'run.artifactSnapshot.ownedArtifactRefsDigest',
    );
    _expectDigest(
      issues,
      snapshot['loadedTraceContentDigest'],
      'run.artifactSnapshot.loadedTraceContentDigest',
    );
    if (manifestDigest != null &&
        snapshotManifestDigest != null &&
        snapshotManifestDigest != manifestDigest) {
      issues.add(
        'run.artifactSnapshot.manifestDigest must match run.manifestDigest',
      );
    }
    if (traceCount != null &&
        judgedTraceCount != null &&
        judgedTraceCount > traceCount) {
      issues.add(
        'run.artifactSnapshot.judgedTraceCount must be <= traceCount',
      );
    }
    if (artifactCount != null &&
        traceCount != null &&
        judgedTraceCount != null &&
        artifactCount < 1 + traceCount + judgedTraceCount) {
      issues.add(
        'run.artifactSnapshot.artifactCount must be >= '
        '1 + traceCount + judgedTraceCount',
      );
    }
  }

  static void _validatePolicy(
    List<String> issues,
    Map<String, dynamic>? policy, {
    required bool allowRedactedPayload,
  }) {
    if (policy == null) return;
    _expectNonEmptyString(issues, policy['name'], 'policy.name');
    final digest = _expectDigest(issues, policy['digest'], 'policy.digest');
    final payload = _expectMap(issues, policy['payload'], 'policy.payload');
    if (!allowRedactedPayload &&
        digest != null &&
        payload != null &&
        EvalProvenance.digestJson(payload) != digest) {
      issues.add('policy.digest must match policy.payload');
    }
  }

  static void _validateStatus(
    List<String> issues,
    Map<String, dynamic>? status,
  ) {
    if (status == null) return;
    _expectBool(issues, status['ready'], 'status.ready');
    _expectNonEmptyString(issues, status['label'], 'status.label');
    _expectNonNegativeInt(
      issues,
      status['failureCount'],
      'status.failureCount',
    );
    _expectNonNegativeInt(
      issues,
      status['warningCount'],
      'status.warningCount',
    );
  }

  static void _validateCoverage(
    List<String> issues,
    Map<String, dynamic>? coverage,
  ) {
    if (coverage == null) return;
    final expectedTraceCount = _expectNonNegativeInt(
      issues,
      coverage['expectedTraceCount'],
      'coverage.expectedTraceCount',
    );
    final traceCount = _expectNonNegativeInt(
      issues,
      coverage['traceCount'],
      'coverage.traceCount',
    );
    final judgedTraceCount = _expectNonNegativeInt(
      issues,
      coverage['judgedTraceCount'],
      'coverage.judgedTraceCount',
    );
    _expectNonNegativeInt(
      issues,
      coverage['scenarioCount'],
      'coverage.scenarioCount',
    );
    _expectNonNegativeInt(
      issues,
      coverage['profileCount'],
      'coverage.profileCount',
    );
    _expectNonNegativeInt(
      issues,
      coverage['promptVariantCount'],
      'coverage.promptVariantCount',
    );
    _expectStringList(
      issues,
      coverage['missingRequiredPrimaryCapabilityIds'],
      'coverage.missingRequiredPrimaryCapabilityIds',
    );
    if (traceCount != null &&
        judgedTraceCount != null &&
        judgedTraceCount > traceCount) {
      issues.add('coverage.judgedTraceCount must be <= traceCount');
    }
    if (expectedTraceCount != null &&
        traceCount != null &&
        traceCount > expectedTraceCount) {
      issues.add('coverage.traceCount must be <= expectedTraceCount');
    }
  }

  static void _validateReadiness(
    List<String> issues,
    Map<String, dynamic>? readiness,
    Map<String, dynamic>? policy,
  ) {
    if (readiness == null) return;
    _expectBool(issues, readiness['ready'], 'readiness.ready');
    _expectNonEmptyString(
      issues,
      readiness['evidenceLabel'],
      'readiness.evidenceLabel',
    );
    _expectNonEmptyString(
      issues,
      readiness['policyName'],
      'readiness.policyName',
    );
    final readinessPolicyDigest = _expectDigest(
      issues,
      readiness['policyDigest'],
      'readiness.policyDigest',
    );
    final policyDigest = policy?['digest'];
    if (policyDigest is String &&
        readinessPolicyDigest != null &&
        readinessPolicyDigest != policyDigest) {
      issues.add('readiness.policyDigest must match policy.digest');
    }
    _expectNonNegativeInt(
      issues,
      readiness['expectedTraceCount'],
      'readiness.expectedTraceCount',
    );
    _expectNonNegativeInt(
      issues,
      readiness['traceCount'],
      'readiness.traceCount',
    );
    _expectNonNegativeInt(
      issues,
      readiness['judgedTraceCount'],
      'readiness.judgedTraceCount',
    );
    _expectStringList(issues, readiness['failures'], 'readiness.failures');
    _expectStringList(issues, readiness['warnings'], 'readiness.warnings');
    _expectStringList(
      issues,
      readiness['missingRequiredPrimaryCapabilityIds'],
      'readiness.missingRequiredPrimaryCapabilityIds',
    );
  }

  static void _validatePresenceSection(
    List<String> issues,
    Map<String, dynamic>? section,
    String path,
  ) {
    if (section == null) return;
    _expectBool(issues, section['present'], '$path.present');
    if (section.containsKey('status')) {
      _expectNonEmptyString(issues, section['status'], '$path.status');
    }
  }

  static void _validateOutcomes(
    List<String> issues,
    Map<String, dynamic>? outcomes,
  ) {
    if (outcomes == null) return;
    _expectMap(issues, outcomes['aggregate'], 'outcomes.aggregate');
    _expectList(issues, outcomes['slices'], 'outcomes.slices');
    _expectNonNegativeInt(
      issues,
      outcomes['failingTraceCount'],
      'outcomes.failingTraceCount',
    );
  }

  static void _validateGates(List<String> issues, Object? value) {
    final gates = _expectList(issues, value, 'gates');
    if (gates == null) return;
    for (var i = 0; i < gates.length; i++) {
      final gate = _expectMap(issues, gates[i], 'gates[$i]');
      if (gate == null) continue;
      _expectNonEmptyString(issues, gate['id'], 'gates[$i].id');
      final status = _expectNonEmptyString(
        issues,
        gate['status'],
        'gates[$i].status',
      );
      if (status != null && status != 'pass' && status != 'fail') {
        issues.add('gates[$i].status must be pass or fail');
      }
      _expectMap(issues, gate['scope'], 'gates[$i].scope');
      _expectNonEmptyString(
        issues,
        gate['comparator'],
        'gates[$i].comparator',
      );
      _expectStringList(
        issues,
        gate['evidenceRefs'],
        'gates[$i].evidenceRefs',
      );
      _expectNonEmptyString(
        issues,
        gate['blockerCode'],
        'gates[$i].blockerCode',
      );
    }
  }

  static void _validateBlockedReasons(List<String> issues, Object? value) {
    final reasons = _expectList(issues, value, 'blockedReasons');
    if (reasons == null) return;
    for (var i = 0; i < reasons.length; i++) {
      final reason = _expectMap(issues, reasons[i], 'blockedReasons[$i]');
      if (reason == null) continue;
      _expectNonEmptyString(issues, reason['code'], 'blockedReasons[$i].code');
      _expectNonEmptyString(
        issues,
        reason['severity'],
        'blockedReasons[$i].severity',
      );
      _expectNonEmptyString(
        issues,
        reason['message'],
        'blockedReasons[$i].message',
      );
      _expectNonEmptyString(
        issues,
        reason['nextAction'],
        'blockedReasons[$i].nextAction',
      );
      _expectMap(issues, reason['scope'], 'blockedReasons[$i].scope');
    }
  }

  static void _validateRecommendations(List<String> issues, Object? value) {
    final recommendations = _expectList(issues, value, 'recommendations');
    if (recommendations == null) return;
    for (var i = 0; i < recommendations.length; i++) {
      final recommendation = _expectMap(
        issues,
        recommendations[i],
        'recommendations[$i]',
      );
      if (recommendation == null) continue;
      _expectNonEmptyString(
        issues,
        recommendation['id'],
        'recommendations[$i].id',
      );
      _expectNonNegativeInt(
        issues,
        recommendation['priority'],
        'recommendations[$i].priority',
      );
      _expectNonEmptyString(
        issues,
        recommendation['action'],
        'recommendations[$i].action',
      );
      _expectNonEmptyString(
        issues,
        recommendation['status'],
        'recommendations[$i].status',
      );
      _expectMap(issues, recommendation['scope'], 'recommendations[$i].scope');
      _expectMap(
        issues,
        recommendation['selectors'],
        'recommendations[$i].selectors',
      );
      _expectStringList(
        issues,
        recommendation['blockedBy'],
        'recommendations[$i].blockedBy',
      );
      _expectStringList(
        issues,
        recommendation['rationaleCodes'],
        'recommendations[$i].rationaleCodes',
      );
    }
  }

  static void _validateSlices(List<String> issues, Object? value) {
    final slices = _expectList(issues, value, 'useCaseModelSlices');
    if (slices == null) return;
    for (var i = 0; i < slices.length; i++) {
      final slice = _expectMap(issues, slices[i], 'useCaseModelSlices[$i]');
      if (slice == null) continue;
      _expectNonEmptyString(
        issues,
        slice['primaryCapabilityId'],
        'useCaseModelSlices[$i].primaryCapabilityId',
      );
      _expectNonEmptyString(
        issues,
        slice['agentKind'],
        'useCaseModelSlices[$i].agentKind',
      );
      _expectNonEmptyString(
        issues,
        slice['modelClass'],
        'useCaseModelSlices[$i].modelClass',
      );
      _expectNonEmptyString(
        issues,
        slice['promptVariantName'],
        'useCaseModelSlices[$i].promptVariantName',
      );
      _expectStringList(
        issues,
        slice['blockingReasons'],
        'useCaseModelSlices[$i].blockingReasons',
      );
      _expectList(issues, slice['gates'], 'useCaseModelSlices[$i].gates');
    }
  }

  static void _validateNextPlan(
    List<String> issues,
    Map<String, dynamic>? plan,
    Map<String, dynamic>? run,
  ) {
    if (plan == null) return;
    _expectEquals(
      issues,
      plan['schemaVersion'],
      schemaVersion,
      'nextExperimentPlan.schemaVersion',
    );
    _expectEquals(
      issues,
      plan['kind'],
      nextExperimentPlanKind,
      'nextExperimentPlan.kind',
    );
    final baseRunId = _expectNonEmptyString(
      issues,
      plan['baseRunId'],
      'nextExperimentPlan.baseRunId',
    );
    final runId = run?['runId'];
    if (runId is String && baseRunId != null && baseRunId != runId) {
      issues.add('nextExperimentPlan.baseRunId must match run.runId');
    }
    _expectNonEmptyString(
      issues,
      plan['objective'],
      'nextExperimentPlan.objective',
    );
    final status = _expectNonEmptyString(
      issues,
      plan['status'],
      'nextExperimentPlan.status',
    );
    if (status != null && status != 'ready' && status != 'blocked') {
      issues.add('nextExperimentPlan.status must be ready or blocked');
    }
    for (final field in const [
      'blockedReasonCodes',
      'requiredCapabilities',
      'suggestedCapabilities',
      'suggestedScenarioIds',
      'suggestedProfileNames',
      'suggestedPromptVariantNames',
      'requiredPairwiseIntentKeys',
      'missingOrFailedPairwiseKeys',
    ]) {
      _expectStringList(issues, plan[field], 'nextExperimentPlan.$field');
    }
    _expectMap(issues, plan['nextRunEnv'], 'nextExperimentPlan.nextRunEnv');
    final commands = _expectList(
      issues,
      plan['recommendedCommands'],
      'nextExperimentPlan.recommendedCommands',
    );
    if (commands == null) return;
    for (var i = 0; i < commands.length; i++) {
      final command = _expectMap(
        issues,
        commands[i],
        'nextExperimentPlan.recommendedCommands[$i]',
      );
      if (command == null) continue;
      _expectNonEmptyString(
        issues,
        command['mode'],
        'nextExperimentPlan.recommendedCommands[$i].mode',
      );
      _expectNonEmptyString(
        issues,
        command['command'],
        'nextExperimentPlan.recommendedCommands[$i].command',
      );
    }
  }

  static void _validateSummaryConsistency(
    List<String> issues, {
    required Map<String, dynamic>? status,
    required Map<String, dynamic>? coverage,
    required Map<String, dynamic>? readiness,
    required Map<String, dynamic>? nextPlan,
  }) {
    if (status != null && readiness != null) {
      if (status['ready'] is bool &&
          readiness['ready'] is bool &&
          status['ready'] != readiness['ready']) {
        issues.add('status.ready must match readiness.ready');
      }
      if (status['label'] is String &&
          readiness['evidenceLabel'] is String &&
          status['label'] != readiness['evidenceLabel']) {
        issues.add('status.label must match readiness.evidenceLabel');
      }
      final failures = readiness['failures'];
      if (status['failureCount'] is int && failures is List) {
        final failureCount = status['failureCount'] as int;
        if (failureCount != failures.length) {
          issues.add('status.failureCount must match readiness.failures');
        }
      }
      final warnings = readiness['warnings'];
      if (status['warningCount'] is int && warnings is List) {
        final warningCount = status['warningCount'] as int;
        if (warningCount != warnings.length) {
          issues.add('status.warningCount must match readiness.warnings');
        }
      }
    }
    if (coverage != null && readiness != null) {
      for (final field in const [
        'expectedTraceCount',
        'traceCount',
        'judgedTraceCount',
        'missingRequiredPrimaryCapabilityIds',
      ]) {
        if (coverage[field].toString() != readiness[field].toString()) {
          issues.add('coverage.$field must match readiness.$field');
        }
      }
    }
    if (nextPlan != null && readiness != null) {
      final ready = readiness['ready'];
      final status = nextPlan['status'];
      if (ready is bool &&
          status is String &&
          (ready ? 'ready' : 'blocked') != status) {
        issues.add('nextExperimentPlan.status must match readiness.ready');
      }
    }
  }

  static Map<String, dynamic>? _expectMap(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map<String, dynamic>) return value;
    issues.add('$path must be an object');
    return null;
  }

  static List<dynamic>? _expectList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is List) return value;
    issues.add('$path must be a list');
    return null;
  }

  static String? _expectNonEmptyString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! String) {
      issues.add('$path must be a string');
      return null;
    }
    if (value.trim().isEmpty) {
      issues.add('$path must not be empty');
      return null;
    }
    return value;
  }

  static void _expectStringList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    final list = _expectList(issues, value, path);
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      if (list[i] is! String) issues.add('$path[$i] must be a string');
    }
  }

  static int? _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! int) {
      issues.add('$path must be an integer');
      return null;
    }
    if (value < 0) {
      issues.add('$path must be non-negative');
      return null;
    }
    return value;
  }

  static void _expectBool(List<String> issues, Object? value, String path) {
    if (value is! bool) issues.add('$path must be a boolean');
  }

  static String? _expectDigest(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! String || !EvalProvenance.isDigest(value)) {
      issues.add('$path must be a sha256 digest');
      return null;
    }
    return value;
  }

  static void _expectIsoDate(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! String || DateTime.tryParse(value) == null) {
      issues.add('$path must be an ISO-8601 timestamp');
    }
  }

  static void _expectEquals(
    List<String> issues,
    Object? actual,
    Object expected,
    String path,
  ) {
    if (actual != expected) {
      issues.add('$path must be $expected');
    }
  }
}
