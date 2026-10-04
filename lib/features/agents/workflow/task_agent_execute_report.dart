part of 'task_agent_workflow.dart';

/// The report finalization of [TaskAgentExecute.executeImpl]: the executor's
/// draft, optionally revised by the report editor.
extension _TaskAgentExecuteReport on TaskAgentWorkflow {
  /// The report this wake publishes: the executor's draft, revised by the
  /// report editor when the route always edits (Mistral) or the direct-Qwen
  /// detector matched a regression. Every editor outcome is recorded on
  /// [strategy] as a workflow result; a failed edit keeps the draft.
  Future<
    ({
      TaskAgentReportDraft? report,
      InferenceUsage? editorUsage,
      ReportFinalizerOutcome? outcome,
    })
  >
  _finalizeReport({
    required TaskAgentStrategy strategy,
    required AiConfigInferenceProvider provider,
    required String modelId,
    required CloudInferenceWrapper inferenceRepo,
    required Task? task,
    required bool reportWasRequired,
    required AgentTemplateContext templateCtx,
    required bool recordConsumption,
    required String? consumptionCategoryId,
    required String agentId,
    required String taskId,
    required String runKey,
    required String threadId,
  }) async {
    var effectiveReport = TaskAgentReportDraft.fromJson({
      'oneLiner': strategy.extractReportOneLiner(),
      'tldr': strategy.extractReportTldr(),
      'content': strategy.extractReportContent(),
    });
    InferenceUsage? reportEditorUsage;
    ReportFinalizerOutcome? reportFinalizerOutcome;
    final reportRoute = TaskAgentReportEditor.routeFor(
      providerType: provider.inferenceProviderType,
      modelId: modelId,
    );
    final mistralReportEditorEligible =
        reportRoute == TaskAgentReportRoute.alwaysEdited;
    final isDirectQwenExecutor = reportRoute == TaskAgentReportRoute.detected;
    final normalizedExecutorModelId = modelId.toLowerCase();
    final isDirectQwenModel =
        normalizedExecutorModelId == meliousQwen35122BA10BModelId;
    final isMistralEditorCandidate =
        normalizedExecutorModelId == meliousMistralSmall4119BInstructModelId;
    final isReportEditorCandidate =
        isMistralEditorCandidate || isDirectQwenModel;
    final reportEditorRouteEligible =
        mistralReportEditorEligible || isDirectQwenExecutor;
    final currentTaskData = task?.data;
    final currentTaskDue = currentTaskData?.due;
    final currentTaskPriority = switch (currentTaskData?.priority) {
      TaskPriority.p0Urgent => TaskPriority.p0Urgent.short,
      TaskPriority.p1High => TaskPriority.p1High.short,
      _ => null,
    };
    final materialTaskState =
        reportEditorRouteEligible && effectiveReport != null
        ? TaskAgentReportEditor.buildMaterialTaskState(
            strategy.extractSuccessfulMutations(),
            currentDueDate: currentTaskDue?.toIso8601String().substring(
              0,
              10,
            ),
            currentEstimateMinutes: currentTaskData?.estimate?.inMinutes,
            currentPriority: currentTaskPriority,
          )
        : null;
    final languageCode = materialTaskState == null
        ? null
        : materialTaskState['languageCode'] as String? ??
              task?.data.languageCode ??
              'en';
    final directQwenIssues = isDirectQwenExecutor && effectiveReport != null
        ? TaskAgentReportEditor.detectDirectQwenRegressions(
            languageCode: languageCode!,
            materialTaskState: materialTaskState!,
            report: effectiveReport.toJson(),
          ).toSet()
        : const <TaskAgentReportRevisionIssue>{};
    if (directQwenIssues.isNotEmpty) {
      final issueCodes = directQwenIssues.map((issue) => issue.name).toList()
        ..sort();
      logInfo(
        'report defect detector matched: ${issueCodes.join(',')}; '
        'executorModelId=$modelId',
        subDomain: 'reportEditor',
      );
    }
    final shouldRunReportEditor =
        mistralReportEditorEligible || directQwenIssues.isNotEmpty;
    if (!reportEditorRouteEligible && isReportEditorCandidate) {
      logInfo(
        'report editor route not eligible: '
        'providerType=${provider.inferenceProviderType.name};'
        'executorModelId=$modelId',
        subDomain: 'reportEditor',
      );
    }
    if (reportEditorRouteEligible && effectiveReport == null) {
      await strategy.recordWorkflowResult(
        toolName: reportWasRequired
            ? '${TaskAgentReportEditor.auditToolPrefix}_failed'
            : '${TaskAgentReportEditor.auditToolPrefix}_not_needed',
        errorMessage: reportWasRequired
            ? 'executor_missing_required_report'
            : null,
      );
    } else if (isDirectQwenExecutor && directQwenIssues.isEmpty) {
      await strategy.recordWorkflowResult(
        toolName: '${TaskAgentReportEditor.auditToolPrefix}_direct_qwen',
      );
    } else if (shouldRunReportEditor && effectiveReport != null) {
      // Whatever happens below, the editor ran, so its outcome is recorded.
      reportFinalizerOutcome = ReportFinalizerOutcome.failed;
      try {
        final editResult =
            await TaskAgentReportEditor(
              conversationRepository: conversationRepository,
              inferenceRepository: inferenceRepo,
              provider: provider,
            ).edit(
              draft: effectiveReport,
              languageCode: languageCode!,
              materialTaskState: materialTaskState!,
              reportDirective: TaskAgentPromptBuilder.effectiveReportDirective(
                version: templateCtx.version,
                modelId: modelId,
              ),
              consumptionAgentId: recordConsumption ? agentId : null,
              consumptionTaskId: recordConsumption ? taskId : null,
              consumptionCategoryId: consumptionCategoryId,
              consumptionWakeRunKey: recordConsumption ? runKey : null,
              consumptionThreadId: recordConsumption ? threadId : null,
              initialValidationIssues: directQwenIssues,
            );
        reportEditorUsage = editResult.usage;
        final revision = editResult.revision;
        if (editResult.error != null) {
          await strategy.recordWorkflowResult(
            toolName: '${TaskAgentReportEditor.auditToolPrefix}_failed',
            errorMessage: editResult.error.runtimeType.toString(),
          );
          logError(
            'report editor failed; preserving executor report',
            error: editResult.error,
            stackTrace: editResult.stackTrace,
          );
        } else if (revision != null) {
          effectiveReport = revision;
          reportFinalizerOutcome = ReportFinalizerOutcome.accepted;
          await strategy.recordWorkflowResult(
            toolName: isDirectQwenExecutor
                ? '${TaskAgentReportEditor.auditToolPrefix}_direct_qwen_repaired'
                : '${TaskAgentReportEditor.auditToolPrefix}_accepted',
          );
          logInfo(
            'accepted report editor revision after '
            '${editResult.attempts} attempt(s)',
            subDomain: 'reportEditor',
          );
        } else {
          reportFinalizerOutcome = ReportFinalizerOutcome.rejected;
          await strategy.recordWorkflowResult(
            toolName: '${TaskAgentReportEditor.auditToolPrefix}_rejected',
            errorMessage: editResult.validationIssues
                .map((issue) => issue.name)
                .join(','),
          );
          logInfo(
            'rejected report editor revision after '
            '${editResult.attempts} attempt(s): '
            '${editResult.validationIssues.map((issue) => issue.name).join(',')}; '
            'candidateReturned=${editResult.hadRevision}',
            subDomain: 'reportEditor',
          );
        }
      } catch (e, s) {
        await strategy.recordWorkflowResult(
          toolName: '${TaskAgentReportEditor.auditToolPrefix}_failed',
          errorMessage: e.runtimeType.toString(),
        );
        logError(
          'report editor failed; preserving executor report',
          error: e,
          stackTrace: s,
        );
      }
    }
    return (
      report: effectiveReport,
      editorUsage: reportEditorUsage,
      outcome: reportFinalizerOutcome,
    );
  }

  /// The report's provenance: the executor alone, or the executor plus the
  /// editor, which runs on the executor's provider connection.
  ReportInferenceProvenance _reportProvenance(
    InferenceRunSnapshot runSnapshot,
    ReportFinalizerOutcome? outcome,
  ) => outcome == null
      ? ReportInferenceProvenance.executorOnly(runSnapshot)
      : ReportInferenceProvenance.edited(
          runSnapshot,
          finalizer: InferenceRouteSnapshot(
            providerModelId: meliousQwen35122BA10BModelId,
            modelName: meliousQwen35122BA10BModelId,
            servingProviderConfigId:
                runSnapshot.executor.servingProviderConfigId,
            servingProviderType: runSnapshot.executor.servingProviderType,
            servingProviderName: runSnapshot.executor.servingProviderName,
            runtimeSettings: const {},
          ),
          outcome: outcome,
        );
}
