// Provenance helpers for eval traces.
//
// These helpers bind each trace to the scenario/profile payload, prompt files,
// tool schema, and code revision that produced it. That makes stale traces and
// mixed-run artifacts auditable before report aggregation.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';
import 'package:openai_dart/openai_dart.dart';

import 'eval_models.dart';
import 'eval_profile_config.dart';

abstract final class EvalProvenance {
  static const unboundManifestDigest =
      'sha256:0000000000000000000000000000000000000000000000000000000000000000';

  static EvalTraceProvenance capture({
    required EvalScenario scenario,
    required EvalProfile profile,
    String manifestDigest = unboundManifestDigest,
  }) {
    return EvalTraceProvenance(
      manifestDigest: manifestDigest,
      scenarioDigest: digestJson(scenario.toJson()),
      profileDigest: digestJson(profile.toJson()),
      promptDigest: promptDigest(),
      toolSchemaDigest: toolSchemaDigest(),
      codeRevision: codeRevision(),
    );
  }

  static EvalRunManifest captureRunManifest({
    required String runId,
    required String targetName,
    required String targetKind,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    DateTime? createdAt,
    String? command,
    Map<String, String>? environment,
    EvalPromotionPlan? promotionPlan,
    List<EvalProfileExecutionBinding>? profileExecutionBindings,
  }) {
    final env = environment ?? Platform.environment;
    final git = _gitState(env);
    final scenarioDigest = scenarioSetDigest(scenarios);
    final executionBindings =
        profileExecutionBindings ??
        [
          for (final profile in profiles)
            evalProfileConfig(profile).toExecutionBinding(),
        ];
    final catalogEvidence =
        scenarioCatalogEvidence ??
        EvalScenarioCatalogEvidence(
          scenarioSetDigest: scenarioDigest,
          publicScenarioCount: scenarios.length,
          externalScenarioCount: 0,
          protectedHoldout: false,
          protectedScenarioIds: const [],
          protectedHoldoutScenarioIds: const [],
        );
    final manifest = EvalRunManifest(
      runId: runId,
      traceSchemaVersion: EvalTrace.schemaVersion,
      targetName: targetName,
      targetKind: targetKind,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      command: _sanitizeCommand(command ?? _defaultCommand()),
      scenarioSetDigest: scenarioDigest,
      profileSetDigest: profileSetDigest(profiles),
      profileBindingSetDigest: profileBindingSetDigest(executionBindings),
      profileExecutionBindings: executionBindings,
      promptDigest: promptDigest(),
      toolSchemaDigest: toolSchemaDigest(),
      codeRevision: git.codeRevision,
      gitDirty: git.isDirty,
      dirtyDiffDigest: git.dirtyDiffDigest,
      scenarioCatalogEvidence: catalogEvidence,
      promotionPlanEvidence: promotionPlan == null
          ? null
          : promotionPlanEvidence(promotionPlan),
      envPresence: envPresence(env),
    );
    return manifest.withManifestDigest(manifestDigest(manifest));
  }

  static String digestJson(Object? value) =>
      _digest(jsonEncode(_canonicalize(value)));

  static String digestText(String value) => _digest(value);

  static String scenarioSetDigest(List<EvalScenario> scenarios) => digestJson([
    for (final scenario in [...scenarios]..sort((a, b) => a.id.compareTo(b.id)))
      scenario.toJson(),
  ]);

  static String scenarioReviewSubjectDigest(EvalScenario scenario) {
    final json = scenario.toJson();
    (json['metadata'] as Map<String, dynamic>).remove('review');
    return digestJson(json);
  }

  static String profileSetDigest(List<EvalProfile> profiles) => digestJson([
    for (final profile in [
      ...profiles,
    ]..sort((a, b) => a.name.compareTo(b.name)))
      profile.toJson(),
  ]);

  static String profileBindingSetDigest(
    List<EvalProfileExecutionBinding> bindings,
  ) => digestJson([
    for (final binding in [
      ...bindings,
    ]..sort((a, b) => a.profileName.compareTo(b.profileName)))
      binding.toJson(),
  ]);

  static String manifestDigest(EvalRunManifest manifest) =>
      digestJson(manifest.toJson(includeManifestDigest: false));

  static String promotionPlanSubjectDigest(EvalPromotionPlan plan) =>
      digestJson(plan.toSubjectJson());

  static EvalPromotionPlanEvidence promotionPlanEvidence(
    EvalPromotionPlan plan,
  ) {
    return EvalPromotionPlanEvidence(
      planId: plan.planId,
      candidateProfileName: plan.candidateProfileName,
      baselineProfileName: plan.baselineProfileName,
      scenarioSetDigest: plan.scenarioSetDigest,
      profileSetDigest: plan.profileSetDigest,
      policyDigest: plan.policyDigest,
      promotionPlanSubjectDigest: promotionPlanSubjectDigest(plan),
    );
  }

  static RuntimePromptRecord runtimePrompt({
    required String? systemMessage,
    required String? userMessage,
    required List<ChatCompletionTool> tools,
  }) {
    return RuntimePromptRecord(
      systemDigest: systemMessage == null ? null : digestText(systemMessage),
      userDigest: userMessage == null ? null : digestText(userMessage),
      toolSchemaDigest: digestJson([
        for (final tool in tools) tool.toJson(),
      ]),
      toolCount: tools.length,
    );
  }

  static String promptDigest() => digestJson({
    for (final entry in _promptFiles.entries)
      entry.key: _readIfPresent(entry.value),
  });

  static String toolSchemaDigest() => digestJson({
    'taskAgentTools': [
      for (final tool in AgentToolRegistry.taskAgentTools)
        {
          'name': tool.name,
          'description': tool.description,
          'enabled': tool.enabled,
          'parameters': tool.parameters,
        },
    ],
    'taskAgentDeferredTools': AgentToolRegistry.deferredTools.toList()..sort(),
    'taskAgentExplodedBatchTools': AgentToolRegistry.explodedBatchTools,
    'planningAgentTools': [
      for (final tool in dayAgentTools)
        {
          'name': tool.name,
          'description': tool.description,
          'enabled': tool.enabled,
          'parameters': tool.parameters,
        },
    ],
  });

  static Map<String, bool> envPresence(Map<String, String> environment) {
    return {
      for (final key in _trackedEnvKeys)
        key: (environment[key]?.trim().isNotEmpty ?? false),
    };
  }

  static String codeRevision([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    for (final key in _codeRevisionEnvKeys) {
      final value = env[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final gitHead = _runGit(const ['rev-parse', 'HEAD']);
    if (gitHead != null && gitHead.trim().isNotEmpty) {
      return gitHead.trim();
    }
    return 'unknown';
  }

  static bool isDigest(String value) =>
      RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

  static const _promptFiles = {
    'judgeSystem': 'eval/prompts/judge_system.md',
    'taskRubric': 'eval/prompts/rubric_task_agent.md',
    'planningRubric': 'eval/prompts/rubric_planning_agent.md',
    'gradeRunbook': 'eval/grade_run.md',
  };

  static const _codeRevisionEnvKeys = [
    'LOTTI_EVAL_GIT_SHA',
    'GITHUB_SHA',
    'BUILDKITE_COMMIT',
  ];

  static const _trackedEnvKeys = [
    'CI',
    'EVAL_RUN',
    'EVAL_PROMOTION_PLAN',
    'EVAL_SCENARIOS',
    'LOTTI_EVAL_ALLOW_CI',
    'LOTTI_EVAL_LIVE',
    'LOTTI_EVAL_LOCAL_MODEL',
    'LOTTI_EVAL_FRONTIER_MODEL',
    'LOTTI_EVAL_FRONTIER_PROVIDER',
    'OLLAMA_MODEL',
    'OLLAMA_BASE_URL',
    'GEMINI_API_KEY',
    'OPENAI_API_KEY',
    'MISTRAL_API_KEY',
    'OPENROUTER_API_KEY',
    'NEBIUS_AI_STUDIO_API_KEY',
  ];

  static String _readIfPresent(String path) {
    final file = File(path);
    if (!file.existsSync()) return '<missing:$path>';
    return file.readAsStringSync();
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is Set) {
      return value.map(_canonicalize).toList()
        ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  static String _digest(String value) =>
      'sha256:${sha256.convert(utf8.encode(value))}';

  static String _defaultCommand() {
    final args = [
      Platform.resolvedExecutable,
      ...Platform.executableArguments,
      Platform.script.toString(),
    ];
    return args.where((arg) => arg.trim().isNotEmpty).join(' ');
  }

  static String _sanitizeCommand(String command) {
    final secretRedacted = command.replaceAllMapped(
      RegExp(
        r'([A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD)[A-Z0-9_]*=)([^\s]+)',
      ),
      (match) => '${match.group(1)}<redacted>',
    );
    return secretRedacted.replaceAllMapped(
      RegExp(r'((?:EVAL_SCENARIOS|EVAL_PROMOTION_PLAN)=)([^\s]+)'),
      (match) => '${match.group(1)}<redacted>',
    );
  }

  static _GitState _gitState(Map<String, String> environment) {
    final revision = codeRevision(environment);
    final status = _runGit(const ['status', '--porcelain=v1']);
    if (status == null) {
      return _GitState(codeRevision: revision, isDirty: false);
    }
    final diff = _runGit(const ['diff', '--binary', 'HEAD', '--']) ?? '';
    final dirtyPayload = 'status\n$status\n\ndiff\n$diff';
    final isDirty = status.trim().isNotEmpty;
    return _GitState(
      codeRevision: revision,
      isDirty: isDirty,
      dirtyDiffDigest: isDirty ? digestText(dirtyPayload) : null,
    );
  }

  static String? _runGit(List<String> args) {
    try {
      final result = Process.runSync(
        'git',
        args,
        workingDirectory: Directory.current.path,
      );
      if (result.exitCode != 0) return null;
      return result.stdout as String;
    } on Object {
      return null;
    }
  }
}

class _GitState {
  const _GitState({
    required this.codeRevision,
    required this.isDirty,
    this.dirtyDiffDigest,
  });

  final String codeRevision;
  final bool isDirty;
  final String? dirtyDiffDigest;
}
