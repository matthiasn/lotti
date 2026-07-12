import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_editor.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'provider-melious',
    baseUrl: 'https://api.melious.ai/v1',
    apiKey: 'test-key',
    name: 'Melious',
    createdAt: DateTime(2026, 7, 12),
    inferenceProviderType: InferenceProviderType.melious,
  );
  const draft = TaskAgentReportDraft(
    oneLiner: 'Task configured for model validation',
    tldr: 'P1, due July 4, 2026, estimated 150 minutes.',
    content: 'Run eval and compare the reference.',
  );
  const materialState = <String, Object?>{
    'priority': 'P1',
    'dueDate': '2026-07-04',
    'estimateMinutes': 150,
  };

  test('report draft requires and trims every field', () {
    expect(
      TaskAgentReportDraft.fromJson(const {
        'oneLiner': '  Next action  ',
        'tldr': '  Useful context.  ',
        'content': '  ## Action\nShip it.  ',
      })?.toJson(),
      {
        'oneLiner': 'Next action',
        'tldr': 'Useful context.',
        'content': '## Action\nShip it.',
      },
    );

    for (final invalid in [
      const <String, dynamic>{},
      const {'oneLiner': '', 'tldr': 'Summary', 'content': 'Body'},
      const {'oneLiner': 'Action', 'tldr': 3, 'content': 'Body'},
      const {'oneLiner': 'Action', 'tldr': 'Summary', 'content': '   '},
    ]) {
      expect(
        TaskAgentReportDraft.fromJson(invalid),
        isNull,
        reason: '$invalid',
      );
    }
  });

  test('editor support is limited to the validated opt-in route', () {
    expect(
      TaskAgentReportEditor.supports(
        enabled: true,
        executorModelId: meliousMistralSmall4119BInstructModelId,
        providerType: InferenceProviderType.melious,
      ),
      isTrue,
    );

    for (final unsupported in [
      (
        enabled: false,
        model: meliousMistralSmall4119BInstructModelId,
        providerType: InferenceProviderType.melious,
      ),
      (
        enabled: true,
        model: meliousQwen35122BA10BModelId,
        providerType: InferenceProviderType.melious,
      ),
      (
        enabled: true,
        model: meliousMistralSmall4119BInstructModelId,
        providerType: InferenceProviderType.genericOpenAi,
      ),
    ]) {
      expect(
        TaskAgentReportEditor.supports(
          enabled: unsupported.enabled,
          executorModelId: unsupported.model,
          providerType: unsupported.providerType,
        ),
        isFalse,
        reason: '$unsupported',
      );
    }
  });

  test('report-only tool localizes every field', () {
    final reportTool = TaskAgentReportEditor.buildTool(languageCode: 'de');
    final properties =
        reportTool.function.parameters!['properties']! as Map<String, dynamic>;

    expect(reportTool.function.name, TaskAgentToolNames.updateReport);
    expect(reportTool.function.description, contains('German'));
    expect(reportTool.function.description, contains('informal `du/dein`'));
    expect(reportTool.function.description, contains('never formal `Sie/Ihr`'));
    expect(
      (properties['oneLiner']! as Map<String, dynamic>)['description'],
      allOf(contains('German'), contains('target date'), contains('12 words')),
    );
    expect(
      (properties['content']! as Map<String, dynamic>)['description'],
      allOf(
        contains('German'),
        contains('headings'),
        contains('task title is already visible'),
        contains('real `http://` or `https://` URL'),
        contains('waits for the user'),
        contains('user-marked complete'),
      ),
    );
    expect(
      (properties['tldr']! as Map<String, dynamic>)['description'],
      allOf(
        contains('Preserve an explicit risk or blocker classification'),
        contains('did or did not prevent'),
      ),
    );
    expect(
      TaskAgentReportEditor.buildTool(
        languageCode: 'xx',
      ).function.description,
      contains('language code `xx`'),
    );
  });

  test('material state keeps report anchors and removes private handles', () {
    final state = TaskAgentReportEditor.buildMaterialTaskState(const [
      (
        toolName: TaskAgentToolNames.setTaskTitle,
        arguments: {'title': 'Launch beta'},
      ),
      (
        toolName: TaskAgentToolNames.setTaskLanguage,
        arguments: {'languageCode': 'de', 'confidence': 'high'},
      ),
      (
        toolName: TaskAgentToolNames.updateTaskPriority,
        arguments: {'priority': 'P1'},
      ),
      (
        toolName: TaskAgentToolNames.updateTaskDueDate,
        arguments: {'dueDate': '2026-09-30'},
      ),
      (
        toolName: TaskAgentToolNames.updateTaskEstimate,
        arguments: {'minutes': 90},
      ),
      (
        toolName: TaskAgentToolNames.addMultipleChecklistItems,
        arguments: {
          'items': [
            {'title': 'Ask Ben'},
            {'title': 'Review beta'},
          ],
        },
      ),
      (
        toolName: TaskAgentToolNames.addChecklistItem,
        arguments: {'title': 'Ship beta'},
      ),
      (
        toolName: TaskAgentToolNames.updateChecklistItems,
        arguments: {
          'items': [
            {'id': 'private-id', 'isChecked': true},
          ],
        },
      ),
      (
        toolName: TaskAgentToolNames.updateReport,
        arguments: {'oneLiner': 'ignored'},
      ),
      (
        toolName: TaskAgentToolNames.setTaskTitle,
        arguments: {'title': '   '},
      ),
    ]);

    expect(state, {
      'title': 'Launch beta',
      'languageCode': 'de',
      'priority': 'P1',
      'dueDate': '2026-09-30',
      'estimateMinutes': 90,
      'newChecklistItems': ['Ask Ben', 'Review beta', 'Ship beta'],
    });
    expect(jsonEncode(state), isNot(contains('private-id')));
    expect(TaskAgentReportEditor.buildMaterialTaskState(const []), isEmpty);
  });

  test('validation catches grounded quality regressions', () {
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'de',
      materialTaskState: const {
        'priority': 'P1',
        'dueDate': '2026-09-30',
        'estimateMinutes': 150,
      },
      draftReport: const {
        'oneLiner': 'Duplicate sync risk',
        'tldr': 'Root cause investigation needed.',
        'content': '## Blockers\nRoot cause unknown.',
      },
      candidateReport: const {
        'oneLiner': 'Aufgaben warten auf Sie',
        'tldr': 'The fix did not prevent recurrence. Highest priority.',
        'content':
            'Deine Checkliste enthält drei Punkte.\n\n## Reference\n'
            'Customer conference date',
      },
    );

    expect(issues, contains(TaskAgentReportRevisionIssue.missingPriority));
    expect(issues, contains(TaskAgentReportRevisionIssue.missingDueDate));
    expect(issues, contains(TaskAgentReportRevisionIssue.missingEstimate));
    expect(issues, contains(TaskAgentReportRevisionIssue.processNarration));
    expect(issues, contains(TaskAgentReportRevisionIssue.checkmarkCausality));
    expect(issues, contains(TaskAgentReportRevisionIssue.unsupportedPriority));
    expect(issues, contains(TaskAgentReportRevisionIssue.fakeLinkSection));
    expect(issues, contains(TaskAgentReportRevisionIssue.formalRegister));
    expect(issues, contains(TaskAgentReportRevisionIssue.missingActiveRisk));
    expect(issues.map((issue) => issue.correction), everyElement(isNotEmpty));
  });

  test('validation rejects missing report fields', () {
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'en',
      materialTaskState: const {},
      draftReport: const {
        'oneLiner': 'Review the candidate',
        'tldr': 'The candidate still needs review.',
        'content': '## Next action\nReview the candidate.',
      },
      candidateReport: const {'content': 'Only one field was returned.'},
    );

    expect(issues, contains(TaskAgentReportRevisionIssue.invalidShape));
  });

  test('validation rejects formal Spanish and French register', () {
    const cases = [
      (languageCode: 'es', text: 'Usted debe revisar el candidato.'),
      (languageCode: 'fr', text: 'Vous devez examiner le candidat.'),
    ];

    for (final testCase in cases) {
      final issues = TaskAgentReportEditor.validateRevision(
        languageCode: testCase.languageCode,
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Review the candidate',
          'tldr': 'The candidate still needs review.',
          'content': 'Review the candidate.',
        },
        candidateReport: {
          'oneLiner': 'Revisar el candidato',
          'tldr': 'La revisión sigue pendiente.',
          'content': testCase.text,
        },
      );

      expect(
        issues,
        contains(TaskAgentReportRevisionIssue.formalRegister),
        reason: testCase.languageCode,
      );
    }
  });

  test('validation rejects localized resolution claims from checkmarks', () {
    const cases = [
      (
        languageCode: 'en',
        text:
            'The prior fix was user-marked complete, so the issue is resolved.',
      ),
      (
        languageCode: 'de',
        text:
            'Der Nutzer hat den Fix als erledigt markiert, daher ist das '
            'Problem gelöst.',
      ),
      (
        languageCode: 'es',
        text:
            'El usuario marcó el arreglo como completado, así que el problema '
            'está resuelto.',
      ),
      (
        languageCode: 'fr',
        text:
            'L’utilisateur a marqué le correctif comme terminé, donc le '
            'problème est résolu.',
      ),
      (
        languageCode: 'cs',
        text:
            'Uživatel označil opravu jako dokončenou, proto je problém vyřešen.',
      ),
      (
        languageCode: 'ro',
        text:
            'Utilizatorul a marcat remedierea ca finalizată, deci problema '
            'este rezolvată.',
      ),
    ];

    for (final testCase in cases) {
      final issues = TaskAgentReportEditor.validateRevision(
        languageCode: testCase.languageCode,
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Investigate the current issue',
          'tldr': 'The prior fix was marked complete.',
          'content': 'Continue the investigation.',
        },
        candidateReport: {
          'oneLiner': 'Investigate the current issue',
          'tldr': testCase.text,
          'content': 'Continue the investigation.',
        },
      );

      expect(
        issues,
        contains(TaskAgentReportRevisionIssue.checkmarkCausality),
        reason: testCase.languageCode,
      );
    }
  });

  test('validation rejects localized checkmark evidence disclaimers', () {
    const cases = [
      (languageCode: 'en', text: 'The checkmark is not proof of resolution.'),
      (
        languageCode: 'de',
        text: 'Die Markierung belegt nicht, dass der Fehler behoben ist.',
      ),
      (
        languageCode: 'es',
        text: 'La marca no confirma que el problema esté resuelto.',
      ),
      (
        languageCode: 'fr',
        text: 'La marque ne confirme pas que le problème est résolu.',
      ),
      (
        languageCode: 'cs',
        text: 'Označení nepotvrzuje, že je problém vyřešený.',
      ),
      (
        languageCode: 'ro',
        text: 'Marcajul nu confirmă că problema este rezolvată.',
      ),
    ];

    for (final testCase in cases) {
      final issues = TaskAgentReportEditor.validateRevision(
        languageCode: testCase.languageCode,
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Investigate the current issue',
          'tldr': 'The prior fix was marked complete.',
          'content': 'Continue the investigation.',
        },
        candidateReport: {
          'oneLiner': 'Investigate the current issue',
          'tldr': testCase.text,
          'content': 'Continue the investigation.',
        },
      );

      expect(
        issues,
        contains(TaskAgentReportRevisionIssue.checkmarkCausality),
        reason: testCase.languageCode,
      );
    }
  });

  test('validation preserves active risks in every supported language', () {
    const cases = [
      (
        languageCode: 'en',
        draft: 'Root cause investigation remains active.',
        preserved: 'Continue the root cause investigation.',
      ),
      (
        languageCode: 'de',
        draft: 'Die Ursache des wiederkehrenden Fehlers wird untersucht.',
        preserved: 'Die Ursache weiter untersuchen.',
      ),
      (
        languageCode: 'es',
        draft: 'La causa raíz del error recurrente sigue bajo investigación.',
        preserved: 'Investigar la causa raíz.',
      ),
      (
        languageCode: 'fr',
        draft: 'La cause racine du problème récurrent reste à examiner.',
        preserved: 'Examiner la cause racine.',
      ),
      (
        languageCode: 'cs',
        draft: 'Vyšetřování hlavní příčiny opakující se chyby pokračuje.',
        preserved: 'Prošetřit hlavní příčinu.',
      ),
      (
        languageCode: 'ro',
        draft:
            'Investigația cauzei principale a erorii recurente rămâne activă.',
        preserved: 'Investigați cauza principală.',
      ),
    ];

    for (final testCase in cases) {
      List<TaskAgentReportRevisionIssue> validate(String content) {
        return TaskAgentReportEditor.validateRevision(
          languageCode: testCase.languageCode,
          materialTaskState: const {},
          draftReport: {
            'oneLiner': testCase.draft,
            'tldr': testCase.draft,
            'content': testCase.draft,
          },
          candidateReport: {
            'oneLiner': 'Current action',
            'tldr': 'Current action remains open.',
            'content': content,
          },
        );
      }

      expect(
        validate('Continue the current action.'),
        contains(TaskAgentReportRevisionIssue.missingActiveRisk),
        reason: '${testCase.languageCode} must reject an omitted risk',
      );
      expect(
        validate(testCase.preserved),
        isNot(contains(TaskAgentReportRevisionIssue.missingActiveRisk)),
        reason: '${testCase.languageCode} must accept the preserved risk',
      );
    }
  });

  test('validation accepts localized equivalent anchors', () {
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'de',
      materialTaskState: const {
        'priority': 'P1',
        'dueDate': '2026-09-30',
        'estimateMinutes': 150,
      },
      draftReport: const {
        'oneLiner': 'Risiko untersuchen',
        'tldr': 'Ursache ist unbekannt.',
        'content': '## Risiko\nUrsache untersuchen.',
      },
      candidateReport: const {
        'oneLiner': 'Ursache bis 30. September 2026 untersuchen',
        'tldr': 'P1 mit 2,5 Stunden Aufwand. Das Risiko bleibt aktiv.',
        'content': '## Nächster Schritt\nUrsache untersuchen.',
      },
    );

    expect(issues, isEmpty);
  });

  test('estimate validation requires a time unit', () {
    const draftReport = {
      'oneLiner': 'Run the evaluation',
      'tldr': 'The estimate is 120 minutes.',
      'content': 'Two actions remain.',
    };
    const materialTaskState = <String, Object?>{'estimateMinutes': 120};

    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: materialTaskState,
        draftReport: draftReport,
        candidateReport: const {
          'oneLiner': 'Run the evaluation',
          'tldr': 'Two actions remain.',
          'content': 'Complete both actions.',
        },
      ),
      [TaskAgentReportRevisionIssue.missingEstimate],
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: materialTaskState,
        draftReport: draftReport,
        candidateReport: const {
          'oneLiner': 'Run the two-hour evaluation',
          'tldr': 'Two actions remain within the 2-hour estimate.',
          'content': 'Complete both actions.',
        },
      ),
      isEmpty,
    );
  });

  glados.Glados(
    glados.IntAnys(glados.any).intInRange(1, 24),
    glados.ExploreConfig(numRuns: 60),
  ).test(
    'estimate anchors cannot be satisfied by an unrelated bare count',
    (hours) {
      final materialTaskState = <String, Object?>{
        'estimateMinutes': hours * 60,
      };
      final draftReport = {
        'oneLiner': 'Run the evaluation',
        'tldr': 'The estimate is $hours hours.',
        'content': 'Complete the evaluation.',
      };

      final bareCountIssues = TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: materialTaskState,
        draftReport: draftReport,
        candidateReport: {
          'oneLiner': 'Run the evaluation',
          'tldr': '$hours actions remain.',
          'content': 'Complete the actions.',
        },
      );
      final groundedIssues = TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: materialTaskState,
        draftReport: draftReport,
        candidateReport: {
          'oneLiner': 'Run the evaluation',
          'tldr': '$hours-hour estimate.',
          'content': 'Complete the actions.',
        },
      );

      expect(
        bareCountIssues,
        contains(TaskAgentReportRevisionIssue.missingEstimate),
        reason: 'hours=$hours',
      );
      expect(groundedIssues, isEmpty, reason: 'hours=$hours');
    },
    tags: 'glados',
  );

  test('validation rejects invented priority and progress on new actions', () {
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Vier Aufgaben stehen an',
          'tldr': 'Zuerst API-Umfang klären.',
          'content': 'API-Umfang klären.',
        },
        candidateReport: const {
          'oneLiner': 'API-Umfang klären',
          'tldr': 'Priorität: API-Klärung mit Ben.',
          'content': 'API-Umfang mit Ben klären.',
        },
      ),
      [TaskAgentReportRevisionIssue.unsupportedPriority],
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {
          'newChecklistItems': [
            'CSV-Export reparieren',
            'Testdaten anfragen',
          ],
        },
        draftReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Zwei konkrete Aktionen stehen an.',
          'content': 'CSV-Export reparieren und Testdaten bei Sam anfragen.',
        },
        candidateReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Du hast diese Punkte bereits markiert.',
          'content': 'CSV-Export reparieren und Testdaten bei Sam anfragen.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
    );
  });

  test('validation preserves grounded completed-item wording', () {
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'de',
      materialTaskState: const {},
      draftReport: const {
        'oneLiner': 'Fehler trat erneut auf',
        'tldr': 'Der Nutzer hat den früheren Fix als erledigt markiert.',
        'content': 'Ursache des erneut aufgetretenen Fehlers untersuchen.',
      },
      candidateReport: const {
        'oneLiner': 'Ursache des erneut aufgetretenen Fehlers untersuchen',
        'tldr': 'Der frühere Fix ist vom Nutzer als erledigt markiert.',
        'content': 'Ursache des erneut aufgetretenen Fehlers untersuchen.',
      },
    );

    expect(issues, isEmpty);
  });

  test('validation preserves evidence-backed waiting states', () {
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'en',
      materialTaskState: const {},
      draftReport: const {
        'oneLiner': 'Deployment blocked until Legal approval',
        'tldr': 'Rollback test complete. Legal approval remains pending.',
        'content': 'Deploy after Marta approves the retention wording.',
      },
      candidateReport: const {
        'oneLiner': 'Await Marta’s Legal approval before deployment',
        'tldr': 'Deployment remains blocked pending Legal approval.',
        'content': '## Blocker\nLegal approval remains pending.',
      },
    );

    expect(issues, isEmpty);
  });

  test('validation removes setup filler and evidence disclaimers', () {
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {
          'newChecklistItems': [
            'CSV-Export reparieren',
            'Testdaten anfragen',
          ],
        },
        draftReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Zwei Aktionen stehen an.',
          'content': 'CSV-Export reparieren und Testdaten anfragen.',
        },
        candidateReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Zwei Aktionen stehen an.',
          'content':
              'CSV-Export reparieren und Testdaten anfragen. Diese drei '
              'Punkte stehen jetzt zur Bearbeitung an.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
    );

    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Duplicate events reappeared',
          'tldr': 'The prior fix was user-marked complete. Root cause unknown.',
          'content': 'Investigate the root cause of recurring events.',
        },
        candidateReport: const {
          'oneLiner': 'Investigate recurring duplicate events',
          'tldr':
              'The prior fix was user-marked complete, though this does not '
              'confirm resolution.',
          'content': 'Investigate the root cause of recurring events.',
        },
      ),
      [TaskAgentReportRevisionIssue.checkmarkCausality],
    );

    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {
          'newChecklistItems': [
            'CSV-Export reparieren',
            'Sam nach Testdaten fragen',
          ],
        },
        draftReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Sam nach Testdaten fragen.',
          'content': 'CSV-Export reparieren und Sam nach Testdaten fragen.',
        },
        candidateReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Warte anschließend auf Testdaten von Sam.',
          'content': 'CSV-Export reparieren und Sam nach Testdaten fragen.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
    );

    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Duplicate events reappeared',
          'tldr': 'The user marked the prior fix complete.',
          'content': 'Investigate the root cause of recurring events.',
        },
        candidateReport: const {
          'oneLiner': 'Investigate recurring duplicate events',
          'tldr': 'The issue resurfaced after device reconnection.',
          'content':
              'Duplicate sync events resolved (user-marked complete). '
              'Investigate the root cause.',
        },
      ),
      [TaskAgentReportRevisionIssue.checkmarkCausality],
    );
  });

  test('editor returns a valid isolated revision and usage', () async {
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the P1 evaluation by July 4, 2026',
              'tldr': 'The 150-minute evaluation has two remaining actions.',
              'content': 'Run the local app eval, then compare the reference.',
            }),
          ),
        ]),
        _usage(inputTokens: 50, outputTokens: 10),
      ],
    ]);
    final result =
        await _createEditor(
          provider: provider,
          inferenceRepository: inferenceRepository,
        ).edit(
          draft: draft,
          languageCode: 'en',
          materialTaskState: materialState,
          consumptionAgentId: 'agent-id',
          consumptionTaskId: 'task-id',
          consumptionCategoryId: 'category-id',
          consumptionWakeRunKey: 'run-key',
          consumptionThreadId: 'thread-id',
        );

    expect(result.revision?.content, contains('compare the reference'));
    expect(result.hadRevision, isTrue);
    expect(result.attempts, 1);
    expect(result.validationIssues, isEmpty);
    expect(result.usage?.inputTokens, 50);
    expect(result.usage?.outputTokens, 10);
    expect(inferenceRepository.requests, hasLength(1));
    final request = inferenceRepository.requests.single;
    expect(request.model, meliousQwen35122BA10BModelId);
    expect(request.temperature, 0);
    expect(request.toolNames, [TaskAgentToolNames.updateReport]);
    final serializedMessages = jsonEncode(
      request.messages.map((message) => message.toJson()).toList(),
    );
    expect(serializedMessages, contains('materialTaskState'));
    expect(serializedMessages, contains('estimateMinutes'));
    expect(serializedMessages, isNot(contains('private-id')));
  });

  test('editor retries with exact issues and merges usage', () async {
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the evaluation',
              'tldr': 'Two actions remain. No blockers.',
              'content': 'Checklist created.',
            }),
          ),
        ]),
        _usage(inputTokens: 50, outputTokens: 10),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the P1 evaluation by July 4, 2026',
              'tldr': 'The 150-minute evaluation has two remaining actions.',
              'content': 'Run the local app eval, then compare the reference.',
            }),
          ),
        ]),
        _usage(inputTokens: 40, outputTokens: 8),
      ],
    ]);
    final result =
        await _createEditor(
          provider: provider,
          inferenceRepository: inferenceRepository,
        ).edit(
          draft: draft,
          languageCode: 'en',
          materialTaskState: materialState,
        );

    expect(result.revision, isNotNull);
    expect(result.attempts, 2);
    expect(result.validationIssues, isEmpty);
    expect(result.usage?.inputTokens, 90);
    expect(result.usage?.outputTokens, 18);
    final repairMessages = jsonEncode(
      inferenceRepository.requests.last.messages
          .map((message) => message.toJson())
          .toList(),
    );
    expect(repairMessages, contains('rejectedReport'));
    expect(repairMessages, contains('requiredCorrections'));
    expect(repairMessages, contains('missingPriority'));
    expect(repairMessages, contains('processNarration'));
  });

  test('editor rejects the final invalid candidate', () async {
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the evaluation',
              'tldr': 'No blockers.',
              'content': 'Checklist created.',
            }),
          ),
        ]),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Run the evaluation',
              'tldr': 'Ready to begin.',
              'content': 'The checklist contains two items.',
            }),
          ),
        ]),
      ],
    ]);
    final result =
        await _createEditor(
          provider: provider,
          inferenceRepository: inferenceRepository,
        ).edit(
          draft: draft,
          languageCode: 'en',
          materialTaskState: materialState,
        );

    expect(result.revision, isNull);
    expect(result.hadRevision, isTrue);
    expect(result.attempts, 2);
    expect(
      result.validationIssues,
      contains(TaskAgentReportRevisionIssue.processNarration),
    );
  });

  test('editor distinguishes missing and malformed report calls', () async {
    final responseSets = [
      (
        responses: [
          _toolCalls([
            (
              name: TaskAgentToolNames.setTaskTitle,
              argumentsJson: '{"title":"Ignored"}',
            ),
          ]),
        ],
        hadRevision: false,
      ),
      (
        responses: [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: 'not-json',
            ),
          ]),
        ],
        hadRevision: true,
      ),
      (
        responses: [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: '[]',
            ),
          ]),
        ],
        hadRevision: true,
      ),
    ];

    for (final responseSet in responseSets) {
      final result =
          await _createEditor(
            provider: provider,
            inferenceRepository: _QueuedInferenceRepository([
              responseSet.responses,
            ]),
            maxAttempts: 1,
          ).edit(
            draft: draft,
            languageCode: 'en',
            materialTaskState: materialState,
          );

      expect(result.revision, isNull);
      expect(
        result.hadRevision,
        responseSet.hadRevision,
        reason: '$responseSet',
      );
      expect(result.validationIssues, [
        TaskAgentReportRevisionIssue.invalidShape,
      ]);
    }
  });

  test(
    'editor deletes its isolated conversation when sending throws',
    () async {
      final repository = _ThrowingConversationRepository();
      addTearDown(repository.disposeManager);
      final editor = TaskAgentReportEditor(
        conversationRepository: repository,
        inferenceRepository: _QueuedInferenceRepository(const []),
        provider: provider,
      );

      final result = await editor.edit(
        draft: draft,
        languageCode: 'en',
        materialTaskState: materialState,
      );
      expect(result.error, isA<StateError>());
      expect(result.stackTrace, isNotNull);
      expect(result.revision, isNull);
      expect(result.attempts, 1);
      expect(repository.deleteCount, 1);
    },
  );

  test('editor retains prior-attempt usage when a repair throws', () async {
    final repository = _ThrowingConversationRepository(throwOnCall: 2);
    addTearDown(repository.disposeManager);
    final result =
        await TaskAgentReportEditor(
          conversationRepository: repository,
          inferenceRepository: _QueuedInferenceRepository(const []),
          provider: provider,
          maxAttempts: 2,
        ).edit(
          draft: draft,
          languageCode: 'en',
          materialTaskState: materialState,
        );

    expect(result.error, isA<StateError>());
    expect(result.attempts, 2);
    expect(result.usage?.inputTokens, 5);
    expect(result.usage?.outputTokens, 2);
    expect(repository.deleteCount, 2);
  });

  test('editor attempt bound is enforced at runtime', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final conversationRepository = container.read(
      conversationRepositoryProvider.notifier,
    );
    expect(
      TaskAgentReportEditor(
        conversationRepository: conversationRepository,
        inferenceRepository: _QueuedInferenceRepository(const []),
        provider: provider,
      ).maxAttempts,
      TaskAgentReportEditor.productionMaxAttempts,
    );
    for (final maxAttempts in [0, 4]) {
      expect(
        () => TaskAgentReportEditor(
          conversationRepository: conversationRepository,
          inferenceRepository: _QueuedInferenceRepository(const []),
          provider: provider,
          maxAttempts: maxAttempts,
        ),
        throwsArgumentError,
        reason: 'maxAttempts=$maxAttempts',
      );
    }
  });
}

TaskAgentReportEditor _createEditor({
  required AiConfigInferenceProvider provider,
  required InferenceRepositoryInterface inferenceRepository,
  int maxAttempts = 2,
}) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return TaskAgentReportEditor(
    conversationRepository: container.read(
      conversationRepositoryProvider.notifier,
    ),
    inferenceRepository: inferenceRepository,
    provider: provider,
    maxAttempts: maxAttempts,
  );
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.messages,
    required this.toolNames,
    required this.model,
    required this.temperature,
  });

  final List<ChatCompletionMessage> messages;
  final List<String> toolNames;
  final String model;
  final double temperature;
}

class _QueuedInferenceRepository extends InferenceRepositoryInterface {
  _QueuedInferenceRepository(this.responsesByRequest);

  final List<List<CreateChatCompletionStreamResponse>> responsesByRequest;
  final requests = <_RecordedRequest>[];
  var _requestIndex = 0;

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    InferenceImpactCollector? impactCollector,
    int? turnIndex,
  }) {
    requests.add(
      _RecordedRequest(
        messages: messages,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
        model: model,
        temperature: temperature,
      ),
    );
    final responses = _requestIndex < responsesByRequest.length
        ? responsesByRequest[_requestIndex]
        : const <CreateChatCompletionStreamResponse>[];
    _requestIndex++;
    return Stream.fromIterable(responses);
  }
}

class _ThrowingConversationRepository extends ConversationRepository {
  _ThrowingConversationRepository({this.throwOnCall = 1});

  final int throwOnCall;
  final _manager = ConversationManager(
    conversationId: 'throwing-report-editor',
    maxTurns: 2,
  );
  int deleteCount = 0;
  int sendCount = 0;

  void disposeManager() => _manager.dispose();

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    _manager.initialize(systemMessage: systemMessage);
    return 'throwing-report-editor';
  }

  @override
  ConversationManager? getConversation(String conversationId) => _manager;

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
  }) async {
    sendCount++;
    if (sendCount == throwOnCall) {
      throw StateError('send failed');
    }
    await strategy!.processToolCalls(
      toolCalls: [
        ChatCompletionMessageToolCall(
          id: 'invalid-report-$sendCount',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: TaskAgentToolNames.updateReport,
            arguments: jsonEncode({
              'oneLiner': 'Run evaluation',
              'tldr': 'Ready to begin.',
              'content': 'Checklist created.',
            }),
          ),
        ),
      ],
      manager: _manager,
    );
    return const InferenceUsage(inputTokens: 5, outputTokens: 2);
  }

  @override
  void deleteConversation(String conversationId) {
    deleteCount++;
  }
}

CreateChatCompletionStreamResponse _usage({
  required int inputTokens,
  required int outputTokens,
}) {
  return CreateChatCompletionStreamResponse(
    id: 'usage',
    choices: const [],
    object: 'chat.completion.chunk',
    created: 0,
    usage: CompletionUsage(
      promptTokens: inputTokens,
      completionTokens: outputTokens,
      totalTokens: inputTokens + outputTokens,
    ),
  );
}

CreateChatCompletionStreamResponse _toolCalls(
  List<({String name, String argumentsJson})> calls,
) {
  return CreateChatCompletionStreamResponse(
    id: 'tools',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [
            for (var index = 0; index < calls.length; index++)
              {
                'index': index,
                'id': 'tool-$index',
                'type': 'function',
                'function': {
                  'name': calls[index].name,
                  'arguments': calls[index].argumentsJson,
                },
              },
          ],
        }),
        index: 0,
      ),
    ],
    object: 'chat.completion.chunk',
    created: 0,
  );
}
