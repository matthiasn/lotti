// Data models for the tiered agent evaluation harness (ADR 0029).
//
// These are plain, JSON-serialisable value objects with NO dependency on the
// app's entity types, so the eval dataset is easy to author, diff, and review.
// Adapters map a scenario onto the real seeding factories at execution time
// (Phase 1); the scenario itself stays decoupled. Token accounting reuses the
// production `InferenceUsage` type verbatim so Level 2 numbers match what
// `WakeTokenUsageEntity` records in the app.
//
// See docs/adr/0029-agent-evaluation-harness.md.

import 'package:lotti/features/ai/model/inference_usage.dart';

/// Parses a nullable ISO-8601 date string.
DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// Which agent a scenario targets.
enum AgentKind {
  taskAgent,
  planningAgent;

  static AgentKind fromName(String name) =>
      AgentKind.values.firstWhere((k) => k.name == name);
}

/// Coarse model capability class used for tuning and reporting.
enum EvalModelClass {
  localSmall,
  localReasoning,
  frontierFast,
  frontierReasoning;

  static EvalModelClass fromName(String name) =>
      EvalModelClass.values.firstWhere((c) => c.name == name);
}

/// The simulated user input that drives a wake.
///
/// For the planner this is the capture transcript ("Here is what I want to
/// achieve today…") plus the trigger tokens that woke the agent
/// (`drafting:<dayId>`, `capture_submitted:<captureId>`, `refine:<dayId>`).
class UserInput {
  const UserInput({
    required this.transcript,
    this.triggerTokens = const <String>{},
  });

  factory UserInput.fromJson(Map<String, dynamic> json) => UserInput(
    transcript: json['transcript'] as String,
    triggerTokens: ((json['triggerTokens'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toSet(),
  );

  final String transcript;
  final Set<String> triggerTokens;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transcript': transcript,
    'triggerTokens': triggerTokens.toList(),
  };
}

/// A checklist item on a mocked task.
class MockChecklistItem {
  const MockChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
  });

  factory MockChecklistItem.fromJson(Map<String, dynamic> json) =>
      MockChecklistItem(
        id: json['id'] as String,
        title: json['title'] as String,
        isChecked: (json['isChecked'] as bool?) ?? false,
      );

  final String id;
  final String title;
  final bool isChecked;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'isChecked': isChecked,
  };
}

/// A mocked task in the app state. `status` mirrors the real journal task
/// status strings (e.g. `OPEN`, `IN PROGRESS`, `GROOMED`, `BLOCKED`, `ON HOLD`,
/// `DONE`, `REJECTED`).
class MockTask {
  const MockTask({
    required this.id,
    required this.title,
    required this.status,
    this.due,
    this.estimateMinutes,
    this.categoryId,
    this.checklist = const <MockChecklistItem>[],
  });

  factory MockTask.fromJson(Map<String, dynamic> json) => MockTask(
    id: json['id'] as String,
    title: json['title'] as String,
    status: json['status'] as String,
    due: _parseDate(json['due']),
    estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
    categoryId: json['categoryId'] as String?,
    checklist: ((json['checklist'] as List<dynamic>?) ?? const [])
        .map((e) => MockChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String title;
  final String status;
  final DateTime? due;
  final int? estimateMinutes;
  final String? categoryId;
  final List<MockChecklistItem> checklist;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'status': status,
    if (due != null) 'due': due!.toIso8601String(),
    if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
    if (categoryId != null) 'categoryId': categoryId,
    'checklist': checklist.map((c) => c.toJson()).toList(),
  };
}

/// A block already present on the day's plan (the planner refines around these).
class MockDayBlock {
  const MockDayBlock({
    required this.id,
    required this.categoryId,
    required this.start,
    required this.end,
    this.taskId,
  });

  factory MockDayBlock.fromJson(Map<String, dynamic> json) => MockDayBlock(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    taskId: json['taskId'] as String?,
  );

  final String id;
  final String categoryId;
  final DateTime start;
  final DateTime end;
  final String? taskId;

  int get durationMinutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (taskId != null) 'taskId': taskId,
  };
}

/// The mocked state of the app a scenario presents to the agent.
class MockedAppState {
  const MockedAppState({
    required this.now,
    this.tasks = const <MockTask>[],
    this.existingBlocks = const <MockDayBlock>[],
    this.capacityMinutes = 480,
    this.categoryIds = const <String>[],
  });

  factory MockedAppState.fromJson(Map<String, dynamic> json) => MockedAppState(
    now: DateTime.parse(json['now'] as String),
    tasks: ((json['tasks'] as List<dynamic>?) ?? const [])
        .map((e) => MockTask.fromJson(e as Map<String, dynamic>))
        .toList(),
    existingBlocks: ((json['existingBlocks'] as List<dynamic>?) ?? const [])
        .map((e) => MockDayBlock.fromJson(e as Map<String, dynamic>))
        .toList(),
    capacityMinutes: (json['capacityMinutes'] as num?)?.toInt() ?? 480,
    categoryIds: ((json['categoryIds'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );

  final DateTime now;
  final List<MockTask> tasks;
  final List<MockDayBlock> existingBlocks;
  final int capacityMinutes;
  final List<String> categoryIds;

  /// All task IDs known to the scenario — used to detect hallucinated refs.
  Set<String> get knownTaskIds => tasks.map((t) => t.id).toSet();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'now': now.toIso8601String(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'existingBlocks': existingBlocks.map((b) => b.toJson()).toList(),
    'capacityMinutes': capacityMinutes,
    'categoryIds': categoryIds,
  };
}

/// Optional hard gates a scenario can assert at Level 1, independent of the
/// model's behaviour.
class EvalExpectations {
  const EvalExpectations({
    this.maxTokenBudget,
    this.maxToolCalls,
    this.mustCallTools = const <String>{},
    this.mustNotCallTools = const <String>{},
  });

  factory EvalExpectations.fromJson(Map<String, dynamic> json) =>
      EvalExpectations(
        maxTokenBudget: (json['maxTokenBudget'] as num?)?.toInt(),
        maxToolCalls: (json['maxToolCalls'] as num?)?.toInt(),
        mustCallTools: ((json['mustCallTools'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        mustNotCallTools:
            ((json['mustNotCallTools'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
      );

  final int? maxTokenBudget;
  final int? maxToolCalls;
  final Set<String> mustCallTools;
  final Set<String> mustNotCallTools;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (maxTokenBudget != null) 'maxTokenBudget': maxTokenBudget,
    if (maxToolCalls != null) 'maxToolCalls': maxToolCalls,
    'mustCallTools': mustCallTools.toList(),
    'mustNotCallTools': mustNotCallTools.toList(),
  };
}

/// One row of the evaluation dataset: mocked state + user input + expectations.
class EvalScenario {
  const EvalScenario({
    required this.id,
    required this.title,
    required this.agentKind,
    required this.appState,
    required this.userInput,
    this.expectations = const EvalExpectations(),
  });

  factory EvalScenario.fromJson(Map<String, dynamic> json) => EvalScenario(
    id: json['id'] as String,
    title: json['title'] as String,
    agentKind: AgentKind.fromName(json['agentKind'] as String),
    appState: MockedAppState.fromJson(json['appState'] as Map<String, dynamic>),
    userInput: UserInput.fromJson(json['userInput'] as Map<String, dynamic>),
    expectations: json['expectations'] == null
        ? const EvalExpectations()
        : EvalExpectations.fromJson(
            json['expectations'] as Map<String, dynamic>,
          ),
  );

  final String id;
  final String title;
  final AgentKind agentKind;
  final MockedAppState appState;
  final UserInput userInput;
  final EvalExpectations expectations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'agentKind': agentKind.name,
    'appState': appState.toJson(),
    'userInput': userInput.toJson(),
    'expectations': expectations.toJson(),
  };
}

/// One tool call the agent made, with its raw arguments (keys match the real
/// tool schemas, e.g. `set_task_status` → `status`, `update_task_estimate` →
/// `minutes`, `draft_day_plan` → `blocks`).
class ToolCallRecord {
  const ToolCallRecord({required this.name, this.args = const {}});

  factory ToolCallRecord.fromJson(Map<String, dynamic> json) => ToolCallRecord(
    name: json['name'] as String,
    args: (json['args'] as Map<String, dynamic>?) ?? const {},
  );

  final String name;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'args': args,
  };
}

/// A time block the planner drafted.
class PlannedBlockRecord {
  const PlannedBlockRecord({
    required this.id,
    required this.categoryId,
    required this.start,
    required this.end,
    this.taskId,
  });

  factory PlannedBlockRecord.fromJson(Map<String, dynamic> json) =>
      PlannedBlockRecord(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        taskId: json['taskId'] as String?,
      );

  final String id;
  final String categoryId;
  final DateTime start;
  final DateTime end;
  final String? taskId;

  int get durationMinutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (taskId != null) 'taskId': taskId,
  };
}

/// The report the task agent publishes at the end of a wake.
class AgentReportRecord {
  const AgentReportRecord({
    required this.oneLiner,
    required this.tldr,
    this.content = '',
  });

  factory AgentReportRecord.fromJson(Map<String, dynamic> json) =>
      AgentReportRecord(
        oneLiner: json['oneLiner'] as String,
        tldr: json['tldr'] as String,
        content: (json['content'] as String?) ?? '',
      );

  final String oneLiner;
  final String tldr;
  final String content;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'oneLiner': oneLiner,
    'tldr': tldr,
    'content': content,
  };
}

/// The normalised output of one agent wake — the unit both the Level 1
/// assertions and the Claude Code judge evaluate. Produced identically by the
/// scripted and live targets.
class AgentRunOutput {
  const AgentRunOutput({
    required this.success,
    required this.usage,
    this.error,
    this.toolCalls = const <ToolCallRecord>[],
    this.plannedBlocks = const <PlannedBlockRecord>[],
    this.report,
    this.observations = const <String>[],
    this.mutatedEntryIds = const <String>{},
    this.turnCount = 0,
    this.wallClockMs = 0,
  });

  factory AgentRunOutput.fromJson(Map<String, dynamic> json) => AgentRunOutput(
    success: json['success'] as bool,
    usage: InferenceUsage.fromJson(
      (json['usage'] as Map<String, dynamic>?) ?? const {},
    ),
    error: json['error'] as String?,
    toolCalls: ((json['toolCalls'] as List<dynamic>?) ?? const [])
        .map((e) => ToolCallRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    plannedBlocks: ((json['plannedBlocks'] as List<dynamic>?) ?? const [])
        .map((e) => PlannedBlockRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    report: json['report'] == null
        ? null
        : AgentReportRecord.fromJson(
            json['report'] as Map<String, dynamic>,
          ),
    observations: ((json['observations'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
    mutatedEntryIds: ((json['mutatedEntryIds'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toSet(),
    turnCount: (json['turnCount'] as num?)?.toInt() ?? 0,
    wallClockMs: (json['wallClockMs'] as num?)?.toInt() ?? 0,
  );

  final bool success;
  final InferenceUsage usage;
  final String? error;
  final List<ToolCallRecord> toolCalls;
  final List<PlannedBlockRecord> plannedBlocks;
  final AgentReportRecord? report;
  final List<String> observations;
  final Set<String> mutatedEntryIds;
  final int turnCount;
  final int wallClockMs;

  /// Names of the tools called, in order.
  List<String> get toolNames => toolCalls.map((t) => t.name).toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'success': success,
    'usage': usage.toJson(),
    if (error != null) 'error': error,
    'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
    'plannedBlocks': plannedBlocks.map((b) => b.toJson()).toList(),
    if (report != null) 'report': report!.toJson(),
    'observations': observations,
    'mutatedEntryIds': mutatedEntryIds.toList(),
    'turnCount': turnCount,
    'wallClockMs': wallClockMs,
  };
}

/// A model profile to grade against: local vs frontier, with the efficiency
/// target encoded as `tokenBudget`.
class EvalProfile {
  const EvalProfile({
    required this.name,
    required this.isLocal,
    required this.modelClass,
    required this.modelId,
    this.temperature = 0.7,
    this.maxCompletionTokens,
    this.tokenBudget = 1 << 30,
    this.trialCount = 1,
  });

  factory EvalProfile.fromJson(Map<String, dynamic> json) => EvalProfile(
    name: json['name'] as String,
    isLocal: json['isLocal'] as bool,
    modelClass: EvalModelClass.fromName(
      (json['modelClass'] as String?) ??
          ((json['isLocal'] as bool) ? 'localReasoning' : 'frontierReasoning'),
    ),
    modelId: json['modelId'] as String,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    maxCompletionTokens: (json['maxCompletionTokens'] as num?)?.toInt(),
    tokenBudget: (json['tokenBudget'] as num?)?.toInt() ?? (1 << 30),
    trialCount: (json['trialCount'] as num?)?.toInt() ?? 1,
  );

  final String name;
  final bool isLocal;
  final EvalModelClass modelClass;
  final String modelId;
  final double temperature;
  final int? maxCompletionTokens;
  final int tokenBudget;
  final int trialCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'isLocal': isLocal,
    'modelClass': modelClass.name,
    'modelId': modelId,
    'temperature': temperature,
    if (maxCompletionTokens != null) 'maxCompletionTokens': maxCompletionTokens,
    'tokenBudget': tokenBudget,
    'trialCount': trialCount,
  };
}

/// Result of one deterministic Level 1 check.
class EvalCheck {
  const EvalCheck({
    required this.name,
    required this.passed,
    this.detail = '',
  });

  factory EvalCheck.pass(String name, [String detail = '']) =>
      EvalCheck(name: name, passed: true, detail: detail);

  factory EvalCheck.fail(String name, String detail) =>
      EvalCheck(name: name, passed: false, detail: detail);

  factory EvalCheck.fromJson(Map<String, dynamic> json) => EvalCheck(
    name: json['name'] as String,
    passed: json['passed'] as bool,
    detail: (json['detail'] as String?) ?? '',
  );

  final String name;
  final bool passed;
  final String detail;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'passed': passed,
    'detail': detail,
  };
}

/// The verdict a Claude Code judge writes back for a trace (see
/// eval/prompts/judge_system.md).
class JudgeVerdict {
  const JudgeVerdict({
    required this.goalAttainment,
    required this.quality,
    required this.efficiency,
    required this.pass,
    this.traceDigest,
    this.rationale = '',
    this.issues = const <String>[],
  });

  factory JudgeVerdict.fromJson(Map<String, dynamic> json) => JudgeVerdict(
    goalAttainment: (json['goalAttainment'] as num).toInt(),
    quality: (json['quality'] as num).toInt(),
    efficiency: (json['efficiency'] as num).toInt(),
    pass: json['pass'] as bool,
    traceDigest: json['traceDigest'] as String?,
    rationale: (json['rationale'] as String?) ?? '',
    issues: ((json['issues'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );

  final int goalAttainment;
  final int quality;
  final int efficiency;
  final bool pass;
  final String? traceDigest;
  final String rationale;
  final List<String> issues;

  JudgeVerdict withTraceDigest(String digest) => JudgeVerdict(
    goalAttainment: goalAttainment,
    quality: quality,
    efficiency: efficiency,
    pass: pass,
    traceDigest: digest,
    rationale: rationale,
    issues: issues,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'goalAttainment': goalAttainment,
    'quality': quality,
    'efficiency': efficiency,
    'pass': pass,
    if (traceDigest != null) 'traceDigest': traceDigest,
    'rationale': rationale,
    'issues': issues,
  };
}

/// The artifact persisted per `(scenario, profile)` and handed to the judge.
class EvalTrace {
  const EvalTrace({
    required this.runId,
    required this.scenario,
    required this.profile,
    required this.output,
    this.trialIndex = 0,
    this.level1Checks = const <EvalCheck>[],
    this.verdict,
  });

  factory EvalTrace.fromJson(Map<String, dynamic> json) => EvalTrace(
    runId: json['runId'] as String,
    trialIndex: (json['trialIndex'] as num?)?.toInt() ?? 0,
    scenario: EvalScenario.fromJson(json['scenario'] as Map<String, dynamic>),
    profile: EvalProfile.fromJson(json['profile'] as Map<String, dynamic>),
    output: AgentRunOutput.fromJson(json['output'] as Map<String, dynamic>),
    level1Checks: ((json['level1Checks'] as List<dynamic>?) ?? const [])
        .map((e) => EvalCheck.fromJson(e as Map<String, dynamic>))
        .toList(),
    verdict: json['verdict'] == null
        ? null
        : JudgeVerdict.fromJson(json['verdict'] as Map<String, dynamic>),
  );

  static const schemaVersion = 1;

  final String runId;
  final int trialIndex;
  final EvalScenario scenario;
  final EvalProfile profile;
  final AgentRunOutput output;
  final List<EvalCheck> level1Checks;
  final JudgeVerdict? verdict;

  /// Whether every Level 1 check passed.
  bool get level1Passed => level1Checks.every((c) => c.passed);

  EvalTrace withVerdict(JudgeVerdict v) => EvalTrace(
    runId: runId,
    scenario: scenario,
    profile: profile,
    output: output,
    trialIndex: trialIndex,
    level1Checks: level1Checks,
    verdict: v,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'runId': runId,
    'trialIndex': trialIndex,
    'scenario': scenario.toJson(),
    'profile': profile.toJson(),
    'output': output.toJson(),
    'level1Checks': level1Checks.map((c) => c.toJson()).toList(),
    if (verdict != null) 'verdict': verdict!.toJson(),
  };
}
