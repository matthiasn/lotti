part of 'agent_template_crud_test.dart';

// Model conformance: agent templates are `Kind = "soul"` in
// `specs/tla/VersionHeads.tla`, like soul documents — a new version archives
// every version that is not archived, a rollback reactivates its target, and
// the head is last-writer-wins. The trace itself is
// `version_heads_conformance.dart`.

class _TemplateDocument implements VersionedDocument {
  static const _templateId = 'template-conformance';

  AgentTemplateCrud _crud(AgentReplica device) => AgentTemplateCrud(
    repository: device.repository,
    syncService: device.syncService,
  );

  @override
  String get documentId => _templateId;

  @override
  bool get rollsBack => true;

  @override
  Future<void> create(AgentReplica author) => _crud(author).createTemplate(
    templateId: _templateId,
    displayName: 'Planner',
    kind: AgentTemplateKind.taskAgent,
    modelId: 'model-1',
    directives: 'v0',
    authoredBy: 'user',
  );

  @override
  Future<void> edit(AgentReplica device, int serial) =>
      _crud(device).createVersion(
        templateId: _templateId,
        directives: 'v$serial',
        authoredBy: 'user',
      );

  @override
  Future<void> rollback(AgentReplica device, String versionId) => _crud(
    device,
  ).rollbackToVersion(templateId: _templateId, versionId: versionId);

  @override
  Future<String?> headVersionId(AgentReplica device) async =>
      (await device.repository.getTemplateHead(_templateId))?.versionId;

  @override
  Future<Map<String, String>> versionStatuses(AgentReplica device) async {
    final versions = await _crud(device).getVersionHistory(_templateId)
      ..sort(
        (a, b) => a.version != b.version
            ? a.version.compareTo(b.version)
            : a.createdAt.compareTo(b.createdAt),
      );
    return {for (final version in versions) version.id: version.status.name};
  }

  @override
  Future<String?> activeVersionId(AgentReplica device) async =>
      (await _crud(device).getActiveVersion(_templateId))?.id;

  @override
  bool isActive(String status) =>
      status == AgentTemplateVersionStatus.active.name;
}

void _registerTemplateVersionHeadsConformance() {
  group('model conformance with specs/tla/VersionHeads.tla', () {
    registerVersionHeadsConformance('agent templates', _TemplateDocument.new);
  });
}
