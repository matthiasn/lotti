import 'dart:developer' as developer;

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Idempotent seeding of default templates and their directive fields.
///
/// Creates the well-known default templates (Laura, Tom, Shepherd, etc.) and
/// backfills directive fields on existing versions. All template reads and
/// writes are delegated to [AgentTemplateCrud]; only [seedDirectiveFields]
/// writes versions directly through the sync service.
class AgentTemplateSeeding {
  AgentTemplateSeeding({
    required this.repository,
    required this.syncService,
    required this.crud,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;
  final AgentTemplateCrud crud;

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
      eventTemplate,
      improver,
      metaImprover,
    ] = await Future.wait([
      crud.getTemplate(lauraTemplateId),
      crud.getTemplate(tomTemplateId),
      crud.getTemplate(dayAgentTemplateId),
      crud.getTemplate(projectTemplateId),
      crud.getTemplate(eventTemplateId),
      crud.getTemplate(improverTemplateId),
      crud.getTemplate(metaImproverTemplateId),
    ]);

    final defaultsAlreadySeeded =
        laura != null &&
        tom != null &&
        dayAgent != null &&
        projectTemplate != null &&
        eventTemplate != null &&
        improver != null &&
        metaImprover != null;
    if (defaultsAlreadySeeded) {
      developer.log(
        'Default templates already seeded, skipping',
        name: 'AgentTemplateService',
      );
    } else {
      if (laura == null) {
        await crud.createTemplate(
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
        await crud.createTemplate(
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
        await crud.createTemplate(
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

      if (eventTemplate == null) {
        await crud.createTemplate(
          templateId: eventTemplateId,
          displayName: 'Scribe',
          kind: AgentTemplateKind.eventAgent,
          modelId: kDefaultAgentTemplateModelId,
          directives:
              'You are Scribe, an event-narration agent. You weave the linked '
              'photos, notes, and voice memos of an event into a short, warm '
              'recap the user would want to re-read, and surface the concrete '
              'follow-ups it throws off. You only narrate — the rating and '
              'cover photo stay with the user.',
          generalDirective: eventAgentGeneralDirective,
          reportDirective: eventAgentReportDirective,
          authoredBy: 'system',
        );
      }

      if (dayAgent == null) {
        await crud.createTemplate(
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
        await crud.createTemplate(
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
        await crud.createTemplate(
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
        'Meta Improver, Project Analyst, Scribe)',
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
    final templates = await crud.listTemplates();

    for (final template in templates) {
      final activeVersion = await crud.getActiveVersion(template.id);
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
        AgentTemplateKind.eventAgent => (
          eventAgentGeneralDirective,
          eventAgentReportDirective,
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
    final template = await crud.getTemplate(dayAgentTemplateId);
    if (template == null) return;

    final activeVersion = await crud.getActiveVersion(dayAgentTemplateId);
    if (activeVersion == null) return;

    if (activeVersion.generalDirective.trim() ==
            dayAgentGeneralDirective.trim() &&
        activeVersion.reportDirective.trim() ==
            dayAgentReportDirective.trim()) {
      return;
    }

    await crud.createVersion(
      templateId: dayAgentTemplateId,
      directives: activeVersion.directives,
      generalDirective: dayAgentGeneralDirective,
      reportDirective: dayAgentReportDirective,
      authoredBy: 'system',
    );
  }
}
