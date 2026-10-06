import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/agents/agent_link_slot.dart';
import 'package:lotti/database/agents/agent_repository.dart';
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
    required this._domainLogger,
  });

  /// Receives this class's log lines and caught failures.
  final DomainLogger _domainLogger;

  final AgentRepository repository;
  final AgentSyncService syncService;
  final SoulVersionOps versionOps;

  /// Assign a soul document to a template.
  ///
  /// Soft-deletes **all** live soul assignment links of this template — the
  /// one the slot shows and any concurrent assignment ranked below it
  /// ([AgentLinkSlot]) — then creates a fresh link to [soulId], which
  /// `AgentSyncService.upsertLink` stamps to outrank them.
  ///
  /// If the only live link already points at [soulId], the method is a
  /// no-op.
  Future<void> assignSoulToTemplate(
    String templateId,
    String soulId,
  ) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final existingLinks = await _liveAssignments(templateId);

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

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Assigned soul ${DomainLogger.sanitizeId(soulId)} to template '
      '${DomainLogger.sanitizeId(templateId)}',
      subDomain: _logTag,
    );
  }

  /// Remove the soul assignment from a template.
  ///
  /// Removes every live assignment of the slot, so a concurrent assignment
  /// ranked below the visible one does not take its place.
  Future<void> unassignSoul(String templateId) async {
    final now = clock.now();

    await syncService.runInTransaction(() async {
      final links = await _liveAssignments(templateId);
      for (final link in links) {
        await syncService.upsertLink(link.softDeleted(now));
      }
    });

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Unassigned soul from template ${DomainLogger.sanitizeId(templateId)}',
      subDomain: _logTag,
    );
  }

  /// Every live soul assignment of [templateId], the hidden ones included.
  Future<List<AgentLink>> _liveAssignments(String templateId) async => [
    for (final link in await repository.getSlotLinks(
      AgentLinkSlot.soul(templateId),
    ))
      if (link.deletedAt == null) link,
  ];

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
  /// still has an active assignment, throws [StateError]. Assignments of this
  /// soul that a template's slot ranks below its visible one ([AgentLinkSlot])
  /// are removed with it, so none can surface later pointing at a deleted
  /// soul.
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

      for (final hidden in await repository.getLinksToIncludingHidden(
        soulId,
        type: AgentLinkTypes.soulAssignment,
      )) {
        if (hidden.deletedAt == null) {
          await syncService.upsertLink(hidden.softDeleted(now));
        }
      }

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
      _domainLogger.log(
        LogDomain.agentWorkflow,
        'Deleted soul ${DomainLogger.sanitizeId(soulId)}',
        subDomain: _logTag,
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
  /// Idempotent and safe to call on every app startup. A user's choice about
  /// a default is never undone (ADR 0100):
  ///
  /// - A soul is created only when no row is stored under its id, **a
  ///   removed one included**, so a default soul the user deleted stays
  ///   deleted and a default that ships in a later release is still seeded.
  /// - A default assignment is made only for a template that has never had
  ///   a soul assignment — a removed one counts — and only while the
  ///   template and the soul both exist. A soul the user unassigned or
  ///   replaced stays that way.
  ///
  /// Both are stamped at `agentSeedInstant`, so a deletion, an unassignment
  /// or a reassignment made concurrently on a device this one has not heard
  /// from yet wins over the seed on every device. The assignment has a
  /// deterministic id ([seededSoulAssignmentLinkId]), so every device seeds
  /// the same link and removing it removes all of their seeds.
  Future<void> seedDefaults() async {
    for (final c in _seedConfigs) {
      // The check and the write share one transaction, so a peer's deletion
      // received in between cannot be overwritten by a re-creation.
      await syncService.runInTransaction(() async {
        if (await repository.getEntityIncludingDeleted(c.id) != null) return;
        await versionOps.createSoul(
          soulId: c.id,
          displayName: c.name,
          voiceDirective: c.voice,
          toneBounds: c.tone,
          coachingStyle: c.coaching,
          antiSycophancyPolicy: c.antiSycophancy,
          authoredBy: AgentAuthors.system,
          seeded: true,
        );
      });
    }

    for (final a in _seedAssignments) {
      await _seedAssignment(templateId: a.templateId, soulId: a.soulId);
    }

    _domainLogger.log(
      LogDomain.agentWorkflow,
      'Seeded default souls and assignments',
      subDomain: _logTag,
    );
  }

  /// Links [soulId] to [templateId] as a seeded default, unless the
  /// template has ever had a soul assignment or either side is gone.
  Future<void> _seedAssignment({
    required String templateId,
    required String soulId,
  }) async {
    await syncService.runInTransaction(() async {
      if (await repository.hasAnyLinkFrom(
        templateId,
        type: AgentLinkTypes.soulAssignment,
      )) {
        return;
      }
      final template = (await repository.getEntity(
        templateId,
      ))?.mapOrNull(agentTemplate: (t) => t);
      if (template == null || await versionOps.getSoul(soulId) == null) {
        return;
      }
      await syncService.upsertLink(
        AgentLink.soulAssignment(
          id: seededSoulAssignmentLinkId(templateId),
          fromId: templateId,
          toId: soulId,
          createdAt: agentSeedInstant,
          updatedAt: agentSeedInstant,
          vectorClock: null,
        ),
      );
    });
  }
}
