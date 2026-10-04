import 'dart:convert';

import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/util/forced_tool_choice.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_agent_report_editor_task_agent_report_capture_strategy_part.dart';
part 'task_agent_report_editor_rules.dart';

/// Isolated, bounded report editor for the efficient task-agent routes.
class TaskAgentReportEditor {
  TaskAgentReportEditor({
    required this.conversationRepository,
    required this.inferenceRepository,
    required this.provider,
    this.modelId = meliousQwen35122BA10BModelId,
    this.maxAttempts = productionMaxAttempts,
    this.temperature = 0,
  }) {
    if (maxAttempts < 1 || maxAttempts > productionMaxAttempts) {
      throw ArgumentError.value(
        maxAttempts,
        'maxAttempts',
        'must be between 1 and $productionMaxAttempts',
      );
    }
  }

  /// Production bound: one initial candidate and at most two repairs.
  static const productionMaxAttempts = 3;

  /// The route a report written by [modelId] takes.
  ///
  /// The one place this is decided, so the task workflow and the evaluation
  /// that mirrors it cannot drift apart. Only Melious executors are routed:
  /// the editor itself runs on a Melious model.
  static TaskAgentReportRoute routeFor({
    required InferenceProviderType providerType,
    required String modelId,
  }) {
    if (providerType != InferenceProviderType.melious) {
      return TaskAgentReportRoute.none;
    }
    final normalized = modelId.toLowerCase();
    if (normalized == meliousMistralSmall4119BInstructModelId) {
      return TaskAgentReportRoute.alwaysEdited;
    }
    if (normalized == meliousQwen35122BA10BModelId) {
      return TaskAgentReportRoute.detected;
    }
    return TaskAgentReportRoute.none;
  }

  /// Prefix used for persisted, internal editor-route outcomes.
  static const auditToolPrefix = 'qwen_report_editor';

  final ConversationRepository conversationRepository;
  final InferenceRepositoryInterface inferenceRepository;
  final AiConfigInferenceProvider provider;

  /// Provider-native model used for the report-only pass.
  final String modelId;

  /// Maximum number of isolated candidate attempts.
  final int maxAttempts;

  /// Sampling temperature for the report-only pass.
  final double temperature;

  /// Whether the validated editor path applies to this executor/provider pair.
  static bool supports({
    required String executorModelId,
    required InferenceProviderType providerType,
  }) =>
      routeFor(providerType: providerType, modelId: executorModelId) ==
      TaskAgentReportRoute.alwaysEdited;

  /// Rewrites [draft] from compact, ID-free task facts.
  Future<TaskAgentReportEditResult> edit({
    required TaskAgentReportDraft draft,
    required String languageCode,
    required Map<String, Object?> materialTaskState,
    required String reportDirective,
    Set<TaskAgentReportRevisionIssue> initialValidationIssues = const {},
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
  }) async {
    final draftJson = draft.toJson();
    final excludedDraftTerms = _extractExcludedDraftTerms(draftJson);
    var editorDraft = excludedDraftTerms.isEmpty
        ? draftJson
        : _withoutExcludedDraftScope(draftJson);
    final hasUnperformedRequest = _hasUnperformedRequestItem(
      materialTaskState,
    );
    if (hasUnperformedRequest &&
        initialValidationIssues.contains(
          TaskAgentReportRevisionIssue.processNarration,
        )) {
      editorDraft = _withoutUngroundedStateClauses(
        editorDraft,
        materialTaskState,
      );
    }
    if (initialValidationIssues.contains(
      TaskAgentReportRevisionIssue.checkmarkCausality,
    )) {
      editorDraft = _withoutCheckmarkCausalityClauses(
        editorDraft,
        languageCode,
      );
    }
    var attempts = 0;
    var hadRevision = false;
    var validationIssues = initialValidationIssues.toList(growable: false);
    var rejectedReport = initialValidationIssues.isEmpty ? null : draft;
    InferenceUsage? usage;

    while (attempts < maxAttempts) {
      final isRepair = validationIssues.isNotEmpty;
      final conversationId = conversationRepository.createConversation(
        systemMessage: isRepair
            ? '$_systemPrompt\n\n'
                  'The previous candidate matched known regression checks. '
                  'Rewrite it again from the sanitized draft, material task '
                  'state, and report directive. Fix every listed violation. '
                  'Do not defend the candidate or mention the corrections.'
            : _systemPrompt,
        maxTurns: 2,
      );
      final strategy = _TaskAgentReportCaptureStrategy();
      final rejectedReportJson = rejectedReport?.toJson();
      final message = <String, Object?>{
        'languageCode': languageCode,
        'materialTaskState': materialTaskState,
        'draftReport': editorDraft,
        'reportDirective': reportDirective.trim(),
        if (isRepair) ...{
          if (rejectedReportJson != null &&
              !validationIssues.contains(
                TaskAgentReportRevisionIssue.deferredScopeLeak,
              ) &&
              !(hasUnperformedRequest &&
                  validationIssues.contains(
                    TaskAgentReportRevisionIssue.processNarration,
                  )) &&
              !validationIssues.contains(
                TaskAgentReportRevisionIssue.checkmarkCausality,
              ))
            'rejectedReport': _withoutExcludedDraftScope(rejectedReportJson),
          'requiredCorrections': [
            for (final issue in validationIssues)
              {
                'code': issue.name,
                'instruction': _repairInstruction(
                  issue,
                  materialTaskState,
                ),
              },
          ],
        },
      };

      Object? attemptError;
      StackTrace? attemptStackTrace;
      try {
        final attemptUsage = await conversationRepository.sendMessage(
          conversationId: conversationId,
          message: jsonEncode(message),
          model: modelId,
          provider: provider,
          inferenceRepo: inferenceRepository,
          tools: [buildTool(languageCode: languageCode)],
          toolChoice: forcedToolChoiceFor(
            modelId: modelId,
            toolName: TaskAgentToolNames.updateReport,
          ),
          temperature: temperature,
          strategy: strategy,
          consumptionAgentId: consumptionAgentId,
          consumptionTaskId: consumptionTaskId,
          consumptionCategoryId: consumptionCategoryId,
          consumptionWakeRunKey: consumptionWakeRunKey,
          consumptionThreadId: consumptionThreadId,
          rethrowInferenceErrors: true,
        );
        if (attemptUsage != null) {
          usage = usage == null ? attemptUsage : usage.merge(attemptUsage);
        }
      } catch (error, stackTrace) {
        attemptError = error;
        attemptStackTrace = stackTrace;
      } finally {
        conversationRepository.deleteConversation(conversationId);
      }

      attempts++;
      hadRevision = hadRevision || strategy.sawReportCall;
      if (attemptError != null) {
        return TaskAgentReportEditResult(
          revision: null,
          hadRevision: hadRevision,
          attempts: attempts,
          validationIssues: validationIssues,
          usage: usage,
          error: attemptError,
          stackTrace: attemptStackTrace,
        );
      }
      final candidate = strategy.report;
      if (candidate == null) {
        validationIssues = [TaskAgentReportRevisionIssue.invalidShape];
        continue;
      }

      rejectedReport = candidate;
      validationIssues = validateRevision(
        languageCode: languageCode,
        materialTaskState: materialTaskState,
        draftReport: draft.toJson(),
        candidateReport: candidate.toJson(),
      );
      if (validationIssues.isEmpty) {
        return TaskAgentReportEditResult(
          revision: candidate,
          hadRevision: true,
          attempts: attempts,
          validationIssues: const [],
          usage: usage,
          error: null,
          stackTrace: null,
        );
      }
    }

    return TaskAgentReportEditResult(
      revision: null,
      hadRevision: hadRevision,
      attempts: attempts,
      validationIssues: validationIssues,
      usage: usage,
      error: null,
      stackTrace: null,
      rejectedReport: hadRevision ? rejectedReport : null,
    );
  }

  /// Builds the forced report-only tool with locale-specific register rules.
  static ChatCompletionTool buildTool({required String languageCode}) {
    final language = _languageInstructions[languageCode];
    final languageInstruction = language ?? 'language code `$languageCode`';

    return ChatCompletionTool(
      type: ChatCompletionToolType.function,
      function: FunctionObject(
        name: TaskAgentToolNames.updateReport,
        description:
            'Return the rewritten user-facing report entirely in '
            '$languageInstruction.',
        parameters: {
          'type': 'object',
          'additionalProperties': false,
          'required': ['oneLiner', 'tldr', 'content'],
          'properties': {
            'oneLiner': {
              'type': 'string',
              'description':
                  'Write entirely in $languageInstruction using at most 12 '
                  'words. State the most useful next action, target date, '
                  'recorded outcome, or active risk. A target date is not a '
                  'completed outcome.',
            },
            'tldr': {
              'type': 'string',
              'description':
                  'Write entirely in $languageInstruction. Be decision-useful '
                  'without repeating the one-liner. Preserve material '
                  'priority, estimate, deadline, and execution constraints. '
                  'Accurately distinguish incomplete work from recorded '
                  'outcomes. A task status does not prove work started, and a '
                  'checkmark proves only that the user marked an item '
                  'complete. Preserve an explicit risk or blocker '
                  'classification when the draft contains one. Never claim a '
                  'marked-complete item did or did not prevent, cause, or '
                  'resolve a later event, and do not explain this evidence '
                  'rule in the report.',
            },
            'content': {
              'type': 'string',
              'description':
                  'Flexible Markdown entirely in $languageInstruction. Follow '
                  'the supplied reportDirective for structure, headings, '
                  'title, detail, and section policy. Translate any retained '
                  'headings into $languageInstruction. Omit empty, process-only, '
                  'and unsupported Status or Progress sections. '
                  'Omit Links or Reference unless it contains a real `http://` '
                  'or `https://` URL. Never say work waits for the user or '
                  'execution. Describe a checkmark-only item as user-marked '
                  'complete, never fixed.',
            },
          },
        },
      ),
    );
  }

  /// Reduces current task anchors and successful mutations to ID-free facts.
  ///
  /// Successful mutations override the corresponding current value because
  /// they describe the task state that will exist after this wake.
  static Map<String, Object?> buildMaterialTaskState(
    Iterable<TaskAgentMutationRecord> mutations, {
    String? currentDueDate,
    int? currentEstimateMinutes,
    String? currentPriority,
  }) {
    final normalizedDueDate = currentDueDate?.trim();
    final normalizedPriority = currentPriority?.trim();
    final state = <String, Object?>{
      if (normalizedPriority != null && normalizedPriority.isNotEmpty)
        'priority': normalizedPriority,
      if (normalizedDueDate != null && normalizedDueDate.isNotEmpty)
        'dueDate': normalizedDueDate,
    };
    if (currentEstimateMinutes case final estimateMinutes?) {
      state['estimateMinutes'] = estimateMinutes;
    }
    final checklistItems = <String>[];

    for (final mutation in mutations) {
      final arguments = mutation.arguments;
      switch (mutation.toolName) {
        case TaskAgentToolNames.setTaskTitle:
          if (arguments['title'] case final String title
              when title.trim().isNotEmpty) {
            state['title'] = title;
          }
        case TaskAgentToolNames.setTaskLanguage:
          if (arguments['languageCode'] case final String languageCode
              when languageCode.trim().isNotEmpty) {
            state['languageCode'] = languageCode;
          }
        case TaskAgentToolNames.updateTaskPriority:
          if (arguments['priority'] case final String priority
              when priority.trim().isNotEmpty) {
            state['priority'] = priority;
          }
        case TaskAgentToolNames.updateTaskDueDate:
          if (arguments['dueDate'] case final String dueDate
              when dueDate.trim().isNotEmpty) {
            state['dueDate'] = dueDate;
          }
        case TaskAgentToolNames.updateTaskEstimate:
          if (arguments['minutes'] case final num minutes) {
            state['estimateMinutes'] = minutes;
          }
        case TaskAgentToolNames.addMultipleChecklistItems:
          if (arguments['items'] case final List<dynamic> items) {
            for (final item in items) {
              if (item case {
                'title': final String title,
              } when title.trim().isNotEmpty) {
                checklistItems.add(title);
              }
            }
          }
        case TaskAgentToolNames.addChecklistItem:
          if (arguments['title'] case final String title
              when title.trim().isNotEmpty) {
            checklistItems.add(title);
          }
      }
    }

    if (checklistItems.isNotEmpty) {
      state['newChecklistItems'] = checklistItems;
    }
    return state;
  }

  /// Detects the narrow, observed regression set on a direct Qwen report.
  ///
  /// This is deliberately not a semantic validator or a parser for the active
  /// report directive. In particular, headings and standalone words such as
  /// `Goal`, `Checklist`, or `No blockers` do not trigger a rewrite.
  static List<TaskAgentReportRevisionIssue> detectDirectQwenRegressions({
    required String languageCode,
    required Map<String, Object?> materialTaskState,
    required Map<String, dynamic> report,
  }) {
    final issues = <TaskAgentReportRevisionIssue>{};
    final reportText = _reportFieldText(report);
    final normalizedReport = reportText.toLowerCase();

    _addShapeAndAnchorIssues(
      issues: issues,
      materialTaskState: materialTaskState,
      candidateReport: report,
      normalizedCandidate: normalizedReport,
    );

    final hasNewChecklistItems =
        switch (materialTaskState['newChecklistItems']) {
          final List<dynamic> items => items.isNotEmpty,
          _ => false,
        };
    if (_hasKnownProcessNarration(
          normalizedCandidate: normalizedReport,
          hasNewChecklistItems: hasNewChecklistItems,
        ) ||
        _inventsWaitingFromUnperformedRequest(
          materialTaskState: materialTaskState,
          normalizedCandidate: normalizedReport,
        )) {
      issues.add(TaskAgentReportRevisionIssue.processNarration);
    }

    final activeRiskTerms = <String>{
      ..._activeRiskTermsByLanguage['en']!,
      ...?_activeRiskTermsByLanguage[languageCode],
    };
    if (activeRiskTerms.any(normalizedReport.contains) &&
        _hasCheckmarkCausality(
          languageCode: languageCode,
          normalizedCandidate: normalizedReport,
        )) {
      issues.add(TaskAgentReportRevisionIssue.checkmarkCausality);
    }

    if (_usesFormalRegister(languageCode, reportText)) {
      issues.add(TaskAgentReportRevisionIssue.formalRegister);
    }

    final excludedTerms = _extractExcludedDraftTerms(report);
    if (excludedTerms.any(normalizedReport.contains)) {
      issues.add(TaskAgentReportRevisionIssue.deferredScopeLeak);
    }

    return issues.toList(growable: false);
  }

  /// Checks an editor candidate against material facts and known regressions.
  static List<TaskAgentReportRevisionIssue> validateRevision({
    required String languageCode,
    required Map<String, Object?> materialTaskState,
    required Map<String, dynamic> draftReport,
    required Map<String, dynamic> candidateReport,
  }) {
    final issues = <TaskAgentReportRevisionIssue>{};
    final candidateText = _reportFieldText(candidateReport);
    final normalizedCandidate = candidateText.toLowerCase();
    final normalizedDraft = _reportFieldText(draftReport).toLowerCase();

    _addShapeAndAnchorIssues(
      issues: issues,
      materialTaskState: materialTaskState,
      candidateReport: candidateReport,
      normalizedCandidate: normalizedCandidate,
    );

    const processFragments = [
      'no blockers',
      'no recorded outcomes',
      'none identified',
      'none at this time',
      'none currently',
      'no estimate',
      'no due date',
      'no decision needed',
      'keine entscheidung erforderlich',
      'ninguna decisión necesaria',
      'aucune décision nécessaire',
      'added to checklist',
      'added to the checklist',
      'checklist created',
      'checklist items added',
      'checklist contains',
      'checklist includes',
      'from the transcript',
      'extracted from',
      'configuration is complete',
      'configuration complete',
      'task configured',
      'metadata updated',
      'ready to begin',
      'ready for execution',
      'awaiting execution',
      'waits for you',
      'waiting for you',
      'warten auf dich',
      'wartet auf dich',
      'aus der transkription',
      'als checkliste angelegt',
      'checkliste enthält',
      'aufgabe konfiguriert',
      'konfiguration abgeschlossen',
    ];
    final hasProcessFragment =
        processFragments.any(normalizedCandidate.contains) ||
        normalizedCandidate.contains('checklist') ||
        normalizedCandidate.contains('checkliste');
    final hasGermanChecklistNarration = RegExp(
      'checkliste.{0,40}(erstellt|hinzugef(?:ü|u)gt|aufgenommen)',
    ).hasMatch(normalizedCandidate);
    final hasNewChecklistItems =
        switch (materialTaskState['newChecklistItems']) {
          final List<dynamic> items => items.isNotEmpty,
          _ => false,
        };
    final hasKnownProcessNarration = _hasKnownProcessNarration(
      normalizedCandidate: normalizedCandidate,
      hasNewChecklistItems: hasNewChecklistItems,
    );
    final candidateAddsWaitingState = RegExp(
      r'\b(await\w*|wait\w*|wart\w*|esper\w*|attend\w*|aștept\w*|ček\w*)\b',
    ).hasMatch(normalizedCandidate);
    final draftGroundsWaitingState = RegExp(
      r'\b(await\w*|wait\w*|pending|blocked|until|cannot proceed|wart\w*|'
      r'esper\w*|attend\w*|aștept\w*|ček\w*|bloquead\w*|pendiente\w*)\b',
    ).hasMatch(normalizedDraft);
    final waitingInventedFromRequest = _inventsWaitingFromUnperformedRequest(
      materialTaskState: materialTaskState,
      normalizedCandidate: normalizedCandidate,
    );
    if (hasProcessFragment ||
        hasGermanChecklistNarration ||
        hasKnownProcessNarration ||
        (candidateAddsWaitingState &&
            (!draftGroundsWaitingState || waitingInventedFromRequest))) {
      issues.add(TaskAgentReportRevisionIssue.processNarration);
    }

    if (_hasCheckmarkCausality(
          languageCode: languageCode,
          normalizedCandidate: normalizedCandidate,
        ) ||
        (_hasCheckmarkCausality(
              languageCode: languageCode,
              normalizedCandidate: normalizedDraft,
            ) &&
            _unsupportedCheckmarkOutcome.hasMatch(normalizedCandidate))) {
      issues.add(TaskAgentReportRevisionIssue.checkmarkCausality);
    }

    const priorityFragments = [
      'first priority',
      'highest priority',
      'höchste priorität',
      'priorität hat',
    ];
    final mentionsPriority = RegExp(
      r'\b(priority|priorität|prioridad|priorité|prioritate)\b',
    ).hasMatch(normalizedCandidate);
    final priorityIsGrounded =
        materialTaskState['priority'] != null ||
        RegExp(
          r'\b(priority|priorität|prioridad|priorité|prioritate|p[0-4])\b',
        ).hasMatch(normalizedDraft);
    if (priorityFragments.any(normalizedCandidate.contains) ||
        (mentionsPriority && !priorityIsGrounded)) {
      issues.add(TaskAgentReportRevisionIssue.unsupportedPriority);
    }

    final content = candidateReport['content'] as String? ?? '';
    final hasLinkHeading = RegExp(
      r'^#{1,6}\s*(links?|references?|verweise?)\s*$',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(content);
    if (hasLinkHeading && !RegExp('https?://').hasMatch(content)) {
      issues.add(TaskAgentReportRevisionIssue.fakeLinkSection);
    }

    if (_usesFormalRegister(languageCode, candidateText)) {
      issues.add(TaskAgentReportRevisionIssue.formalRegister);
    }

    final activeRiskTerms = <String>{
      ..._activeRiskTermsByLanguage['en']!,
      ...?_activeRiskTermsByLanguage[languageCode],
    };
    final reportedRiskTerms = <String>{
      ..._reportedRiskTermsByLanguage['en']!,
      ...?_reportedRiskTermsByLanguage[languageCode],
    };
    if (activeRiskTerms.any(normalizedDraft.contains) &&
        !reportedRiskTerms.any(normalizedCandidate.contains)) {
      issues.add(TaskAgentReportRevisionIssue.missingActiveRisk);
    }

    final excludedDraftTerms = _extractExcludedDraftTerms(draftReport);
    if (excludedDraftTerms.any(normalizedCandidate.contains)) {
      issues.add(TaskAgentReportRevisionIssue.deferredScopeLeak);
    }

    return issues.toList(growable: false);
  }

  static final _scopeClause = RegExp(
    r'[^.!?;\n]+(?:[.!?;\n]+|$)',
    unicode: true,
  );
  static final _distinctiveWord = RegExp(
    r'[\p{L}\p{N}]{7,}',
    unicode: true,
  );
  static final _excludedScopeMarker = RegExp(
    r'\b(?:rejected|omitted|out[- ]of[- ]scope|outside scope|'
    'scoped[- ]out|do not include|must not be included|'
    'leave (?:it|that|this) out|'
    'zurückgestellt|nicht.{0,60}aufgenommen|nicht.{0,40}aufnehmen|'
    r'nicht.{0,40}bearbeit\w*|'
    r'(?:erst\s+)?später.{0,40}(?:aufgenommen|betrachtet|berücksichtigt|bearbeitet|angegangen)|'
    'ausgeschlossen|fuera de alcance|no incluir|'
    'hors périmètre|ne pas inclure|'
    r'în afara domeniului|nu include|odložen|mimo rozsah|nezahrnovat)\b',
    caseSensitive: false,
    unicode: true,
  );
  static final _requestActionPrefix = RegExp(
    '^(?:request|ask|contact|anfordern|beantragen|solicitar|pedir|contactar|'
    r'demander|contacter|solicita|contactează|požádat|kontaktovat)\b',
    unicode: true,
  );
  static final _unsupportedCheckmarkOutcome = RegExp(
    r'\b(?:deployed|verified|validated|implemented|applied)\b',
  );
  static const _requestActionStopWords = <String>{
    'request',
    'contact',
    'anfordern',
    'beantragen',
    'solicitar',
    'contactar',
    'demander',
    'contacter',
    'solicita',
    'contactează',
    'požádat',
    'kontaktovat',
  };
  static const _excludedScopeStopWords = <String>{
    'because',
    'concept',
    'concepts',
    'current',
    'deferred',
    'explicitly',
    'included',
    'include',
    'mentioned',
    'omitted',
    'outside',
    'rejected',
    'report',
    'someday',
    'zurückgestellt',
    'aufgenommen',
    'aufnehmen',
    'ausgeschlossen',
    'aktuell',
    'bewusst',
    'erstellung',
    'erwähnt',
    'möglicher',
    'vorerst',
    'zukünftiger',
    'zukünftige',
    'zukünftigen',
    'zukünftig',
  };

  static const _causalFragmentsByLanguage = <String, List<String>>{
    'en': [
      'did not prevent',
      'did not fully resolve',
      'failed to prevent',
      'fix was applied',
      'fix failed',
      'fix reverted',
      'addressed the symptom',
      'issue persists',
      'problem persists',
      'does not confirm',
      "doesn't confirm",
      'not proof',
    ],
    'cs': ['nezabránilo', 'problém přetrvává', 'nepotvrzuje', 'není důkaz'],
    'de': [
      'hat nicht verhindert',
      'verhinderte nicht',
      'fehler besteht fort',
      'problem besteht fort',
      'bestätigt nicht',
      'belegt nicht',
    ],
    'es': [
      'no evitó',
      'no ha evitado',
      'el problema persiste',
      'no confirma',
      'no demuestra',
    ],
    'fr': [
      "n'a pas empêché",
      'n’a pas empêché',
      'le problème persiste',
      'ne confirme pas',
      'ne prouve pas',
    ],
    'ro': [
      'nu a prevenit',
      'problema persistă',
      'nu confirmă',
      'nu dovedește',
    ],
  };

  static const _checkmarkCausalityPatterns = <String, ({String resolution, String checkmark})>{
    'en': (
      resolution:
          r'\b(?:resolved|fixed|implemented|applied|deployed|verified|validated)\b',
      checkmark:
          r'\b(?:user-marked|user marked|marked complete|marked as complete)\b',
    ),
    'cs': (
      resolution: r'\b(?:vyřešen|opraven|implementov|nasazen|ověřen|validov)',
      checkmark:
          '(?:uživatel.{0,50}označ.{0,30}(?:dokončen|hotov)|označ.{0,30}(?:dokončen|hotov).{0,30}uživatel)',
    ),
    'de': (
      resolution:
          r'\b(?:gelöst|behoben|umgesetzt|implementier|angewend|bereitgestell|verifizier|validier)',
      checkmark:
          '(?:nutzer.{0,50}(?:(?:erledigt|abgeschlossen).{0,20}markiert|markiert.{0,30}(?:erledigt|abgeschlossen))|(?:erledigt|abgeschlossen).{0,20}markiert.{0,30}nutzer)',
    ),
    'es': (
      resolution:
          r'\b(?:resuelt|arreglad|corregid|implementad|aplicad|desplegad|verificad|validad)',
      checkmark:
          '(?:usuario.{0,50}marc.{0,30}(?:complet|terminad)|marc.{0,30}(?:complet|terminad).{0,30}usuario)',
    ),
    'fr': (
      resolution: r'\b(?:résolu|corrig|implément|appliqu|déploy|vérifi|validé)',
      checkmark:
          '(?:utilisateur.{0,50}marqu.{0,30}(?:termin|achev|compl)|marqu.{0,30}(?:termin|achev|compl).{0,30}utilisateur)',
    ),
    'ro': (
      resolution:
          r'\b(?:rezolvat|remediat|implementat|aplicat|lansat|verificat|validat)',
      checkmark:
          '(?:utilizator.{0,50}marcat.{0,30}(?:finalizat|complet)|marcat.{0,30}(?:finalizat|complet).{0,30}utilizator)',
    ),
  };

  static const _activeRiskTermsByLanguage = <String, List<String>>{
    'en': [
      'root cause',
      'reappear',
      'resurfac',
      'recurr',
      'blocked until',
      'pending until',
      'active risk',
    ],
    'cs': [
      'hlavní příčin',
      'kořenov',
      'znovu obje',
      'vrací se',
      'opakuj',
      'blokován',
      'blokována',
      'čeká na',
      'aktivní riziko',
      'riziko',
    ],
    'de': [
      'wurzelursache',
      'ursache',
      'wiederkehr',
      'wieder auf',
      'erneut auf',
      'blockiert bis',
      'ausstehend bis',
      'aktives risiko',
      'risiko',
    ],
    'es': [
      'causa raíz',
      'reaparec',
      'resurg',
      'recurr',
      'bloquead',
      'pendiente hasta',
      'riesgo activo',
      'riesgo',
    ],
    'fr': [
      'cause racine',
      'réappar',
      'ressurg',
      'récurr',
      'bloqué',
      'bloquée',
      'en attente jusqu',
      'risque actif',
      'risque',
    ],
    'ro': [
      'cauza principală',
      'cauza rădăcină',
      'reapăr',
      'recuren',
      'blocat',
      'blocată',
      'în așteptare până',
      'risc activ',
      'risc',
    ],
  };

  static const _reportedRiskTermsByLanguage = <String, List<String>>{
    'en': [
      'blocker',
      'blocked',
      'risk',
      'root cause',
      'investigat',
      'pending',
      'waiting until',
      'awaiting approval',
      'cannot proceed',
      'on hold',
      'constraint',
      'maintenance window',
    ],
    'cs': [
      'blokace',
      'blokován',
      'blokována',
      'riziko',
      'příčin',
      'prošetř',
      'vyšetř',
      'pozastav',
      'omezení',
    ],
    'de': [
      'blocker',
      'blockiert',
      'risiko',
      'ursache',
      'untersuch',
      'ausstehend',
      'kann nicht',
      'bedingung',
    ],
    'es': [
      'bloqueador',
      'bloquead',
      'riesgo',
      'causa raíz',
      'investig',
      'pendiente',
      'no puede',
      'restricción',
    ],
    'fr': [
      'blocage',
      'bloqué',
      'bloquée',
      'risque',
      'cause racine',
      'enquêt',
      'examin',
      'en attente',
      'ne peut pas',
      'contrainte',
    ],
    'ro': [
      'blocaj',
      'blocat',
      'blocată',
      'risc',
      'cauz',
      'investig',
      'în așteptare',
      'nu poate',
      'constrângere',
    ],
  };

  static const _languageInstructions = {
    'en': 'English',
    'cs': 'Czech using informal address',
    'de': 'German using informal `du/dein`, never formal `Sie/Ihr`',
    'es': 'Spanish using informal `tú/tus`, never formal `usted/sus`',
    'fr': 'French using informal `tu/tes`, never formal `vous/vos`',
    'ro': 'Romanian using the formal `dvs.` register',
  };

  static const _systemPrompt = '''
Rewrite the draft task report for its user. Use only facts in the draft and the
material task state. Every material-state value comes from a task change that
applied successfully or was successfully queued and must remain visible in the
revised report. Task-state changes are not real-world accomplishments. Add no
other fact, rationale, or inference.

Keep every real action, person, current priority, estimate, date and its
purpose, quantity, explicit dependency, blocker, recorded outcome, and real
external URL. Add nothing. Preserve state and tense exactly: a target date is
not completion, incomplete work is not in progress, and a checkmark alone is
not a real-world outcome.

Delete task setup, metadata changes, checklist creation or identification,
analysis, transcription, readiness, waiting filler, internal IDs, rejected or
deferred scope, empty sections, and claims that no blocker, link, or outcome
exists. Never restate the task status as real-world progress or label a user
checkmark as applied, implemented, fixed, or achieved.
Explicitly deferred, rejected, omitted, and out-of-scope draft clauses have
already been removed. Never reconstruct, infer, or explain those omissions.
Do not mention the checklist itself; present its real actions directly.
Links and reference sections require a real HTTP or HTTPS URL; a date, title,
or internal label is not a link.
A user-marked-complete item does not establish that a fix was applied or that
it caused, prevented, failed to prevent, or resolved a later event. State the
facts separately; never explain this evidence rule in the report.
Pending work is never underway, in progress, started, established, or active
without explicit source evidence. An instruction that an investigation is
needed means the investigation remains pending. Never say a checkmark-only fix
addressed the symptom or was applied. Do not invent generic downstream fixes
or validation after a pending investigation.

The request contains the active template's `reportDirective`. Treat it as
authoritative for voice, structure, emphasis, level of detail, required or
forbidden sections, and Markdown presentation. Follow it for all three report
fields. Do not quote, mention, critique, or summarize the directive. A report
directive cannot authorize unsupported facts, internal IDs, mutation tools, or
private process narration; the evidence and privacy rules above take
precedence when they conflict.

When the report directive leaves a presentation choice open, write warmly,
clearly, directly, and without repetition. Do not summarize the whole context.
Surface only the current outcome, next actions, deadline, decision, or risk
that helps the user act.
''';
}
