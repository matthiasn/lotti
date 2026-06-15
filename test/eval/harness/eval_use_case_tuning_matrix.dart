import 'eval_provenance.dart';
import 'eval_tuning_report_contract.dart';
import 'eval_tuning_report_source_check.dart';

abstract final class EvalUseCaseTuningMatrix {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseTuningMatrix';
  static const nextExperimentPlanKind =
      'lotti.evalUseCaseTuningMatrixNextExperimentPlan';
  static const _allowedStatuses = {
    'invalid',
    'insufficientReports',
    'incompatible',
    'promotionReady',
    'diagnosticOnly',
    'dataDeficient',
    'blocked',
  };
  static final _safeSelectorPattern = RegExp(r'^[A-Za-z0-9_.:-]+$');
  static final _opaqueFallbackPattern = RegExp(
    r'^(capability|agent|model|prompt|recommendation)-[0-9a-f]{12}$',
  );
  static final _scenarioFieldTokenPattern = RegExp(
    r'\b(?:scenarioId|scenarioIds|[A-Za-z0-9_]*ScenarioIds)\b',
  );
  static final _liveRunLevel2CommandPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:\./)?eval/run_level2\.sh\s+'
    r'(?:plan|run|tune|all)(?=$|[^A-Za-z0-9_-])',
  );
  static final Expando<String> _verifiedSourceReplayDigests = Expando<String>(
    'evalUseCaseTuningMatrixSourceReplayDigest',
  );

  static Map<String, dynamic> build({
    required List<Map<String, dynamic>> reports,
    Map<String, EvalTuningReportSourceCheckResult> sourceChecksByReportDigest =
        const {},
    bool requireSourceChecks = true,
    DateTime? generatedAt,
  }) {
    final deniedValues = _collectDeniedValues(reports);
    final snapshots = [
      for (final indexed in reports.indexed)
        _ReportSnapshot.fromReport(
          index: indexed.$1,
          report: indexed.$2,
          deniedValues: deniedValues,
          sourceCheck:
              sourceChecksByReportDigest[EvalProvenance.digestJson(
                indexed.$2,
              )],
          requireSourceCheck: requireSourceChecks,
        ),
    ];
    final validSnapshots = [
      for (final snapshot in snapshots)
        if (snapshot.valid) snapshot,
    ];
    final groups = _groups(validSnapshots, deniedValues);
    final groupJson = [for (final group in groups) group.toJson()];
    final matrixCells = [
      for (final group in groupJson)
        for (final cell in _mapList(group['matrixCells']))
          <String, dynamic>{
            'compatibilityKey': _string(group['compatibilityKey']),
            ...cell,
          },
    ];
    final issues = _issues(
      snapshots: snapshots,
      groupJson: groupJson,
    );
    final status = _status(
      snapshots: snapshots,
      groupJson: groupJson,
    );
    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'summary': <String, dynamic>{
        'inputReportCount': snapshots.length,
        'validReportCount': validSnapshots.length,
        'invalidReportCount': snapshots.length - validSnapshots.length,
        'compatibilityGroupCount': groupJson.length,
        'matrixCellCount': matrixCells.length,
        'evidenceGapCount': _evidenceGapCount(groupJson),
        'promotionReadyCellCount': _statusCount(
          matrixCells,
          'promotionReady',
        ),
        'diagnosticOnlyCellCount': _statusCount(
          matrixCells,
          'diagnosticOnly',
        ),
        'dataDeficientCellCount': _statusCount(
          matrixCells,
          'dataDeficient',
        ),
      },
      'privacy': <String, dynamic>{
        'scenarioIdsOmitted': true,
        'deniedValueCount': deniedValues.length,
        'redactedPlaceholderCount': _redactedPlaceholderCount(reports),
        'unsafeSelectorValueCount': _unsafeSelectorValueCount(snapshots),
        'reason':
            'matrix reports never expose scenario ids, raw run ids, or '
            'redacted scenario placeholders',
      },
      'limitations': <String, dynamic>{
        'consumesTuningReportsOnly': true,
        'tracesReRead':
            requireSourceChecks || sourceChecksByReportDigest.isNotEmpty,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'promotionClaimRequiresSourcePromotionEvidence': true,
      },
      'inputReports': [for (final snapshot in snapshots) snapshot.toJson()],
      'compatibilityGroups': groupJson,
      'matrixCells': matrixCells,
      'gaps': _gaps(groupJson),
      'issues': issues,
      'nextExperimentPlan': _nextExperimentPlan(
        status: status,
        issues: issues,
        groups: groupJson,
        snapshots: snapshots,
      ),
    };
    assertValid(artifact, deniedValues: deniedValues);
    return artifact;
  }

  static List<String> validate(
    Map<String, dynamic> matrix, {
    Iterable<String> deniedValues = const [],
  }) {
    final issues = <String>[];
    _expectEquals(
      issues,
      matrix['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, matrix['kind'], kind, 'kind');
    _expectIsoDate(issues, matrix['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, matrix['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final summary = _expectMap(issues, matrix['summary'], 'summary');
    final inputReports = _expectList(
      issues,
      matrix['inputReports'],
      'inputReports',
    );
    final groups = _expectList(
      issues,
      matrix['compatibilityGroups'],
      'compatibilityGroups',
    );
    final cells = _expectList(issues, matrix['matrixCells'], 'matrixCells');
    _validateSummary(
      issues,
      summary: summary,
      inputReports: inputReports,
      groups: groups,
      cells: cells,
    );
    _validatePrivacy(issues, _expectMap(issues, matrix['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, matrix['limitations'], 'limitations'),
    );
    _validateInputReports(issues, inputReports);
    _validateGroups(issues, groups);
    _validateCells(issues, cells, 'matrixCells');
    _validateGaps(issues, _expectList(issues, matrix['gaps'], 'gaps'));
    _validateIssues(issues, _expectList(issues, matrix['issues'], 'issues'));
    _validateNextPlan(
      issues,
      _expectMap(
        issues,
        matrix['nextExperimentPlan'],
        'nextExperimentPlan',
      ),
      status,
    );
    _validateNoScenarioIds(issues, matrix, 'matrix');
    _validateNoDeniedValues(issues, matrix, 'matrix', deniedValues.toSet());
    return issues;
  }

  static void assertValid(
    Map<String, dynamic> matrix, {
    Iterable<String> deniedValues = const [],
  }) {
    final issues = validate(matrix, deniedValues: deniedValues);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning matrix:\n${issues.join('\n')}',
    );
  }

  static bool hasVerifiedSourceReplay(Map<String, dynamic> matrix) =>
      _verifiedSourceReplayDigests[matrix] == EvalProvenance.digestJson(matrix);

  static List<String> validateAgainstSources(
    Map<String, dynamic> matrix, {
    required List<Map<String, dynamic>> reports,
    Map<String, EvalTuningReportSourceCheckResult> sourceChecksByReportDigest =
        const {},
    bool requireSourceChecks = true,
  }) {
    final issues = validate(matrix);
    final generatedAt = DateTime.tryParse(_string(matrix['generatedAt']));
    if (generatedAt == null) {
      issues.add('generatedAt must be an ISO-8601 timestamp');
      return issues;
    }
    Map<String, dynamic> expected;
    try {
      expected = build(
        reports: reports,
        sourceChecksByReportDigest: sourceChecksByReportDigest,
        requireSourceChecks: requireSourceChecks,
        generatedAt: generatedAt,
      );
    } catch (error) {
      issues.add('source artifacts cannot build matrix: $error');
      return issues;
    }

    void expectMatches(String field) {
      if (EvalProvenance.digestJson(matrix[field]) ==
          EvalProvenance.digestJson(expected[field])) {
        return;
      }
      issues.add('$field must match matrix source artifacts');
    }

    const [
      'status',
      'summary',
      'privacy',
      'limitations',
      'inputReports',
      'compatibilityGroups',
      'matrixCells',
      'gaps',
      'issues',
      'nextExperimentPlan',
    ].forEach(expectMatches);
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> matrix, {
    required List<Map<String, dynamic>> reports,
    Map<String, EvalTuningReportSourceCheckResult> sourceChecksByReportDigest =
        const {},
    bool requireSourceChecks = true,
  }) {
    final issues = validateAgainstSources(
      matrix,
      reports: reports,
      sourceChecksByReportDigest: sourceChecksByReportDigest,
      requireSourceChecks: requireSourceChecks,
    );
    if (issues.isEmpty) {
      _verifiedSourceReplayDigests[matrix] = EvalProvenance.digestJson(matrix);
      return;
    }
    throw StateError(
      'Invalid use-case tuning matrix source binding:\n${issues.join('\n')}',
    );
  }

  static Set<String> _collectDeniedValues(List<Map<String, dynamic>> reports) {
    final values = <String>{};
    void collect(Object? value, {String key = ''}) {
      if (value is Map) {
        for (final entry in value.entries) {
          final childKey = entry.key.toString();
          final normalized = childKey.toLowerCase();
          if (normalized == 'scenarioid' ||
              normalized == 'scenarioids' ||
              normalized.endsWith('scenarioids') ||
              normalized == 'runid' ||
              normalized == 'baserunid') {
            _collectStrings(entry.value, values);
          }
          collect(entry.value, key: childKey);
        }
        return;
      }
      if (value is List) {
        for (final item in value) {
          collect(item, key: key);
        }
      }
    }

    reports.forEach(collect);
    return values.where((value) => value.trim().isNotEmpty).toSet();
  }

  static void _collectStrings(Object? value, Set<String> out) {
    if (value is String) {
      out.add(value);
    } else if (value is List) {
      for (final item in value) {
        _collectStrings(item, out);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        _collectStrings(item, out);
      }
    }
  }

  static List<_CompatibilityGroup> _groups(
    List<_ReportSnapshot> snapshots,
    Set<String> deniedValues,
  ) {
    final byKey = <String, _CompatibilityGroup>{};
    for (final snapshot in snapshots) {
      byKey
          .putIfAbsent(
            snapshot.compatibilityKey,
            () => _CompatibilityGroup(
              fixedEvidence: snapshot.compatibilityEvidence,
              deniedValues: deniedValues,
            ),
          )
          .add(snapshot);
    }
    return byKey.values.toList()
      ..sort((a, b) => a.compatibilityKey.compareTo(b.compatibilityKey));
  }

  static List<Map<String, dynamic>> _issues({
    required List<_ReportSnapshot> snapshots,
    required List<Map<String, dynamic>> groupJson,
  }) {
    final issues = <Map<String, dynamic>>[
      for (final snapshot in snapshots)
        if (!snapshot.valid)
          <String, dynamic>{
            'code': 'report.contractInvalid',
            'severity': 'blocking',
            'reportRef': snapshot.reportRef,
            'messages': snapshot.publicContractIssues,
          },
    ];
    if (snapshots.where((snapshot) => snapshot.valid).isEmpty) {
      issues.add(
        const <String, dynamic>{
          'code': 'matrix.noValidReports',
          'severity': 'blocking',
        },
      );
    }
    if (groupJson.length > 1) {
      issues.add(
        <String, dynamic>{
          'code': 'compatibility.multipleGroups',
          'severity': 'blocking',
          'compatibilityGroupCount': groupJson.length,
        },
      );
    }
    return issues;
  }

  static String _status({
    required List<_ReportSnapshot> snapshots,
    required List<Map<String, dynamic>> groupJson,
  }) {
    if (snapshots.any((snapshot) => !snapshot.valid)) return 'invalid';
    if (snapshots.isEmpty || groupJson.isEmpty) return 'insufficientReports';
    if (groupJson.length > 1) return 'incompatible';
    if (groupJson.any((group) => group['status'] == 'promotionReady')) {
      return 'promotionReady';
    }
    if (groupJson.any((group) => group['status'] == 'diagnosticOnly')) {
      return 'diagnosticOnly';
    }
    if (groupJson.any((group) => group['status'] == 'dataDeficient')) {
      return 'dataDeficient';
    }
    return 'blocked';
  }

  static int _statusCount(List<Map<String, dynamic>> cells, String status) {
    return cells.where((cell) => cell['evidenceStatus'] == status).length;
  }

  static int _evidenceGapCount(List<Map<String, dynamic>> groups) {
    return groups.fold<int>(
      0,
      (count, group) => count + _mapList(group['evidenceGaps']).length,
    );
  }

  static List<Map<String, dynamic>> _gaps(List<Map<String, dynamic>> groups) {
    return [
      for (final group in groups)
        for (final gap in _mapList(group['evidenceGaps']))
          <String, dynamic>{
            'compatibilityKey': _string(group['compatibilityKey']),
            ...gap,
          },
      for (final group in groups)
        for (final cell in _mapList(group['matrixCells']))
          if (_stringList(cell['blockingReasonCodes']).isNotEmpty)
            <String, dynamic>{
              'compatibilityKey': _string(group['compatibilityKey']),
              'cellKey': _string(cell['cellKey']),
              'primaryCapabilityId': _string(cell['primaryCapabilityId']),
              'agentKind': _string(cell['agentKind']),
              'blockerCodes': _stringList(cell['blockingReasonCodes']),
            },
    ];
  }

  static Map<String, dynamic> _nextExperimentPlan({
    required String status,
    required List<Map<String, dynamic>> issues,
    required List<Map<String, dynamic>> groups,
    required List<_ReportSnapshot> snapshots,
  }) {
    final blockedCodes = _sortedStrings({
      for (final issue in issues) _string(issue['code']),
      for (final group in groups)
        for (final gap in _mapList(group['evidenceGaps']))
          ..._stringList(gap['blockerCodes']),
      for (final group in groups)
        for (final cell in _mapList(group['matrixCells']))
          ..._stringList(cell['blockingReasonCodes']),
    });
    final groupPlans = [
      for (final group in groups) _groupPlan(group, matrixStatus: status),
    ];
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': nextExperimentPlanKind,
      'status': status,
      'objective': _objective(status),
      'sourceReportRefs': _sortedStrings(
        snapshots
            .where((snapshot) => snapshot.valid)
            .map(
              (snapshot) => snapshot.reportRef,
            ),
      ),
      'blockedReasonCodes': blockedCodes,
      'withheldSelectors': <String, dynamic>{
        'scenarioIdsOmitted': true,
        'sourceReportScenarioSelectorCount': snapshots.fold<int>(
          0,
          (count, snapshot) => count + snapshot.scenarioSelectorCount,
        ),
        'reason': 'select scenarios from private catalogs or source reports',
      },
      'manualPrerequisites': [
        for (final code in blockedCodes)
          <String, dynamic>{
            'code': code,
            'action': _manualAction(code),
          },
      ],
      'groupPlans': groupPlans,
      'recommendedCommands': _recommendedCommands(),
    };
  }

  static Map<String, dynamic> _groupPlan(
    Map<String, dynamic> group, {
    required String matrixStatus,
  }) {
    final cells = _mapList(group['matrixCells']);
    final blockedCodes = _sortedStrings({
      for (final gap in _mapList(group['evidenceGaps']))
        ..._stringList(gap['blockerCodes']),
      for (final cell in cells) ..._stringList(cell['blockingReasonCodes']),
    });
    final safeCapabilities = _safeSelectorValues(
      cells.map((cell) => _string(cell['primaryCapabilityId'])),
    );
    final safePromptVariants = _safeSelectorValues(
      cells.map((cell) => _string(cell['promptVariantName'])),
    );
    final env = <String, dynamic>{
      if (safeCapabilities.isNotEmpty)
        'EVAL_REQUIRED_CAPABILITIES': safeCapabilities.join(','),
      if (safePromptVariants.isNotEmpty)
        'EVAL_PROMPT_VARIANT_NAMES': safePromptVariants.join(','),
    };
    final status = _string(group['status']);
    return <String, dynamic>{
      'compatibilityKey': _string(group['compatibilityKey']),
      'status': status,
      'sourceReportRefs': _stringList(group['sourceReportRefs']),
      'blockedReasonCodes': blockedCodes,
      'safeSelectors': <String, dynamic>{
        'capabilities': safeCapabilities,
        'modelClasses': _safeSelectorValues(
          cells.map((cell) => _string(cell['modelClass'])),
        ),
        'promptVariantNames': safePromptVariants,
      },
      'withheldSelectors': const <String, dynamic>{
        'scenarioIdsOmitted': true,
      },
      'nextRunEnv': env,
      'manualPrerequisites': [
        for (final code in blockedCodes)
          <String, dynamic>{
            'code': code,
            'action': _manualAction(code),
          },
      ],
      'recommendedCommands': _recommendedCommands(),
    };
  }

  static String _objective(String status) => switch (status) {
    'promotionReady' => 'reviewUseCasePromotionCandidates',
    'diagnosticOnly' => 'collectPromotionEvidenceForLeadingUseCases',
    'dataDeficient' => 'closeUseCaseEvidenceGaps',
    'incompatible' => 'compareWithinCompatibilityGroups',
    'invalid' => 'fixInvalidTuningReports',
    'insufficientReports' => 'collectTuningReports',
    _ => 'closeUseCaseBlockers',
  };

  static String _manualAction(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('contract')) return 'regenerateTuningReport';
    if (normalized.contains('compatibility')) return 'compareWithinGroup';
    if (normalized.contains('coverage') || normalized.contains('capability')) {
      return 'addRequiredCapabilityCoverage';
    }
    if (normalized.contains('calibration') || normalized.contains('human')) {
      return 'completeHumanCalibration';
    }
    if (normalized.contains('pairwise')) return 'completePairwiseReview';
    if (normalized.contains('verdict') || normalized.contains('judge')) {
      return 'gradeMissingVerdicts';
    }
    return 'collectMissingEvidence';
  }

  static List<Map<String, dynamic>> _recommendedCommands() {
    return const [
      <String, dynamic>{
        'mode': 'use-case-matrix',
        'command': 'eval/run_level2.sh use-case-matrix',
      },
      <String, dynamic>{
        'mode': 'experiment-plan',
        'command': 'eval/run_level2.sh experiment-plan',
      },
    ];
  }

  static int _redactedPlaceholderCount(Object? value) {
    var count = 0;
    void visit(Object? node) {
      if (node is Map) {
        for (final entry in node.entries) {
          visit(entry.key);
          visit(entry.value);
        }
      } else if (node is List) {
        node.forEach(visit);
      } else if (node is String && node.contains('<redacted-scenario')) {
        count += 1;
      }
    }

    visit(value);
    return count;
  }

  static int _unsafeSelectorValueCount(List<_ReportSnapshot> snapshots) {
    return snapshots.fold<int>(
      0,
      (count, snapshot) => count + snapshot.unsafeSelectorValueCount,
    );
  }

  static List<String> _safeSelectorValues(Iterable<String> values) {
    return _sortedStrings(
      values
          .where(_safeSelectorPattern.hasMatch)
          .where((value) => !_opaqueFallbackPattern.hasMatch(value)),
    );
  }

  static void _validateSummary(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? inputReports,
    required List<dynamic>? groups,
    required List<dynamic>? cells,
  }) {
    if (summary == null) return;
    for (final field in const [
      'inputReportCount',
      'validReportCount',
      'invalidReportCount',
      'compatibilityGroupCount',
      'matrixCellCount',
      'evidenceGapCount',
      'promotionReadyCellCount',
      'diagnosticOnlyCellCount',
      'dataDeficientCellCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
    if (inputReports != null &&
        summary['inputReportCount'] != inputReports.length) {
      issues.add('summary.inputReportCount must match inputReports length');
    }
    if (groups != null && summary['compatibilityGroupCount'] != groups.length) {
      issues.add(
        'summary.compatibilityGroupCount must match compatibilityGroups length',
      );
    }
    if (cells != null && summary['matrixCellCount'] != cells.length) {
      issues.add('summary.matrixCellCount must match matrixCells length');
    }
    if (groups != null) {
      final evidenceGapCount = groups.fold<int>(
        0,
        (count, group) => group is Map<String, dynamic>
            ? count + _mapList(group['evidenceGaps']).length
            : count,
      );
      if (summary['evidenceGapCount'] != evidenceGapCount) {
        issues.add('summary.evidenceGapCount must match evidenceGaps length');
      }
    }
  }

  static void _validatePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    _expectBool(
      issues,
      privacy['scenarioIdsOmitted'],
      'privacy.scenarioIdsOmitted',
    );
    if (privacy['scenarioIdsOmitted'] != true) {
      issues.add('privacy.scenarioIdsOmitted must be true');
    }
    for (final field in const [
      'deniedValueCount',
      'redactedPlaceholderCount',
      'unsafeSelectorValueCount',
    ]) {
      _expectNonNegativeInt(issues, privacy[field], 'privacy.$field');
    }
    _expectNonEmptyString(issues, privacy['reason'], 'privacy.reason');
  }

  static void _validateLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesTuningReportsOnly': true,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'promotionClaimRequiresSourcePromotionEvidence': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        limitations[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
    _expectBool(
      issues,
      limitations['tracesReRead'],
      'limitations.tracesReRead',
    );
  }

  static void _validateInputReports(
    List<String> issues,
    List<dynamic>? reports,
  ) {
    if (reports == null) return;
    for (final (index, value) in reports.indexed) {
      final report = _expectMap(issues, value, 'inputReports[$index]');
      if (report == null) continue;
      _expectNonEmptyString(
        issues,
        report['reportRef'],
        'inputReports[$index].reportRef',
      );
      final status = _expectNonEmptyString(
        issues,
        report['contractStatus'],
        'inputReports[$index].contractStatus',
      );
      if (status != null && status != 'valid' && status != 'invalid') {
        issues.add(
          'inputReports[$index].contractStatus must be valid or invalid',
        );
      }
      final sourceStatus = _expectNonEmptyString(
        issues,
        report['sourceCheckStatus'],
        'inputReports[$index].sourceCheckStatus',
      );
      if (sourceStatus != null &&
          !const {
            'notRequired',
            'sourceChecked',
            'sourceInvalid',
            'sourceMissing',
          }.contains(sourceStatus)) {
        issues.add(
          'inputReports[$index].sourceCheckStatus is unsupported',
        );
      }
      _expectNonNegativeInt(
        issues,
        report['sourceIssueCount'],
        'inputReports[$index].sourceIssueCount',
      );
      if (_expectList(
            issues,
            report['sourceIssueCodes'],
            'inputReports[$index].sourceIssueCodes',
          ) !=
          null) {
        _expectStringList(
          issues,
          report['sourceIssueCodes'],
          'inputReports[$index].sourceIssueCodes',
        );
      }
      if (status == 'invalid') {
        _expectStringList(
          issues,
          report['contractIssues'],
          'inputReports[$index].contractIssues',
        );
        continue;
      }
      for (final field in const [
        'reportDigest',
        'manifestDigest',
        'scenarioSetDigest',
        'policyDigest',
        'profileSetDigest',
        'profileBindingSetDigest',
        'promptVariantSetDigest',
        'requiredCapabilitySetDigest',
      ]) {
        _expectDigest(issues, report[field], 'inputReports[$index].$field');
      }
      _expectBool(issues, report['ready'], 'inputReports[$index].ready');
      _expectNonEmptyString(
        issues,
        report['promotionStatus'],
        'inputReports[$index].promotionStatus',
      );
      _expectBool(
        issues,
        report['calibrationPresent'],
        'inputReports[$index].calibrationPresent',
      );
      _expectBool(
        issues,
        report['pairwisePresent'],
        'inputReports[$index].pairwisePresent',
      );
      _expectStringList(
        issues,
        report['requiredCapabilities'],
        'inputReports[$index].requiredCapabilities',
      );
      _expectNonNegativeInt(
        issues,
        report['missingRequiredPrimaryCapabilityCount'],
        'inputReports[$index].missingRequiredPrimaryCapabilityCount',
      );
      _expectDigest(
        issues,
        report['missingRequiredPrimaryCapabilitySetDigest'],
        'inputReports[$index].missingRequiredPrimaryCapabilitySetDigest',
      );
      _expectNonNegativeInt(
        issues,
        report['omittedMissingRequiredPrimaryCapabilityValueCount'],
        'inputReports[$index].omittedMissingRequiredPrimaryCapabilityValueCount',
      );
      _expectStringList(
        issues,
        report['publicMissingRequiredPrimaryCapabilities'],
        'inputReports[$index].publicMissingRequiredPrimaryCapabilities',
      );
    }
  }

  static void _validateGroups(List<String> issues, List<dynamic>? groups) {
    if (groups == null) return;
    for (final (index, value) in groups.indexed) {
      final group = _expectMap(issues, value, 'compatibilityGroups[$index]');
      if (group == null) continue;
      _expectDigest(
        issues,
        group['compatibilityKey'],
        'compatibilityGroups[$index].compatibilityKey',
      );
      _expectNonEmptyString(
        issues,
        group['status'],
        'compatibilityGroups[$index].status',
      );
      final fixedEvidence = _expectMap(
        issues,
        group['fixedEvidence'],
        'compatibilityGroups[$index].fixedEvidence',
      );
      if (fixedEvidence != null) {
        _expectNonEmptyString(
          issues,
          fixedEvidence['targetKind'],
          'compatibilityGroups[$index].fixedEvidence.targetKind',
        );
        for (final field in const [
          'scenarioSetDigest',
          'policyDigest',
          'requiredCapabilitySetDigest',
        ]) {
          _expectDigest(
            issues,
            fixedEvidence[field],
            'compatibilityGroups[$index].fixedEvidence.$field',
          );
        }
        _expectStringList(
          issues,
          fixedEvidence['requiredCapabilities'],
          'compatibilityGroups[$index].fixedEvidence.requiredCapabilities',
        );
        _expectBool(
          issues,
          fixedEvidence['protectedIdsRedacted'],
          'compatibilityGroups[$index].fixedEvidence.protectedIdsRedacted',
        );
      }
      _expectStringList(
        issues,
        group['sourceReportRefs'],
        'compatibilityGroups[$index].sourceReportRefs',
      );
      final cells = _expectList(
        issues,
        group['matrixCells'],
        'compatibilityGroups[$index].matrixCells',
      );
      _validateEvidenceGaps(
        issues,
        _expectList(
          issues,
          group['evidenceGaps'],
          'compatibilityGroups[$index].evidenceGaps',
        ),
        'compatibilityGroups[$index].evidenceGaps',
      );
      _validateCells(issues, cells, 'compatibilityGroups[$index].matrixCells');
      final expectedKey = group['fixedEvidence'] is Map<String, dynamic>
          ? EvalProvenance.digestJson(group['fixedEvidence'])
          : null;
      if (expectedKey != null && group['compatibilityKey'] != expectedKey) {
        issues.add(
          'compatibilityGroups[$index].compatibilityKey must match fixedEvidence',
        );
      }
    }
  }

  static void _validateCells(
    List<String> issues,
    List<dynamic>? cells,
    String path,
  ) {
    if (cells == null) return;
    for (final (index, value) in cells.indexed) {
      final cell = _expectMap(issues, value, '$path[$index]');
      if (cell == null) continue;
      _expectDigest(issues, cell['cellKey'], '$path[$index].cellKey');
      if (cell.containsKey('compatibilityKey')) {
        _expectDigest(
          issues,
          cell['compatibilityKey'],
          '$path[$index].compatibilityKey',
        );
      }
      for (final field in const [
        'reportRef',
        'primaryCapabilityId',
        'agentKind',
        'modelClass',
        'promptVariantName',
        'evidenceStatus',
        'recommendation',
      ]) {
        _expectNonEmptyString(issues, cell[field], '$path[$index].$field');
      }
      for (final field in const [
        'manifestDigest',
        'profileSetDigest',
        'profileBindingSetDigest',
        'promptVariantSetDigest',
      ]) {
        _expectDigest(issues, cell[field], '$path[$index].$field');
      }
      for (final field in const [
        'traceCount',
        'judgedTraceCount',
        'passCount',
        'level1PassCount',
        'weightedCostTraceCount',
        'missingWeightedCostCount',
      ]) {
        _expectNonNegativeInt(issues, cell[field], '$path[$index].$field');
      }
      for (final field in const [
        'passRate',
        'passRateLowerBound',
        'meanGoalAttainment',
        'meanQuality',
        'meanEfficiency',
        'meanTokenBudgetRatio',
        'meanWeightedCostBudgetRatio',
      ]) {
        _expectFiniteNum(issues, cell[field], '$path[$index].$field');
      }
      _expectBool(
        issues,
        cell['promotionEvidence'],
        '$path[$index].promotionEvidence',
      );
      _expectStringList(
        issues,
        cell['blockingReasonCodes'],
        '$path[$index].blockingReasonCodes',
      );
    }
  }

  static void _validateGaps(List<String> issues, List<dynamic>? gaps) {
    if (gaps == null) return;
    for (final (index, value) in gaps.indexed) {
      final gap = _expectMap(issues, value, 'gaps[$index]');
      if (gap == null) continue;
      _expectDigest(
        issues,
        gap['compatibilityKey'],
        'gaps[$index].compatibilityKey',
      );
      if (gap.containsKey('cellKey')) {
        _expectDigest(issues, gap['cellKey'], 'gaps[$index].cellKey');
        _expectStringList(
          issues,
          gap['blockerCodes'],
          'gaps[$index].blockerCodes',
        );
      } else {
        _validateEvidenceGapMap(issues, gap, 'gaps[$index]');
      }
    }
  }

  static void _validateEvidenceGaps(
    List<String> issues,
    List<dynamic>? gaps,
    String path,
  ) {
    if (gaps == null) return;
    for (final (index, value) in gaps.indexed) {
      final gap = _expectMap(issues, value, '$path[$index]');
      if (gap == null) continue;
      _validateEvidenceGapMap(issues, gap, '$path[$index]');
    }
  }

  static void _validateEvidenceGapMap(
    List<String> issues,
    Map<String, dynamic> gap,
    String path,
  ) {
    _expectNonEmptyString(issues, gap['code'], '$path.code');
    _expectNonEmptyString(issues, gap['severity'], '$path.severity');
    _expectNonEmptyString(issues, gap['gapKind'], '$path.gapKind');
    _expectDigest(issues, gap['gapKey'], '$path.gapKey');
    _expectStringList(
      issues,
      gap['sourceReportRefs'],
      '$path.sourceReportRefs',
    );
    _expectNonNegativeInt(
      issues,
      gap['missingRequiredPrimaryCapabilityCount'],
      '$path.missingRequiredPrimaryCapabilityCount',
    );
    _expectDigest(
      issues,
      gap['missingRequiredPrimaryCapabilitySetDigest'],
      '$path.missingRequiredPrimaryCapabilitySetDigest',
    );
    _expectNonNegativeInt(
      issues,
      gap['omittedMissingRequiredPrimaryCapabilityValueCount'],
      '$path.omittedMissingRequiredPrimaryCapabilityValueCount',
    );
    _expectStringList(
      issues,
      gap['publicMissingRequiredPrimaryCapabilities'],
      '$path.publicMissingRequiredPrimaryCapabilities',
    );
    _expectStringList(
      issues,
      gap['blockerCodes'],
      '$path.blockerCodes',
    );
  }

  static void _validateIssues(List<String> issues, List<dynamic>? values) {
    if (values == null) return;
    for (final (index, value) in values.indexed) {
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

  static void _validateNextPlan(
    List<String> issues,
    Map<String, dynamic>? plan,
    String? status,
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
    final planStatus = _expectNonEmptyString(
      issues,
      plan['status'],
      'nextExperimentPlan.status',
    );
    if (status != null && planStatus != null && status != planStatus) {
      issues.add('nextExperimentPlan.status must match matrix status');
    }
    _expectNonEmptyString(
      issues,
      plan['objective'],
      'nextExperimentPlan.objective',
    );
    _expectStringList(
      issues,
      plan['sourceReportRefs'],
      'nextExperimentPlan.sourceReportRefs',
    );
    _expectStringList(
      issues,
      plan['blockedReasonCodes'],
      'nextExperimentPlan.blockedReasonCodes',
    );
    _validateWithheldSelectors(
      issues,
      _expectMap(
        issues,
        plan['withheldSelectors'],
        'nextExperimentPlan.withheldSelectors',
      ),
      'nextExperimentPlan.withheldSelectors',
    );
    _validatePlanItems(
      issues,
      _expectList(
        issues,
        plan['manualPrerequisites'],
        'nextExperimentPlan.manualPrerequisites',
      ),
      'nextExperimentPlan.manualPrerequisites',
    );
    final groupPlans = _expectList(
      issues,
      plan['groupPlans'],
      'nextExperimentPlan.groupPlans',
    );
    if (groupPlans != null) {
      for (final (index, value) in groupPlans.indexed) {
        final groupPlan = _expectMap(
          issues,
          value,
          'nextExperimentPlan.groupPlans[$index]',
        );
        if (groupPlan == null) continue;
        _expectDigest(
          issues,
          groupPlan['compatibilityKey'],
          'nextExperimentPlan.groupPlans[$index].compatibilityKey',
        );
        _validateRecommendedCommands(
          issues,
          _expectList(
            issues,
            groupPlan['recommendedCommands'],
            'nextExperimentPlan.groupPlans[$index].recommendedCommands',
          ),
          'nextExperimentPlan.groupPlans[$index].recommendedCommands',
        );
        _validateEnvMap(
          issues,
          _expectMap(
            issues,
            groupPlan['nextRunEnv'],
            'nextExperimentPlan.groupPlans[$index].nextRunEnv',
          ),
          'nextExperimentPlan.groupPlans[$index].nextRunEnv',
        );
      }
    }
    _validateRecommendedCommands(
      issues,
      _expectList(
        issues,
        plan['recommendedCommands'],
        'nextExperimentPlan.recommendedCommands',
      ),
      'nextExperimentPlan.recommendedCommands',
    );
  }

  static void _validateWithheldSelectors(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    _expectBool(
      issues,
      selectors['scenarioIdsOmitted'],
      '$path.scenarioIdsOmitted',
    );
    if (selectors['scenarioIdsOmitted'] != true) {
      issues.add('$path.scenarioIdsOmitted must be true');
    }
  }

  static void _validatePlanItems(
    List<String> issues,
    List<dynamic>? items,
    String path,
  ) {
    if (items == null) return;
    for (final (index, value) in items.indexed) {
      final item = _expectMap(issues, value, '$path[$index]');
      if (item == null) continue;
      _expectNonEmptyString(issues, item['code'], '$path[$index].code');
      _expectNonEmptyString(issues, item['action'], '$path[$index].action');
    }
  }

  static void _validateRecommendedCommands(
    List<String> issues,
    List<dynamic>? commands,
    String path,
  ) {
    if (commands == null) return;
    for (final (index, value) in commands.indexed) {
      final command = _expectMap(issues, value, '$path[$index]');
      if (command == null) continue;
      final mode = _expectNonEmptyString(
        issues,
        command['mode'],
        '$path[$index].mode',
      );
      if (mode != null &&
          !const {'use-case-matrix', 'experiment-plan'}.contains(mode)) {
        issues.add('$path[$index].mode is unsupported');
      }
      final text = _expectNonEmptyString(
        issues,
        command['command'],
        '$path[$index].command',
      );
      if (text != null && text.contains('EVAL_SCENARIO_IDS')) {
        issues.add('$path[$index].command must not contain EVAL_SCENARIO_IDS');
      }
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

  static void _validateEnvMap(
    List<String> issues,
    Map<String, dynamic>? env,
    String path,
  ) {
    if (env == null) return;
    for (final entry in env.entries) {
      if (entry.key == 'EVAL_SCENARIO_IDS') {
        issues.add('$path must not contain EVAL_SCENARIO_IDS');
      }
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) {
        issues.add('$path.${entry.key} must be a non-empty string');
      } else if (!_safeEnvValue(value)) {
        issues.add('$path.${entry.key} contains unsafe values');
      }
    }
  }

  static bool _safeEnvValue(String value) {
    return value.split(',').every(_safeSelectorPattern.hasMatch);
  }

  static void _validateNoScenarioIds(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (normalized == 'scenarioid' ||
            normalized == 'scenarioids' ||
            normalized.endsWith('scenarioids')) {
          issues.add('$path.$key must not expose scenario ids');
        }
        _validateNoScenarioIds(issues, entry.value, '$path.$key');
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoScenarioIds(issues, item, '$path[$index]');
      }
      return;
    }
    if (value is String) {
      if (value.contains('<redacted-scenario')) {
        issues.add('$path must not contain redacted scenario placeholders');
      }
      if (value.contains('EVAL_SCENARIO_IDS')) {
        issues.add('$path must not contain EVAL_SCENARIO_IDS');
      }
      if (_scenarioFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain scenario id field names');
      }
    }
  }

  static void _validateNoDeniedValues(
    List<String> issues,
    Object? value,
    String path,
    Set<String> deniedValues,
  ) {
    if (deniedValues.isEmpty) return;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_containsDeniedValue(key, deniedValues)) {
          issues.add('$path.$key must not expose denied values');
        }
        _validateNoDeniedValues(
          issues,
          entry.value,
          '$path.$key',
          deniedValues,
        );
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoDeniedValues(
          issues,
          item,
          '$path[$index]',
          deniedValues,
        );
      }
      return;
    }
    if (value is String && _containsDeniedValue(value, deniedValues)) {
      issues.add('$path must not expose denied values');
    }
  }

  static bool _containsDeniedValue(String value, Set<String> deniedValues) {
    return _isDeniedText(value, deniedValues);
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

  static void _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is int && value >= 0) return;
    issues.add('$path must be a non-negative integer');
  }

  static void _expectFiniteNum(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is num && value.isFinite) return;
    issues.add('$path must be finite');
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

final class _ReportSnapshot {
  _ReportSnapshot({
    required this.index,
    required this.report,
    required this.deniedValues,
    required this.contractIssues,
    required this.sourceCheck,
    required this.requireSourceCheck,
  });

  factory _ReportSnapshot.fromReport({
    required int index,
    required Map<String, dynamic> report,
    required Set<String> deniedValues,
    required EvalTuningReportSourceCheckResult? sourceCheck,
    required bool requireSourceCheck,
  }) {
    return _ReportSnapshot(
      index: index,
      report: report,
      deniedValues: deniedValues,
      contractIssues: EvalTuningReportContract.validate(report),
      sourceCheck: sourceCheck,
      requireSourceCheck: requireSourceCheck,
    );
  }

  final int index;
  final Map<String, dynamic> report;
  final Set<String> deniedValues;
  final List<String> contractIssues;
  final EvalTuningReportSourceCheckResult? sourceCheck;
  final bool requireSourceCheck;

  bool get valid =>
      contractIssues.isEmpty &&
      sourceIssueCodes.isEmpty &&
      (!requireSourceCheck || sourceCheck?.isSourceChecked == true);

  String get reportRef => 'report-$index';

  String get reportDigest => EvalProvenance.digestJson(report);

  List<String> get publicContractIssues => _publicDiagnosticStrings(
    [
      ...contractIssues,
      ...sourceIssueCodes,
    ],
    deniedValues,
  );

  String get sourceCheckStatus {
    final check = sourceCheck;
    if (check != null) return check.sourceCheckStatus.name;
    return requireSourceCheck ? 'sourceMissing' : 'notRequired';
  }

  List<String> get sourceIssueCodes {
    final check = sourceCheck;
    if (check == null) {
      return requireSourceCheck
          ? const ['report.sourceCheckMissing']
          : const <String>[];
    }
    final issues = <String>[
      if (check.reportDigest != reportDigest)
        'report.sourceCheckDigestMismatch',
      if (check.sourceCheckStatus ==
              EvalTuningReportSourceCheckStatus.sourceChecked &&
          !check.isSourceChecked)
        'report.sourceCheckUnvalidated',
      if (!check.isSourceChecked) ...check.sourceIssueCodes,
    ]..sort();
    return issues;
  }

  Map<String, dynamic> get run => _map(report['run']);

  Map<String, dynamic> get policy => _map(report['policy']);

  Map<String, dynamic> get status => _map(report['status']);

  Map<String, dynamic> get coverage => _map(report['coverage']);

  Map<String, dynamic> get calibration => _map(report['calibration']);

  Map<String, dynamic> get pairwise => _map(report['pairwise']);

  Map<String, dynamic> get promotion => _map(report['promotion']);

  Map<String, dynamic> get selectors => _map(run['selectors']);

  Map<String, dynamic> get nextPlan => _map(report['nextExperimentPlan']);

  String get manifestDigest => _string(run['manifestDigest']);

  String get targetKind => _string(run['targetKind']);

  String get scenarioSetDigest => _string(run['scenarioSetDigest']);

  String get policyDigest => _string(policy['digest']);

  String get profileSetDigest => _string(run['profileSetDigest']);

  String get profileBindingSetDigest => _string(run['profileBindingSetDigest']);

  String get promptVariantSetDigest =>
      _string(run['agentDirectiveVariantSetDigest']);

  bool get protectedIdsRedacted => run['protectedIdsRedacted'] == true;

  bool get ready => status['ready'] == true;

  String get promotionStatus => _string(promotion['status']);

  bool get promotionReady => ready && promotionStatus == 'promote';

  bool get calibrationPresent => calibration['present'] == true;

  bool get pairwisePresent => pairwise['present'] == true;

  List<String> get requiredCapabilities => _publicStrings(
    _stringList(selectors['requiredPrimaryCapabilityIds']),
    deniedValues,
  );

  List<String> get publicMissingRequiredPrimaryCapabilities => _publicStrings(
    _stringList(coverage['missingRequiredPrimaryCapabilityIds']),
    deniedValues,
  );

  int get missingRequiredPrimaryCapabilityCount =>
      _stringList(coverage['missingRequiredPrimaryCapabilityIds']).length;

  String get missingRequiredPrimaryCapabilitySetDigest =>
      EvalProvenance.digestJson(
        _sortedStrings(
          _stringList(coverage['missingRequiredPrimaryCapabilityIds']),
        ),
      );

  int get omittedMissingRequiredPrimaryCapabilityValueCount =>
      missingRequiredPrimaryCapabilityCount -
      publicMissingRequiredPrimaryCapabilities.length;

  String get requiredCapabilitySetDigest => EvalProvenance.digestJson(
    _sortedStrings(_stringList(selectors['requiredPrimaryCapabilityIds'])),
  );

  List<Map<String, dynamic>> get slices => [
    for (final item in _list(report['useCaseModelSlices']))
      if (item is Map<String, dynamic>) item,
  ];

  int get scenarioSelectorCount =>
      _stringList(selectors['scenarioIds']).length +
      _stringList(nextPlan['suggestedScenarioIds']).length +
      slices.fold<int>(
        0,
        (count, slice) => count + _stringList(slice['scenarioIds']).length,
      );

  int get unsafeSelectorValueCount {
    var count = 0;
    for (final field in const [
      'requiredPrimaryCapabilityIds',
      'profileNames',
      'promptVariantNames',
    ]) {
      for (final value in _stringList(selectors[field])) {
        if (!EvalUseCaseTuningMatrix._safeSelectorPattern.hasMatch(value)) {
          count += 1;
        }
      }
    }
    for (final field in const [
      'suggestedCapabilities',
      'suggestedProfileNames',
      'suggestedPromptVariantNames',
    ]) {
      for (final value in _stringList(nextPlan[field])) {
        if (!EvalUseCaseTuningMatrix._safeSelectorPattern.hasMatch(value)) {
          count += 1;
        }
      }
    }
    return count;
  }

  Map<String, dynamic> get compatibilityEvidence => <String, dynamic>{
    'targetKind': targetKind,
    'scenarioSetDigest': scenarioSetDigest,
    'policyDigest': policyDigest,
    'requiredCapabilities': requiredCapabilities,
    'requiredCapabilitySetDigest': requiredCapabilitySetDigest,
    'protectedIdsRedacted': protectedIdsRedacted,
  };

  String get compatibilityKey => EvalProvenance.digestJson(
    compatibilityEvidence,
  );

  List<String> get blockedReasonCodes {
    return _sortedStrings({
      for (final reason in _list(report['blockedReasons']))
        if (reason is Map<String, dynamic>)
          _publicString(
            _string(reason['code']),
            deniedValues,
            fallbackPrefix: 'blocker',
          ),
    });
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'reportRef': reportRef,
    'reportDigest': reportDigest,
    'contractStatus': valid ? 'valid' : 'invalid',
    'sourceCheckStatus': sourceCheckStatus,
    'sourceIssueCount': sourceIssueCodes.length,
    'sourceIssueCodes': sourceIssueCodes,
    if (!valid) 'contractIssues': publicContractIssues,
    if (valid) ...<String, dynamic>{
      'manifestDigest': manifestDigest,
      'targetKind': targetKind,
      'scenarioSetDigest': scenarioSetDigest,
      'policyDigest': policyDigest,
      'profileSetDigest': profileSetDigest,
      'profileBindingSetDigest': profileBindingSetDigest,
      'promptVariantSetDigest': promptVariantSetDigest,
      'protectedIdsRedacted': protectedIdsRedacted,
      'ready': ready,
      'promotionStatus': promotionStatus,
      'calibrationPresent': calibrationPresent,
      'pairwisePresent': pairwisePresent,
      'requiredCapabilities': requiredCapabilities,
      'requiredCapabilitySetDigest': requiredCapabilitySetDigest,
      'missingRequiredPrimaryCapabilityCount':
          missingRequiredPrimaryCapabilityCount,
      'missingRequiredPrimaryCapabilitySetDigest':
          missingRequiredPrimaryCapabilitySetDigest,
      'omittedMissingRequiredPrimaryCapabilityValueCount':
          omittedMissingRequiredPrimaryCapabilityValueCount,
      'publicMissingRequiredPrimaryCapabilities':
          publicMissingRequiredPrimaryCapabilities,
    },
  };
}

final class _CompatibilityGroup {
  _CompatibilityGroup({
    required this.fixedEvidence,
    required this.deniedValues,
  });

  final Map<String, dynamic> fixedEvidence;
  final Set<String> deniedValues;
  final reports = <_ReportSnapshot>[];

  String get compatibilityKey => EvalProvenance.digestJson(fixedEvidence);

  void add(_ReportSnapshot report) {
    reports.add(report);
  }

  Map<String, dynamic> toJson() {
    final cells = [
      for (final report in reports)
        for (final slice in report.slices)
          _MatrixCell.fromSlice(
            report: report,
            slice: slice,
            deniedValues: deniedValues,
          ).toJson(),
    ]..sort((a, b) => _string(a['cellKey']).compareTo(_string(b['cellKey'])));
    final evidenceGaps = _evidenceGaps();
    return <String, dynamic>{
      'compatibilityKey': compatibilityKey,
      'status': _groupStatus(cells, evidenceGaps),
      'fixedEvidence': fixedEvidence,
      'reportCount': reports.length,
      'sourceReportRefs': _sortedStrings(
        reports.map((report) => report.reportRef),
      ),
      'tuningAxes': <String, dynamic>{
        'profileSetDigests': _sortedStrings(
          reports.map((report) => report.profileSetDigest),
        ),
        'profileBindingSetDigests': _sortedStrings(
          reports.map((report) => report.profileBindingSetDigest),
        ),
        'promptVariantSetDigests': _sortedStrings(
          reports.map((report) => report.promptVariantSetDigest),
        ),
        'modelClasses': EvalUseCaseTuningMatrix._safeSelectorValues(
          cells.map((cell) => _string(cell['modelClass'])),
        ),
        'promptVariantNames': EvalUseCaseTuningMatrix._safeSelectorValues(
          cells.map((cell) => _string(cell['promptVariantName'])),
        ),
      },
      'evidenceGaps': evidenceGaps,
      'matrixCells': cells,
    };
  }

  List<Map<String, dynamic>> _evidenceGaps() {
    return [
      for (final report in reports)
        if (report.missingRequiredPrimaryCapabilityCount > 0)
          <String, dynamic>{
            'gapKind': 'requiredPrimaryCapability',
            'gapKey': EvalProvenance.digestJson(<String, dynamic>{
              'gapKind': 'requiredPrimaryCapability',
              'sourceReportRefs': [report.reportRef],
              'missingRequiredPrimaryCapabilitySetDigest':
                  report.missingRequiredPrimaryCapabilitySetDigest,
            }),
            'code': 'coverage.capabilityMissing',
            'severity': 'blocking',
            'sourceReportRefs': [report.reportRef],
            'missingRequiredPrimaryCapabilityCount':
                report.missingRequiredPrimaryCapabilityCount,
            'missingRequiredPrimaryCapabilitySetDigest':
                report.missingRequiredPrimaryCapabilitySetDigest,
            'publicMissingRequiredPrimaryCapabilities':
                report.publicMissingRequiredPrimaryCapabilities,
            'omittedMissingRequiredPrimaryCapabilityValueCount':
                report.omittedMissingRequiredPrimaryCapabilityValueCount,
            'blockerCodes': const ['coverage.capabilityMissing'],
          },
    ];
  }

  static String _groupStatus(
    List<Map<String, dynamic>> cells,
    List<Map<String, dynamic>> evidenceGaps,
  ) {
    if (evidenceGaps.isNotEmpty) return 'blocked';
    if (EvalUseCaseTuningMatrix._statusCount(cells, 'promotionReady') > 0) {
      return 'promotionReady';
    }
    if (EvalUseCaseTuningMatrix._statusCount(cells, 'diagnosticOnly') > 0) {
      return 'diagnosticOnly';
    }
    if (EvalUseCaseTuningMatrix._statusCount(cells, 'dataDeficient') > 0) {
      return 'dataDeficient';
    }
    return 'blocked';
  }
}

final class _MatrixCell {
  const _MatrixCell({
    required this.report,
    required this.slice,
    required this.deniedValues,
  });

  factory _MatrixCell.fromSlice({
    required _ReportSnapshot report,
    required Map<String, dynamic> slice,
    required Set<String> deniedValues,
  }) {
    return _MatrixCell(
      report: report,
      slice: slice,
      deniedValues: deniedValues,
    );
  }

  final _ReportSnapshot report;
  final Map<String, dynamic> slice;
  final Set<String> deniedValues;

  String get primaryCapabilityId => _publicString(
    _string(slice['primaryCapabilityId']),
    deniedValues,
    fallbackPrefix: 'capability',
  );

  String get agentKind => _publicString(
    _string(slice['agentKind']),
    deniedValues,
    fallbackPrefix: 'agent',
  );

  String get modelClass => _publicString(
    _string(slice['modelClass']),
    deniedValues,
    fallbackPrefix: 'model',
  );

  String get promptVariantName => _publicString(
    _string(slice['promptVariantName']),
    deniedValues,
    fallbackPrefix: 'prompt',
  );

  List<String> get blockingReasonCodes => _sortedStrings({
    for (final value in _stringList(slice['blockingReasons']))
      _publicString(value, deniedValues, fallbackPrefix: 'blocker'),
    if (!report.ready) ...report.blockedReasonCodes,
  });

  String get recommendation => _publicString(
    _string(slice['recommendation']),
    deniedValues,
    fallbackPrefix: 'recommendation',
  );

  String get evidenceStatus {
    if (!report.ready) return 'dataDeficient';
    if (blockingReasonCodes.isNotEmpty || recommendation != 'keep') {
      return 'blocked';
    }
    if (report.promotionReady) return 'promotionReady';
    return 'diagnosticOnly';
  }

  bool get promotionEvidence => evidenceStatus == 'promotionReady';

  String get cellKey => EvalProvenance.digestJson(<String, dynamic>{
    'reportRef': report.reportRef,
    'manifestDigest': report.manifestDigest,
    'profileBindingSetDigest': report.profileBindingSetDigest,
    'promptVariantSetDigest': report.promptVariantSetDigest,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cellKey': cellKey,
    'reportRef': report.reportRef,
    'manifestDigest': report.manifestDigest,
    'profileSetDigest': report.profileSetDigest,
    'profileBindingSetDigest': report.profileBindingSetDigest,
    'promptVariantSetDigest': report.promptVariantSetDigest,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
    'evidenceStatus': evidenceStatus,
    'promotionEvidence': promotionEvidence,
    'reportReady': report.ready,
    'sourcePromotionStatus': report.promotionStatus,
    'calibrationPresent': report.calibrationPresent,
    'pairwisePresent': report.pairwisePresent,
    'traceCount': _int(slice['traceCount']),
    'judgedTraceCount': _int(slice['judgedTraceCount']),
    'passCount': _int(slice['passCount']),
    'level1PassCount': _int(slice['level1PassCount']),
    'passRate': _double(slice['passRate']),
    'passRateLowerBound': _double(slice['passRateLowerBound']),
    'meanGoalAttainment': _double(slice['meanGoalAttainment']),
    'meanQuality': _double(slice['meanQuality']),
    'meanEfficiency': _double(slice['meanEfficiency']),
    'meanTokenBudgetRatio': _double(slice['meanTokenBudgetRatio']),
    'weightedCostTraceCount': _int(slice['weightedCostTraceCount']),
    'missingWeightedCostCount': _int(slice['missingWeightedCostCount']),
    'meanWeightedCostBudgetRatio': _double(
      slice['meanWeightedCostBudgetRatio'],
    ),
    'recommendation': recommendation,
    'blockingReasonCodes': blockingReasonCodes,
    'scenarioSelectorCount': _stringList(slice['scenarioIds']).length,
  };
}

String _publicString(
  String value,
  Set<String> deniedValues, {
  required String fallbackPrefix,
}) {
  if (value.isEmpty) return fallbackPrefix;
  if (!_isDeniedText(value, deniedValues)) {
    return value;
  }
  return '$fallbackPrefix-${EvalProvenance.digestText(value).substring(7, 19)}';
}

List<String> _publicStrings(
  Iterable<String> values,
  Set<String> deniedValues,
) {
  return _sortedStrings(
    values.where((value) => !_isDeniedText(value, deniedValues)),
  );
}

List<String> _publicDiagnosticStrings(
  Iterable<String> values,
  Set<String> deniedValues,
) {
  return [
    for (final value in values)
      value
          .replaceAll(
            EvalUseCaseTuningMatrix._scenarioFieldTokenPattern,
            'scenario selector field',
          )
          .replaceAll('<redacted-scenario', 'redacted scenario')
          .split(' ')
          .map(
            (part) =>
                _isDeniedText(part, deniedValues) ? 'protected-value' : part,
          )
          .join(' '),
  ];
}

bool _isDeniedText(String value, Set<String> deniedValues) {
  if (value.contains('<redacted-scenario')) return true;
  if (EvalUseCaseTuningMatrix._scenarioFieldTokenPattern.hasMatch(value)) {
    return true;
  }
  return deniedValues.any(
    (denied) =>
        denied.trim().isNotEmpty &&
        (value == denied || (denied.length > 5 && value.contains(denied))),
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<dynamic> _list(Object? value) =>
    value is List<dynamic> ? value : const <dynamic>[];

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) => value is num ? value.toInt() : 0;

double _double(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : 0;

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}

List<String> _sortedStrings(Iterable<String> values) {
  final sorted =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return sorted;
}
