part of 'soul_version_ops_test.dart';

// Model conformance: soul documents are `Kind = "soul"` in
// `specs/tla/VersionHeads.tla` — a new version archives every version that is
// not archived, a rollback reactivates its target, and the head is
// last-writer-wins. The trace itself is `version_heads_conformance.dart`.

class _SoulDocument implements VersionedDocument {
  static const _soulId = 'soul-conformance';

  SoulVersionOps _ops(AgentReplica device) => SoulVersionOps(
    repository: device.repository,
    syncService: device.syncService,
  );

  @override
  String get documentId => _soulId;

  @override
  bool get rollsBack => true;

  @override
  Future<void> create(AgentReplica author) => _ops(author).createSoul(
    soulId: _soulId,
    displayName: 'Aria',
    voiceDirective: 'v0',
    authoredBy: 'user',
  );

  @override
  Future<void> edit(AgentReplica device, int serial) =>
      _ops(
        device,
      ).createVersion(
        soulId: _soulId,
        voiceDirective: 'v$serial',
        authoredBy: 'user',
      );

  @override
  Future<void> rollback(AgentReplica device, String versionId) =>
      _ops(device).rollbackToVersion(soulId: _soulId, versionId: versionId);

  @override
  Future<String?> headVersionId(AgentReplica device) async =>
      (await device.repository.getSoulDocumentHead(_soulId))?.versionId;

  @override
  Future<Map<String, String>> versionStatuses(AgentReplica device) async {
    final versions = await _ops(device).getVersionHistory(_soulId, limit: -1)
      ..sort(
        (a, b) => a.version != b.version
            ? a.version.compareTo(b.version)
            : a.createdAt.compareTo(b.createdAt),
      );
    return {for (final version in versions) version.id: version.status.name};
  }

  @override
  Future<String?> activeVersionId(AgentReplica device) async =>
      (await _ops(device).getActiveSoulVersion(_soulId))?.id;

  @override
  bool isActive(String status) =>
      status == SoulDocumentVersionStatus.active.name;
}

void _registerSoulVersionHeadsConformance() {
  group('model conformance with specs/tla/VersionHeads.tla', () {
    registerVersionHeadsConformance('soul documents', _SoulDocument.new);
  });
}
