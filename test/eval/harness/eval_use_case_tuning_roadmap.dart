import 'eval_provenance.dart';
import 'eval_use_case_tuning_decision_ledger.dart';

abstract final class EvalUseCaseTuningRoadmap {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseTuningRoadmap';
  static const _allowedStatuses = {
    'empty',
    'invalid',
    'conflict',
    'rollbackRequired',
    'revalidateRequired',
    'accepted',
    'watchOnly',
    'blocked',
  };
  static const _allowedScopeStatuses = {
    'accepted',
    'conflict',
    'rollbackRequired',
    'revalidateRequired',
    'watch',
    'blocked',
  };
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=)/(?:Users|private|var|tmp|Volumes)/',
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

  static Map<String, dynamic> build({
    required List<Map<String, dynamic>> ledgers,
    bool requireDecisionLedgerSourceReplay = false,
    DateTime? generatedAt,
  }) {
    final sourceLedgers = [
      for (final indexed in ledgers.indexed)
        _SourceLedger.fromLedger(
          index: indexed.$1,
          ledger: indexed.$2,
          requireSourceReplay: requireDecisionLedgerSourceReplay,
        ),
    ];
    final scopes = _scopeStates(sourceLedgers);
    final issues = _issues(
      sources: sourceLedgers,
      scopes: scopes,
    );
    final blockedReasonCodes = _blockedReasonCodes(
      issues: issues,
      sources: sourceLedgers,
      scopes: scopes,
    );
    final roadmap = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': _status(
        sources: sourceLedgers,
        scopes: scopes,
      ),
      'summary': <String, dynamic>{
        'sourceLedgerCount': sourceLedgers.length,
        'validLedgerCount': sourceLedgers
            .where((source) => source.valid)
            .length,
        'invalidLedgerCount': sourceLedgers
            .where((source) => !source.valid)
            .length,
        'scopeCount': scopes.length,
        'acceptedScopeCount': _statusCount(scopes, 'accepted'),
        'conflictScopeCount': _statusCount(scopes, 'conflict'),
        'rollbackRequiredScopeCount': _statusCount(
          scopes,
          'rollbackRequired',
        ),
        'revalidateRequiredScopeCount': _statusCount(
          scopes,
          'revalidateRequired',
        ),
        'watchScopeCount': _statusCount(scopes, 'watch'),
        'blockedScopeCount': _statusCount(scopes, 'blocked'),
        'blockedReasonCount': blockedReasonCodes.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'sourceLedgerPathsOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesDecisionLedgersOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'liveCommandsCreated': false,
        'runtimeConfigurationApplied': false,
      },
      'blockedReasonCodes': blockedReasonCodes,
      'sourceLedgers': [
        for (final source in sourceLedgers) source.toJson(),
      ],
      'scopes': [
        for (final scope in scopes) scope.toJson(),
      ],
      'issues': issues,
      'recommendedCommands': _recommendedCommands(
        blockedReasonCodes: blockedReasonCodes,
      ),
    };
    assertValid(roadmap);
    return roadmap;
  }

  static List<String> validate(Map<String, dynamic> roadmap) {
    final issues = <String>[];
    _expectEquals(
      issues,
      roadmap['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, roadmap['kind'], kind, 'kind');
    _expectIsoDate(issues, roadmap['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, roadmap['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final summary = _expectMap(issues, roadmap['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(issues, _expectMap(issues, roadmap['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, roadmap['limitations'], 'limitations'),
    );
    final blockedReasonCodes = _expectStringList(
      issues,
      roadmap['blockedReasonCodes'],
      'blockedReasonCodes',
    );
    final sourceLedgers = _expectList(
      issues,
      roadmap['sourceLedgers'],
      'sourceLedgers',
    );
    _validateSourceLedgers(issues, sourceLedgers);
    final scopes = _expectList(issues, roadmap['scopes'], 'scopes');
    _validateScopes(issues, scopes);
    _validateAcceptedSourceLedgerRefs(
      issues,
      roadmapStatus: _string(roadmap['status']),
      sourceLedgers: _mapList(sourceLedgers),
      scopes: _mapList(scopes),
    );
    _validateIssues(issues, _expectList(issues, roadmap['issues'], 'issues'));
    _validateCommands(
      issues,
      _expectList(
        issues,
        roadmap['recommendedCommands'],
        'recommendedCommands',
      ),
      'recommendedCommands',
    );
    _validateSummaryInvariants(
      issues,
      summary: summary,
      sourceLedgers: sourceLedgers,
      scopes: scopes,
      blockedReasonCodes: blockedReasonCodes,
    );
    _validateNoPrivatePayloads(issues, roadmap, 'roadmap');
    return issues;
  }

  static void assertValid(Map<String, dynamic> roadmap) {
    final issues = validate(roadmap);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning roadmap:\n${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstDecisionLedgers(
    Map<String, dynamic> roadmap, {
    required List<Map<String, dynamic>> ledgers,
    bool requireDecisionLedgerSourceReplay = false,
  }) {
    final issues = validate(roadmap);
    final ledgerIssues = [
      for (final (index, ledger) in ledgers.indexed)
        for (final issue in EvalUseCaseTuningDecisionLedger.validate(ledger))
          'sourceDecisionLedgers[$index]: $issue',
    ];
    if (ledgerIssues.isNotEmpty) {
      issues.add('source decision ledger contract is invalid');
      return issues;
    }
    final expected = build(
      ledgers: ledgers,
      requireDecisionLedgerSourceReplay: requireDecisionLedgerSourceReplay,
    );
    if (EvalProvenance.digestJson(_sourceBoundSubject(roadmap)) !=
        EvalProvenance.digestJson(_sourceBoundSubject(expected))) {
      issues.add('roadmap must match source decision ledgers');
    }
    return issues;
  }

  static void assertMatchesDecisionLedgers(
    Map<String, dynamic> roadmap, {
    required List<Map<String, dynamic>> ledgers,
    bool requireDecisionLedgerSourceReplay = false,
  }) {
    final issues = validateAgainstDecisionLedgers(
      roadmap,
      ledgers: ledgers,
      requireDecisionLedgerSourceReplay: requireDecisionLedgerSourceReplay,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning roadmap source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static List<_ScopeState> _scopeStates(List<_SourceLedger> sources) {
    final groups = <String, _ScopeAccumulator>{};
    for (final source in sources.where((source) => source.valid)) {
      for (final decision in _mapList(source.ledger['decisions'])) {
        groups
            .putIfAbsent(
              _string(decision['scopeKey']),
              () => _ScopeAccumulator(_string(decision['scopeKey'])),
            )
            .addDecision(source, decision);
      }
      for (final entry in _mapList(
        source.ledger['previousDecisionContinuity'],
      )) {
        groups
            .putIfAbsent(
              _string(entry['scopeKey']),
              () => _ScopeAccumulator(_string(entry['scopeKey'])),
            )
            .addContinuity(source, entry);
      }
    }
    return groups.values.map((scope) => scope.build()).toList()
      ..sort((a, b) => a.scopeKey.compareTo(b.scopeKey));
  }

  static List<Map<String, dynamic>> _issues({
    required List<_SourceLedger> sources,
    required List<_ScopeState> scopes,
  }) {
    return [
      if (sources.isEmpty)
        const <String, dynamic>{
          'code': 'roadmap.noDecisionLedgers',
          'severity': 'blocking',
        },
      for (final source in sources)
        if (!source.valid)
          <String, dynamic>{
            'code': 'roadmap.sourceLedgerInvalid',
            'severity': 'blocking',
            'ledgerRef': source.ledgerRef,
            'contractIssueCount': source.contractIssueCount,
          },
      for (final scope in scopes)
        if (scope.status == 'conflict')
          <String, dynamic>{
            'code': 'roadmap.scopeConflict',
            'severity': 'blocking',
            'scopeKey': scope.scopeKey,
            'sourceLedgerCount': scope.sourceLedgerRefs.length,
            'uniqueAcceptedChoiceCount': scope.uniqueAcceptedChoiceCount,
          },
      for (final scope in scopes)
        if (scope.status == 'rollbackRequired')
          <String, dynamic>{
            'code': 'roadmap.scopeRollbackRequired',
            'severity': 'blocking',
            'scopeKey': scope.scopeKey,
            'sourceLedgerCount': scope.sourceLedgerRefs.length,
          },
      for (final scope in scopes)
        if (scope.status == 'revalidateRequired')
          <String, dynamic>{
            'code': 'roadmap.scopeRevalidateRequired',
            'severity': 'blocking',
            'scopeKey': scope.scopeKey,
            'sourceLedgerCount': scope.sourceLedgerRefs.length,
          },
    ];
  }

  static List<String> _blockedReasonCodes({
    required List<Map<String, dynamic>> issues,
    required List<_SourceLedger> sources,
    required List<_ScopeState> scopes,
  }) {
    return _sortedStrings({
      for (final issue in issues) _string(issue['code']),
      for (final source in sources) ...source.blockedReasonCodes,
      for (final scope in scopes) ...scope.blockerCodes,
    });
  }

  static String _status({
    required List<_SourceLedger> sources,
    required List<_ScopeState> scopes,
  }) {
    if (sources.isEmpty) return 'empty';
    if (sources.any((source) => !source.valid)) return 'invalid';
    if (_statusCount(scopes, 'conflict') > 0) return 'conflict';
    if (_statusCount(scopes, 'rollbackRequired') > 0) {
      return 'rollbackRequired';
    }
    if (_statusCount(scopes, 'revalidateRequired') > 0) {
      return 'revalidateRequired';
    }
    if (scopes.isNotEmpty &&
        scopes.every((scope) => scope.status == 'accepted')) {
      return 'accepted';
    }
    if (scopes.isNotEmpty && scopes.every((scope) => scope.status == 'watch')) {
      return 'watchOnly';
    }
    return 'blocked';
  }

  static int _statusCount(List<_ScopeState> scopes, String status) =>
      scopes.where((scope) => scope.status == status).length;

  static List<Map<String, dynamic>> _recommendedCommands({
    required List<String> blockedReasonCodes,
  }) {
    final modes = [
      const ('roadmap', 'eval/run_level2.sh roadmap'),
      if (blockedReasonCodes.any((code) => code.contains('sourceLedger')))
        const ('decision-gate', 'eval/run_level2.sh decision-gate'),
      if (blockedReasonCodes.any((code) => code.contains('scope')))
        const ('decision-gate', 'eval/run_level2.sh decision-gate'),
    ];
    return [
      for (final command in modes)
        <String, dynamic>{
          'mode': command.$1,
          'command': command.$2,
        },
    ];
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'sourceLedgerCount',
      'validLedgerCount',
      'invalidLedgerCount',
      'scopeCount',
      'acceptedScopeCount',
      'conflictScopeCount',
      'rollbackRequiredScopeCount',
      'revalidateRequiredScopeCount',
      'watchScopeCount',
      'blockedScopeCount',
      'blockedReasonCount',
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
      'sourceLedgerPathsOmitted': true,
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
      'consumesDecisionLedgersOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'liveCommandsCreated': false,
      'runtimeConfigurationApplied': false,
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

  static void _validateSourceLedgers(
    List<String> issues,
    List<dynamic>? sourceLedgers,
  ) {
    if (sourceLedgers == null) return;
    for (final (index, value) in sourceLedgers.indexed) {
      final source = _expectMap(issues, value, 'sourceLedgers[$index]');
      if (source == null) continue;
      _expectNonEmptyString(
        issues,
        source['ledgerRef'],
        'sourceLedgers[$index].ledgerRef',
      );
      _expectEquals(
        issues,
        source['kind'],
        EvalUseCaseTuningDecisionLedger.kind,
        'sourceLedgers[$index].kind',
      );
      _expectEquals(
        issues,
        source['schemaVersion'],
        EvalUseCaseTuningDecisionLedger.schemaVersion,
        'sourceLedgers[$index].schemaVersion',
      );
      _expectNonEmptyString(
        issues,
        source['status'],
        'sourceLedgers[$index].status',
      );
      _expectDigest(
        issues,
        source['ledgerDigest'],
        'sourceLedgers[$index].ledgerDigest',
      );
      for (final field in const [
        'contractIssueCount',
        'decisionCount',
        'acceptedDecisionCount',
        'conflictDecisionCount',
        'watchDecisionCount',
        'blockedDecisionCount',
        'rollbackRequiredCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          source[field],
          'sourceLedgers[$index].$field',
        );
      }
      _expectStringList(
        issues,
        source['blockedReasonCodes'],
        'sourceLedgers[$index].blockedReasonCodes',
      );
    }
  }

  static void _validateScopes(List<String> issues, List<dynamic>? scopes) {
    if (scopes == null) return;
    for (final (index, value) in scopes.indexed) {
      final scope = _expectMap(issues, value, 'scopes[$index]');
      if (scope == null) continue;
      _expectDigest(issues, scope['scopeKey'], 'scopes[$index].scopeKey');
      _expectBool(
        issues,
        scope['scopeMetadataAvailable'],
        'scopes[$index].scopeMetadataAvailable',
      );
      if (scope['scopeMetadataAvailable'] == true) {
        _expectDigest(
          issues,
          scope['compatibilityKey'],
          'scopes[$index].compatibilityKey',
        );
        for (final field in const ['primaryCapabilityId', 'agentKind']) {
          _expectNonEmptyString(
            issues,
            scope[field],
            'scopes[$index].$field',
          );
        }
      }
      final status = _expectNonEmptyString(
        issues,
        scope['status'],
        'scopes[$index].status',
      );
      if (status != null && !_allowedScopeStatuses.contains(status)) {
        issues.add('scopes[$index].status must be supported');
      }
      _expectStringList(
        issues,
        scope['sourceLedgerRefs'],
        'scopes[$index].sourceLedgerRefs',
      );
      _expectStringList(
        issues,
        scope['decisionStatuses'],
        'scopes[$index].decisionStatuses',
      );
      _expectStringList(
        issues,
        scope['continuityStatuses'],
        'scopes[$index].continuityStatuses',
      );
      for (final field in const [
        'acceptedChoiceCount',
        'uniqueAcceptedChoiceCount',
      ]) {
        _expectNonNegativeInt(issues, scope[field], 'scopes[$index].$field');
      }
      final choices = _expectList(
        issues,
        scope['acceptedChoices'],
        'scopes[$index].acceptedChoices',
      );
      if (choices != null) {
        for (final (choiceIndex, choice) in choices.indexed) {
          _validateAcceptedChoice(
            issues,
            _expectMap(
              issues,
              choice,
              'scopes[$index].acceptedChoices[$choiceIndex]',
            ),
            'scopes[$index].acceptedChoices[$choiceIndex]',
          );
        }
      }
      _expectStringList(
        issues,
        scope['blockerCodes'],
        'scopes[$index].blockerCodes',
      );
      _expectNonEmptyString(
        issues,
        scope['nextAction'],
        'scopes[$index].nextAction',
      );
    }
  }

  static void _validateAcceptedSourceLedgerRefs(
    List<String> issues, {
    required String roadmapStatus,
    required List<Map<String, dynamic>> sourceLedgers,
    required List<Map<String, dynamic>> scopes,
  }) {
    final acceptedScopes = [
      for (final scope in scopes)
        if (_string(scope['status']) == 'accepted') scope,
    ];
    if (roadmapStatus != 'accepted' && acceptedScopes.isEmpty) return;
    final sourceLedgerRefs = {
      for (final source in sourceLedgers) _string(source['ledgerRef']),
    }..remove('');
    if (sourceLedgerRefs.isEmpty) {
      issues.add('accepted roadmap requires source ledger evidence');
    }
    for (final (scopeIndex, scope) in scopes.indexed) {
      if (_string(scope['status']) != 'accepted') continue;
      final scopeRefs = _stringList(scope['sourceLedgerRefs']);
      if (scopeRefs.isEmpty) {
        issues.add('scopes[$scopeIndex].sourceLedgerRefs must not be empty');
      }
      for (final ref in scopeRefs) {
        if (!sourceLedgerRefs.contains(ref)) {
          issues.add(
            'scopes[$scopeIndex].sourceLedgerRefs must reference sourceLedgers',
          );
        }
      }
      for (final (choiceIndex, choice) in _mapList(
        scope['acceptedChoices'],
      ).indexed) {
        final choiceRefs = _stringList(choice['sourceLedgerRefs']);
        if (choiceRefs.isEmpty) {
          issues.add(
            'scopes[$scopeIndex].acceptedChoices[$choiceIndex].sourceLedgerRefs '
            'must not be empty',
          );
        }
        for (final ref in choiceRefs) {
          if (!sourceLedgerRefs.contains(ref)) {
            issues.add(
              'scopes[$scopeIndex].acceptedChoices[$choiceIndex].'
              'sourceLedgerRefs must reference sourceLedgers',
            );
          }
        }
      }
    }
  }

  static void _validateAcceptedChoice(
    List<String> issues,
    Map<String, dynamic>? choice,
    String path,
  ) {
    if (choice == null) return;
    for (final field in const [
      'acceptedCellKey',
      'reportDigest',
      'modelClassCoverageProofRef',
      'modelClassCoverageClassRef',
      'workOrderBatchRef',
      'modelClassCoverageDigest',
      'sourceWorkOrderDigest',
    ]) {
      _expectDigest(issues, choice[field], '$path.$field');
    }
    _expectDigest(
      issues,
      choice['modelClassCoverageRef'],
      '$path.modelClassCoverageRef',
    );
    for (final field in const ['modelClass', 'promptVariantName']) {
      _expectNonEmptyString(issues, choice[field], '$path.$field');
    }
    _expectStringList(issues, choice['sourceLedgerRefs'], '$path.sourceRefs');
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
    required List<dynamic>? sourceLedgers,
    required List<dynamic>? scopes,
    required List<String>? blockedReasonCodes,
  }) {
    if (summary == null) return;
    if (sourceLedgers != null &&
        summary['sourceLedgerCount'] is int &&
        summary['sourceLedgerCount'] != sourceLedgers.length) {
      issues.add('summary.sourceLedgerCount must match sourceLedgers.length');
    }
    if (scopes != null &&
        summary['scopeCount'] is int &&
        summary['scopeCount'] != scopes.length) {
      issues.add('summary.scopeCount must match scopes.length');
    }
    if (blockedReasonCodes != null &&
        summary['blockedReasonCount'] is int &&
        summary['blockedReasonCount'] != blockedReasonCodes.length) {
      issues.add(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      );
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

  static Map<String, dynamic> _sourceBoundSubject(
    Map<String, dynamic> roadmap,
  ) => <String, dynamic>{
    'schemaVersion': roadmap['schemaVersion'],
    'kind': roadmap['kind'],
    'status': roadmap['status'],
    'summary': roadmap['summary'],
    'privacy': roadmap['privacy'],
    'limitations': roadmap['limitations'],
    'blockedReasonCodes': roadmap['blockedReasonCodes'],
    'sourceLedgers': _sortedMapListByStringField(
      _mapList(roadmap['sourceLedgers']),
      'ledgerRef',
    ),
    'scopes': roadmap['scopes'],
    'issues': roadmap['issues'],
    'recommendedCommands': roadmap['recommendedCommands'],
  };

  static List<Map<String, dynamic>> _sortedMapListByStringField(
    List<Map<String, dynamic>> values,
    String field,
  ) =>
      values.toList()
        ..sort((a, b) => _string(a[field]).compareTo(_string(b[field])));
}

final class _SourceLedger {
  _SourceLedger({
    required this.ledgerRef,
    required this.ledger,
    required this.ledgerDigest,
    required this.contractIssues,
  });

  factory _SourceLedger.fromLedger({
    required int index,
    required Map<String, dynamic> ledger,
    bool requireSourceReplay = false,
  }) {
    final ledgerContractIssues = EvalUseCaseTuningDecisionLedger.validate(
      ledger,
    );
    final contractIssues = [
      ...ledgerContractIssues,
      if (requireSourceReplay &&
          ledgerContractIssues.isEmpty &&
          !EvalUseCaseTuningDecisionLedger.hasVerifiedSourceReplay(ledger))
        'decision ledger source replay must be verified',
    ];
    final decisionLedgerRef = _string(ledger['decisionLedgerRef']);
    return _SourceLedger(
      ledgerRef:
          contractIssues.isEmpty && EvalProvenance.isDigest(decisionLedgerRef)
          ? decisionLedgerRef
          : 'ledger-${(index + 1).toString().padLeft(4, '0')}',
      ledger: ledger,
      ledgerDigest: EvalProvenance.digestJson(ledger),
      contractIssues: contractIssues,
    );
  }

  final String ledgerRef;
  final Map<String, dynamic> ledger;
  final String ledgerDigest;
  final List<String> contractIssues;

  bool get valid => contractIssues.isEmpty;

  int get contractIssueCount => contractIssues.length;

  List<String> get blockedReasonCodes =>
      valid ? _stringList(ledger['blockedReasonCodes']) : const <String>[];

  Map<String, dynamic> toJson() {
    final decisions = _mapList(ledger['decisions']);
    final continuity = _mapList(ledger['previousDecisionContinuity']);
    return <String, dynamic>{
      'ledgerRef': ledgerRef,
      'kind': EvalUseCaseTuningDecisionLedger.kind,
      'schemaVersion': EvalUseCaseTuningDecisionLedger.schemaVersion,
      'status': !valid
          ? 'invalid'
          : _string(ledger['status']).isEmpty
          ? 'unknown'
          : _string(ledger['status']),
      'ledgerDigest': ledgerDigest,
      'contractIssueCount': contractIssueCount,
      'decisionCount': decisions.length,
      'acceptedDecisionCount': _statusCount(decisions, 'accepted'),
      'conflictDecisionCount': _statusCount(decisions, 'conflict'),
      'watchDecisionCount': _statusCount(decisions, 'watch'),
      'blockedDecisionCount':
          _statusCount(decisions, 'blocked') +
          _statusCount(decisions, 'reviewBlocked') +
          _statusCount(decisions, 'staleEvidence'),
      'rollbackRequiredCount': _statusCount(
        continuity,
        'rollbackRequired',
      ),
      'blockedReasonCodes': blockedReasonCodes,
    };
  }

  int _statusCount(List<Map<String, dynamic>> items, String status) =>
      items.where((item) => item['status'] == status).length;
}

final class _ScopeAccumulator {
  _ScopeAccumulator(this.scopeKey);

  final String scopeKey;
  final _sourceLedgerRefs = <String>{};
  final _decisionStatuses = <String>{};
  final _continuityStatuses = <String>{};
  final _blockerCodes = <String>{};
  final _choicesByKey = <String, _AcceptedChoice>{};
  var _acceptedChoiceCount = 0;
  String? _compatibilityKey;
  String? _primaryCapabilityId;
  String? _agentKind;

  void addDecision(_SourceLedger source, Map<String, dynamic> decision) {
    _sourceLedgerRefs.add(source.ledgerRef);
    _decisionStatuses.add(_string(decision['status']));
    _blockerCodes.addAll(_stringList(decision['blockerCodes']));
    _compatibilityKey ??= _string(decision['compatibilityKey']);
    _primaryCapabilityId ??= _string(decision['primaryCapabilityId']);
    _agentKind ??= _string(decision['agentKind']);
    if (_string(decision['status']) != 'accepted') return;
    final candidate = _map(decision['acceptedCandidate']);
    final choice = _AcceptedChoice.fromCandidate(source, candidate);
    _acceptedChoiceCount += 1;
    _choicesByKey.update(
      choice.key,
      (existing) => existing.withSource(source),
      ifAbsent: () => choice,
    );
  }

  void addContinuity(_SourceLedger source, Map<String, dynamic> entry) {
    _sourceLedgerRefs.add(source.ledgerRef);
    final status = _string(entry['status']);
    _continuityStatuses.add(status);
    _blockerCodes.addAll(_stringList(entry['blockerCodes']));
    if (status == 'rollbackRequired') {
      _blockerCodes.add('roadmap.rollbackRequired');
    }
    if (status == 'revalidateRequired') {
      _blockerCodes.add('roadmap.revalidateRequired');
    }
  }

  _ScopeState build() {
    final choices = _choicesByKey.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final status = _scopeStatus(choices);
    final blockers = _sortedStrings({
      ..._blockerCodes,
      if (choices.length > 1) 'roadmap.multipleAcceptedChoices',
      if (choices.length == 1 &&
          _decisionStatuses.any((status) => status != 'accepted'))
        'roadmap.acceptedChoiceHasContestedEvidence',
    });
    return _ScopeState(
      scopeKey: scopeKey,
      compatibilityKey: _compatibilityKey,
      primaryCapabilityId: _primaryCapabilityId,
      agentKind: _agentKind,
      status: status,
      sourceLedgerRefs: _sortedStrings(_sourceLedgerRefs),
      decisionStatuses: _sortedStrings(
        _decisionStatuses.where((status) => status.isNotEmpty),
      ),
      continuityStatuses: _sortedStrings(
        _continuityStatuses.where((status) => status.isNotEmpty),
      ),
      acceptedChoiceCount: _acceptedChoiceCount,
      choices: choices,
      blockerCodes: blockers,
      nextAction: _nextAction(status),
    );
  }

  String _scopeStatus(List<_AcceptedChoice> choices) {
    if (_continuityStatuses.contains('rollbackRequired')) {
      return 'rollbackRequired';
    }
    if (choices.length > 1 || _decisionStatuses.contains('conflict')) {
      return 'conflict';
    }
    if (_continuityStatuses.contains('revalidateRequired')) {
      return 'revalidateRequired';
    }
    if (choices.length == 1) {
      if (_decisionStatuses.any((status) => status != 'accepted')) {
        return 'revalidateRequired';
      }
      return 'accepted';
    }
    if (_decisionStatuses.isNotEmpty &&
        _decisionStatuses.every((status) => status == 'watch')) {
      return 'watch';
    }
    return 'blocked';
  }

  String _nextAction(String status) => switch (status) {
    'accepted' => 'keepAcceptedUseCaseChoiceUnderReleaseReview',
    'conflict' => 'resolveCrossLedgerAcceptedChoiceConflict',
    'rollbackRequired' => 'rollBackPreviouslyAcceptedUseCaseChoice',
    'revalidateRequired' => 'refreshDecisionLedgerEvidence',
    'watch' => 'collectPromotionEvidenceBeforeRoadmapAcceptance',
    _ => 'continueDecisionGateEvidenceCollection',
  };
}

final class _ScopeState {
  const _ScopeState({
    required this.scopeKey,
    required this.compatibilityKey,
    required this.primaryCapabilityId,
    required this.agentKind,
    required this.status,
    required this.sourceLedgerRefs,
    required this.decisionStatuses,
    required this.continuityStatuses,
    required this.acceptedChoiceCount,
    required this.choices,
    required this.blockerCodes,
    required this.nextAction,
  });

  final String scopeKey;
  final String? compatibilityKey;
  final String? primaryCapabilityId;
  final String? agentKind;
  final String status;
  final List<String> sourceLedgerRefs;
  final List<String> decisionStatuses;
  final List<String> continuityStatuses;
  final int acceptedChoiceCount;
  final List<_AcceptedChoice> choices;
  final List<String> blockerCodes;
  final String nextAction;

  int get uniqueAcceptedChoiceCount => choices.length;

  Map<String, dynamic> toJson() {
    final metadataAvailable =
        _string(compatibilityKey).isNotEmpty &&
        _string(primaryCapabilityId).isNotEmpty &&
        _string(agentKind).isNotEmpty;
    return <String, dynamic>{
      'scopeKey': scopeKey,
      'scopeMetadataAvailable': metadataAvailable,
      if (metadataAvailable) ...<String, dynamic>{
        'compatibilityKey': compatibilityKey,
        'primaryCapabilityId': primaryCapabilityId,
        'agentKind': agentKind,
      },
      'status': status,
      'sourceLedgerRefs': sourceLedgerRefs,
      'decisionStatuses': decisionStatuses,
      'continuityStatuses': continuityStatuses,
      'acceptedChoiceCount': acceptedChoiceCount,
      'uniqueAcceptedChoiceCount': uniqueAcceptedChoiceCount,
      'acceptedChoices': [
        for (final choice in choices) choice.toJson(),
      ],
      'blockerCodes': blockerCodes,
      'nextAction': nextAction,
    };
  }
}

final class _AcceptedChoice {
  const _AcceptedChoice({
    required this.acceptedCellKey,
    required this.reportDigest,
    required this.modelClassCoverageProofRef,
    required this.workOrderBatchRef,
    required this.modelClassCoverageRef,
    required this.modelClassCoverageClassRef,
    required this.modelClassCoverageDigest,
    required this.sourceWorkOrderDigest,
    required this.modelClass,
    required this.promptVariantName,
    required this.sourceLedgerRefs,
  });

  factory _AcceptedChoice.fromCandidate(
    _SourceLedger source,
    Map<String, dynamic> candidate,
  ) {
    final proof = _map(candidate['modelClassCoverageProof']);
    return _AcceptedChoice(
      acceptedCellKey: _string(candidate['cellKey']),
      reportDigest: _string(candidate['reportDigest']),
      modelClassCoverageProofRef: _string(proof['proofRef']),
      workOrderBatchRef: _string(proof['workOrderBatchRef']),
      modelClassCoverageRef: _string(proof['modelClassCoverageRef']),
      modelClassCoverageClassRef: _string(
        proof['modelClassCoverageClassRef'],
      ),
      modelClassCoverageDigest: _string(proof['modelClassCoverageDigest']),
      sourceWorkOrderDigest: _string(proof['sourceWorkOrderDigest']),
      modelClass: _string(candidate['modelClass']),
      promptVariantName: _string(candidate['promptVariantName']),
      sourceLedgerRefs: [source.ledgerRef],
    );
  }

  final String acceptedCellKey;
  final String reportDigest;
  final String modelClassCoverageProofRef;
  final String workOrderBatchRef;
  final String modelClassCoverageRef;
  final String modelClassCoverageClassRef;
  final String modelClassCoverageDigest;
  final String sourceWorkOrderDigest;
  final String modelClass;
  final String promptVariantName;
  final List<String> sourceLedgerRefs;

  String get key => [
    acceptedCellKey,
    reportDigest,
    modelClassCoverageProofRef,
    workOrderBatchRef,
    modelClassCoverageRef,
    modelClassCoverageClassRef,
    modelClassCoverageDigest,
    sourceWorkOrderDigest,
    modelClass,
    promptVariantName,
  ].join(':');

  _AcceptedChoice withSource(_SourceLedger source) {
    return _AcceptedChoice(
      acceptedCellKey: acceptedCellKey,
      reportDigest: reportDigest,
      modelClassCoverageProofRef: modelClassCoverageProofRef,
      workOrderBatchRef: workOrderBatchRef,
      modelClassCoverageRef: modelClassCoverageRef,
      modelClassCoverageClassRef: modelClassCoverageClassRef,
      modelClassCoverageDigest: modelClassCoverageDigest,
      sourceWorkOrderDigest: sourceWorkOrderDigest,
      modelClass: modelClass,
      promptVariantName: promptVariantName,
      sourceLedgerRefs: _sortedStrings({...sourceLedgerRefs, source.ledgerRef}),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'acceptedCellKey': acceptedCellKey,
    'reportDigest': reportDigest,
    'modelClassCoverageProofRef': modelClassCoverageProofRef,
    'workOrderBatchRef': workOrderBatchRef,
    'modelClassCoverageRef': modelClassCoverageRef,
    'modelClassCoverageClassRef': modelClassCoverageClassRef,
    'modelClassCoverageDigest': modelClassCoverageDigest,
    'sourceWorkOrderDigest': sourceWorkOrderDigest,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
    'sourceLedgerRefs': sourceLedgerRefs,
  };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map<String, dynamic>) item,
      ]
    : const <Map<String, dynamic>>[];

List<String> _stringList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const <String>[];

String _string(Object? value) => value is String ? value : '';

List<String> _sortedStrings(Iterable<String> values) =>
    values.where((value) => value.isNotEmpty).toSet().toList()..sort();
