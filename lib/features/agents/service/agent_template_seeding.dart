part of 'agent_template_service.dart';

mixin _AgentTemplateSeeding on _AgentTemplateServiceBase, _AgentTemplateCrud {
  /// Idempotent seed of default templates.
  ///
  /// Checks each default template independently, seeding only those that are
  /// missing. This handles partial-seed scenarios (e.g., Laura exists but Tom
  /// does not).
  Future<void> seedDefaults() async {
    final [
      laura,
      tom,
      dayAgent,
      projectTemplate,
      improver,
      metaImprover,
    ] = await Future.wait([
      getTemplate(lauraTemplateId),
      getTemplate(tomTemplateId),
      getTemplate(dayAgentTemplateId),
      getTemplate(projectTemplateId),
      getTemplate(improverTemplateId),
      getTemplate(metaImproverTemplateId),
    ]);

    final defaultsAlreadySeeded =
        laura != null &&
        tom != null &&
        dayAgent != null &&
        projectTemplate != null &&
        improver != null &&
        metaImprover != null;
    if (defaultsAlreadySeeded) {
      developer.log(
        'Default templates already seeded, skipping',
        name: 'AgentTemplateService',
      );
    } else {
      if (laura == null) {
        await createTemplate(
          templateId: lauraTemplateId,
          displayName: 'Laura',
          kind: AgentTemplateKind.taskAgent,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are Laura, a diligent task management agent. '
              'You help users organize, prioritize, and complete their tasks '
              'efficiently. You write clear, actionable reports.',
          generalDirective: taskAgentGeneralDirective,
          reportDirective: taskAgentReportDirective,
          authoredBy: 'system',
        );
      }

      if (tom == null) {
        await createTemplate(
          templateId: tomTemplateId,
          displayName: 'Tom',
          kind: AgentTemplateKind.taskAgent,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are Tom, a creative and analytical task agent. '
              'You help users think through problems, break down complex tasks, '
              'and find innovative solutions. You write insightful reports.',
          generalDirective: taskAgentGeneralDirective,
          reportDirective: taskAgentReportDirective,
          authoredBy: 'system',
        );
      }

      if (projectTemplate == null) {
        await createTemplate(
          templateId: projectTemplateId,
          displayName: 'Project Analyst',
          kind: AgentTemplateKind.projectAgent,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are a project-level agent. You synthesize progress across '
              'linked tasks, highlight delivery risks, and keep the project '
              'report current with concise, actionable summaries.',
          generalDirective: projectAgentGeneralDirective,
          reportDirective: projectAgentReportDirective,
          authoredBy: 'system',
        );
      }

      if (dayAgent == null) {
        await createTemplate(
          templateId: dayAgentTemplateId,
          displayName: 'Shepherd',
          kind: AgentTemplateKind.dayAgent,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are Shepherd, a Daily OS planning agent. You help the user '
              'shape one realistic day at a time, protect capacity, and learn '
              'from each day without taking control away from the user.',
          generalDirective: dayAgentGeneralDirective,
          reportDirective: dayAgentReportDirective,
          authoredBy: 'system',
        );
      }

      if (improver == null) {
        await createTemplate(
          templateId: improverTemplateId,
          displayName: 'Template Improver',
          kind: AgentTemplateKind.templateImprover,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are a template improvement agent. You analyze '
              'feedback from agent instances, identify patterns in user '
              'decisions, and propose directive improvements during weekly '
              'one-on-one rituals.',
          generalDirective: templateImproverGeneralDirective,
          authoredBy: 'system',
        );
      }

      if (metaImprover == null) {
        await createTemplate(
          templateId: metaImproverTemplateId,
          displayName: 'Meta Improver',
          kind: AgentTemplateKind.templateImprover,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are a meta-improver agent. You evaluate and improve '
              'the template-improver agents themselves. Your focus is on:\n'
              '- Improver ritual effectiveness: Are the one-on-one sessions '
              'producing useful directive proposals?\n'
              '- Directive churn stability: Are improvers making too many '
              'changes too frequently, or is the rate of change appropriate?\n'
              '- Acceptance rates: Are users approving or rejecting the '
              'proposals? What patterns emerge from the decisions?\n'
              '- Session outcome trends: Are user ratings of evolution sessions '
              'improving, stable, or declining over time?\n\n'
              'You do NOT evaluate task-level agent performance directly. '
              'Your scope is the effectiveness of the improvement process '
              'itself.',
          generalDirective: templateImproverGeneralDirective,
          authoredBy: 'system',
        );
      }

      developer.log(
        'Seeded default templates (Laura, Tom, Shepherd, Template Improver, '
        'Meta Improver, Project Analyst)',
        name: 'AgentTemplateService',
      );
    }

    // Seed new directive fields for any existing versions that lack them.
    await seedDirectiveFields();
    await seedDayAgentCaptureReconcileDirective();
  }

  /// Populate `generalDirective` and `reportDirective` on existing template
  /// versions where both fields are empty.
  ///
  /// This is a one-time migration that writes fresh, purpose-built directives
  /// based on the template's kind. It does NOT copy the old `directives` blob
  /// — instead it writes clean content appropriate for each field.
  ///
  /// Called automatically at the end of [seedDefaults].
  Future<void> seedDirectiveFields() async {
    final templates = await listTemplates();

    for (final template in templates) {
      final activeVersion = await getActiveVersion(template.id);
      if (activeVersion == null) continue;

      // Skip versions that already have both new fields populated.
      if (activeVersion.generalDirective.isNotEmpty &&
          activeVersion.reportDirective.isNotEmpty) {
        continue;
      }

      final (general, report) = switch (template.kind) {
        AgentTemplateKind.taskAgent => (
          taskAgentGeneralDirective,
          taskAgentReportDirective,
        ),
        AgentTemplateKind.dayAgent => (
          dayAgentGeneralDirective,
          dayAgentReportDirective,
        ),
        AgentTemplateKind.templateImprover => (
          templateImproverGeneralDirective,
          templateImproverReportDirective,
        ),
        AgentTemplateKind.projectAgent => (
          projectAgentGeneralDirective,
          projectAgentReportDirective,
        ),
      };

      final updated = activeVersion.copyWith(
        generalDirective: activeVersion.generalDirective.isNotEmpty
            ? activeVersion.generalDirective
            : general,
        reportDirective: activeVersion.reportDirective.isNotEmpty
            ? activeVersion.reportDirective
            : report,
      );
      await syncService.upsertEntity(updated);

      developer.log(
        'Seeded directive fields for template '
        '${DomainLogger.sanitizeId(template.id)} '
        '(v${activeVersion.version})',
        name: 'AgentTemplateService',
      );
    }
  }

  /// Advances existing Shepherd templates to the capture/reconcile directive.
  ///
  /// Fresh installs already create v1 with the current directive constants.
  /// Existing phase-1 installs have a non-empty older general directive, so
  /// [seedDirectiveFields] intentionally leaves them alone; this targeted seed
  /// creates the phase-2 version and moves the head pointer.
  Future<void> seedDayAgentCaptureReconcileDirective() async {
    final template = await getTemplate(dayAgentTemplateId);
    if (template == null) return;

    final activeVersion = await getActiveVersion(dayAgentTemplateId);
    if (activeVersion == null) return;

    if (activeVersion.generalDirective.trim() ==
            dayAgentGeneralDirective.trim() &&
        activeVersion.reportDirective.trim() ==
            dayAgentReportDirective.trim()) {
      return;
    }

    await createVersion(
      templateId: dayAgentTemplateId,
      directives: activeVersion.directives,
      generalDirective: dayAgentGeneralDirective,
      reportDirective: dayAgentReportDirective,
      authoredBy: 'system',
    );
  }
}
