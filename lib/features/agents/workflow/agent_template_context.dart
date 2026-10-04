import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';

/// The resolved agent template for a wake: its definition, the pinned version
/// whose prompt and tooling will run, and the optional Soul personality
/// document version layered on top.
class AgentTemplateContext {
  const AgentTemplateContext({
    required this.template,
    required this.version,
    this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;

  /// Active soul version for this template, if a soul is assigned.
  final SoulDocumentVersionEntity? soulVersion;
}

/// Resolves the template assigned to [agentId], its active version and the
/// template's active soul.
///
/// Returns null when no template is assigned or it has no active version —
/// each workflow decides what that means for its wake. A missing soul is the
/// legitimate fallback and yields a null [AgentTemplateContext.soulVersion];
/// a broken soul chain throws, because it is a real error. [onTrace] receives
/// one line per outcome for workflows that log their resolution.
Future<AgentTemplateContext?> resolveAgentTemplateContext({
  required AgentTemplateService templateService,
  required SoulDocumentService? soulDocumentService,
  required String agentId,
  void Function(String message)? onTrace,
}) async {
  final template = await templateService.getTemplateForAgent(agentId);
  if (template == null) {
    onTrace?.call('no template assigned');
    return null;
  }

  final version = await templateService.getActiveVersion(template.id);
  if (version == null) {
    onTrace?.call('no active version for template');
    return null;
  }

  final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
    template.id,
  );
  if (soulVersion != null) {
    onTrace?.call('resolved soul v${soulVersion.version} for template');
  }

  return AgentTemplateContext(
    template: template,
    version: version,
    soulVersion: soulVersion,
  );
}
