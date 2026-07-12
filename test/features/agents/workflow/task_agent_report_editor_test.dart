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
  const evolvedReportDirective = '''
Write as a pragmatic project partner, not as a status bot. Lead with the
decision-relevant situation in one or two natural sentences. Then use a
`## Next moves` section for concrete actions with owners or dates when known,
and a `## Decisions needed` section only when the user must resolve something.
Use the task language, omit empty sections and process narration, and never
turn task metadata or a checklist edit into an accomplishment.
''';

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

  test('editor support is limited to the validated Melious route', () {
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
        contains('reportDirective'),
        contains('title, detail, and section policy'),
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

  test(
    'material state keeps current task anchors until mutations replace them',
    () {
      expect(
        TaskAgentReportEditor.buildMaterialTaskState(
          const [],
          currentDueDate: '2026-09-30',
          currentEstimateMinutes: 120,
          currentPriority: 'P1',
        ),
        {
          'priority': 'P1',
          'dueDate': '2026-09-30',
          'estimateMinutes': 120,
        },
      );
      expect(
        TaskAgentReportEditor.buildMaterialTaskState(
          const [
            (
              toolName: TaskAgentToolNames.updateTaskDueDate,
              arguments: {'dueDate': '2026-10-15'},
            ),
          ],
          currentDueDate: '2026-09-30',
        )['dueDate'],
        '2026-10-15',
      );
    },
  );

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

  test('direct Qwen detector catches paired release-run regressions', () {
    const cases = [
      (
        name: 'implicit workflow false progress',
        languageCode: 'en',
        materialTaskState: <String, Object?>{
          'newChecklistItems': ['Fix profile seeding'],
        },
        report: <String, dynamic>{
          'oneLiner': 'Fix inference profile seeding',
          'tldr': 'Implementation work is underway.',
          'content': 'The work is in progress. Fix profile seeding next.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
        },
      ),
      (
        name: 'German plan false progress',
        languageCode: 'de',
        materialTaskState: <String, Object?>{
          'priority': 'P1',
          'dueDate': '2026-09-30',
          'newChecklistItems': ['API-Umfang klaeren'],
        },
        report: <String, dynamic>{
          'oneLiner': 'Beta-Vorbereitung laeuft bis 30. September 2026',
          'tldr': 'Die Aufgabe mit Prioritaet P1 laeuft bereits.',
          'content': 'Die Arbeit laeuft bereits. API-Umfang klaeren.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
        },
      ),
      (
        name: 'German plan false progress from current Melious run',
        languageCode: 'de',
        materialTaskState: <String, Object?>{
          'priority': 'P1',
          'dueDate': '2026-09-30',
          'newChecklistItems': ['API-Umfang mit Ben klären'],
        },
        report: <String, dynamic>{
          'oneLiner':
              'Beta-Vorbereitung läuft mit vier Schritten bis '
              '30. September 2026',
          'tldr': 'Vier konkrete Arbeitsschritte warten auf Bearbeitung.',
          'content':
              'Der Auftrag ist priorisiert (P1) und bereits in Bearbeitung.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
        },
      ),
      (
        name: 'Spanish plan false progress from current Melious run',
        languageCode: 'es',
        materialTaskState: <String, Object?>{
          'newChecklistItems': ['Llamar al proveedor'],
        },
        report: <String, dynamic>{
          'oneLiner': 'Dos acciones pendientes para desbloquear la activación',
          'tldr': 'Faltan las credenciales del proveedor.',
          'content': 'La activación está en progreso pero bloqueada.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
        },
      ),
      (
        name: 'recorded priority omission',
        languageCode: 'en',
        materialTaskState: <String, Object?>{
          'priority': 'P1',
          'dueDate': '2026-10-15',
        },
        report: <String, dynamic>{
          'oneLiner': 'Customer interviews complete',
          'tldr': 'Legal review remains blocked.',
          'content': 'Launch deadline: October 15, 2026.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.missingPriority,
        },
      ),
      (
        name: 'duplicate reconciliation false progress',
        languageCode: 'en',
        materialTaskState: <String, Object?>{
          'newChecklistItems': ['Submit the expense report'],
        },
        report: <String, dynamic>{
          'oneLiner': 'Three pending actions',
          'tldr': 'Expense report preparation is underway.',
          'content': 'Task is in progress. Submit the report by Friday.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
        },
      ),
      (
        name: 'German deferred-scope leak',
        languageCode: 'de',
        materialTaskState: <String, Object?>{
          'newChecklistItems': ['CSV-Export reparieren'],
        },
        report: <String, dynamic>{
          'oneLiner': 'CSV-Export-Reparatur geplant',
          'tldr': 'Die Stabilisierung des CSV-Exports läuft.',
          'content':
              'CSV-Export reparieren. Ein Newsletter wurde bewusst '
              'zurückgestellt und gehört nicht zum aktuellen Scope.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
          TaskAgentReportRevisionIssue.deferredScopeLeak,
        },
      ),
      (
        name: 'German future-scope phrasing from current Melious run',
        languageCode: 'de',
        materialTaskState: <String, Object?>{
          'newChecklistItems': ['CSV-Export reparieren'],
        },
        report: <String, dynamic>{
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Drei konkrete Aktionen stehen an.',
          'content':
              'Ein Newsletter wurde als zukünftige Möglichkeit erwähnt, '
              'soll aber erst später betrachtet werden.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.deferredScopeLeak,
        },
      ),
      (
        name: 'certificate deferred-scope leak',
        languageCode: 'en',
        materialTaskState: <String, Object?>{
          'newChecklistItems': ['Request replacement certificate'],
        },
        report: <String, dynamic>{
          'oneLiner': 'Production certificate rotation underway',
          'tldr': 'Request the replacement certificate next.',
          'content':
              'Certificate rotation is underway. Administrator analytics '
              'dashboard work is scoped out for now.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.processNarration,
          TaskAgentReportRevisionIssue.deferredScopeLeak,
        },
      ),
      (
        name: 'resurfaced issue causal invention',
        languageCode: 'en',
        materialTaskState: <String, Object?>{},
        report: <String, dynamic>{
          'oneLiner': 'Duplicate sync issue resurfaced',
          'tldr': 'The duplicate sync fix did not fully resolve the issue.',
          'content':
              'Duplicate events reappeared. The current fix addressed the '
              'symptom. Investigate the root cause.',
        },
        expected: <TaskAgentReportRevisionIssue>{
          TaskAgentReportRevisionIssue.checkmarkCausality,
        },
      ),
    ];

    for (final testCase in cases) {
      expect(
        TaskAgentReportEditor.detectDirectQwenRegressions(
          languageCode: testCase.languageCode,
          materialTaskState: testCase.materialTaskState,
          report: testCase.report,
        ),
        unorderedEquals(testCase.expected),
        reason: testCase.name,
      );
    }
  });

  test('direct Qwen detector preserves directive-controlled free text', () {
    const reports = [
      <String, dynamic>{
        'oneLiner': 'Fix profile seeding',
        'tldr': 'The checklist remains the clearest view of pending work.',
        'content':
            '## Checklist\n- Fix profile seeding\n\n## Goal\nShip safely.',
      },
      <String, dynamic>{
        'oneLiner': 'Fix profile seeding',
        'tldr': 'No blockers.',
        'content': 'Fix profile seeding next.',
      },
      <String, dynamic>{
        'oneLiner': 'Monitor the deployed fix',
        'tldr': 'The release log records that the fix was applied.',
        'content': 'Monitor the rollout for new evidence.',
      },
    ];

    for (final report in reports) {
      expect(
        TaskAgentReportEditor.detectDirectQwenRegressions(
          languageCode: 'en',
          materialTaskState: const {
            'newChecklistItems': ['Fix profile seeding'],
          },
          report: report,
        ),
        isEmpty,
        reason: '$report',
      );
    }
  });

  test('direct Qwen detector catches shape, anchors, and formal register', () {
    final issues = TaskAgentReportEditor.detectDirectQwenRegressions(
      languageCode: 'fr',
      materialTaskState: const {
        'priority': 'P1',
        'dueDate': '2026-09-30',
        'estimateMinutes': 150,
      },
      report: const {
        'content': 'Vous pouvez commencer.',
      },
    );

    expect(
      issues,
      unorderedEquals({
        TaskAgentReportRevisionIssue.invalidShape,
        TaskAgentReportRevisionIssue.missingPriority,
        TaskAgentReportRevisionIssue.missingDueDate,
        TaskAgentReportRevisionIssue.missingEstimate,
        TaskAgentReportRevisionIssue.formalRegister,
      }),
    );
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

  test('German sentence-initial Sie is not treated as formal register', () {
    const report = {
      'oneLiner': 'Die Berichte sind erstellt',
      'tldr': 'Sie werden morgen geprüft.',
      'content': 'Die Berichte sind erstellt. Sie werden morgen geprüft.',
    };

    expect(
      TaskAgentReportEditor.detectDirectQwenRegressions(
        languageCode: 'de',
        materialTaskState: const {},
        report: report,
      ),
      isNot(contains(TaskAgentReportRevisionIssue.formalRegister)),
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {},
        draftReport: report,
        candidateReport: report,
      ),
      isNot(contains(TaskAgentReportRevisionIssue.formalRegister)),
    );
  });

  test('validation rejects localized resolution claims from checkmarks', () {
    const cases = [
      (
        languageCode: 'en',
        text:
            'The prior fix was user-marked complete, so the issue is resolved.',
      ),
      (
        languageCode: 'en',
        text:
            'The initial fix was applied but did not fully resolve the issue; '
            'it addressed the symptom rather than the root cause.',
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

  test('checkmark-causality correction remains active during repair', () {
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'en',
      materialTaskState: const {},
      draftReport: const {
        'oneLiner': 'Duplicate sync issue reappeared',
        'tldr': 'The previous fix did not fully resolve the issue.',
        'content': 'Investigate the root cause.',
      },
      candidateReport: const {
        'oneLiner': 'Duplicate sync events reappeared',
        'tldr': 'Root cause investigation is required.',
        'content': 'Investigate before the fix can be validated.',
      },
    );

    expect(issues, [TaskAgentReportRevisionIssue.checkmarkCausality]);
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

  test('validation accepts a preserved scheduling constraint', () {
    const draftReport = {
      'oneLiner': 'Deployment pending until the maintenance window',
      'tldr': 'The pull request is merged; deployment remains pending.',
      'content': "Deploy during tomorrow's maintenance window.",
    };

    List<TaskAgentReportRevisionIssue> validate(String content) {
      return TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: draftReport,
        candidateReport: {
          'oneLiner': 'Release status updated',
          'tldr': content,
          'content': content,
        },
      );
    }

    expect(
      validate(
        "Deployment remains pending for tomorrow's maintenance window.",
      ),
      isNot(contains(TaskAgentReportRevisionIssue.missingActiveRisk)),
    );
    expect(
      validate('The pull request is merged.'),
      contains(TaskAgentReportRevisionIssue.missingActiveRisk),
    );
  });

  test('bare deferred scheduling does not look like excluded scope', () {
    const report = {
      'oneLiner': 'Deployment deferred until Friday',
      'tldr': 'Deployment waits for the Friday maintenance window.',
      'content': 'Deployment deferred until the Friday maintenance window.',
    };

    expect(
      TaskAgentReportEditor.detectDirectQwenRegressions(
        languageCode: 'en',
        materialTaskState: const {},
        report: report,
      ),
      isNot(contains(TaskAgentReportRevisionIssue.deferredScopeLeak)),
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: report,
        candidateReport: report,
      ),
      isNot(contains(TaskAgentReportRevisionIssue.deferredScopeLeak)),
    );
  });

  test('validation rejects explicitly deferred draft scope', () {
    const draftReport = {
      'oneLiner': 'Repair the CSV export',
      'tldr': 'Three committed actions remain.',
      'content':
          'Repair the export. The newsletter idea is explicitly deferred and '
          'must not be included.',
    };

    List<TaskAgentReportRevisionIssue> validate(String content) {
      return TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: draftReport,
        candidateReport: {
          'oneLiner': 'Repair the CSV export',
          'tldr': 'Three committed actions remain.',
          'content': content,
        },
      );
    }

    expect(
      validate('Repair the export; the newsletter remains outside scope.'),
      contains(TaskAgentReportRevisionIssue.deferredScopeLeak),
    );
    expect(
      validate('Repair the export, request test data, then run regression.'),
      isNot(contains(TaskAgentReportRevisionIssue.deferredScopeLeak)),
    );
    const scopedOutDraft = {
      'oneLiner': 'Rotate the production certificate',
      'tldr': 'Three certificate actions remain.',
      'content':
          'Administrator analytics dashboard work is scoped out for this '
          'certificate rotation.',
    };
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: scopedOutDraft,
        candidateReport: const {
          'oneLiner': 'Request the production certificate',
          'tldr': 'Three certificate actions remain.',
          'content': 'The analytics dashboard remains scoped out.',
        },
      ),
      contains(TaskAgentReportRevisionIssue.deferredScopeLeak),
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content':
              'Ein Newsletter wurde als zukünftige Idee erwähnt, soll aber '
              'aktuell nicht bearbeitet werden.',
        },
        candidateReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content': 'Newsletter später bearbeiten und CSV-Export reparieren.',
        },
      ),
      contains(TaskAgentReportRevisionIssue.deferredScopeLeak),
    );
    const germanDeferredDraft = {
      'oneLiner': 'CSV-Export reparieren',
      'tldr': 'Drei konkrete Schritte stehen an.',
      'content':
          'Ein Newsletter wurde als zukünftige Idee erwähnt, soll aber '
          'aktuell nicht aufgenommen werden.',
    };
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {},
        draftReport: germanDeferredDraft,
        candidateReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content':
              '## Aktueller Stand\nCSV-Export reparieren, Testdaten anfragen '
              'und Regressionstest ausführen.',
        },
      ),
      isNot(contains(TaskAgentReportRevisionIssue.deferredScopeLeak)),
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'de',
        materialTaskState: const {},
        draftReport: germanDeferredDraft,
        candidateReport: const {
          'oneLiner': 'CSV-Export reparieren',
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content': 'Newsletter später aufnehmen und CSV-Export reparieren.',
        },
      ),
      contains(TaskAgentReportRevisionIssue.deferredScopeLeak),
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: scopedOutDraft,
        candidateReport: const {
          'oneLiner': 'Request the production certificate',
          'tldr': 'Three certificate rotation actions remain.',
          'content':
              'Request the certificate, get staging access, then rotate it.',
        },
      ),
      isNot(contains(TaskAgentReportRevisionIssue.deferredScopeLeak)),
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Repair the CSV export',
          'tldr': 'Three export actions remain.',
          'content': 'Do not include the newsletter.',
        },
        candidateReport: const {
          'oneLiner': 'Repair the CSV export',
          'tldr': 'Three export actions remain.',
          'content': 'Repair the export and include the newsletter.',
        },
      ),
      contains(TaskAgentReportRevisionIssue.deferredScopeLeak),
    );
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
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content': 'Export reparieren, Testdaten anfragen, Tests ausführen.',
        },
        candidateReport: const {
          'oneLiner': 'CSV-Export stabilisieren',
          'tldr': 'Die Stabilisierung des CSV-Exports läuft.',
          'content': 'Die Arbeit wurde aufgenommen.',
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
          'tldr': 'Root cause investigation is needed.',
          'content': 'Investigate the root cause of recurring events.',
        },
        candidateReport: const {
          'oneLiner': 'Investigate recurring duplicate events',
          'tldr': 'Root cause investigation is needed.',
          'content':
              'Once the root cause is understood, additional fixes can be '
              'applied and validated.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Run the evaluation',
          'tldr': 'Compare the candidate with the reference.',
          'content': 'Run the evaluation and compare the models.',
        },
        candidateReport: const {
          'oneLiner': 'Run the evaluation',
          'tldr': 'Compare the candidate with the reference.',
          'content': '## Decision needed\nNone at this time.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
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
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content': 'Export reparieren, Testdaten anfragen, Tests ausführen.',
        },
        candidateReport: const {
          'oneLiner': 'CSV-Export stabilisieren',
          'tldr': 'Drei konkrete Schritte stehen an.',
          'content':
              'Die Arbeit am CSV-Export läuft aktuell. Export reparieren, '
              'Testdaten anfragen und Tests ausführen.',
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

  test('validation rejects waiting invented from an unperformed request', () {
    const materialTaskState = {
      'newChecklistItems': ['Request replacement certificate from Security'],
    };
    const candidateReport = {
      'oneLiner': 'Awaiting replacement certificate from Security',
      'tldr': 'Three actions remain pending.',
      'content': 'The certificate must arrive before rotation can proceed.',
    };
    final issues = TaskAgentReportEditor.validateRevision(
      languageCode: 'en',
      materialTaskState: materialTaskState,
      draftReport: const {
        'oneLiner': 'Awaiting replacement certificate from Security',
        'tldr': 'Request the replacement certificate next.',
        'content': 'Request the certificate, then rotate it.',
      },
      candidateReport: candidateReport,
    );

    expect(issues, [TaskAgentReportRevisionIssue.processNarration]);
    expect(
      TaskAgentReportEditor.detectDirectQwenRegressions(
        languageCode: 'en',
        materialTaskState: materialTaskState,
        report: candidateReport,
      ),
      [TaskAgentReportRevisionIssue.processNarration],
    );
  });

  test('validation removes setup filler and evidence disclaimers', () {
    for (final phrase in [
      'Six workflow items queued from implementation to release.',
      'Six workflow items identified from implementation to release.',
      'The implementation through release workflow is ready.',
      'Production certificate rotation is underway.',
    ]) {
      expect(
        TaskAgentReportEditor.validateRevision(
          languageCode: 'en',
          materialTaskState: const {
            'newChecklistItems': [
              'Fix inference profile seeding',
              'Create pull request',
            ],
          },
          draftReport: const {
            'oneLiner': 'Fix inference profile seeding',
            'tldr': 'Fix seeding, then create and review the pull request.',
            'content': 'Fix inference profile seeding and create the PR.',
          },
          candidateReport: {
            'oneLiner': 'Fix inference profile seeding',
            'tldr': phrase,
            'content': 'Fix inference profile seeding and create the PR.',
          },
        ),
        [TaskAgentReportRevisionIssue.processNarration],
        reason: 'phrase=$phrase',
      );
    }
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Investigate duplicate sync events',
          'tldr': 'Investigation is needed.',
          'content': 'Investigate the recurrence.',
        },
        candidateReport: const {
          'oneLiner': 'Investigation underway',
          'tldr': 'Investigation is needed to find the root cause.',
          'content': 'The investigation is underway.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
    );
    expect(
      TaskAgentReportEditor.validateRevision(
        languageCode: 'en',
        materialTaskState: const {},
        draftReport: const {
          'oneLiner': 'Run the evaluation',
          'tldr': 'Compare the candidate with the reference.',
          'content': 'Run the evaluation and compare the models.',
        },
        candidateReport: const {
          'oneLiner': 'Run the evaluation',
          'tldr': 'Configuration is complete; begin the evaluation.',
          'content': 'Run the evaluation and compare the models.',
        },
      ),
      [TaskAgentReportRevisionIssue.processNarration],
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
    const draftWithDeferredScope = TaskAgentReportDraft(
      oneLiner: 'Task configured for model validation',
      tldr: 'P1, due July 4, 2026, estimated 150 minutes.',
      content:
          'Run eval and compare the reference. A newsletter idea is deferred '
          'and must not be included.',
    );
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
          draft: draftWithDeferredScope,
          languageCode: 'en',
          materialTaskState: materialState,
          reportDirective: evolvedReportDirective,
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
    expect(serializedMessages, contains('reportDirective'));
    expect(serializedMessages, contains('pragmatic project partner'));
    expect(serializedMessages, contains('## Next moves'));
    expect(serializedMessages, contains('## Decisions needed'));
    expect(serializedMessages, contains('Run eval and compare the reference'));
    expect(serializedMessages, isNot(contains('newsletter')));
    expect(serializedMessages, isNot(contains('private-id')));
  });

  test('editor repairs deferred scope without re-exposing the term', () async {
    const deferredDraft = TaskAgentReportDraft(
      oneLiner: 'Repair the CSV export',
      tldr: 'Three committed actions remain.',
      content:
          'Repair the export. The newsletter idea is explicitly deferred and '
          'must not be included.',
    );
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Repair the CSV export',
              'tldr': 'The newsletter remains outside scope.',
              'content': 'Repair the export; omit the newsletter.',
            }),
          ),
        ]),
      ],
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Repair the CSV export',
              'tldr': 'Three committed actions remain.',
              'content':
                  'Repair the export, request test data, then run regression.',
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
          draft: deferredDraft,
          languageCode: 'en',
          materialTaskState: const {},
          reportDirective: evolvedReportDirective,
        );

    expect(result.revision?.content, contains('run regression'));
    expect(result.attempts, 2);
    final repairMessages = jsonEncode(
      inferenceRepository.requests.last.messages
          .map((message) => message.toJson())
          .toList(),
    );
    expect(repairMessages, contains('deferredScopeLeak'));
    expect(repairMessages, isNot(contains('newsletter')));
  });

  test(
    'editor applies deterministic issues on its first isolated call',
    () async {
      final inferenceRepository = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Fix inference profile seeding',
                'tldr':
                    'Fix seeding first, then complete review, merge, and release.',
                'content':
                    'Fix inference profile seeding, create the pull request, '
                    'complete both reviews, merge, and release.',
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
            materialTaskState: const {
              'newChecklistItems': [
                'Fix inference profile seeding',
                'Create pull request',
              ],
            },
            reportDirective: evolvedReportDirective,
            initialValidationIssues: const {
              TaskAgentReportRevisionIssue.processNarration,
            },
          );

      expect(result.revision, isNotNull);
      expect(result.attempts, 1);
      final messages = jsonEncode(
        inferenceRepository.requests.single.messages
            .map((message) => message.toJson())
            .toList(),
      );
      expect(messages, contains('requiredCorrections'));
      expect(messages, contains('processNarration'));
      expect(messages, contains('Pending work is never underway'));
      expect(messages, contains('investigation is needed'));
      expect(messages, contains('Do not invent generic downstream fixes'));
      expect(messages, contains('rejectedReport'));
    },
  );

  test(
    'editor sanitizes rejected draft scope for unrelated initial issues',
    () async {
      const deferredDraft = TaskAgentReportDraft(
        oneLiner: 'Rotate the production certificate',
        tldr: 'Three certificate actions remain.',
        content:
            'Request the certificate. An administrator analytics dashboard '
            'is scoped out for now.',
      );
      final inferenceRepository = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Request the production certificate',
                'tldr': 'Three certificate actions remain.',
                'content':
                    'Request the certificate, get staging access, then rotate '
                    'it and verify webhooks.',
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
            draft: deferredDraft,
            languageCode: 'en',
            materialTaskState: const {},
            reportDirective: evolvedReportDirective,
            initialValidationIssues: const {
              TaskAgentReportRevisionIssue.processNarration,
            },
          );

      expect(result.revision, isNotNull);
      final messages = jsonEncode(
        inferenceRepository.requests.single.messages
            .map((message) => message.toJson())
            .toList(),
      );
      expect(messages, contains('rejectedReport'));
      expect(messages, isNot(contains('dashboard')));
      expect(messages, isNot(contains('analytics')));
    },
  );

  test('editor removes invented request state from its repair input', () async {
    const draft = TaskAgentReportDraft(
      oneLiner: 'Certificate rotation underway; awaiting Security',
      tldr: 'Rotation is in progress while awaiting the certificate.',
      content:
          'Rotation is actively underway. Request replacement certificate '
          'from Security. Analytics planning is out of scope.',
    );
    final inferenceRepository = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Request the replacement certificate',
              'tldr': 'Request Security certificate, then obtain access.',
              'content':
                  'Request the replacement certificate from Security. Ask '
                  'Priya for staging access, then rotate the certificate.',
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
          materialTaskState: const {
            'newChecklistItems': [
              'Request replacement certificate from Security',
              'Ask Priya for staging access',
              'Rotate certificate and verify webhook deliveries',
            ],
          },
          reportDirective: evolvedReportDirective,
          initialValidationIssues: const {
            TaskAgentReportRevisionIssue.processNarration,
            TaskAgentReportRevisionIssue.deferredScopeLeak,
          },
        );

    expect(result.revision, isNotNull);
    final messages = jsonEncode(
      inferenceRepository.requests.single.messages
          .map((message) => message.toJson())
          .toList(),
    ).toLowerCase();
    expect(messages, isNot(contains('awaiting security')));
    expect(messages, isNot(contains('actively underway')));
    expect(messages, isNot(contains('analytics planning')));
    expect(messages, isNot(contains('rejectedreport')));
    expect(messages, contains('request replacement certificate'));
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
          reportDirective: evolvedReportDirective,
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
    expect(
      repairMessages,
      contains('Include the exact current task priority `P1`'),
    );
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
          reportDirective: evolvedReportDirective,
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
            reportDirective: evolvedReportDirective,
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
        reportDirective: evolvedReportDirective,
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
          reportDirective: evolvedReportDirective,
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
    bool rethrowInferenceErrors = false,
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
