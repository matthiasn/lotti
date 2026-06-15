import 'eval_provenance.dart';
import 'eval_use_case_runtime_resolver_snapshot.dart';
import 'eval_use_case_tuning_release_gate.dart';
import 'eval_use_case_tuning_release_plan.dart';

abstract final class EvalUseCaseRuntimeVerification {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseRuntimeVerification';
  static const resolverSnapshotSchemaVersion = 1;
  static const resolverSnapshotKind =
      'lotti.evalUseCaseRuntimeResolverSnapshot';
  static const int snapshotSchemaVersion = resolverSnapshotSchemaVersion;
  static const String snapshotKind = resolverSnapshotKind;
  static const _runtimeResolverPacketSchemaVersion = 1;
  static const _runtimeResolverPacketKind =
      'lotti.evalUseCaseRuntimeResolverPacket';
  static const _runtimeLocatorPacketSchemaVersion = 1;
  static const _runtimeLocatorPacketKind =
      'lotti.evalRuntimeBindingLocatorPacket';

  static const _approvedGateStatus = 'approvedForManualApply';
  static const _allowedStatuses = {
    'verified',
    'notApplied',
    'drift',
    'blockedReleaseGate',
    'invalid',
  };
  static const _allowedResolutionStatuses = {
    'applied',
    'notApplied',
    'partiallyApplied',
    'drift',
    'unsupported',
    'unknown',
  };
  static const _allowedRuntimeObservationSourceModes = {
    'manualCompletedBindingImport',
    'directRuntimeObservation',
    'privateRuntimeStateLocator',
  };
  static const _productionAgentKinds = <String, String>{
    'taskAgent': 'task_agent',
    'planningAgent': 'day_agent',
  };
  static const _runtimeDigestFields = [
    'resolvedProfileDigest',
    'providerModelBindingDigest',
    'thinkingModelBindingDigest',
    'promptVariantDigest',
    'promptDirectiveDigest',
  ];

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

  static Map<String, dynamic> build({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> runtimeResolverSnapshot,
    Map<String, dynamic>? runtimeResolverPacket,
    Map<String, dynamic>? runtimeLocatorPacket,
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
    final releaseGateStatus = _nonEmptyOrUnknown(releaseGate['status']);
    final releaseGateIssues = [
      ...(releaseReviewBundles.isEmpty
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
            )),
      if (sourceRoadmap != null &&
          releaseGateStatus == _approvedGateStatus &&
          releaseReviewBundles.isEmpty)
        'release gate review sources must be supplied for source-aware runtime verification',
    ];
    final resolverSnapshotIssues = [
      ...validateRuntimeResolverSnapshot(runtimeResolverSnapshot),
      ...validateRuntimeResolverSnapshotSourceArtifacts(
        runtimeResolverSnapshot,
        runtimeResolverPacket: runtimeResolverPacket,
        runtimeLocatorPacket: runtimeLocatorPacket,
      ),
    ];
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final releaseGateDigest = EvalProvenance.digestJson(releaseGate);
    final approvedAssignmentRefs = _stringList(
      releaseGate['approvedAssignmentRefs'],
    )..sort();
    final approvedAssignmentRefSet = approvedAssignmentRefs.toSet();
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
    final expectedAssignments = [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        if (approvedAssignmentRefSet.contains(
          _string(assignment['assignmentRef']),
        ))
          assignment,
    ];
    final runtimeBindings = _mapList(
      runtimeResolverSnapshot['runtimeBindings'],
    );
    final runtimeIssues = _runtimeIssues(
      releasePlanIssues: releasePlanIssues,
      releaseGateIssues: releaseGateIssues,
      resolverSnapshotIssues: resolverSnapshotIssues,
      releasePlanDigest: releasePlanDigest,
      releaseGateDigest: releaseGateDigest,
      releaseGateRef: _string(releaseGate['releaseGateRef']),
      approvedAssignmentRefsDigest: approvedAssignmentRefsDigest,
      releasePlanAssignmentRefsDigest: releasePlanAssignmentRefsDigest,
      modelClassCoverageProofSummaryDigest:
          modelClassCoverageProofSummaryDigest,
      releaseGateStatus: releaseGateStatus,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: runtimeResolverSnapshot,
      expectedAssignments: expectedAssignments,
      runtimeBindings: runtimeBindings,
    );
    final status = _status(
      releasePlanIssues: releasePlanIssues,
      releaseGateIssues: releaseGateIssues,
      resolverSnapshotIssues: resolverSnapshotIssues,
      releaseGateStatus: releaseGateStatus,
      runtimeIssues: runtimeIssues,
    );
    final verifiedRefs = _verifiedRefs(
      expectedAssignments: expectedAssignments,
      runtimeBindings: runtimeBindings,
      issues: runtimeIssues,
    );
    final resolverSnapshotDigest = EvalProvenance.digestJson(
      runtimeResolverSnapshot,
    );
    final verification = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'runtimeVerificationRef': _runtimeVerificationRef(
        status: status,
        sourceReleasePlanDigest: releasePlanDigest,
        sourceReleaseGateDigest: releaseGateDigest,
        runtimeResolverSnapshotRef: _string(
          runtimeResolverSnapshot['runtimeResolverSnapshotRef'],
        ),
        runtimeResolverSnapshotDigest: resolverSnapshotDigest,
        verifiedAssignmentRefs: verifiedRefs,
        modelClassCoverageProofSummaryDigest:
            modelClassCoverageProofSummaryDigest,
        summary: <String, dynamic>{
          'expectedAssignmentCount': expectedAssignments.length,
          'runtimeBindingCount': runtimeBindings.length,
          'verifiedAssignmentCount': verifiedRefs.length,
          'missingAssignmentCount': _issueCount(runtimeIssues, 'missing'),
          'duplicateBindingCount': _issueCount(runtimeIssues, 'duplicate'),
          'unapprovedBindingCount': _issueCount(runtimeIssues, 'unapproved'),
          'unsupportedBindingCount': _issueCount(runtimeIssues, 'unsupported'),
          'driftCount': _issueCount(runtimeIssues, 'drift'),
          'partialBindingCount': _issueCount(runtimeIssues, 'partial'),
          'notAppliedCount': _issueCount(runtimeIssues, 'notApplied'),
          'issueCount': runtimeIssues.length,
        },
        expectedAssignments: [
          for (final assignment in expectedAssignments)
            _expectedAssignment(assignment),
        ],
        observedRuntimeBindings: [
          for (final binding in runtimeBindings)
            _observedRuntimeBinding(binding),
        ],
        issues: runtimeIssues,
      ),
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
        'releaseGateRef': _string(releaseGate['releaseGateRef']),
        'releaseGateDigest': releaseGateDigest,
        'sourceReleasePlanDigest': _string(
          _map(releaseGate['sourceReleasePlan'])['releasePlanDigest'],
        ),
        'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
        'modelClassCoverageProofSummaryDigest': releaseGateProofSummaryDigest,
        'contractIssueCount': releaseGateIssues.length,
        'approvedAssignmentRefCount': approvedAssignmentRefs.length,
      },
      'runtimeResolverSnapshot': <String, dynamic>{
        'kind': resolverSnapshotKind,
        'schemaVersion': resolverSnapshotSchemaVersion,
        'capturedAt': _string(runtimeResolverSnapshot['capturedAt']),
        'runtimeResolverSnapshotRef': _string(
          runtimeResolverSnapshot['runtimeResolverSnapshotRef'],
        ),
        'snapshotDigest': resolverSnapshotDigest,
        'sourceReleasePlanDigest': _string(
          runtimeResolverSnapshot['sourceReleasePlanDigest'],
        ),
        'sourceReleaseGateRef': _string(
          runtimeResolverSnapshot['sourceReleaseGateRef'],
        ),
        'sourceReleaseGateDigest': _string(
          runtimeResolverSnapshot['sourceReleaseGateDigest'],
        ),
        'approvedAssignmentRefsDigest': _string(
          runtimeResolverSnapshot['approvedAssignmentRefsDigest'],
        ),
        'modelClassCoverageProofSummaryDigest': _string(
          runtimeResolverSnapshot['modelClassCoverageProofSummaryDigest'],
        ),
        'runtimeObservationSourceDigest': EvalProvenance.digestJson(
          _map(runtimeResolverSnapshot['runtimeObservationSource']),
        ),
        'contractIssueCount': resolverSnapshotIssues.length,
        'runtimeBindingCount': runtimeBindings.length,
      },
      'summary': <String, dynamic>{
        'expectedAssignmentCount': expectedAssignments.length,
        'runtimeBindingCount': runtimeBindings.length,
        'verifiedAssignmentCount': verifiedRefs.length,
        'missingAssignmentCount': _issueCount(runtimeIssues, 'missing'),
        'duplicateBindingCount': _issueCount(runtimeIssues, 'duplicate'),
        'unapprovedBindingCount': _issueCount(runtimeIssues, 'unapproved'),
        'unsupportedBindingCount': _issueCount(runtimeIssues, 'unsupported'),
        'driftCount': _issueCount(runtimeIssues, 'drift'),
        'partialBindingCount': _issueCount(runtimeIssues, 'partial'),
        'notAppliedCount': _issueCount(runtimeIssues, 'notApplied'),
        'issueCount': runtimeIssues.length,
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
        'consumesReleasePlanGateAndPrivateResolverSnapshotOnly': true,
        'privateRuntimeLocatorSnapshotsRequireSourcePackets': true,
        'privateResolverSnapshotIsNotAPublicArtifact': true,
        'runtimeStateObservedOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'liveCommandsCreated': false,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
      },
      'expectedAssignments': [
        for (final assignment in expectedAssignments)
          _expectedAssignment(assignment),
      ],
      'observedRuntimeBindings': [
        for (final binding in runtimeBindings) _observedRuntimeBinding(binding),
      ],
      'verifiedAssignmentRefs': verifiedRefs,
      'issues': runtimeIssues,
      'recommendedCommands': _recommendedCommands(status),
    };
    assertValid(verification);
    return verification;
  }

  static List<String> validateRuntimeSnapshot(Map<String, dynamic> snapshot) =>
      validateRuntimeResolverSnapshot(snapshot);

  static List<String> validateRuntimeResolverSnapshot(
    Map<String, dynamic> snapshot,
  ) {
    final issues = <String>[];
    _expectEquals(
      issues,
      snapshot['schemaVersion'],
      resolverSnapshotSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, snapshot['kind'], resolverSnapshotKind, 'kind');
    _expectDigest(
      issues,
      snapshot['runtimeResolverSnapshotRef'],
      'runtimeResolverSnapshotRef',
    );
    _expectIsoDate(issues, snapshot['capturedAt'], 'capturedAt');
    for (final field in const [
      'sourceReleasePlanDigest',
      'sourceReleaseGateRef',
      'sourceReleaseGateDigest',
      'approvedAssignmentRefsDigest',
      'modelClassCoverageProofSummaryDigest',
    ]) {
      _expectDigest(issues, snapshot[field], field);
    }
    final runtimeBindings = _expectList(
      issues,
      snapshot['runtimeBindings'],
      'runtimeBindings',
    );
    final runtimeObservationSource = _expectMap(
      issues,
      snapshot['runtimeObservationSource'],
      'runtimeObservationSource',
    );
    _validateRuntimeObservationSource(
      issues,
      runtimeObservationSource,
      'runtimeObservationSource',
    );
    _validateRuntimeObservationSourceConsistency(
      issues,
      snapshot: snapshot,
      source: runtimeObservationSource,
    );
    _validateResolverSnapshotSummary(
      issues,
      _expectMap(issues, snapshot['summary'], 'summary'),
      runtimeBindings,
    );
    _validateResolverSnapshotPrivacy(
      issues,
      _expectMap(issues, snapshot['privacy'], 'privacy'),
    );
    _validateResolverSnapshotLimitations(
      issues,
      _expectMap(issues, snapshot['limitations'], 'limitations'),
    );
    _validateRuntimeBindings(
      issues,
      runtimeBindings,
      'runtimeBindings',
    );
    _validateRuntimeResolverSnapshotRef(issues, snapshot);
    _validateNoPrivatePayloads(
      issues,
      snapshot,
      'runtimeResolverSnapshot',
      allowPrivateRuntimeIds: true,
    );
    return issues;
  }

  static List<String> validateRuntimeResolverSnapshotSourceArtifacts(
    Map<String, dynamic> snapshot, {
    Map<String, dynamic>? runtimeResolverPacket,
    Map<String, dynamic>? runtimeLocatorPacket,
  }) {
    final source = _map(snapshot['runtimeObservationSource']);
    final mode = _string(source['mode']);
    final issues = <String>[];
    if (runtimeResolverPacket == null) {
      issues.add('runtime resolver snapshots require source resolver packet');
    }
    if (mode == 'privateRuntimeStateLocator' && runtimeLocatorPacket == null) {
      issues.add(
        'private runtime resolver snapshots require source locator packet',
      );
    }
    if (!EvalUseCaseRuntimeResolverSnapshot.hasVerifiedSnapshotSources(
      snapshot,
    )) {
      issues.add('source runtime resolver snapshot sources must be verified');
    }
    if (runtimeResolverPacket == null ||
        (mode == 'privateRuntimeStateLocator' &&
            runtimeLocatorPacket == null)) {
      return issues;
    }

    _expectEquals(
      issues,
      runtimeResolverPacket['schemaVersion'],
      _runtimeResolverPacketSchemaVersion,
      'sourceRuntimeResolverPacket.schemaVersion',
    );
    _expectEquals(
      issues,
      runtimeResolverPacket['kind'],
      _runtimeResolverPacketKind,
      'sourceRuntimeResolverPacket.kind',
    );
    if (!EvalUseCaseRuntimeResolverSnapshot.hasVerifiedPacketSources(
      runtimeResolverPacket,
    )) {
      issues.add('source runtime resolver packet sources must be verified');
    }
    if (runtimeLocatorPacket != null) {
      _expectEquals(
        issues,
        runtimeLocatorPacket['schemaVersion'],
        _runtimeLocatorPacketSchemaVersion,
        'sourceRuntimeLocatorPacket.schemaVersion',
      );
      _expectEquals(
        issues,
        runtimeLocatorPacket['kind'],
        _runtimeLocatorPacketKind,
        'sourceRuntimeLocatorPacket.kind',
      );
    }

    final resolverPacketDigest = EvalProvenance.digestJson(
      runtimeResolverPacket,
    );
    final resolverSourcePlan = _map(runtimeResolverPacket['sourceReleasePlan']);
    final resolverSourceGate = _map(runtimeResolverPacket['sourceReleaseGate']);
    final resolverAssignmentRefs = [
      for (final template in _mapList(
        runtimeResolverPacket['bindingTemplates'],
      ))
        _string(template['assignmentRef']),
    ]..sort();
    final resolverAssignmentRefsDigest = EvalProvenance.digestJson(
      resolverAssignmentRefs,
    );

    for (final entry in <String, Object?>{
      'sourceResolverPacketDigest': resolverPacketDigest,
      'sourceResolverPacketStatus': runtimeResolverPacket['status'],
      'sourceResolverPacketSourceReleasePlanDigest':
          resolverSourcePlan['releasePlanDigest'],
      'sourceResolverPacketSourceReleaseGateRef':
          resolverSourceGate['releaseGateRef'],
      'sourceResolverPacketSourceReleaseGateDigest':
          resolverSourceGate['releaseGateDigest'],
      'sourceResolverPacketApprovedAssignmentRefsDigest':
          resolverSourceGate['approvedAssignmentRefsDigest'],
      'sourceResolverPacketModelClassCoverageProofSummaryDigest':
          resolverSourcePlan['modelClassCoverageProofSummaryDigest'],
      'sourceResolverPacketRequiredAssignmentRefsDigest':
          resolverAssignmentRefsDigest,
      'sourceResolverPacketRequiredBindingCount': resolverAssignmentRefs.length,
    }.entries) {
      if (source[entry.key] != entry.value) {
        issues.add(
          'runtimeObservationSource.${entry.key} must match source runtime artifacts',
        );
      }
    }
    if (mode != 'privateRuntimeStateLocator') {
      return issues;
    }
    final sourceLocatorPacket = runtimeLocatorPacket!;
    final locatorPacketDigest = EvalProvenance.digestJson(sourceLocatorPacket);
    final locatorSource = _map(sourceLocatorPacket['sourceResolverPacket']);
    final locatorRequiredRefs = _stringList(
      sourceLocatorPacket['requiredAssignmentRefs'],
    )..sort();
    final locatorRequiredRefsDigest = EvalProvenance.digestJson(
      locatorRequiredRefs,
    );
    final locatorRows = _mapList(sourceLocatorPacket['locators']);
    for (final entry in <String, Object?>{
      'sourceLocatorPacketDigest': locatorPacketDigest,
      'sourceLocatorPacketRef': sourceLocatorPacket['locatorPacketRef'],
      'sourceLocatorPacketRequiredAssignmentRefsDigest':
          locatorRequiredRefsDigest,
      'sourceLocatorPacketLocatorCount': locatorRows.length,
    }.entries) {
      if (source[entry.key] != entry.value) {
        issues.add(
          'runtimeObservationSource.${entry.key} must match source runtime artifacts',
        );
      }
    }

    for (final entry in <String, Object?>{
      'resolverPacketDigest': resolverPacketDigest,
      'status': runtimeResolverPacket['status'],
      'sourceReleasePlanDigest': resolverSourcePlan['releasePlanDigest'],
      'sourceReleaseGateRef': resolverSourceGate['releaseGateRef'],
      'sourceReleaseGateDigest': resolverSourceGate['releaseGateDigest'],
      'approvedAssignmentRefsDigest':
          resolverSourceGate['approvedAssignmentRefsDigest'],
      'requiredAssignmentRefsDigest': resolverAssignmentRefsDigest,
      'requiredRuntimeBindingCount': resolverAssignmentRefs.length,
    }.entries) {
      if (locatorSource[entry.key] != entry.value) {
        issues.add(
          'sourceRuntimeLocatorPacket.sourceResolverPacket.${entry.key} '
          'must match source resolver packet',
        );
      }
    }

    if (locatorRequiredRefsDigest != resolverAssignmentRefsDigest) {
      issues.add(
        'sourceRuntimeLocatorPacket.requiredAssignmentRefs must match source resolver packet binding refs',
      );
    }
    if (locatorRows.length != resolverAssignmentRefs.length) {
      issues.add(
        'sourceRuntimeLocatorPacket.locators.length must match source resolver packet binding count',
      );
    }
    return issues;
  }

  static List<String> validate(Map<String, dynamic> verification) {
    final issues = <String>[];
    _expectEquals(
      issues,
      verification['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, verification['kind'], kind, 'kind');
    _expectIsoDate(issues, verification['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(
      issues,
      verification['status'],
      'status',
    );
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    _expectDigest(
      issues,
      verification['runtimeVerificationRef'],
      'runtimeVerificationRef',
    );
    final sourceReleasePlan = _expectMap(
      issues,
      verification['sourceReleasePlan'],
      'sourceReleasePlan',
    );
    _validateSource(issues, sourceReleasePlan, 'sourceReleasePlan');
    final sourceReleaseGate = _expectMap(
      issues,
      verification['sourceReleaseGate'],
      'sourceReleaseGate',
    );
    _validateSource(issues, sourceReleaseGate, 'sourceReleaseGate');
    final runtimeResolverSnapshot = _expectMap(
      issues,
      verification['runtimeResolverSnapshot'],
      'runtimeResolverSnapshot',
    );
    _validateRuntimeResolverSnapshotSummary(
      issues,
      runtimeResolverSnapshot,
    );
    _validateSummary(
      issues,
      _expectMap(issues, verification['summary'], 'summary'),
    );
    _validatePrivacy(
      issues,
      _expectMap(issues, verification['privacy'], 'privacy'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, verification['limitations'], 'limitations'),
    );
    _validateExpectedAssignments(
      issues,
      _expectList(
        issues,
        verification['expectedAssignments'],
        'expectedAssignments',
      ),
      'expectedAssignments',
    );
    _validatePublicRuntimeBindings(
      issues,
      _expectList(
        issues,
        verification['observedRuntimeBindings'],
        'observedRuntimeBindings',
      ),
      'observedRuntimeBindings',
    );
    _expectDigestList(
      issues,
      verification['verifiedAssignmentRefs'],
      'verifiedAssignmentRefs',
    );
    final issueList = _expectList(issues, verification['issues'], 'issues');
    _validateIssues(issues, issueList);
    _validateCommands(
      issues,
      _expectList(
        issues,
        verification['recommendedCommands'],
        'recommendedCommands',
      ),
      'recommendedCommands',
      expectedCommands: status == null ? null : _recommendedCommands(status),
    );
    _validateSourceSummaryConsistency(
      issues,
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseGate: sourceReleaseGate,
      runtimeResolverSnapshot: runtimeResolverSnapshot,
      issueList: issueList,
    );
    _validateDerivedRuntimeState(issues, verification);
    _validateRuntimeVerificationRef(issues, verification);
    _validateNoPrivatePayloads(issues, verification, 'runtimeVerification');
    return issues;
  }

  static void assertValid(Map<String, dynamic> verification) {
    final issues = validate(verification);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case runtime verification:\n${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstRuntimeResolverSnapshot(
    Map<String, dynamic> verification, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> runtimeResolverSnapshot,
    Map<String, dynamic>? runtimeResolverPacket,
    Map<String, dynamic>? runtimeLocatorPacket,
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validate(verification);
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
    final releaseGateStatus = _nonEmptyOrUnknown(releaseGate['status']);
    final releaseGateIssues = [
      ...(releaseReviewBundles.isEmpty
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
            )),
      if (sourceRoadmap != null &&
          releaseGateStatus == _approvedGateStatus &&
          releaseReviewBundles.isEmpty)
        'release gate review sources must be supplied for source-aware runtime verification',
    ];
    final snapshotIssues = validateRuntimeResolverSnapshot(
      runtimeResolverSnapshot,
    );
    final snapshotSourceArtifactIssues =
        validateRuntimeResolverSnapshotSourceArtifacts(
          runtimeResolverSnapshot,
          runtimeResolverPacket: runtimeResolverPacket,
          runtimeLocatorPacket: runtimeLocatorPacket,
        );
    if (releasePlanIssues.isNotEmpty) {
      issues.add('source release plan contract is invalid');
    }
    if (releaseGateIssues.isNotEmpty) {
      issues.add('source release gate contract is invalid');
    }
    if (snapshotIssues.isNotEmpty) {
      issues.add('source runtime resolver snapshot contract is invalid');
    }
    for (final issue in snapshotSourceArtifactIssues) {
      issues.add(
        'source runtime resolver snapshot artifact binding is invalid: $issue',
      );
    }

    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final releaseGateDigest = EvalProvenance.digestJson(releaseGate);
    final snapshotDigest = EvalProvenance.digestJson(runtimeResolverSnapshot);
    final sourcePlan = _map(verification['sourceReleasePlan']);
    final sourceGate = _map(verification['sourceReleaseGate']);
    final snapshotSource = _map(verification['runtimeResolverSnapshot']);

    void expectSource({
      required Object? actual,
      required Object? expected,
      required String message,
    }) {
      if (actual != expected) issues.add(message);
    }

    expectSource(
      actual: sourcePlan['releasePlanDigest'],
      expected: releasePlanDigest,
      message: 'sourceReleasePlan.releasePlanDigest must match releasePlan',
    );
    expectSource(
      actual: sourceGate['releaseGateRef'],
      expected: releaseGate['releaseGateRef'],
      message: 'sourceReleaseGate.releaseGateRef must match releaseGate',
    );
    expectSource(
      actual: sourceGate['releaseGateDigest'],
      expected: releaseGateDigest,
      message: 'sourceReleaseGate.releaseGateDigest must match releaseGate',
    );
    expectSource(
      actual: snapshotSource['runtimeResolverSnapshotRef'],
      expected: runtimeResolverSnapshot['runtimeResolverSnapshotRef'],
      message:
          'runtimeResolverSnapshot.runtimeResolverSnapshotRef must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['snapshotDigest'],
      expected: snapshotDigest,
      message:
          'runtimeResolverSnapshot.snapshotDigest must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['capturedAt'],
      expected: runtimeResolverSnapshot['capturedAt'],
      message: 'runtimeResolverSnapshot.capturedAt must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['sourceReleasePlanDigest'],
      expected: releasePlanDigest,
      message:
          'runtimeResolverSnapshot.sourceReleasePlanDigest must match releasePlan',
    );
    expectSource(
      actual: snapshotSource['sourceReleaseGateRef'],
      expected: releaseGate['releaseGateRef'],
      message:
          'runtimeResolverSnapshot.sourceReleaseGateRef must match releaseGate',
    );
    expectSource(
      actual: snapshotSource['sourceReleaseGateDigest'],
      expected: releaseGateDigest,
      message:
          'runtimeResolverSnapshot.sourceReleaseGateDigest must match releaseGate',
    );
    expectSource(
      actual: snapshotSource['approvedAssignmentRefsDigest'],
      expected: runtimeResolverSnapshot['approvedAssignmentRefsDigest'],
      message:
          'runtimeResolverSnapshot.approvedAssignmentRefsDigest must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['modelClassCoverageProofSummaryDigest'],
      expected: runtimeResolverSnapshot['modelClassCoverageProofSummaryDigest'],
      message:
          'runtimeResolverSnapshot.modelClassCoverageProofSummaryDigest must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['runtimeObservationSourceDigest'],
      expected: EvalProvenance.digestJson(
        _map(runtimeResolverSnapshot['runtimeObservationSource']),
      ),
      message:
          'runtimeResolverSnapshot.runtimeObservationSourceDigest must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['contractIssueCount'],
      expected: snapshotIssues.length + snapshotSourceArtifactIssues.length,
      message:
          'runtimeResolverSnapshot.contractIssueCount must match source snapshot',
    );
    expectSource(
      actual: snapshotSource['runtimeBindingCount'],
      expected: _mapList(runtimeResolverSnapshot['runtimeBindings']).length,
      message:
          'runtimeResolverSnapshot.runtimeBindingCount must match source snapshot',
    );

    final expectedAssignments = [
      for (final assignment in _expectedAssignmentsForSources(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
      ))
        _expectedAssignment(assignment),
    ];
    final observedBindings = [
      for (final binding in _mapList(
        runtimeResolverSnapshot['runtimeBindings'],
      ))
        _observedRuntimeBinding(binding),
    ];
    if (EvalProvenance.digestJson(
          _mapList(verification['expectedAssignments']),
        ) !=
        EvalProvenance.digestJson(expectedAssignments)) {
      issues.add('expectedAssignments must match releasePlan and releaseGate');
    }
    if (EvalProvenance.digestJson(
          _mapList(verification['observedRuntimeBindings']),
        ) !=
        EvalProvenance.digestJson(observedBindings)) {
      issues.add(
        'observedRuntimeBindings must match source runtime resolver snapshot',
      );
    }
    return issues;
  }

  static void assertMatchesRuntimeResolverSnapshot(
    Map<String, dynamic> verification, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> runtimeResolverSnapshot,
    Map<String, dynamic>? runtimeResolverPacket,
    Map<String, dynamic>? runtimeLocatorPacket,
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validateAgainstRuntimeResolverSnapshot(
      verification,
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeResolverSnapshot: runtimeResolverSnapshot,
      runtimeResolverPacket: runtimeResolverPacket,
      runtimeLocatorPacket: runtimeLocatorPacket,
      releaseReviewBundles: releaseReviewBundles,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case runtime verification source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static List<Map<String, dynamic>> _runtimeIssues({
    required List<String> releasePlanIssues,
    required List<String> releaseGateIssues,
    required List<String> resolverSnapshotIssues,
    required String releasePlanDigest,
    required String releaseGateDigest,
    required String releaseGateRef,
    required String approvedAssignmentRefsDigest,
    required String releasePlanAssignmentRefsDigest,
    required String modelClassCoverageProofSummaryDigest,
    required String releaseGateStatus,
    required Map<String, dynamic> releaseGate,
    required Map<String, dynamic> runtimeResolverSnapshot,
    required List<Map<String, dynamic>> expectedAssignments,
    required List<Map<String, dynamic>> runtimeBindings,
  }) {
    final issues = <Map<String, dynamic>>[
      for (final issue in releasePlanIssues)
        <String, dynamic>{
          'code': 'runtime.releasePlanContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in releaseGateIssues)
        <String, dynamic>{
          'code': 'runtime.releaseGateContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in resolverSnapshotIssues)
        <String, dynamic>{
          'code': 'runtime.resolverSnapshotContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (_string(
            _map(releaseGate['sourceReleasePlan'])['releasePlanDigest'],
          ) !=
          releasePlanDigest)
        const <String, dynamic>{
          'code': 'runtime.releaseGateSourceMismatch',
          'severity': 'blocking',
        },
      if (_string(
            _map(releaseGate['sourceReleasePlan'])['assignmentRefsDigest'],
          ) !=
          releasePlanAssignmentRefsDigest)
        const <String, dynamic>{
          'code': 'runtime.releaseGateAssignmentRefsMismatch',
          'severity': 'blocking',
        },
      if (releaseGateStatus == _approvedGateStatus &&
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
          'code': 'runtime.releaseGateApprovedAssignmentRefsMismatch',
          'severity': 'blocking',
        },
      if (_string(
            _map(
              releaseGate['sourceReleasePlan'],
            )['modelClassCoverageProofSummaryDigest'],
          ) !=
          modelClassCoverageProofSummaryDigest)
        const <String, dynamic>{
          'code': 'runtime.releaseGateProofSummaryMismatch',
          'severity': 'blocking',
        },
      if (releaseGateIssues.isEmpty && releaseGateStatus != _approvedGateStatus)
        <String, dynamic>{
          'code': 'runtime.releaseGateNotApproved',
          'severity': 'blocking',
          'releaseGateStatus': releaseGateStatus,
        },
      if (resolverSnapshotIssues.isEmpty &&
          _string(runtimeResolverSnapshot['sourceReleasePlanDigest']) !=
              releasePlanDigest)
        const <String, dynamic>{
          'code': 'runtime.resolverSnapshotReleasePlanMismatch',
          'severity': 'blocking',
        },
      if (resolverSnapshotIssues.isEmpty &&
          _string(runtimeResolverSnapshot['sourceReleaseGateRef']) !=
              releaseGateRef)
        const <String, dynamic>{
          'code': 'runtime.resolverSnapshotReleaseGateRefMismatch',
          'severity': 'blocking',
        },
      if (resolverSnapshotIssues.isEmpty &&
          _string(runtimeResolverSnapshot['sourceReleaseGateDigest']) !=
              releaseGateDigest)
        const <String, dynamic>{
          'code': 'runtime.resolverSnapshotReleaseGateDigestMismatch',
          'severity': 'blocking',
        },
      if (resolverSnapshotIssues.isEmpty &&
          _string(runtimeResolverSnapshot['approvedAssignmentRefsDigest']) !=
              approvedAssignmentRefsDigest)
        const <String, dynamic>{
          'code': 'runtime.resolverSnapshotAssignmentRefsMismatch',
          'severity': 'blocking',
        },
      if (resolverSnapshotIssues.isEmpty &&
          _string(
                runtimeResolverSnapshot['modelClassCoverageProofSummaryDigest'],
              ) !=
              modelClassCoverageProofSummaryDigest)
        const <String, dynamic>{
          'code': 'runtime.resolverSnapshotProofSummaryMismatch',
          'severity': 'blocking',
        },
    ];
    if (issues.isNotEmpty) return issues;

    final expectedByRef = {
      for (final assignment in expectedAssignments)
        _string(assignment['assignmentRef']): assignment,
    };
    final bindingsByRef = <String, List<Map<String, dynamic>>>{};
    for (final binding in runtimeBindings) {
      final ref = _string(binding['assignmentRef']);
      bindingsByRef.putIfAbsent(ref, () => []).add(binding);
      if (!expectedByRef.containsKey(ref)) {
        issues.add(<String, dynamic>{
          'code': 'runtime.unapprovedRuntimeBinding',
          'severity': 'blocking',
          'assignmentRef': ref,
          'issueKind': 'unapproved',
        });
      }
    }
    for (final entry in expectedByRef.entries) {
      final bindings = bindingsByRef[entry.key] ?? const [];
      if (bindings.isEmpty) {
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentMissing',
          'severity': 'blocking',
          'assignmentRef': entry.key,
          'issueKind': 'missing',
        });
        continue;
      }
      if (bindings.length > 1) {
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentDuplicate',
          'severity': 'blocking',
          'assignmentRef': entry.key,
          'issueKind': 'duplicate',
        });
        continue;
      }
      _compareBinding(
        issues: issues,
        expected: entry.value,
        binding: bindings.single,
      );
    }
    return issues;
  }

  static void _compareBinding({
    required List<Map<String, dynamic>> issues,
    required Map<String, dynamic> expected,
    required Map<String, dynamic> binding,
  }) {
    final assignmentRef = _string(expected['assignmentRef']);
    for (final field in const [
      'scopeKey',
      'targetSurface',
      'primaryCapabilityId',
      'agentKind',
      'modelClass',
      'promptVariantName',
      'modelClassCoverageProofRef',
      'modelClassCoverageClassRef',
      'workOrderBatchRef',
      'modelClassCoverageRef',
      'modelClassCoverageDigest',
      'sourceWorkOrderDigest',
    ]) {
      if (_string(expected[field]) != _string(binding[field])) {
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentDrift',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'field': field,
          'issueKind': 'drift',
        });
      }
    }
    final productionAgentKind = _productionAgentKind(
      _string(expected['agentKind']),
    );
    if (productionAgentKind == null) {
      issues.add(<String, dynamic>{
        'code': 'runtime.unsupportedAgentKind',
        'severity': 'blocking',
        'assignmentRef': assignmentRef,
        'agentKind': _string(expected['agentKind']),
        'issueKind': 'unsupported',
      });
    } else if (_string(binding['productionAgentKind']) != productionAgentKind) {
      issues.add(<String, dynamic>{
        'code': 'runtime.productionAgentKindMismatch',
        'severity': 'blocking',
        'assignmentRef': assignmentRef,
        'expectedProductionAgentKind': productionAgentKind,
        'observedProductionAgentKind': _string(binding['productionAgentKind']),
        'issueKind': 'drift',
      });
    }

    final expectedDigests = _map(binding['expected']);
    final observedDigests = _map(binding['observed']);
    for (final field in _runtimeDigestFields) {
      if (_string(expectedDigests[field]) != _string(observedDigests[field])) {
        issues.add(<String, dynamic>{
          'code': 'runtime.effectiveBindingDrift',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'field': field,
          'issueKind': 'drift',
        });
      }
    }
    if (binding['shadowedTemplateOverride'] == true) {
      issues.add(<String, dynamic>{
        'code': 'runtime.shadowedTemplateOverride',
        'severity': 'blocking',
        'assignmentRef': assignmentRef,
        'issueKind': 'drift',
      });
    }
    final resolutionStatus = _string(binding['resolutionStatus']);
    switch (resolutionStatus) {
      case 'applied':
        break;
      case 'notApplied':
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentNotApplied',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'issueKind': 'notApplied',
        });
      case 'partiallyApplied':
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentPartiallyApplied',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'issueKind': 'partial',
        });
      case 'unsupported':
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentUnsupported',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'issueKind': 'unsupported',
        });
      default:
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentResolutionUnknown',
          'severity': 'blocking',
          'assignmentRef': assignmentRef,
          'issueKind': 'drift',
        });
    }
  }

  static String _status({
    required List<String> releasePlanIssues,
    required List<String> releaseGateIssues,
    required List<String> resolverSnapshotIssues,
    required String releaseGateStatus,
    required List<Map<String, dynamic>> runtimeIssues,
  }) {
    if (releasePlanIssues.isNotEmpty ||
        releaseGateIssues.isNotEmpty ||
        resolverSnapshotIssues.isNotEmpty ||
        runtimeIssues.any(
          (issue) => {
            'runtime.releaseGateSourceMismatch',
            'runtime.releaseGateAssignmentRefsMismatch',
            'runtime.releaseGateApprovedAssignmentRefsMismatch',
            'runtime.releaseGateProofSummaryMismatch',
            'runtime.resolverSnapshotReleasePlanMismatch',
            'runtime.resolverSnapshotReleaseGateRefMismatch',
            'runtime.resolverSnapshotReleaseGateDigestMismatch',
            'runtime.resolverSnapshotAssignmentRefsMismatch',
            'runtime.resolverSnapshotProofSummaryMismatch',
          }.contains(_string(issue['code'])),
        )) {
      return 'invalid';
    }
    if (releaseGateStatus != _approvedGateStatus) return 'blockedReleaseGate';
    if (runtimeIssues.isEmpty) return 'verified';
    if (runtimeIssues.every((issue) => issue['issueKind'] == 'notApplied')) {
      return 'notApplied';
    }
    return 'drift';
  }

  static List<String> _verifiedRefs({
    required List<Map<String, dynamic>> expectedAssignments,
    required List<Map<String, dynamic>> runtimeBindings,
    required List<Map<String, dynamic>> issues,
  }) {
    if (issues.any(_isSourceBlockingIssue)) return const [];
    final blockedRefs = {
      for (final issue in issues) _string(issue['assignmentRef']),
    }..remove('');
    final bindingByRef = {
      for (final binding in runtimeBindings)
        _string(binding['assignmentRef']): binding,
    };
    return [
      for (final assignment in expectedAssignments)
        if (!blockedRefs.contains(_string(assignment['assignmentRef'])) &&
            _string(
                  bindingByRef[_string(
                    assignment['assignmentRef'],
                  )]?['resolutionStatus'],
                ) ==
                'applied')
          _string(assignment['assignmentRef']),
    ]..sort();
  }

  static Map<String, dynamic> _expectedAssignment(
    Map<String, dynamic> assignment,
  ) {
    final agentKind = _string(assignment['agentKind']);
    return <String, dynamic>{
      'assignmentRef': _string(assignment['assignmentRef']),
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
      'expectedResolutionStatus': 'applied',
    };
  }

  static Map<String, dynamic> _observedRuntimeBinding(
    Map<String, dynamic> binding,
  ) {
    return <String, dynamic>{
      'assignmentRef': _string(binding['assignmentRef']),
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
      'modelClassCoverageDigest': _string(binding['modelClassCoverageDigest']),
      'sourceWorkOrderDigest': _string(binding['sourceWorkOrderDigest']),
      'resolutionStatus': _string(binding['resolutionStatus']),
      'runtimeTargetRef': _string(binding['runtimeTargetRef']),
      'resolverBindingDigest': _string(binding['resolverBindingDigest']),
      'expected': _publicDigestMap(_map(binding['expected'])),
      'observed': _publicDigestMap(_map(binding['observed'])),
      'privateRuntimeIdsOmitted': true,
      'rawPromptTextOmitted': true,
      'rawDirectiveTextOmitted': true,
    };
  }

  static Map<String, dynamic> _publicDigestMap(Map<String, dynamic> value) {
    return <String, dynamic>{
      for (final field in _runtimeDigestFields) field: _string(value[field]),
    };
  }

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final modes = switch (status) {
      'blockedReleaseGate' => const [
        ('release-gate', 'eval/run_level2.sh release-gate'),
      ],
      _ => const [
        ('runtime-verify', 'eval/run_level2.sh runtime-verify'),
      ],
    };
    return [
      for (final command in modes)
        <String, dynamic>{
          'mode': command.$1,
          'command': command.$2,
        },
    ];
  }

  static int _issueCount(List<Map<String, dynamic>> issues, String kind) =>
      issues.where((issue) => issue['issueKind'] == kind).length;

  static void _validateResolverSnapshotSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
    List<dynamic>? bindings,
  ) {
    if (summary == null) return;
    _expectNonNegativeInt(
      issues,
      summary['runtimeBindingCount'],
      'summary.runtimeBindingCount',
    );
    if (bindings != null &&
        summary['runtimeBindingCount'] is int &&
        summary['runtimeBindingCount'] != bindings.length) {
      issues.add(
        'summary.runtimeBindingCount must match runtimeBindings.length',
      );
    }
  }

  static void _validateResolverSnapshotPrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'rawPromptsOmitted': true,
      'rawDirectivesOmitted': true,
      'apiKeysOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
      'publicExportRequiresSanitization': true,
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

  static void _validateResolverSnapshotLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'runtimeStateObservedOnly': true,
      'runtimeConfigurationAppliedByHarness': false,
      'aiConfigMutationsWrittenByHarness': false,
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

  static void _validateRuntimeObservationSource(
    List<String> issues,
    Map<String, dynamic>? source,
    String path,
  ) {
    if (source == null) return;
    final mode = _expectNonEmptyString(issues, source['mode'], '$path.mode');
    if (mode != null && !_allowedRuntimeObservationSourceModes.contains(mode)) {
      issues.add('$path.mode must be a supported runtime observation mode');
    }
    for (final field in const [
      'sourceResolverPacketDigest',
      'sourceResolverPacketSourceReleasePlanDigest',
      'sourceResolverPacketSourceReleaseGateRef',
      'sourceResolverPacketSourceReleaseGateDigest',
      'sourceResolverPacketApprovedAssignmentRefsDigest',
      'sourceResolverPacketModelClassCoverageProofSummaryDigest',
      'sourceResolverPacketRequiredAssignmentRefsDigest',
    ]) {
      _expectDigest(issues, source[field], '$path.$field');
    }
    _expectSafePublicToken(
      issues,
      source['sourceResolverPacketStatus'],
      '$path.sourceResolverPacketStatus',
    );
    _expectNonNegativeInt(
      issues,
      source['sourceResolverPacketRequiredBindingCount'],
      '$path.sourceResolverPacketRequiredBindingCount',
    );
    final locatorDigest = source['sourceLocatorPacketDigest'];
    final locatorRef = source['sourceLocatorPacketRef'];
    final locatorRefsDigest =
        source['sourceLocatorPacketRequiredAssignmentRefsDigest'];
    final locatorCount = source['sourceLocatorPacketLocatorCount'];
    if (mode == 'privateRuntimeStateLocator') {
      _expectDigest(
        issues,
        locatorDigest,
        '$path.sourceLocatorPacketDigest',
      );
      _expectDigest(
        issues,
        locatorRef,
        '$path.sourceLocatorPacketRef',
      );
      _expectDigest(
        issues,
        locatorRefsDigest,
        '$path.sourceLocatorPacketRequiredAssignmentRefsDigest',
      );
      _expectNonNegativeInt(
        issues,
        locatorCount,
        '$path.sourceLocatorPacketLocatorCount',
      );
      return;
    }
    if (locatorDigest != null ||
        locatorRef != null ||
        locatorRefsDigest != null ||
        locatorCount != null) {
      issues.add(
        '$path locator packet fields require privateRuntimeStateLocator mode',
      );
    }
  }

  static void _validateRuntimeObservationSourceConsistency(
    List<String> issues, {
    required Map<String, dynamic> snapshot,
    required Map<String, dynamic>? source,
  }) {
    if (source == null) return;
    for (final entry in const [
      (
        'sourceResolverPacketSourceReleasePlanDigest',
        'sourceReleasePlanDigest',
      ),
      ('sourceResolverPacketSourceReleaseGateRef', 'sourceReleaseGateRef'),
      (
        'sourceResolverPacketSourceReleaseGateDigest',
        'sourceReleaseGateDigest',
      ),
      (
        'sourceResolverPacketApprovedAssignmentRefsDigest',
        'approvedAssignmentRefsDigest',
      ),
      (
        'sourceResolverPacketModelClassCoverageProofSummaryDigest',
        'modelClassCoverageProofSummaryDigest',
      ),
      (
        'sourceResolverPacketRequiredAssignmentRefsDigest',
        'approvedAssignmentRefsDigest',
      ),
    ]) {
      if (_string(source[entry.$1]) != _string(snapshot[entry.$2])) {
        issues.add(
          'runtimeObservationSource.${entry.$1} must match '
          'snapshot.${entry.$2}',
        );
      }
    }
    final locatorRefsDigest =
        source['sourceLocatorPacketRequiredAssignmentRefsDigest'];
    if (_string(source['mode']) == 'privateRuntimeStateLocator' &&
        locatorRefsDigest is String &&
        locatorRefsDigest !=
            _string(
              source['sourceResolverPacketRequiredAssignmentRefsDigest'],
            )) {
      issues.add(
        'runtimeObservationSource.sourceLocatorPacketRequiredAssignmentRefsDigest '
        'must match sourceResolverPacketRequiredAssignmentRefsDigest',
      );
    }
    if (_string(source['mode']) == 'privateRuntimeStateLocator') {
      final locatorCount = source['sourceLocatorPacketLocatorCount'];
      final requiredBindingCount =
          source['sourceResolverPacketRequiredBindingCount'];
      final runtimeBindingCount = _mapList(snapshot['runtimeBindings']).length;
      if (locatorCount is int &&
          requiredBindingCount is int &&
          locatorCount != requiredBindingCount) {
        issues.add(
          'runtimeObservationSource.sourceLocatorPacketLocatorCount must match '
          'sourceResolverPacketRequiredBindingCount',
        );
      }
      if (locatorCount is int && locatorCount != runtimeBindingCount) {
        issues.add(
          'runtimeObservationSource.sourceLocatorPacketLocatorCount must match '
          'runtimeBindings.length',
        );
      }
    }
  }

  static void _validateRuntimeBindings(
    List<String> issues,
    List<dynamic>? bindings,
    String path,
  ) {
    if (bindings == null) return;
    for (final (index, value) in bindings.indexed) {
      final binding = _expectMap(issues, value, '$path[$index]');
      if (binding == null) continue;
      _validateRuntimeBinding(issues, binding, '$path[$index]');
    }
  }

  static void _validateRuntimeBinding(
    List<String> issues,
    Map<String, dynamic> binding,
    String path,
  ) {
    for (final field in const [
      'assignmentRef',
      'scopeKey',
      'modelClassCoverageProofRef',
      'modelClassCoverageClassRef',
      'workOrderBatchRef',
      'modelClassCoverageDigest',
      'sourceWorkOrderDigest',
      'runtimeTargetRef',
      'resolverBindingDigest',
    ]) {
      _expectDigest(issues, binding[field], '$path.$field');
    }
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
    final resolutionStatus = _expectNonEmptyString(
      issues,
      binding['resolutionStatus'],
      '$path.resolutionStatus',
    );
    if (resolutionStatus != null &&
        !_allowedResolutionStatuses.contains(resolutionStatus)) {
      issues.add('$path.resolutionStatus must be supported');
    }
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
    if (binding['resolverBindingDigest'] !=
        runtimeResolverBindingDigest(binding)) {
      issues.add(
        '$path.resolverBindingDigest must match resolver binding subject digest',
      );
    }
    final privateRuntimeIds = binding['privateRuntimeIds'];
    if (privateRuntimeIds != null) {
      _validatePrivateRuntimeIds(
        issues,
        privateRuntimeIds,
        '$path.privateRuntimeIds',
      );
    }
  }

  static void _validateDigestMap(
    List<String> issues,
    Map<String, dynamic>? digests,
    String path,
  ) {
    if (digests == null) return;
    for (final field in _runtimeDigestFields) {
      _expectDigest(issues, digests[field], '$path.$field');
    }
  }

  static String runtimeResolverBindingDigest(Map<String, dynamic> binding) =>
      EvalProvenance.digestJson(_runtimeResolverBindingSubject(binding));

  static Map<String, dynamic> _runtimeResolverBindingSubject(
    Map<String, dynamic> binding,
  ) => <String, dynamic>{
    'assignmentRef': _string(binding['assignmentRef']),
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
    'modelClassCoverageDigest': _string(binding['modelClassCoverageDigest']),
    'sourceWorkOrderDigest': _string(binding['sourceWorkOrderDigest']),
    'runtimeTargetRef': _string(binding['runtimeTargetRef']),
    'expected': _publicDigestMap(_map(binding['expected'])),
    'observed': _publicDigestMap(_map(binding['observed'])),
    'resolutionStatus': _string(binding['resolutionStatus']),
    'shadowedTemplateOverride': binding['shadowedTemplateOverride'] == true,
  };

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

  static void _validateRuntimeResolverSnapshotSummary(
    List<String> issues,
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null) return;
    _expectEquals(
      issues,
      snapshot['kind'],
      resolverSnapshotKind,
      'runtimeResolverSnapshot.kind',
    );
    _expectEquals(
      issues,
      snapshot['schemaVersion'],
      resolverSnapshotSchemaVersion,
      'runtimeResolverSnapshot.schemaVersion',
    );
    _expectIsoDate(
      issues,
      snapshot['capturedAt'],
      'runtimeResolverSnapshot.capturedAt',
    );
    for (final field in const [
      'runtimeResolverSnapshotRef',
      'snapshotDigest',
      'sourceReleasePlanDigest',
      'sourceReleaseGateRef',
      'sourceReleaseGateDigest',
      'approvedAssignmentRefsDigest',
      'modelClassCoverageProofSummaryDigest',
      'runtimeObservationSourceDigest',
    ]) {
      _expectDigest(issues, snapshot[field], 'runtimeResolverSnapshot.$field');
    }
    for (final field in const [
      'contractIssueCount',
      'runtimeBindingCount',
    ]) {
      _expectNonNegativeInt(
        issues,
        snapshot[field],
        'runtimeResolverSnapshot.$field',
      );
    }
  }

  static void _validateRuntimeVerificationRef(
    List<String> issues,
    Map<String, dynamic> verification,
  ) {
    final expectedRef = runtimeVerificationRef(verification);
    if (verification['runtimeVerificationRef'] != expectedRef) {
      issues.add(
        'runtimeVerificationRef must match runtime verification subject digest',
      );
    }
  }

  static String runtimeVerificationRef(Map<String, dynamic> verification) {
    final sourcePlan = _map(verification['sourceReleasePlan']);
    final sourceGate = _map(verification['sourceReleaseGate']);
    final resolverSnapshot = _map(verification['runtimeResolverSnapshot']);
    return _runtimeVerificationRef(
      status: _string(verification['status']),
      sourceReleasePlanDigest: _string(sourcePlan['releasePlanDigest']),
      sourceReleaseGateDigest: _string(sourceGate['releaseGateDigest']),
      runtimeResolverSnapshotDigest: _string(
        resolverSnapshot['snapshotDigest'],
      ),
      runtimeResolverSnapshotRef: _string(
        resolverSnapshot['runtimeResolverSnapshotRef'],
      ),
      verifiedAssignmentRefs: _stringList(
        verification['verifiedAssignmentRefs'],
      ),
      modelClassCoverageProofSummaryDigest: _string(
        sourcePlan['modelClassCoverageProofSummaryDigest'],
      ),
      summary: _map(verification['summary']),
      expectedAssignments: _mapList(verification['expectedAssignments']),
      observedRuntimeBindings: _mapList(
        verification['observedRuntimeBindings'],
      ),
      issues: _mapList(verification['issues']),
    );
  }

  static void _validateDerivedRuntimeState(
    List<String> issues,
    Map<String, dynamic> verification,
  ) {
    final expectedAssignments = _mapList(verification['expectedAssignments']);
    final observedRuntimeBindings = _mapList(
      verification['observedRuntimeBindings'],
    );
    final actualIssues = _mapList(verification['issues']);
    final derivedAssignmentIssues = _publicRuntimeIssues(
      expectedAssignments: expectedAssignments,
      runtimeBindings: observedRuntimeBindings,
    );
    final hasGlobalIssue = actualIssues.any(
      (issue) => _string(issue['assignmentRef']).isEmpty,
    );
    final hasSourceBlockingIssue =
        hasGlobalIssue &&
        actualIssues
            .where((issue) => _string(issue['assignmentRef']).isEmpty)
            .every(_isSourceBlockingIssue);
    final actualAssignmentIssues = [
      for (final issue in actualIssues)
        if (_string(issue['assignmentRef']).isNotEmpty) issue,
    ];
    _validateSourceBlockingIssueConsistency(
      issues,
      verification: verification,
      actualIssues: actualIssues,
    );
    if (!hasSourceBlockingIssue) {
      final actualIssueDigests = _issueDigests(actualAssignmentIssues);
      final derivedIssueDigests = _issueDigests(derivedAssignmentIssues);
      if (!_listEquals(actualIssueDigests, derivedIssueDigests)) {
        issues.add(
          'issues must match runtime verification derived assignment issues',
        );
      }
    }

    final verifiedRefs = _stringList(verification['verifiedAssignmentRefs'])
      ..sort();
    final derivedVerifiedRefs = hasSourceBlockingIssue
        ? const <String>[]
        : _verifiedRefs(
            expectedAssignments: expectedAssignments,
            runtimeBindings: observedRuntimeBindings,
            issues: derivedAssignmentIssues,
          );
    if (!_listEquals(verifiedRefs, derivedVerifiedRefs)) {
      issues.add(
        'verifiedAssignmentRefs must match derived runtime verification state',
      );
    }

    final summaryIssues = hasSourceBlockingIssue
        ? actualIssues
        : derivedAssignmentIssues;

    final summary = _map(verification['summary']);
    final expectedSummary = <String, int>{
      'expectedAssignmentCount': expectedAssignments.length,
      'runtimeBindingCount': observedRuntimeBindings.length,
      'verifiedAssignmentCount': derivedVerifiedRefs.length,
      'missingAssignmentCount': _issueCount(summaryIssues, 'missing'),
      'duplicateBindingCount': _issueCount(summaryIssues, 'duplicate'),
      'unapprovedBindingCount': _issueCount(summaryIssues, 'unapproved'),
      'unsupportedBindingCount': _issueCount(summaryIssues, 'unsupported'),
      'driftCount': _issueCount(summaryIssues, 'drift'),
      'partialBindingCount': _issueCount(summaryIssues, 'partial'),
      'notAppliedCount': _issueCount(summaryIssues, 'notApplied'),
      'issueCount': summaryIssues.length,
    };
    for (final entry in expectedSummary.entries) {
      if (summary[entry.key] != entry.value) {
        issues.add('summary.${entry.key} must match derived runtime state');
      }
    }

    final expectedStatus = _publicStatusFromIssues(summaryIssues);
    if (_string(verification['status']) != expectedStatus) {
      issues.add('status must match derived runtime verification state');
    }
  }

  static void _validateSourceBlockingIssueConsistency(
    List<String> issues, {
    required Map<String, dynamic> verification,
    required List<Map<String, dynamic>> actualIssues,
  }) {
    final sourcePlan = _map(verification['sourceReleasePlan']);
    final sourceGate = _map(verification['sourceReleaseGate']);
    final resolverSnapshot = _map(verification['runtimeResolverSnapshot']);
    final issueCodes = {
      for (final issue in actualIssues) _string(issue['code']),
    };
    void requireEvidence({
      required String issueCode,
      required bool condition,
      required String message,
    }) {
      if (!issueCodes.contains(issueCode) || condition) return;
      issues.add(message);
    }

    final releasePlanDigest = _string(sourcePlan['releasePlanDigest']);
    final proofSummaryDigest = _string(
      sourcePlan['modelClassCoverageProofSummaryDigest'],
    );
    requireEvidence(
      issueCode: 'runtime.releasePlanContractInvalid',
      condition: _intOrZero(sourcePlan['contractIssueCount']) > 0,
      message:
          'runtime.releasePlanContractInvalid issue must match sourceReleasePlan.contractIssueCount',
    );
    requireEvidence(
      issueCode: 'runtime.releaseGateContractInvalid',
      condition: _intOrZero(sourceGate['contractIssueCount']) > 0,
      message:
          'runtime.releaseGateContractInvalid issue must match sourceReleaseGate.contractIssueCount',
    );
    requireEvidence(
      issueCode: 'runtime.resolverSnapshotContractInvalid',
      condition: _intOrZero(resolverSnapshot['contractIssueCount']) > 0,
      message:
          'runtime.resolverSnapshotContractInvalid issue must match runtimeResolverSnapshot.contractIssueCount',
    );
    requireEvidence(
      issueCode: 'runtime.releaseGateSourceMismatch',
      condition:
          _string(sourceGate['sourceReleasePlanDigest']) != releasePlanDigest,
      message:
          'runtime.releaseGateSourceMismatch issue must match sourceReleaseGate.sourceReleasePlanDigest',
    );
    requireEvidence(
      issueCode: 'runtime.releaseGateProofSummaryMismatch',
      condition:
          _string(sourceGate['modelClassCoverageProofSummaryDigest']) !=
          proofSummaryDigest,
      message:
          'runtime.releaseGateProofSummaryMismatch issue must match sourceReleaseGate.modelClassCoverageProofSummaryDigest',
    );
    requireEvidence(
      issueCode: 'runtime.releaseGateNotApproved',
      condition: _string(sourceGate['status']) != _approvedGateStatus,
      message:
          'runtime.releaseGateNotApproved issue must match sourceReleaseGate.status',
    );
    requireEvidence(
      issueCode: 'runtime.releaseGateApprovedAssignmentRefsMismatch',
      condition:
          _string(sourceGate['status']) == _approvedGateStatus &&
          _intOrZero(sourceGate['approvedAssignmentRefCount']) !=
              _intOrZero(sourcePlan['assignmentCount']),
      message:
          'runtime.releaseGateApprovedAssignmentRefsMismatch issue must match sourceReleaseGate.approvedAssignmentRefCount',
    );
    requireEvidence(
      issueCode: 'runtime.resolverSnapshotReleasePlanMismatch',
      condition:
          _string(resolverSnapshot['sourceReleasePlanDigest']) !=
          releasePlanDigest,
      message:
          'runtime.resolverSnapshotReleasePlanMismatch issue must match runtimeResolverSnapshot.sourceReleasePlanDigest',
    );
    requireEvidence(
      issueCode: 'runtime.resolverSnapshotReleaseGateRefMismatch',
      condition:
          _string(resolverSnapshot['sourceReleaseGateRef']) !=
          _string(sourceGate['releaseGateRef']),
      message:
          'runtime.resolverSnapshotReleaseGateRefMismatch issue must match runtimeResolverSnapshot.sourceReleaseGateRef',
    );
    requireEvidence(
      issueCode: 'runtime.resolverSnapshotReleaseGateDigestMismatch',
      condition:
          _string(resolverSnapshot['sourceReleaseGateDigest']) !=
          _string(sourceGate['releaseGateDigest']),
      message:
          'runtime.resolverSnapshotReleaseGateDigestMismatch issue must match runtimeResolverSnapshot.sourceReleaseGateDigest',
    );
    requireEvidence(
      issueCode: 'runtime.resolverSnapshotAssignmentRefsMismatch',
      condition:
          _string(resolverSnapshot['approvedAssignmentRefsDigest']) !=
          _string(sourceGate['approvedAssignmentRefsDigest']),
      message:
          'runtime.resolverSnapshotAssignmentRefsMismatch issue must match runtimeResolverSnapshot.approvedAssignmentRefsDigest',
    );
    requireEvidence(
      issueCode: 'runtime.resolverSnapshotProofSummaryMismatch',
      condition:
          _string(resolverSnapshot['modelClassCoverageProofSummaryDigest']) !=
          proofSummaryDigest,
      message:
          'runtime.resolverSnapshotProofSummaryMismatch issue must match runtimeResolverSnapshot.modelClassCoverageProofSummaryDigest',
    );
  }

  static List<Map<String, dynamic>> _publicRuntimeIssues({
    required List<Map<String, dynamic>> expectedAssignments,
    required List<Map<String, dynamic>> runtimeBindings,
  }) {
    final issues = <Map<String, dynamic>>[];
    final expectedByRef = {
      for (final assignment in expectedAssignments)
        _string(assignment['assignmentRef']): assignment,
    };
    final bindingsByRef = <String, List<Map<String, dynamic>>>{};
    for (final binding in runtimeBindings) {
      final ref = _string(binding['assignmentRef']);
      bindingsByRef.putIfAbsent(ref, () => []).add(binding);
      if (!expectedByRef.containsKey(ref)) {
        issues.add(<String, dynamic>{
          'code': 'runtime.unapprovedRuntimeBinding',
          'severity': 'blocking',
          'assignmentRef': ref,
          'issueKind': 'unapproved',
        });
      }
    }
    for (final entry in expectedByRef.entries) {
      final bindings = bindingsByRef[entry.key] ?? const [];
      if (bindings.isEmpty) {
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentMissing',
          'severity': 'blocking',
          'assignmentRef': entry.key,
          'issueKind': 'missing',
        });
        continue;
      }
      if (bindings.length > 1) {
        issues.add(<String, dynamic>{
          'code': 'runtime.assignmentDuplicate',
          'severity': 'blocking',
          'assignmentRef': entry.key,
          'issueKind': 'duplicate',
        });
        continue;
      }
      _compareBinding(
        issues: issues,
        expected: entry.value,
        binding: bindings.single,
      );
    }
    return issues;
  }

  static List<Map<String, dynamic>> _expectedAssignmentsForSources({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
  }) {
    final approvedAssignmentRefs = _stringList(
      releaseGate['approvedAssignmentRefs'],
    ).toSet();
    return [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        if (approvedAssignmentRefs.contains(
          _string(assignment['assignmentRef']),
        ))
          assignment,
    ];
  }

  static String _publicStatusFromIssues(List<Map<String, dynamic>> issues) {
    if (issues.any(
      (issue) => {
        'runtime.releasePlanContractInvalid',
        'runtime.releaseGateContractInvalid',
        'runtime.resolverSnapshotContractInvalid',
        'runtime.releaseGateSourceMismatch',
        'runtime.releaseGateAssignmentRefsMismatch',
        'runtime.releaseGateApprovedAssignmentRefsMismatch',
        'runtime.releaseGateProofSummaryMismatch',
        'runtime.resolverSnapshotReleasePlanMismatch',
        'runtime.resolverSnapshotReleaseGateRefMismatch',
        'runtime.resolverSnapshotReleaseGateDigestMismatch',
        'runtime.resolverSnapshotAssignmentRefsMismatch',
        'runtime.resolverSnapshotProofSummaryMismatch',
      }.contains(_string(issue['code'])),
    )) {
      return 'invalid';
    }
    if (issues.any(
      (issue) => _string(issue['code']) == 'runtime.releaseGateNotApproved',
    )) {
      return 'blockedReleaseGate';
    }
    if (issues.isEmpty) return 'verified';
    if (issues.every((issue) => issue['issueKind'] == 'notApplied')) {
      return 'notApplied';
    }
    return 'drift';
  }

  static bool _isSourceBlockingIssue(Map<String, dynamic> issue) => {
    'runtime.releasePlanContractInvalid',
    'runtime.releaseGateContractInvalid',
    'runtime.resolverSnapshotContractInvalid',
    'runtime.releaseGateSourceMismatch',
    'runtime.releaseGateAssignmentRefsMismatch',
    'runtime.releaseGateApprovedAssignmentRefsMismatch',
    'runtime.releaseGateProofSummaryMismatch',
    'runtime.releaseGateNotApproved',
    'runtime.resolverSnapshotReleasePlanMismatch',
    'runtime.resolverSnapshotReleaseGateRefMismatch',
    'runtime.resolverSnapshotReleaseGateDigestMismatch',
    'runtime.resolverSnapshotAssignmentRefsMismatch',
    'runtime.resolverSnapshotProofSummaryMismatch',
  }.contains(_string(issue['code']));

  static List<String> _issueDigests(List<Map<String, dynamic>> issues) =>
      [for (final issue in issues) EvalProvenance.digestJson(issue)]..sort();

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static String runtimeResolverSnapshotRef(Map<String, dynamic> snapshot) =>
      EvalProvenance.digestJson(_runtimeResolverSnapshotSubject(snapshot));

  static void _validateRuntimeResolverSnapshotRef(
    List<String> issues,
    Map<String, dynamic> snapshot,
  ) {
    final expectedRef = runtimeResolverSnapshotRef(snapshot);
    if (snapshot['runtimeResolverSnapshotRef'] != expectedRef) {
      issues.add(
        'runtimeResolverSnapshotRef must match runtime resolver snapshot subject digest',
      );
    }
  }

  static Map<String, dynamic> _runtimeResolverSnapshotSubject(
    Map<String, dynamic> snapshot,
  ) => <String, dynamic>{
    'kind': resolverSnapshotKind,
    'schemaVersion': resolverSnapshotSchemaVersion,
    'capturedAt': _string(snapshot['capturedAt']),
    'sourceReleasePlanDigest': _string(snapshot['sourceReleasePlanDigest']),
    'sourceReleaseGateRef': _string(snapshot['sourceReleaseGateRef']),
    'sourceReleaseGateDigest': _string(snapshot['sourceReleaseGateDigest']),
    'approvedAssignmentRefsDigest': _string(
      snapshot['approvedAssignmentRefsDigest'],
    ),
    'modelClassCoverageProofSummaryDigest': _string(
      snapshot['modelClassCoverageProofSummaryDigest'],
    ),
    'runtimeObservationSourceDigest': EvalProvenance.digestJson(
      _map(snapshot['runtimeObservationSource']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(snapshot['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(snapshot['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(snapshot['limitations']),
    ),
    'runtimeBindingsDigest': EvalProvenance.digestJson(
      _mapList(snapshot['runtimeBindings']),
    ),
  };

  static String _runtimeVerificationRef({
    required String status,
    required String sourceReleasePlanDigest,
    required String sourceReleaseGateDigest,
    required String runtimeResolverSnapshotRef,
    required String runtimeResolverSnapshotDigest,
    required List<String> verifiedAssignmentRefs,
    required String modelClassCoverageProofSummaryDigest,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> expectedAssignments,
    required List<Map<String, dynamic>> observedRuntimeBindings,
    required List<Map<String, dynamic>> issues,
  }) => EvalProvenance.digestJson(<String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': status,
    'sourceReleasePlanDigest': sourceReleasePlanDigest,
    'sourceReleaseGateDigest': sourceReleaseGateDigest,
    'runtimeResolverSnapshotRef': runtimeResolverSnapshotRef,
    'runtimeResolverSnapshotDigest': runtimeResolverSnapshotDigest,
    'verifiedAssignmentRefs': verifiedAssignmentRefs,
    'modelClassCoverageProofSummaryDigest':
        modelClassCoverageProofSummaryDigest,
    'summaryDigest': EvalProvenance.digestJson(summary),
    'expectedAssignmentsDigest': EvalProvenance.digestJson(
      expectedAssignments,
    ),
    'observedRuntimeBindingsDigest': EvalProvenance.digestJson(
      observedRuntimeBindings,
    ),
    'issuesDigest': EvalProvenance.digestJson(issues),
  });

  static void _validateSourceSummaryConsistency(
    List<String> issues, {
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
    required Map<String, dynamic>? runtimeResolverSnapshot,
    required List<dynamic>? issueList,
  }) {
    if (sourceReleasePlan == null ||
        sourceReleaseGate == null ||
        runtimeResolverSnapshot == null) {
      return;
    }
    final issueCodes = {
      for (final issue in _mapList(issueList)) _string(issue['code']),
    };
    void requireMatch({
      required String actual,
      required String expected,
      required String message,
      required String allowedIssueCode,
    }) {
      if (actual == expected || issueCodes.contains(allowedIssueCode)) {
        return;
      }
      issues.add(message);
    }

    final releasePlanDigest = _string(sourceReleasePlan['releasePlanDigest']);
    final proofSummaryDigest = _string(
      sourceReleasePlan['modelClassCoverageProofSummaryDigest'],
    );
    requireMatch(
      actual: _string(sourceReleaseGate['sourceReleasePlanDigest']),
      expected: releasePlanDigest,
      message:
          'sourceReleaseGate.sourceReleasePlanDigest must match sourceReleasePlan.releasePlanDigest',
      allowedIssueCode: 'runtime.releaseGateSourceMismatch',
    );
    requireMatch(
      actual: _string(runtimeResolverSnapshot['sourceReleasePlanDigest']),
      expected: releasePlanDigest,
      message:
          'runtimeResolverSnapshot.sourceReleasePlanDigest must match sourceReleasePlan.releasePlanDigest',
      allowedIssueCode: 'runtime.resolverSnapshotReleasePlanMismatch',
    );
    requireMatch(
      actual: _string(
        sourceReleaseGate['modelClassCoverageProofSummaryDigest'],
      ),
      expected: proofSummaryDigest,
      message:
          'sourceReleaseGate.modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      allowedIssueCode: 'runtime.releaseGateProofSummaryMismatch',
    );
    if (_string(sourceReleaseGate['status']) == _approvedGateStatus &&
        _intOrZero(sourceReleaseGate['approvedAssignmentRefCount']) !=
            _intOrZero(sourceReleasePlan['assignmentCount']) &&
        !issueCodes.contains(
          'runtime.releaseGateApprovedAssignmentRefsMismatch',
        ) &&
        !issueCodes.contains('runtime.releaseGateAssignmentRefsMismatch')) {
      issues.add(
        'sourceReleaseGate.approvedAssignmentRefCount must match sourceReleasePlan.assignmentCount',
      );
    }
    requireMatch(
      actual: _string(
        runtimeResolverSnapshot['modelClassCoverageProofSummaryDigest'],
      ),
      expected: proofSummaryDigest,
      message:
          'runtimeResolverSnapshot.modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      allowedIssueCode: 'runtime.resolverSnapshotProofSummaryMismatch',
    );
    requireMatch(
      actual: _string(runtimeResolverSnapshot['sourceReleaseGateRef']),
      expected: _string(sourceReleaseGate['releaseGateRef']),
      message:
          'runtimeResolverSnapshot.sourceReleaseGateRef must match sourceReleaseGate',
      allowedIssueCode: 'runtime.resolverSnapshotReleaseGateRefMismatch',
    );
    requireMatch(
      actual: _string(runtimeResolverSnapshot['sourceReleaseGateDigest']),
      expected: _string(sourceReleaseGate['releaseGateDigest']),
      message:
          'runtimeResolverSnapshot.sourceReleaseGateDigest must match sourceReleaseGate',
      allowedIssueCode: 'runtime.resolverSnapshotReleaseGateDigestMismatch',
    );
    requireMatch(
      actual: _string(runtimeResolverSnapshot['approvedAssignmentRefsDigest']),
      expected: _string(sourceReleaseGate['approvedAssignmentRefsDigest']),
      message:
          'runtimeResolverSnapshot.approvedAssignmentRefsDigest must match sourceReleaseGate',
      allowedIssueCode: 'runtime.resolverSnapshotAssignmentRefsMismatch',
    );
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'expectedAssignmentCount',
      'runtimeBindingCount',
      'verifiedAssignmentCount',
      'missingAssignmentCount',
      'duplicateBindingCount',
      'unapprovedBindingCount',
      'unsupportedBindingCount',
      'driftCount',
      'partialBindingCount',
      'notAppliedCount',
      'issueCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validatePrivacy(
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

  static void _validateLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesReleasePlanGateAndPrivateResolverSnapshotOnly': true,
      'privateRuntimeLocatorSnapshotsRequireSourcePackets': true,
      'privateResolverSnapshotIsNotAPublicArtifact': true,
      'runtimeStateObservedOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'liveCommandsCreated': false,
      'runtimeConfigurationAppliedByHarness': false,
      'aiConfigMutationsWrittenByHarness': false,
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

  static void _validateExpectedAssignments(
    List<String> issues,
    List<dynamic>? assignments,
    String path,
  ) {
    if (assignments == null) return;
    for (final (index, value) in assignments.indexed) {
      final assignment = _expectMap(issues, value, '$path[$index]');
      if (assignment == null) continue;
      for (final field in const [
        'assignmentRef',
        'scopeKey',
        'modelClassCoverageProofRef',
        'modelClassCoverageClassRef',
        'workOrderBatchRef',
        'modelClassCoverageDigest',
        'sourceWorkOrderDigest',
      ]) {
        _expectDigest(issues, assignment[field], '$path[$index].$field');
      }
      for (final field in const [
        'targetSurface',
        'primaryCapabilityId',
        'agentKind',
        'productionAgentKind',
        'modelClass',
        'promptVariantName',
        'modelClassCoverageRef',
      ]) {
        _expectSafePublicToken(
          issues,
          assignment[field],
          '$path[$index].$field',
        );
      }
      _expectEquals(
        issues,
        assignment['expectedResolutionStatus'],
        'applied',
        '$path[$index].expectedResolutionStatus',
      );
    }
  }

  static void _validatePublicRuntimeBindings(
    List<String> issues,
    List<dynamic>? bindings,
    String path,
  ) {
    if (bindings == null) return;
    for (final (index, value) in bindings.indexed) {
      final binding = _expectMap(issues, value, '$path[$index]');
      if (binding == null) continue;
      _validateRuntimeBinding(issues, binding, '$path[$index]');
      _expectEquals(
        issues,
        binding['privateRuntimeIdsOmitted'],
        true,
        '$path[$index].privateRuntimeIdsOmitted',
      );
      _expectEquals(
        issues,
        binding['rawPromptTextOmitted'],
        true,
        '$path[$index].rawPromptTextOmitted',
      );
      _expectEquals(
        issues,
        binding['rawDirectiveTextOmitted'],
        true,
        '$path[$index].rawDirectiveTextOmitted',
      );
      if (binding.containsKey('privateRuntimeIds')) {
        issues.add('$path[$index] must not contain privateRuntimeIds');
      }
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

  static void _expectDigestList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    final strings = _expectStringList(issues, value, path);
    if (strings == null) return;
    for (final (index, item) in strings.indexed) {
      if (!EvalProvenance.isDigest(item)) {
        issues.add('$path[$index] must be a sha256 digest');
      }
    }
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
