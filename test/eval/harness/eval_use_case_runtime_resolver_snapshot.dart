import 'eval_provenance.dart';
import 'eval_use_case_runtime_verification.dart';
import 'eval_use_case_tuning_release_gate.dart';
import 'eval_use_case_tuning_release_plan.dart';

abstract final class EvalUseCaseRuntimeResolverSnapshot {
  static const packetSchemaVersion = 1;
  static const packetKind = 'lotti.evalUseCaseRuntimeResolverPacket';
  static const directObservationSourceSchemaVersion = 1;
  static const directObservationSourceKind =
      'lotti.evalUseCaseRuntimeDirectObservationSource';
  static final Expando<String> _verifiedPacketSourceDigests = Expando<String>(
    'verifiedRuntimeResolverPacketSourceDigest',
  );
  static final Expando<String> _verifiedSnapshotSourceDigests = Expando<String>(
    'verifiedRuntimeResolverSnapshotSourceDigest',
  );
  static const _approvedGateStatus = 'approvedForManualApply';
  static const _allowedPacketStatuses = {
    'invalidReleasePlan',
    'invalidReleaseGate',
    'blockedReleaseGate',
    'noRuntimeBindings',
    'readyForRuntimeResolution',
  };
  static const _productionAgentKinds = <String, String>{
    'taskAgent': 'task_agent',
    'planningAgent': 'day_agent',
  };
  static const runtimeDigestFields = [
    'resolvedProfileDigest',
    'providerModelBindingDigest',
    'thinkingModelBindingDigest',
    'promptVariantDigest',
    'promptDirectiveDigest',
  ];
  static const _allowedResolutionStatuses = {
    'applied',
    'notApplied',
    'partiallyApplied',
    'drift',
    'unsupported',
    'unknown',
  };
  static const runtimeObservationModeManualCompletedBindingImport =
      'manualCompletedBindingImport';
  static const runtimeObservationModeDirectRuntimeObservation =
      'directRuntimeObservation';
  static const runtimeObservationModePrivateRuntimeStateLocator =
      'privateRuntimeStateLocator';
  static const _directObservationSourceKeys = {
    'schemaVersion',
    'kind',
    'directObservationSourceRef',
    'observedAt',
    'sourceReleasePlanDigest',
    'sourceReleaseGateRef',
    'sourceReleaseGateDigest',
    'sourceResolverPacketDigest',
    'runtimeObservationSource',
    'runtimeObservationSourceDigest',
    'summary',
    'privacy',
    'limitations',
    'completedBindings',
  };

  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=|file://)/(?:Users|home|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+|'
    r'EVAL_USE_CASE_[A-Z0-9_]+)\b',
  );
  static final _scenarioFieldTokenPattern = RegExp(
    r'\b(?:scenarioId|scenarioIds|[A-Za-z0-9_]*ScenarioIds)\b',
  );
  static final _profileFieldTokenPattern = RegExp(
    r'\b(?:profileName|profileNames|[A-Za-z0-9_]*ProfileNames)\b',
  );
  static final _rawPromptFieldTokenPattern = RegExp(
    r'\b(?:rawPrompt|rawPrompts|promptText|systemPrompt|directiveText|'
    r'rawDirective|rawDirectives)\b',
  );
  static final _liveRunLevel2CommandPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:\./)?eval/run_level2\.sh\s+'
    r'(?:plan|run|tune|all)(?=$|[^A-Za-z0-9_-])',
  );
  static final _dangerousCommandTokenPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:bash\s+-lc|fvm\s+flutter|'
    r'fvm\s+dart|dart\s+run|sqlite3|TaskAgentService\.updateAgentProfile|'
    r'AgentTemplateService\.(?:update|save)|AiConfigRepository\.(?:save|update))'
    r'(?=$|[^A-Za-z0-9_-])',
  );
  static final _publicTokenPattern = RegExp(r'^[A-Za-z0-9._:@+-]{1,96}$');

  static Map<String, dynamic> buildPacket({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    DateTime? generatedAt,
  }) {
    final releasePlanIssues = sourceRoadmap == null
        ? EvalUseCaseTuningReleasePlan.validate(releasePlan)
        : EvalUseCaseTuningReleasePlan.validateAgainstSources(
            releasePlan,
            roadmap: sourceRoadmap,
            sourceDecisionLedgers: sourceDecisionLedgers,
            sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
            previousReleasePlan: previousReleasePlan,
            requireDecisionLedgerSourceReplay: sourceDecisionLedgers.isNotEmpty,
          );
    final baseReleaseGateIssues = releaseReviewBundles.isEmpty
        ? EvalUseCaseTuningReleaseGate.validateAgainstReleasePlan(
            releaseGate,
            releasePlan: releasePlan,
            sourceRoadmap: sourceRoadmap,
            sourceDecisionLedgers: sourceDecisionLedgers,
            sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
            previousReleasePlan: previousReleasePlan,
          )
        : EvalUseCaseTuningReleaseGate.validateAgainstSources(
            releaseGate,
            releasePlan: releasePlan,
            releaseReviewBundles: releaseReviewBundles,
            sourceRoadmap: sourceRoadmap,
            sourceDecisionLedgers: sourceDecisionLedgers,
            sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
            previousReleasePlan: previousReleasePlan,
          );
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final releaseGateDigest = EvalProvenance.digestJson(releaseGate);
    final releaseGateRef = _string(releaseGate['releaseGateRef']);
    final releaseGateStatus = _nonEmptyOrUnknown(releaseGate['status']);
    final releaseGateReviewSourcesVerified =
        releaseGateStatus != _approvedGateStatus ||
        EvalUseCaseTuningReleaseGate.hasVerifiedReleaseReviewSources(
          releaseGate,
        ) ||
        (releaseReviewBundles.isNotEmpty && baseReleaseGateIssues.isEmpty);
    final releaseGateIssues = [
      ...baseReleaseGateIssues,
      if (releaseGateStatus == _approvedGateStatus &&
          baseReleaseGateIssues.isEmpty &&
          !releaseGateReviewSourcesVerified)
        'releaseGate review sources must be verified',
    ];
    final approvedAssignmentRefs = _approvedAssignmentRefs(releaseGate);
    final approvedAssignmentRefsDigest = EvalProvenance.digestJson(
      approvedAssignmentRefs,
    );
    final releasePlanAssignmentRefs = [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        _string(assignment['assignmentRef']),
    ]..sort();
    final releasePlanAssignmentRefsDigest = EvalProvenance.digestJson(
      releasePlanAssignmentRefs,
    );
    final modelClassCoverageProofSummaryDigest = _string(
      _map(
        releasePlan['modelClassCoverageProofSummary'],
      )['proofSummaryDigest'],
    );
    final releaseGateProofSummaryDigest = _string(
      _map(
        releaseGate['sourceReleasePlan'],
      )['modelClassCoverageProofSummaryDigest'],
    );
    final expectedAssignments = _expectedAssignments(
      releasePlan: releasePlan,
      approvedAssignmentRefs: approvedAssignmentRefs,
    );
    final releaseGateSourceMatches =
        releaseGateIssues.isEmpty &&
        _string(_map(releaseGate['sourceReleasePlan'])['releasePlanDigest']) ==
            releasePlanDigest &&
        _string(
              _map(releaseGate['sourceReleasePlan'])['assignmentRefsDigest'],
            ) ==
            releasePlanAssignmentRefsDigest &&
        releaseGateProofSummaryDigest == modelClassCoverageProofSummaryDigest;
    final releaseGateApprovesAssignments =
        releaseGateStatus == _approvedGateStatus &&
        approvedAssignmentRefsDigest == releasePlanAssignmentRefsDigest;
    final sourceReady =
        releasePlanIssues.isEmpty &&
        releaseGateIssues.isEmpty &&
        releaseGateSourceMatches &&
        releaseGateApprovesAssignments;
    final requiredBindings = [
      if (sourceReady)
        for (final assignment in expectedAssignments)
          _requiredBinding(
            assignment: assignment,
            releasePlanDigest: releasePlanDigest,
            releaseGateRef: releaseGateRef,
            releaseGateDigest: releaseGateDigest,
            approvedAssignmentRefsDigest: approvedAssignmentRefsDigest,
            modelClassCoverageProofSummaryDigest:
                modelClassCoverageProofSummaryDigest,
          ),
    ];
    final status = releasePlanIssues.isNotEmpty
        ? 'invalidReleasePlan'
        : releaseGateIssues.isNotEmpty || !releaseGateSourceMatches
        ? 'invalidReleaseGate'
        : releaseGateStatus != _approvedGateStatus
        ? 'blockedReleaseGate'
        : !releaseGateApprovesAssignments
        ? 'invalidReleaseGate'
        : requiredBindings.isEmpty
        ? 'noRuntimeBindings'
        : 'readyForRuntimeResolution';
    final packet = <String, dynamic>{
      'schemaVersion': packetSchemaVersion,
      'kind': packetKind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceReleasePlan': <String, dynamic>{
        'kind': EvalUseCaseTuningReleasePlan.kind,
        'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
        'status': _nonEmptyOrUnknown(releasePlan['status']),
        'releasePlanRef': _string(releasePlan['releasePlanRef']),
        'releasePlanDigest': releasePlanDigest,
        'modelClassCoverageProofSummaryDigest':
            modelClassCoverageProofSummaryDigest,
        'contractIssueCount': releasePlanIssues.length,
        'assignmentCount': _mapList(releasePlan['runtimeAssignments']).length,
      },
      'sourceReleaseGate': <String, dynamic>{
        'kind': EvalUseCaseTuningReleaseGate.kind,
        'schemaVersion': EvalUseCaseTuningReleaseGate.schemaVersion,
        'status': releaseGateStatus,
        'releaseGateRef': releaseGateRef,
        'releaseGateDigest': releaseGateDigest,
        'sourceReleasePlanDigest': _string(
          _map(releaseGate['sourceReleasePlan'])['releasePlanDigest'],
        ),
        'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
        'modelClassCoverageProofSummaryDigest': releaseGateProofSummaryDigest,
        'contractIssueCount': releaseGateIssues.length,
        'approvedAssignmentRefCount': approvedAssignmentRefs.length,
      },
      'summary': <String, dynamic>{
        'requiredRuntimeBindingCount': requiredBindings.length,
        'bindingTemplateCount': sourceReady ? requiredBindings.length : 0,
        'releasePlanContractIssueCount': releasePlanIssues.length,
        'releaseGateContractIssueCount': releaseGateIssues.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'localConfigIdsOmitted': true,
        'privateRuntimeIdsOmitted': true,
        'providerBaseUrlsOmitted': true,
        'apiKeysOmitted': true,
        'rawPromptTextOmitted': true,
        'rawDirectiveTextOmitted': true,
        'sourceArtifactPathsOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesReleasePlanGateAndReviewEvidence': true,
        'runtimeStateObserved': false,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
        'liveCommandsCreated': false,
      },
      'requiredRuntimeBindings': requiredBindings,
      'bindingTemplates': [
        for (final binding in requiredBindings) _bindingTemplate(binding),
      ],
      'issues': [
        for (final issue in releasePlanIssues)
          <String, dynamic>{
            'code': 'runtimeResolver.releasePlanContractInvalid',
            'severity': 'blocking',
            'message': issue,
          },
        for (final issue in releaseGateIssues)
          <String, dynamic>{
            'code': 'runtimeResolver.releaseGateContractInvalid',
            'severity': 'blocking',
            'message': issue,
          },
        if (releaseGateIssues.isEmpty && !releaseGateSourceMatches)
          const <String, dynamic>{
            'code': 'runtimeResolver.releaseGateSourceMismatch',
            'severity': 'blocking',
          },
        if (releaseGateIssues.isEmpty &&
            releaseGateSourceMatches &&
            releaseGateStatus != _approvedGateStatus)
          <String, dynamic>{
            'code': 'runtimeResolver.releaseGateNotApproved',
            'severity': 'blocking',
            'releaseGateStatus': releaseGateStatus,
          },
        if (releaseGateIssues.isEmpty &&
            releaseGateSourceMatches &&
            releaseGateStatus == _approvedGateStatus &&
            !releaseGateApprovesAssignments)
          const <String, dynamic>{
            'code': 'runtimeResolver.releaseGateApprovedAssignmentRefsMismatch',
            'severity': 'blocking',
          },
      ],
      'recommendedCommands': _recommendedCommands(),
    };
    assertValidPacket(packet);
    _markVerifiedPacketSources(packet);
    return packet;
  }

  static bool hasVerifiedPacketSources(Map<String, dynamic> packet) =>
      _verifiedPacketSourceDigests[packet] == EvalProvenance.digestJson(packet);

  static List<String> validatePacket(Map<String, dynamic> packet) {
    final issues = <String>[];
    _expectEquals(
      issues,
      packet['schemaVersion'],
      packetSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, packet['kind'], packetKind, 'kind');
    _expectIsoDate(issues, packet['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, packet['status'], 'status');
    if (status != null && !_allowedPacketStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedPacketStatuses.join(', ')}');
    }
    final sourceReleasePlan = _expectMap(
      issues,
      packet['sourceReleasePlan'],
      'sourceReleasePlan',
    );
    _validateSource(issues, sourceReleasePlan, 'sourceReleasePlan');
    final sourceReleaseGate = _expectMap(
      issues,
      packet['sourceReleaseGate'],
      'sourceReleaseGate',
    );
    _validateSource(issues, sourceReleaseGate, 'sourceReleaseGate');
    _validatePacketSummary(
      issues,
      _expectMap(issues, packet['summary'], 'summary'),
    );
    _validatePacketPrivacy(
      issues,
      _expectMap(issues, packet['privacy'], 'privacy'),
    );
    _validatePacketLimitations(
      issues,
      _expectMap(issues, packet['limitations'], 'limitations'),
    );
    final requiredBindings = _expectList(
      issues,
      packet['requiredRuntimeBindings'],
      'requiredRuntimeBindings',
    );
    _validateRequiredBindings(
      issues,
      requiredBindings,
      'requiredRuntimeBindings',
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseGate: sourceReleaseGate,
    );
    final templates = _expectList(
      issues,
      packet['bindingTemplates'],
      'bindingTemplates',
    );
    _validateBindingTemplates(
      issues,
      templates,
      'bindingTemplates',
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseGate: sourceReleaseGate,
    );
    final packetIssues = _expectList(issues, packet['issues'], 'issues');
    _validatePacketSummaryInvariants(
      issues,
      status: status,
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseGate: sourceReleaseGate,
      summary: _map(packet['summary']),
      requiredBindings: requiredBindings,
      templates: templates,
      issuesList: packetIssues,
    );
    _validateBindingTemplateCoverage(
      issues,
      requiredBindings: requiredBindings,
      templates: templates,
    );
    _validateIssues(issues, packetIssues);
    _validateCommands(
      issues,
      _expectList(issues, packet['recommendedCommands'], 'recommendedCommands'),
      'recommendedCommands',
      expectedCommands: _recommendedCommands(),
    );
    _validateNoPrivatePayloads(issues, packet, 'packet');
    return issues;
  }

  static void assertValidPacket(Map<String, dynamic> packet) {
    final issues = validatePacket(packet);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case runtime resolver packet:\n${issues.join('\n')}',
    );
  }

  static List<String> validatePacketAgainstSources(
    Map<String, dynamic> packet, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validatePacket(packet);
    final generatedAt = DateTime.tryParse(_string(packet['generatedAt']));
    if (generatedAt == null) {
      issues.add('generatedAt must be an ISO-8601 timestamp');
      return issues;
    }
    Map<String, dynamic> expected;
    try {
      expected = buildPacket(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceRoadmap,
        sourceDecisionLedgers: sourceDecisionLedgers,
        sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
        previousReleasePlan: previousReleasePlan,
        generatedAt: generatedAt,
      );
    } catch (error) {
      issues.add(
        'source artifacts cannot build runtime resolver packet: $error',
      );
      return issues;
    }
    if (EvalProvenance.digestJson(packet) !=
        EvalProvenance.digestJson(expected)) {
      issues.add('runtime resolver packet must match source artifacts');
    }
    return issues;
  }

  static void assertPacketMatchesSources(
    Map<String, dynamic> packet, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validatePacketAgainstSources(
      packet,
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      releaseReviewBundles: releaseReviewBundles,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    if (issues.isEmpty) {
      _markVerifiedPacketSources(packet);
      return;
    }
    throw StateError(
      'Invalid use-case runtime resolver packet source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static void _markVerifiedPacketSources(Map<String, dynamic> packet) {
    _verifiedPacketSourceDigests[packet] = EvalProvenance.digestJson(packet);
  }

  static Map<String, dynamic>
  runtimeObservationSourceForManualCompletedBindingImport({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    DateTime? generatedAt,
  }) {
    final resolverPacket = buildPacket(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      generatedAt: generatedAt,
    );
    return runtimeObservationSourceFromResolverPacket(
      resolverPacket: resolverPacket,
      mode: runtimeObservationModeManualCompletedBindingImport,
    );
  }

  static Map<String, dynamic> runtimeObservationSourceForDirectObservation({
    required Map<String, dynamic> resolverPacket,
  }) => runtimeObservationSourceFromResolverPacket(
    resolverPacket: resolverPacket,
    mode: runtimeObservationModeDirectRuntimeObservation,
  );

  static Map<String, dynamic> buildDirectObservationSource({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> resolverPacket,
    required List<Map<String, dynamic>> completedBindings,
    DateTime? observedAt,
  }) {
    if (!hasVerifiedPacketSources(resolverPacket)) {
      throw StateError(
        'Direct runtime observation source requires verified packet sources.',
      );
    }
    final observedAtUtc = (observedAt ?? DateTime.now().toUtc()).toUtc();
    final runtimeObservationSource =
        runtimeObservationSourceForDirectObservation(
          resolverPacket: resolverPacket,
        );
    buildSnapshot(
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      completedBindings: completedBindings,
      runtimeObservationSource: runtimeObservationSource,
      capturedAt: observedAtUtc,
    );
    final source = <String, dynamic>{
      'schemaVersion': directObservationSourceSchemaVersion,
      'kind': directObservationSourceKind,
      'directObservationSourceRef': '',
      'observedAt': observedAtUtc.toIso8601String(),
      'sourceReleasePlanDigest': EvalProvenance.digestJson(releasePlan),
      'sourceReleaseGateRef': _string(releaseGate['releaseGateRef']),
      'sourceReleaseGateDigest': EvalProvenance.digestJson(releaseGate),
      'sourceResolverPacketDigest': EvalProvenance.digestJson(resolverPacket),
      'runtimeObservationSource': runtimeObservationSource,
      'runtimeObservationSourceDigest': EvalProvenance.digestJson(
        runtimeObservationSource,
      ),
      'summary': <String, dynamic>{
        'completedBindingCount': completedBindings.length,
      },
      'privacy': const <String, dynamic>{
        'privateRuntimeIdsAllowed': true,
        'rawPromptsOmitted': true,
        'rawDirectivesOmitted': true,
        'apiKeysOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'runtimeStateObservedOnly': true,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
        'liveCommandsCreated': false,
      },
      'completedBindings': [
        for (final binding in completedBindings)
          Map<String, dynamic>.of(binding),
      ],
    };
    source['directObservationSourceRef'] = directObservationSourceRef(source);
    assertValidDirectObservationSource(source);
    return source;
  }

  static String directObservationSourceRef(Map<String, dynamic> source) =>
      EvalProvenance.digestJson(<String, dynamic>{
        'kind': directObservationSourceKind,
        'schemaVersion': directObservationSourceSchemaVersion,
        'observedAt': source['observedAt'],
        'sourceReleasePlanDigest': source['sourceReleasePlanDigest'],
        'sourceReleaseGateRef': source['sourceReleaseGateRef'],
        'sourceReleaseGateDigest': source['sourceReleaseGateDigest'],
        'sourceResolverPacketDigest': source['sourceResolverPacketDigest'],
        'runtimeObservationSourceDigest':
            source['runtimeObservationSourceDigest'],
        'summary': source['summary'],
        'privacyDigest': EvalProvenance.digestJson(_map(source['privacy'])),
        'limitationsDigest': EvalProvenance.digestJson(
          _map(source['limitations']),
        ),
        'completedBindingsDigest': EvalProvenance.digestJson(
          _mapList(source['completedBindings']),
        ),
      });

  static List<String> validateDirectObservationSource(
    Map<String, dynamic> source,
  ) {
    final issues = <String>[];
    _expectOnlyKeys(
      issues,
      source,
      _directObservationSourceKeys,
      'directObservationSource',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      directObservationSourceSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, source['kind'], directObservationSourceKind, 'kind');
    _expectIsoDate(issues, source['observedAt'], 'observedAt');
    _expectDigest(
      issues,
      source['directObservationSourceRef'],
      'directObservationSourceRef',
    );
    _expectDigest(
      issues,
      source['sourceReleasePlanDigest'],
      'sourceReleasePlanDigest',
    );
    _expectNonEmptyString(
      issues,
      source['sourceReleaseGateRef'],
      'sourceReleaseGateRef',
    );
    _expectDigest(
      issues,
      source['sourceReleaseGateDigest'],
      'sourceReleaseGateDigest',
    );
    _expectDigest(
      issues,
      source['sourceResolverPacketDigest'],
      'sourceResolverPacketDigest',
    );
    final runtimeObservationSource = _expectMap(
      issues,
      source['runtimeObservationSource'],
      'runtimeObservationSource',
    );
    if (_string(runtimeObservationSource?['mode']) !=
        runtimeObservationModeDirectRuntimeObservation) {
      issues.add(
        'runtimeObservationSource.mode must be $runtimeObservationModeDirectRuntimeObservation',
      );
    }
    final runtimeObservationSourceDigest = EvalProvenance.digestJson(
      runtimeObservationSource,
    );
    if (_string(source['runtimeObservationSourceDigest']) !=
        runtimeObservationSourceDigest) {
      issues.add(
        'runtimeObservationSourceDigest must match runtimeObservationSource',
      );
    }
    final bindings = _mapList(source['completedBindings']);
    for (final (index, binding) in bindings.indexed) {
      _validateCompletedBinding(
        issues,
        binding,
        'completedBindings[$index]',
      );
    }
    final summary = _expectMap(issues, source['summary'], 'summary');
    if (summary != null &&
        summary['completedBindingCount'] is int &&
        summary['completedBindingCount'] != bindings.length) {
      issues.add(
        'summary.completedBindingCount must match completedBindings.length',
      );
    }
    _validateDirectObservationSourcePrivacy(
      issues,
      _expectMap(issues, source['privacy'], 'privacy'),
    );
    _validateDirectObservationSourceLimitations(
      issues,
      _expectMap(issues, source['limitations'], 'limitations'),
    );
    if (_string(source['directObservationSourceRef']) !=
        directObservationSourceRef(source)) {
      issues.add(
        'directObservationSourceRef must match direct observation source subject digest',
      );
    }
    _validateNoPrivatePayloads(
      issues,
      source,
      'directObservationSource',
      allowPrivateRuntimeIds: true,
    );
    return issues;
  }

  static void assertValidDirectObservationSource(Map<String, dynamic> source) {
    final issues = validateDirectObservationSource(source);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case runtime direct observation source:\n'
      '${issues.join('\n')}',
    );
  }

  static List<String> validateDirectObservationSourceAgainstSources(
    Map<String, dynamic> source, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> resolverPacket,
  }) {
    final issues = validateDirectObservationSource(source);
    if (!hasVerifiedPacketSources(resolverPacket)) {
      issues.add('source runtime resolver packet sources must be verified');
    }
    final observedAt = DateTime.tryParse(_string(source['observedAt']));
    if (issues.isNotEmpty || observedAt == null) {
      return issues;
    }
    Map<String, dynamic> expected;
    try {
      expected = buildDirectObservationSource(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        resolverPacket: resolverPacket,
        completedBindings: _mapList(source['completedBindings']),
        observedAt: observedAt,
      );
    } catch (error) {
      issues.add(
        'source artifacts cannot build direct observation source: $error',
      );
      return issues;
    }
    if (EvalProvenance.digestJson(source) !=
        EvalProvenance.digestJson(expected)) {
      issues.add('direct observation source must match source artifacts');
    }
    return issues;
  }

  static void assertDirectObservationSourceMatchesSources(
    Map<String, dynamic> source, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> resolverPacket,
  }) {
    final issues = validateDirectObservationSourceAgainstSources(
      source,
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      resolverPacket: resolverPacket,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid direct observation source binding:\n${issues.join('\n')}',
    );
  }

  static Map<String, dynamic>
  runtimeObservationSourceForPrivateRuntimeStateLocator({
    required Map<String, dynamic> resolverPacket,
    required Map<String, dynamic> locatorPacket,
  }) {
    final source = runtimeObservationSourceFromResolverPacket(
      resolverPacket: resolverPacket,
      mode: runtimeObservationModePrivateRuntimeStateLocator,
    );
    final locatorSource = _map(locatorPacket['sourceResolverPacket']);
    final locatorRequiredRefs = _stringList(
      locatorPacket['requiredAssignmentRefs'],
    )..sort();
    return <String, dynamic>{
      ...source,
      'sourceLocatorPacketDigest': EvalProvenance.digestJson(locatorPacket),
      'sourceLocatorPacketRef': _string(locatorPacket['locatorPacketRef']),
      'sourceLocatorPacketRequiredAssignmentRefsDigest':
          _string(locatorSource['requiredAssignmentRefsDigest']).isNotEmpty
          ? _string(locatorSource['requiredAssignmentRefsDigest'])
          : EvalProvenance.digestJson(locatorRequiredRefs),
      'sourceLocatorPacketLocatorCount': _mapList(
        locatorPacket['locators'],
      ).length,
    };
  }

  static Map<String, dynamic> runtimeObservationSourceFromResolverPacket({
    required Map<String, dynamic> resolverPacket,
    required String mode,
  }) {
    assertValidPacket(resolverPacket);
    final assignmentRefs = [
      for (final template in _mapList(resolverPacket['bindingTemplates']))
        _string(template['assignmentRef']),
    ]..sort();
    final sourcePlan = _map(resolverPacket['sourceReleasePlan']);
    final sourceGate = _map(resolverPacket['sourceReleaseGate']);
    return <String, dynamic>{
      'mode': mode,
      'sourceResolverPacketDigest': EvalProvenance.digestJson(resolverPacket),
      'sourceResolverPacketStatus': _nonEmptyOrUnknown(
        resolverPacket['status'],
      ),
      'sourceResolverPacketSourceReleasePlanDigest': _string(
        sourcePlan['releasePlanDigest'],
      ),
      'sourceResolverPacketSourceReleaseGateRef': _string(
        sourceGate['releaseGateRef'],
      ),
      'sourceResolverPacketSourceReleaseGateDigest': _string(
        sourceGate['releaseGateDigest'],
      ),
      'sourceResolverPacketApprovedAssignmentRefsDigest': _string(
        sourceGate['approvedAssignmentRefsDigest'],
      ),
      'sourceResolverPacketModelClassCoverageProofSummaryDigest': _string(
        sourcePlan['modelClassCoverageProofSummaryDigest'],
      ),
      'sourceResolverPacketRequiredAssignmentRefsDigest':
          EvalProvenance.digestJson(assignmentRefs),
      'sourceResolverPacketRequiredBindingCount': assignmentRefs.length,
    };
  }

  static Map<String, dynamic> buildSnapshot({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required List<Map<String, dynamic>> completedBindings,
    Map<String, dynamic>? runtimeObservationSource,
    DateTime? capturedAt,
  }) {
    final capturedAtUtc = (capturedAt ?? DateTime.now().toUtc()).toUtc();
    final releasePlanIssues = EvalUseCaseTuningReleasePlan.validate(
      releasePlan,
    );
    final releaseGateIssues =
        EvalUseCaseTuningReleaseGate.validateAgainstReleasePlan(
          releaseGate,
          releasePlan: releasePlan,
        );
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final releaseGateDigest = EvalProvenance.digestJson(releaseGate);
    final releaseGateRef = _string(releaseGate['releaseGateRef']);
    final releaseGateStatus = _nonEmptyOrUnknown(releaseGate['status']);
    final approvedAssignmentRefs = _approvedAssignmentRefs(releaseGate);
    final approvedAssignmentRefsDigest = EvalProvenance.digestJson(
      approvedAssignmentRefs,
    );
    final releasePlanAssignmentRefs = [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        _string(assignment['assignmentRef']),
    ]..sort();
    final releasePlanAssignmentRefsDigest = EvalProvenance.digestJson(
      releasePlanAssignmentRefs,
    );
    final modelClassCoverageProofSummaryDigest = _string(
      _map(
        releasePlan['modelClassCoverageProofSummary'],
      )['proofSummaryDigest'],
    );
    final expectedAssignments = _expectedAssignments(
      releasePlan: releasePlan,
      approvedAssignmentRefs: approvedAssignmentRefs,
    );
    final importIssues = _snapshotImportIssues(
      releasePlanIssues: releasePlanIssues,
      releaseGateIssues: releaseGateIssues,
      releasePlanDigest: releasePlanDigest,
      releaseGateDigest: releaseGateDigest,
      releaseGateRef: releaseGateRef,
      releaseGateStatus: releaseGateStatus,
      approvedAssignmentRefsDigest: approvedAssignmentRefsDigest,
      releasePlanAssignmentRefsDigest: releasePlanAssignmentRefsDigest,
      modelClassCoverageProofSummaryDigest:
          modelClassCoverageProofSummaryDigest,
      releaseGate: releaseGate,
      expectedAssignments: expectedAssignments,
      completedBindings: completedBindings,
    );
    if (importIssues.isNotEmpty) {
      throw StateError(
        'Invalid use-case runtime resolver snapshot input:\n'
        '${importIssues.map(_issueSummary).join('\n')}',
      );
    }
    final runtimeBindings = [
      for (final assignment in expectedAssignments)
        _canonicalRuntimeBinding(
          assignment: assignment,
          input: completedBindings.singleWhere(
            (binding) =>
                _string(binding['assignmentRef']) ==
                _string(assignment['assignmentRef']),
          ),
        ),
    ];
    final observationSource =
        runtimeObservationSource ??
        runtimeObservationSourceForManualCompletedBindingImport(
          releasePlan: releasePlan,
          releaseGate: releaseGate,
          generatedAt: capturedAtUtc,
        );
    final snapshot = <String, dynamic>{
      'schemaVersion':
          EvalUseCaseRuntimeVerification.resolverSnapshotSchemaVersion,
      'kind': EvalUseCaseRuntimeVerification.resolverSnapshotKind,
      'runtimeResolverSnapshotRef': '',
      'capturedAt': capturedAtUtc.toIso8601String(),
      'sourceReleasePlanDigest': releasePlanDigest,
      'sourceReleaseGateRef': releaseGateRef,
      'sourceReleaseGateDigest': releaseGateDigest,
      'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
      'modelClassCoverageProofSummaryDigest':
          modelClassCoverageProofSummaryDigest,
      'runtimeObservationSource': observationSource,
      'summary': <String, dynamic>{
        'runtimeBindingCount': runtimeBindings.length,
      },
      'privacy': const <String, dynamic>{
        'rawPromptsOmitted': true,
        'rawDirectivesOmitted': true,
        'apiKeysOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'publicExportRequiresSanitization': true,
      },
      'limitations': const <String, dynamic>{
        'runtimeStateObservedOnly': true,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
      },
      'runtimeBindings': runtimeBindings,
    };
    snapshot['runtimeResolverSnapshotRef'] =
        EvalUseCaseRuntimeVerification.runtimeResolverSnapshotRef(snapshot);
    final issues =
        EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          snapshot,
        );
    if (issues.isNotEmpty) {
      throw StateError(
        'Invalid canonical runtime resolver snapshot:\n${issues.join('\n')}',
      );
    }
    _markVerifiedSnapshotSources(snapshot);
    return snapshot;
  }

  static bool hasVerifiedSnapshotSources(Map<String, dynamic> snapshot) =>
      _verifiedSnapshotSourceDigests[snapshot] ==
      EvalProvenance.digestJson(snapshot);

  static List<String> validateSnapshotAgainstExpected(
    Map<String, dynamic> snapshot, {
    required Map<String, dynamic> expectedSnapshot,
  }) {
    final issues = [
      ...EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
        snapshot,
      ),
      ...EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
        expectedSnapshot,
      ).map((issue) => 'expected runtime resolver snapshot invalid: $issue'),
    ];
    if (EvalProvenance.digestJson(snapshot) !=
        EvalProvenance.digestJson(expectedSnapshot)) {
      issues.add('runtime resolver snapshot must match source artifacts');
    }
    return issues;
  }

  static void assertSnapshotMatchesExpected(
    Map<String, dynamic> snapshot, {
    required Map<String, dynamic> expectedSnapshot,
  }) {
    final issues = validateSnapshotAgainstExpected(
      snapshot,
      expectedSnapshot: expectedSnapshot,
    );
    if (issues.isEmpty) {
      _markVerifiedSnapshotSources(snapshot);
      return;
    }
    throw StateError(
      'Invalid use-case runtime resolver snapshot source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static void _markVerifiedSnapshotSources(Map<String, dynamic> snapshot) {
    _verifiedSnapshotSourceDigests[snapshot] = EvalProvenance.digestJson(
      snapshot,
    );
  }

  static List<Map<String, dynamic>> _snapshotImportIssues({
    required List<String> releasePlanIssues,
    required List<String> releaseGateIssues,
    required String releasePlanDigest,
    required String releaseGateDigest,
    required String releaseGateRef,
    required String releaseGateStatus,
    required String approvedAssignmentRefsDigest,
    required String releasePlanAssignmentRefsDigest,
    required String modelClassCoverageProofSummaryDigest,
    required Map<String, dynamic> releaseGate,
    required List<Map<String, dynamic>> expectedAssignments,
    required List<Map<String, dynamic>> completedBindings,
  }) {
    final issues = <Map<String, dynamic>>[
      for (final issue in releasePlanIssues)
        <String, dynamic>{
          'code': 'runtimeResolver.releasePlanContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in releaseGateIssues)
        <String, dynamic>{
          'code': 'runtimeResolver.releaseGateContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (releaseGateIssues.isEmpty &&
          _string(
                _map(releaseGate['sourceReleasePlan'])['releasePlanDigest'],
              ) !=
              releasePlanDigest)
        const <String, dynamic>{
          'code': 'runtimeResolver.releaseGateSourceMismatch',
          'severity': 'blocking',
        },
      if (releaseGateIssues.isEmpty &&
          _string(
                _map(releaseGate['sourceReleasePlan'])['assignmentRefsDigest'],
              ) !=
              releasePlanAssignmentRefsDigest)
        const <String, dynamic>{
          'code': 'runtimeResolver.releaseGateAssignmentRefsMismatch',
          'severity': 'blocking',
        },
      if (releaseGateIssues.isEmpty &&
          _string(
                _map(
                  releaseGate['sourceReleasePlan'],
                )['modelClassCoverageProofSummaryDigest'],
              ) !=
              modelClassCoverageProofSummaryDigest)
        const <String, dynamic>{
          'code': 'runtimeResolver.releaseGateProofSummaryMismatch',
          'severity': 'blocking',
        },
      if (releaseGateIssues.isEmpty && releaseGateStatus != _approvedGateStatus)
        <String, dynamic>{
          'code': 'runtimeResolver.releaseGateNotApproved',
          'severity': 'blocking',
          'releaseGateStatus': releaseGateStatus,
        },
      if (releaseGateIssues.isEmpty &&
          releaseGateStatus == _approvedGateStatus &&
          _string(
                _map(releaseGate['sourceReleasePlan'])['releasePlanDigest'],
              ) ==
              releasePlanDigest &&
          _string(
                _map(releaseGate['sourceReleasePlan'])['assignmentRefsDigest'],
              ) ==
              releasePlanAssignmentRefsDigest &&
          approvedAssignmentRefsDigest != releasePlanAssignmentRefsDigest)
        const <String, dynamic>{
          'code': 'runtimeResolver.releaseGateApprovedAssignmentRefsMismatch',
          'severity': 'blocking',
        },
    ];
    if (issues.isNotEmpty) return issues;

    final expectedByRef = {
      for (final assignment in expectedAssignments)
        _string(assignment['assignmentRef']): assignment,
    };
    final bindingsByRef = <String, List<Map<String, dynamic>>>{};
    for (final binding in completedBindings) {
      final bindingIssues = <String>[];
      _validateCompletedBinding(
        bindingIssues,
        binding,
        'runtimeBindings[${completedBindings.indexOf(binding)}]',
      );
      for (final issue in bindingIssues) {
        issues.add(<String, dynamic>{
          'code': 'runtimeResolver.bindingContractInvalid',
          'severity': 'blocking',
          'assignmentRef': _string(binding['assignmentRef']),
          'message': issue,
        });
      }
      final ref = _string(binding['assignmentRef']);
      bindingsByRef.putIfAbsent(ref, () => []).add(binding);
      if (!expectedByRef.containsKey(ref)) {
        issues.add(<String, dynamic>{
          'code': 'runtimeResolver.unapprovedBinding',
          'severity': 'blocking',
          'assignmentRef': ref,
        });
      }
    }
    for (final entry in expectedByRef.entries) {
      final bindings = bindingsByRef[entry.key] ?? const [];
      if (bindings.isEmpty) {
        issues.add(<String, dynamic>{
          'code': 'runtimeResolver.bindingMissing',
          'severity': 'blocking',
          'assignmentRef': entry.key,
        });
        continue;
      }
      if (bindings.length > 1) {
        issues.add(<String, dynamic>{
          'code': 'runtimeResolver.bindingDuplicate',
          'severity': 'blocking',
          'assignmentRef': entry.key,
        });
        continue;
      }
      _compareCompletedBinding(
        issues: issues,
        expected: entry.value,
        binding: bindings.single,
        releasePlanDigest: releasePlanDigest,
        releaseGateRef: releaseGateRef,
        releaseGateDigest: releaseGateDigest,
        approvedAssignmentRefsDigest: approvedAssignmentRefsDigest,
        modelClassCoverageProofSummaryDigest:
            modelClassCoverageProofSummaryDigest,
      );
    }
    return issues;
  }

  static String _issueSummary(Map<String, dynamic> issue) {
    final code = _string(issue['code']);
    final message = _string(issue['message']);
    final field = _string(issue['field']);
    final assignmentRef = _string(issue['assignmentRef']);
    return [
      code,
      if (assignmentRef.isNotEmpty) 'assignmentRef=$assignmentRef',
      if (field.isNotEmpty) 'field=$field',
      if (message.isNotEmpty) message,
    ].join(' ');
  }

  static void _compareCompletedBinding({
    required List<Map<String, dynamic>> issues,
    required Map<String, dynamic> expected,
    required Map<String, dynamic> binding,
    required String releasePlanDigest,
    required String releaseGateRef,
    required String releaseGateDigest,
    required String approvedAssignmentRefsDigest,
    required String modelClassCoverageProofSummaryDigest,
  }) {
    final assignmentRef = _string(expected['assignmentRef']);
    for (final entry in <String, String>{
      'sourceReleasePlanDigest': releasePlanDigest,
      'sourceReleaseGateRef': releaseGateRef,
      'sourceReleaseGateDigest': releaseGateDigest,
      'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
      'modelClassCoverageProofSummaryDigest':
          modelClassCoverageProofSummaryDigest,
    }.entries) {
      if (_string(binding[entry.key]) != entry.value) {
        issues.add(<String, dynamic>{
          'code': 'runtimeResolver.bindingSourceMismatch',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'field': entry.key,
        });
      }
    }
    for (final field in const [
      'scopeKey',
      'targetSurface',
      'primaryCapabilityId',
      'agentKind',
      'modelClass',
      'promptVariantName',
    ]) {
      if (_string(expected[field]) != _string(binding[field])) {
        issues.add(<String, dynamic>{
          'code': 'runtimeResolver.bindingDimensionMismatch',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'field': field,
        });
      }
    }
    final productionAgentKind = _productionAgentKind(
      _string(expected['agentKind']),
    );
    if (productionAgentKind == null ||
        _string(binding['productionAgentKind']) != productionAgentKind) {
      issues.add(<String, dynamic>{
        'code': 'runtimeResolver.productionAgentKindMismatch',
        'severity': 'blocking',
        'assignmentRef': assignmentRef,
      });
    }
    if (_string(binding['status']) == 'pending') {
      issues.add(<String, dynamic>{
        'code': 'runtimeResolver.bindingPending',
        'severity': 'blocking',
        'assignmentRef': assignmentRef,
      });
    }
  }

  static Map<String, dynamic> _canonicalRuntimeBinding({
    required Map<String, dynamic> assignment,
    required Map<String, dynamic> input,
  }) {
    final expectedDigests = _digestMap(input['expected']);
    final observedDigests = _digestMap(input['observed']);
    final shadowedTemplateOverride = input['shadowedTemplateOverride'] == true;
    final assignmentRef = _string(assignment['assignmentRef']);
    final binding = <String, dynamic>{
      'assignmentRef': assignmentRef,
      'scopeKey': _string(assignment['scopeKey']),
      'targetSurface': _string(assignment['targetSurface']),
      'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
      'agentKind': _string(assignment['agentKind']),
      'productionAgentKind': _productionAgentKind(
        _string(assignment['agentKind']),
      ),
      'modelClass': _string(assignment['modelClass']),
      'promptVariantName': _string(assignment['promptVariantName']),
      'modelClassCoverageProofRef': _string(
        assignment['modelClassCoverageProofRef'],
      ),
      'modelClassCoverageClassRef': _string(
        assignment['modelClassCoverageClassRef'],
      ),
      'workOrderBatchRef': _string(assignment['workOrderBatchRef']),
      'modelClassCoverageRef': _string(assignment['modelClassCoverageRef']),
      'modelClassCoverageDigest': _string(
        assignment['modelClassCoverageDigest'],
      ),
      'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
      'resolutionStatus': _string(input['resolutionStatus']),
      'runtimeTargetRef': _string(input['runtimeTargetRef']),
      'expected': expectedDigests,
      'observed': observedDigests,
      if (shadowedTemplateOverride) 'shadowedTemplateOverride': true,
      if (input['privateRuntimeIds'] != null)
        'privateRuntimeIds': input['privateRuntimeIds'],
    };
    binding['resolverBindingDigest'] =
        EvalUseCaseRuntimeVerification.runtimeResolverBindingDigest(binding);
    return binding;
  }

  static Map<String, dynamic> _requiredBinding({
    required Map<String, dynamic> assignment,
    required String releasePlanDigest,
    required String releaseGateRef,
    required String releaseGateDigest,
    required String approvedAssignmentRefsDigest,
    required String modelClassCoverageProofSummaryDigest,
  }) {
    final agentKind = _string(assignment['agentKind']);
    return <String, dynamic>{
      'assignmentRef': _string(assignment['assignmentRef']),
      'sourceReleasePlanDigest': releasePlanDigest,
      'sourceReleaseGateRef': releaseGateRef,
      'sourceReleaseGateDigest': releaseGateDigest,
      'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
      'modelClassCoverageProofSummaryDigest':
          modelClassCoverageProofSummaryDigest,
      'scopeKey': _string(assignment['scopeKey']),
      'targetSurface': _string(assignment['targetSurface']),
      'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
      'agentKind': agentKind,
      'productionAgentKind': _productionAgentKind(agentKind) ?? 'unsupported',
      'modelClass': _string(assignment['modelClass']),
      'promptVariantName': _string(assignment['promptVariantName']),
      'modelClassCoverageProofRef': _string(
        assignment['modelClassCoverageProofRef'],
      ),
      'modelClassCoverageClassRef': _string(
        assignment['modelClassCoverageClassRef'],
      ),
      'workOrderBatchRef': _string(assignment['workOrderBatchRef']),
      'modelClassCoverageRef': _string(assignment['modelClassCoverageRef']),
      'modelClassCoverageDigest': _string(
        assignment['modelClassCoverageDigest'],
      ),
      'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
      'requiredDigestFields': runtimeDigestFields,
      'requiredRuntimeSurfaces': const [
        'ProfileResolver',
        'TaskAgentService',
        'AgentTemplateService',
        'AiConfigRepository',
      ],
    };
  }

  static Map<String, dynamic> _bindingTemplate(
    Map<String, dynamic> requiredBinding,
  ) {
    return <String, dynamic>{
      ...requiredBinding,
      'status': 'pending',
      'resolutionStatus': '',
      'runtimeTargetRef': '',
      'expected': {
        for (final field in runtimeDigestFields) field: '',
      },
      'observed': {
        for (final field in runtimeDigestFields) field: '',
      },
      'privateRuntimeIdsRequired': true,
      'shadowedTemplateOverride': false,
    };
  }

  static void _validateCompletedBinding(
    List<String> issues,
    Map<String, dynamic> binding,
    String path,
  ) {
    _validateBindingSourceFields(issues, binding, path);
    _validateAssignmentDimensions(issues, binding, path);
    final status = _string(binding['status']);
    if (status.isEmpty) {
      issues.add('$path.status must be a non-empty string');
    }
    final resolutionStatus = _expectNonEmptyString(
      issues,
      binding['resolutionStatus'],
      '$path.resolutionStatus',
    );
    if (resolutionStatus != null &&
        !_allowedResolutionStatuses.contains(resolutionStatus)) {
      issues.add('$path.resolutionStatus must be supported');
    }
    _expectDigest(
      issues,
      binding['runtimeTargetRef'],
      '$path.runtimeTargetRef',
    );
    _validateDigestMap(
      issues,
      _expectMap(issues, binding['expected'], '$path.expected'),
      '$path.expected',
    );
    _validateDigestMap(
      issues,
      _expectMap(issues, binding['observed'], '$path.observed'),
      '$path.observed',
    );
    if (binding['privateRuntimeIds'] != null) {
      _validatePrivateRuntimeIds(
        issues,
        binding['privateRuntimeIds'],
        '$path.privateRuntimeIds',
      );
    }
    _validateNoPrivatePayloads(
      issues,
      binding,
      path,
      allowPrivateRuntimeIds: true,
    );
  }

  static void _validateRequiredBindings(
    List<String> issues,
    List<dynamic>? bindings,
    String path, {
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
  }) {
    if (bindings == null) return;
    for (final (index, value) in bindings.indexed) {
      final binding = _expectMap(issues, value, '$path[$index]');
      if (binding == null) continue;
      _validateBindingSourceFields(issues, binding, '$path[$index]');
      _validateBindingSourceConsistency(
        issues,
        binding,
        '$path[$index]',
        sourceReleasePlan: sourceReleasePlan,
        sourceReleaseGate: sourceReleaseGate,
      );
      _validateAssignmentDimensions(issues, binding, '$path[$index]');
      _validateRequiredDigestFields(issues, binding, '$path[$index]');
    }
  }

  static void _validateBindingTemplates(
    List<String> issues,
    List<dynamic>? bindings,
    String path, {
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
  }) {
    if (bindings == null) return;
    for (final (index, value) in bindings.indexed) {
      final binding = _expectMap(issues, value, '$path[$index]');
      if (binding == null) continue;
      _validateBindingSourceFields(issues, binding, '$path[$index]');
      _validateBindingSourceConsistency(
        issues,
        binding,
        '$path[$index]',
        sourceReleasePlan: sourceReleasePlan,
        sourceReleaseGate: sourceReleaseGate,
      );
      _validateAssignmentDimensions(issues, binding, '$path[$index]');
      _validateRequiredDigestFields(issues, binding, '$path[$index]');
      _expectEquals(
        issues,
        binding['status'],
        'pending',
        '$path[$index].status',
      );
    }
  }

  static void _validateBindingSourceFields(
    List<String> issues,
    Map<String, dynamic> binding,
    String path,
  ) {
    for (final field in const [
      'assignmentRef',
      'sourceReleasePlanDigest',
      'sourceReleaseGateRef',
      'sourceReleaseGateDigest',
      'approvedAssignmentRefsDigest',
      'modelClassCoverageProofSummaryDigest',
      'scopeKey',
      'modelClassCoverageProofRef',
      'modelClassCoverageClassRef',
      'workOrderBatchRef',
      'modelClassCoverageDigest',
      'sourceWorkOrderDigest',
    ]) {
      _expectDigest(issues, binding[field], '$path.$field');
    }
  }

  static void _validateBindingSourceConsistency(
    List<String> issues,
    Map<String, dynamic> binding,
    String path, {
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
  }) {
    if (sourceReleasePlan == null || sourceReleaseGate == null) return;
    for (final entry in <String, String>{
      'sourceReleasePlanDigest': _string(
        sourceReleasePlan['releasePlanDigest'],
      ),
      'sourceReleaseGateRef': _string(sourceReleaseGate['releaseGateRef']),
      'sourceReleaseGateDigest': _string(
        sourceReleaseGate['releaseGateDigest'],
      ),
      'approvedAssignmentRefsDigest': _string(
        sourceReleaseGate['approvedAssignmentRefsDigest'],
      ),
      'modelClassCoverageProofSummaryDigest': _string(
        sourceReleasePlan['modelClassCoverageProofSummaryDigest'],
      ),
    }.entries) {
      if (_string(binding[entry.key]) != entry.value) {
        issues.add('$path.${entry.key} must match ${_sourcePath(entry.key)}');
      }
    }
  }

  static String _sourcePath(String field) => switch (field) {
    'sourceReleasePlanDigest' => 'sourceReleasePlan.releasePlanDigest',
    'sourceReleaseGateRef' => 'sourceReleaseGate.releaseGateRef',
    'sourceReleaseGateDigest' => 'sourceReleaseGate.releaseGateDigest',
    'approvedAssignmentRefsDigest' =>
      'sourceReleaseGate.approvedAssignmentRefsDigest',
    _ => 'sourceReleasePlan.modelClassCoverageProofSummaryDigest',
  };

  static void _validateAssignmentDimensions(
    List<String> issues,
    Map<String, dynamic> binding,
    String path,
  ) {
    for (final field in const [
      'targetSurface',
      'primaryCapabilityId',
      'agentKind',
      'productionAgentKind',
      'modelClass',
      'promptVariantName',
      'modelClassCoverageRef',
    ]) {
      _expectSafePublicToken(issues, binding[field], '$path.$field');
    }
  }

  static void _validateRequiredDigestFields(
    List<String> issues,
    Map<String, dynamic> binding,
    String path,
  ) {
    final fields = _expectStringList(
      issues,
      binding['requiredDigestFields'],
      '$path.requiredDigestFields',
    );
    if (fields == null) return;
    final extra = fields.toSet()..removeAll(runtimeDigestFields);
    if (extra.isNotEmpty) {
      issues.add('$path.requiredDigestFields contains unsupported fields');
    }
    if (!fields.toSet().containsAll(runtimeDigestFields)) {
      issues.add(
        '$path.requiredDigestFields must include runtime digest fields',
      );
    }
  }

  static void _validateDigestMap(
    List<String> issues,
    Map<String, dynamic>? digests,
    String path,
  ) {
    if (digests == null) return;
    for (final field in runtimeDigestFields) {
      _expectDigest(issues, digests[field], '$path.$field');
    }
  }

  static Map<String, dynamic> _digestMap(Object? value) {
    final source = _map(value);
    return <String, dynamic>{
      for (final field in runtimeDigestFields) field: _string(source[field]),
    };
  }

  static void _validateSource(
    List<String> issues,
    Map<String, dynamic>? source,
    String path,
  ) {
    if (source == null) return;
    _expectNonEmptyString(issues, source['kind'], '$path.kind');
    _expectNonNegativeInt(
      issues,
      source['schemaVersion'],
      '$path.schemaVersion',
    );
    _expectNonEmptyString(issues, source['status'], '$path.status');
    for (final field in const [
      'releasePlanRef',
      'releasePlanDigest',
      'releaseGateRef',
      'releaseGateDigest',
      'sourceReleasePlanDigest',
      'approvedAssignmentRefsDigest',
      'modelClassCoverageProofSummaryDigest',
    ]) {
      if (source.containsKey(field)) {
        _expectDigest(issues, source[field], '$path.$field');
      }
    }
    for (final field in const [
      'contractIssueCount',
      'assignmentCount',
      'approvedAssignmentRefCount',
    ]) {
      if (source.containsKey(field)) {
        _expectNonNegativeInt(issues, source[field], '$path.$field');
      }
    }
  }

  static void _validatePacketSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'requiredRuntimeBindingCount',
      'bindingTemplateCount',
      'releasePlanContractIssueCount',
      'releaseGateContractIssueCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validatePacketSummaryInvariants(
    List<String> issues, {
    required String? status,
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
    required Map<String, dynamic> summary,
    required List<dynamic>? requiredBindings,
    required List<dynamic>? templates,
    required List<dynamic>? issuesList,
  }) {
    if (summary['requiredRuntimeBindingCount'] is int &&
        requiredBindings != null &&
        summary['requiredRuntimeBindingCount'] != requiredBindings.length) {
      issues.add(
        'summary.requiredRuntimeBindingCount must match requiredRuntimeBindings.length',
      );
    }
    if (summary['bindingTemplateCount'] is int &&
        templates != null &&
        summary['bindingTemplateCount'] != templates.length) {
      issues.add(
        'summary.bindingTemplateCount must match bindingTemplates.length',
      );
    }
    if (status == null ||
        sourceReleasePlan == null ||
        sourceReleaseGate == null) {
      return;
    }
    final sourceReady =
        _string(sourceReleasePlan['status']) == 'readyForReleaseReview' &&
        _intOrZero(sourceReleasePlan['contractIssueCount']) == 0 &&
        _string(sourceReleaseGate['status']) == _approvedGateStatus &&
        _intOrZero(sourceReleaseGate['contractIssueCount']) == 0 &&
        _intOrZero(sourceReleaseGate['approvedAssignmentRefCount']) ==
            _intOrZero(sourceReleasePlan['assignmentCount']) &&
        _intOrZero(sourceReleasePlan['assignmentCount']) > 0 &&
        _mapList(issuesList).isEmpty;
    final expectedStatus = !sourceReady
        ? _expectedBlockedPacketStatus(
            sourceReleasePlan: sourceReleasePlan,
            sourceReleaseGate: sourceReleaseGate,
          )
        : requiredBindings != null && requiredBindings.isEmpty
        ? 'noRuntimeBindings'
        : 'readyForRuntimeResolution';
    if (status != expectedStatus) {
      issues.add('status must match resolver packet source readiness');
    }
    if (status == 'readyForRuntimeResolution' &&
        requiredBindings != null &&
        requiredBindings.isEmpty) {
      issues.add(
        'readyForRuntimeResolution packets require runtime bindings',
      );
    }
  }

  static String _expectedBlockedPacketStatus({
    required Map<String, dynamic> sourceReleasePlan,
    required Map<String, dynamic> sourceReleaseGate,
  }) {
    if (_intOrZero(sourceReleasePlan['contractIssueCount']) > 0) {
      return 'invalidReleasePlan';
    }
    if (_intOrZero(sourceReleaseGate['contractIssueCount']) > 0) {
      return 'invalidReleaseGate';
    }
    if (_string(sourceReleaseGate['status']) != _approvedGateStatus) {
      return 'blockedReleaseGate';
    }
    return 'invalidReleaseGate';
  }

  static void _validateBindingTemplateCoverage(
    List<String> issues, {
    required List<dynamic>? requiredBindings,
    required List<dynamic>? templates,
  }) {
    if (requiredBindings == null || templates == null) return;
    final requiredKeys = {
      for (final binding in _mapList(requiredBindings))
        _bindingCoverageKey(binding),
    };
    final seenTemplateKeys = <String>{};
    for (final (index, value) in templates.indexed) {
      if (value is! Map<String, dynamic>) continue;
      final key = _bindingCoverageKey(value);
      if (!requiredKeys.contains(key)) {
        issues.add('bindingTemplates[$index] must match a required binding');
      }
      if (!seenTemplateKeys.add(key)) {
        issues.add(
          'bindingTemplates[$index] must not duplicate a required binding',
        );
      }
    }
    for (final key in requiredKeys) {
      if (!seenTemplateKeys.contains(key)) {
        issues.add('bindingTemplates must include every required binding');
      }
    }
  }

  static String _bindingCoverageKey(Map<String, dynamic> binding) =>
      EvalProvenance.digestJson(<String, dynamic>{
        'assignmentRef': _string(binding['assignmentRef']),
        'sourceReleasePlanDigest': _string(
          binding['sourceReleasePlanDigest'],
        ),
        'sourceReleaseGateRef': _string(binding['sourceReleaseGateRef']),
        'sourceReleaseGateDigest': _string(binding['sourceReleaseGateDigest']),
        'approvedAssignmentRefsDigest': _string(
          binding['approvedAssignmentRefsDigest'],
        ),
        'modelClassCoverageProofSummaryDigest': _string(
          binding['modelClassCoverageProofSummaryDigest'],
        ),
        'scopeKey': _string(binding['scopeKey']),
        'targetSurface': _string(binding['targetSurface']),
        'primaryCapabilityId': _string(binding['primaryCapabilityId']),
        'agentKind': _string(binding['agentKind']),
        'productionAgentKind': _string(binding['productionAgentKind']),
        'modelClass': _string(binding['modelClass']),
        'promptVariantName': _string(binding['promptVariantName']),
        'modelClassCoverageProofRef': _string(
          binding['modelClassCoverageProofRef'],
        ),
        'modelClassCoverageClassRef': _string(
          binding['modelClassCoverageClassRef'],
        ),
        'workOrderBatchRef': _string(binding['workOrderBatchRef']),
        'modelClassCoverageRef': _string(binding['modelClassCoverageRef']),
        'modelClassCoverageDigest': _string(
          binding['modelClassCoverageDigest'],
        ),
        'sourceWorkOrderDigest': _string(binding['sourceWorkOrderDigest']),
        'requiredDigestFields': _stringList(binding['requiredDigestFields']),
      });

  static void _validatePacketPrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'rawRunIdsOmitted': true,
      'profileNamesOmitted': true,
      'localConfigIdsOmitted': true,
      'privateRuntimeIdsOmitted': true,
      'providerBaseUrlsOmitted': true,
      'apiKeysOmitted': true,
      'rawPromptTextOmitted': true,
      'rawDirectiveTextOmitted': true,
      'sourceArtifactPathsOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        privacy[entry.key],
        entry.value,
        'privacy.${entry.key}',
      );
    }
  }

  static void _validatePacketLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesReleasePlanGateAndReviewEvidence': true,
      'runtimeStateObserved': false,
      'runtimeConfigurationAppliedByHarness': false,
      'aiConfigMutationsWrittenByHarness': false,
      'liveCommandsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        limitations[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
  }

  static void _validateDirectObservationSourcePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'privateRuntimeIdsAllowed': true,
      'rawPromptsOmitted': true,
      'rawDirectivesOmitted': true,
      'apiKeysOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        privacy[entry.key],
        entry.value,
        'privacy.${entry.key}',
      );
    }
  }

  static void _validateDirectObservationSourceLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'runtimeStateObservedOnly': true,
      'runtimeConfigurationAppliedByHarness': false,
      'aiConfigMutationsWrittenByHarness': false,
      'liveCommandsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        limitations[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
  }

  static void _validateIssues(List<String> issues, List<dynamic>? issueList) {
    if (issueList == null) return;
    for (final (index, value) in issueList.indexed) {
      final issue = _expectMap(issues, value, 'issues[$index]');
      if (issue == null) continue;
      _expectNonEmptyString(issues, issue['code'], 'issues[$index].code');
      _expectNonEmptyString(
        issues,
        issue['severity'],
        'issues[$index].severity',
      );
    }
  }

  static void _validateCommands(
    List<String> issues,
    List<dynamic>? commands,
    String path, {
    List<Map<String, dynamic>>? expectedCommands,
  }) {
    if (commands == null) return;
    if (expectedCommands != null &&
        EvalProvenance.digestJson(commands) !=
            EvalProvenance.digestJson(expectedCommands)) {
      issues.add('$path must match static recommended command templates');
    }
    for (final (index, value) in commands.indexed) {
      final command = _expectMap(issues, value, '$path[$index]');
      if (command == null) continue;
      _expectNonEmptyString(issues, command['mode'], '$path[$index].mode');
      final text = _expectNonEmptyString(
        issues,
        command['command'],
        '$path[$index].command',
      );
      if (text != null && _liveRunLevel2CommandPattern.hasMatch(text)) {
        issues.add(
          '$path[$index].command must not recommend live run commands',
        );
      }
      if (text != null && _dangerousCommandTokenPattern.hasMatch(text)) {
        issues.add(
          '$path[$index].command must not recommend mutation commands',
        );
      }
      if (command.containsKey('env')) {
        issues.add('$path[$index] must not contain env values');
      }
    }
  }

  static List<Map<String, dynamic>> _recommendedCommands() => const [
    <String, dynamic>{
      'mode': 'runtime-resolver-packet',
      'command': 'eval/run_level2.sh runtime-resolver-packet',
    },
    <String, dynamic>{
      'mode': 'runtime-locator-packet',
      'command': 'eval/run_level2.sh runtime-locator-packet',
    },
    <String, dynamic>{
      'mode': 'observe-runtime-state',
      'command': 'eval/run_level2.sh observe-runtime-state',
    },
    <String, dynamic>{
      'mode': 'import-runtime-resolver',
      'command': 'eval/run_level2.sh import-runtime-resolver',
    },
    <String, dynamic>{
      'mode': 'runtime-verify',
      'command': 'eval/run_level2.sh runtime-verify',
    },
  ];

  static List<String> _approvedAssignmentRefs(
    Map<String, dynamic> releaseGate,
  ) {
    final refs = _stringList(releaseGate['approvedAssignmentRefs'])..sort();
    return refs;
  }

  static List<Map<String, dynamic>> _expectedAssignments({
    required Map<String, dynamic> releasePlan,
    required List<String> approvedAssignmentRefs,
  }) {
    final approvedRefSet = approvedAssignmentRefs.toSet();
    return [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        if (approvedRefSet.contains(_string(assignment['assignmentRef'])))
          assignment,
    ];
  }

  static void _validatePrivateRuntimeIds(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! Map<String, dynamic>) {
      issues.add('$path must be a JSON object');
      return;
    }
    for (final entry in value.entries) {
      _expectSafePublicToken(issues, entry.key, '$path.${entry.key}.key');
      final text = _expectNonEmptyString(
        issues,
        entry.value,
        '$path.${entry.key}',
      );
      if (text == null) continue;
      _expectNoPrivateStringPayload(issues, text, '$path.${entry.key}');
    }
  }

  static void _validateNoPrivatePayloads(
    List<String> issues,
    Object? value,
    String path, {
    bool allowPrivateRuntimeIds = false,
  }) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (allowPrivateRuntimeIds &&
            (normalized == 'privateruntimeids' || normalized == 'runtimeids')) {
          _validatePrivateRuntimeIds(issues, entry.value, '$path.$key');
          continue;
        }
        if (_privateFieldReason(normalized) case final reason?) {
          issues.add('$path.$key must not expose $reason');
        }
        _validateNoPrivatePayloads(
          issues,
          entry.value,
          '$path.$key',
          allowPrivateRuntimeIds: allowPrivateRuntimeIds,
        );
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoPrivatePayloads(
          issues,
          item,
          '$path[$index]',
          allowPrivateRuntimeIds: allowPrivateRuntimeIds,
        );
      }
      return;
    }
    if (value is String) {
      _expectNoPrivateStringPayload(issues, value, path);
    }
  }

  static void _expectNoPrivateStringPayload(
    List<String> issues,
    String value,
    String path,
  ) {
    if (_privatePathPattern.hasMatch(value)) {
      issues.add('$path must not contain private paths');
    }
    if (_privateEnvTokenPattern.hasMatch(value)) {
      issues.add('$path must not contain private env value keys');
    }
    if (_liveRunLevel2CommandPattern.hasMatch(value)) {
      issues.add('$path must not contain live run commands');
    }
    if (_dangerousCommandTokenPattern.hasMatch(value)) {
      issues.add('$path must not contain mutation commands');
    }
    if (value.contains('<redacted-scenario')) {
      issues.add('$path must not contain redacted scenario placeholders');
    }
    if (_scenarioFieldTokenPattern.hasMatch(value)) {
      issues.add('$path must not contain scenario id field names');
    }
    if (_profileFieldTokenPattern.hasMatch(value)) {
      issues.add('$path must not contain profile selector field names');
    }
    if (_rawPromptFieldTokenPattern.hasMatch(value)) {
      issues.add('$path must not contain raw prompt or directive field names');
    }
  }

  static String? _privateFieldReason(String normalized) {
    if (normalized.endsWith('omitted') ||
        normalized.endsWith('digest') ||
        normalized.endsWith('ref')) {
      return null;
    }
    if (normalized == 'scenarioid' ||
        normalized == 'scenarioids' ||
        normalized.endsWith('scenarioids')) {
      return 'scenario ids';
    }
    if (normalized == 'profilename' ||
        normalized == 'profilenames' ||
        normalized.endsWith('profilenames')) {
      return 'profile selectors';
    }
    if (normalized == 'runid' ||
        normalized == 'baserunid' ||
        normalized.endsWith('runid')) {
      return 'run ids';
    }
    if (normalized == 'localconfigid' ||
        normalized == 'modelconfigid' ||
        normalized == 'profileid' ||
        normalized == 'agentid' ||
        normalized == 'taskid' ||
        normalized == 'templateid' ||
        normalized == 'categoryid' ||
        normalized == 'providerid' ||
        normalized == 'runtimeid' ||
        normalized == 'privateruntimeids' ||
        normalized == 'runtimeids' ||
        normalized.endsWith('configid')) {
      return 'private runtime ids';
    }
    if (normalized == 'apikey' ||
        normalized == 'apikeys' ||
        normalized == 'baseurl' ||
        normalized == 'providerbaseurl') {
      return 'provider secrets';
    }
    if (normalized == 'rawprompt' ||
        normalized == 'rawprompts' ||
        normalized == 'prompttext' ||
        normalized == 'systemprompt' ||
        normalized == 'directivetext' ||
        normalized == 'rawdirective' ||
        normalized == 'rawdirectives') {
      return 'raw prompt text';
    }
    return null;
  }

  static Map<String, dynamic>? _expectMap(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map<String, dynamic>) return value;
    issues.add('$path must be a JSON object');
    return null;
  }

  static void _expectOnlyKeys(
    List<String> issues,
    Map<String, dynamic> value,
    Set<String> allowedKeys,
    String path,
  ) {
    final unknownKeys = value.keys.toSet().difference(allowedKeys);
    if (unknownKeys.isEmpty) return;
    final sorted = unknownKeys.toList()..sort();
    issues.add('$path contains unknown fields: ${sorted.join(', ')}');
  }

  static List<dynamic>? _expectList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is List<dynamic>) return value;
    issues.add('$path must be a list');
    return null;
  }

  static List<String>? _expectStringList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! List) {
      issues.add('$path must be a list');
      return null;
    }
    final strings = <String>[];
    for (final (index, item) in value.indexed) {
      if (item is String) {
        strings.add(item);
      } else {
        issues.add('$path[$index] must be a string');
      }
    }
    return strings;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return [
      for (final item in value)
        if (item is String && item.isNotEmpty) item,
    ];
  }

  static String? _expectNonEmptyString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is String && value.trim().isNotEmpty) return value;
    issues.add('$path must be a non-empty string');
    return null;
  }

  static void _expectSafePublicToken(
    List<String> issues,
    Object? value,
    String path,
  ) {
    final text = _expectNonEmptyString(issues, value, path);
    if (text == null) return;
    if (!_publicTokenPattern.hasMatch(text)) {
      issues.add('$path must be a safe public token');
    }
    if (_liveRunLevel2CommandPattern.hasMatch(text) ||
        _dangerousCommandTokenPattern.hasMatch(text)) {
      issues.add('$path must not contain executable command text');
    }
  }

  static void _expectDigest(List<String> issues, Object? value, String path) {
    final digest = _expectNonEmptyString(issues, value, path);
    if (digest != null && !EvalProvenance.isDigest(digest)) {
      issues.add('$path must be a sha256 digest');
    }
  }

  static void _expectIsoDate(List<String> issues, Object? value, String path) {
    final text = _expectNonEmptyString(issues, value, path);
    if (text == null) return;
    try {
      DateTime.parse(text);
    } on FormatException {
      issues.add('$path must be an ISO-8601 timestamp');
    }
  }

  static int? _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is int && value >= 0) return value;
    issues.add('$path must be a non-negative integer');
    return null;
  }

  static void _expectEquals(
    List<String> issues,
    Object? value,
    Object? expected,
    String path,
  ) {
    if (value == expected) return;
    issues.add('$path must be $expected');
  }

  static String? _productionAgentKind(String agentKind) =>
      _productionAgentKinds[agentKind];

  static String _nonEmptyOrUnknown(Object? value) {
    final text = _string(value);
    return text.isEmpty ? 'unknown' : text;
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String _string(Object? value) => value is String ? value : '';

int _intOrZero(Object? value) => value is int ? value : 0;
