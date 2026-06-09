part of 'soul_document_service.dart';

/// Soul-to-template assignment methods for [SoulDocumentService].
mixin _SoulTemplateOps on _SoulDocumentServiceBase {
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
    return getActiveSoulVersion(soulId);
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
}
