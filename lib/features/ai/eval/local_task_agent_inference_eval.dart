import 'dart:convert';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directive_content.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_evidence_synthesis.dart';
import 'package:lotti/features/agents/workflow/task_agent_prompt_builder.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_editor.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

const localTaskAgentEvalKind = 'lotti.localTaskAgentInferenceEvalReport';

final _defaultTaskAgentEvalSoul =
    AgentDomainEntity.soulDocumentVersion(
          id: 'eval-$lauraSoulId-v1',
          agentId: lauraSoulId,
          version: 1,
          status: SoulDocumentVersionStatus.active,
          authoredBy: 'system',
          createdAt: DateTime.utc(2026, 7, 10),
          vectorClock: null,
          voiceDirective: lauraSoulVoiceDirective,
          toneBounds: lauraSoulToneBounds,
          coachingStyle: lauraSoulCoachingStyle,
          antiSycophancyPolicy: lauraSoulAntiSycophancyPolicy,
        )
        as SoulDocumentVersionEntity;

const defaultLocalTaskAgentEvalProfiles = [
  LocalTaskAgentEvalProfile(
    name: 'qwen36-a35b-a3b-mlx4',
    providerModelId: omlxQwen36A35bA3b4BitModelId,
    modelClass: 'qwen36-a35b-a3b-omlx',
  ),
  LocalTaskAgentEvalProfile(
    name: 'gemma4-26b-a4b-qat-mlx4',
    providerModelId: omlxGemma426BA4BItQatMlx4BitModelId,
    modelClass: 'gemma4-26b-a4b-omlx',
  ),
];

const defaultMeliousTaskAgentEvalProfiles = [
  LocalTaskAgentEvalProfile(
    name: 'mistral-small-4-baseline',
    providerModelId: meliousMistralSmall4119BInstructModelId,
    modelClass: 'mistral-small-4-119b-instruct',
  ),
  LocalTaskAgentEvalProfile(
    name: 'qwen3.5-122b-a10b-candidate',
    providerModelId: meliousQwen35122BA10BModelId,
    modelClass: 'qwen3.5-122b-a10b',
  ),
  LocalTaskAgentEvalProfile(
    name: 'deepseek-v4-flash-candidate',
    providerModelId: meliousDeepseekV4FlashModelId,
    modelClass: 'deepseek-v4-flash',
  ),
  LocalTaskAgentEvalProfile(
    name: 'glm-5.2-reference',
    providerModelId: meliousGlm52ModelId,
    modelClass: 'glm-5.2',
  ),
];

enum LocalTaskAgentEvalPromptVariant {
  production,
  compactModel,
  qualityFocused,
  conciseReport,
  evidenceSynthesis,
}

enum LocalTaskAgentEvalExecutionMode {
  singlePass,
  twoPass,
  reportRevision,
  reportEditing,
  productionRouting,
}

enum _LocalTaskAgentProductionRoute { none, mistralWithQwen, directQwen }

const _missingInitialReportPrompt =
    'You did not call `update_report` before stopping. Call it now. You MUST '
    'supply a concise `oneLiner`, a 1-3 sentence `tldr`, and the full markdown '
    '`content`. This is the final step of the wake and is mandatory. Do not '
    'respond with anything else.';

ReasoningEffort? parseLocalTaskAgentEvalReasoningEffort(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return ReasoningEffort.values.firstWhere(
    (effort) => effort.name == normalized,
    orElse: () => throw FormatException(
      'Unknown task-agent eval reasoning effort "$value".',
      value,
    ),
  );
}

int parseLocalTaskAgentEvalReportEditorAttempts(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return 1;
  final attempts = int.tryParse(normalized);
  if (attempts == null || attempts < 1 || attempts > 3) {
    throw FormatException(
      'Expected report editor attempts in [1, 3], got "$value".',
      value,
    );
  }
  return attempts;
}

LocalTaskAgentEvalExecutionMode parseLocalTaskAgentEvalExecutionMode(
  String value,
) {
  final normalized = value.trim();
  return LocalTaskAgentEvalExecutionMode.values.firstWhere(
    (mode) => mode.name == normalized,
    orElse: () => throw FormatException(
      'Unknown task-agent eval execution mode "$value".',
      value,
    ),
  );
}

LocalTaskAgentEvalPromptVariant parseLocalTaskAgentEvalPromptVariant(
  String value,
) {
  final normalized = value.trim();
  return LocalTaskAgentEvalPromptVariant.values.firstWhere(
    (variant) => variant.name == normalized,
    orElse: () => throw FormatException(
      'Unknown task-agent eval prompt variant "$value".',
      value,
    ),
  );
}

class LocalTaskAgentEvalProfile {
  const LocalTaskAgentEvalProfile({
    required this.name,
    required this.providerModelId,
    required this.modelClass,
  });

  final String name;
  final String providerModelId;
  final String modelClass;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'providerModelId': providerModelId,
      'modelClass': modelClass,
    };
  }
}

class LocalTaskAgentExpectedToolCall {
  const LocalTaskAgentExpectedToolCall({
    required this.name,
    this.expectedArgumentsSubset = const {},
  });

  final String name;
  final Map<String, Object?> expectedArgumentsSubset;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'expectedArgumentsSubset': expectedArgumentsSubset,
    };
  }
}

class LocalTaskAgentEvalScenario {
  const LocalTaskAgentEvalScenario({
    required this.id,
    required this.systemPrompt,
    required this.userMessage,
    required this.expectedToolCalls,
    this.allowedExtraToolNames = const {
      TaskAgentToolNames.updateReport,
      TaskAgentToolNames.recordObservations,
    },
    this.requiresReport = true,
    this.isFirstWake = true,
    this.maxTurns = 6,
    this.languageCode = 'en',
    this.promptVariant = LocalTaskAgentEvalPromptVariant.production,
    this.reportDirective,
    this.currentDueDate,
    this.currentEstimateMinutes,
    this.currentPriority,
    this.requiredReportTermGroups = const [],
    this.forbiddenReportTerms = const [],
    this.requiredToolArgumentTermGroups = const {},
    this.forbiddenToolNames = const {},
    this.forbiddenToolArgumentTerms = const {},
  });

  final String id;
  final String systemPrompt;
  final String userMessage;
  final List<LocalTaskAgentExpectedToolCall> expectedToolCalls;
  final Set<String> allowedExtraToolNames;
  final bool requiresReport;
  final bool isFirstWake;
  final int maxTurns;
  final String languageCode;
  final LocalTaskAgentEvalPromptVariant promptVariant;

  /// Optional evolved report directive used instead of the prompt variant's
  /// configured contract.
  final String? reportDirective;

  /// Existing material task anchors supplied to the production report route.
  final String? currentDueDate;
  final int? currentEstimateMinutes;
  final String? currentPriority;

  /// Each group is satisfied when the report contains at least one term.
  final List<List<String>> requiredReportTermGroups;

  /// Terms that must never appear in the user-visible report payload.
  final List<String> forbiddenReportTerms;

  /// Semantic term groups required in a specific tool's arguments.
  final Map<String, List<List<String>>> requiredToolArgumentTermGroups;

  /// Tools that must not be called for this scenario.
  final Set<String> forbiddenToolNames;

  /// Terms that must not appear in a specific tool's arguments.
  final Map<String, List<String>> forbiddenToolArgumentTerms;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'expectedToolCalls': expectedToolCalls
          .map((expected) => expected.toJson())
          .toList(),
      'allowedExtraToolNames': allowedExtraToolNames.toList()..sort(),
      'requiresReport': requiresReport,
      'isFirstWake': isFirstWake,
      'maxTurns': maxTurns,
      'languageCode': languageCode,
      'promptVariant': promptVariant.name,
      'reportDirective': reportDirective,
      'currentDueDate': currentDueDate,
      'currentEstimateMinutes': currentEstimateMinutes,
      'currentPriority': currentPriority,
      'requiredReportTermGroups': requiredReportTermGroups,
      'forbiddenReportTerms': forbiddenReportTerms,
      'requiredToolArgumentTermGroups': requiredToolArgumentTermGroups,
      'forbiddenToolNames': forbiddenToolNames.toList()..sort(),
      'forbiddenToolArgumentTerms': forbiddenToolArgumentTerms,
      'systemPromptChars': systemPrompt.length,
      'userMessageChars': userMessage.length,
      'userMessage': userMessage,
    };
  }
}

List<LocalTaskAgentEvalScenario> defaultMeliousTaskAgentEvalScenarios({
  List<LocalTaskAgentEvalPromptVariant> variants = const [
    LocalTaskAgentEvalPromptVariant.production,
  ],
}) {
  return [
    for (final variant in variants) ...[
      _metadataScenario(variant),
      _implicitWorkflowPlanScenario(variant),
      _germanPlanningScenario(variant),
      _progressUpdateScenario(variant),
      _noOpRefreshScenario(variant),
      _duplicateChecklistScenario(variant),
      _staleDeadlineScenario(variant),
      _messyGermanTranscriptScenario(variant),
      _deferredScopeScenario(variant),
      _activeDeploymentConstraintScenario(variant),
      _userCompletedItemScenario(variant),
      _spanishMixedContextScenario(variant),
      _externalLinkScenario(variant),
      _latestDeadlineWinsScenario(variant),
    ],
  ];
}

LocalTaskAgentEvalScenario _implicitWorkflowPlanScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'implicit_workflow_plan_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _implicitWorkflowPlanUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.addMultipleChecklistItems,
      ),
    ],
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['profile seeding'],
      ['pull request', 'pr'],
      ['review'],
      ['release'],
    ],
    forbiddenReportTerms: const [
      'implementation in progress',
      'working on',
      'checklist created',
      'all checklist items ready',
    ],
    requiredToolArgumentTermGroups: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        ['profile seeding', 'empty profile'],
        ['implement'],
        ['pull request', 'pr'],
        ['gemini'],
        ['code review'],
        ['merge'],
        ['release'],
      ],
    },
  );
}

/// Synthetic scenarios with representative report directives produced by an
/// agent-evolution workflow rather than Lotti's seeded report contract.
List<LocalTaskAgentEvalScenario>
evolvedReportDirectiveTaskAgentEvalScenarios() {
  final base = defaultMeliousTaskAgentEvalScenarios(
    variants: const [LocalTaskAgentEvalPromptVariant.evidenceSynthesis],
  );

  LocalTaskAgentEvalScenario find(String id) =>
      base.firstWhere((scenario) => scenario.id == id);

  return [
    _withEvolvedReportDirective(
      find('metadata_explicit_evidenceSynthesis'),
      id: 'metadata_explicit_evolved_decision_memo',
      reportDirective: _evolvedDecisionMemoDirective,
      requiredDirectiveTerms: const [
        ['## recommendation'],
        ['## next moves'],
      ],
      forbiddenDirectiveTerms: const [
        '## achieved',
        'what is left to do',
        '## decision needed',
      ],
    ),
    _withEvolvedReportDirective(
      find('german_voice_plan_evidenceSynthesis'),
      id: 'german_voice_plan_evolved_delivery_coach',
      reportDirective: _evolvedGermanDeliveryCoachDirective,
      requiredDirectiveTerms: const [
        ['## lage'],
        ['## nächste schritte', r'## n\u00e4chste schritte'],
      ],
      forbiddenDirectiveTerms: const [
        '## progress',
        '## next actions',
      ],
    ),
    _withEvolvedReportDirective(
      find('progress_update_evidenceSynthesis'),
      id: 'progress_update_evolved_risk_brief',
      reportDirective: _evolvedRiskBriefDirective,
      requiredDirectiveTerms: const [
        ['## delivery risk'],
        ['## next intervention'],
      ],
      forbiddenDirectiveTerms: const ['no blockers'],
    ),
    _withEvolvedReportDirective(
      find('messy_german_transcript_evidenceSynthesis'),
      id: 'messy_german_transcript_evolved_plain_language',
      reportDirective: _evolvedPlainLanguageDirective,
      forbiddenDirectiveTerms: const ['##', '|---'],
    ),
    _withEvolvedReportDirective(
      find('active_deployment_constraint_evidenceSynthesis'),
      id: 'active_deployment_constraint_evolved_decision_memo',
      reportDirective: _evolvedDecisionMemoDirective,
      requiredDirectiveTerms: const [
        ['## recommendation'],
        ['## next moves'],
      ],
      forbiddenDirectiveTerms: const ['## decision needed'],
    ),
    _withEvolvedReportDirective(
      find('spanish_mixed_context_evidenceSynthesis'),
      id: 'spanish_mixed_context_evolved_localized_partner',
      reportDirective: _evolvedLocalizedPartnerDirective,
      requiredDirectiveTerms: const [
        ['## situación', r'## situaci\u00f3n'],
        ['## próximos pasos', r'## pr\u00f3ximos pasos'],
      ],
      forbiddenDirectiveTerms: const [
        '## situation',
        '## next steps',
      ],
    ),
    _withEvolvedReportDirective(
      find('external_link_and_completion_evidenceSynthesis'),
      id: 'external_link_and_completion_evolved_release_evidence',
      reportDirective: _evolvedReleaseEvidenceDirective,
      requiredDirectiveTerms: const [
        ['## outcome'],
        ['## remaining'],
        ['## evidence'],
      ],
      forbiddenDirectiveTerms: const ['## achieved'],
    ),
  ];
}

LocalTaskAgentEvalScenario _withEvolvedReportDirective(
  LocalTaskAgentEvalScenario source, {
  required String id,
  required String reportDirective,
  List<List<String>> requiredDirectiveTerms = const [],
  List<String> forbiddenDirectiveTerms = const [],
}) {
  return LocalTaskAgentEvalScenario(
    id: id,
    systemPrompt: _buildEvalSystemPrompt(
      source.promptVariant,
      reportDirective: reportDirective,
    ),
    userMessage: source.userMessage,
    expectedToolCalls: source.expectedToolCalls,
    allowedExtraToolNames: source.allowedExtraToolNames,
    requiresReport: source.requiresReport,
    isFirstWake: source.isFirstWake,
    maxTurns: source.maxTurns,
    languageCode: source.languageCode,
    promptVariant: source.promptVariant,
    reportDirective: reportDirective,
    requiredReportTermGroups: [
      ...source.requiredReportTermGroups,
      ...requiredDirectiveTerms,
    ],
    forbiddenReportTerms: [
      ...source.forbiddenReportTerms,
      ...forbiddenDirectiveTerms,
    ],
    requiredToolArgumentTermGroups: source.requiredToolArgumentTermGroups,
    forbiddenToolNames: source.forbiddenToolNames,
    forbiddenToolArgumentTerms: source.forbiddenToolArgumentTerms,
  );
}

const _evolvedDecisionMemoDirective = '''
Write as a senior delivery partner, not a status bot. Use the task's language.
The one-liner states the current delivery call; the TLDR explains its practical
consequence without repeating it. Start the full report with
`## Recommendation` and one short evidence-backed paragraph. Follow with
`## Next moves`, using one to four concrete bullets and retaining owners and
dates when known. Add `## Decision needed` only when the user must resolve an
active choice or dependency. Omit generic status headings, empty sections,
tool narration, and repeated context.
''';

const _evolvedGermanDeliveryCoachDirective = '''
Schreibe auf Deutsch und sprich die Person informell mit du/dein an. Beginne
mit `## Lage` und zwei klaren Sätzen dazu, worauf es jetzt ankommt. Verwende
danach genau `## Nächste Schritte` für die wenigen konkreten Aktionen; nenne
Verantwortliche, Reihenfolge und Termine, wenn sie belegt sind. Keine
Standardrubriken wie Progress oder Achieved, keine leeren Abschnitte und keine
Erzählung über Checklisten, Metadaten oder Agentenarbeit.
''';

const _evolvedRiskBriefDirective = '''
Write a candid delivery-risk brief in the task language. Begin with
`## Delivery risk`: name the active constraint, owner, consequence, and
deadline without softening or inventing certainty. Then use
`## Next intervention` for the smallest action that can unblock delivery.
Mention completed outcomes only when the evidence records them. Do not add a
generic progress recap, optimism, empty sections, or agent-process commentary.
''';

const _evolvedPlainLanguageDirective = '''
Write in the task language as plain, natural prose for a busy person. Use no
headings, tables, status labels, or checkbox syntax. Start with one short
paragraph describing the current real-world situation, then give only the
concrete next actions as ordinary Markdown bullets. Keep owners, sequence,
deadlines, blockers, and recorded outcomes, but omit speculative or deferred
scope and all narration about tools, metadata, transcription, or checklists.
''';

const _evolvedLocalizedPartnerDirective = '''
Write entirely in the task language with a direct, informal, collaborative
voice. For a Spanish task, use exactly `## Situación` for the current external
constraint and `## Próximos pasos` for concrete actions. Keep named owners and
dates. Never leak headings from another language, repeat parent-project filler,
or describe task setup and checklist operations as progress.
''';

const _evolvedReleaseEvidenceDirective = '''
Write a compact release note grounded only in recorded outcomes. Use exactly
`## Outcome` for completed real-world work and `## Remaining` for work that is
still pending. Add `## Evidence` only when a real external URL exists, using a
descriptive Markdown link. Keep completion separate from deployment readiness.
Do not use generic achievement headings, expose internal IDs, or turn task
state and checklist edits into accomplishments.
''';

List<LocalTaskAgentEvalScenario> selectLocalTaskAgentEvalScenarios(
  List<LocalTaskAgentEvalScenario> scenarios,
  List<String> ids,
) {
  if (ids.isEmpty) return scenarios;
  final selected = scenarios
      .where((scenario) => ids.contains(scenario.id))
      .toList(growable: false);
  final unknown = ids.where(
    (id) => scenarios.every((scenario) => scenario.id != id),
  );
  if (unknown.isNotEmpty) {
    throw ArgumentError.value(unknown.toList(), 'ids', 'Unknown scenario IDs');
  }
  return selected;
}

LocalTaskAgentEvalProfile parseLocalTaskAgentEvalProfile(String value) {
  final separator = value.indexOf('=');
  if (separator <= 0 || separator == value.length - 1) {
    throw FormatException(
      'Expected profile as name=model, got "$value".',
      value,
    );
  }
  final name = value.substring(0, separator).trim();
  final model = value.substring(separator + 1).trim();
  if (name.isEmpty || model.isEmpty) {
    throw FormatException(
      'Expected profile as name=model, got "$value".',
      value,
    );
  }
  return LocalTaskAgentEvalProfile(
    name: name,
    providerModelId: model,
    modelClass: name,
  );
}

List<ChatCompletionTool> buildLocalTaskAgentEvalTools({
  LocalTaskAgentEvalPromptVariant? promptVariant,
}) {
  return AgentToolRegistry.taskAgentTools
      .where((definition) {
        return definition.enabled;
      })
      .map((definition) {
        final useEvidenceContract =
            definition.name == TaskAgentToolNames.updateReport &&
            promptVariant == LocalTaskAgentEvalPromptVariant.evidenceSynthesis;
        return ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: definition.name,
            description: useEvidenceContract
                ? TaskAgentEvidenceSynthesis.updateReportDescription(
                    definition.description,
                  )
                : definition.description,
            parameters: useEvidenceContract
                ? TaskAgentEvidenceSynthesis.updateReportParameters(
                    definition.parameters,
                  )
                : definition.parameters,
          ),
        );
      })
      .toList(growable: false);
}

/// Reduces current scenario anchors and mutations to ID-free editor facts.
Map<String, Object?> buildLocalTaskAgentEvalMaterialTaskState(
  List<LocalTaskAgentEvalToolCall> toolCalls, {
  String? currentDueDate,
  int? currentEstimateMinutes,
  String? currentPriority,
}) {
  return TaskAgentReportEditor.buildMaterialTaskState(
    toolCalls
        .where((call) => call.phase == LocalTaskAgentEvalToolCallPhase.main)
        .map((call) {
          final arguments = call.jsonObjectArguments;
          if (arguments == null) return null;
          return (toolName: call.name, arguments: arguments);
        })
        .whereType<TaskAgentMutationRecord>(),
    currentDueDate: currentDueDate,
    currentEstimateMinutes: currentEstimateMinutes,
    currentPriority: currentPriority,
  );
}

LocalTaskAgentEvalScenario defaultLocalTaskAgentWakeScenario() {
  final version =
      AgentDomainEntity.agentTemplateVersion(
            id: 'local-task-agent-eval-template-version',
            agentId: 'local-task-agent-eval-template',
            version: 1,
            status: AgentTemplateVersionStatus.active,
            directives:
                'Be precise, avoid redundant task updates, and publish a '
                'short user-facing report only after required changes are '
                'queued.',
            generalDirective: taskAgentGeneralDirective,
            reportDirective: taskAgentReportDirective,
            authoredBy: 'system',
            createdAt: DateTime.utc(2026, 6, 21),
            vectorClock: null,
          )
          as AgentTemplateVersionEntity;

  return LocalTaskAgentEvalScenario(
    id: 'task_agent_first_wake_metadata_and_report',
    systemPrompt: TaskAgentPromptBuilder.buildSystemPrompt(
      version: version,
      soulVersion: _defaultTaskAgentEvalSoul,
    ),
    userMessage: _defaultProductionWakeUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.setTaskTitle,
        expectedArgumentsSubset: {
          'title': 'Validate efficient task-agent model',
        },
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskEstimate,
        expectedArgumentsSubset: {'minutes': 150},
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskDueDate,
        expectedArgumentsSubset: {'dueDate': '2026-07-04'},
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskPriority,
        expectedArgumentsSubset: {'priority': 'P1'},
      ),
    ],
  );
}

LocalTaskAgentEvalScenario _metadataScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  final base = defaultLocalTaskAgentWakeScenario();
  return LocalTaskAgentEvalScenario(
    id: 'metadata_explicit_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: base.userMessage,
    expectedToolCalls: base.expectedToolCalls,
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['candidate', 'task-agent'],
      ['p1'],
      ['2026-07-04', 'july 4'],
      ['150', '2.5', 'two and a half'],
      ['reference'],
    ],
    forbiddenReportTerms: const ['check-1', 'check-2'],
  );
}

LocalTaskAgentEvalScenario _germanPlanningScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'german_voice_plan_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _germanPlanningUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.addMultipleChecklistItems,
      ),
    ],
    languageCode: 'de',
    promptVariant: variant,
    currentDueDate: '2026-09-30',
    currentPriority: 'P1',
    requiredReportTermGroups: const [
      ['30. september', '30.09', '2026-09-30'],
      ['ben'],
      ['figma', 'prototyp'],
      ['auth', 'anmeldung'],
      ['lea'],
      ['security', 'sicherheit'],
    ],
    requiredToolArgumentTermGroups: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        ['ben'],
        ['figma', 'prototyp'],
        ['auth', 'anmeldung'],
        ['lea'],
        ['security', 'sicherheit'],
      ],
    },
  );
}

LocalTaskAgentEvalScenario _progressUpdateScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'progress_update_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _progressUpdateUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateChecklistItems,
        expectedArgumentsSubset: {
          'items': [
            {'id': 'item-interviews', 'isChecked': true},
          ],
        },
      ),
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskDueDate,
        expectedArgumentsSubset: {'dueDate': '2026-10-15'},
      ),
    ],
    promptVariant: variant,
    currentDueDate: '2026-09-30',
    currentPriority: 'P1',
    requiredReportTermGroups: const [
      ['interviews'],
      ['dana'],
      ['legal'],
      ['2026-10-15', 'october 15', 'oct 15'],
    ],
    forbiddenReportTerms: const [
      'item-interviews',
      'item-legal',
      'task-client-portal',
    ],
  );
}

LocalTaskAgentEvalScenario _noOpRefreshScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'no_op_background_refresh_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _noOpRefreshUserMessage,
    expectedToolCalls: const [],
    forbiddenToolNames: const {TaskAgentToolNames.updateReport},
    requiresReport: false,
    isFirstWake: false,
    maxTurns: 3,
    promptVariant: variant,
  );
}

LocalTaskAgentEvalScenario _duplicateChecklistScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'duplicate_checklist_reconciliation_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _duplicateChecklistUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.addMultipleChecklistItems,
      ),
    ],
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['submit'],
      ['friday'],
      ['receipt'],
      ['reconcile'],
    ],
    forbiddenReportTerms: const ['item-receipts', 'item-reconcile'],
    requiredToolArgumentTermGroups: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        ['submit'],
        ['expense report'],
        ['friday'],
      ],
    },
    forbiddenToolArgumentTerms: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        'email the q2 receipts',
        'reconcile the card transactions',
      ],
    },
  );
}

LocalTaskAgentEvalScenario _staleDeadlineScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'stale_deadline_user_override_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _staleDeadlineUserMessage,
    expectedToolCalls: const [],
    forbiddenToolNames: const {
      TaskAgentToolNames.updateTaskDueDate,
      TaskAgentToolNames.updateReport,
    },
    requiresReport: false,
    isFirstWake: false,
    maxTurns: 3,
    promptVariant: variant,
  );
}

LocalTaskAgentEvalScenario _messyGermanTranscriptScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'messy_german_transcript_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _messyGermanTranscriptUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.addMultipleChecklistItems,
      ),
    ],
    languageCode: 'de',
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['export'],
      ['sam'],
      ['testdaten'],
      ['regression'],
    ],
    forbiddenReportTerms: const ['newsletter'],
    requiredToolArgumentTermGroups: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        ['export'],
        ['sam'],
        ['testdaten'],
        ['regression'],
      ],
    },
    forbiddenToolArgumentTerms: const {
      TaskAgentToolNames.addMultipleChecklistItems: ['newsletter'],
    },
  );
}

LocalTaskAgentEvalScenario _deferredScopeScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'deferred_scope_filter_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _deferredScopeUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.addMultipleChecklistItems,
      ),
    ],
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['certificate'],
      ['security'],
      ['priya'],
      ['staging'],
      ['webhook'],
    ],
    forbiddenReportTerms: [
      'dashboard',
      'analytics',
      if (_usesEvidenceSynthesis(variant)) ...['underway', 'awaiting'],
    ],
    requiredToolArgumentTermGroups: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        ['certificate'],
        ['security'],
        ['priya'],
        ['staging'],
        ['webhook'],
      ],
    },
    forbiddenToolArgumentTerms: const {
      TaskAgentToolNames.addMultipleChecklistItems: ['dashboard', 'analytics'],
    },
  );
}

LocalTaskAgentEvalScenario _activeDeploymentConstraintScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'active_deployment_constraint_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _activeDeploymentConstraintUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateChecklistItems,
        expectedArgumentsSubset: {
          'items': [
            {'id': 'item-rollback', 'isChecked': true},
          ],
        },
      ),
    ],
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['legal'],
      ['marta'],
      ['approval', 'approve'],
      ['deploy'],
      ['rollback'],
    ],
    forbiddenReportTerms: const ['item-rollback', 'item-deploy'],
  );
}

LocalTaskAgentEvalScenario _userCompletedItemScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'user_completed_item_resurfaced_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _userCompletedItemUserMessage,
    expectedToolCalls: const [],
    forbiddenToolNames: const {TaskAgentToolNames.updateChecklistItems},
    isFirstWake: false,
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['sync'],
      ['reappeared', 'resurfaced', 'again', 'recurrence', 'recurred'],
      ['blocked', 'blocker', 'risk', 'root cause', 'investigat'],
    ],
    forbiddenReportTerms: [
      'item-sync-fix',
      if (_usesEvidenceSynthesis(variant)) ...[
        'deployed',
        'verified',
        'validated',
        'implemented',
        'applied',
        'underway',
      ],
    ],
  );
}

LocalTaskAgentEvalScenario _spanishMixedContextScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'spanish_mixed_context_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _spanishMixedContextUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.addMultipleChecklistItems,
      ),
    ],
    languageCode: 'es',
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['marta'],
      ['proveedor'],
      ['bloquead', 'pendiente'],
    ],
    forbiddenReportTerms: const ['waiting for the vendor'],
    requiredToolArgumentTermGroups: const {
      TaskAgentToolNames.addMultipleChecklistItems: [
        ['marta'],
        ['proveedor'],
      ],
    },
  );
}

LocalTaskAgentEvalScenario _externalLinkScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'external_link_and_completion_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _externalLinkUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateChecklistItems,
        expectedArgumentsSubset: {
          'items': [
            {'id': 'item-pr', 'isChecked': true},
          ],
        },
      ),
    ],
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['merged'],
      ['https://github.com/acme/portal/pull/482'],
      ['migration'],
    ],
    forbiddenReportTerms: const ['item-pr', 'task-release-portal'],
  );
}

LocalTaskAgentEvalScenario _latestDeadlineWinsScenario(
  LocalTaskAgentEvalPromptVariant variant,
) {
  return LocalTaskAgentEvalScenario(
    id: 'latest_deadline_wins_${variant.name}',
    systemPrompt: _buildEvalSystemPrompt(variant),
    userMessage: _latestDeadlineWinsUserMessage,
    expectedToolCalls: const [
      LocalTaskAgentExpectedToolCall(
        name: TaskAgentToolNames.updateTaskDueDate,
        expectedArgumentsSubset: {'dueDate': '2026-11-20'},
      ),
    ],
    promptVariant: variant,
    requiredReportTermGroups: const [
      ['2026-11-20', 'november 20'],
      ['customer conference'],
      ['procurement'],
    ],
  );
}

String _buildEvalSystemPrompt(
  LocalTaskAgentEvalPromptVariant variant, {
  String? evidenceSynthesisModelId,
  String? reportDirective,
}) {
  final version =
      AgentDomainEntity.agentTemplateVersion(
            id: 'melious-task-agent-eval-${variant.name}',
            agentId: 'melious-task-agent-eval',
            version: 1,
            status: AgentTemplateVersionStatus.active,
            directives: '',
            generalDirective:
                '$taskAgentGeneralDirective${_evalVariantDirective(variant)}',
            reportDirective:
                reportDirective ?? _reportDirectiveForVariant(variant),
            authoredBy: 'system',
            createdAt: DateTime.utc(2026, 7, 10),
            vectorClock: null,
          )
          as AgentTemplateVersionEntity;
  return TaskAgentPromptBuilder.buildSystemPrompt(
    version: version,
    soulVersion: _defaultTaskAgentEvalSoul,
    evidenceSynthesis:
        variant == LocalTaskAgentEvalPromptVariant.evidenceSynthesis,
    evidenceSynthesisModelId: evidenceSynthesisModelId,
  );
}

String _reportDirectiveForVariant(LocalTaskAgentEvalPromptVariant variant) =>
    variant == LocalTaskAgentEvalPromptVariant.conciseReport
    ? _conciseReportDirective
    : taskAgentReportDirective;

String _effectiveEvalReportDirective({
  required LocalTaskAgentEvalProfile profile,
  required LocalTaskAgentEvalScenario scenario,
}) {
  final configured =
      scenario.reportDirective ??
      _reportDirectiveForVariant(scenario.promptVariant);
  final isSeededContract = configured.trim() == taskAgentReportDirective.trim();
  return _usesEvidenceSynthesis(scenario.promptVariant) && isSeededContract
      ? TaskAgentEvidenceSynthesis.reportDirectiveForModel(
          profile.providerModelId,
        ).trim()
      : configured.trim();
}

String _evalVariantDirective(LocalTaskAgentEvalPromptVariant variant) {
  return switch (variant) {
    LocalTaskAgentEvalPromptVariant.production => '',
    LocalTaskAgentEvalPromptVariant.compactModel => _compactModelDirective,
    LocalTaskAgentEvalPromptVariant.qualityFocused => _qualityFocusedDirective,
    LocalTaskAgentEvalPromptVariant.conciseReport => '',
    LocalTaskAgentEvalPromptVariant.evidenceSynthesis => '',
  };
}

bool _usesEvidenceSynthesis(LocalTaskAgentEvalPromptVariant variant) =>
    variant == LocalTaskAgentEvalPromptVariant.evidenceSynthesis;

const _compactModelDirective = '''

## Compact-Model Execution Protocol

Follow this sequence exactly on every wake:
1. Extract only explicit facts and requested changes from the task context.
2. Call every necessary non-report tool before writing the report. Prefer one
   batch checklist call over several single-item calls.
3. Verify that each requested change has a matching successful tool response.
4. Call `update_report` exactly once as the final tool call. Never stop after
   metadata, checklist, or observation tools.

For checklist items, write concrete verb-first actions, preserve named owners,
and neither merge distinct actions nor invent new work. In the report, reflect
the current state after the proposed changes, include every material blocker
and deadline, omit internal IDs, and keep the TLDR factual and concise.
''';

const _qualityFocusedDirective = '''

## Report Quality Gate

Before calling `update_report`, verify all of the following:
- Describe the task's real-world state, not your own processing or tool calls.
  Never list "analyzed the note", "created the checklist", "updated metadata",
  or similar agent activity as an achievement.
- Do not add an H1/title or status banner. The task header already shows them.
- Write every heading and sentence in the task's `languageCode`; translate the
  standard section headings instead of leaving them in English.
- Omit empty sections completely, including an empty Links section.
- Omit explicitly deferred or rejected ideas from the public report unless they
  are a current blocker. Do not repeat them merely to say they were excluded.
- Include every current deadline, named owner, and blocker that materially
  affects the next action, while staying concise.

After any successful metadata or checklist mutation, do not stop. On a first
wake or whenever state materially changed, `update_report` is the required
final tool call.
''';

const _conciseReportDirective = '''
## Final report

Call `update_report` exactly once at the end of the wake. Do not finish with a
plain-text answer and do not describe your tool calls.

### `oneLiner`

Write a specific current-state tagline of at most 12 words. Do not use an
emoji, label, or sentence about what the agent did.

### `tldr`

In one or two concise sentences, state the current outcome and the most
important next action, deadline, or blocker. Do not repeat the one-liner and do
not use emojis.

### `content`

Write a compact current-state report in the task's `languageCode`. Do not add a
title because the task title is already visible. Include only sections that
contain useful, evidence-backed information:

- `## Progress`: meaningful completed outcomes, not analysis, transcription,
  checklist creation, metadata changes, or other agent activity.
- `## Next actions`: the few concrete pending actions that matter now. Do not
  reproduce the entire checklist when a shorter synthesis is clearer.
- `## Blockers`: only active blockers or delivery risks.
- `## Links`: only real external URLs from the task context, using descriptive
  Markdown link text.

Omit empty sections. Use human-readable labels instead of internal IDs. Every
claim must be evidence-backed and describe the current active task state.
Preserve user-completed work and user-set task fields.
''';

const _implicitWorkflowPlanUserMessage = '''
## Current Task Context
```json
{
  "id": "task-inference-profile-cleanup",
  "title": "Inference profile cleanup",
  "status": "IN PROGRESS",
  "priority": "P2",
  "languageCode": "en",
  "description": "Clean up inference profile seeding so empty profiles are no longer selectable.",
  "checklist": [],
  "log": [
    {
      "timestamp": "2026-07-12T10:09:00Z",
      "text": "In this task I need to clean up the inference profile seeding because there are too many empty profiles I can still choose from. Let's fix this and do the implementation, create a pull request, address the Gemini review comments, address the code review comments, merge the pull request, and then create a release on all platforms."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

## Changed Since Last Wake
The following entity IDs changed: task-inference-profile-cleanup

Analyze the current state and follow the wake protocol.
''';

const _germanPlanningUserMessage = '''
## Current Task Context
```json
{
  "id": "task-client-portal",
  "title": "Kundenportal Beta vorbereiten",
  "status": "IN PROGRESS",
  "priority": "P1",
  "dueDate": "2026-09-30",
  "languageCode": "de",
  "description": "Die Beta des Kundenportals bis Ende September vorbereiten.",
  "checklist": [],
  "log": [
    {
      "timestamp": "2026-07-10T08:45:00Z",
      "text": "Sprachnotiz: Also fuer die Beta am 30. September: zuerst mit Ben den API-Umfang klaeren. Dann den Figma-Prototyp fertig machen, danach die Anmeldung implementieren und Lea um den Security-Review bitten. Bitte mach daraus konkrete Checklisteneintraege."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

## Changed Since Last Wake
The following entity IDs changed: task-client-portal

Analyze the current state and execute the explicitly requested checklist
changes. Finish with the full user-facing report.
''';

const _progressUpdateUserMessage = '''
## Current Task Context
```json
{
  "id": "task-client-portal",
  "title": "Launch customer portal",
  "status": "IN PROGRESS",
  "priority": "P1",
  "dueDate": "2026-09-30",
  "languageCode": "en",
  "description": "Prepare and launch the customer portal.",
  "checklist": [
    {"id": "item-interviews", "title": "Interview five customers", "isChecked": false, "lastModifiedBy": "agent"},
    {"id": "item-legal", "title": "Complete legal review", "isChecked": false, "lastModifiedBy": "agent"}
  ],
  "log": [
    {
      "timestamp": "2026-07-10T09:00:00Z",
      "text": "All five customer interviews are complete, so check that item. Legal review is blocked while Dana confirms the retention clause. Move the launch deadline to October 15, 2026."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

## Changed Since Last Wake
The following entity IDs changed: task-client-portal

Apply only the explicit checklist and deadline changes. Preserve the legal
review as pending and report Dana's retention-clause blocker.
''';

const _noOpRefreshUserMessage = '''
## Current Task Context
```json
{
  "id": "task-tax-return",
  "title": "File 2025 tax return",
  "status": "DONE",
  "priority": "P1",
  "dueDate": "2026-07-31",
  "languageCode": "en",
  "checklist": [
    {"id": "tax-1", "title": "Upload signed return", "isChecked": true},
    {"id": "tax-2", "title": "Confirm submission receipt", "isChecked": true}
  ],
  "log": [
    {"timestamp": "2026-07-09T16:10:00Z", "text": "Submission receipt received. Task completed."}
  ]
}
```

## Previous Agent Report
```json
{
  "oneLiner": "2025 return filed and receipt confirmed",
  "tldr": "The signed return was submitted and the receipt is on file.",
  "content": "## Achieved\n- Return filed\n- Submission receipt confirmed"
}
```

## Changed Since Last Wake
The sync engine reported label-tax as changed. The task, checklist, and log are
identical to the previous wake.

Check whether the report or task needs any action. Do not republish unchanged
content.
''';

const _duplicateChecklistUserMessage = '''
## Current Task Context
```json
{
  "id": "task-expenses-q2",
  "title": "Submit Q2 expense report",
  "status": "IN PROGRESS",
  "languageCode": "en",
  "checklist": [
    {"id": "item-receipts", "title": "Email the Q2 receipts to Finance", "isChecked": false},
    {"id": "item-reconcile", "title": "Reconcile the card transactions", "isChecked": false}
  ],
  "log": [
    {
      "timestamp": "2026-07-10T07:40:00Z",
      "text": "Please make sure the checklist covers emailing the Q2 receipts to Finance, reconciling the card transactions, and submitting the expense report by Friday. Do not duplicate anything already there."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

Add only genuinely missing checklist work. Preserve the two existing items and
finish with the full report.
''';

const _staleDeadlineUserMessage = '''
## Current Task Context
```json
{
  "id": "task-mobile-release",
  "title": "Ship mobile release",
  "status": "IN PROGRESS",
  "dueDate": "2026-10-31",
  "languageCode": "en",
  "checklist": [
    {"id": "release-qa", "title": "Complete release QA", "isChecked": false}
  ],
  "log": [
    {"timestamp": "2026-06-01T09:00:00Z", "text": "Target October 15 for the release."},
    {"timestamp": "2026-07-09T14:00:00Z", "text": "I manually moved the release deadline to October 31. Keep that date."},
    {"timestamp": "2026-07-10T08:00:00Z", "text": "The updated app icon looks good on the dark home screen."}
  ],
  "recentUserDecisions": [
    {"field": "dueDate", "value": "2026-10-31", "decidedAt": "2026-07-09T14:00:00Z"}
  ]
}
```

## Previous Agent Report
```json
{
  "oneLiner": "Release QA underway for October 31",
  "tldr": "The release remains targeted for October 31; release QA is pending.",
  "content": "## What is left to do\n- Complete release QA"
}
```

## Changed Since Last Wake
Only the latest app-icon note is new.

Respect the user's latest manual deadline and avoid republishing an unchanged
report.
''';

const _messyGermanTranscriptUserMessage = '''
## Current Task Context
```json
{
  "id": "task-csv-export",
  "title": "CSV-Export stabilisieren",
  "status": "IN PROGRESS",
  "languageCode": "de",
  "checklist": [],
  "log": [
    {
      "timestamp": "2026-07-10T10:03:00Z",
      "text": "Sprachnotiz automatisch transkribiert: Aeh ja also wegen Export, ich glaub wir sollten irgendwann vielleicht auch noch Newsletter machen, aber das bitte noch nicht aufnehmen. Was wir wirklich tun muessen: den kaputten CSV-Export reparieren, Sam nach anonymisierten Testdaten fragen und danach den Regressionstest laufen lassen. Das sind die drei Punkte."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

Interpret the noisy transcript carefully. Add only the three committed actions,
not speculative future ideas, and publish the initial report in German.
''';

const _deferredScopeUserMessage = '''
## Current Task Context
```json
{
  "id": "task-signing-certificate",
  "title": "Rotate production signing certificate",
  "status": "IN PROGRESS",
  "languageCode": "en",
  "checklist": [],
  "log": [
    {
      "timestamp": "2026-07-10T14:00:00Z",
      "text": "We might build an administrator analytics dashboard someday, but leave that out for now. The active certificate work is: request the replacement certificate from Security, ask Priya for staging access, then rotate the certificate and verify webhook deliveries."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

Add the three active certificate-rotation actions as checklist items and publish
a focused report. The future product idea is outside the current task scope.
''';

const _activeDeploymentConstraintUserMessage = '''
## Current Task Context
```json
{
  "id": "task-retention-migration",
  "title": "Deploy retention policy migration",
  "status": "IN PROGRESS",
  "languageCode": "en",
  "checklist": [
    {"id": "item-rollback", "title": "Complete rollback test", "isChecked": false},
    {"id": "item-deploy", "title": "Deploy the retention migration", "isChecked": false}
  ],
  "log": [
    {
      "timestamp": "2026-07-10T15:00:00Z",
      "text": "The rollback test is complete, so check it off. Do not deploy until Legal approves the retention wording. Marta owns that approval; deployment remains pending."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

Apply the explicit completion while preserving deployment as pending. The Legal
approval gate is an active constraint and must remain visible in the report.
''';

const _userCompletedItemUserMessage = '''
## Current Task Context
```json
{
  "id": "task-offline-sync",
  "title": "Stabilize offline sync",
  "status": "IN PROGRESS",
  "languageCode": "en",
  "checklist": [
    {
      "id": "item-sync-fix",
      "title": "Fix duplicate sync events",
      "isChecked": true,
      "lastModifiedBy": "user",
      "lastModifiedAt": "2026-07-10T08:00:00Z"
    }
  ],
  "log": [
    {"timestamp": "2026-07-10T08:00:00Z", "text": "User checked Fix duplicate sync events."},
    {"timestamp": "2026-07-10T11:20:00Z", "text": "QA note: duplicate sync events reappeared once after reconnecting two devices. Investigation is needed; no root cause yet."}
  ]
}
```

## Previous Agent Report
```json
{
  "oneLiner": "Duplicate sync fix completed, monitoring remains",
  "tldr": "The duplicate-event fix is complete and awaiting validation.",
  "content": "## Achieved\n- Fixed duplicate sync events"
}
```

## Changed Since Last Wake
The QA note at 11:20 is new.

Do not override the user's checked state without an explicit request. Update the
report to surface the renewed sync risk and need for investigation.
''';

const _spanishMixedContextUserMessage = '''
## Current Task Context
```json
{
  "id": "task-facturacion",
  "title": "Activar facturacion electronica",
  "status": "IN PROGRESS",
  "languageCode": "es",
  "description": "Preparar la activacion con el proveedor externo.",
  "checklist": [],
  "log": [
    {
      "timestamp": "2026-07-10T09:30:00Z",
      "text": "Seguimos bloqueados porque el proveedor no ha enviado las credenciales. Anade dos pasos: llamar al proveedor para pedir las credenciales y confirmar con Marta la fecha de activacion."
    }
  ]
}
```

## Parent Project Context
```json
{
  "title": "Finance systems migration",
  "latestProjectAgentReport": {
    "tldr": "The migration is waiting for the external vendor.",
    "content": "Keep accounting stakeholders informed about activation risk."
  }
}
```

## First Wake - No prior report exists. Produce an initial report.

Create the requested checklist items and write the complete report in Spanish,
regardless of the English parent-project context.
''';

const _externalLinkUserMessage = '''
## Current Task Context
```json
{
  "id": "task-release-portal",
  "title": "Release portal migration",
  "status": "IN PROGRESS",
  "languageCode": "en",
  "checklist": [
    {"id": "item-pr", "title": "Merge the migration pull request", "isChecked": false},
    {"id": "item-deploy", "title": "Deploy the migration", "isChecked": false}
  ],
  "log": [
    {
      "timestamp": "2026-07-10T12:00:00Z",
      "text": "PR 482 was merged: https://github.com/acme/portal/pull/482 . Check off the merge item. Deployment is still pending until tomorrow's maintenance window."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

Apply the explicit completion, preserve deployment as pending, and include the
real pull-request URL in the report without exposing internal IDs.
''';

const _latestDeadlineWinsUserMessage = '''
## Current Task Context
```json
{
  "id": "task-enterprise-demo",
  "title": "Prepare enterprise demo",
  "status": "IN PROGRESS",
  "dueDate": "2026-10-15",
  "languageCode": "en",
  "checklist": [
    {"id": "demo-data", "title": "Prepare demo dataset", "isChecked": true},
    {"id": "demo-script", "title": "Finalize demo script", "isChecked": false}
  ],
  "log": [
    {"timestamp": "2026-02-01T09:00:00Z", "text": "Original target was September 30."},
    {"timestamp": "2026-04-12T09:00:00Z", "text": "Tentatively moved to October 15 while procurement reviews scope."},
    {"timestamp": "2026-06-02T09:00:00Z", "text": "Demo dataset is ready."},
    {"timestamp": "2026-07-08T13:00:00Z", "text": "Procurement confirmed the customer conference slot."},
    {"timestamp": "2026-07-10T13:15:00Z", "text": "Final decision: the customer conference demo is November 20, 2026. Move this task to that date. Procurement is confirmed; the demo script is the remaining work."}
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

Resolve the timeline using the newest explicit decision, update only the due
date, and publish a report focused on the confirmed conference and remaining
demo script.
''';

const _defaultProductionWakeUserMessage = '''
## Current Task Context
```json
{
  "id": "task-local-agent-eval-1",
  "title": "",
  "status": "OPEN",
  "priority": null,
  "estimate": null,
  "dueDate": null,
  "languageCode": "en",
  "description": "Evaluate whether an efficient task-agent model is usable in Lotti.",
  "checklist": [
    {"id": "check-1", "title": "Run a meaningful local app eval", "isChecked": false},
    {"id": "check-2", "title": "Compare the candidate against the reference model", "isChecked": false}
  ],
  "log": [
    {
      "timestamp": "2026-06-21T09:00:00Z",
      "text": "User asked: title this task Validate efficient task-agent model, make it P1, due July 4 2026, and estimate two and a half hours."
    },
    {
      "timestamp": "2026-06-21T09:05:00Z",
      "text": "The user is skeptical of shallow tool-call smoke reports and wants a real app-shaped local eval."
    }
  ]
}
```

## Parent Project Context
```json
{
  "id": "project-local-inference",
  "title": "Local inference reliability",
  "latestProjectAgentReport": {
    "tldr": "The current reference model is reliable. The candidate needs stronger validation before it is trusted.",
    "content": "Focus on runtime behavior that affects the Lotti task-agent workflow, not generic benchmark scores."
  }
}
```

## Linked Tasks
```json
{
  "linked_from": [],
  "linked_to": [
    {
      "id": "task-reference-baseline",
      "title": "Reference model baseline",
      "summaryStatus": "present",
      "latestTaskAgentReportOneLiner": "Reference model passes app-shaped task-agent checks",
      "latestTaskAgentReportTldr": "The reference model emits task metadata tools and a final report reliably."
    }
  ]
}
```

## First Wake - No prior report exists. Produce an initial report.

## Changed Since Last Wake
The following entity IDs changed: task-local-agent-eval-1

Analyze the current state, maintain any attention requests, and call tools if
needed. The user explicitly asked for the title, priority, due date, and
estimate changes in the task log. Do not change status. If the report would
materially change, call `update_report` with the full updated report; otherwise
finish with a brief plain-text note. Add observations if warranted.
''';

enum LocalTaskAgentEvalFailureCategory {
  none,
  emptyResponse,
  missingExpectedToolCall,
  invalidToolArguments,
  argumentMismatch,
  forbiddenToolCall,
  forbiddenToolArguments,
  unexpectedToolCall,
  missingReport,
  missingRequiredContent,
  forbiddenReportContent,
  missingReportRevision,
  invalidReportRevision,
  inferenceFailed,
}

double? parseLocalTaskAgentEvalTemperature(
  String? value, {
  String name = 'LOCAL_TASK_AGENT_EVAL_TEMPERATURE',
}) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = double.tryParse(value.trim());
  if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 2) {
    throw FormatException(
      'Expected $name to be a finite number in [0, 2], got "$value".',
      value,
    );
  }
  return parsed;
}

enum LocalTaskAgentEvalToolCallPhase { main, reportPass }

class LocalTaskAgentEvalToolCall {
  const LocalTaskAgentEvalToolCall({
    required this.name,
    required this.argumentsJson,
    this.phase = LocalTaskAgentEvalToolCallPhase.main,
  });

  final String name;
  final String argumentsJson;
  final LocalTaskAgentEvalToolCallPhase phase;

  Map<String, dynamic>? get jsonObjectArguments {
    try {
      final decoded = jsonDecode(argumentsJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool get hasJsonObjectArguments => jsonObjectArguments != null;

  bool containsExpectedArguments(Map<String, Object?> expectedArguments) {
    final arguments = jsonObjectArguments;
    if (arguments == null) return false;
    return _containsExpectedValues(arguments, expectedArguments);
  }

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'argumentsJson': argumentsJson,
      'argumentsJsonValid': hasJsonObjectArguments,
      'phase': phase.name,
    };
  }
}

class LocalTaskAgentEvalCaseResult {
  const LocalTaskAgentEvalCaseResult({
    required this.profile,
    required this.scenario,
    required this.provider,
    required this.latencyMs,
    required this.toolCalls,
    required this.failureCategory,
    this.inputTokens,
    this.outputTokens,
    this.thoughtsTokens,
    this.cachedInputTokens,
    this.finalContent,
    this.usedForcedReportRetry = false,
    this.reportEditorAttempts = 0,
    this.reportEditorValidationIssues = const [],
    this.errorMessage,
  });

  final LocalTaskAgentEvalProfile profile;
  final LocalTaskAgentEvalScenario scenario;
  final AiConfigInferenceProvider provider;
  final int latencyMs;
  final int? inputTokens;
  final int? outputTokens;
  final int? thoughtsTokens;
  final int? cachedInputTokens;
  final String? finalContent;
  final bool usedForcedReportRetry;
  final int reportEditorAttempts;
  final List<TaskAgentReportRevisionIssue> reportEditorValidationIssues;
  final String? errorMessage;
  final List<LocalTaskAgentEvalToolCall> toolCalls;
  final LocalTaskAgentEvalFailureCategory failureCategory;

  bool get passed => failureCategory == LocalTaskAgentEvalFailureCategory.none;

  LocalTaskAgentEvalToolCall? get reportToolCall {
    for (final call in toolCalls.reversed) {
      if (call.name == TaskAgentToolNames.updateReport) return call;
    }
    return null;
  }

  String get reportText => reportToolCall?.argumentsJson ?? '';

  int get qualityCheckCount =>
      scenario.requiredReportTermGroups.length +
      scenario.forbiddenReportTerms.length +
      scenario.forbiddenToolNames.length +
      scenario.requiredToolArgumentTermGroups.values.fold<int>(
        0,
        (sum, groups) => sum + groups.length,
      ) +
      scenario.forbiddenToolArgumentTerms.values.fold<int>(
        0,
        (sum, terms) => sum + terms.length,
      );

  int get passedQualityCheckCount {
    if (scenario.requiresReport && reportToolCall == null) return 0;
    final normalizedReport = reportText.toLowerCase();
    var passed = scenario.requiredReportTermGroups
        .where((group) => _containsAnyTerm(normalizedReport, group))
        .length;
    passed += scenario.forbiddenReportTerms
        .where((term) => !normalizedReport.contains(term.toLowerCase()))
        .length;
    passed += scenario.forbiddenToolNames
        .where((name) => toolCalls.every((call) => call.name != name))
        .length;
    for (final entry in scenario.requiredToolArgumentTermGroups.entries) {
      final arguments = toolCalls
          .where((call) => call.name == entry.key)
          .map((call) => call.argumentsJson)
          .join('\n')
          .toLowerCase();
      passed += entry.value
          .where((group) => _containsAnyTerm(arguments, group))
          .length;
    }
    for (final entry in scenario.forbiddenToolArgumentTerms.entries) {
      final arguments = toolCalls
          .where((call) => call.name == entry.key)
          .map((call) => call.argumentsJson)
          .join('\n')
          .toLowerCase();
      passed += entry.value
          .where((term) => !arguments.contains(term.toLowerCase()))
          .length;
    }
    return passed;
  }

  double get qualityScore =>
      qualityCheckCount == 0 ? 1 : passedQualityCheckCount / qualityCheckCount;

  Map<String, Object?> toJson() {
    return {
      'profileName': profile.name,
      'providerModelId': profile.providerModelId,
      'modelClass': profile.modelClass,
      'scenarioId': scenario.id,
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'latencyMs': latencyMs,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'thoughtsTokens': thoughtsTokens,
      'cachedInputTokens': cachedInputTokens,
      'finalContentLength': finalContent?.length ?? 0,
      'toolCallCount': toolCalls.length,
      'toolCallNames': toolCalls.map((call) => call.name).toList(),
      'expectedToolNames': scenario.expectedToolCalls
          .map((call) => call.name)
          .toList(),
      'failureCategory': failureCategory.name,
      'qualityChecksPassed': passedQualityCheckCount,
      'qualityCheckCount': qualityCheckCount,
      'qualityScore': qualityScore,
      'finalContent': finalContent,
      'usedForcedReportRetry': usedForcedReportRetry,
      'reportEditorAttempts': reportEditorAttempts,
      'reportEditorValidationIssues': reportEditorValidationIssues
          .map((issue) => issue.name)
          .toList(),
      'errorMessage': errorMessage,
      'toolCalls': toolCalls.map((call) => call.toJson()).toList(),
    };
  }
}

class LocalTaskAgentEvalReport {
  const LocalTaskAgentEvalReport({
    required this.provider,
    required this.profiles,
    required this.scenarios,
    required this.results,
    required this.temperature,
    required this.executionMode,
    this.reasoningEffort,
    this.reportEditorModelId,
    this.reportEditorMaxAttempts = 1,
  });

  final AiConfigInferenceProvider provider;
  final List<LocalTaskAgentEvalProfile> profiles;
  final List<LocalTaskAgentEvalScenario> scenarios;
  final List<LocalTaskAgentEvalCaseResult> results;
  final double temperature;
  final LocalTaskAgentEvalExecutionMode executionMode;
  final ReasoningEffort? reasoningEffort;
  final String? reportEditorModelId;
  final int reportEditorMaxAttempts;

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 6,
      'kind': localTaskAgentEvalKind,
      'temperature': temperature,
      'executionMode': executionMode.name,
      'reasoningEffort': reasoningEffort?.name,
      'reportEditorModelId': reportEditorModelId,
      'reportEditorMaxAttempts': reportEditorMaxAttempts,
      'provider': {
        'id': provider.id,
        'name': provider.name,
        'type': provider.inferenceProviderType.name,
        'baseUrl': provider.baseUrl,
      },
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'scenarios': scenarios.map((scenario) => scenario.toJson()).toList(),
      'results': results.map((result) => result.toJson()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Local Task-Agent Inference Eval')
      ..writeln()
      ..writeln(
        'Provider: `${provider.name}` (${provider.inferenceProviderType.name}) '
        'at `${provider.baseUrl}`',
      )
      ..writeln(
        'Execution: `${executionMode.name}` at temperature `$temperature`; '
        'reasoning effort `${reasoningEffort?.name ?? 'modelDefault'}`; '
        'report editor `${reportEditorModelId ?? 'profileModel'}` '
        '(max attempts `$reportEditorMaxAttempts`)',
      )
      ..writeln()
      ..writeln(
        '| Profile | Model | Scenario | Prompt | Pass | Quality | Retry | Latency | Tool calls | Failure |',
      )
      ..writeln(
        '| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |',
      );

    for (final result in results) {
      final toolNames = result.toolCalls.map((call) => call.name).join(', ');
      buffer.writeln(
        '| ${result.profile.name} | `${result.profile.providerModelId}` | '
        '${result.scenario.id} | ${result.scenario.promptVariant.name} | '
        '${result.passed ? 'yes' : 'no'} | '
        '${(result.qualityScore * 100).round()}% | '
        '${result.usedForcedReportRetry ? 'yes' : 'no'} | '
        '${result.latencyMs} ms | ${toolNames.isEmpty ? '-' : toolNames} | '
        '${result.failureCategory.name} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Case Details');
    for (final result in results) {
      buffer
        ..writeln()
        ..writeln(
          '### ${result.profile.name} / ${result.scenario.id}',
        )
        ..writeln()
        ..writeln(
          'Deterministic quality: ${result.passedQualityCheckCount}/'
          '${result.qualityCheckCount}.',
        );
      if (result.finalContent case final content? when content.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('Final assistant content:')
          ..writeln()
          ..writeln('```text')
          ..writeln(content)
          ..writeln('```');
      }
      for (final call in result.toolCalls) {
        buffer
          ..writeln()
          ..writeln('`${call.phase.name}` / `${call.name}`')
          ..writeln()
          ..writeln('```json')
          ..writeln(call.argumentsJson)
          ..writeln('```');
      }
    }

    final failures = results.where((result) => !result.passed);
    if (failures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Failures');
      for (final result in failures) {
        buffer.writeln(
          '- `${result.profile.name}` / `${result.scenario.id}`: '
          '${result.failureCategory.name}',
        );
      }
    }

    return buffer.toString();
  }
}

class LocalTaskAgentInferenceEvalRunner {
  LocalTaskAgentInferenceEvalRunner({
    required this.provider,
    required this.conversationRepository,
    required this.inferenceRepository,
    this.temperature = 0.3,
    this.forceReportRetry = true,
    this.executionMode = LocalTaskAgentEvalExecutionMode.singlePass,
    this.reasoningEffort,
    this.reportEditorModelId,
    this.reportEditorMaxAttempts = 1,
  }) : assert(
         reportEditorMaxAttempts >= 1 && reportEditorMaxAttempts <= 3,
         'reportEditorMaxAttempts must be between 1 and 3.',
       );

  final AiConfigInferenceProvider provider;
  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final double temperature;
  final bool forceReportRetry;
  final LocalTaskAgentEvalExecutionMode executionMode;
  final ReasoningEffort? reasoningEffort;
  final String? reportEditorModelId;
  final int reportEditorMaxAttempts;

  String? get _effectiveReportEditorModelId =>
      executionMode == LocalTaskAgentEvalExecutionMode.productionRouting
      ? meliousQwen35122BA10BModelId
      : reportEditorModelId;

  int get _effectiveReportEditorMaxAttempts =>
      executionMode == LocalTaskAgentEvalExecutionMode.productionRouting
      ? TaskAgentReportEditor.productionMaxAttempts
      : reportEditorMaxAttempts;

  Future<LocalTaskAgentEvalReport> run({
    required List<LocalTaskAgentEvalProfile> profiles,
    required List<LocalTaskAgentEvalScenario> scenarios,
  }) async {
    final results = <LocalTaskAgentEvalCaseResult>[];
    for (final profile in profiles) {
      for (final scenario in scenarios) {
        try {
          results.add(await _runScenario(profile, scenario));
        } catch (error) {
          results.add(
            _inferenceFailedResult(
              profile: profile,
              scenario: scenario,
              latencyMs: 0,
              toolCalls: const [],
              error: error,
            ),
          );
        }
      }
    }
    return LocalTaskAgentEvalReport(
      provider: provider,
      profiles: profiles,
      scenarios: scenarios,
      results: results,
      temperature: temperature,
      executionMode: executionMode,
      reasoningEffort: reasoningEffort,
      reportEditorModelId: _effectiveReportEditorModelId,
      reportEditorMaxAttempts: _effectiveReportEditorMaxAttempts,
    );
  }

  _LocalTaskAgentProductionRoute _productionReportRoute(
    LocalTaskAgentEvalProfile profile,
  ) {
    if (provider.inferenceProviderType != InferenceProviderType.melious) {
      return _LocalTaskAgentProductionRoute.none;
    }
    return switch (profile.providerModelId.toLowerCase()) {
      meliousMistralSmall4119BInstructModelId =>
        _LocalTaskAgentProductionRoute.mistralWithQwen,
      meliousQwen35122BA10BModelId => _LocalTaskAgentProductionRoute.directQwen,
      _ => _LocalTaskAgentProductionRoute.none,
    };
  }

  Future<LocalTaskAgentEvalCaseResult> _runScenario(
    LocalTaskAgentEvalProfile profile,
    LocalTaskAgentEvalScenario scenario,
  ) async {
    final stopwatch = Stopwatch()..start();
    final strategy = _LocalTaskAgentEvalStrategy(scenario: scenario);
    final systemPrompt = _usesEvidenceSynthesis(scenario.promptVariant)
        ? _buildEvalSystemPrompt(
            scenario.promptVariant,
            evidenceSynthesisModelId: profile.providerModelId,
            reportDirective: scenario.reportDirective,
          )
        : scenario.systemPrompt;
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns:
          scenario.maxTurns +
          (executionMode == LocalTaskAgentEvalExecutionMode.singlePass ? 0 : 1),
    );
    final manager = conversationRepository.getConversation(conversationId);

    try {
      try {
        final allTools = buildLocalTaskAgentEvalTools(
          promptVariant: scenario.promptVariant,
        );
        final mutationTools =
            executionMode == LocalTaskAgentEvalExecutionMode.twoPass
            ? allTools
                  .where(
                    (tool) =>
                        tool.function.name != TaskAgentToolNames.updateReport,
                  )
                  .toList(growable: false)
            : allTools;
        var usage = await conversationRepository.sendMessage(
          conversationId: conversationId,
          message: scenario.userMessage,
          model: profile.providerModelId,
          provider: provider,
          inferenceRepo: inferenceRepository,
          tools: mutationTools,
          temperature: temperature,
          strategy: strategy,
        );
        var usedForcedReportRetry = false;
        var reportRevisionCompleted = true;
        var reportRevisionValid = true;
        var reportEditorAttempts = 0;
        var reportEditorValidationIssues = <TaskAgentReportRevisionIssue>[];
        void includeUsage(InferenceUsage? additionalUsage) {
          if (additionalUsage == null) return;
          final currentUsage = usage;
          usage = currentUsage == null
              ? additionalUsage
              : currentUsage.merge(additionalUsage);
        }

        void applyEditResult(_LocalTaskAgentReportEditingResult editResult) {
          reportRevisionCompleted = editResult.completed;
          reportEditorValidationIssues = editResult.validationIssues;
          reportRevisionValid = reportEditorValidationIssues.isEmpty;
          reportEditorAttempts = editResult.attempts;
          includeUsage(editResult.usage);
        }

        Future<void> runForcedReportPass(String message) async {
          usedForcedReportRetry = true;
          strategy.beginReportPass();
          final retryUsage = await conversationRepository.sendMessage(
            conversationId: conversationId,
            message: message,
            model: profile.providerModelId,
            provider: provider,
            inferenceRepo: inferenceRepository,
            tools: allTools
                .where(
                  (tool) =>
                      tool.function.name == TaskAgentToolNames.updateReport,
                )
                .toList(growable: false),
            toolChoice: const ChatCompletionToolChoiceOption.tool(
              ChatCompletionNamedToolChoice(
                type: ChatCompletionNamedToolChoiceType.function,
                function: ChatCompletionFunctionCallOption(
                  name: TaskAgentToolNames.updateReport,
                ),
              ),
            ),
            temperature: temperature,
            strategy: strategy,
          );
          includeUsage(retryUsage);
        }

        final plannedReportPass =
            executionMode == LocalTaskAgentEvalExecutionMode.twoPass &&
            scenario.requiresReport;
        final plannedReportRevision =
            executionMode == LocalTaskAgentEvalExecutionMode.reportRevision &&
            scenario.requiresReport &&
            strategy.hasReport;
        final plannedReportEditing =
            executionMode == LocalTaskAgentEvalExecutionMode.reportEditing &&
            scenario.requiresReport &&
            strategy.hasReport;
        final plannedProductionRouting =
            executionMode == LocalTaskAgentEvalExecutionMode.productionRouting;
        final recoverMissingInitialReport =
            forceReportRetry &&
            scenario.isFirstWake &&
            scenario.requiresReport &&
            !strategy.hasReport;
        if (plannedProductionRouting) {
          if (recoverMissingInitialReport) {
            await runForcedReportPass(_missingInitialReportPrompt);
          }
          final route = _productionReportRoute(profile);
          if (scenario.requiresReport && strategy.hasReport) {
            final materialTaskState = buildLocalTaskAgentEvalMaterialTaskState(
              strategy.toolCalls,
              currentDueDate: scenario.currentDueDate,
              currentEstimateMinutes: scenario.currentEstimateMinutes,
              currentPriority: scenario.currentPriority,
            );
            final initialValidationIssues =
                route == _LocalTaskAgentProductionRoute.directQwen
                ? TaskAgentReportEditor.detectDirectQwenRegressions(
                    languageCode:
                        materialTaskState['languageCode'] as String? ??
                        scenario.languageCode,
                    materialTaskState: materialTaskState,
                    report: strategy.latestReportArguments!,
                  ).toSet()
                : const <TaskAgentReportRevisionIssue>{};
            if (route == _LocalTaskAgentProductionRoute.mistralWithQwen ||
                initialValidationIssues.isNotEmpty) {
              usedForcedReportRetry = true;
              applyEditResult(
                await _editReport(
                  profile: profile,
                  scenario: scenario,
                  strategy: strategy,
                  initialValidationIssues: initialValidationIssues,
                ),
              );
            }
          }
        } else if (plannedReportEditing) {
          usedForcedReportRetry = true;
          applyEditResult(
            await _editReport(
              profile: profile,
              scenario: scenario,
              strategy: strategy,
            ),
          );
        } else if (plannedReportPass ||
            plannedReportRevision ||
            recoverMissingInitialReport) {
          await runForcedReportPass(
            plannedReportRevision
                ? 'Audit the `update_report` draft you just produced against '
                      'the original task context. Rebuild its public fact set '
                      'from evidence before writing. Use `pending` unless the '
                      'source explicitly records that work started, and treat '
                      'a checked item as only user-marked complete unless a '
                      'real-world outcome is stated. Include only facts tied '
                      'to current actions or active constraints; do not '
                      'discuss source filtering. Replace the draft by calling '
                      '`update_report` exactly once with a distinct concise '
                      '`oneLiner`, `tldr`, and free-form markdown `content`. '
                      'Do not respond with anything else.'
                : plannedReportPass
                ? 'The mutation phase is complete. Review the original task '
                      'context and all tool results, then call `update_report` '
                      'exactly once. Supply a concise `oneLiner`, a 1-3 '
                      'sentence `tldr`, and the full markdown `content`. '
                      'Describe the resulting task state and current next '
                      'actions, not your tool usage. Do not respond with '
                      'anything else.'
                : _missingInitialReportPrompt,
          );
        }

        stopwatch.stop();

        var finalContent = _extractFinalAssistantContent(manager);
        final classifiedFailure = !reportRevisionCompleted
            ? LocalTaskAgentEvalFailureCategory.missingReportRevision
            : !reportRevisionValid
            ? LocalTaskAgentEvalFailureCategory.invalidReportRevision
            : _classifyResult(
                scenario: scenario,
                toolCalls: strategy.toolCalls,
                finalContent: finalContent,
                hasReport: strategy.hasReport,
              );
        final failureCategory =
            classifiedFailure ==
                    LocalTaskAgentEvalFailureCategory.emptyResponse &&
                usage == null &&
                !_hasAssistantMessage(manager)
            ? LocalTaskAgentEvalFailureCategory.inferenceFailed
            : classifiedFailure;
        if (failureCategory ==
                LocalTaskAgentEvalFailureCategory.inferenceFailed &&
            finalContent == null) {
          finalContent =
              manager?.lastError ??
              'Inference failed before the model returned a response.';
        }

        return LocalTaskAgentEvalCaseResult(
          profile: profile,
          scenario: scenario,
          provider: provider,
          latencyMs: stopwatch.elapsedMilliseconds,
          inputTokens: usage?.inputTokens,
          outputTokens: usage?.outputTokens,
          thoughtsTokens: usage?.thoughtsTokens,
          cachedInputTokens: usage?.cachedInputTokens,
          finalContent: finalContent,
          usedForcedReportRetry: usedForcedReportRetry,
          reportEditorAttempts: reportEditorAttempts,
          reportEditorValidationIssues: reportEditorValidationIssues,
          errorMessage: manager?.lastError,
          toolCalls: strategy.toolCalls,
          failureCategory: failureCategory,
        );
      } catch (error) {
        stopwatch.stop();
        return _inferenceFailedResult(
          profile: profile,
          scenario: scenario,
          latencyMs: stopwatch.elapsedMilliseconds,
          toolCalls: strategy.toolCalls,
          error: error,
        );
      }
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }

  Future<_LocalTaskAgentReportEditingResult> _editReport({
    required LocalTaskAgentEvalProfile profile,
    required LocalTaskAgentEvalScenario scenario,
    required _LocalTaskAgentEvalStrategy strategy,
    Set<TaskAgentReportRevisionIssue> initialValidationIssues = const {},
  }) async {
    final materialTaskState = buildLocalTaskAgentEvalMaterialTaskState(
      strategy.toolCalls,
      currentDueDate: scenario.currentDueDate,
      currentEstimateMinutes: scenario.currentEstimateMinutes,
      currentPriority: scenario.currentPriority,
    );
    final result =
        await TaskAgentReportEditor(
          conversationRepository: conversationRepository,
          inferenceRepository: inferenceRepository,
          provider: provider,
          modelId: _effectiveReportEditorModelId ?? profile.providerModelId,
          maxAttempts: _effectiveReportEditorMaxAttempts,
          temperature: temperature,
        ).edit(
          draft: TaskAgentReportDraft.fromJson(
            strategy.latestReportArguments!,
          )!,
          languageCode: scenario.languageCode,
          materialTaskState: materialTaskState,
          reportDirective: _effectiveEvalReportDirective(
            profile: profile,
            scenario: scenario,
          ),
          initialValidationIssues: initialValidationIssues,
        );
    final revision = result.revision;
    if (revision != null) {
      strategy.recordEditedReport(revision);
    }

    return _LocalTaskAgentReportEditingResult(
      completed: result.hadRevision,
      attempts: result.attempts,
      validationIssues: result.validationIssues,
      usage: result.usage,
    );
  }

  LocalTaskAgentEvalCaseResult _inferenceFailedResult({
    required LocalTaskAgentEvalProfile profile,
    required LocalTaskAgentEvalScenario scenario,
    required int latencyMs,
    required List<LocalTaskAgentEvalToolCall> toolCalls,
    required Object error,
  }) {
    return LocalTaskAgentEvalCaseResult(
      profile: profile,
      scenario: scenario,
      provider: provider,
      latencyMs: latencyMs,
      finalContent: 'Inference failed with exception: $error',
      errorMessage: error.toString(),
      toolCalls: toolCalls,
      failureCategory: LocalTaskAgentEvalFailureCategory.inferenceFailed,
    );
  }
}

class _LocalTaskAgentReportEditingResult {
  const _LocalTaskAgentReportEditingResult({
    required this.completed,
    required this.attempts,
    required this.validationIssues,
    required this.usage,
  });

  final bool completed;
  final int attempts;
  final List<TaskAgentReportRevisionIssue> validationIssues;
  final InferenceUsage? usage;
}

class _LocalTaskAgentEvalStrategy extends ConversationStrategy {
  _LocalTaskAgentEvalStrategy({required this.scenario});

  final LocalTaskAgentEvalScenario scenario;
  final _toolCalls = <LocalTaskAgentEvalToolCall>[];
  LocalTaskAgentEvalToolCallPhase _phase = LocalTaskAgentEvalToolCallPhase.main;
  bool hasReport = false;

  List<LocalTaskAgentEvalToolCall> get toolCalls =>
      List.unmodifiable(_toolCalls);

  Map<String, dynamic>? get latestReportArguments {
    for (final call in _toolCalls.reversed) {
      if (call.name == TaskAgentToolNames.updateReport) {
        final arguments = call.jsonObjectArguments;
        if (arguments != null &&
            _hasNonEmptyString(arguments, 'oneLiner') &&
            _hasNonEmptyString(arguments, 'tldr') &&
            _hasNonEmptyString(arguments, 'content')) {
          return arguments;
        }
      }
    }
    return null;
  }

  void beginReportPass() {
    _phase = LocalTaskAgentEvalToolCallPhase.reportPass;
  }

  void recordEditedReport(TaskAgentReportDraft report) {
    _toolCalls.add(
      LocalTaskAgentEvalToolCall(
        name: TaskAgentToolNames.updateReport,
        argumentsJson: jsonEncode(report.toJson()),
        phase: LocalTaskAgentEvalToolCallPhase.reportPass,
      ),
    );
    hasReport = true;
  }

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      final recorded = LocalTaskAgentEvalToolCall(
        name: call.function.name,
        argumentsJson: call.function.arguments,
        phase: _phase,
      );
      _toolCalls.add(recorded);

      final args = recorded.jsonObjectArguments;
      final response = args == null
          ? 'Eval harness rejected invalid JSON arguments.'
          : 'Eval harness accepted ${call.function.name}.';
      if (call.function.name == TaskAgentToolNames.updateReport &&
          args != null &&
          _hasNonEmptyString(args, 'oneLiner') &&
          _hasNonEmptyString(args, 'tldr') &&
          _hasNonEmptyString(args, 'content')) {
        hasReport = true;
      }

      manager.addToolResponse(
        toolCallId: call.id,
        response: response,
      );
    }

    return hasReport
        ? ConversationAction.complete
        : ConversationAction.continueConversation;
  }

  // ConversationRepository enforces the turn limit directly and does not call
  // this legacy strategy hook.
  // coverage:ignore-start
  @override
  bool shouldContinue(ConversationManager manager) => manager.canContinue();
  // coverage:ignore-end

  @override
  String? getContinuationPrompt(ConversationManager manager) {
    if (hasReport) return null;
    return 'Continue. If you have finished your analysis, call '
        '`update_report` with `oneLiner`, `tldr`, and `content` if the '
        'report would materially change; otherwise finish with a brief '
        'plain-text note.';
  }
}

LocalTaskAgentEvalFailureCategory _classifyResult({
  required LocalTaskAgentEvalScenario scenario,
  required List<LocalTaskAgentEvalToolCall> toolCalls,
  required String? finalContent,
  required bool hasReport,
}) {
  if (toolCalls.isEmpty && (finalContent == null || finalContent.isEmpty)) {
    return LocalTaskAgentEvalFailureCategory.emptyResponse;
  }

  if (toolCalls.any((call) => !call.hasJsonObjectArguments)) {
    return LocalTaskAgentEvalFailureCategory.invalidToolArguments;
  }

  if (toolCalls.any(
    (call) => scenario.forbiddenToolNames.contains(call.name),
  )) {
    return LocalTaskAgentEvalFailureCategory.forbiddenToolCall;
  }

  final expectedNames = scenario.expectedToolCalls
      .map((expected) => expected.name)
      .toSet();
  final allowedNames = {...expectedNames, ...scenario.allowedExtraToolNames};
  if (toolCalls.any((call) => !allowedNames.contains(call.name))) {
    return LocalTaskAgentEvalFailureCategory.unexpectedToolCall;
  }

  for (final expected in scenario.expectedToolCalls) {
    final matchingCalls = toolCalls
        .where((call) => call.name == expected.name)
        .toList(growable: false);
    if (matchingCalls.isEmpty) {
      return LocalTaskAgentEvalFailureCategory.missingExpectedToolCall;
    }
    if (expected.expectedArgumentsSubset.isNotEmpty &&
        !matchingCalls.any(
          (call) => call.containsExpectedArguments(
            expected.expectedArgumentsSubset,
          ),
        )) {
      return LocalTaskAgentEvalFailureCategory.argumentMismatch;
    }
  }

  if (scenario.requiresReport && !hasReport) {
    return LocalTaskAgentEvalFailureCategory.missingReport;
  }

  final reportText =
      _latestReportCall(toolCalls)?.argumentsJson.toLowerCase() ?? '';
  if (scenario.requiredReportTermGroups.any(
    (group) => !_containsAnyTerm(reportText, group),
  )) {
    return LocalTaskAgentEvalFailureCategory.missingRequiredContent;
  }
  if (scenario.forbiddenReportTerms.any(
    (term) => reportText.contains(term.toLowerCase()),
  )) {
    return LocalTaskAgentEvalFailureCategory.forbiddenReportContent;
  }
  for (final entry in scenario.requiredToolArgumentTermGroups.entries) {
    final arguments = toolCalls
        .where((call) => call.name == entry.key)
        .map((call) => call.argumentsJson)
        .join('\n')
        .toLowerCase();
    if (entry.value.any((group) => !_containsAnyTerm(arguments, group))) {
      return LocalTaskAgentEvalFailureCategory.missingRequiredContent;
    }
  }
  for (final entry in scenario.forbiddenToolArgumentTerms.entries) {
    final arguments = toolCalls
        .where((call) => call.name == entry.key)
        .map((call) => call.argumentsJson)
        .join('\n')
        .toLowerCase();
    if (entry.value.any((term) => arguments.contains(term.toLowerCase()))) {
      return LocalTaskAgentEvalFailureCategory.forbiddenToolArguments;
    }
  }

  return LocalTaskAgentEvalFailureCategory.none;
}

bool _containsAnyTerm(String normalizedText, List<String> terms) {
  return terms.any((term) => normalizedText.contains(term.toLowerCase()));
}

LocalTaskAgentEvalToolCall? _latestReportCall(
  List<LocalTaskAgentEvalToolCall> toolCalls,
) {
  for (final call in toolCalls.reversed) {
    if (call.name == TaskAgentToolNames.updateReport) return call;
  }
  return null;
}

bool _hasAssistantMessage(ConversationManager? manager) {
  if (manager == null) return false;
  return manager.messages.any(
    (message) => message.role == ChatCompletionMessageRole.assistant,
  );
}

String? _extractFinalAssistantContent(ConversationManager? manager) {
  if (manager == null) return null;
  for (final message in manager.messages.reversed) {
    if (message case ChatCompletionMessage(
      role: ChatCompletionMessageRole.assistant,
    )) {
      final content = message.mapOrNull(
        assistant: (message) => message.content,
      );
      if (content != null && content.isNotEmpty) return content;
    }
  }
  return null;
}

bool _hasNonEmptyString(Map<String, dynamic> args, String key) {
  final value = args[key];
  return value is String && value.trim().isNotEmpty;
}

bool _containsExpectedValues(
  Map<String, dynamic> actual,
  Map<String, Object?> expected,
) {
  for (final entry in expected.entries) {
    if (!actual.containsKey(entry.key)) return false;
    if (!_matchesExpectedValue(actual[entry.key], entry.value)) return false;
  }
  return true;
}

bool _matchesExpectedValue(Object? actual, Object? expected) {
  if (expected is Map<String, Object?>) {
    return actual is Map<String, dynamic> &&
        _containsExpectedValues(actual, expected);
  }
  if (expected is List<Object?>) {
    if (actual is! List || actual.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (!_matchesExpectedValue(actual[i], expected[i])) return false;
    }
    return true;
  }
  return actual == expected;
}
