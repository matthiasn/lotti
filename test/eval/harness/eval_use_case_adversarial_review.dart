import 'eval_provenance.dart';
import 'eval_use_case_tuning_campaign.dart';

abstract final class EvalUseCaseAdversarialReview {
  static const packetSchemaVersion = 1;
  static const packetKind = 'lotti.evalUseCaseAdversarialReviewPacket';
  static const attestationSchemaVersion = 1;
  static const attestationKind =
      'lotti.evalUseCaseAdversarialReviewAttestation';
  static const bundleSchemaVersion = 1;
  static const bundleKind =
      'lotti.evalUseCaseAdversarialReviewAttestationBundle';
  static const _allowedPacketStatuses = {
    'invalidCampaign',
    'noReviewTasks',
    'readyForReview',
  };
  static const _allowedBundleStatuses = {
    'approved',
    'changesRequested',
    'invalid',
  };
  static const _allowedReviewCategories = {
    'privacyAudit',
    'reportLinkageAudit',
    'modelClassCoverageAudit',
    'blockerRegressionAudit',
  };
  static const _allowedAttestationStatuses = {
    'pending',
    'approved',
    'rejected',
    'needsChanges',
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
  static final _liveRunLevel2CommandPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:\./)?eval/run_level2\.sh\s+'
    r'(?:plan|run|tune|all)(?=$|[^A-Za-z0-9_-])',
  );

  static Map<String, dynamic> buildPacket({
    required Map<String, dynamic> campaign,
    DateTime? generatedAt,
  }) {
    final campaignIssues = EvalUseCaseTuningCampaign.validate(campaign);
    final campaignDigest = EvalProvenance.digestJson(campaign);
    final campaignRef = EvalUseCaseTuningCampaign.campaignRef(campaign);
    final queue = _map(campaign['adversarialReviewQueue']);
    final sourceQueueDigest = EvalProvenance.digestJson(queue);
    final tasks = campaignIssues.isEmpty
        ? _mapList(queue['tasks'])
        : const <Map<String, dynamic>>[];
    final reviewTasks = [
      for (final task in tasks)
        if (task['required'] == true)
          _reviewTask(
            campaignDigest: campaignDigest,
            sourceQueueDigest: sourceQueueDigest,
            task: task,
          ),
    ];
    final status = campaignIssues.isNotEmpty
        ? 'invalidCampaign'
        : reviewTasks.isEmpty
        ? 'noReviewTasks'
        : 'readyForReview';
    final packet = <String, dynamic>{
      'schemaVersion': packetSchemaVersion,
      'kind': packetKind,
      'reviewPacketRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceCampaign': <String, dynamic>{
        'kind': EvalUseCaseTuningCampaign.kind,
        'schemaVersion': EvalUseCaseTuningCampaign.schemaVersion,
        'status': _string(campaign['status']).isEmpty
            ? 'unknown'
            : _string(campaign['status']),
        'campaignRef': campaignRef,
        'campaignDigest': campaignDigest,
        'sourceQueueDigest': sourceQueueDigest,
        'contractIssueCount': campaignIssues.length,
        'reviewTaskCount': tasks.length,
      },
      'summary': <String, dynamic>{
        'reviewTaskCount': reviewTasks.length,
        'attestationTemplateCount': reviewTasks.length,
        'campaignContractIssueCount': campaignIssues.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'reviewCompletionClaimsCreated': false,
      },
      'limitations': const <String, dynamic>{
        'consumesCampaignOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'attestationsApproved': false,
      },
      'reviewTasks': reviewTasks,
      'attestationTemplates': [
        for (final task in reviewTasks)
          _attestationTemplate(
            sourceArtifactDigest: campaignDigest,
            sourceQueueDigest: sourceQueueDigest,
            task: task,
          ),
      ],
      'issues': [
        for (final issue in campaignIssues)
          <String, dynamic>{
            'code': 'campaign.contractInvalid',
            'severity': 'blocking',
            'message': issue,
          },
      ],
      'recommendedCommands': const [
        <String, dynamic>{
          'mode': 'review-packet',
          'command': 'eval/run_level2.sh review-packet',
        },
        <String, dynamic>{
          'mode': 'decision-gate',
          'command': 'eval/run_level2.sh decision-gate',
        },
      ],
    };
    packet['reviewPacketRef'] = reviewPacketRef(packet);
    assertValidPacket(packet);
    return packet;
  }

  static String reviewPacketRef(Map<String, dynamic> packet) =>
      EvalProvenance.digestJson(_reviewPacketSubject(packet));

  static List<String> validatePacket(Map<String, dynamic> packet) {
    final issues = <String>[];
    _expectEquals(
      issues,
      packet['schemaVersion'],
      packetSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, packet['kind'], packetKind, 'kind');
    _expectDigest(issues, packet['reviewPacketRef'], 'reviewPacketRef');
    _expectIsoDate(issues, packet['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, packet['status'], 'status');
    if (status != null && !_allowedPacketStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedPacketStatuses.join(', ')}');
    }
    _validateSourceCampaign(
      issues,
      _expectMap(issues, packet['sourceCampaign'], 'sourceCampaign'),
    );
    final summary = _expectMap(issues, packet['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(issues, _expectMap(issues, packet['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, packet['limitations'], 'limitations'),
    );
    final tasks = _expectList(issues, packet['reviewTasks'], 'reviewTasks');
    _validateReviewTasks(issues, tasks);
    final templates = _expectList(
      issues,
      packet['attestationTemplates'],
      'attestationTemplates',
    );
    _validateAttestations(
      issues,
      templates,
      path: 'attestationTemplates',
      requireApproved: false,
    );
    _validateIssues(issues, _expectList(issues, packet['issues'], 'issues'));
    _validateCommands(
      issues,
      _expectList(issues, packet['recommendedCommands'], 'recommendedCommands'),
      'recommendedCommands',
    );
    _validateSummaryInvariants(
      issues,
      summary: summary,
      tasks: tasks,
      templates: templates,
    );
    _validateReviewPacketRef(issues, packet);
    _validateNoPrivatePayloads(issues, packet, 'packet');
    return issues;
  }

  static void assertValidPacket(Map<String, dynamic> packet) {
    final issues = validatePacket(packet);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case adversarial review packet:\n${issues.join('\n')}',
    );
  }

  static Map<String, dynamic> buildAttestationBundle({
    required Map<String, dynamic> campaign,
    required List<Map<String, dynamic>> attestations,
    DateTime? generatedAt,
  }) {
    final campaignIssues = EvalUseCaseTuningCampaign.validate(campaign);
    final campaignDigest = EvalProvenance.digestJson(campaign);
    final campaignRef = EvalUseCaseTuningCampaign.campaignRef(campaign);
    final queue = _map(campaign['adversarialReviewQueue']);
    final sourceQueueDigest = EvalProvenance.digestJson(queue);
    final tasks = campaignIssues.isEmpty
        ? _mapList(queue['tasks'])
        : const <Map<String, dynamic>>[];
    final requiredTasks = [
      for (final task in tasks)
        if (task['required'] == true)
          _reviewTask(
            campaignDigest: campaignDigest,
            sourceQueueDigest: sourceQueueDigest,
            task: task,
          ),
    ];
    final importIssues = _bundleImportIssues(
      requiredTasks: requiredTasks,
      attestations: attestations,
      campaignIssues: campaignIssues,
      sourceArtifactDigest: campaignDigest,
      sourceQueueDigest: sourceQueueDigest,
    );
    final approvedCount = attestations
        .where((attestation) => attestation['status'] == 'approved')
        .length;
    final rejectedCount = attestations
        .where(
          (attestation) =>
              attestation['status'] == 'rejected' ||
              attestation['status'] == 'needsChanges',
        )
        .length;
    final status = importIssues.isNotEmpty
        ? 'invalid'
        : rejectedCount > 0
        ? 'changesRequested'
        : 'approved';
    final bundle = <String, dynamic>{
      'schemaVersion': bundleSchemaVersion,
      'kind': bundleKind,
      'attestationBundleRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceCampaign': <String, dynamic>{
        'kind': EvalUseCaseTuningCampaign.kind,
        'schemaVersion': EvalUseCaseTuningCampaign.schemaVersion,
        'status': _string(campaign['status']).isEmpty
            ? 'unknown'
            : _string(campaign['status']),
        'campaignRef': campaignRef,
        'campaignDigest': campaignDigest,
        'sourceQueueDigest': sourceQueueDigest,
        'contractIssueCount': campaignIssues.length,
        'reviewTaskCount': tasks.length,
      },
      'summary': <String, dynamic>{
        'requiredReviewTaskCount': requiredTasks.length,
        'attestationCount': attestations.length,
        'approvedAttestationCount': approvedCount,
        'rejectedAttestationCount': rejectedCount,
        'issueCount': importIssues.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesCampaignAndReviewInputOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'commandsCreated': false,
      },
      'requiredReviewTasks': requiredTasks,
      'attestations': attestations,
      'issues': importIssues,
    };
    bundle['attestationBundleRef'] = attestationBundleRef(bundle);
    assertValidBundle(bundle);
    if (importIssues.isNotEmpty) {
      throw StateError(
        'Invalid use-case adversarial review attestation bundle:\n'
        '${importIssues.map((issue) => _string(issue['code'])).join('\n')}',
      );
    }
    return bundle;
  }

  static String attestationBundleRef(Map<String, dynamic> bundle) =>
      EvalProvenance.digestJson(_attestationBundleSubject(bundle));

  static List<String> validateBundle(Map<String, dynamic> bundle) {
    final issues = <String>[];
    _expectEquals(
      issues,
      bundle['schemaVersion'],
      bundleSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, bundle['kind'], bundleKind, 'kind');
    _expectDigest(
      issues,
      bundle['attestationBundleRef'],
      'attestationBundleRef',
    );
    _expectIsoDate(issues, bundle['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, bundle['status'], 'status');
    if (status != null && !_allowedBundleStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedBundleStatuses.join(', ')}');
    }
    final sourceCampaign = _expectMap(
      issues,
      bundle['sourceCampaign'],
      'sourceCampaign',
    );
    _validateSourceCampaign(issues, sourceCampaign);
    final summary = _expectMap(issues, bundle['summary'], 'summary');
    _validateBundleSummary(issues, summary);
    _validateBundlePrivacy(
      issues,
      _expectMap(issues, bundle['privacy'], 'privacy'),
    );
    _validateBundleLimitations(
      issues,
      _expectMap(issues, bundle['limitations'], 'limitations'),
    );
    final requiredTasks = _expectList(
      issues,
      bundle['requiredReviewTasks'],
      'requiredReviewTasks',
    );
    _validateReviewTasks(issues, requiredTasks, path: 'requiredReviewTasks');
    final attestations = _expectList(
      issues,
      bundle['attestations'],
      'attestations',
    );
    _validateAttestations(
      issues,
      attestations,
      path: 'attestations',
      requireApproved: false,
    );
    final issueList = _expectList(issues, bundle['issues'], 'issues');
    _validateIssues(issues, issueList);
    _validateBundleSummaryInvariants(
      issues,
      summary: summary,
      sourceCampaign: sourceCampaign,
      requiredTasks: requiredTasks,
      attestations: attestations,
      issueList: issueList,
    );
    _validateAttestationBundleRef(issues, bundle);
    _validateNoPrivatePayloads(issues, bundle, 'bundle');
    return issues;
  }

  static void assertValidBundle(Map<String, dynamic> bundle) {
    final issues = validateBundle(bundle);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case adversarial review attestation bundle:\n'
      '${issues.join('\n')}',
    );
  }

  static List<Map<String, dynamic>> approvedAttestationsFromBundles(
    List<Map<String, dynamic>> bundles,
  ) {
    return [
      for (final bundle in bundles)
        if (validateBundle(bundle).isEmpty && bundle['status'] == 'approved')
          for (final attestation in _mapList(bundle['attestations']))
            if (attestation['status'] == 'approved') attestation,
    ];
  }

  static void assertBundlesValid(List<Map<String, dynamic>> bundles) {
    for (final (index, bundle) in bundles.indexed) {
      final issues = validateBundle(bundle);
      if (issues.isNotEmpty) {
        throw StateError(
          'Invalid use-case adversarial review attestation bundle '
          '$index:\n${issues.join('\n')}',
        );
      }
    }
  }

  static List<Map<String, dynamic>> approvedAttestationsFromValidBundles(
    List<Map<String, dynamic>> bundles,
  ) {
    assertBundlesValid(bundles);
    return [
      for (final bundle in bundles)
        if (bundle['status'] == 'approved')
          for (final attestation in _mapList(bundle['attestations']))
            if (attestation['status'] == 'approved') attestation,
    ];
  }

  static List<String> validateApprovedAttestations(
    List<Map<String, dynamic>> attestations,
  ) {
    final issues = <String>[];
    _validateAttestations(
      issues,
      attestations,
      path: 'reviewAttestations',
      requireApproved: true,
    );
    return issues;
  }

  static String attestationEvidenceDigest(Map<String, dynamic> attestation) =>
      EvalProvenance.digestJson(_attestationEvidenceSubject(attestation));

  static List<Map<String, dynamic>> _bundleImportIssues({
    required List<Map<String, dynamic>> requiredTasks,
    required List<Map<String, dynamic>> attestations,
    required List<String> campaignIssues,
    required String sourceArtifactDigest,
    required String sourceQueueDigest,
  }) {
    final issues = <Map<String, dynamic>>[
      for (final issue in campaignIssues)
        <String, dynamic>{
          'code': 'campaign.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
    ];
    final attestationIssues = validateApprovedAttestations(
      attestations
          .where((attestation) => attestation['status'] == 'approved')
          .toList(),
    );
    final allAttestationIssues = <String>[];
    _validateAttestations(
      allAttestationIssues,
      attestations,
      path: 'attestations',
      requireApproved: false,
    );
    for (final issue in {...allAttestationIssues, ...attestationIssues}) {
      issues.add(
        <String, dynamic>{
          'code': 'reviewAttestation.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      );
    }
    final requiredKeys = {
      for (final task in requiredTasks)
        _reviewKey(
          sourceArtifactDigest: sourceArtifactDigest,
          sourceQueueDigest: sourceQueueDigest,
          reviewRef: _string(task['reviewRef']),
          category: _string(task['category']),
        ): task,
    };
    final seen = <String, Map<String, dynamic>>{};
    for (final attestation in attestations) {
      if (_string(attestation['status']) == 'pending') {
        issues.add(
          const <String, dynamic>{
            'code': 'reviewAttestation.pendingStatus',
            'severity': 'blocking',
          },
        );
      }
      final key = _reviewKey(
        sourceArtifactDigest: _string(attestation['sourceArtifactDigest']),
        sourceQueueDigest: _string(attestation['sourceQueueDigest']),
        reviewRef: _string(attestation['reviewRef']),
        category: _string(attestation['category']),
      );
      if (_string(attestation['sourceArtifactDigest']) !=
          sourceArtifactDigest) {
        issues.add(
          const <String, dynamic>{
            'code': 'reviewAttestation.sourceDigestMismatch',
            'severity': 'blocking',
          },
        );
      }
      if (_string(attestation['sourceQueueDigest']) != sourceQueueDigest) {
        issues.add(
          const <String, dynamic>{
            'code': 'reviewAttestation.sourceQueueDigestMismatch',
            'severity': 'blocking',
          },
        );
      }
      if (!requiredKeys.containsKey(key)) {
        issues.add(
          <String, dynamic>{
            'code': 'reviewAttestation.unmatchedTask',
            'severity': 'blocking',
            'reviewRef': _string(attestation['reviewRef']),
            'category': _string(attestation['category']),
          },
        );
      }
      if (seen.containsKey(key)) {
        issues.add(
          <String, dynamic>{
            'code': 'reviewAttestation.duplicateTask',
            'severity': 'blocking',
            'reviewRef': _string(attestation['reviewRef']),
            'category': _string(attestation['category']),
          },
        );
      }
      seen[key] = attestation;
    }
    for (final key in requiredKeys.keys) {
      if (!seen.containsKey(key)) {
        final task = requiredKeys[key]!;
        issues.add(
          <String, dynamic>{
            'code': 'reviewAttestation.missingTask',
            'severity': 'blocking',
            'reviewRef': _string(task['reviewRef']),
            'category': _string(task['category']),
          },
        );
      }
    }
    return issues;
  }

  static Map<String, dynamic> _reviewTask({
    required String campaignDigest,
    required String sourceQueueDigest,
    required Map<String, dynamic> task,
  }) {
    final sourceRefs = _map(task['sourceRefs']);
    return <String, dynamic>{
      'sourceArtifactDigest': campaignDigest,
      'sourceQueueDigest': sourceQueueDigest,
      'reviewRef': _string(task['reviewRef']),
      'category': _string(task['category']),
      'required': task['required'] == true,
      'mustCheck': _stringList(task['mustCheck']),
      'sourceRefs': <String, dynamic>{
        'sourceExperimentPlanDigest': _string(
          sourceRefs['sourceExperimentPlanDigest'],
        ),
        'batchRefs': _stringList(sourceRefs['batchRefs']),
        'blockedReasonCodes': _stringList(sourceRefs['blockedReasonCodes']),
      },
      'privateValuesOmitted': true,
      'commandsOmitted': true,
      'completionEvidenceOmitted': true,
    };
  }

  static Map<String, dynamic> _attestationTemplate({
    required String sourceArtifactDigest,
    required String sourceQueueDigest,
    required Map<String, dynamic> task,
  }) {
    final template = <String, dynamic>{
      'schemaVersion': attestationSchemaVersion,
      'kind': attestationKind,
      'sourceArtifactDigest': sourceArtifactDigest,
      'sourceQueueDigest': sourceQueueDigest,
      'reviewRef': _string(task['reviewRef']),
      'category': _string(task['category']),
      'status': 'pending',
      'privateValuesOmitted': true,
      'commandsOmitted': true,
      'reviewCompletionClaimsCreated': false,
    };
    template['evidenceDigest'] = attestationEvidenceDigest(template);
    return template;
  }

  static void _validateSourceCampaign(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseTuningCampaign.kind,
      'sourceCampaign.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseTuningCampaign.schemaVersion,
      'sourceCampaign.schemaVersion',
    );
    _expectNonEmptyString(issues, source['status'], 'sourceCampaign.status');
    _expectDigest(
      issues,
      source['campaignRef'],
      'sourceCampaign.campaignRef',
    );
    _expectDigest(
      issues,
      source['campaignDigest'],
      'sourceCampaign.campaignDigest',
    );
    _expectDigest(
      issues,
      source['sourceQueueDigest'],
      'sourceCampaign.sourceQueueDigest',
    );
    for (final field in const [
      'contractIssueCount',
      'reviewTaskCount',
    ]) {
      _expectNonNegativeInt(issues, source[field], 'sourceCampaign.$field');
    }
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'reviewTaskCount',
      'attestationTemplateCount',
      'campaignContractIssueCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validateBundleSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'requiredReviewTaskCount',
      'attestationCount',
      'approvedAttestationCount',
      'rejectedAttestationCount',
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
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
      'reviewCompletionClaimsCreated': false,
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

  static void _validateBundlePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'rawRunIdsOmitted': true,
      'profileNamesOmitted': true,
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
      'consumesCampaignOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'attestationsApproved': false,
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

  static void _validateBundleLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesCampaignAndReviewInputOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'commandsCreated': false,
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

  static void _validateReviewTasks(
    List<String> issues,
    List<dynamic>? tasks, {
    String path = 'reviewTasks',
  }) {
    if (tasks == null) return;
    for (final (index, value) in tasks.indexed) {
      final task = _expectMap(issues, value, '$path[$index]');
      if (task == null) continue;
      _expectDigest(
        issues,
        task['sourceArtifactDigest'],
        '$path[$index].sourceArtifactDigest',
      );
      _expectDigest(
        issues,
        task['sourceQueueDigest'],
        '$path[$index].sourceQueueDigest',
      );
      _expectDigest(issues, task['reviewRef'], '$path[$index].reviewRef');
      final category = _expectNonEmptyString(
        issues,
        task['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
      }
      _expectBool(issues, task['required'], '$path[$index].required');
      final mustCheck = _expectStringList(
        issues,
        task['mustCheck'],
        '$path[$index].mustCheck',
      );
      if (mustCheck != null && mustCheck.isEmpty) {
        issues.add('$path[$index].mustCheck must not be empty');
      }
      _validateReviewTaskSourceRefs(
        issues,
        _expectMap(issues, task['sourceRefs'], '$path[$index].sourceRefs'),
        '$path[$index].sourceRefs',
      );
      _expectEquals(
        issues,
        task['privateValuesOmitted'],
        true,
        '$path[$index].privateValuesOmitted',
      );
      _expectEquals(
        issues,
        task['commandsOmitted'],
        true,
        '$path[$index].commandsOmitted',
      );
      _expectEquals(
        issues,
        task['completionEvidenceOmitted'],
        true,
        '$path[$index].completionEvidenceOmitted',
      );
    }
  }

  static void _validateReviewTaskSourceRefs(
    List<String> issues,
    Map<String, dynamic>? sourceRefs,
    String path,
  ) {
    if (sourceRefs == null) return;
    _expectDigest(
      issues,
      sourceRefs['sourceExperimentPlanDigest'],
      '$path.sourceExperimentPlanDigest',
    );
    _expectStringList(issues, sourceRefs['batchRefs'], '$path.batchRefs');
    _expectStringList(
      issues,
      sourceRefs['blockedReasonCodes'],
      '$path.blockedReasonCodes',
    );
  }

  static void _validateAttestations(
    List<String> issues,
    List<dynamic>? attestations, {
    required String path,
    required bool requireApproved,
  }) {
    if (attestations == null) return;
    for (final (index, value) in attestations.indexed) {
      final attestation = _expectMap(issues, value, '$path[$index]');
      if (attestation == null) continue;
      _expectEquals(
        issues,
        attestation['schemaVersion'],
        attestationSchemaVersion,
        '$path[$index].schemaVersion',
      );
      _expectEquals(
        issues,
        attestation['kind'],
        attestationKind,
        '$path[$index].kind',
      );
      _expectDigest(
        issues,
        attestation['sourceArtifactDigest'],
        '$path[$index].sourceArtifactDigest',
      );
      _expectDigest(
        issues,
        attestation['sourceQueueDigest'],
        '$path[$index].sourceQueueDigest',
      );
      _expectDigest(
        issues,
        attestation['reviewRef'],
        '$path[$index].reviewRef',
      );
      _expectDigest(
        issues,
        attestation['evidenceDigest'],
        '$path[$index].evidenceDigest',
      );
      final category = _expectNonEmptyString(
        issues,
        attestation['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
      }
      final status = _expectNonEmptyString(
        issues,
        attestation['status'],
        '$path[$index].status',
      );
      if (status != null && !_allowedAttestationStatuses.contains(status)) {
        issues.add('$path[$index].status must be supported');
      }
      if (requireApproved && status != 'approved') {
        issues.add('$path[$index].status must be approved');
      }
      if (status == 'approved') {
        _expectDigest(
          issues,
          attestation['reviewerRefDigest'],
          '$path[$index].reviewerRefDigest',
        );
        _expectIsoDate(
          issues,
          attestation['reviewedAt'],
          '$path[$index].reviewedAt',
        );
      }
      _expectEquals(
        issues,
        attestation['privateValuesOmitted'],
        true,
        '$path[$index].privateValuesOmitted',
      );
      _expectEquals(
        issues,
        attestation['commandsOmitted'],
        true,
        '$path[$index].commandsOmitted',
      );
      _expectEquals(
        issues,
        attestation['reviewCompletionClaimsCreated'],
        false,
        '$path[$index].reviewCompletionClaimsCreated',
      );
      for (final forbidden in const [
        'command',
        'commands',
        'env',
        'nextRunEnv',
        'recommendedCommands',
        'shell',
        'shellCommand',
        'reviewedBy',
        'reviewer',
        'reviewerRef',
        'scenarioIds',
        'profileNames',
        'runId',
        'baseRunId',
        'completionEvidence',
      ]) {
        if (attestation.containsKey(forbidden)) {
          issues.add('$path[$index] must not contain $forbidden');
        }
      }
      _validateAttestationEvidenceDigest(
        issues,
        attestation,
        '$path[$index]',
      );
      _validateNoPrivatePayloads(issues, attestation, '$path[$index]');
    }
  }

  static void _validateAttestationEvidenceDigest(
    List<String> issues,
    Map<String, dynamic> attestation,
    String path,
  ) {
    final expectedDigest = attestationEvidenceDigest(attestation);
    if (attestation['evidenceDigest'] != expectedDigest) {
      issues.add('$path.evidenceDigest must bind review attestation fields');
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
    String path,
  ) {
    if (commands == null) return;
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
      if (command.containsKey('env')) {
        issues.add('$path[$index] must not contain env values');
      }
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? tasks,
    required List<dynamic>? templates,
  }) {
    if (summary == null) return;
    if (tasks != null &&
        summary['reviewTaskCount'] is int &&
        summary['reviewTaskCount'] != tasks.length) {
      issues.add('summary.reviewTaskCount must match reviewTasks.length');
    }
    if (templates != null &&
        summary['attestationTemplateCount'] is int &&
        summary['attestationTemplateCount'] != templates.length) {
      issues.add(
        'summary.attestationTemplateCount must match templates.length',
      );
    }
  }

  static void _validateBundleSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required Map<String, dynamic>? sourceCampaign,
    required List<dynamic>? requiredTasks,
    required List<dynamic>? attestations,
    required List<dynamic>? issueList,
  }) {
    if (summary == null) return;
    if (requiredTasks != null &&
        summary['requiredReviewTaskCount'] is int &&
        summary['requiredReviewTaskCount'] != requiredTasks.length) {
      issues.add(
        'summary.requiredReviewTaskCount must match requiredReviewTasks.length',
      );
    }
    if (attestations != null &&
        summary['attestationCount'] is int &&
        summary['attestationCount'] != attestations.length) {
      issues.add('summary.attestationCount must match attestations.length');
    }
    if (issueList != null &&
        summary['issueCount'] is int &&
        summary['issueCount'] != issueList.length) {
      issues.add('summary.issueCount must match issues.length');
    }
    if (attestations != null) {
      final approvedCount = _attestationStatusCount(attestations, {
        'approved',
      });
      if (summary['approvedAttestationCount'] is int &&
          summary['approvedAttestationCount'] != approvedCount) {
        issues.add(
          'summary.approvedAttestationCount must match approved attestations',
        );
      }
      final rejectedCount = _attestationStatusCount(attestations, {
        'rejected',
        'needsChanges',
      });
      if (summary['rejectedAttestationCount'] is int &&
          summary['rejectedAttestationCount'] != rejectedCount) {
        issues.add(
          'summary.rejectedAttestationCount must match rejected attestations',
        );
      }
    }
    if (sourceCampaign != null &&
        requiredTasks != null &&
        attestations != null) {
      _validateBundleTaskCoverage(
        issues,
        sourceCampaign: sourceCampaign,
        requiredTasks: requiredTasks,
        attestations: attestations,
      );
    }
  }

  static int _attestationStatusCount(
    List<dynamic> attestations,
    Set<String> statuses,
  ) => attestations
      .whereType<Map<String, dynamic>>()
      .where((attestation) => statuses.contains(attestation['status']))
      .length;

  static void _validateBundleTaskCoverage(
    List<String> issues, {
    required Map<String, dynamic> sourceCampaign,
    required List<dynamic> requiredTasks,
    required List<dynamic> attestations,
  }) {
    final sourceArtifactDigest = _string(sourceCampaign['campaignDigest']);
    final sourceQueueDigest = _string(sourceCampaign['sourceQueueDigest']);
    final requiredKeys = <String>{};
    for (final (index, value) in requiredTasks.indexed) {
      if (value is! Map<String, dynamic>) continue;
      if (value['sourceArtifactDigest'] != sourceArtifactDigest) {
        issues.add(
          'requiredReviewTasks[$index].sourceArtifactDigest must match sourceCampaign.campaignDigest',
        );
      }
      if (value['sourceQueueDigest'] != sourceQueueDigest) {
        issues.add(
          'requiredReviewTasks[$index].sourceQueueDigest must match sourceCampaign.sourceQueueDigest',
        );
      }
      if (value['required'] != true) {
        issues.add('requiredReviewTasks[$index].required must be true');
      }
      final key = _reviewKey(
        sourceArtifactDigest: _string(value['sourceArtifactDigest']),
        sourceQueueDigest: _string(value['sourceQueueDigest']),
        reviewRef: _string(value['reviewRef']),
        category: _string(value['category']),
      );
      if (!requiredKeys.add(key)) {
        issues.add('requiredReviewTasks[$index] must not duplicate a task');
      }
    }

    final seen = <String>{};
    for (final (index, value) in attestations.indexed) {
      if (value is! Map<String, dynamic>) continue;
      if (value['status'] == 'pending') {
        issues.add('attestations[$index].status must not be pending');
      }
      final key = _reviewKey(
        sourceArtifactDigest: _string(value['sourceArtifactDigest']),
        sourceQueueDigest: _string(value['sourceQueueDigest']),
        reviewRef: _string(value['reviewRef']),
        category: _string(value['category']),
      );
      if (!requiredKeys.contains(key)) {
        issues.add('attestations[$index] must match a required review task');
      }
      if (!seen.add(key)) {
        issues.add('attestations[$index] must not duplicate a review task');
      }
    }

    for (final key in requiredKeys) {
      if (!seen.contains(key)) {
        issues.add('attestations must cover every requiredReviewTasks entry');
      }
    }
  }

  static String _reviewKey({
    required String sourceArtifactDigest,
    required String sourceQueueDigest,
    required String reviewRef,
    required String category,
  }) => [
    sourceArtifactDigest,
    sourceQueueDigest,
    reviewRef,
    category,
  ].join(':');

  static void _validateReviewPacketRef(
    List<String> issues,
    Map<String, dynamic> packet,
  ) {
    final expectedRef = reviewPacketRef(packet);
    if (packet['reviewPacketRef'] != expectedRef) {
      issues.add(
        'reviewPacketRef must match adversarial review packet subject digest',
      );
    }
  }

  static void _validateAttestationBundleRef(
    List<String> issues,
    Map<String, dynamic> bundle,
  ) {
    final expectedRef = attestationBundleRef(bundle);
    if (bundle['attestationBundleRef'] != expectedRef) {
      issues.add(
        'attestationBundleRef must match adversarial review bundle subject digest',
      );
    }
  }

  static Map<String, dynamic> _reviewPacketSubject(
    Map<String, dynamic> packet,
  ) => <String, dynamic>{
    'kind': packetKind,
    'schemaVersion': packetSchemaVersion,
    'status': _string(packet['status']),
    'sourceCampaignDigest': EvalProvenance.digestJson(
      _map(packet['sourceCampaign']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(packet['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(packet['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(packet['limitations']),
    ),
    'reviewTasksDigest': EvalProvenance.digestJson(
      _mapList(packet['reviewTasks']),
    ),
    'attestationTemplatesDigest': EvalProvenance.digestJson(
      _mapList(packet['attestationTemplates']),
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(packet['issues'])),
  };

  static Map<String, dynamic> _attestationBundleSubject(
    Map<String, dynamic> bundle,
  ) => <String, dynamic>{
    'kind': bundleKind,
    'schemaVersion': bundleSchemaVersion,
    'status': _string(bundle['status']),
    'sourceCampaignDigest': EvalProvenance.digestJson(
      _map(bundle['sourceCampaign']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(bundle['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(bundle['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(bundle['limitations']),
    ),
    'requiredReviewTasksDigest': EvalProvenance.digestJson(
      _mapList(bundle['requiredReviewTasks']),
    ),
    'attestationsDigest': EvalProvenance.digestJson(
      _mapList(bundle['attestations']),
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(bundle['issues'])),
  };

  static Map<String, dynamic> _attestationEvidenceSubject(
    Map<String, dynamic> attestation,
  ) => <String, dynamic>{
    'kind': attestationKind,
    'schemaVersion': attestationSchemaVersion,
    'sourceArtifactDigest': _string(attestation['sourceArtifactDigest']),
    'sourceQueueDigest': _string(attestation['sourceQueueDigest']),
    'reviewRef': _string(attestation['reviewRef']),
    'category': _string(attestation['category']),
    'status': _string(attestation['status']),
    'reviewerRefDigest': _string(attestation['reviewerRefDigest']),
    'reviewedAt': _string(attestation['reviewedAt']),
    'privateValuesOmitted': attestation['privateValuesOmitted'] == true,
    'commandsOmitted': attestation['commandsOmitted'] == true,
    'reviewCompletionClaimsCreated':
        attestation['reviewCompletionClaimsCreated'] == true,
  };

  static void _validateNoPrivatePayloads(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (_privateFieldReason(normalized) case final reason?) {
          issues.add('$path.$key must not expose $reason');
        }
        _validateNoPrivatePayloads(issues, entry.value, '$path.$key');
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoPrivatePayloads(issues, item, '$path[$index]');
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
      if (value.contains('<redacted-scenario')) {
        issues.add('$path must not contain redacted scenario placeholders');
      }
      if (_scenarioFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain scenario id field names');
      }
      if (_profileFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain profile selector field names');
      }
    }
  }

  static String? _privateFieldReason(String normalized) {
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

  static String? _expectNonEmptyString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is String && value.trim().isNotEmpty) return value;
    issues.add('$path must be a non-empty string');
    return null;
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

  static void _expectBool(List<String> issues, Object? value, String path) {
    if (value is bool) return;
    issues.add('$path must be a boolean');
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

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}
