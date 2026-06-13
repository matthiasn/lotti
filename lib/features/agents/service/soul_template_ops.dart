import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_version_ops.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _logTag = 'SoulDocumentService';

/// Soul-to-template assignment links, soul deletion, and default seeding.
///
/// Manages the soul ↔ template relationship (assign/unassign, forward and
/// reverse resolution) and the lifecycle that spans both relationships and the
/// soul-document head — soft-deleting a soul and seeding the default souls plus
/// their template assignments. Soul-document and version reads/writes are
/// delegated to [SoulVersionOps].
class SoulTemplateOps {
  SoulTemplateOps({
    required this.repository,
    required this.syncService,
    required this.versionOps,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;
  final SoulVersionOps versionOps;

  /// Assign a soul document to a template.
  ///
  /// Soft-deletes **all** existing soul assignment links for this template,
  /// then creates a fresh link to [soulId]. This ensures exactly one active
  /// assignment regardless of sync races or prior corruption.
  ///
  /// If the only existing link already points at [soulId] and no stale
  /// parallel links exist, the method is a no-op.
  Future<void> assignSoulToTemplate(
    String templateId,
    String soulId,
  ) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final existingLinks = await repository.getLinksFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      );

      // Only skip if the sole link already points at the requested soul.
      // If there are multiple links (sync race residue), fall through to
      // clean them all up.
      if (existingLinks.length == 1 && existingLinks.first.toId == soulId) {
        return;
      }

      for (final link in existingLinks) {
        await syncService.upsertLink(link.softDeleted(now));
      }

      final link = AgentLink.soulAssignment(
        id: _uuid.v4(),
        fromId: templateId,
        toId: soulId,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      );
      await syncService.upsertLink(link);
    });

    developer.log(
      'Assigned soul ${DomainLogger.sanitizeId(soulId)} to template '
      '${DomainLogger.sanitizeId(templateId)}',
      name: _logTag,
    );
  }

  /// Remove the soul assignment from a template.
  Future<void> unassignSoul(String templateId) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final links = await repository.getLinksFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      );
      for (final link in links) {
        await syncService.upsertLink(link.softDeleted(now));
      }
    });

    developer.log(
      'Unassigned soul from template ${DomainLogger.sanitizeId(templateId)}',
      name: _logTag,
    );
  }

  /// Resolve the active soul version for a template by following the
  /// assignment link → soul → head → version chain.
  ///
  /// When multiple assignment links exist (sync race residue), the most
  /// recently created link is selected using the canonical
  /// [AgentLinkSelection.orderedPrimaryFirst] tie-breaking strategy.
  ///
  /// Returns `null` if no soul is assigned or the chain is broken.
  Future<SoulDocumentVersionEntity?> resolveActiveSoulForTemplate(
    String templateId,
  ) async {
    final links = await repository.getLinksFrom(
      templateId,
      type: AgentLinkTypes.soulAssignment,
    );
    if (links.isEmpty) return null;

    final soulId = links.orderedPrimaryFirst().first.toId;
    return versionOps.getActiveSoulVersion(soulId);
  }

  /// Resolve active soul versions for multiple templates in bulk.
  ///
  /// The result is keyed by template id. Templates with no active assignment or
  /// a broken head/version chain are omitted.
  Future<Map<String, SoulDocumentVersionEntity>> resolveActiveSoulsForTemplates(
    Iterable<String> templateIds,
  ) async {
    final idList = templateIds.toSet().toList(growable: false);
    if (idList.isEmpty) return {};

    final linksByTemplateId = await repository.getLinksFromMultiple(
      idList,
      type: AgentLinkTypes.soulAssignment,
    );

    final soulIdByTemplateId = <String, String>{};
    for (final entry in linksByTemplateId.entries) {
      final links = entry.value;
      if (links.isEmpty) continue;
      soulIdByTemplateId[entry.key] = links.selectPrimary().toId;
    }
    if (soulIdByTemplateId.isEmpty) return {};

    final versionsBySoulId = await repository
        .getActiveSoulDocumentVersionsBySoulIds(
          soulIdByTemplateId.values.toSet().toList(growable: false),
        );
    return {
      for (final entry in soulIdByTemplateId.entries)
        if (versionsBySoulId[entry.value]
            case final SoulDocumentVersionEntity version)
          entry.key: version,
    };
  }

  /// Reverse lookup: find all templates that use a given soul document.
  ///
  /// Returns the template IDs (not full entities) for efficiency.
  Future<List<String>> getTemplatesUsingSoul(String soulId) async {
    final links = await repository.getLinksTo(
      soulId,
      type: AgentLinkTypes.soulAssignment,
    );
    return links.map((l) => l.fromId).toList();
  }

  /// Soft-delete a soul document and all its versions, head, and links.
  ///
  /// Checks that no templates are currently using this soul. If any template
  /// still has an active assignment, throws [StateError].
  Future<void> deleteSoul(String soulId) async {
    final templateIds = await getTemplatesUsingSoul(soulId);
    if (templateIds.isNotEmpty) {
      throw StateError(
        'Cannot delete soul $soulId: '
        '${templateIds.length} template(s) still assigned',
      );
    }

    final now = clock.now();

    final deleted = await syncService.runInTransaction(() async {
      final soul = await versionOps.getSoul(soulId);
      if (soul == null) return false;

      final versions = await versionOps.getVersionHistory(soulId, limit: -1);
      for (final version in versions) {
        await syncService.upsertEntity(
          version.copyWith(deletedAt: now),
        );
      }

      final head = await repository.getSoulDocumentHead(soulId);
      if (head != null) {
        await syncService.upsertEntity(head.copyWith(deletedAt: now));
      }

      await syncService.upsertEntity(soul.copyWith(deletedAt: now));
      return true;
    });

    if (deleted) {
      developer.log(
        'Deleted soul ${DomainLogger.sanitizeId(soulId)}',
        name: _logTag,
      );
    }
  }

  // ── seeding ───────────────────────────────────────────────────────────────

  /// Seeded soul configurations, keyed by ID.
  static const List<
    ({
      String antiSycophancy,
      String coaching,
      String id,
      String name,
      String tone,
      String voice,
    })
  >
  _seedConfigs = [
    (
      id: lauraSoulId,
      name: 'Laura',
      voice: lauraSoulVoiceDirective,
      tone: lauraSoulToneBounds,
      coaching: lauraSoulCoachingStyle,
      antiSycophancy: lauraSoulAntiSycophancyPolicy,
    ),
    (
      id: tomSoulId,
      name: 'Tom',
      voice: tomSoulVoiceDirective,
      tone: tomSoulToneBounds,
      coaching: tomSoulCoachingStyle,
      antiSycophancy: tomSoulAntiSycophancyPolicy,
    ),
    (
      id: maxSoulId,
      name: 'Max',
      voice: maxSoulVoiceDirective,
      tone: maxSoulToneBounds,
      coaching: maxSoulCoachingStyle,
      antiSycophancy: maxSoulAntiSycophancyPolicy,
    ),
    (
      id: irisSoulId,
      name: 'Iris',
      voice: irisSoulVoiceDirective,
      tone: irisSoulToneBounds,
      coaching: irisSoulCoachingStyle,
      antiSycophancy: irisSoulAntiSycophancyPolicy,
    ),
    (
      id: sageSoulId,
      name: 'Sage',
      voice: sageSoulVoiceDirective,
      tone: sageSoulToneBounds,
      coaching: sageSoulCoachingStyle,
      antiSycophancy: sageSoulAntiSycophancyPolicy,
    ),
    (
      id: kitSoulId,
      name: 'Kit',
      voice: kitSoulVoiceDirective,
      tone: kitSoulToneBounds,
      coaching: kitSoulCoachingStyle,
      antiSycophancy: kitSoulAntiSycophancyPolicy,
    ),
  ];

  /// Default soul-to-template assignments.
  static const List<({String soulId, String templateId})> _seedAssignments = [
    (templateId: lauraTemplateId, soulId: lauraSoulId),
    (templateId: tomTemplateId, soulId: tomSoulId),
    (templateId: projectTemplateId, soulId: lauraSoulId),
  ];

  /// Seed the default soul documents and assign them to seeded templates.
  ///
  /// Idempotent — checks existence before creating. Safe to call on every
  /// app startup.
  Future<void> seedDefaults() async {
    final existing = await Future.wait(
      _seedConfigs.map((c) => versionOps.getSoul(c.id)),
    );

    // Seed missing soul documents.
    for (var i = 0; i < _seedConfigs.length; i++) {
      if (existing[i] == null) {
        final c = _seedConfigs[i];
        await versionOps.createSoul(
          soulId: c.id,
          displayName: c.name,
          voiceDirective: c.voice,
          toneBounds: c.tone,
          coachingStyle: c.coaching,
          antiSycophancyPolicy: c.antiSycophancy,
          authoredBy: AgentAuthors.system,
        );
      }
    }

    // Always run assignments — assignSoulToTemplate is idempotent (no-op when
    // already assigned), so this repairs stale or missing links on existing
    // installs without creating churn.
    for (final a in _seedAssignments) {
      await assignSoulToTemplate(a.templateId, a.soulId);
    }

    developer.log('Seeded default souls and assignments', name: _logTag);
  }
}
