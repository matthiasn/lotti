import 'eval_provenance.dart';
import 'eval_tuning_report_contract.dart';

abstract final class EvalTuningEvidenceIntakePlan {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalTuningEvidenceIntakePlan';
  static const _allowedStatuses = {
    'invalid',
    'noReports',
    'readyForEvidenceCollection',
    'noActionableGaps',
  };
  static const _allowedTaskTypes = {
    'calibration',
    'protectedHoldout',
    'scenarioReview',
    'pairwiseReview',
    'verdictGrading',
    'coverageExpansion',
    'evidenceCollection',
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
  static final _dangerousCommandTokenPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:bash\s+-lc|fvm\s+flutter|'
    r'fvm\s+dart|dart\s+run|sqlite3)(?=$|[^A-Za-z0-9_-])',
  );
  static final _safeTokenPattern = RegExp(r'^[A-Za-z0-9._:@+-]{1,96}$');

  static Map<String, dynamic> build({
    required List<Map<String, dynamic>> reports,
    DateTime? generatedAt,
    int maxTasks = 48,
  }) {
    final sourceReports = [
      for (final indexed in reports.indexed)
        _SourceTuningReport.fromReport(
          index: indexed.$1,
          report: indexed.$2,
        ),
    ];
    final validReports = [
      for (final source in sourceReports)
        if (source.valid) source,
    ];
    final tasks = sourceReports.any((source) => !source.valid)
        ? const <Map<String, dynamic>>[]
        : _tasks(validReports).take(maxTasks < 0 ? 0 : maxTasks).toList();
    final status = sourceReports.any((source) => !source.valid)
        ? 'invalid'
        : reports.isEmpty
        ? 'noReports'
        : tasks.isNotEmpty
        ? 'readyForEvidenceCollection'
        : 'noActionableGaps';
    final plan = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'summary': <String, dynamic>{
        'inputReportCount': sourceReports.length,
        'validReportCount': validReports.length,
        'invalidReportCount': sourceReports.length - validReports.length,
        'taskCount': tasks.length,
        'calibrationTaskCount': _taskTypeCount(tasks, 'calibration'),
        'protectedHoldoutTaskCount': _taskTypeCount(tasks, 'protectedHoldout'),
        'scenarioReviewTaskCount': _taskTypeCount(tasks, 'scenarioReview'),
        'pairwiseReviewTaskCount': _taskTypeCount(tasks, 'pairwiseReview'),
        'verdictGradingTaskCount': _taskTypeCount(tasks, 'verdictGrading'),
        'coverageExpansionTaskCount': _taskTypeCount(
          tasks,
          'coverageExpansion',
        ),
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'rawRunIdsOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'rawLabelsOmitted': true,
        'protectedCatalogRowsOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesTuningReportsOnly': true,
        'humanLabelsCreated': false,
        'protectedHoldoutDataCreated': false,
        'scenarioReviewsCreated': false,
        'liveCommandsCreated': false,
        'promotionClaimsCreated': false,
      },
      'sourceReports': [
        for (final source in sourceReports) source.toJson(),
      ],
      'tasks': tasks,
      'recommendedCommands': _recommendedCommands(status),
    };
    assertValid(plan);
    return plan;
  }

  static List<String> validate(Map<String, dynamic> plan) {
    final issues = <String>[];
    _expectEquals(
      issues,
      plan['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, plan['kind'], kind, 'kind');
    _expectIsoDate(issues, plan['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, plan['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final summary = _expectMap(issues, plan['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(issues, _expectMap(issues, plan['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, plan['limitations'], 'limitations'),
    );
    final sourceReports = _expectList(
      issues,
      plan['sourceReports'],
      'sourceReports',
    );
    _validateSourceReports(issues, sourceReports);
    final tasks = _expectList(issues, plan['tasks'], 'tasks');
    _validateTasks(issues, tasks);
    final commands = _expectList(
      issues,
      plan['recommendedCommands'],
      'recommendedCommands',
    );
    _validateCommands(issues, commands, 'recommendedCommands');
    _validateSummaryInvariants(
      issues,
      summary: summary,
      sourceReports: sourceReports,
      tasks: tasks,
    );
    _validateNoPrivatePayloads(issues, plan, 'evidenceIntakePlan');
    return issues;
  }

  static void assertValid(Map<String, dynamic> plan) {
    final issues = validate(plan);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid tuning evidence intake plan:\n${issues.join('\n')}',
    );
  }

  static List<Map<String, dynamic>> _tasks(
    List<_SourceTuningReport> sources,
  ) {
    final builders = <String, _EvidenceTaskBuilder>{};
    for (final source in sources) {
      final privateValues = _privateStringValues(source.report);
      for (final blockerCode in source.blockerCodes) {
        final safeCode = _sanitizeBlockerCode(blockerCode, privateValues);
        final matchingSlices = source.slicesForBlocker(blockerCode);
        final scopes = matchingSlices.isEmpty
            ? const [<String, dynamic>{}]
            : matchingSlices;
        for (final scope in scopes) {
          final type = _taskType(blockerCode);
          final taskKey = EvalProvenance.digestJson(<String, dynamic>{
            'type': type,
            'scope': _taskScope(scope),
            'blockerCode': safeCode,
          });
          builders
              .putIfAbsent(
                taskKey,
                () => _EvidenceTaskBuilder(
                  taskRef: taskKey,
                  taskType: type,
                  scope: _taskScope(scope),
                ),
              )
              .add(source, safeCode);
        }
      }
    }
    final tasks =
        [
          for (final builder in builders.values) builder.toJson(),
        ]..sort(
          (a, b) =>
              _priority(a['taskType'] as String).compareTo(
                    _priority(b['taskType'] as String),
                  ) ==
                  0
              ? _string(a['taskRef']).compareTo(_string(b['taskRef']))
              : _priority(
                  a['taskType'] as String,
                ).compareTo(_priority(b['taskType'] as String)),
        );
    return tasks;
  }

  static Map<String, dynamic> _taskScope(Map<String, dynamic> slice) {
    final scope = <String, dynamic>{};
    void addSafe(String key, Object? value) {
      final safe = _safeToken(_string(value));
      if (safe != null) scope[key] = safe;
    }

    addSafe('primaryCapabilityId', slice['primaryCapabilityId']);
    addSafe('agentKind', slice['agentKind']);
    addSafe('modelClass', slice['modelClass']);
    addSafe('promptVariantName', slice['promptVariantName']);
    return scope;
  }

  static String _taskType(String blockerCode) {
    final normalized = blockerCode.toLowerCase();
    if (normalized.contains('calibration') || normalized.contains('human')) {
      return 'calibration';
    }
    if (normalized.contains('protected') ||
        normalized.contains('holdout') ||
        normalized.contains('catalog') ||
        normalized.contains('productionreplay') ||
        normalized.contains('production-replay')) {
      return 'protectedHoldout';
    }
    if (normalized.contains('review') ||
        normalized.contains('adversarial') ||
        normalized.contains('synthetic') ||
        normalized.contains('sourcedigest')) {
      return 'scenarioReview';
    }
    if (normalized.contains('pairwise')) return 'pairwiseReview';
    if (normalized.contains('verdict') || normalized.contains('judge')) {
      return 'verdictGrading';
    }
    if (normalized.contains('coverage') ||
        normalized.contains('capability') ||
        normalized.contains('scenario') ||
        normalized.contains('trial')) {
      return 'coverageExpansion';
    }
    return 'evidenceCollection';
  }

  static String _actionForTaskType(String taskType) => switch (taskType) {
    'calibration' => 'completeHumanCalibrationLabelsAndRecalibrate',
    'protectedHoldout' => 'curateProtectedProductionReplayHoldoutCatalog',
    'scenarioReview' => 'completeScenarioReviewMetadata',
    'pairwiseReview' => 'completeBlindedPairwiseReviewImport',
    'verdictGrading' => 'gradeMissingOrStaleVerdicts',
    'coverageExpansion' => 'addCapabilityModelPromptCoverage',
    _ => 'collectMissingTuningEvidence',
  };

  static int _priority(String taskType) => switch (taskType) {
    'protectedHoldout' => 1,
    'calibration' => 1,
    'scenarioReview' => 1,
    'pairwiseReview' => 2,
    'verdictGrading' => 2,
    'coverageExpansion' => 3,
    _ => 4,
  };

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final commands = status == 'readyForEvidenceCollection'
        ? const [
            ('template', 'eval/run_level2.sh template <runId>'),
            ('calibrate', 'eval/run_level2.sh calibrate <runId>'),
            ('catalog', 'eval/run_level2.sh catalog'),
            ('report', 'eval/run_level2.sh report <runId>'),
            ('evidence-intake', 'eval/run_level2.sh evidence-intake'),
            ('use-case-matrix', 'eval/run_level2.sh use-case-matrix'),
          ]
        : const [
            ('report', 'eval/run_level2.sh report <runId>'),
            ('evidence-intake', 'eval/run_level2.sh evidence-intake'),
          ];
    return [
      for (final command in commands)
        <String, dynamic>{
          'mode': command.$1,
          'command': command.$2,
        },
    ];
  }

  static int _taskTypeCount(List<Map<String, dynamic>> tasks, String type) =>
      tasks.where((task) => task['taskType'] == type).length;

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'inputReportCount',
      'validReportCount',
      'invalidReportCount',
      'taskCount',
      'calibrationTaskCount',
      'protectedHoldoutTaskCount',
      'scenarioReviewTaskCount',
      'pairwiseReviewTaskCount',
      'verdictGradingTaskCount',
      'coverageExpansionTaskCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validatePrivacy(
    List<String> issues,
    Map<String, dynamic>? value,
  ) {
    if (value == null) return;
    const expected = {
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'rawRunIdsOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
      'rawLabelsOmitted': true,
      'protectedCatalogRowsOmitted': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        value[entry.key],
        entry.value,
        'privacy.${entry.key}',
      );
    }
  }

  static void _validateLimitations(
    List<String> issues,
    Map<String, dynamic>? value,
  ) {
    if (value == null) return;
    const expected = {
      'consumesTuningReportsOnly': true,
      'humanLabelsCreated': false,
      'protectedHoldoutDataCreated': false,
      'scenarioReviewsCreated': false,
      'liveCommandsCreated': false,
      'promotionClaimsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        value[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
  }

  static void _validateSourceReports(List<String> issues, List<dynamic>? rows) {
    if (rows == null) return;
    for (final (index, value) in rows.indexed) {
      final row = _expectMap(issues, value, 'sourceReports[$index]');
      if (row == null) continue;
      _expectNonEmptyString(
        issues,
        row['reportRef'],
        'sourceReports[$index].reportRef',
      );
      _expectNonEmptyString(
        issues,
        row['contractStatus'],
        'sourceReports[$index].contractStatus',
      );
      for (final field in const [
        'reportDigest',
        'runRefDigest',
        'manifestDigest',
        'scenarioSetDigest',
        'profileSetDigest',
        'policyDigest',
      ]) {
        _expectDigest(issues, row[field], 'sourceReports[$index].$field');
      }
      for (final field in const [
        'contractIssueCount',
        'blockedReasonCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          row[field],
          'sourceReports[$index].$field',
        );
      }
      _expectBool(
        issues,
        row['protectedIdsRedacted'],
        'sourceReports[$index].protectedIdsRedacted',
      );
      _expectStringList(
        issues,
        row['blockedReasonCodes'],
        'sourceReports[$index].blockedReasonCodes',
      );
    }
  }

  static void _validateTasks(List<String> issues, List<dynamic>? tasks) {
    if (tasks == null) return;
    for (final (index, value) in tasks.indexed) {
      final task = _expectMap(issues, value, 'tasks[$index]');
      if (task == null) continue;
      _expectDigest(issues, task['taskRef'], 'tasks[$index].taskRef');
      final taskType = _expectNonEmptyString(
        issues,
        task['taskType'],
        'tasks[$index].taskType',
      );
      if (taskType != null && !_allowedTaskTypes.contains(taskType)) {
        issues.add('tasks[$index].taskType must be supported');
      }
      _expectNonNegativeInt(issues, task['priority'], 'tasks[$index].priority');
      _expectNonEmptyString(issues, task['status'], 'tasks[$index].status');
      _expectNonEmptyString(issues, task['action'], 'tasks[$index].action');
      _validateScope(
        issues,
        _expectMap(issues, task['scope'], 'tasks[$index].scope'),
        'tasks[$index].scope',
      );
      _expectStringList(
        issues,
        task['sourceReportRefs'],
        'tasks[$index].sourceReportRefs',
      );
      _expectStringList(
        issues,
        task['blockerCodes'],
        'tasks[$index].blockerCodes',
      );
      _expectStringList(
        issues,
        task['manualSteps'],
        'tasks[$index].manualSteps',
      );
    }
  }

  static void _validateScope(
    List<String> issues,
    Map<String, dynamic>? scope,
    String path,
  ) {
    if (scope == null) return;
    for (final field in const [
      'primaryCapabilityId',
      'agentKind',
      'modelClass',
      'promptVariantName',
    ]) {
      if (!scope.containsKey(field)) continue;
      final value = _expectNonEmptyString(issues, scope[field], '$path.$field');
      if (value != null && !_safeTokenPattern.hasMatch(value)) {
        issues.add('$path.$field must be a safe public token');
      }
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
      if (text != null && _dangerousCommandTokenPattern.hasMatch(text)) {
        issues.add('$path[$index].command must not contain mutation commands');
      }
      if (command.containsKey('env')) {
        issues.add('$path[$index] must not contain env values');
      }
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? sourceReports,
    required List<dynamic>? tasks,
  }) {
    if (summary == null) return;
    if (sourceReports != null &&
        summary['inputReportCount'] is int &&
        summary['inputReportCount'] != sourceReports.length) {
      issues.add('summary.inputReportCount must match sourceReports.length');
    }
    if (sourceReports != null && summary['validReportCount'] is int) {
      final valid = sourceReports.where((source) {
        return source is Map && source['contractStatus'] == 'valid';
      }).length;
      if (summary['validReportCount'] != valid) {
        issues.add('summary.validReportCount must match valid source reports');
      }
    }
    if (sourceReports != null && summary['invalidReportCount'] is int) {
      final invalid = sourceReports.where((source) {
        return source is Map && source['contractStatus'] != 'valid';
      }).length;
      if (summary['invalidReportCount'] != invalid) {
        issues.add(
          'summary.invalidReportCount must match invalid source reports',
        );
      }
    }
    if (tasks != null &&
        summary['taskCount'] is int &&
        summary['taskCount'] != tasks.length) {
      issues.add('summary.taskCount must match tasks.length');
    }
    if (tasks == null) return;
    const typedCountFields = {
      'calibrationTaskCount': 'calibration',
      'protectedHoldoutTaskCount': 'protectedHoldout',
      'scenarioReviewTaskCount': 'scenarioReview',
      'pairwiseReviewTaskCount': 'pairwiseReview',
      'verdictGradingTaskCount': 'verdictGrading',
      'coverageExpansionTaskCount': 'coverageExpansion',
    };
    for (final entry in typedCountFields.entries) {
      if (summary[entry.key] is! int) continue;
      final actual = tasks.where((task) {
        return task is Map && task['taskType'] == entry.value;
      }).length;
      if (summary[entry.key] != actual) {
        issues.add('summary.${entry.key} must match ${entry.value} tasks');
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
        if (_privateFieldReason(key.toLowerCase()) case final reason?) {
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
      if (_scenarioFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain scenario id field names');
      }
      if (_profileFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain profile selector field names');
      }
      if (_liveRunLevel2CommandPattern.hasMatch(value)) {
        issues.add('$path must not contain live run commands');
      }
      if (_dangerousCommandTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain mutation commands');
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
    if (normalized == 'profileid' ||
        normalized == 'agentid' ||
        normalized == 'templateid' ||
        normalized == 'providerid' ||
        normalized.endsWith('configid')) {
      return 'private runtime ids';
    }
    return null;
  }

  static Set<String> _privateStringValues(Object? value) {
    final values = <String>{};

    void collect(Object? node) {
      if (node is String && node.trim().length >= 3) {
        values.add(node.trim());
      } else if (node is List) {
        node.forEach(collect);
      } else if (node is Map) {
        node.values.forEach(collect);
      }
    }

    void visit(Object? node) {
      if (node is List) {
        node.forEach(visit);
        return;
      }
      if (node is! Map) return;
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_privateFieldReason(key) != null) collect(entry.value);
        visit(entry.value);
      }
    }

    visit(value);
    return values;
  }

  static String _sanitizeBlockerCode(String code, Set<String> privateValues) {
    if (_containsPrivatePayload(code, privateValues)) {
      return 'protected-blocker.${EvalProvenance.digestText(code)}';
    }
    return code;
  }

  static bool _containsPrivatePayload(String value, Set<String> privateValues) {
    if (_privatePathPattern.hasMatch(value) ||
        _privateEnvTokenPattern.hasMatch(value) ||
        _scenarioFieldTokenPattern.hasMatch(value) ||
        _profileFieldTokenPattern.hasMatch(value) ||
        value.contains('<redacted-scenario')) {
      return true;
    }
    return privateValues.any(value.contains);
  }

  static String? _safeToken(String value) {
    if (value.isEmpty || !_safeTokenPattern.hasMatch(value)) return null;
    return value;
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is Map<String, dynamic>) item,
        ]
      : const <Map<String, dynamic>>[];

  static List<String> _stringList(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is String && item.isNotEmpty) item,
        ]
      : const <String>[];

  static List<String> _sortedStrings(Iterable<String> values) =>
      values.where((value) => value.isNotEmpty).toSet().toList()..sort();

  static String _string(Object? value) => value is String ? value : '';

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
      if (item is! String || item.isEmpty) {
        issues.add('$path[$index] must be a non-empty string');
      }
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
    if (value is String && EvalProvenance.isDigest(value)) return;
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

final class _SourceTuningReport {
  _SourceTuningReport({
    required this.index,
    required this.report,
    required this.reportDigest,
    required this.contractIssues,
  });

  factory _SourceTuningReport.fromReport({
    required int index,
    required Map<String, dynamic> report,
  }) {
    return _SourceTuningReport(
      index: index,
      report: report,
      reportDigest: EvalProvenance.digestJson(report),
      contractIssues: EvalTuningReportContract.validate(report),
    );
  }

  final int index;
  final Map<String, dynamic> report;
  final String reportDigest;
  final List<String> contractIssues;

  bool get valid => contractIssues.isEmpty;

  String get reportRef => 'report-${(index + 1).toString().padLeft(4, '0')}';

  List<String> get blockerCodes {
    return EvalTuningEvidenceIntakePlan._sortedStrings({
      for (final failure in EvalTuningEvidenceIntakePlan._stringList(
        EvalTuningEvidenceIntakePlan._map(report['readiness'])['failures'],
      ))
        failure,
      for (final blockedReason in EvalTuningEvidenceIntakePlan._mapList(
        report['blockedReasons'],
      ))
        EvalTuningEvidenceIntakePlan._string(blockedReason['code']),
      ...EvalTuningEvidenceIntakePlan._stringList(
        EvalTuningEvidenceIntakePlan._map(
          report['nextExperimentPlan'],
        )['blockedReasonCodes'],
      ),
      for (final slice in EvalTuningEvidenceIntakePlan._mapList(
        report['useCaseModelSlices'],
      ))
        ...EvalTuningEvidenceIntakePlan._stringList(slice['blockingReasons']),
    });
  }

  List<Map<String, dynamic>> slicesForBlocker(String blockerCode) {
    return [
      for (final slice in EvalTuningEvidenceIntakePlan._mapList(
        report['useCaseModelSlices'],
      ))
        if (EvalTuningEvidenceIntakePlan._stringList(
          slice['blockingReasons'],
        ).contains(blockerCode))
          slice,
    ];
  }

  Map<String, dynamic> toJson() {
    final run = EvalTuningEvidenceIntakePlan._map(report['run']);
    final status = EvalTuningEvidenceIntakePlan._map(report['status']);
    final readiness = EvalTuningEvidenceIntakePlan._map(report['readiness']);
    final calibration = EvalTuningEvidenceIntakePlan._map(
      report['calibration'],
    );
    final pairwise = EvalTuningEvidenceIntakePlan._map(report['pairwise']);
    final privateValues = EvalTuningEvidenceIntakePlan._privateStringValues(
      report,
    );
    final safeBlockers = EvalTuningEvidenceIntakePlan._sortedStrings(
      blockerCodes.map(
        (code) => EvalTuningEvidenceIntakePlan._sanitizeBlockerCode(
          code,
          privateValues,
        ),
      ),
    );
    return <String, dynamic>{
      'reportRef': reportRef,
      'contractStatus': valid ? 'valid' : 'invalid',
      'contractIssueCount': contractIssues.length,
      'reportDigest': reportDigest,
      'runRefDigest': EvalProvenance.digestText(
        EvalTuningEvidenceIntakePlan._string(run['runId']).isEmpty
            ? 'missing-run-$index'
            : EvalTuningEvidenceIntakePlan._string(run['runId']),
      ),
      'manifestDigest': _digestOrSelf(run['manifestDigest'], 'manifest-$index'),
      'scenarioSetDigest': _digestOrSelf(
        run['scenarioSetDigest'],
        'scenario-set-$index',
      ),
      'profileSetDigest': _digestOrSelf(
        run['profileSetDigest'],
        'profile-set-$index',
      ),
      'policyDigest': _digestOrSelf(
        EvalTuningEvidenceIntakePlan._map(report['policy'])['digest'],
        'policy-$index',
      ),
      'ready': status['ready'] == true,
      'label': EvalTuningEvidenceIntakePlan._string(status['label']).isEmpty
          ? 'unknown'
          : EvalTuningEvidenceIntakePlan._string(status['label']),
      'calibrationPresent': calibration['present'] == true,
      'pairwisePresent': pairwise['present'] == true,
      'protectedIdsRedacted': run['protectedIdsRedacted'] == true,
      'blockedReasonCount': safeBlockers.length,
      'blockedReasonCodes': safeBlockers,
      'readinessFailureCount': EvalTuningEvidenceIntakePlan._stringList(
        readiness['failures'],
      ).length,
    };
  }

  static String _digestOrSelf(Object? value, String fallback) {
    if (value is String && EvalProvenance.isDigest(value)) return value;
    return EvalProvenance.digestText(fallback);
  }
}

final class _EvidenceTaskBuilder {
  _EvidenceTaskBuilder({
    required this.taskRef,
    required this.taskType,
    required this.scope,
  });

  final String taskRef;
  final String taskType;
  final Map<String, dynamic> scope;
  final Set<String> sourceReportRefs = <String>{};
  final Set<String> blockerCodes = <String>{};

  void add(_SourceTuningReport source, String blockerCode) {
    sourceReportRefs.add(source.reportRef);
    blockerCodes.add(blockerCode);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'taskRef': taskRef,
    'taskType': taskType,
    'priority': EvalTuningEvidenceIntakePlan._priority(taskType),
    'status': 'pendingManualEvidence',
    'action': EvalTuningEvidenceIntakePlan._actionForTaskType(taskType),
    'scope': scope,
    'sourceReportRefs': EvalTuningEvidenceIntakePlan._sortedStrings(
      sourceReportRefs,
    ),
    'blockerCodes': EvalTuningEvidenceIntakePlan._sortedStrings(blockerCodes),
    'manualSteps': _manualSteps(taskType),
  };

  static List<String> _manualSteps(String taskType) => switch (taskType) {
    'calibration' => const [
      'generate a calibration template for the source run',
      'complete blinded human labels outside the harness',
      'run calibration and regenerate the tuning report',
    ],
    'protectedHoldout' => const [
      'curate protected production-replay holdout scenarios outside the repo',
      'run catalog preflight with protected holdout evidence',
      'rerun report with protected catalog evidence attached',
    ],
    'scenarioReview' => const [
      'complete scenario review metadata with current subject digests',
      'regenerate catalog preflight and report after review updates',
    ],
    'pairwiseReview' => const [
      'complete blinded pairwise review import',
      'rerun report so pairwise readiness evidence is current',
    ],
    'verdictGrading' => const [
      'grade missing or stale verdicts',
      'rerun report so judge evidence is current',
    ],
    'coverageExpansion' => const [
      'add coverage for the public capability/model/prompt scope',
      'rerun the matrix and report after coverage is collected',
    ],
    _ => const [
      'collect the missing tuning evidence for the public scope',
      'regenerate the tuning report after evidence changes',
    ],
  };
}
