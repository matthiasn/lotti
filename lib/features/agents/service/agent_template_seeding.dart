import 'dart:developer' as developer;

import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// One default template the app seeds under a well-known id.
typedef _DefaultTemplate = ({
  String id,
  String displayName,
  AgentTemplateKind kind,
  String directives,
  String generalDirective,
  String reportDirective,
});

/// Idempotent seeding of default templates and their directive fields.
///
/// Creates the well-known default templates (Laura, Tom, Shepherd, etc.) and
/// backfills directive fields on existing versions. All template reads and
/// writes are delegated to [AgentTemplateCrud]; only [seedDirectiveFields]
/// writes versions directly through the sync service.
class AgentTemplateSeeding {
  AgentTemplateSeeding({
    required this.syncService,
    required this.crud,
  });

  final AgentSyncService syncService;
  final AgentTemplateCrud crud;

  /// The defaults, in the order they are created.
  static const List<_DefaultTemplate> _defaults = [
    (
      id: lauraTemplateId,
      displayName: 'Laura',
      kind: AgentTemplateKind.taskAgent,
      directives:
          'You are Laura, a diligent task management agent. '
          'You help users organize, prioritize, and complete their tasks '
          'efficiently. You write clear, actionable reports.',
      generalDirective: taskAgentGeneralDirective,
      reportDirective: taskAgentReportDirective,
    ),
    (
      id: tomTemplateId,
      displayName: 'Tom',
      kind: AgentTemplateKind.taskAgent,
      directives:
          'You are Tom, a creative and analytical task agent. '
          'You help users think through problems, break down complex tasks, '
          'and find innovative solutions. You write insightful reports.',
      generalDirective: taskAgentGeneralDirective,
      reportDirective: taskAgentReportDirective,
    ),
    (
      id: projectTemplateId,
      displayName: 'Project Analyst',
      kind: AgentTemplateKind.projectAgent,
      directives:
          'You are a project-level agent. You synthesize progress across '
          'linked tasks, highlight delivery risks, and keep the project '
          'report current with concise, actionable summaries.',
      generalDirective: projectAgentGeneralDirective,
      reportDirective: projectAgentReportDirective,
    ),
    (
      id: eventTemplateId,
      displayName: 'Scribe',
      kind: AgentTemplateKind.eventAgent,
      directives:
          'You are Scribe, an event-narration agent. You weave the linked '
          'photos, notes, and voice memos of an event into a short, warm '
          'recap the user would want to re-read, and surface the concrete '
          'follow-ups it throws off. You only narrate — the rating and '
          'cover photo stay with the user.',
      generalDirective: eventAgentGeneralDirective,
      reportDirective: eventAgentReportDirective,
    ),
    (
      id: dayAgentTemplateId,
      displayName: 'Shepherd',
      kind: AgentTemplateKind.dayAgent,
      directives:
          'You are Shepherd, a Daily OS planning agent. You help the user '
          'shape one realistic day at a time, protect capacity, and learn '
          'from each day without taking control away from the user.',
      generalDirective: dayAgentGeneralDirective,
      reportDirective: dayAgentReportDirective,
    ),
    (
      id: improverTemplateId,
      displayName: 'Template Improver',
      kind: AgentTemplateKind.templateImprover,
      directives:
          'You are a template improvement agent. You analyze '
          'feedback from agent instances, identify patterns in user '
          'decisions, and propose directive improvements during weekly '
          'one-on-one rituals.',
      generalDirective: templateImproverGeneralDirective,
      reportDirective: '',
    ),
    (
      id: metaImproverTemplateId,
      displayName: 'Meta Improver',
      kind: AgentTemplateKind.templateImprover,
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
      reportDirective: '',
    ),
  ];

  /// Idempotent seed of default templates.
  ///
  /// Each default is created only when no row is stored under its id —
  /// **a removed one included** (ADR 0100). A default the user deleted stays
  /// deleted, on this device and, because the deletion syncs as a tombstone,
  /// on every other; a default that ships in a later release has no row yet
  /// and is seeded as usual. The typed reads hide a tombstone, so the check
  /// reads with `getEntityIncludingDeleted`.
  ///
  /// A device that seeds before it has received a peer's deletion writes a
  /// version concurrent with it; the seed is stamped at `agentSeedInstant`,
  /// so the deletion wins on every device ([AgentTemplateCrud.createTemplate]).
  Future<void> seedDefaults() async {
    final seeded = <_DefaultTemplate>[];
    for (final definition in _defaults) {
      // The check and the write share one transaction: a peer's deletion
      // received in between would otherwise be written over by a row built
      // afresh, which the local write resolution takes as a re-creation.
      final created = await syncService.runInTransaction(() async {
        if (await crud.repository.getEntityIncludingDeleted(definition.id) !=
            null) {
          return false;
        }
        await crud.createTemplate(
          templateId: definition.id,
          displayName: definition.displayName,
          kind: definition.kind,
          modelId: kDefaultAgentTemplateModelId,
          directives: definition.directives,
          generalDirective: definition.generalDirective,
          reportDirective: definition.reportDirective,
          authoredBy: 'system',
          seeded: true,
        );
        return true;
      });
      if (created) seeded.add(definition);
    }

    if (seeded.isEmpty) {
      developer.log(
        'Default templates already seeded, skipping',
        name: 'AgentTemplateService',
      );
    } else {
      developer.log(
        'Seeded default templates: '
        '${seeded.map((d) => d.displayName).join(', ')}',
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
