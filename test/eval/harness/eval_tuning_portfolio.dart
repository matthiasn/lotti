import 'eval_provenance.dart';
import 'eval_tuning_report_contract.dart';

abstract final class EvalTuningPortfolio {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalTuningPortfolio';
  static const nextExperimentPlanKind =
      'lotti.evalTuningPortfolioNextExperimentPlan';
  static const _allowedStatuses = {
    'invalid',
    'insufficientReports',
    'incompatible',
    'promotionReady',
    'dataDeficient',
    'diagnosticLeader',
    'blocked',
  };
  static const _allowedCommandModes = {'compare-tuning'};
  static final _liveRunLevel2CommandPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:\./)?eval/run_level2\.sh\s+'
    r'(?:plan|run|tune|all)(?=$|[^A-Za-z0-9_-])',
  );

  static Map<String, dynamic> compare({
    required List<Map<String, dynamic>> reports,
    DateTime? generatedAt,
  }) {
    final snapshots = [
      for (final indexed in reports.indexed)
        _TuningReportSnapshot.fromReport(
          index: indexed.$1,
          report: indexed.$2,
        ),
    ];
    final validSnapshots = [
      for (final snapshot in snapshots)
        if (snapshot.isValid) snapshot,
    ];
    final groups = _compatibilityGroups(validSnapshots);
    final groupReports = [
      for (final group in groups) group.toJson(),
    ];
    final issues = _portfolioIssues(
      snapshots: snapshots,
      groupReports: groupReports,
    );
    final portfolioStatus = _portfolioStatus(
      snapshots: snapshots,
      groupReports: groupReports,
    );

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': portfolioStatus,
      'summary': <String, dynamic>{
        'inputReportCount': snapshots.length,
        'validReportCount': validSnapshots.length,
        'invalidReportCount': snapshots.length - validSnapshots.length,
        'compatibilityGroupCount': groupReports.length,
        'promotionReadyFamilyCount': _familyStatusCount(
          groupReports,
          'promotionReady',
        ),
        'dataDeficientFamilyCount': _familyStatusCount(
          groupReports,
          'dataDeficient',
        ),
        'diagnosticLeaderFamilyCount': _familyStatusCount(
          groupReports,
          'diagnosticLeader',
        ),
      },
      'nextExperimentPlan': _nextExperimentPlan(
        snapshots: snapshots,
        validSnapshots: validSnapshots,
        groupReports: groupReports,
        issues: issues,
        portfolioStatus: portfolioStatus,
      ),
      'inputReports': [
        for (final snapshot in snapshots) snapshot.toJson(),
      ],
      'compatibilityGroups': groupReports,
      'issues': issues,
    };
  }

  static void assertValid(Map<String, dynamic> portfolio) {
    final issues = validate(portfolio);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid tuning portfolio contract:\n${issues.join('\n')}',
    );
  }

  static List<String> validate(Map<String, dynamic> portfolio) {
    final issues = <String>[];
    _expectEquals(
      issues,
      portfolio['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, portfolio['kind'], kind, 'kind');
    _expectIsoDate(issues, portfolio['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(
      issues,
      portfolio['status'],
      'status',
    );
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }

    final summary = _expectMap(issues, portfolio['summary'], 'summary');
    final inputReports = _expectList(
      issues,
      portfolio['inputReports'],
      'inputReports',
    );
    final groups = _expectList(
      issues,
      portfolio['compatibilityGroups'],
      'compatibilityGroups',
    );
    _expectList(issues, portfolio['issues'], 'issues');
    _validateNextPlan(
      issues,
      _expectMap(
        issues,
        portfolio['nextExperimentPlan'],
        'nextExperimentPlan',
      ),
      status,
    );
    _validateInputReports(issues, inputReports);
    _validateCompatibilityGroups(issues, groups);
    _validateSummary(
      issues,
      status: status,
      summary: summary,
      inputReports: inputReports,
      groups: groups,
    );
    _validateNoScenarioIds(issues, portfolio, 'portfolio');
    return issues;
  }

  static List<_TuningCompatibilityGroup> _compatibilityGroups(
    List<_TuningReportSnapshot> snapshots,
  ) {
    final groupsByKey = <String, _TuningCompatibilityGroup>{};
    for (final snapshot in snapshots) {
      groupsByKey
          .putIfAbsent(
            snapshot.compatibilityKey,
            () => _TuningCompatibilityGroup(snapshot.compatibilityEvidence),
          )
          .add(snapshot);
    }
    return groupsByKey.values.toList()
      ..sort((a, b) => a.compatibilityKey.compareTo(b.compatibilityKey));
  }

  static List<Map<String, dynamic>> _portfolioIssues({
    required List<_TuningReportSnapshot> snapshots,
    required List<Map<String, dynamic>> groupReports,
  }) {
    final issues = <Map<String, dynamic>>[
      for (final snapshot in snapshots)
        if (!snapshot.isValid)
          <String, dynamic>{
            'code': 'report.contractInvalid',
            'severity': 'blocking',
            'reportIndex': snapshot.index,
            'runId': snapshot.runId,
            'messages': snapshot.contractIssues,
          },
    ];
    if (snapshots.where((snapshot) => snapshot.isValid).length < 2) {
      issues.add(
        const <String, dynamic>{
          'code': 'portfolio.insufficientReports',
          'severity': 'blocking',
          'message': 'At least two valid tuning reports are required.',
        },
      );
    }
    if (groupReports.length > 1) {
      issues.add(
        <String, dynamic>{
          'code': 'compatibility.multipleGroups',
          'severity': 'blocking',
          'message':
              'Reports with different fixed evidence are not ranked '
              'against each other.',
          'compatibilityGroupCount': groupReports.length,
        },
      );
    }
    return issues;
  }

  static String _portfolioStatus({
    required List<_TuningReportSnapshot> snapshots,
    required List<Map<String, dynamic>> groupReports,
  }) {
    if (snapshots.any((snapshot) => !snapshot.isValid)) return 'invalid';
    if (snapshots.length < 2) return 'insufficientReports';
    if (groupReports.length > 1) return 'incompatible';
    if (_familyStatusCount(groupReports, 'promotionReady') > 0) {
      return 'promotionReady';
    }
    if (_familyStatusCount(groupReports, 'dataDeficient') > 0) {
      return 'dataDeficient';
    }
    if (_familyStatusCount(groupReports, 'diagnosticLeader') > 0) {
      return 'diagnosticLeader';
    }
    return 'blocked';
  }

  static int _familyStatusCount(
    List<Map<String, dynamic>> groupReports,
    String status,
  ) {
    var count = 0;
    for (final group in groupReports) {
      final families = group['families'];
      if (families is! List) continue;
      for (final family in families) {
        if (family is Map<String, dynamic> && family['status'] == status) {
          count += 1;
        }
      }
    }
    return count;
  }

  static Map<String, dynamic> _nextExperimentPlan({
    required List<_TuningReportSnapshot> snapshots,
    required List<_TuningReportSnapshot> validSnapshots,
    required List<Map<String, dynamic>> groupReports,
    required List<Map<String, dynamic>> issues,
    required String portfolioStatus,
  }) {
    final issueCodes = _sortedStrings({
      for (final issue in issues) _string(issue['code']),
    });
    final groupPlans = [
      for (final group in groupReports)
        _groupNextExperimentPlan(
          group: group,
          snapshots: validSnapshots
              .where(
                (snapshot) =>
                    snapshot.compatibilityKey == group['compatibilityKey'],
              )
              .toList(),
        ),
    ];
    final blockedReasonCodes = _sortedStrings({
      ...issueCodes,
      for (final groupPlan in groupPlans)
        ..._stringList(groupPlan['blockedReasonCodes']),
    });
    final sourceScenarioSuggestionCount = validSnapshots.fold<int>(
      0,
      (count, snapshot) =>
          count + snapshot.nextPlanStrings('suggestedScenarioIds').length,
    );

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': nextExperimentPlanKind,
      'status': portfolioStatus,
      'objective': _nextExperimentObjective(portfolioStatus),
      'inputReportCount': snapshots.length,
      'validReportCount': validSnapshots.length,
      'sourceCompatibilityKeys': _sortedStrings(
        groupReports.map((group) => _string(group['compatibilityKey'])),
      ),
      'sourceRunIds': _sortedStrings(
        validSnapshots.map((snapshot) => snapshot.runId),
      ),
      'blockedReasonCodes': blockedReasonCodes,
      'withheldSelectors': <String, dynamic>{
        'scenarioIdsOmitted': true,
        'sourceReportScenarioSuggestionCount': sourceScenarioSuggestionCount,
        'reason':
            'portfolio reports never expose scenario ids; select '
            'scenarios from the source tuning reports or a private catalog',
      },
      'manualPrerequisites': _manualPrerequisites(blockedReasonCodes),
      'groupPlans': groupPlans,
      'recommendedCommands': _recommendedCommands(),
    };
  }

  static Map<String, dynamic> _groupNextExperimentPlan({
    required Map<String, dynamic> group,
    required List<_TuningReportSnapshot> snapshots,
  }) {
    final families = _mapList(group['families']);
    final evidenceNeeds = [
      for (final family in families)
        for (final candidate in _mapList(family['candidates']))
          if (_string(candidate['evidenceStatus']) != 'promotionReady')
            <String, dynamic>{
              'primaryCapabilityId': _string(candidate['primaryCapabilityId']),
              'agentKind': _string(candidate['agentKind']),
              'modelClass': _string(candidate['modelClass']),
              'promptVariantName': _string(candidate['promptVariantName']),
              'evidenceStatus': _string(candidate['evidenceStatus']),
              'blockerCodes': _stringList(candidate['blockingReasonCodes']),
            },
    ];
    final blockedReasonCodes = _sortedStrings({
      for (final snapshot in snapshots) ...snapshot.blockedReasonCodes,
      for (final family in families)
        ..._stringList(family['dataDeficiencyCodes']),
      for (final need in evidenceNeeds) ..._stringList(need['blockerCodes']),
    });
    final sourceScenarioSuggestionCount = snapshots.fold<int>(
      0,
      (count, snapshot) =>
          count + snapshot.nextPlanStrings('suggestedScenarioIds').length,
    );
    final unsafeSelectorValueCount = snapshots.fold<int>(
      0,
      (count, snapshot) => count + snapshot.unsafeNextPlanSelectorCount,
    );
    final safeCapabilities = _safeSelectorValues({
      for (final snapshot in snapshots)
        ...snapshot.nextPlanStrings('suggestedCapabilities'),
      for (final snapshot in snapshots) ...snapshot.requiredCapabilities,
    });
    final safeProfileNames = _safeSelectorValues({
      for (final snapshot in snapshots)
        ...snapshot.nextPlanStrings('suggestedProfileNames'),
    });
    final safePromptVariantNames = _safeSelectorValues({
      for (final snapshot in snapshots)
        ...snapshot.nextPlanStrings('suggestedPromptVariantNames'),
      ..._stringList(_map(group['tuningAxes'])['promptVariantNames']),
    });
    final safePairwiseIntentKeys = _safeSelectorValues({
      for (final snapshot in snapshots)
        ...snapshot.nextPlanStrings('requiredPairwiseIntentKeys'),
      for (final snapshot in snapshots)
        ...snapshot.nextPlanStrings('missingOrFailedPairwiseKeys'),
    });
    final nextRunEnv = <String, dynamic>{
      if (safeCapabilities.isNotEmpty)
        'EVAL_REQUIRED_CAPABILITIES': safeCapabilities.join(','),
      if (safeProfileNames.isNotEmpty)
        'EVAL_PROFILE_NAMES': safeProfileNames.join(','),
      if (safePromptVariantNames.isNotEmpty)
        'EVAL_PROMPT_VARIANT_NAMES': safePromptVariantNames.join(','),
    };

    return <String, dynamic>{
      'compatibilityKey': _string(group['compatibilityKey']),
      'status': _string(group['status']),
      'sourceRunIds': _stringList(group['runIds']),
      'blockedReasonCodes': blockedReasonCodes,
      'evidenceNeeds': evidenceNeeds,
      'safeSelectors': <String, dynamic>{
        'capabilities': safeCapabilities,
        'modelClasses': _safeSelectorValues({
          for (final need in evidenceNeeds) _string(need['modelClass']),
        }),
        'profileNames': safeProfileNames,
        'promptVariantNames': safePromptVariantNames,
        'pairwiseIntentKeys': safePairwiseIntentKeys,
      },
      'withheldSelectors': <String, dynamic>{
        'scenarioIdsOmitted': true,
        'sourceReportScenarioSuggestionCount': sourceScenarioSuggestionCount,
        'unsafeSelectorValueCount': unsafeSelectorValueCount,
        'reason':
            'scenario ids and unsafe selector values are withheld from '
            'portfolio plans',
      },
      'manualPrerequisites': _manualPrerequisites(blockedReasonCodes),
      'nextRunEnv': nextRunEnv,
      'recommendedCommands': _recommendedCommands(),
    };
  }

  static List<Map<String, dynamic>> _manualPrerequisites(
    Iterable<String> blockerCodes,
  ) {
    return [
      for (final code in _sortedStrings(blockerCodes))
        <String, dynamic>{
          'code': code,
          'action': _manualPrerequisiteAction(code),
        },
    ];
  }

  static String _manualPrerequisiteAction(String blockerCode) {
    final normalized = blockerCode.toLowerCase();
    if (normalized.contains('contract')) return 'regenerateTuningReport';
    if (normalized.contains('compatibility')) return 'compareWithinGroup';
    if (normalized.contains('calibration') || normalized.contains('human')) {
      return 'completeHumanCalibration';
    }
    if (normalized.contains('holdout') ||
        normalized.contains('protected') ||
        normalized.contains('catalog')) {
      return 'curateProtectedHoldoutCatalog';
    }
    if (normalized.contains('pairwise')) return 'completePairwiseReviewImport';
    if (normalized.contains('verdict') || normalized.contains('judge')) {
      return 'gradeMissingVerdicts';
    }
    return 'collectMissingEvidence';
  }

  static List<Map<String, dynamic>> _recommendedCommands() {
    return const [
      <String, dynamic>{
        'mode': 'compare-tuning',
        'command': 'eval/run_level2.sh compare-tuning',
      },
    ];
  }

  static String _nextExperimentObjective(String portfolioStatus) {
    return switch (portfolioStatus) {
      'invalid' => 'fixInvalidTuningReports',
      'insufficientReports' => 'collectComparableTuningReports',
      'incompatible' => 'compareWithinCompatibilityGroups',
      'promotionReady' => 'reviewPromotionCandidates',
      'diagnosticLeader' => 'collectPromotionEvidenceForDiagnosticLeader',
      'dataDeficient' => 'closePortfolioEvidenceGaps',
      _ => 'closePortfolioBlockers',
    };
  }

  static void _validateInputReports(
    List<String> issues,
    List<dynamic>? inputReports,
  ) {
    if (inputReports == null) return;
    for (final (index, report) in inputReports.indexed) {
      final input = _expectMap(issues, report, 'inputReports[$index]');
      if (input == null) continue;
      _expectNonNegativeInt(
        issues,
        input['index'],
        'inputReports[$index].index',
      );
      _expectNonEmptyString(
        issues,
        input['runId'],
        'inputReports[$index].runId',
      );
      final contractStatus = _expectNonEmptyString(
        issues,
        input['contractStatus'],
        'inputReports[$index].contractStatus',
      );
      if (contractStatus != null &&
          contractStatus != 'valid' &&
          contractStatus != 'invalid') {
        issues.add(
          'inputReports[$index].contractStatus must be valid or invalid',
        );
      }
      if (contractStatus == 'invalid') {
        _expectStringList(
          issues,
          input['contractIssues'],
          'inputReports[$index].contractIssues',
        );
        continue;
      }
      _expectDigest(
        issues,
        input['manifestDigest'],
        'inputReports[$index].manifestDigest',
      );
      _expectBool(issues, input['ready'], 'inputReports[$index].ready');
      _expectNonEmptyString(
        issues,
        input['label'],
        'inputReports[$index].label',
      );
      _expectNonEmptyString(
        issues,
        input['promotionStatus'],
        'inputReports[$index].promotionStatus',
      );
      _expectBool(
        issues,
        input['calibrationPresent'],
        'inputReports[$index].calibrationPresent',
      );
      _expectBool(
        issues,
        input['pairwisePresent'],
        'inputReports[$index].pairwisePresent',
      );
      _expectNonEmptyString(
        issues,
        input['targetKind'],
        'inputReports[$index].targetKind',
      );
      for (final field in const [
        'scenarioSetDigest',
        'policyDigest',
        'profileSetDigest',
        'profileBindingSetDigest',
        'promptVariantSetDigest',
      ]) {
        _expectDigest(issues, input[field], 'inputReports[$index].$field');
      }
      _expectBool(
        issues,
        input['protectedIdsRedacted'],
        'inputReports[$index].protectedIdsRedacted',
      );
      _expectStringList(
        issues,
        input['requiredCapabilities'],
        'inputReports[$index].requiredCapabilities',
      );
      _expectStringList(
        issues,
        input['blockedReasonCodes'],
        'inputReports[$index].blockedReasonCodes',
      );
    }
  }

  static void _validateNextPlan(
    List<String> issues,
    Map<String, dynamic>? plan,
    String? portfolioStatus,
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
    final status = _expectNonEmptyString(
      issues,
      plan['status'],
      'nextExperimentPlan.status',
    );
    if (portfolioStatus != null &&
        status != null &&
        status != portfolioStatus) {
      issues.add('nextExperimentPlan.status must match portfolio status');
    }
    _expectNonEmptyString(
      issues,
      plan['objective'],
      'nextExperimentPlan.objective',
    );
    _expectNonNegativeInt(
      issues,
      plan['inputReportCount'],
      'nextExperimentPlan.inputReportCount',
    );
    _expectNonNegativeInt(
      issues,
      plan['validReportCount'],
      'nextExperimentPlan.validReportCount',
    );
    for (final field in const [
      'sourceCompatibilityKeys',
      'sourceRunIds',
      'blockedReasonCodes',
    ]) {
      _expectStringList(issues, plan[field], 'nextExperimentPlan.$field');
    }
    _validateWithheldSelectors(
      issues,
      _expectMap(
        issues,
        plan['withheldSelectors'],
        'nextExperimentPlan.withheldSelectors',
      ),
      'nextExperimentPlan.withheldSelectors',
    );
    _validateManualPrerequisites(
      issues,
      _expectList(
        issues,
        plan['manualPrerequisites'],
        'nextExperimentPlan.manualPrerequisites',
      ),
      'nextExperimentPlan.manualPrerequisites',
    );
    _validateGroupPlans(
      issues,
      _expectList(issues, plan['groupPlans'], 'nextExperimentPlan.groupPlans'),
    );
    final commands = _expectList(
      issues,
      plan['recommendedCommands'],
      'nextExperimentPlan.recommendedCommands',
    );
    _validateRecommendedCommands(
      issues,
      commands,
      'nextExperimentPlan.recommendedCommands',
    );
  }

  static void _validateWithheldSelectors(
    List<String> issues,
    Map<String, dynamic>? selection,
    String path,
  ) {
    if (selection == null) return;
    _expectBool(
      issues,
      selection['scenarioIdsOmitted'],
      '$path.scenarioIdsOmitted',
    );
    if (selection['scenarioIdsOmitted'] != true) {
      issues.add('$path.scenarioIdsOmitted must be true');
    }
    _expectNonNegativeInt(
      issues,
      selection['sourceReportScenarioSuggestionCount'],
      '$path.sourceReportScenarioSuggestionCount',
    );
    if (selection.containsKey('unsafeSelectorValueCount')) {
      _expectNonNegativeInt(
        issues,
        selection['unsafeSelectorValueCount'],
        '$path.unsafeSelectorValueCount',
      );
    }
    _expectNonEmptyString(issues, selection['reason'], '$path.reason');
  }

  static void _validateGroupPlans(
    List<String> issues,
    List<dynamic>? plans,
  ) {
    if (plans == null) return;
    for (final (index, planValue) in plans.indexed) {
      final plan = _expectMap(
        issues,
        planValue,
        'nextExperimentPlan.groupPlans[$index]',
      );
      if (plan == null) continue;
      _expectDigest(
        issues,
        plan['compatibilityKey'],
        'nextExperimentPlan.groupPlans[$index].compatibilityKey',
      );
      _expectNonEmptyString(
        issues,
        plan['status'],
        'nextExperimentPlan.groupPlans[$index].status',
      );
      _expectStringList(
        issues,
        plan['sourceRunIds'],
        'nextExperimentPlan.groupPlans[$index].sourceRunIds',
      );
      _expectStringList(
        issues,
        plan['blockedReasonCodes'],
        'nextExperimentPlan.groupPlans[$index].blockedReasonCodes',
      );
      _validateEvidenceNeeds(
        issues,
        _expectList(
          issues,
          plan['evidenceNeeds'],
          'nextExperimentPlan.groupPlans[$index].evidenceNeeds',
        ),
        'nextExperimentPlan.groupPlans[$index].evidenceNeeds',
      );
      _validateSafeSelectors(
        issues,
        _expectMap(
          issues,
          plan['safeSelectors'],
          'nextExperimentPlan.groupPlans[$index].safeSelectors',
        ),
        'nextExperimentPlan.groupPlans[$index].safeSelectors',
      );
      _validateWithheldSelectors(
        issues,
        _expectMap(
          issues,
          plan['withheldSelectors'],
          'nextExperimentPlan.groupPlans[$index].withheldSelectors',
        ),
        'nextExperimentPlan.groupPlans[$index].withheldSelectors',
      );
      _validateManualPrerequisites(
        issues,
        _expectList(
          issues,
          plan['manualPrerequisites'],
          'nextExperimentPlan.groupPlans[$index].manualPrerequisites',
        ),
        'nextExperimentPlan.groupPlans[$index].manualPrerequisites',
      );
      _validateEnvMap(
        issues,
        _expectMap(
          issues,
          plan['nextRunEnv'],
          'nextExperimentPlan.groupPlans[$index].nextRunEnv',
        ),
        'nextExperimentPlan.groupPlans[$index].nextRunEnv',
      );
      _validateRecommendedCommands(
        issues,
        _expectList(
          issues,
          plan['recommendedCommands'],
          'nextExperimentPlan.groupPlans[$index].recommendedCommands',
        ),
        'nextExperimentPlan.groupPlans[$index].recommendedCommands',
      );
    }
  }

  static void _validateEvidenceNeeds(
    List<String> issues,
    List<dynamic>? needs,
    String path,
  ) {
    if (needs == null) return;
    for (final (index, needValue) in needs.indexed) {
      final need = _expectMap(issues, needValue, '$path[$index]');
      if (need == null) continue;
      for (final field in const [
        'primaryCapabilityId',
        'agentKind',
        'modelClass',
        'promptVariantName',
        'evidenceStatus',
      ]) {
        _expectNonEmptyString(issues, need[field], '$path[$index].$field');
      }
      _expectStringList(
        issues,
        need['blockerCodes'],
        '$path[$index].blockerCodes',
      );
    }
  }

  static void _validateSafeSelectors(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    for (final field in const [
      'capabilities',
      'modelClasses',
      'profileNames',
      'promptVariantNames',
      'pairwiseIntentKeys',
    ]) {
      final values = _expectList(issues, selectors[field], '$path.$field');
      if (values == null) continue;
      for (final (index, value) in values.indexed) {
        if (value is! String || !_isSafeSelectorValue(value)) {
          issues.add('$path.$field[$index] must be a safe selector string');
        }
      }
    }
  }

  static void _validateManualPrerequisites(
    List<String> issues,
    List<dynamic>? prerequisites,
    String path,
  ) {
    if (prerequisites == null) return;
    for (final (index, prerequisiteValue) in prerequisites.indexed) {
      final prerequisite = _expectMap(
        issues,
        prerequisiteValue,
        '$path[$index]',
      );
      if (prerequisite == null) continue;
      _expectNonEmptyString(issues, prerequisite['code'], '$path[$index].code');
      _expectNonEmptyString(
        issues,
        prerequisite['action'],
        '$path[$index].action',
      );
    }
  }

  static void _validateRecommendedCommands(
    List<String> issues,
    List<dynamic>? commands,
    String path,
  ) {
    if (commands == null) return;
    for (final (index, commandValue) in commands.indexed) {
      final command = _expectMap(issues, commandValue, '$path[$index]');
      if (command == null) continue;
      final mode = _expectNonEmptyString(
        issues,
        command['mode'],
        '$path[$index].mode',
      );
      if (mode != null && !_allowedCommandModes.contains(mode)) {
        issues.add('$path[$index].mode is unsupported');
      }
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
      if (entry.value is! String || !_isSafeEnvValue(entry.value as String)) {
        issues.add('$path.${entry.key} must be a safe string');
      }
    }
  }

  static void _validateCompatibilityGroups(
    List<String> issues,
    List<dynamic>? groups,
  ) {
    if (groups == null) return;
    for (final (index, groupValue) in groups.indexed) {
      final group = _expectMap(
        issues,
        groupValue,
        'compatibilityGroups[$index]',
      );
      if (group == null) continue;
      final compatibilityKey = _expectDigest(
        issues,
        group['compatibilityKey'],
        'compatibilityGroups[$index].compatibilityKey',
      );
      final status = _expectNonEmptyString(
        issues,
        group['status'],
        'compatibilityGroups[$index].status',
      );
      if (status != null &&
          status != 'promotionReady' &&
          status != 'dataDeficient' &&
          status != 'diagnosticLeader' &&
          status != 'blocked') {
        issues.add(
          'compatibilityGroups[$index].status must be promotionReady, '
          'dataDeficient, diagnosticLeader, or blocked',
        );
      }
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
        _expectDigest(
          issues,
          fixedEvidence['scenarioSetDigest'],
          'compatibilityGroups[$index].fixedEvidence.scenarioSetDigest',
        );
        _expectDigest(
          issues,
          fixedEvidence['policyDigest'],
          'compatibilityGroups[$index].fixedEvidence.policyDigest',
        );
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
        if (compatibilityKey != null &&
            EvalProvenance.digestJson(fixedEvidence) != compatibilityKey) {
          issues.add(
            'compatibilityGroups[$index].compatibilityKey must match '
            'fixedEvidence',
          );
        }
      }
      _expectNonNegativeInt(
        issues,
        group['reportCount'],
        'compatibilityGroups[$index].reportCount',
      );
      _expectStringList(
        issues,
        group['runIds'],
        'compatibilityGroups[$index].runIds',
      );
      _validateTuningAxes(issues, group, index);
      _validateFamilies(issues, group, index);
    }
  }

  static void _validateTuningAxes(
    List<String> issues,
    Map<String, dynamic> group,
    int groupIndex,
  ) {
    final axes = _expectMap(
      issues,
      group['tuningAxes'],
      'compatibilityGroups[$groupIndex].tuningAxes',
    );
    if (axes == null) return;
    for (final field in const [
      'profileSetDigests',
      'profileBindingSetDigests',
      'promptVariantSetDigests',
    ]) {
      final values = _expectList(
        issues,
        axes[field],
        'compatibilityGroups[$groupIndex].tuningAxes.$field',
      );
      if (values == null) continue;
      for (final (index, value) in values.indexed) {
        _expectDigest(
          issues,
          value,
          'compatibilityGroups[$groupIndex].tuningAxes.$field[$index]',
        );
      }
    }
    _expectStringList(
      issues,
      axes['modelClasses'],
      'compatibilityGroups[$groupIndex].tuningAxes.modelClasses',
    );
    _expectStringList(
      issues,
      axes['promptVariantNames'],
      'compatibilityGroups[$groupIndex].tuningAxes.promptVariantNames',
    );
  }

  static void _validateFamilies(
    List<String> issues,
    Map<String, dynamic> group,
    int groupIndex,
  ) {
    final families = _expectList(
      issues,
      group['families'],
      'compatibilityGroups[$groupIndex].families',
    );
    if (families == null) return;
    for (final (familyIndex, familyValue) in families.indexed) {
      final family = _expectMap(
        issues,
        familyValue,
        'compatibilityGroups[$groupIndex].families[$familyIndex]',
      );
      if (family == null) continue;
      _expectNonEmptyString(
        issues,
        family['familyKey'],
        'compatibilityGroups[$groupIndex].families[$familyIndex].familyKey',
      );
      final status = _expectNonEmptyString(
        issues,
        family['status'],
        'compatibilityGroups[$groupIndex].families[$familyIndex].status',
      );
      if (status != null &&
          status != 'promotionReady' &&
          status != 'dataDeficient' &&
          status != 'diagnosticLeader' &&
          status != 'blocked') {
        issues.add(
          'compatibilityGroups[$groupIndex].families[$familyIndex].status '
          'must be promotionReady, dataDeficient, diagnosticLeader, or blocked',
        );
      }
      _expectNonEmptyString(
        issues,
        family['primaryCapabilityId'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.primaryCapabilityId',
      );
      _expectNonEmptyString(
        issues,
        family['agentKind'],
        'compatibilityGroups[$groupIndex].families[$familyIndex].agentKind',
      );
      _expectNonNegativeInt(
        issues,
        family['candidateCount'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidateCount',
      );
      _validateLeader(issues, family, groupIndex, familyIndex);
      _expectStringList(
        issues,
        family['promotionReadyCandidateKeys'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.promotionReadyCandidateKeys',
      );
      _expectStringList(
        issues,
        family['dataDeficiencyCodes'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.dataDeficiencyCodes',
      );
      _validateCandidates(issues, family, groupIndex, familyIndex);
    }
  }

  static void _validateLeader(
    List<String> issues,
    Map<String, dynamic> family,
    int groupIndex,
    int familyIndex,
  ) {
    final leader = _expectMap(
      issues,
      family['leader'],
      'compatibilityGroups[$groupIndex].families[$familyIndex].leader',
    );
    if (leader == null) return;
    _expectNonEmptyString(
      issues,
      leader['candidateKey'],
      'compatibilityGroups[$groupIndex].families[$familyIndex]'
      '.leader.candidateKey',
    );
    _expectNonEmptyString(
      issues,
      leader['runId'],
      'compatibilityGroups[$groupIndex].families[$familyIndex].leader.runId',
    );
    _expectNonEmptyString(
      issues,
      leader['modelClass'],
      'compatibilityGroups[$groupIndex].families[$familyIndex]'
      '.leader.modelClass',
    );
    _expectNonEmptyString(
      issues,
      leader['promptVariantName'],
      'compatibilityGroups[$groupIndex].families[$familyIndex]'
      '.leader.promptVariantName',
    );
    _expectNonEmptyString(
      issues,
      leader['evidenceStatus'],
      'compatibilityGroups[$groupIndex].families[$familyIndex]'
      '.leader.evidenceStatus',
    );
    _expectBool(
      issues,
      leader['promotionEvidence'],
      'compatibilityGroups[$groupIndex].families[$familyIndex]'
      '.leader.promotionEvidence',
    );
    _expectMap(
      issues,
      leader['rankInputs'],
      'compatibilityGroups[$groupIndex].families[$familyIndex]'
      '.leader.rankInputs',
    );
  }

  static void _validateCandidates(
    List<String> issues,
    Map<String, dynamic> family,
    int groupIndex,
    int familyIndex,
  ) {
    final candidates = _expectList(
      issues,
      family['candidates'],
      'compatibilityGroups[$groupIndex].families[$familyIndex].candidates',
    );
    if (candidates == null) return;
    if (family['candidateCount'] is int &&
        family['candidateCount'] != candidates.length) {
      issues.add(
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidateCount must match candidates.length',
      );
    }
    for (final (candidateIndex, candidateValue) in candidates.indexed) {
      final candidate = _expectMap(
        issues,
        candidateValue,
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex]',
      );
      if (candidate == null) continue;
      _expectNonEmptyString(
        issues,
        candidate['candidateKey'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex].candidateKey',
      );
      _expectNonEmptyString(
        issues,
        candidate['runId'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex].runId',
      );
      for (final field in const [
        'manifestDigest',
        'profileSetDigest',
        'profileBindingSetDigest',
        'promptVariantSetDigest',
      ]) {
        _expectDigest(
          issues,
          candidate[field],
          'compatibilityGroups[$groupIndex].families[$familyIndex]'
          '.candidates[$candidateIndex].$field',
        );
      }
      for (final field in const [
        'primaryCapabilityId',
        'agentKind',
        'modelClass',
        'promptVariantName',
        'promotionStatus',
        'evidenceStatus',
        'recommendation',
      ]) {
        _expectNonEmptyString(
          issues,
          candidate[field],
          'compatibilityGroups[$groupIndex].families[$familyIndex]'
          '.candidates[$candidateIndex].$field',
        );
      }
      _expectBool(
        issues,
        candidate['reportReady'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex].reportReady',
      );
      _expectBool(
        issues,
        candidate['calibrationPresent'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex].calibrationPresent',
      );
      _expectBool(
        issues,
        candidate['pairwisePresent'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex].pairwisePresent',
      );
      for (final field in const [
        'traceCount',
        'judgedTraceCount',
        'passCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          candidate[field],
          'compatibilityGroups[$groupIndex].families[$familyIndex]'
          '.candidates[$candidateIndex].$field',
        );
      }
      for (final field in const [
        'passRate',
        'passRateLowerBound',
        'meanGoalAttainment',
        'meanQuality',
        'meanEfficiency',
        'meanTokenBudgetRatio',
      ]) {
        _expectNumber(
          issues,
          candidate[field],
          'compatibilityGroups[$groupIndex].families[$familyIndex]'
          '.candidates[$candidateIndex].$field',
        );
      }
      _expectStringList(
        issues,
        candidate['blockingReasonCodes'],
        'compatibilityGroups[$groupIndex].families[$familyIndex]'
        '.candidates[$candidateIndex].blockingReasonCodes',
      );
    }
  }

  static void _validateSummary(
    List<String> issues, {
    required String? status,
    required Map<String, dynamic>? summary,
    required List<dynamic>? inputReports,
    required List<dynamic>? groups,
  }) {
    if (summary == null) return;
    final inputReportCount = _expectNonNegativeInt(
      issues,
      summary['inputReportCount'],
      'summary.inputReportCount',
    );
    final validReportCount = _expectNonNegativeInt(
      issues,
      summary['validReportCount'],
      'summary.validReportCount',
    );
    final invalidReportCount = _expectNonNegativeInt(
      issues,
      summary['invalidReportCount'],
      'summary.invalidReportCount',
    );
    final compatibilityGroupCount = _expectNonNegativeInt(
      issues,
      summary['compatibilityGroupCount'],
      'summary.compatibilityGroupCount',
    );
    _expectNonNegativeInt(
      issues,
      summary['promotionReadyFamilyCount'],
      'summary.promotionReadyFamilyCount',
    );
    _expectNonNegativeInt(
      issues,
      summary['dataDeficientFamilyCount'],
      'summary.dataDeficientFamilyCount',
    );
    _expectNonNegativeInt(
      issues,
      summary['diagnosticLeaderFamilyCount'],
      'summary.diagnosticLeaderFamilyCount',
    );

    if (inputReports != null && inputReportCount != inputReports.length) {
      issues.add('summary.inputReportCount must match inputReports.length');
    }
    if (groups != null && compatibilityGroupCount != groups.length) {
      issues.add(
        'summary.compatibilityGroupCount must match '
        'compatibilityGroups.length',
      );
    }
    if (inputReports != null &&
        validReportCount != null &&
        invalidReportCount != null) {
      final actualValid = inputReports.where((input) {
        return input is Map<String, dynamic> &&
            input['contractStatus'] == 'valid';
      }).length;
      final actualInvalid = inputReports.length - actualValid;
      if (validReportCount != actualValid) {
        issues.add('summary.validReportCount must match valid inputs');
      }
      if (invalidReportCount != actualInvalid) {
        issues.add('summary.invalidReportCount must match invalid inputs');
      }
    }
    if (status == null ||
        inputReports == null ||
        groups == null ||
        validReportCount == null ||
        invalidReportCount == null) {
      return;
    }
    final groupStatuses = [
      for (final group in groups)
        if (group is Map<String, dynamic>) _string(group['status']),
    ];
    final expectedStatus = _expectedPortfolioStatus(
      validReportCount: validReportCount,
      invalidReportCount: invalidReportCount,
      groupCount: groups.length,
      groupStatuses: groupStatuses,
    );
    if (status != expectedStatus) {
      issues.add('status must match summary and compatibility group evidence');
    }
  }

  static String _expectedPortfolioStatus({
    required int validReportCount,
    required int invalidReportCount,
    required int groupCount,
    required List<String> groupStatuses,
  }) {
    if (invalidReportCount > 0) return 'invalid';
    if (validReportCount < 2) return 'insufficientReports';
    if (groupCount > 1) return 'incompatible';
    if (groupStatuses.contains('promotionReady')) return 'promotionReady';
    if (groupStatuses.contains('dataDeficient')) return 'dataDeficient';
    if (groupStatuses.contains('diagnosticLeader')) return 'diagnosticLeader';
    return 'blocked';
  }

  static void _validateNoScenarioIds(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is String) {
      if (value.contains('<redacted-scenario')) {
        issues.add('$path must not contain redacted scenario placeholders');
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoScenarioIds(issues, item, '$path[$index]');
      }
      return;
    }
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
    }
  }
}

final class _TuningReportSnapshot {
  _TuningReportSnapshot._({
    required this.index,
    required this.report,
    required this.contractIssues,
  });

  factory _TuningReportSnapshot.fromReport({
    required int index,
    required Map<String, dynamic> report,
  }) {
    return _TuningReportSnapshot._(
      index: index,
      report: report,
      contractIssues: EvalTuningReportContract.validate(report),
    );
  }

  final int index;
  final Map<String, dynamic> report;
  final List<String> contractIssues;

  bool get isValid => contractIssues.isEmpty;

  Map<String, dynamic> get run => _map(report['run']);

  Map<String, dynamic> get policy => _map(report['policy']);

  Map<String, dynamic> get status => _map(report['status']);

  Map<String, dynamic> get promotion => _map(report['promotion']);

  Map<String, dynamic> get pairwise => _map(report['pairwise']);

  Map<String, dynamic> get calibration => _map(report['calibration']);

  Map<String, dynamic> get selectors => _map(run['selectors']);

  String get runId => _string(run['runId'], fallback: 'report-$index');

  String get manifestDigest => _string(run['manifestDigest']);

  String get targetKind => _string(run['targetKind']);

  String get scenarioSetDigest => _string(run['scenarioSetDigest']);

  String get profileSetDigest => _string(run['profileSetDigest']);

  String get profileBindingSetDigest => _string(run['profileBindingSetDigest']);

  String get promptVariantSetDigest =>
      _string(run['agentDirectiveVariantSetDigest']);

  String get policyDigest => _string(policy['digest']);

  bool get protectedIdsRedacted => run['protectedIdsRedacted'] == true;

  bool get ready => status['ready'] == true;

  String get label => _string(status['label']);

  bool get promotionPresent => promotion['present'] == true;

  String get promotionStatus => _string(
    promotion['status'],
    fallback: promotionPresent ? 'unknown' : 'notRequested',
  );

  bool get promotionReady =>
      ready && promotionPresent && promotionStatus == 'promote';

  bool get calibrationPresent => calibration['present'] == true;

  bool get pairwisePresent => pairwise['present'] == true;

  List<String> get requiredCapabilities =>
      _sortedStrings(_stringList(selectors['requiredPrimaryCapabilityIds']));

  Map<String, dynamic> get nextPlan => _map(report['nextExperimentPlan']);

  List<String> nextPlanStrings(String field) => _stringList(nextPlan[field]);

  int get unsafeNextPlanSelectorCount {
    var count = 0;
    for (final field in const [
      'suggestedCapabilities',
      'suggestedProfileNames',
      'suggestedPromptVariantNames',
      'requiredPairwiseIntentKeys',
      'missingOrFailedPairwiseKeys',
    ]) {
      for (final value in nextPlanStrings(field)) {
        if (!_isSafeSelectorValue(value)) count += 1;
      }
    }
    return count;
  }

  List<String> get blockedReasonCodes {
    final reasons = report['blockedReasons'];
    if (reasons is! List) return const <String>[];
    return _sortedStrings(
      {
        for (final reason in reasons)
          if (reason is Map<String, dynamic>) _string(reason['code']),
      }.where((code) => code.isNotEmpty),
    );
  }

  List<Map<String, dynamic>> get slices {
    final value = report['useCaseModelSlices'];
    if (value is! List) return const <Map<String, dynamic>>[];
    return [
      for (final item in value)
        if (item is Map<String, dynamic>) item,
    ];
  }

  Map<String, dynamic> get compatibilityEvidence => <String, dynamic>{
    'targetKind': targetKind,
    'scenarioSetDigest': scenarioSetDigest,
    'policyDigest': policyDigest,
    'requiredCapabilities': requiredCapabilities,
    'protectedIdsRedacted': protectedIdsRedacted,
  };

  String get compatibilityKey =>
      EvalProvenance.digestJson(compatibilityEvidence);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'runId': runId,
    'manifestDigest': manifestDigest,
    'contractStatus': isValid ? 'valid' : 'invalid',
    if (contractIssues.isNotEmpty) 'contractIssues': contractIssues,
    'ready': ready,
    'label': label,
    'promotionStatus': promotionStatus,
    'calibrationPresent': calibrationPresent,
    'pairwisePresent': pairwisePresent,
    'targetKind': targetKind,
    'scenarioSetDigest': scenarioSetDigest,
    'policyDigest': policyDigest,
    'profileSetDigest': profileSetDigest,
    'profileBindingSetDigest': profileBindingSetDigest,
    'promptVariantSetDigest': promptVariantSetDigest,
    'protectedIdsRedacted': protectedIdsRedacted,
    'requiredCapabilities': requiredCapabilities,
    'blockedReasonCodes': blockedReasonCodes,
  };
}

final class _TuningCompatibilityGroup {
  _TuningCompatibilityGroup(this.fixedEvidence);

  final Map<String, dynamic> fixedEvidence;
  final reports = <_TuningReportSnapshot>[];

  String get compatibilityKey => EvalProvenance.digestJson(fixedEvidence);

  void add(_TuningReportSnapshot snapshot) {
    reports.add(snapshot);
  }

  Map<String, dynamic> toJson() {
    final candidates = [
      for (final report in reports)
        for (final slice in report.slices)
          _TuningCandidate.fromSlice(report: report, slice: slice),
    ];
    final families = _families(candidates);
    return <String, dynamic>{
      'compatibilityKey': compatibilityKey,
      'status': _groupStatus(families),
      'fixedEvidence': fixedEvidence,
      'reportCount': reports.length,
      'runIds': _sortedStrings(reports.map((report) => report.runId)),
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
        'modelClasses': _sortedStrings(
          candidates.map((candidate) => candidate.modelClass),
        ),
        'promptVariantNames': _sortedStrings(
          candidates.map((candidate) => candidate.promptVariantName),
        ),
      },
      'families': [
        for (final family in families) family.toJson(),
      ],
    };
  }

  static List<_TuningFamily> _families(List<_TuningCandidate> candidates) {
    final familiesByKey = <String, _TuningFamily>{};
    for (final candidate in candidates) {
      familiesByKey
          .putIfAbsent(
            candidate.familyKey,
            () => _TuningFamily(
              primaryCapabilityId: candidate.primaryCapabilityId,
              agentKind: candidate.agentKind,
            ),
          )
          .add(candidate);
    }
    return familiesByKey.values.toList()
      ..sort((a, b) => a.familyKey.compareTo(b.familyKey));
  }

  static String _groupStatus(List<_TuningFamily> families) {
    if (families.any((family) => family.status == 'promotionReady')) {
      return 'promotionReady';
    }
    if (families.any((family) => family.status == 'dataDeficient')) {
      return 'dataDeficient';
    }
    if (families.any((family) => family.status == 'diagnosticLeader')) {
      return 'diagnosticLeader';
    }
    return 'blocked';
  }
}

final class _TuningFamily {
  _TuningFamily({
    required this.primaryCapabilityId,
    required this.agentKind,
  });

  final String primaryCapabilityId;
  final String agentKind;
  final candidates = <_TuningCandidate>[];

  String get familyKey => '$primaryCapabilityId@$agentKind';

  String get status {
    if (candidates.any(
      (candidate) => candidate.evidenceStatus == 'promotionReady',
    )) {
      return 'promotionReady';
    }
    if (candidates.any(
      (candidate) => candidate.evidenceStatus == 'dataDeficient',
    )) {
      return 'dataDeficient';
    }
    if (candidates.any(
      (candidate) => candidate.evidenceStatus == 'diagnosticOnly',
    )) {
      return 'diagnosticLeader';
    }
    return 'blocked';
  }

  void add(_TuningCandidate candidate) {
    candidates.add(candidate);
  }

  Map<String, dynamic> toJson() {
    final ranked = [...candidates]..sort(_compareCandidates);
    final leader = ranked.isEmpty ? null : ranked.first;
    return <String, dynamic>{
      'familyKey': familyKey,
      'status': status,
      'primaryCapabilityId': primaryCapabilityId,
      'agentKind': agentKind,
      'candidateCount': candidates.length,
      if (leader != null) 'leader': leader.toLeaderJson(),
      'promotionReadyCandidateKeys': _sortedStrings(
        candidates
            .where((candidate) => candidate.evidenceStatus == 'promotionReady')
            .map((candidate) => candidate.candidateKey),
      ),
      'dataDeficiencyCodes': _sortedStrings(
        candidates
            .where((candidate) => candidate.evidenceStatus == 'dataDeficient')
            .expand((candidate) => candidate.blockingReasonCodes),
      ),
      'candidates': [
        for (final candidate in ranked) candidate.toJson(),
      ],
    };
  }

  static int _compareCandidates(
    _TuningCandidate a,
    _TuningCandidate b,
  ) {
    final tier = _compareNum(a.evidenceTier, b.evidenceTier);
    if (tier != 0) return tier;
    final lowerBound = _compareNum(a.passRateLowerBound, b.passRateLowerBound);
    if (lowerBound != 0) return lowerBound;
    final passRate = _compareNum(a.passRate, b.passRate);
    if (passRate != 0) return passRate;
    final goal = _compareNum(a.meanGoalAttainment, b.meanGoalAttainment);
    if (goal != 0) return goal;
    final quality = _compareNum(a.meanQuality, b.meanQuality);
    if (quality != 0) return quality;
    final efficiency = _compareNum(a.meanEfficiency, b.meanEfficiency);
    if (efficiency != 0) return efficiency;
    final tokens = _compareNum(b.meanTokenBudgetRatio, a.meanTokenBudgetRatio);
    if (tokens != 0) return tokens;
    return a.candidateKey.compareTo(b.candidateKey);
  }

  static int _compareNum(num a, num b) => b.compareTo(a);
}

final class _TuningCandidate {
  _TuningCandidate({
    required this.report,
    required this.slice,
  });

  factory _TuningCandidate.fromSlice({
    required _TuningReportSnapshot report,
    required Map<String, dynamic> slice,
  }) {
    return _TuningCandidate(report: report, slice: slice);
  }

  final _TuningReportSnapshot report;
  final Map<String, dynamic> slice;

  String get primaryCapabilityId => _string(slice['primaryCapabilityId']);

  String get agentKind => _string(slice['agentKind']);

  String get modelClass => _string(slice['modelClass']);

  String get promptVariantName => _string(slice['promptVariantName']);

  String get familyKey => '$primaryCapabilityId@$agentKind';

  String get candidateKey =>
      '$primaryCapabilityId@$agentKind@$modelClass@$promptVariantName@'
      '${report.runId}';

  int get traceCount => _int(slice['traceCount']);

  int get judgedTraceCount => _int(slice['judgedTraceCount']);

  int get passCount => _int(slice['passCount']);

  double get passRate => _double(slice['passRate']);

  double get passRateLowerBound => _double(slice['passRateLowerBound']);

  double get meanGoalAttainment => _double(slice['meanGoalAttainment']);

  double get meanQuality => _double(slice['meanQuality']);

  double get meanEfficiency => _double(slice['meanEfficiency']);

  double get meanTokenBudgetRatio => _double(slice['meanTokenBudgetRatio']);

  String get recommendation => _string(slice['recommendation']);

  List<String> get blockingReasonCodes => _sortedStrings({
    ..._stringList(slice['blockingReasons']),
    if (!report.ready) ...report.blockedReasonCodes,
  });

  String get evidenceStatus {
    if (!report.ready) return 'dataDeficient';
    if (blockingReasonCodes.isNotEmpty || recommendation != 'keep') {
      return 'blocked';
    }
    if (report.promotionReady) return 'promotionReady';
    return 'diagnosticOnly';
  }

  int get evidenceTier => switch (evidenceStatus) {
    'promotionReady' => 3,
    'diagnosticOnly' => 2,
    'blocked' => 1,
    _ => 0,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'candidateKey': candidateKey,
    'runId': report.runId,
    'manifestDigest': report.manifestDigest,
    'profileSetDigest': report.profileSetDigest,
    'profileBindingSetDigest': report.profileBindingSetDigest,
    'promptVariantSetDigest': report.promptVariantSetDigest,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
    'reportReady': report.ready,
    'promotionStatus': report.promotionStatus,
    'calibrationPresent': report.calibrationPresent,
    'pairwisePresent': report.pairwisePresent,
    'evidenceStatus': evidenceStatus,
    'traceCount': traceCount,
    'judgedTraceCount': judgedTraceCount,
    'passCount': passCount,
    'passRate': passRate,
    'passRateLowerBound': passRateLowerBound,
    'meanGoalAttainment': meanGoalAttainment,
    'meanQuality': meanQuality,
    'meanEfficiency': meanEfficiency,
    'meanTokenBudgetRatio': meanTokenBudgetRatio,
    'recommendation': recommendation,
    'blockingReasonCodes': blockingReasonCodes,
  };

  Map<String, dynamic> toLeaderJson() {
    final promotionEvidence = evidenceStatus == 'promotionReady';
    return <String, dynamic>{
      'candidateKey': candidateKey,
      'runId': report.runId,
      'modelClass': modelClass,
      'promptVariantName': promptVariantName,
      'evidenceStatus': evidenceStatus,
      'promotionEvidence': promotionEvidence,
      'notPromotionEvidenceReason': promotionEvidence
          ? null
          : 'diagnostic ranking only; promotion requires ready report and '
                'matched promotion evidence',
      'rankInputs': <String, dynamic>{
        'passRateLowerBound': passRateLowerBound,
        'passRate': passRate,
        'meanGoalAttainment': meanGoalAttainment,
        'meanQuality': meanQuality,
        'meanEfficiency': meanEfficiency,
        'meanTokenBudgetRatio': meanTokenBudgetRatio,
      },
    };
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String _string(Object? value, {String fallback = ''}) {
  if (value is String && value.isNotEmpty) return value;
  return fallback;
}

int _int(Object? value) {
  if (value is int) return value;
  return 0;
}

double _double(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return 0;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
  ];
}

List<String> _sortedStrings(Iterable<String> values) {
  return values.where((value) => value.isNotEmpty).toSet().toList()..sort();
}

List<String> _safeSelectorValues(Iterable<String> values) {
  return _sortedStrings(values.where(_isSafeSelectorValue));
}

bool _isSafeSelectorValue(String value) {
  return RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(value);
}

bool _isSafeEnvValue(String value) {
  if (value.trim().isEmpty) return false;
  return value.split(',').every(_isSafeSelectorValue);
}

void _expectEquals(
  List<String> issues,
  Object? actual,
  Object? expected,
  String path,
) {
  if (actual != expected) issues.add('$path must be $expected');
}

Map<String, dynamic>? _expectMap(
  List<String> issues,
  Object? value,
  String path,
) {
  if (value is Map<String, dynamic>) return value;
  issues.add('$path must be an object');
  return null;
}

List<dynamic>? _expectList(
  List<String> issues,
  Object? value,
  String path,
) {
  if (value is List) return value;
  issues.add('$path must be a list');
  return null;
}

String? _expectNonEmptyString(
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

void _expectStringList(
  List<String> issues,
  Object? value,
  String path,
) {
  final list = _expectList(issues, value, path);
  if (list == null) return;
  for (final (index, item) in list.indexed) {
    if (item is! String) issues.add('$path[$index] must be a string');
  }
}

int? _expectNonNegativeInt(
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

void _expectNumber(List<String> issues, Object? value, String path) {
  if (value is! num || !value.isFinite) {
    issues.add('$path must be a finite number');
  }
}

void _expectBool(List<String> issues, Object? value, String path) {
  if (value is! bool) issues.add('$path must be a boolean');
}

String? _expectDigest(List<String> issues, Object? value, String path) {
  if (value is! String || !EvalProvenance.isDigest(value)) {
    issues.add('$path must be a sha256 digest');
    return null;
  }
  return value;
}

void _expectIsoDate(List<String> issues, Object? value, String path) {
  if (value is! String || DateTime.tryParse(value) == null) {
    issues.add('$path must be an ISO-8601 timestamp');
  }
}
