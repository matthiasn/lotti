import 'eval_provenance.dart';
import 'eval_use_case_runtime_verification.dart';
import 'eval_use_case_tuning_release_gate.dart';
import 'eval_use_case_tuning_release_plan.dart';

abstract final class EvalUseCaseRuntimeRolloutLedger {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseRuntimeRolloutLedger';
  static final Expando<String> _verifiedSourceDigests = Expando<String>(
    'verifiedRuntimeRolloutLedgerSourceDigest',
  );
  static const _approvedGateStatus = 'approvedForManualApply';
  static const _allowedStatuses = {'verified', 'blocked'};
  static const _allowedAssignmentStatuses = {
    'runtimeVerified',
    'notApplied',
    'drift',
    'invalid',
  };
  static const _productionAgentKinds = <String, String>{
    'taskAgent': 'task_agent',
    'planningAgent': 'day_agent',
  };
  static final _digestPattern = RegExp(r'^sha256:[a-f0-9]{64}$');
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=|file://)/(?:Users|home|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+|'
    r'EVAL_USE_CASE_[A-Z0-9_]+)\b',
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

  static Map<String, dynamic> build({
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required List<Map<String, dynamic>> runtimeVerifications,
    required List<Map<String, dynamic>> runtimeResolverSnapshots,
    List<Map<String, dynamic>> runtimeResolverPackets = const [],
    List<Map<String, dynamic>> runtimeLocatorPackets = const [],
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    Map<String, dynamic>? previousLedger,
    bool requirePreviousLedgerSourceReplay = false,
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
    final releaseGateStatus = _string(releaseGate['status']);
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
        'release gate review sources must be supplied for source-aware runtime rollout ledger',
    ];
    if (releasePlanIssues.isNotEmpty || releaseGateIssues.isNotEmpty) {
      throw StateError(
        'Invalid runtime rollout ledger source:\n'
        '${[...releasePlanIssues, ...releaseGateIssues].join('\n')}',
      );
    }
    if (runtimeVerifications.isEmpty) {
      throw StateError('Runtime rollout ledger needs verification evidence.');
    }
    if (runtimeResolverSnapshots.isEmpty) {
      throw StateError(
        'Runtime rollout ledger needs resolver snapshot evidence.',
      );
    }
    if (previousLedger != null) {
      assertValid(previousLedger);
      final sourceReplayRequired =
          requirePreviousLedgerSourceReplay || sourceRoadmap != null;
      if (sourceReplayRequired && !hasVerifiedSources(previousLedger)) {
        throw StateError(
          'Previous runtime rollout ledger source replay must be verified.',
        );
      }
    }

    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final releaseGateDigest = EvalProvenance.digestJson(releaseGate);
    final releaseGateRef = _string(releaseGate['releaseGateRef']);
    if (previousLedger != null) {
      final previousSourcePlan = _map(previousLedger['sourceReleasePlan']);
      final previousSourceGate = _map(previousLedger['sourceReleaseGate']);
      if (_string(previousSourcePlan['releasePlanDigest']) !=
          releasePlanDigest) {
        throw StateError(
          'Previous runtime rollout ledger source release plan must match.',
        );
      }
      if (_string(previousSourceGate['releaseGateRef']) != releaseGateRef ||
          _string(previousSourceGate['releaseGateDigest']) !=
              releaseGateDigest) {
        throw StateError(
          'Previous runtime rollout ledger source release gate must match.',
        );
      }
    }
    final approvedAssignmentRefs = _stringList(
      releaseGate['approvedAssignmentRefs'],
    )..sort();
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
    if (releaseGateStatus != _approvedGateStatus) {
      throw StateError('Runtime rollout ledger requires an approved gate.');
    }
    if (_string(
          _map(releaseGate['sourceReleasePlan'])['assignmentRefsDigest'],
        ) !=
        releasePlanAssignmentRefsDigest) {
      throw StateError(
        'Runtime rollout ledger source release gate assignment refs drift.',
      );
    }
    if (approvedAssignmentRefsDigest != releasePlanAssignmentRefsDigest) {
      throw StateError(
        'Runtime rollout ledger requires approved release gate assignments.',
      );
    }

    final expectedAssignments = [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        if (approvedAssignmentRefs.contains(
          _string(assignment['assignmentRef']),
        ))
          assignment,
    ];
    final expectedAssignmentSubjects = {
      for (final assignment in expectedAssignments)
        _string(assignment['assignmentRef']): _approvedAssignmentSubject(
          assignment,
        ),
    };
    final verificationSources = <Map<String, dynamic>>[];
    final resolverSnapshotSources = <Map<String, dynamic>>[];
    final assignments = <Map<String, dynamic>>[];
    final seenAssignmentRefs = <String>{};
    final seenVerificationRefs = <String>{};
    final resolverSnapshotsByRef = <String, Map<String, dynamic>>{};
    final sourceArtifactsBySnapshotRef =
        <String, _RuntimeResolverSnapshotSourceArtifacts>{};
    for (final snapshot in runtimeResolverSnapshots) {
      final sourceArtifacts = _sourceArtifactsForSnapshot(
        snapshot: snapshot,
        runtimeResolverPackets: runtimeResolverPackets,
        runtimeLocatorPackets: runtimeLocatorPackets,
      );
      final snapshotIssues = [
        ...EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshot(
          snapshot,
        ),
        ...EvalUseCaseRuntimeVerification.validateRuntimeResolverSnapshotSourceArtifacts(
          snapshot,
          runtimeResolverPacket: sourceArtifacts.runtimeResolverPacket,
          runtimeLocatorPacket: sourceArtifacts.runtimeLocatorPacket,
        ),
      ];
      if (snapshotIssues.isNotEmpty) {
        throw StateError(
          'Invalid runtime resolver snapshot artifact:\n'
          '${snapshotIssues.join('\n')}',
        );
      }
      final snapshotRef = _string(snapshot['runtimeResolverSnapshotRef']);
      if (resolverSnapshotsByRef.containsKey(snapshotRef)) {
        throw StateError('Duplicate runtime resolver snapshot artifact.');
      }
      resolverSnapshotsByRef[snapshotRef] = snapshot;
      sourceArtifactsBySnapshotRef[snapshotRef] = sourceArtifacts;
    }
    final usedResolverSnapshotRefs = <String>{};

    for (final verification in runtimeVerifications) {
      EvalUseCaseRuntimeVerification.assertValid(verification);
      final snapshotRef = _string(
        _map(
          verification['runtimeResolverSnapshot'],
        )['runtimeResolverSnapshotRef'],
      );
      final resolverSnapshot = resolverSnapshotsByRef[snapshotRef];
      if (resolverSnapshot == null) {
        throw StateError(
          'Runtime verification source resolver snapshot is missing.',
        );
      }
      final sourceArtifacts =
          sourceArtifactsBySnapshotRef[snapshotRef] ??
          const _RuntimeResolverSnapshotSourceArtifacts();
      EvalUseCaseRuntimeVerification.assertMatchesRuntimeResolverSnapshot(
        verification,
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeResolverSnapshot: resolverSnapshot,
        runtimeResolverPacket: sourceArtifacts.runtimeResolverPacket,
        runtimeLocatorPacket: sourceArtifacts.runtimeLocatorPacket,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceRoadmap,
        sourceDecisionLedgers: sourceDecisionLedgers,
        sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
        previousReleasePlan: previousReleasePlan,
      );
      if (usedResolverSnapshotRefs.add(snapshotRef)) {
        resolverSnapshotSources.add(
          _resolverSnapshotSource(
            resolverSnapshot,
            EvalProvenance.digestJson(resolverSnapshot),
          ),
        );
      }
      _assertVerificationMatchesSources(
        verification: verification,
        releasePlanDigest: releasePlanDigest,
        releaseGateRef: releaseGateRef,
        releaseGateDigest: releaseGateDigest,
        approvedAssignmentRefsDigest: approvedAssignmentRefsDigest,
        modelClassCoverageProofSummaryDigest:
            modelClassCoverageProofSummaryDigest,
      );
      _assertVerificationExpectedAssignmentsMatchReleasePlan(
        verification: verification,
        expectedAssignmentSubjects: expectedAssignmentSubjects,
      );
      final verificationRef = _string(verification['runtimeVerificationRef']);
      if (!seenVerificationRefs.add(verificationRef)) {
        throw StateError('Duplicate runtime verification artifact.');
      }
      final verificationDigest = EvalProvenance.digestJson(verification);
      verificationSources.add(
        _verificationSource(verification, verificationDigest),
      );
      for (final assignment in _mapList(verification['expectedAssignments'])) {
        final assignmentRef = _string(assignment['assignmentRef']);
        if (!seenAssignmentRefs.add(assignmentRef)) {
          throw StateError(
            'Duplicate runtime verification for assignmentRef $assignmentRef.',
          );
        }
        assignments.add(
          _assignmentLedgerRow(
            assignment: assignment,
            verification: verification,
            verificationDigest: verificationDigest,
          ),
        );
      }
    }
    final unusedSnapshotRefs = resolverSnapshotsByRef.keys.toSet().difference(
      usedResolverSnapshotRefs,
    );
    if (unusedSnapshotRefs.isNotEmpty) {
      throw StateError('Unused runtime resolver snapshot artifact.');
    }

    final expectedRefs = {
      for (final assignment in expectedAssignments)
        _string(assignment['assignmentRef']),
    };
    final observedRefs = {
      for (final assignment in assignments)
        _string(assignment['assignmentRef']),
    };
    final missingRefs = expectedRefs.difference(observedRefs).toList()..sort();
    if (missingRefs.isNotEmpty) {
      throw StateError(
        'Runtime rollout ledger missing verification for assignment refs: '
        '${missingRefs.join(', ')}',
      );
    }

    assignments.sort(
      (a, b) => _string(a['scopeKey']).compareTo(_string(b['scopeKey'])),
    );
    final blockers = [
      for (final assignment in assignments)
        for (final blocker in _mapList(assignment['blockers'])) blocker,
    ];
    final status = blockers.isEmpty ? 'verified' : 'blocked';
    final sourceReleasePlan = <String, dynamic>{
      'kind': EvalUseCaseTuningReleasePlan.kind,
      'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
      'releasePlanRef': _string(releasePlan['releasePlanRef']),
      'releasePlanDigest': releasePlanDigest,
      'modelClassCoverageProofSummaryDigest':
          modelClassCoverageProofSummaryDigest,
    };
    final sourceReleaseGate = <String, dynamic>{
      'kind': EvalUseCaseTuningReleaseGate.kind,
      'schemaVersion': EvalUseCaseTuningReleaseGate.schemaVersion,
      'releaseGateRef': releaseGateRef,
      'releaseGateDigest': releaseGateDigest,
      'approvedAssignmentRefsDigest': approvedAssignmentRefsDigest,
      'modelClassCoverageProofSummaryDigest': _string(
        _map(
          releaseGate['sourceReleasePlan'],
        )['modelClassCoverageProofSummaryDigest'],
      ),
    };
    final sourcePreviousLedger = previousLedger == null
        ? null
        : <String, dynamic>{
            'kind': kind,
            'schemaVersion': schemaVersion,
            'ledgerDigest': EvalProvenance.digestJson(previousLedger),
            'status': _string(previousLedger['status']),
          };
    final sourcePreviousLedgerEntry = sourcePreviousLedger == null
        ? const <String, dynamic>{}
        : <String, dynamic>{'sourcePreviousLedger': sourcePreviousLedger};
    final summary = <String, dynamic>{
      'assignmentCount': assignments.length,
      'runtimeVerificationCount': verificationSources.length,
      'runtimeResolverSnapshotCount': resolverSnapshotSources.length,
      'runtimeVerifiedCount': _assignmentStatusCount(
        assignments,
        'runtimeVerified',
      ),
      'notAppliedCount': _assignmentStatusCount(assignments, 'notApplied'),
      'driftCount': _assignmentStatusCount(assignments, 'drift'),
      'invalidCount': _assignmentStatusCount(assignments, 'invalid'),
      'blockerCount': blockers.length,
    };
    final ledger = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'rolloutLedgerRef': _rolloutLedgerRef(
        status: status,
        sourceReleasePlan: sourceReleasePlan,
        sourceReleaseGate: sourceReleaseGate,
        sourcePreviousLedger: sourcePreviousLedger,
        summary: summary,
        verificationSources: verificationSources,
        resolverSnapshotSources: resolverSnapshotSources,
        assignments: assignments,
        blockers: blockers,
      ),
      'sourceReleasePlan': sourceReleasePlan,
      'sourceReleaseGate': sourceReleaseGate,
      ...sourcePreviousLedgerEntry,
      'summary': summary,
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
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
        'consumesRuntimeVerificationAndResolverSnapshotArtifactsOnly': true,
        'runtimeConfigurationAppliedByHarness': false,
        'aiConfigMutationsWrittenByHarness': false,
        'liveCommandsCreated': false,
      },
      'runtimeResolverSnapshotSources': resolverSnapshotSources,
      'runtimeVerificationSources': verificationSources,
      'assignments': assignments,
      'blockers': blockers,
      'recommendedCommands': _recommendedCommands(status),
    };
    assertValid(ledger);
    if (sourceRoadmap != null &&
        sourceDecisionLedgers.isNotEmpty &&
        releaseReviewBundles.isNotEmpty) {
      _markVerifiedSources(ledger);
    }
    return ledger;
  }

  static bool hasVerifiedSources(Map<String, dynamic> ledger) =>
      _verifiedSourceDigests[ledger] == EvalProvenance.digestJson(ledger);

  static List<String> validate(Map<String, dynamic> ledger) {
    final issues = <String>[];
    _expectEquals(
      issues,
      ledger['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, ledger['kind'], kind, 'kind');
    _expectIsoDate(issues, ledger['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, ledger['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    _expectDigest(issues, ledger['rolloutLedgerRef'], 'rolloutLedgerRef');
    final sourceReleasePlan = _expectMap(
      issues,
      ledger['sourceReleasePlan'],
      'sourceReleasePlan',
    );
    _validateSource(issues, sourceReleasePlan, 'sourceReleasePlan');
    final sourceReleaseGate = _expectMap(
      issues,
      ledger['sourceReleaseGate'],
      'sourceReleaseGate',
    );
    _validateSource(issues, sourceReleaseGate, 'sourceReleaseGate');
    if (ledger['sourcePreviousLedger'] != null) {
      _validatePreviousLedgerSource(
        issues,
        _expectMap(
          issues,
          ledger['sourcePreviousLedger'],
          'sourcePreviousLedger',
        ),
      );
    }
    final sources = _expectList(
      issues,
      ledger['runtimeVerificationSources'],
      'runtimeVerificationSources',
    );
    _validateVerificationSources(issues, sources);
    final snapshotSources = _expectList(
      issues,
      ledger['runtimeResolverSnapshotSources'],
      'runtimeResolverSnapshotSources',
    );
    _validateResolverSnapshotSources(issues, snapshotSources);
    final assignments = _expectList(
      issues,
      ledger['assignments'],
      'assignments',
    );
    _validateAssignments(issues, assignments);
    final blockers = _expectList(issues, ledger['blockers'], 'blockers');
    _validateBlockers(issues, blockers);
    _validateSummary(
      issues,
      _expectMap(issues, ledger['summary'], 'summary'),
      assignments,
      sources,
      snapshotSources,
      blockers,
    );
    _validateStatusInvariant(issues, status: status, blockers: blockers);
    _validateAssignmentStatusInvariants(
      issues,
      status: status,
      assignments: assignments,
      blockers: blockers,
    );
    _validateAssignmentVerificationSources(
      issues,
      assignments: assignments,
      verificationSources: sources,
    );
    _validatePrivacy(issues, _expectMap(issues, ledger['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, ledger['limitations'], 'limitations'),
    );
    _validateCommands(
      issues,
      _expectList(issues, ledger['recommendedCommands'], 'recommendedCommands'),
      expectedCommands: status == null ? null : _recommendedCommands(status),
    );
    _validateSourceSummaryConsistency(
      issues,
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseGate: sourceReleaseGate,
      verificationSources: sources,
      resolverSnapshotSources: snapshotSources,
    );
    _validateRolloutLedgerRef(
      issues,
      ledger,
      status: status,
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseGate: sourceReleaseGate,
      sourcePreviousLedger: ledger['sourcePreviousLedger'] == null
          ? null
          : _map(ledger['sourcePreviousLedger']),
      summary: _map(ledger['summary']),
      verificationSources: sources,
      resolverSnapshotSources: snapshotSources,
      assignments: assignments,
      blockers: blockers,
    );
    _validateNoPrivatePayloads(issues, ledger, 'runtimeRolloutLedger');
    return issues;
  }

  static void assertValid(Map<String, dynamic> ledger) {
    final issues = validate(ledger);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case runtime rollout ledger:\n${issues.join('\n')}',
    );
  }

  static _RuntimeResolverSnapshotSourceArtifacts _sourceArtifactsForSnapshot({
    required Map<String, dynamic> snapshot,
    required List<Map<String, dynamic>> runtimeResolverPackets,
    required List<Map<String, dynamic>> runtimeLocatorPackets,
  }) {
    final source = _map(snapshot['runtimeObservationSource']);
    final resolverPacket = _sourceArtifactByDigest(
      runtimeResolverPackets,
      _string(source['sourceResolverPacketDigest']),
    );
    if (_string(source['mode']) != 'privateRuntimeStateLocator') {
      return _RuntimeResolverSnapshotSourceArtifacts(
        runtimeResolverPacket: resolverPacket,
      );
    }
    final locatorPacket = _sourceArtifactByDigest(
      runtimeLocatorPackets,
      _string(source['sourceLocatorPacketDigest']),
    );
    if (locatorPacket == null ||
        _string(locatorPacket['locatorPacketRef']) ==
            _string(source['sourceLocatorPacketRef'])) {
      return _RuntimeResolverSnapshotSourceArtifacts(
        runtimeResolverPacket: resolverPacket,
        runtimeLocatorPacket: locatorPacket,
      );
    }
    return _RuntimeResolverSnapshotSourceArtifacts(
      runtimeResolverPacket: resolverPacket,
    );
  }

  static Map<String, dynamic>? _sourceArtifactByDigest(
    List<Map<String, dynamic>> artifacts,
    String digest,
  ) {
    if (digest.isEmpty) return null;
    for (final artifact in artifacts) {
      if (EvalProvenance.digestJson(artifact) == digest) {
        return artifact;
      }
    }
    return null;
  }

  static List<String> validateAgainstSources(
    Map<String, dynamic> ledger, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required List<Map<String, dynamic>> runtimeVerifications,
    required List<Map<String, dynamic>> runtimeResolverSnapshots,
    List<Map<String, dynamic>> runtimeResolverPackets = const [],
    List<Map<String, dynamic>> runtimeLocatorPackets = const [],
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    Map<String, dynamic>? previousLedger,
    bool requirePreviousLedgerSourceReplay = true,
  }) {
    final issues = validate(ledger);
    Map<String, dynamic> expected;
    try {
      expected = build(
        releasePlan: releasePlan,
        releaseGate: releaseGate,
        runtimeVerifications: runtimeVerifications,
        runtimeResolverSnapshots: runtimeResolverSnapshots,
        runtimeResolverPackets: runtimeResolverPackets,
        runtimeLocatorPackets: runtimeLocatorPackets,
        releaseReviewBundles: releaseReviewBundles,
        sourceRoadmap: sourceRoadmap,
        sourceDecisionLedgers: sourceDecisionLedgers,
        sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
        previousReleasePlan: previousReleasePlan,
        previousLedger: previousLedger,
        requirePreviousLedgerSourceReplay:
            previousLedger != null && requirePreviousLedgerSourceReplay,
        generatedAt: DateTime.utc(2026),
      );
    } catch (error) {
      issues.add(
        'source artifacts cannot build runtime rollout ledger: $error',
      );
      return issues;
    }
    for (final field in const [
      'status',
      'rolloutLedgerRef',
      'sourceReleasePlan',
      'sourceReleaseGate',
      'summary',
      'runtimeResolverSnapshotSources',
      'runtimeVerificationSources',
      'assignments',
      'blockers',
      'recommendedCommands',
    ]) {
      if (EvalProvenance.digestJson(ledger[field]) !=
          EvalProvenance.digestJson(expected[field])) {
        issues.add('$field must match source runtime artifacts');
      }
    }
    if (EvalProvenance.digestJson(ledger['sourcePreviousLedger']) !=
        EvalProvenance.digestJson(expected['sourcePreviousLedger'])) {
      issues.add('sourcePreviousLedger must match source runtime artifacts');
    }
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> ledger, {
    required Map<String, dynamic> releasePlan,
    required Map<String, dynamic> releaseGate,
    required List<Map<String, dynamic>> runtimeVerifications,
    required List<Map<String, dynamic>> runtimeResolverSnapshots,
    List<Map<String, dynamic>> runtimeResolverPackets = const [],
    List<Map<String, dynamic>> runtimeLocatorPackets = const [],
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    Map<String, dynamic>? previousLedger,
    bool requirePreviousLedgerSourceReplay = true,
  }) {
    final issues = validateAgainstSources(
      ledger,
      releasePlan: releasePlan,
      releaseGate: releaseGate,
      runtimeVerifications: runtimeVerifications,
      runtimeResolverSnapshots: runtimeResolverSnapshots,
      runtimeResolverPackets: runtimeResolverPackets,
      runtimeLocatorPackets: runtimeLocatorPackets,
      releaseReviewBundles: releaseReviewBundles,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
      previousLedger: previousLedger,
      requirePreviousLedgerSourceReplay: requirePreviousLedgerSourceReplay,
    );
    if (issues.isEmpty) {
      if (sourceRoadmap != null &&
          sourceDecisionLedgers.isNotEmpty &&
          releaseReviewBundles.isNotEmpty) {
        _markVerifiedSources(ledger);
      }
      return;
    }
    throw StateError(
      'Invalid use-case runtime rollout ledger source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static void _markVerifiedSources(Map<String, dynamic> ledger) {
    _verifiedSourceDigests[ledger] = EvalProvenance.digestJson(ledger);
  }

  static void _assertVerificationMatchesSources({
    required Map<String, dynamic> verification,
    required String releasePlanDigest,
    required String releaseGateRef,
    required String releaseGateDigest,
    required String approvedAssignmentRefsDigest,
    required String modelClassCoverageProofSummaryDigest,
  }) {
    final sourcePlan = _map(verification['sourceReleasePlan']);
    final sourceGate = _map(verification['sourceReleaseGate']);
    if (_string(sourcePlan['releasePlanDigest']) != releasePlanDigest ||
        _string(sourcePlan['modelClassCoverageProofSummaryDigest']) !=
            modelClassCoverageProofSummaryDigest ||
        _string(sourceGate['releaseGateRef']) != releaseGateRef ||
        _string(sourceGate['releaseGateDigest']) != releaseGateDigest ||
        _string(sourceGate['approvedAssignmentRefsDigest']) !=
            approvedAssignmentRefsDigest ||
        _string(sourceGate['modelClassCoverageProofSummaryDigest']) !=
            modelClassCoverageProofSummaryDigest) {
      throw StateError(
        'Runtime verification source release plan/gate digest drift.',
      );
    }
  }

  static void _assertVerificationExpectedAssignmentsMatchReleasePlan({
    required Map<String, dynamic> verification,
    required Map<String, Map<String, dynamic>> expectedAssignmentSubjects,
  }) {
    for (final assignment in _mapList(verification['expectedAssignments'])) {
      final assignmentRef = _string(assignment['assignmentRef']);
      final expectedSubject = expectedAssignmentSubjects[assignmentRef];
      if (expectedSubject == null ||
          EvalProvenance.digestJson(expectedSubject) !=
              EvalProvenance.digestJson(
                _verificationAssignmentSubject(assignment),
              )) {
        throw StateError(
          'Runtime verification expected assignment drift for assignmentRef '
          '$assignmentRef.',
        );
      }
    }
  }

  static Map<String, dynamic> _approvedAssignmentSubject(
    Map<String, dynamic> assignment,
  ) {
    final agentKind = _string(assignment['agentKind']);
    return <String, dynamic>{
      'assignmentRef': _string(assignment['assignmentRef']),
      'scopeKey': _string(assignment['scopeKey']),
      'targetSurface': _string(assignment['targetSurface']),
      'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
      'agentKind': agentKind,
      'productionAgentKind': _productionAgentKinds[agentKind] ?? 'unsupported',
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
    };
  }

  static Map<String, dynamic> _verificationAssignmentSubject(
    Map<String, dynamic> assignment,
  ) => <String, dynamic>{
    'assignmentRef': _string(assignment['assignmentRef']),
    'scopeKey': _string(assignment['scopeKey']),
    'targetSurface': _string(assignment['targetSurface']),
    'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
    'agentKind': _string(assignment['agentKind']),
    'productionAgentKind': _string(assignment['productionAgentKind']),
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
    'modelClassCoverageDigest': _string(assignment['modelClassCoverageDigest']),
    'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
  };

  static Map<String, dynamic> _verificationSource(
    Map<String, dynamic> verification,
    String verificationDigest,
  ) {
    final snapshot = _map(verification['runtimeResolverSnapshot']);
    return <String, dynamic>{
      'kind': EvalUseCaseRuntimeVerification.kind,
      'schemaVersion': EvalUseCaseRuntimeVerification.schemaVersion,
      'runtimeVerificationRef': _string(verification['runtimeVerificationRef']),
      'runtimeVerificationDigest': verificationDigest,
      'runtimeResolverSnapshotRef': _string(
        snapshot['runtimeResolverSnapshotRef'],
      ),
      'runtimeResolverSnapshotDigest': _string(snapshot['snapshotDigest']),
      'runtimeObservationSourceDigest': _string(
        snapshot['runtimeObservationSourceDigest'],
      ),
      'modelClassCoverageProofSummaryDigest': _string(
        _map(
          verification['sourceReleasePlan'],
        )['modelClassCoverageProofSummaryDigest'],
      ),
      'generatedAt': _string(verification['generatedAt']),
      'status': _string(verification['status']),
      'verifiedAssignmentCount': _map(
        verification['summary'],
      )['verifiedAssignmentCount'],
      'issueCount': _map(verification['summary'])['issueCount'],
    };
  }

  static Map<String, dynamic> _resolverSnapshotSource(
    Map<String, dynamic> snapshot,
    String snapshotDigest,
  ) {
    return <String, dynamic>{
      'kind': EvalUseCaseRuntimeVerification.resolverSnapshotKind,
      'schemaVersion':
          EvalUseCaseRuntimeVerification.resolverSnapshotSchemaVersion,
      'runtimeResolverSnapshotRef': _string(
        snapshot['runtimeResolverSnapshotRef'],
      ),
      'runtimeResolverSnapshotDigest': snapshotDigest,
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
      'runtimeBindingCount': _map(snapshot['summary'])['runtimeBindingCount'],
    };
  }

  static Map<String, dynamic> _assignmentLedgerRow({
    required Map<String, dynamic> assignment,
    required Map<String, dynamic> verification,
    required String verificationDigest,
  }) {
    final assignmentRef = _string(assignment['assignmentRef']);
    final sourceIssues = [
      for (final issue in _mapList(verification['issues']))
        if (_string(issue['assignmentRef']) == assignmentRef) issue,
    ];
    final runtimeStatus = _runtimeStatus(
      verificationStatus: _string(verification['status']),
      assignmentRef: assignmentRef,
      verifiedRefs: _stringList(verification['verifiedAssignmentRefs']),
      issues: sourceIssues,
    );
    final blockers = _blockers(
      assignmentRef: assignmentRef,
      runtimeStatus: runtimeStatus,
      issues: sourceIssues,
    );
    return <String, dynamic>{
      'assignmentRef': assignmentRef,
      'scopeKey': _string(assignment['scopeKey']),
      'targetSurface': _string(assignment['targetSurface']),
      'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
      'agentKind': _string(assignment['agentKind']),
      'productionAgentKind': _string(assignment['productionAgentKind']),
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
      'runtimeStatus': runtimeStatus,
      'runtimeVerificationRef': _string(verification['runtimeVerificationRef']),
      'runtimeVerificationDigest': verificationDigest,
      'sourceIssueCodes': [
        for (final issue in sourceIssues) _string(issue['code']),
      ]..sort(),
      'blockerCodes': [
        for (final blocker in blockers) _string(blocker['blockerCode']),
      ],
      'blockers': blockers,
      'nextAction': _nextAction(runtimeStatus),
    };
  }

  static String _runtimeStatus({
    required String verificationStatus,
    required String assignmentRef,
    required List<String> verifiedRefs,
    required List<Map<String, dynamic>> issues,
  }) {
    if (verificationStatus == 'invalid' ||
        verificationStatus == 'blockedReleaseGate') {
      return 'invalid';
    }
    if (verificationStatus == 'verified' &&
        verifiedRefs.contains(assignmentRef) &&
        issues.isEmpty) {
      return 'runtimeVerified';
    }
    final kinds = {for (final issue in issues) _string(issue['issueKind'])};
    if (kinds.isEmpty) return 'invalid';
    if (kinds.length == 1 && kinds.single == 'notApplied') {
      return 'notApplied';
    }
    if (kinds.contains('drift') || kinds.contains('partial')) return 'drift';
    return 'invalid';
  }

  static List<Map<String, dynamic>> _blockers({
    required String assignmentRef,
    required String runtimeStatus,
    required List<Map<String, dynamic>> issues,
  }) {
    final blockerCode = switch (runtimeStatus) {
      'runtimeVerified' => '',
      'notApplied' => 'runtime.notApplied',
      'drift' => 'runtime.drift',
      _ => 'runtime.invalid',
    };
    if (blockerCode.isEmpty) return const [];
    return [
      <String, dynamic>{
        'assignmentRef': assignmentRef,
        'blockerCode': blockerCode,
        'sourceIssueCodes': [
          for (final issue in issues) _string(issue['code']),
        ]..sort(),
        'nextAction': _nextAction(runtimeStatus),
      },
    ];
  }

  static String _nextAction(String runtimeStatus) => switch (runtimeStatus) {
    'runtimeVerified' => 'continueReleasePlanning',
    'notApplied' => 'applyRuntimeAssignmentThenReverify',
    'drift' => 'reconcileRuntimeDriftThenReverify',
    _ => 'regenerateRuntimeVerificationEvidence',
  };

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final commands = status == 'verified'
        ? const [
            ('roadmap', 'eval/run_level2.sh roadmap'),
            ('release-plan', 'eval/run_level2.sh release-plan'),
          ]
        : const [
            (
              'runtime-locator-packet',
              'eval/run_level2.sh runtime-locator-packet',
            ),
            (
              'observe-runtime-state',
              'eval/run_level2.sh observe-runtime-state',
            ),
            ('runtime-verify', 'eval/run_level2.sh runtime-verify'),
          ];
    return [
      for (final command in commands)
        <String, dynamic>{
          'mode': command.$1,
          'command': command.$2,
        },
    ];
  }

  static int _assignmentStatusCount(
    List<Map<String, dynamic>> assignments,
    String status,
  ) => assignments
      .where((assignment) => assignment['runtimeStatus'] == status)
      .length;

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
    for (final field in [
      if (path == 'sourceReleasePlan') ...[
        'releasePlanDigest',
        'modelClassCoverageProofSummaryDigest',
      ],
      if (path == 'sourceReleaseGate') ...[
        'releaseGateRef',
        'releaseGateDigest',
        'approvedAssignmentRefsDigest',
        'modelClassCoverageProofSummaryDigest',
      ],
    ]) {
      _expectDigest(issues, source[field], '$path.$field');
    }
  }

  static void _validatePreviousLedgerSource(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(issues, source['kind'], kind, 'sourcePreviousLedger.kind');
    _expectEquals(
      issues,
      source['schemaVersion'],
      schemaVersion,
      'sourcePreviousLedger.schemaVersion',
    );
    _expectDigest(
      issues,
      source['ledgerDigest'],
      'sourcePreviousLedger.ledgerDigest',
    );
    _expectNonEmptyString(
      issues,
      source['status'],
      'sourcePreviousLedger.status',
    );
  }

  static void _validateVerificationSources(
    List<String> issues,
    List<dynamic>? sources,
  ) {
    if (sources == null) return;
    for (final (index, value) in sources.indexed) {
      final source = _expectMap(
        issues,
        value,
        'runtimeVerificationSources[$index]',
      );
      if (source == null) continue;
      _expectEquals(
        issues,
        source['kind'],
        EvalUseCaseRuntimeVerification.kind,
        'runtimeVerificationSources[$index].kind',
      );
      _expectDigest(
        issues,
        source['runtimeVerificationRef'],
        'runtimeVerificationSources[$index].runtimeVerificationRef',
      );
      _expectDigest(
        issues,
        source['runtimeVerificationDigest'],
        'runtimeVerificationSources[$index].runtimeVerificationDigest',
      );
      _expectDigest(
        issues,
        source['runtimeResolverSnapshotRef'],
        'runtimeVerificationSources[$index].runtimeResolverSnapshotRef',
      );
      _expectDigest(
        issues,
        source['runtimeResolverSnapshotDigest'],
        'runtimeVerificationSources[$index].runtimeResolverSnapshotDigest',
      );
      _expectDigest(
        issues,
        source['runtimeObservationSourceDigest'],
        'runtimeVerificationSources[$index].runtimeObservationSourceDigest',
      );
      _expectDigest(
        issues,
        source['modelClassCoverageProofSummaryDigest'],
        'runtimeVerificationSources[$index].modelClassCoverageProofSummaryDigest',
      );
      _expectIsoDate(
        issues,
        source['generatedAt'],
        'runtimeVerificationSources[$index].generatedAt',
      );
      _expectNonEmptyString(
        issues,
        source['status'],
        'runtimeVerificationSources[$index].status',
      );
    }
  }

  static void _validateResolverSnapshotSources(
    List<String> issues,
    List<dynamic>? sources,
  ) {
    if (sources == null) return;
    for (final (index, value) in sources.indexed) {
      final source = _expectMap(
        issues,
        value,
        'runtimeResolverSnapshotSources[$index]',
      );
      if (source == null) continue;
      _expectEquals(
        issues,
        source['kind'],
        EvalUseCaseRuntimeVerification.resolverSnapshotKind,
        'runtimeResolverSnapshotSources[$index].kind',
      );
      _expectEquals(
        issues,
        source['schemaVersion'],
        EvalUseCaseRuntimeVerification.resolverSnapshotSchemaVersion,
        'runtimeResolverSnapshotSources[$index].schemaVersion',
      );
      _expectDigest(
        issues,
        source['runtimeResolverSnapshotRef'],
        'runtimeResolverSnapshotSources[$index].runtimeResolverSnapshotRef',
      );
      _expectDigest(
        issues,
        source['runtimeResolverSnapshotDigest'],
        'runtimeResolverSnapshotSources[$index].runtimeResolverSnapshotDigest',
      );
      for (final field in const [
        'sourceReleasePlanDigest',
        'sourceReleaseGateRef',
        'sourceReleaseGateDigest',
        'approvedAssignmentRefsDigest',
        'modelClassCoverageProofSummaryDigest',
        'runtimeObservationSourceDigest',
      ]) {
        _expectDigest(
          issues,
          source[field],
          'runtimeResolverSnapshotSources[$index].$field',
        );
      }
      _expectNonNegativeInt(
        issues,
        source['runtimeBindingCount'],
        'runtimeResolverSnapshotSources[$index].runtimeBindingCount',
      );
    }
  }

  static void _validateAssignments(List<String> issues, List<dynamic>? rows) {
    if (rows == null) return;
    for (final (index, value) in rows.indexed) {
      final row = _expectMap(issues, value, 'assignments[$index]');
      if (row == null) continue;
      for (final field in const [
        'assignmentRef',
        'modelClassCoverageProofRef',
        'modelClassCoverageClassRef',
        'workOrderBatchRef',
        'modelClassCoverageDigest',
        'sourceWorkOrderDigest',
        'runtimeVerificationRef',
        'runtimeVerificationDigest',
      ]) {
        _expectDigest(issues, row[field], 'assignments[$index].$field');
      }
      for (final field in const [
        'scopeKey',
        'targetSurface',
        'primaryCapabilityId',
        'agentKind',
        'productionAgentKind',
        'modelClass',
        'promptVariantName',
        'modelClassCoverageRef',
        'nextAction',
      ]) {
        _expectNonEmptyString(issues, row[field], 'assignments[$index].$field');
      }
      final status = _expectNonEmptyString(
        issues,
        row['runtimeStatus'],
        'assignments[$index].runtimeStatus',
      );
      if (status != null && !_allowedAssignmentStatuses.contains(status)) {
        issues.add('assignments[$index].runtimeStatus must be supported');
      }
      _expectStringList(
        issues,
        row['sourceIssueCodes'],
        'assignments[$index].sourceIssueCodes',
      );
      _expectStringList(
        issues,
        row['blockerCodes'],
        'assignments[$index].blockerCodes',
      );
      _validateBlockers(
        issues,
        _expectList(issues, row['blockers'], 'assignments[$index].blockers'),
        path: 'assignments[$index].blockers',
      );
    }
  }

  static void _validateBlockers(
    List<String> issues,
    List<dynamic>? blockers, {
    String path = 'blockers',
  }) {
    if (blockers == null) return;
    for (final (index, value) in blockers.indexed) {
      final blocker = _expectMap(issues, value, '$path[$index]');
      if (blocker == null) continue;
      _expectDigest(
        issues,
        blocker['assignmentRef'],
        '$path[$index].assignmentRef',
      );
      _expectNonEmptyString(
        issues,
        blocker['blockerCode'],
        '$path[$index].blockerCode',
      );
      _expectStringList(
        issues,
        blocker['sourceIssueCodes'],
        '$path[$index].sourceIssueCodes',
      );
      _expectNonEmptyString(
        issues,
        blocker['nextAction'],
        '$path[$index].nextAction',
      );
    }
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
    List<dynamic>? assignments,
    List<dynamic>? sources,
    List<dynamic>? snapshotSources,
    List<dynamic>? blockers,
  ) {
    if (summary == null) return;
    for (final field in const [
      'assignmentCount',
      'runtimeVerificationCount',
      'runtimeResolverSnapshotCount',
      'runtimeVerifiedCount',
      'notAppliedCount',
      'driftCount',
      'invalidCount',
      'blockerCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
    if (assignments != null &&
        summary['assignmentCount'] != assignments.length) {
      issues.add('summary.assignmentCount must match assignments.length');
    }
    if (sources != null &&
        summary['runtimeVerificationCount'] != sources.length) {
      issues.add(
        'summary.runtimeVerificationCount must match runtimeVerificationSources.length',
      );
    }
    if (snapshotSources != null &&
        summary['runtimeResolverSnapshotCount'] != snapshotSources.length) {
      issues.add(
        'summary.runtimeResolverSnapshotCount must match runtimeResolverSnapshotSources.length',
      );
    }
    if (blockers != null && summary['blockerCount'] != blockers.length) {
      issues.add('summary.blockerCount must match blockers.length');
    }
    if (assignments != null) {
      for (final status in const [
        ('runtimeVerifiedCount', 'runtimeVerified'),
        ('notAppliedCount', 'notApplied'),
        ('driftCount', 'drift'),
        ('invalidCount', 'invalid'),
      ]) {
        final count = _mapList(assignments)
            .where((assignment) => assignment['runtimeStatus'] == status.$2)
            .length;
        if (summary[status.$1] != count) {
          issues.add('summary.${status.$1} must match assignments');
        }
      }
    }
  }

  static void _validateStatusInvariant(
    List<String> issues, {
    required String? status,
    required List<dynamic>? blockers,
  }) {
    if (status == null || blockers == null) return;
    final expectedStatus = blockers.isEmpty ? 'verified' : 'blocked';
    if (status != expectedStatus) {
      issues.add('status must match blocker presence');
    }
  }

  static void _validateAssignmentStatusInvariants(
    List<String> issues, {
    required String? status,
    required List<dynamic>? assignments,
    required List<dynamic>? blockers,
  }) {
    if (assignments == null || blockers == null) return;
    final assignmentRows = _mapList(assignments);
    final flattenedBlockers = [
      for (final assignment in assignmentRows)
        ..._mapList(assignment['blockers']),
    ];
    if (_digestList(flattenedBlockers) != _digestList(_mapList(blockers))) {
      issues.add('blockers must match flattened assignment blockers');
    }
    final nonVerified = [
      for (final assignment in assignmentRows)
        if (_string(assignment['runtimeStatus']) != 'runtimeVerified')
          assignment,
    ];
    if (status == 'verified' && nonVerified.isNotEmpty) {
      issues.add(
        'verified rollout ledgers require every assignment to be runtimeVerified',
      );
    }
    for (final (index, assignment) in assignmentRows.indexed) {
      final runtimeStatus = _string(assignment['runtimeStatus']);
      final expectedBlockerCode = switch (runtimeStatus) {
        'runtimeVerified' => '',
        'notApplied' => 'runtime.notApplied',
        'drift' => 'runtime.drift',
        _ => 'runtime.invalid',
      };
      final expectedNextAction = _nextAction(runtimeStatus);
      final blockerCodes = _stringList(assignment['blockerCodes']);
      final rowBlockers = _mapList(assignment['blockers']);
      if (_string(assignment['nextAction']) != expectedNextAction) {
        issues.add('assignments[$index].nextAction must match runtimeStatus');
      }
      if (expectedBlockerCode.isEmpty) {
        if (blockerCodes.isNotEmpty || rowBlockers.isNotEmpty) {
          issues.add(
            'assignments[$index] must not carry blockers when runtimeVerified',
          );
        }
        continue;
      }
      if (blockerCodes.length != 1 ||
          blockerCodes.single != expectedBlockerCode) {
        issues.add('assignments[$index].blockerCodes must match runtimeStatus');
      }
      if (rowBlockers.length != 1) {
        issues.add('assignments[$index].blockers must contain one blocker');
        continue;
      }
      final blocker = rowBlockers.single;
      if (_string(blocker['assignmentRef']) !=
          _string(assignment['assignmentRef'])) {
        issues.add(
          'assignments[$index].blockers[0].assignmentRef must match assignmentRef',
        );
      }
      if (_string(blocker['blockerCode']) != expectedBlockerCode) {
        issues.add(
          'assignments[$index].blockers[0].blockerCode must match runtimeStatus',
        );
      }
      if (_string(blocker['nextAction']) != expectedNextAction) {
        issues.add(
          'assignments[$index].blockers[0].nextAction must match runtimeStatus',
        );
      }
      if (_digestList(_stringList(blocker['sourceIssueCodes'])) !=
          _digestList(_stringList(assignment['sourceIssueCodes']))) {
        issues.add(
          'assignments[$index].blockers[0].sourceIssueCodes must match assignment sourceIssueCodes',
        );
      }
    }
  }

  static void _validateAssignmentVerificationSources(
    List<String> issues, {
    required List<dynamic>? assignments,
    required List<dynamic>? verificationSources,
  }) {
    if (assignments == null || verificationSources == null) return;
    final sourceKeys = <String>{};
    final usedKeys = <String>{};
    for (final (index, source) in _mapList(verificationSources).indexed) {
      final key = _verificationSourceKey(source);
      if (key.trim().isEmpty) continue;
      if (!sourceKeys.add(key)) {
        issues.add(
          'runtimeVerificationSources[$index] must not duplicate a verification source',
        );
      }
    }
    for (final (index, assignment) in _mapList(assignments).indexed) {
      final key = _verificationSourceKey(assignment);
      if (!sourceKeys.contains(key)) {
        issues.add(
          'assignments[$index] must reference a runtimeVerificationSources entry',
        );
      } else {
        usedKeys.add(key);
      }
    }
    for (final key in sourceKeys) {
      if (!usedKeys.contains(key)) {
        issues.add(
          'runtimeVerificationSources must not contain unused verification sources',
        );
      }
    }
  }

  static String _verificationSourceKey(Map<String, dynamic> value) => [
    _string(value['runtimeVerificationRef']),
    _string(value['runtimeVerificationDigest']),
  ].join(':');

  static void _validateSourceSummaryConsistency(
    List<String> issues, {
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
    required List<dynamic>? verificationSources,
    required List<dynamic>? resolverSnapshotSources,
  }) {
    if (sourceReleasePlan == null || sourceReleaseGate == null) return;
    final proofSummaryDigest = _string(
      sourceReleasePlan['modelClassCoverageProofSummaryDigest'],
    );
    if (_string(sourceReleaseGate['modelClassCoverageProofSummaryDigest']) !=
        proofSummaryDigest) {
      issues.add(
        'sourceReleaseGate.modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      );
    }
    if (verificationSources == null) return;
    final snapshotSourcesByRef = {
      for (final source in _mapList(resolverSnapshotSources))
        _string(source['runtimeResolverSnapshotRef']): source,
    };
    for (final (index, source) in verificationSources.indexed) {
      if (source is! Map<String, dynamic>) continue;
      if (_string(source['modelClassCoverageProofSummaryDigest']) !=
          proofSummaryDigest) {
        issues.add(
          'runtimeVerificationSources[$index].modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
        );
      }
      final snapshotRef = _string(source['runtimeResolverSnapshotRef']);
      final snapshotSource = snapshotSourcesByRef[snapshotRef];
      if (snapshotSource == null) {
        issues.add(
          'runtimeVerificationSources[$index] must reference a runtimeResolverSnapshotSources entry',
        );
        continue;
      }
      if (_string(source['runtimeResolverSnapshotDigest']) !=
          _string(snapshotSource['runtimeResolverSnapshotDigest'])) {
        issues.add(
          'runtimeVerificationSources[$index].runtimeResolverSnapshotDigest must match runtimeResolverSnapshotSources',
        );
      }
      if (_string(source['runtimeObservationSourceDigest']) !=
          _string(snapshotSource['runtimeObservationSourceDigest'])) {
        issues.add(
          'runtimeVerificationSources[$index].runtimeObservationSourceDigest must match runtimeResolverSnapshotSources',
        );
      }
    }
  }

  static void _validateRolloutLedgerRef(
    List<String> issues,
    Map<String, dynamic> ledger, {
    required String? status,
    required Map<String, dynamic>? sourceReleasePlan,
    required Map<String, dynamic>? sourceReleaseGate,
    required Map<String, dynamic>? sourcePreviousLedger,
    required Map<String, dynamic>? summary,
    required List<dynamic>? verificationSources,
    required List<dynamic>? resolverSnapshotSources,
    required List<dynamic>? assignments,
    required List<dynamic>? blockers,
  }) {
    if (status == null ||
        sourceReleasePlan == null ||
        sourceReleaseGate == null ||
        summary == null ||
        verificationSources == null ||
        resolverSnapshotSources == null ||
        assignments == null ||
        blockers == null) {
      return;
    }
    final expectedRef = rolloutLedgerRef(ledger);
    if (ledger['rolloutLedgerRef'] != expectedRef) {
      issues.add('rolloutLedgerRef must match rollout ledger subject digest');
    }
  }

  static String rolloutLedgerRef(Map<String, dynamic> ledger) =>
      _rolloutLedgerRef(
        status: _string(ledger['status']),
        sourceReleasePlan: _map(ledger['sourceReleasePlan']),
        sourceReleaseGate: _map(ledger['sourceReleaseGate']),
        sourcePreviousLedger: ledger['sourcePreviousLedger'] == null
            ? null
            : _map(ledger['sourcePreviousLedger']),
        summary: _map(ledger['summary']),
        verificationSources: _mapList(ledger['runtimeVerificationSources']),
        resolverSnapshotSources: _mapList(
          ledger['runtimeResolverSnapshotSources'],
        ),
        assignments: _mapList(ledger['assignments']),
        blockers: _mapList(ledger['blockers']),
      );

  static String _rolloutLedgerRef({
    required String status,
    required Map<String, dynamic> sourceReleasePlan,
    required Map<String, dynamic> sourceReleaseGate,
    required Map<String, dynamic>? sourcePreviousLedger,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> verificationSources,
    required List<Map<String, dynamic>> resolverSnapshotSources,
    required List<Map<String, dynamic>> assignments,
    required List<Map<String, dynamic>> blockers,
  }) => EvalProvenance.digestJson(<String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': status,
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
    'sourcePreviousLedgerDigest': sourcePreviousLedger == null
        ? ''
        : EvalProvenance.digestJson(sourcePreviousLedger),
    'summaryDigest': EvalProvenance.digestJson(summary),
    'runtimeVerificationRefs': [
      for (final source in verificationSources)
        _string(source['runtimeVerificationRef']),
    ],
    'runtimeVerificationDigests': [
      for (final source in verificationSources)
        _string(source['runtimeVerificationDigest']),
    ],
    'runtimeResolverSnapshotRefs': [
      for (final source in resolverSnapshotSources)
        _string(source['runtimeResolverSnapshotRef']),
    ],
    'runtimeResolverSnapshotDigests': [
      for (final source in resolverSnapshotSources)
        _string(source['runtimeResolverSnapshotDigest']),
    ],
    'assignmentsDigest': EvalProvenance.digestJson(assignments),
    'blockersDigest': EvalProvenance.digestJson(blockers),
  });

  static void _validatePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = {
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
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
    const expected = {
      'consumesRuntimeVerificationAndResolverSnapshotArtifactsOnly': true,
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

  static void _validateCommands(
    List<String> issues,
    List<dynamic>? commands, {
    List<Map<String, dynamic>>? expectedCommands,
  }) {
    if (commands == null) return;
    if (expectedCommands != null &&
        EvalProvenance.digestJson(commands) !=
            EvalProvenance.digestJson(expectedCommands)) {
      issues.add(
        'recommendedCommands must match static recommended command templates',
      );
    }
    for (final (index, value) in commands.indexed) {
      final command = _expectMap(issues, value, 'recommendedCommands[$index]');
      if (command == null) continue;
      _expectNonEmptyString(
        issues,
        command['mode'],
        'recommendedCommands[$index].mode',
      );
      final text = _expectNonEmptyString(
        issues,
        command['command'],
        'recommendedCommands[$index].command',
      );
      if (text != null && _liveRunLevel2CommandPattern.hasMatch(text)) {
        issues.add(
          'recommendedCommands[$index].command must not recommend live run commands',
        );
      }
      if (text != null && _dangerousCommandTokenPattern.hasMatch(text)) {
        issues.add(
          'recommendedCommands[$index].command must not mutate runtime',
        );
      }
      if (command.containsKey('env')) {
        issues.add('recommendedCommands[$index] must not contain env values');
      }
    }
  }

  static void _validateNoPrivatePayloads(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (const {
          'privateruntimeids',
          'agentid',
          'templateid',
          'templateversionid',
          'profileid',
          'baseurl',
          'apikey',
          'rawprompt',
          'prompttext',
          'systemprompt',
          'rawdirective',
          'directivetext',
        }.contains(normalized)) {
          issues.add('$path.$key must not expose private runtime payloads');
        }
        _validateNoPrivatePayloads(issues, entry.value, '$path.$key');
      }
      return;
    }
    if (value is Iterable) {
      var index = 0;
      for (final item in value) {
        _validateNoPrivatePayloads(issues, item, '$path[$index]');
        index++;
      }
      return;
    }
    if (value is String) {
      if (_privatePathPattern.hasMatch(value)) {
        issues.add('$path must not contain private paths');
      }
      if (_privateEnvTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain private env value keys');
      }
      if (_dangerousCommandTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain mutation commands');
      }
    }
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) item,
    ];
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String) item,
    ];
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
    if (value is List) return value;
    issues.add('$path must be a JSON array');
    return null;
  }

  static void _expectStringList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    final list = _expectList(issues, value, path);
    if (list == null) return;
    for (final (index, item) in list.indexed) {
      _expectNonEmptyString(issues, item, '$path[$index]');
    }
  }

  static String? _expectNonEmptyString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is String && value.isNotEmpty) return value;
    issues.add('$path must be a non-empty string');
    return null;
  }

  static void _expectDigest(List<String> issues, Object? value, String path) {
    if (value is String && _digestPattern.hasMatch(value)) return;
    issues.add('$path must be a sha256 digest');
  }

  static void _expectIsoDate(List<String> issues, Object? value, String path) {
    if (value is String && DateTime.tryParse(value) != null) return;
    issues.add('$path must be an ISO-8601 timestamp');
  }

  static void _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is int && value >= 0) return;
    issues.add('$path must be a non-negative integer');
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

  static String _string(Object? value) => value is String ? value : '';

  static String _digestList(List<dynamic> values) {
    return ([
      for (final value in values)
        value is String ? value : EvalProvenance.digestJson(value),
    ]..sort()).join('|');
  }
}

final class _RuntimeResolverSnapshotSourceArtifacts {
  const _RuntimeResolverSnapshotSourceArtifacts({
    this.runtimeResolverPacket,
    this.runtimeLocatorPacket,
  });

  final Map<String, dynamic>? runtimeResolverPacket;
  final Map<String, dynamic>? runtimeLocatorPacket;
}
