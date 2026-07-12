import 'dart:convert';

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

/// A successful task mutation, stripped to the tool name and decoded inputs.
typedef TaskAgentMutationRecord = ({
  String toolName,
  Map<String, dynamic> arguments,
});

/// The three user-facing fields published by `update_report`.
class TaskAgentReportDraft {
  const TaskAgentReportDraft({
    required this.oneLiner,
    required this.tldr,
    required this.content,
  });

  /// Creates a draft only when all required report fields are non-empty.
  static TaskAgentReportDraft? fromJson(Map<String, dynamic> value) {
    final oneLiner = _nonEmptyString(value['oneLiner']);
    final tldr = _nonEmptyString(value['tldr']);
    final content = _nonEmptyString(value['content']);
    if (oneLiner == null || tldr == null || content == null) return null;
    return TaskAgentReportDraft(
      oneLiner: oneLiner,
      tldr: tldr,
      content: content,
    );
  }

  final String oneLiner;
  final String tldr;
  final String content;

  /// Serializes the draft for the compact editor request and validator.
  Map<String, dynamic> toJson() => {
    'oneLiner': oneLiner,
    'tldr': tldr,
    'content': content,
  };
}

/// Deterministic report defects that the bounded repair pass can correct.
enum TaskAgentReportRevisionIssue {
  invalidShape('Return non-empty oneLiner, tldr, and content fields.'),
  missingPriority('Restore the current task priority.'),
  missingDueDate('Restore the current due date and its purpose.'),
  missingEstimate('Restore the current time estimate.'),
  processNarration(
    'Remove task setup, transcription, readiness, and waiting narration. '
    'Remove every reference to the checklist itself, including saying it '
    'has, contains, includes, or received items; present the actions directly. '
    'Do not turn an unperformed request into waiting for its result.',
  ),
  checkmarkCausality(
    'State a user-marked-complete item neutrally. Remove causal claims and '
    'explanations of what the checkmark does or does not prove.',
  ),
  unsupportedPriority(
    'Remove every priority label or claim unless the original draft or '
    'material task state contains one. Keep action order without calling it '
    'a priority.',
  ),
  fakeLinkSection(
    'Remove Links or Reference sections that contain no HTTP or HTTPS URL.',
  ),
  formalRegister('Use the configured informal language register.'),
  missingActiveRisk(
    'Restore the active risk, blocker, or root-cause investigation.',
  );

  const TaskAgentReportRevisionIssue(this.correction);

  /// The exact repair instruction sent after this issue is detected.
  final String correction;
}

/// The bounded report-editing outcome.
class TaskAgentReportEditResult {
  const TaskAgentReportEditResult({
    required this.revision,
    required this.hadRevision,
    required this.attempts,
    required this.validationIssues,
    required this.usage,
    required this.error,
    required this.stackTrace,
  });

  /// Accepted revision, or `null` when every candidate was rejected.
  final TaskAgentReportDraft? revision;

  /// Whether the editor returned at least one `update_report` candidate.
  final bool hadRevision;

  /// Number of editor calls made.
  final int attempts;

  /// Remaining issues on the last rejected candidate.
  final List<TaskAgentReportRevisionIssue> validationIssues;

  /// Combined usage from every editor attempt.
  final InferenceUsage? usage;

  /// Error from the final attempt, if inference aborted before validation.
  final Object? error;

  /// Stack trace paired with [error].
  final StackTrace? stackTrace;
}

/// Isolated, bounded report editor for the opt-in efficient task-agent path.
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
    required bool enabled,
    required String executorModelId,
    required InferenceProviderType providerType,
  }) {
    return enabled &&
        providerType == InferenceProviderType.melious &&
        executorModelId.toLowerCase() ==
            meliousMistralSmall4119BInstructModelId;
  }

  /// Rewrites [draft] from compact, ID-free task facts.
  Future<TaskAgentReportEditResult> edit({
    required TaskAgentReportDraft draft,
    required String languageCode,
    required Map<String, Object?> materialTaskState,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
  }) async {
    var attempts = 0;
    var hadRevision = false;
    var validationIssues = <TaskAgentReportRevisionIssue>[];
    TaskAgentReportDraft? rejectedReport;
    InferenceUsage? usage;

    while (attempts < maxAttempts) {
      final isRepair = attempts > 0;
      final conversationId = conversationRepository.createConversation(
        systemMessage: isRepair
            ? '$_systemPrompt\n\n'
                  'The previous candidate failed deterministic quality checks. '
                  'Rewrite it again from the original draft and material task '
                  'state. Fix every listed violation. Do not defend the '
                  'candidate or mention the corrections.'
            : _systemPrompt,
        maxTurns: 2,
      );
      final strategy = _TaskAgentReportCaptureStrategy();
      final message = <String, Object?>{
        'languageCode': languageCode,
        'materialTaskState': materialTaskState,
        'draftReport': draft.toJson(),
        if (isRepair) ...{
          'rejectedReport': rejectedReport?.toJson(),
          'requiredCorrections': [
            for (final issue in validationIssues)
              {'code': issue.name, 'instruction': issue.correction},
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
          consumptionAgentId: consumptionAgentId,
          consumptionTaskId: consumptionTaskId,
          consumptionCategoryId: consumptionCategoryId,
          consumptionWakeRunKey: consumptionWakeRunKey,
          consumptionThreadId: consumptionThreadId,
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
                  'Concise, flexible Markdown entirely in '
                  '$languageInstruction, including headings. Translate or '
                  'remove headings from another language. Do not add a title '
                  'because the task title is already visible. Omit empty, '
                  'process-only, and unsupported Status or Progress sections. '
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

  /// Reduces successful mutation calls to ID-free facts the editor must keep.
  static Map<String, Object?> buildMaterialTaskState(
    Iterable<TaskAgentMutationRecord> mutations,
  ) {
    final state = <String, Object?>{};
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

  /// Checks a candidate against material facts and known report regressions.
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

    if (TaskAgentReportDraft.fromJson(candidateReport) == null) {
      issues.add(TaskAgentReportRevisionIssue.invalidShape);
    }

    if (materialTaskState['priority'] case final String priority
        when priority.trim().isNotEmpty &&
            !normalizedCandidate.contains(priority.toLowerCase())) {
      issues.add(TaskAgentReportRevisionIssue.missingPriority);
    }
    if (materialTaskState['dueDate'] case final String dueDate
        when !_containsReportDate(normalizedCandidate, dueDate)) {
      issues.add(TaskAgentReportRevisionIssue.missingDueDate);
    }
    if (materialTaskState['estimateMinutes'] case final num minutes
        when !_containsReportEstimate(normalizedCandidate, minutes)) {
      issues.add(TaskAgentReportRevisionIssue.missingEstimate);
    }

    const processFragments = [
      'no blockers',
      'no recorded outcomes',
      'none identified',
      'added to checklist',
      'added to the checklist',
      'checklist created',
      'checklist items added',
      'checklist contains',
      'checklist includes',
      'from the transcript',
      'extracted from',
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
    final assignsProgressToNewActions =
        hasNewChecklistItems &&
        RegExp(
          r'\b(these|those|diese[nmrs]?|estos?|estas?|ces)\b.{0,60}'
          r'\b(already\s+|bereits\s+)?'
          r'(marked|markiert|marcad\w*|coch\w*|označ\w*|bifat\w*)\b',
        ).hasMatch(normalizedCandidate);
    final describesNewActionsAsSetup =
        hasNewChecklistItems &&
        RegExp(
          r'\b(these|those|diese[nmrs]?|estos?|estas?|ces)\b.{0,30}'
          r'\b(points?|punkte|items?|actions?|aktionen|acciones)\b.{0,50}'
          r'\b(ready|ahead|pending|zur bearbeitung|pendientes?)\b',
        ).hasMatch(normalizedCandidate);
    final candidateAddsWaitingState = RegExp(
      r'\b(await\w*|wait\w*|wart\w*|esper\w*|attend\w*|aștept\w*|ček\w*)\b',
    ).hasMatch(normalizedCandidate);
    final draftGroundsWaitingState = RegExp(
      r'\b(await\w*|wait\w*|pending|blocked|until|cannot proceed|wart\w*|'
      r'esper\w*|attend\w*|aștept\w*|ček\w*|bloquead\w*|pendiente\w*)\b',
    ).hasMatch(normalizedDraft);
    if (hasProcessFragment ||
        hasGermanChecklistNarration ||
        assignsProgressToNewActions ||
        describesNewActionsAsSetup ||
        (candidateAddsWaitingState && !draftGroundsWaitingState)) {
      issues.add(TaskAgentReportRevisionIssue.processNarration);
    }

    final causalFragments = <String>{
      ..._causalFragmentsByLanguage['en']!,
      ...?_causalFragmentsByLanguage[languageCode],
    };
    if (causalFragments.any(normalizedCandidate.contains)) {
      issues.add(TaskAgentReportRevisionIssue.checkmarkCausality);
    }
    final localizedCheckmarkPattern = _checkmarkCausalityPatterns[languageCode];
    final checkmarkPatterns = <({String resolution, String checkmark})>{
      _checkmarkCausalityPatterns['en']!,
      ?localizedCheckmarkPattern,
    };
    final claimsResolutionFromCheckmark = checkmarkPatterns.any(
      (patterns) => _containsNearbyPatterns(
        normalizedCandidate,
        patterns.resolution,
        patterns.checkmark,
      ),
    );
    if (claimsResolutionFromCheckmark) {
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

    final usesFormalRegister = switch (languageCode) {
      'de' => RegExp(
        r'\b(Sie|Ihr(?:e|en|er|em|es)?)\b',
      ).hasMatch(candidateText),
      'es' => RegExp(
        r'\b(usted|ustedes)\b',
        caseSensitive: false,
      ).hasMatch(candidateText),
      'fr' => RegExp(
        r'\b(vous|votre|vos)\b',
        caseSensitive: false,
      ).hasMatch(candidateText),
      _ => false,
    };
    if (usesFormalRegister) {
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

    return issues.toList(growable: false);
  }

  static bool _containsNearbyPatterns(
    String text,
    String firstPattern,
    String secondPattern,
  ) {
    return RegExp(
      '(?:$firstPattern).{0,100}(?:$secondPattern)|'
      '(?:$secondPattern).{0,100}(?:$firstPattern)',
    ).hasMatch(text);
  }

  static const _causalFragmentsByLanguage = <String, List<String>>{
    'en': [
      'did not prevent',
      'failed to prevent',
      'fix failed',
      'fix reverted',
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
    'en': ['blocker', 'blocked', 'risk', 'root cause', 'investigat'],
    'cs': [
      'blokace',
      'blokován',
      'blokována',
      'riziko',
      'příčin',
      'prošetř',
      'vyšetř',
    ],
    'de': ['blocker', 'blockiert', 'risiko', 'ursache', 'untersuch'],
    'es': [
      'bloqueador',
      'bloquead',
      'riesgo',
      'causa raíz',
      'investig',
      'pendiente',
    ],
    'fr': [
      'blocage',
      'bloqué',
      'bloquée',
      'risque',
      'cause racine',
      'enquêt',
      'examin',
    ],
    'ro': ['blocaj', 'blocat', 'blocată', 'risc', 'cauz', 'investig'],
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
Do not mention the checklist itself; present its real actions directly.
Links and reference sections require a real HTTP or HTTPS URL; a date, title,
or internal label is not a link.
A user-marked-complete item does not establish that a fix was applied or that
it caused, prevented, failed to prevent, or resolved a later event. State the
facts separately; never explain this evidence rule in the report.

Write warmly, clearly, directly, and without repetition. Do not summarize the
whole context. Surface only the current outcome, next actions, deadline, or
risk that helps the user act. Use short prose or a compact list; the task title
is already visible.
''';
}

class _TaskAgentReportCaptureStrategy extends ConversationStrategy {
  TaskAgentReportDraft? report;
  bool sawReportCall = false;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    for (final call in toolCalls) {
      if (call.function.name != TaskAgentToolNames.updateReport) {
        manager.addToolResponse(
          toolCallId: call.id,
          response: 'Only update_report is accepted.',
        );
        continue;
      }
      sawReportCall = true;

      TaskAgentReportDraft? candidate;
      try {
        final decoded = jsonDecode(call.function.arguments);
        if (decoded is Map<String, dynamic>) {
          candidate = TaskAgentReportDraft.fromJson(decoded);
        }
      } on FormatException {
        candidate = null;
      }
      if (candidate == null) {
        manager.addToolResponse(
          toolCallId: call.id,
          response: 'Invalid report fields.',
        );
        continue;
      }

      report = candidate;
      manager.addToolResponse(
        toolCallId: call.id,
        response: 'Report revision captured.',
      );
    }
    return ConversationAction.complete;
  }

  // coverage:ignore-start
  @override
  bool shouldContinue(ConversationManager manager) => false;

  @override
  String? getContinuationPrompt(ConversationManager manager) => null;
  // coverage:ignore-end
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _reportFieldText(Map<String, dynamic> report) => [
  report['oneLiner'],
  report['tldr'],
  report['content'],
].whereType<String>().join('\n');

bool _containsReportDate(String report, String isoDate) {
  if (report.contains(isoDate.toLowerCase())) return true;
  final parts = isoDate.split('-');
  if (parts.length != 3) return report.contains(isoDate.toLowerCase());
  final year = parts[0];
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || !report.contains(year)) return false;
  const monthTerms = <int, List<String>>{
    1: ['january', 'januar', 'enero', 'janvier', 'ianuarie', 'leden'],
    2: ['february', 'februar', 'febrero', 'février', 'februarie', 'únor'],
    3: ['march', 'märz', 'marzo', 'mars', 'martie', 'březen'],
    4: ['april', 'abril', 'avril', 'aprilie', 'duben'],
    5: ['may', 'mai', 'mayo', 'mai', 'květen'],
    6: ['june', 'juni', 'junio', 'juin', 'iunie', 'červen'],
    7: ['july', 'juli', 'julio', 'juillet', 'iulie', 'červenec'],
    8: ['august', 'agosto', 'août', 'august', 'srpen'],
    9: ['september', 'septiembre', 'septembre', 'septembrie', 'září'],
    10: ['october', 'oktober', 'octubre', 'octobre', 'octombrie', 'říjen'],
    11: ['november', 'noviembre', 'novembre', 'noiembrie', 'listopad'],
    12: [
      'december',
      'dezember',
      'diciembre',
      'décembre',
      'decembrie',
      'prosinec',
    ],
  };
  final hasDay = RegExp('(^|\\D)0?$day(\\D|\$)').hasMatch(report);
  final hasMonth =
      report.contains(parts[1]) ||
      (monthTerms[month]?.any(report.contains) ?? false);
  return hasDay && hasMonth;
}

bool _containsReportEstimate(String report, num minutes) {
  final normalizedMinutes = minutes.toString().replaceFirst(
    RegExp(r'\.0$'),
    '',
  );
  if (_containsNumberWithUnit(
    report,
    normalizedMinutes,
    const [
      'm',
      'min',
      'mins',
      'minute',
      'minutes',
      'minuten',
      'minuto',
      'minutos',
      'minut',
      'minuty',
    ],
  )) {
    return true;
  }
  final hours = minutes / 60;
  final normalizedHours = hours % 1 == 0
      ? hours.toStringAsFixed(0)
      : hours
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
  return _containsNumberWithUnit(
    report,
    normalizedHours,
    const [
      'h',
      'hr',
      'hrs',
      'hour',
      'hours',
      'stunde',
      'stunden',
      'hora',
      'horas',
      'heure',
      'heures',
      'oră',
      'ore',
      'hodina',
      'hodiny',
      'hodin',
    ],
  );
}

bool _containsNumberWithUnit(
  String report,
  String number,
  List<String> units,
) {
  final decimalVariants = {
    RegExp.escape(number),
    RegExp.escape(number.replaceFirst('.', ',')),
  }.join('|');
  final unitPattern = units.map(RegExp.escape).join('|');
  return RegExp(
    '(^|\\D)(?:$decimalVariants)\\s*-?\\s*(?:$unitPattern)\\b',
  ).hasMatch(report);
}
