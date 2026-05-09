import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/seeded_directives.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

const _generatedTemplateId = 'generated-template';
const _generatedDisplayName = 'Generated Template';
const _generatedChangedDisplayName = 'Generated Template Updated';
const _generatedModelId = 'models/generated-original';
const _generatedChangedModelId = 'models/generated-updated';
const _generatedProfileId = 'generated-profile';
const _generatedChangedProfileId = 'generated-profile-updated';
const _generatedTargetProfileId = 'generated-target-profile';
const _generatedHeadId = 'generated-template-head';

enum _GeneratedTemplateEntitySlot { present, missing, wrongType }

enum _GeneratedTemplateDisplayNameSlot { omitted, same, changed }

enum _GeneratedTemplateModelSlot { omitted, same, changed }

enum _GeneratedTemplateExistingProfileSlot { none, profile }

enum _GeneratedTemplateProfileSlot {
  omitted,
  same,
  changed,
  cleared,
  changedAndCleared,
}

enum _GeneratedTemplateActiveVersionSlot { present, missing }

enum _GeneratedTemplateHistorySlot { empty, allArchived, headActive, mixed }

enum _GeneratedTemplateHeadSlot { present, missing }

enum _GeneratedTemplateDeleteAssignmentSlot {
  active,
  created,
  dormant,
  destroyed,
  missing,
  wrongType,
}

enum _GeneratedTemplateDeleteVersionSlot {
  version,
  archivedVersion,
  nonVersion,
}

enum _GeneratedTemplateRollbackTargetSlot {
  active,
  archived,
  missing,
  wrongType,
  wrongTemplate,
}

enum _GeneratedTemplateRollbackHistorySlot {
  empty,
  allArchived,
  activeOnly,
  targetActive,
  targetArchived,
  mixedWithoutTarget,
  mixedWithTarget,
}

enum _GeneratedProfileReferenceSlot { none, target, other }

enum _GeneratedProfileVersionSlot { none, target, other, nonVersion }

enum _GeneratedGatherVersionSlot { active, archived, nonVersion }

enum _GeneratedGatherPayloadSlot {
  none,
  payloadA,
  payloadB,
  missing,
  wrongType,
}

enum _GeneratedGatherAgentSlot {
  active,
  dormant,
  destroyed,
  missing,
  wrongType,
}

enum _GeneratedDefaultTemplateSlot { present, missing, wrongType }

enum _GeneratedDirectiveVersionSlot {
  missing,
  empty,
  generalOnly,
  reportOnly,
  bothPopulated,
}

class _GeneratedTemplateUpdateDelta {
  const _GeneratedTemplateUpdateDelta({
    required this.existingProfileSlot,
    required this.displayNameSlot,
    required this.modelSlot,
    required this.profileSlot,
  });

  final _GeneratedTemplateExistingProfileSlot existingProfileSlot;
  final _GeneratedTemplateDisplayNameSlot displayNameSlot;
  final _GeneratedTemplateModelSlot modelSlot;
  final _GeneratedTemplateProfileSlot profileSlot;

  String? get existingProfileId {
    return switch (existingProfileSlot) {
      _GeneratedTemplateExistingProfileSlot.none => null,
      _GeneratedTemplateExistingProfileSlot.profile => _generatedProfileId,
    };
  }

  String? get requestedDisplayName {
    return switch (displayNameSlot) {
      _GeneratedTemplateDisplayNameSlot.omitted => null,
      _GeneratedTemplateDisplayNameSlot.same => _generatedDisplayName,
      _GeneratedTemplateDisplayNameSlot.changed => _generatedChangedDisplayName,
    };
  }

  String get expectedDisplayName =>
      requestedDisplayName ?? _generatedDisplayName;

  String? get requestedModelId {
    return switch (modelSlot) {
      _GeneratedTemplateModelSlot.omitted => null,
      _GeneratedTemplateModelSlot.same => _generatedModelId,
      _GeneratedTemplateModelSlot.changed => _generatedChangedModelId,
    };
  }

  String get expectedModelId => requestedModelId ?? _generatedModelId;

  bool get modelChanged =>
      requestedModelId != null && requestedModelId != _generatedModelId;

  String? get requestedProfileId {
    return switch (profileSlot) {
      _GeneratedTemplateProfileSlot.omitted => null,
      _GeneratedTemplateProfileSlot.same => existingProfileId,
      _GeneratedTemplateProfileSlot.changed => _generatedChangedProfileId,
      _GeneratedTemplateProfileSlot.cleared => null,
      _GeneratedTemplateProfileSlot.changedAndCleared =>
        _generatedChangedProfileId,
    };
  }

  bool get clearProfileId =>
      profileSlot == _GeneratedTemplateProfileSlot.cleared ||
      profileSlot == _GeneratedTemplateProfileSlot.changedAndCleared;

  String? get expectedProfileId {
    if (clearProfileId) {
      return null;
    }
    return requestedProfileId ?? existingProfileId;
  }

  bool get profileChanged => expectedProfileId != existingProfileId;

  @override
  String toString() {
    return '_GeneratedTemplateUpdateDelta('
        'existingProfileSlot: $existingProfileSlot, '
        'displayNameSlot: $displayNameSlot, modelSlot: $modelSlot, '
        'profileSlot: $profileSlot)';
  }
}

class _GeneratedTemplateUpdateScenario {
  const _GeneratedTemplateUpdateScenario({
    required this.templateSlot,
    required this.delta,
    required this.activeVersionSlot,
    required this.historySlot,
    required this.headSlot,
    required this.nextVersionNumber,
  });

  final _GeneratedTemplateEntitySlot templateSlot;
  final _GeneratedTemplateUpdateDelta delta;
  final _GeneratedTemplateActiveVersionSlot activeVersionSlot;
  final _GeneratedTemplateHistorySlot historySlot;
  final _GeneratedTemplateHeadSlot headSlot;
  final int nextVersionNumber;

  bool get templateExists =>
      templateSlot == _GeneratedTemplateEntitySlot.present;

  bool get shouldReadActiveVersion =>
      templateExists && (delta.modelChanged || delta.profileChanged);

  bool get shouldCreateVersion =>
      shouldReadActiveVersion &&
      activeVersionSlot == _GeneratedTemplateActiveVersionSlot.present;

  AgentDomainEntity? get initialTemplateEntity {
    return switch (templateSlot) {
      _GeneratedTemplateEntitySlot.present => makeTestTemplate(
        id: _generatedTemplateId,
        agentId: _generatedTemplateId,
        displayName: _generatedDisplayName,
        modelId: _generatedModelId,
        profileId: delta.existingProfileId,
      ),
      _GeneratedTemplateEntitySlot.missing => null,
      _GeneratedTemplateEntitySlot.wrongType => makeTestTemplateVersion(
        id: _generatedTemplateId,
        agentId: _generatedTemplateId,
      ),
    };
  }

  AgentTemplateVersionEntity? get activeVersion {
    if (activeVersionSlot == _GeneratedTemplateActiveVersionSlot.missing) {
      return null;
    }
    return makeTestTemplateVersion(
      id: 'generated-active-version',
      agentId: _generatedTemplateId,
      version: 3,
      directives: 'Generated active directives.',
      generalDirective: 'Generated general directive.',
      reportDirective: 'Generated report directive.',
      authoredBy: 'generated-user',
      modelId: _generatedModelId,
      profileId: delta.existingProfileId,
    );
  }

  AgentTemplateHeadEntity? get currentHead {
    return switch (headSlot) {
      _GeneratedTemplateHeadSlot.present => makeTestTemplateHead(
        id: _generatedHeadId,
        agentId: _generatedTemplateId,
        versionId: 'generated-active-version',
      ),
      _GeneratedTemplateHeadSlot.missing => null,
    };
  }

  List<AgentTemplateVersionEntity> get versionHistory {
    return switch (historySlot) {
      _GeneratedTemplateHistorySlot.empty => const [],
      _GeneratedTemplateHistorySlot.allArchived => [
        makeTestTemplateVersion(
          id: 'generated-archived-version-1',
          agentId: _generatedTemplateId,
          status: AgentTemplateVersionStatus.archived,
        ),
        makeTestTemplateVersion(
          id: 'generated-archived-version-2',
          agentId: _generatedTemplateId,
          version: 2,
          status: AgentTemplateVersionStatus.archived,
        ),
      ],
      _GeneratedTemplateHistorySlot.headActive => [
        makeTestTemplateVersion(
          id: 'generated-active-version',
          agentId: _generatedTemplateId,
          version: 3,
        ),
      ],
      _GeneratedTemplateHistorySlot.mixed => [
        makeTestTemplateVersion(
          id: 'generated-archived-version',
          agentId: _generatedTemplateId,
          status: AgentTemplateVersionStatus.archived,
        ),
        makeTestTemplateVersion(
          id: 'generated-stale-active-version',
          agentId: _generatedTemplateId,
          version: 2,
        ),
        makeTestTemplateVersion(
          id: 'generated-active-version',
          agentId: _generatedTemplateId,
          version: 3,
        ),
      ],
    };
  }

  Set<String> get archivedVersionIds {
    return versionHistory
        .where(
          (version) => version.status != AgentTemplateVersionStatus.archived,
        )
        .map((version) => version.id)
        .toSet();
  }

  @override
  String toString() {
    return '_GeneratedTemplateUpdateScenario('
        'templateSlot: $templateSlot, delta: $delta, '
        'activeVersionSlot: $activeVersionSlot, historySlot: $historySlot, '
        'headSlot: $headSlot, nextVersionNumber: $nextVersionNumber)';
  }
}

class _GeneratedTemplateDeleteScenario {
  const _GeneratedTemplateDeleteScenario({
    required this.templateSlot,
    required this.headSlot,
    required this.assignmentSlots,
    required this.versionSlots,
  });

  final _GeneratedTemplateEntitySlot templateSlot;
  final _GeneratedTemplateHeadSlot headSlot;
  final List<_GeneratedTemplateDeleteAssignmentSlot> assignmentSlots;
  final List<_GeneratedTemplateDeleteVersionSlot> versionSlots;

  bool get templateExists =>
      templateSlot == _GeneratedTemplateEntitySlot.present;

  AgentDomainEntity? get initialTemplateEntity {
    return switch (templateSlot) {
      _GeneratedTemplateEntitySlot.present => makeTestTemplate(
        id: _generatedTemplateId,
        agentId: _generatedTemplateId,
        displayName: _generatedDisplayName,
        modelId: _generatedModelId,
      ),
      _GeneratedTemplateEntitySlot.missing => null,
      _GeneratedTemplateEntitySlot.wrongType => makeTestTemplateVersion(
        id: _generatedTemplateId,
        agentId: _generatedTemplateId,
      ),
    };
  }

  AgentTemplateHeadEntity? get currentHead {
    return switch (headSlot) {
      _GeneratedTemplateHeadSlot.present => makeTestTemplateHead(
        id: _generatedHeadId,
        agentId: _generatedTemplateId,
        versionId: 'generated-delete-version-0',
      ),
      _GeneratedTemplateHeadSlot.missing => null,
    };
  }

  int get blockingAgentCount {
    return assignmentSlots.where((slot) {
      return switch (slot) {
        _GeneratedTemplateDeleteAssignmentSlot.active ||
        _GeneratedTemplateDeleteAssignmentSlot.created ||
        _GeneratedTemplateDeleteAssignmentSlot.dormant => true,
        _GeneratedTemplateDeleteAssignmentSlot.destroyed ||
        _GeneratedTemplateDeleteAssignmentSlot.missing ||
        _GeneratedTemplateDeleteAssignmentSlot.wrongType => false,
      };
    }).length;
  }

  List<AgentDomainEntity> get versionEntities {
    return [
      for (final (index, slot) in versionSlots.indexed)
        switch (slot) {
          _GeneratedTemplateDeleteVersionSlot.version =>
            makeTestTemplateVersion(
              id: 'generated-delete-version-$index',
              agentId: _generatedTemplateId,
              version: index + 1,
            ),
          _GeneratedTemplateDeleteVersionSlot.archivedVersion =>
            makeTestTemplateVersion(
              id: 'generated-delete-version-$index',
              agentId: _generatedTemplateId,
              version: index + 1,
              status: AgentTemplateVersionStatus.archived,
            ),
          _GeneratedTemplateDeleteVersionSlot.nonVersion => makeTestTemplate(
            id: 'generated-delete-non-version-$index',
            agentId: _generatedTemplateId,
          ),
        },
    ];
  }

  Set<String> get deletedVersionIds {
    return versionEntities
        .whereType<AgentTemplateVersionEntity>()
        .map((version) => version.id)
        .toSet();
  }

  AgentDomainEntity? assignmentEntity(
    _GeneratedTemplateDeleteAssignmentSlot slot,
    int index,
  ) {
    final agentId = 'generated-delete-agent-$index';
    return switch (slot) {
      _GeneratedTemplateDeleteAssignmentSlot.active => makeTestIdentity(
        id: agentId,
        agentId: agentId,
      ),
      _GeneratedTemplateDeleteAssignmentSlot.created => makeTestIdentity(
        id: agentId,
        agentId: agentId,
        lifecycle: AgentLifecycle.created,
      ),
      _GeneratedTemplateDeleteAssignmentSlot.dormant => makeTestIdentity(
        id: agentId,
        agentId: agentId,
        lifecycle: AgentLifecycle.dormant,
      ),
      _GeneratedTemplateDeleteAssignmentSlot.destroyed => makeTestIdentity(
        id: agentId,
        agentId: agentId,
        lifecycle: AgentLifecycle.destroyed,
      ),
      _GeneratedTemplateDeleteAssignmentSlot.missing => null,
      _GeneratedTemplateDeleteAssignmentSlot.wrongType => makeTestTemplate(
        id: agentId,
        agentId: agentId,
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedTemplateDeleteScenario('
        'templateSlot: $templateSlot, headSlot: $headSlot, '
        'assignmentSlots: $assignmentSlots, versionSlots: $versionSlots)';
  }
}

class _GeneratedTemplateRollbackScenario {
  const _GeneratedTemplateRollbackScenario({
    required this.headSlot,
    required this.targetSlot,
    required this.historySlot,
  });

  final _GeneratedTemplateHeadSlot headSlot;
  final _GeneratedTemplateRollbackTargetSlot targetSlot;
  final _GeneratedTemplateRollbackHistorySlot historySlot;

  String get requestedVersionId {
    return switch (targetSlot) {
      _GeneratedTemplateRollbackTargetSlot.active ||
      _GeneratedTemplateRollbackTargetSlot.archived =>
        'generated-rollback-target',
      _GeneratedTemplateRollbackTargetSlot.missing =>
        'generated-rollback-missing',
      _GeneratedTemplateRollbackTargetSlot.wrongType =>
        'generated-rollback-non-version',
      _GeneratedTemplateRollbackTargetSlot.wrongTemplate =>
        'generated-rollback-wrong-template',
    };
  }

  AgentTemplateHeadEntity? get currentHead {
    return switch (headSlot) {
      _GeneratedTemplateHeadSlot.present => makeTestTemplateHead(
        id: _generatedHeadId,
        agentId: _generatedTemplateId,
        versionId: 'generated-rollback-current',
      ),
      _GeneratedTemplateHeadSlot.missing => null,
    };
  }

  bool get targetIsValid =>
      targetSlot == _GeneratedTemplateRollbackTargetSlot.active ||
      targetSlot == _GeneratedTemplateRollbackTargetSlot.archived;

  AgentDomainEntity? get targetEntity {
    return switch (targetSlot) {
      _GeneratedTemplateRollbackTargetSlot.active => _targetVersion(),
      _GeneratedTemplateRollbackTargetSlot.archived => _targetVersion(
        status: AgentTemplateVersionStatus.archived,
      ),
      _GeneratedTemplateRollbackTargetSlot.missing => null,
      _GeneratedTemplateRollbackTargetSlot.wrongType => makeTestTemplate(
        id: requestedVersionId,
        agentId: _generatedTemplateId,
      ),
      _GeneratedTemplateRollbackTargetSlot.wrongTemplate =>
        makeTestTemplateVersion(
          id: requestedVersionId,
          agentId: 'generated-other-template',
        ),
    };
  }

  AgentTemplateVersionEntity get validTargetVersion =>
      targetEntity! as AgentTemplateVersionEntity;

  List<AgentDomainEntity> get historyEntities {
    return switch (historySlot) {
      _GeneratedTemplateRollbackHistorySlot.empty => const [],
      _GeneratedTemplateRollbackHistorySlot.allArchived => [
        _historyVersion(
          id: 'generated-rollback-archived-1',
          status: AgentTemplateVersionStatus.archived,
        ),
        _historyVersion(
          id: 'generated-rollback-archived-2',
          version: 2,
          status: AgentTemplateVersionStatus.archived,
        ),
      ],
      _GeneratedTemplateRollbackHistorySlot.activeOnly => [
        _historyVersion(id: 'generated-rollback-active'),
      ],
      _GeneratedTemplateRollbackHistorySlot.targetActive => [
        _targetVersion(version: 5),
      ],
      _GeneratedTemplateRollbackHistorySlot.targetArchived => [
        _targetVersion(
          version: 5,
          status: AgentTemplateVersionStatus.archived,
        ),
      ],
      _GeneratedTemplateRollbackHistorySlot.mixedWithoutTarget => [
        _historyVersion(
          id: 'generated-rollback-archived',
          status: AgentTemplateVersionStatus.archived,
        ),
        _historyVersion(id: 'generated-rollback-stale-active', version: 2),
        makeTestTemplate(
          id: 'generated-rollback-non-version-history',
          agentId: _generatedTemplateId,
        ),
        _historyVersion(id: 'generated-rollback-current', version: 4),
      ],
      _GeneratedTemplateRollbackHistorySlot.mixedWithTarget => [
        _targetVersion(version: 5),
        _historyVersion(
          id: 'generated-rollback-archived',
          version: 3,
          status: AgentTemplateVersionStatus.archived,
        ),
        _historyVersion(id: 'generated-rollback-stale-active', version: 2),
        makeTestTemplate(
          id: 'generated-rollback-non-version-history',
          agentId: _generatedTemplateId,
        ),
      ],
    };
  }

  List<AgentTemplateVersionEntity> get sortedHistoryVersions {
    return historyEntities.whereType<AgentTemplateVersionEntity>().toList()
      ..sort((a, b) => b.version.compareTo(a.version));
  }

  List<AgentTemplateVersionEntity> get expectedArchivedWrites {
    return sortedHistoryVersions
        .where(
          (version) => version.status != AgentTemplateVersionStatus.archived,
        )
        .toList();
  }

  @override
  String toString() {
    return '_GeneratedTemplateRollbackScenario('
        'headSlot: $headSlot, targetSlot: $targetSlot, '
        'historySlot: $historySlot)';
  }
}

class _GeneratedProfileTemplateSpec {
  const _GeneratedProfileTemplateSpec({
    required this.profileSlot,
    required this.versionSlots,
  });

  final _GeneratedProfileReferenceSlot profileSlot;
  final List<_GeneratedProfileVersionSlot> versionSlots;

  bool get templateReferencesTarget =>
      profileSlot == _GeneratedProfileReferenceSlot.target;

  bool get versionReferencesTarget =>
      versionSlots.contains(_GeneratedProfileVersionSlot.target);

  AgentTemplateEntity template(int index) {
    final id = 'generated-profile-template-$index';
    return makeTestTemplate(
      id: id,
      agentId: id,
      profileId: profileSlot.profileId,
    );
  }

  List<AgentDomainEntity> versionEntities(int templateIndex) {
    return [
      for (final (index, slot) in versionSlots.indexed)
        switch (slot) {
          _GeneratedProfileVersionSlot.none => makeTestTemplateVersion(
            id: 'generated-profile-version-$templateIndex-$index',
            agentId: 'generated-profile-template-$templateIndex',
            version: index + 1,
          ),
          _GeneratedProfileVersionSlot.target => makeTestTemplateVersion(
            id: 'generated-profile-version-$templateIndex-$index',
            agentId: 'generated-profile-template-$templateIndex',
            version: index + 1,
            profileId: _generatedTargetProfileId,
          ),
          _GeneratedProfileVersionSlot.other => makeTestTemplateVersion(
            id: 'generated-profile-version-$templateIndex-$index',
            agentId: 'generated-profile-template-$templateIndex',
            version: index + 1,
            profileId: 'generated-other-profile',
          ),
          _GeneratedProfileVersionSlot.nonVersion => makeTestTemplate(
            id: 'generated-profile-non-version-$templateIndex-$index',
            agentId: 'generated-profile-template-$templateIndex',
            profileId: _generatedTargetProfileId,
          ),
        },
    ];
  }

  @override
  String toString() {
    return '_GeneratedProfileTemplateSpec('
        'profileSlot: $profileSlot, versionSlots: $versionSlots)';
  }
}

class _GeneratedProfileInUseScenario {
  const _GeneratedProfileInUseScenario({
    required this.templates,
    required this.agentProfileSlots,
  });

  final List<_GeneratedProfileTemplateSpec> templates;
  final List<_GeneratedProfileReferenceSlot> agentProfileSlots;

  bool get templateReferencesTarget =>
      templates.any((template) => template.templateReferencesTarget);

  bool get versionReferencesTarget =>
      templates.any((template) => template.versionReferencesTarget);

  bool get agentReferencesTarget =>
      agentProfileSlots.contains(_GeneratedProfileReferenceSlot.target);

  bool get expectedResult =>
      templateReferencesTarget ||
      versionReferencesTarget ||
      agentReferencesTarget;

  List<AgentTemplateEntity> get templateEntities {
    return [
      for (final (index, template) in templates.indexed)
        template.template(index),
    ];
  }

  List<AgentIdentityEntity> get agentEntities {
    return [
      for (final (index, slot) in agentProfileSlots.indexed)
        makeTestIdentity(
          id: 'generated-profile-agent-$index',
          agentId: 'generated-profile-agent-$index',
          config: AgentConfig(profileId: slot.profileId),
        ),
    ];
  }

  @override
  String toString() {
    return '_GeneratedProfileInUseScenario('
        'templates: $templates, agentProfileSlots: $agentProfileSlots)';
  }
}

extension _GeneratedProfileReferenceSlotX on _GeneratedProfileReferenceSlot {
  String? get profileId {
    return switch (this) {
      _GeneratedProfileReferenceSlot.none => null,
      _GeneratedProfileReferenceSlot.target => _generatedTargetProfileId,
      _GeneratedProfileReferenceSlot.other => 'generated-other-profile',
    };
  }
}

class _GeneratedGatherEvolutionScenario {
  const _GeneratedGatherEvolutionScenario({
    required this.versionSlots,
    required this.reportCount,
    required this.observationPayloadSlots,
    required this.noteCount,
    required this.sessionDateOffsets,
    required this.agentSlots,
    required this.changesSinceLastSession,
  });

  final List<_GeneratedGatherVersionSlot> versionSlots;
  final int reportCount;
  final List<_GeneratedGatherPayloadSlot> observationPayloadSlots;
  final int noteCount;
  final List<int> sessionDateOffsets;
  final List<_GeneratedGatherAgentSlot> agentSlots;
  final int changesSinceLastSession;

  List<AgentDomainEntity> get versionEntities {
    return [
      for (final (index, slot) in versionSlots.indexed)
        switch (slot) {
          _GeneratedGatherVersionSlot.active => makeTestTemplateVersion(
            id: 'generated-gather-version-$index',
            agentId: _generatedTemplateId,
            version: index + 1,
          ),
          _GeneratedGatherVersionSlot.archived => makeTestTemplateVersion(
            id: 'generated-gather-version-$index',
            agentId: _generatedTemplateId,
            version: index + 1,
            status: AgentTemplateVersionStatus.archived,
          ),
          _GeneratedGatherVersionSlot.nonVersion => makeTestTemplate(
            id: 'generated-gather-non-version-$index',
            agentId: _generatedTemplateId,
          ),
        },
    ];
  }

  List<AgentTemplateVersionEntity> get expectedRecentVersions {
    return versionEntities.whereType<AgentTemplateVersionEntity>().toList()
      ..sort((a, b) => b.version.compareTo(a.version));
  }

  List<AgentReportEntity> get reports {
    return [
      for (var index = 0; index < reportCount; index++)
        makeTestReport(
          id: 'generated-gather-report-$index',
          agentId: 'generated-gather-agent-$index',
          content: 'Generated report $index',
        ),
    ];
  }

  List<AgentMessageEntity> get observations {
    return [
      for (final (index, slot) in observationPayloadSlots.indexed)
        makeTestMessage(
          id: 'generated-gather-observation-$index',
          agentId: 'generated-gather-agent-$index',
          kind: AgentMessageKind.observation,
          contentEntryId: slot.contentEntryId,
        ),
    ];
  }

  List<EvolutionNoteEntity> get notes {
    return [
      for (var index = 0; index < noteCount; index++)
        makeTestEvolutionNote(
          id: 'generated-gather-note-$index',
          agentId: _generatedTemplateId,
          content: 'Generated note $index',
        ),
    ];
  }

  List<EvolutionSessionEntity> get sessions {
    final baseDate = DateTime(2026, 4, 1, 8);
    return [
      for (final (index, offset) in sessionDateOffsets.indexed)
        makeTestEvolutionSession(
          id: 'generated-gather-session-$index',
          agentId: _generatedTemplateId,
          templateId: _generatedTemplateId,
          sessionNumber: index + 1,
          createdAt: baseDate.add(Duration(days: offset)),
        ),
    ];
  }

  DateTime? get expectedSince {
    final generatedSessions = sessions;
    return generatedSessions.isEmpty ? null : generatedSessions.first.createdAt;
  }

  List<AgentIdentityEntity> get expectedAgents {
    return [
      for (final (index, slot) in agentSlots.indexed)
        if (slot.identity(index) != null) slot.identity(index)!,
    ];
  }

  int get expectedActiveAgentCount {
    return expectedAgents
        .where((agent) => agent.lifecycle == AgentLifecycle.active)
        .length;
  }

  Map<String, AgentMessagePayloadEntity> get expectedPayloads {
    final payloads = <String, AgentMessagePayloadEntity>{};
    for (final slot in observationPayloadSlots) {
      final payload = slot.payloadEntity;
      if (payload != null) {
        payloads[payload.id] = payload;
      }
    }
    return payloads;
  }

  Map<String, int> get payloadLookupCounts {
    final counts = <String, int>{};
    for (final slot in observationPayloadSlots) {
      final contentEntryId = slot.contentEntryId;
      if (contentEntryId != null) {
        counts[contentEntryId] = (counts[contentEntryId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  String toString() {
    return '_GeneratedGatherEvolutionScenario('
        'versionSlots: $versionSlots, reportCount: $reportCount, '
        'observationPayloadSlots: $observationPayloadSlots, '
        'noteCount: $noteCount, sessionDateOffsets: $sessionDateOffsets, '
        'agentSlots: $agentSlots, '
        'changesSinceLastSession: $changesSinceLastSession)';
  }
}

extension _GeneratedGatherPayloadSlotX on _GeneratedGatherPayloadSlot {
  String? get contentEntryId {
    return switch (this) {
      _GeneratedGatherPayloadSlot.none => null,
      _GeneratedGatherPayloadSlot.payloadA => 'generated-gather-payload-a',
      _GeneratedGatherPayloadSlot.payloadB => 'generated-gather-payload-b',
      _GeneratedGatherPayloadSlot.missing => 'generated-gather-payload-missing',
      _GeneratedGatherPayloadSlot.wrongType => 'generated-gather-payload-wrong',
    };
  }

  AgentDomainEntity? get lookupEntity {
    return switch (this) {
      _GeneratedGatherPayloadSlot.none => null,
      _GeneratedGatherPayloadSlot.payloadA => payloadEntity,
      _GeneratedGatherPayloadSlot.payloadB => payloadEntity,
      _GeneratedGatherPayloadSlot.missing => null,
      _GeneratedGatherPayloadSlot.wrongType => makeTestTemplate(
        id: 'generated-gather-payload-wrong',
        agentId: _generatedTemplateId,
      ),
    };
  }

  AgentMessagePayloadEntity? get payloadEntity {
    return switch (this) {
      _GeneratedGatherPayloadSlot.payloadA => makeTestMessagePayload(
        id: 'generated-gather-payload-a',
        agentId: _generatedTemplateId,
        content: const {'text': 'Generated payload A'},
      ),
      _GeneratedGatherPayloadSlot.payloadB => makeTestMessagePayload(
        id: 'generated-gather-payload-b',
        agentId: _generatedTemplateId,
        content: const {'text': 'Generated payload B'},
      ),
      _GeneratedGatherPayloadSlot.none ||
      _GeneratedGatherPayloadSlot.missing ||
      _GeneratedGatherPayloadSlot.wrongType => null,
    };
  }
}

extension _GeneratedGatherAgentSlotX on _GeneratedGatherAgentSlot {
  AgentDomainEntity? entity(int index) {
    final agentId = 'generated-gather-agent-link-$index';
    return switch (this) {
      _GeneratedGatherAgentSlot.active => makeTestIdentity(
        id: agentId,
        agentId: agentId,
      ),
      _GeneratedGatherAgentSlot.dormant => makeTestIdentity(
        id: agentId,
        agentId: agentId,
        lifecycle: AgentLifecycle.dormant,
      ),
      _GeneratedGatherAgentSlot.destroyed => makeTestIdentity(
        id: agentId,
        agentId: agentId,
        lifecycle: AgentLifecycle.destroyed,
      ),
      _GeneratedGatherAgentSlot.missing => null,
      _GeneratedGatherAgentSlot.wrongType => makeTestTemplate(
        id: agentId,
        agentId: agentId,
      ),
    };
  }

  AgentIdentityEntity? identity(int index) {
    final entity = this.entity(index);
    return entity is AgentIdentityEntity ? entity : null;
  }
}

class _DefaultTemplateDefinition {
  const _DefaultTemplateDefinition({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.generalDirective,
    required this.reportDirective,
  });

  final String id;
  final String displayName;
  final AgentTemplateKind kind;
  final String generalDirective;
  final String reportDirective;

  AgentDomainEntity? existingEntity(_GeneratedDefaultTemplateSlot slot) {
    return switch (slot) {
      _GeneratedDefaultTemplateSlot.present => makeTestTemplate(
        id: id,
        agentId: id,
        displayName: displayName,
        kind: kind,
      ),
      _GeneratedDefaultTemplateSlot.missing => null,
      _GeneratedDefaultTemplateSlot.wrongType => makeTestTemplateVersion(
        id: id,
        agentId: id,
      ),
    };
  }
}

const _defaultTemplateDefinitions = [
  _DefaultTemplateDefinition(
    id: lauraTemplateId,
    displayName: 'Laura',
    kind: AgentTemplateKind.taskAgent,
    generalDirective: taskAgentGeneralDirective,
    reportDirective: taskAgentReportDirective,
  ),
  _DefaultTemplateDefinition(
    id: tomTemplateId,
    displayName: 'Tom',
    kind: AgentTemplateKind.taskAgent,
    generalDirective: taskAgentGeneralDirective,
    reportDirective: taskAgentReportDirective,
  ),
  _DefaultTemplateDefinition(
    id: projectTemplateId,
    displayName: 'Project Analyst',
    kind: AgentTemplateKind.projectAgent,
    generalDirective: projectAgentGeneralDirective,
    reportDirective: projectAgentReportDirective,
  ),
  _DefaultTemplateDefinition(
    id: improverTemplateId,
    displayName: 'Template Improver',
    kind: AgentTemplateKind.templateImprover,
    generalDirective: templateImproverGeneralDirective,
    reportDirective: '',
  ),
  _DefaultTemplateDefinition(
    id: metaImproverTemplateId,
    displayName: 'Meta Improver',
    kind: AgentTemplateKind.templateImprover,
    generalDirective: templateImproverGeneralDirective,
    reportDirective: '',
  ),
];

class _GeneratedSeedDefaultsScenario {
  const _GeneratedSeedDefaultsScenario({
    required this.lauraSlot,
    required this.tomSlot,
    required this.projectSlot,
    required this.improverSlot,
    required this.metaImproverSlot,
  });

  final _GeneratedDefaultTemplateSlot lauraSlot;
  final _GeneratedDefaultTemplateSlot tomSlot;
  final _GeneratedDefaultTemplateSlot projectSlot;
  final _GeneratedDefaultTemplateSlot improverSlot;
  final _GeneratedDefaultTemplateSlot metaImproverSlot;

  List<_GeneratedDefaultTemplateSlot> get slots => [
    lauraSlot,
    tomSlot,
    projectSlot,
    improverSlot,
    metaImproverSlot,
  ];

  bool get allPresent =>
      slots.every((slot) => slot == _GeneratedDefaultTemplateSlot.present);

  List<_DefaultTemplateDefinition> get templatesToCreate {
    return [
      for (final (index, slot) in slots.indexed)
        if (slot != _GeneratedDefaultTemplateSlot.present)
          _defaultTemplateDefinitions[index],
    ];
  }

  @override
  String toString() {
    return '_GeneratedSeedDefaultsScenario('
        'lauraSlot: $lauraSlot, tomSlot: $tomSlot, '
        'projectSlot: $projectSlot, improverSlot: $improverSlot, '
        'metaImproverSlot: $metaImproverSlot)';
  }
}

class _GeneratedDirectiveTemplateSpec {
  const _GeneratedDirectiveTemplateSpec({
    required this.kind,
    required this.versionSlot,
  });

  final AgentTemplateKind kind;
  final _GeneratedDirectiveVersionSlot versionSlot;

  AgentTemplateEntity template(int index) {
    final id = 'generated-directive-template-$index';
    return makeTestTemplate(
      id: id,
      agentId: id,
      kind: kind,
      displayName: 'Generated directive template $index',
    );
  }

  AgentTemplateVersionEntity? activeVersion(int index) {
    final id = 'generated-directive-template-$index';
    return switch (versionSlot) {
      _GeneratedDirectiveVersionSlot.missing => null,
      _GeneratedDirectiveVersionSlot.empty => makeTestTemplateVersion(
        id: 'generated-directive-version-$index',
        agentId: id,
        directives: 'Legacy directives $index',
      ),
      _GeneratedDirectiveVersionSlot.generalOnly => makeTestTemplateVersion(
        id: 'generated-directive-version-$index',
        agentId: id,
        directives: 'Legacy directives $index',
        generalDirective: 'Existing general $index',
      ),
      _GeneratedDirectiveVersionSlot.reportOnly => makeTestTemplateVersion(
        id: 'generated-directive-version-$index',
        agentId: id,
        directives: 'Legacy directives $index',
        reportDirective: 'Existing report $index',
      ),
      _GeneratedDirectiveVersionSlot.bothPopulated => makeTestTemplateVersion(
        id: 'generated-directive-version-$index',
        agentId: id,
        directives: 'Legacy directives $index',
        generalDirective: 'Existing general $index',
        reportDirective: 'Existing report $index',
      ),
    };
  }

  bool shouldSeed(int index) {
    final version = activeVersion(index);
    return version != null &&
        (version.generalDirective.isEmpty || version.reportDirective.isEmpty);
  }

  AgentTemplateVersionEntity expectedSeededVersion(int index) {
    final version = activeVersion(index)!;
    final (general, report) = kind.seedDirectives;
    return version.copyWith(
      generalDirective: version.generalDirective.isNotEmpty
          ? version.generalDirective
          : general,
      reportDirective: version.reportDirective.isNotEmpty
          ? version.reportDirective
          : report,
    );
  }

  @override
  String toString() {
    return '_GeneratedDirectiveTemplateSpec('
        'kind: $kind, versionSlot: $versionSlot)';
  }
}

class _GeneratedSeedDirectiveFieldsScenario {
  const _GeneratedSeedDirectiveFieldsScenario({required this.templates});

  final List<_GeneratedDirectiveTemplateSpec> templates;

  List<AgentTemplateEntity> get templateEntities {
    return [
      for (final (index, spec) in templates.indexed) spec.template(index),
    ];
  }

  List<AgentTemplateVersionEntity> get expectedWrites {
    return [
      for (final (index, spec) in templates.indexed)
        if (spec.shouldSeed(index)) spec.expectedSeededVersion(index),
    ];
  }

  @override
  String toString() {
    return '_GeneratedSeedDirectiveFieldsScenario(templates: $templates)';
  }
}

extension _AgentTemplateKindSeedDirectives on AgentTemplateKind {
  (String, String) get seedDirectives {
    return switch (this) {
      AgentTemplateKind.taskAgent => (
        taskAgentGeneralDirective,
        taskAgentReportDirective,
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
  }
}

AgentTemplateVersionEntity _targetVersion({
  int version = 7,
  AgentTemplateVersionStatus status = AgentTemplateVersionStatus.active,
}) {
  return makeTestTemplateVersion(
    id: 'generated-rollback-target',
    agentId: _generatedTemplateId,
    version: version,
    status: status,
    directives: 'Generated rollback target directives.',
    generalDirective: 'Generated rollback target general.',
    reportDirective: 'Generated rollback target report.',
  );
}

AgentTemplateVersionEntity _historyVersion({
  required String id,
  int version = 1,
  AgentTemplateVersionStatus status = AgentTemplateVersionStatus.active,
}) {
  return makeTestTemplateVersion(
    id: id,
    agentId: _generatedTemplateId,
    version: version,
    status: status,
  );
}

extension _AnyGeneratedAgentTemplateServiceScenario on glados.Any {
  glados.Generator<_GeneratedTemplateEntitySlot> get templateEntitySlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateEntitySlot.values);

  glados.Generator<_GeneratedTemplateDisplayNameSlot>
  get templateDisplayNameSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateDisplayNameSlot.values);

  glados.Generator<_GeneratedTemplateModelSlot> get templateModelSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateModelSlot.values);

  glados.Generator<_GeneratedTemplateExistingProfileSlot>
  get templateExistingProfileSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedTemplateExistingProfileSlot.values);

  glados.Generator<_GeneratedTemplateProfileSlot> get templateProfileSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateProfileSlot.values);

  glados.Generator<_GeneratedTemplateActiveVersionSlot>
  get templateActiveVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateActiveVersionSlot.values);

  glados.Generator<_GeneratedTemplateHistorySlot> get templateHistorySlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateHistorySlot.values);

  glados.Generator<_GeneratedTemplateHeadSlot> get templateHeadSlot =>
      glados.AnyUtils(this).choose(_GeneratedTemplateHeadSlot.values);

  glados.Generator<_GeneratedTemplateDeleteAssignmentSlot>
  get templateDeleteAssignmentSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedTemplateDeleteAssignmentSlot.values);

  glados.Generator<_GeneratedTemplateDeleteVersionSlot>
  get templateDeleteVersionSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedTemplateDeleteVersionSlot.values);

  glados.Generator<_GeneratedTemplateRollbackTargetSlot>
  get templateRollbackTargetSlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedTemplateRollbackTargetSlot.values);

  glados.Generator<_GeneratedTemplateRollbackHistorySlot>
  get templateRollbackHistorySlot => glados.AnyUtils(
    this,
  ).choose(_GeneratedTemplateRollbackHistorySlot.values);

  glados.Generator<_GeneratedProfileReferenceSlot> get profileReferenceSlot =>
      glados.AnyUtils(this).choose(_GeneratedProfileReferenceSlot.values);

  glados.Generator<_GeneratedProfileVersionSlot> get profileVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedProfileVersionSlot.values);

  glados.Generator<_GeneratedGatherVersionSlot> get gatherVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedGatherVersionSlot.values);

  glados.Generator<_GeneratedGatherPayloadSlot> get gatherPayloadSlot =>
      glados.AnyUtils(this).choose(_GeneratedGatherPayloadSlot.values);

  glados.Generator<_GeneratedGatherAgentSlot> get gatherAgentSlot =>
      glados.AnyUtils(this).choose(_GeneratedGatherAgentSlot.values);

  glados.Generator<_GeneratedDefaultTemplateSlot> get defaultTemplateSlot =>
      glados.AnyUtils(this).choose(_GeneratedDefaultTemplateSlot.values);

  glados.Generator<AgentTemplateKind> get agentTemplateKind =>
      glados.AnyUtils(this).choose(AgentTemplateKind.values);

  glados.Generator<_GeneratedDirectiveVersionSlot> get directiveVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedDirectiveVersionSlot.values);

  glados.Generator<int> get gatherSessionDateOffset =>
      glados.IntAnys(this).intInRange(0, 30);

  glados.Generator<_GeneratedSeedDefaultsScenario> get seedDefaultsScenario =>
      glados.CombinableAny(this).combine5(
        defaultTemplateSlot,
        defaultTemplateSlot,
        defaultTemplateSlot,
        defaultTemplateSlot,
        defaultTemplateSlot,
        (
          _GeneratedDefaultTemplateSlot lauraSlot,
          _GeneratedDefaultTemplateSlot tomSlot,
          _GeneratedDefaultTemplateSlot projectSlot,
          _GeneratedDefaultTemplateSlot improverSlot,
          _GeneratedDefaultTemplateSlot metaImproverSlot,
        ) => _GeneratedSeedDefaultsScenario(
          lauraSlot: lauraSlot,
          tomSlot: tomSlot,
          projectSlot: projectSlot,
          improverSlot: improverSlot,
          metaImproverSlot: metaImproverSlot,
        ),
      );

  glados.Generator<_GeneratedDirectiveTemplateSpec> get directiveTemplateSpec =>
      glados.CombinableAny(this).combine2(
        agentTemplateKind,
        directiveVersionSlot,
        (
          AgentTemplateKind kind,
          _GeneratedDirectiveVersionSlot versionSlot,
        ) => _GeneratedDirectiveTemplateSpec(
          kind: kind,
          versionSlot: versionSlot,
        ),
      );

  glados.Generator<_GeneratedSeedDirectiveFieldsScenario>
  get seedDirectiveFieldsScenario =>
      glados.ListAnys(
            this,
          )
          .listWithLengthInRange(0, 6, directiveTemplateSpec)
          .map(
            (templates) => _GeneratedSeedDirectiveFieldsScenario(
              templates: templates,
            ),
          );

  glados.Generator<_GeneratedProfileTemplateSpec> get profileTemplateSpec =>
      glados.CombinableAny(this).combine2(
        profileReferenceSlot,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 4, profileVersionSlot),
        (
          _GeneratedProfileReferenceSlot profileSlot,
          List<_GeneratedProfileVersionSlot> versionSlots,
        ) => _GeneratedProfileTemplateSpec(
          profileSlot: profileSlot,
          versionSlots: versionSlots,
        ),
      );

  glados.Generator<_GeneratedTemplateUpdateDelta> get templateUpdateDelta =>
      glados.CombinableAny(this).combine4(
        templateExistingProfileSlot,
        templateDisplayNameSlot,
        templateModelSlot,
        templateProfileSlot,
        (
          _GeneratedTemplateExistingProfileSlot existingProfileSlot,
          _GeneratedTemplateDisplayNameSlot displayNameSlot,
          _GeneratedTemplateModelSlot modelSlot,
          _GeneratedTemplateProfileSlot profileSlot,
        ) => _GeneratedTemplateUpdateDelta(
          existingProfileSlot: existingProfileSlot,
          displayNameSlot: displayNameSlot,
          modelSlot: modelSlot,
          profileSlot: profileSlot,
        ),
      );

  glados.Generator<_GeneratedTemplateUpdateScenario>
  get templateUpdateScenario => glados.CombinableAny(this).combine6(
    templateEntitySlot,
    templateUpdateDelta,
    templateActiveVersionSlot,
    templateHistorySlot,
    templateHeadSlot,
    glados.IntAnys(this).intInRange(1, 20),
    (
      _GeneratedTemplateEntitySlot templateSlot,
      _GeneratedTemplateUpdateDelta delta,
      _GeneratedTemplateActiveVersionSlot activeVersionSlot,
      _GeneratedTemplateHistorySlot historySlot,
      _GeneratedTemplateHeadSlot headSlot,
      int nextVersionNumber,
    ) => _GeneratedTemplateUpdateScenario(
      templateSlot: templateSlot,
      delta: delta,
      activeVersionSlot: activeVersionSlot,
      historySlot: historySlot,
      headSlot: headSlot,
      nextVersionNumber: nextVersionNumber,
    ),
  );

  glados.Generator<_GeneratedTemplateDeleteScenario>
  get templateDeleteScenario => glados.CombinableAny(this).combine4(
    templateEntitySlot,
    templateHeadSlot,
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 5, templateDeleteAssignmentSlot),
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 5, templateDeleteVersionSlot),
    (
      _GeneratedTemplateEntitySlot templateSlot,
      _GeneratedTemplateHeadSlot headSlot,
      List<_GeneratedTemplateDeleteAssignmentSlot> assignmentSlots,
      List<_GeneratedTemplateDeleteVersionSlot> versionSlots,
    ) => _GeneratedTemplateDeleteScenario(
      templateSlot: templateSlot,
      headSlot: headSlot,
      assignmentSlots: assignmentSlots,
      versionSlots: versionSlots,
    ),
  );

  glados.Generator<_GeneratedTemplateRollbackScenario>
  get templateRollbackScenario => glados.CombinableAny(this).combine3(
    templateHeadSlot,
    templateRollbackTargetSlot,
    templateRollbackHistorySlot,
    (
      _GeneratedTemplateHeadSlot headSlot,
      _GeneratedTemplateRollbackTargetSlot targetSlot,
      _GeneratedTemplateRollbackHistorySlot historySlot,
    ) => _GeneratedTemplateRollbackScenario(
      headSlot: headSlot,
      targetSlot: targetSlot,
      historySlot: historySlot,
    ),
  );

  glados.Generator<_GeneratedProfileInUseScenario> get profileInUseScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(this).listWithLengthInRange(0, 5, profileTemplateSpec),
        glados.ListAnys(this).listWithLengthInRange(0, 5, profileReferenceSlot),
        (
          List<_GeneratedProfileTemplateSpec> templates,
          List<_GeneratedProfileReferenceSlot> agentProfileSlots,
        ) => _GeneratedProfileInUseScenario(
          templates: templates,
          agentProfileSlots: agentProfileSlots,
        ),
      );

  glados.Generator<_GeneratedGatherEvolutionScenario>
  get gatherEvolutionScenario => glados.CombinableAny(this).combine7(
    glados.ListAnys(this).listWithLengthInRange(0, 5, gatherVersionSlot),
    glados.IntAnys(this).intInRange(0, 4),
    glados.ListAnys(this).listWithLengthInRange(0, 6, gatherPayloadSlot),
    glados.IntAnys(this).intInRange(0, 4),
    glados.ListAnys(this).listWithLengthInRange(0, 4, gatherSessionDateOffset),
    glados.ListAnys(this).listWithLengthInRange(0, 5, gatherAgentSlot),
    glados.IntAnys(this).intInRange(0, 50),
    (
      List<_GeneratedGatherVersionSlot> versionSlots,
      int reportCount,
      List<_GeneratedGatherPayloadSlot> observationPayloadSlots,
      int noteCount,
      List<int> sessionDateOffsets,
      List<_GeneratedGatherAgentSlot> agentSlots,
      int changesSinceLastSession,
    ) => _GeneratedGatherEvolutionScenario(
      versionSlots: versionSlots,
      reportCount: reportCount,
      observationPayloadSlots: observationPayloadSlots,
      noteCount: noteCount,
      sessionDateOffsets: sessionDateOffsets,
      agentSlots: agentSlots,
      changesSinceLastSession: changesSinceLastSession,
    ),
  );
}

void main() {
  late MockAgentRepository mockRepo;
  late MockAgentSyncService mockSync;
  late AgentTemplateService service;

  setUp(() {
    mockRepo = MockAgentRepository();
    mockSync = MockAgentSyncService();

    // Stub sync service to delegate to repo stubs.
    when(() => mockSync.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSync.upsertLink(any())).thenAnswer((_) async {});

    service = AgentTemplateService(
      repository: mockRepo,
      syncService: mockSync,
    );
  });

  setUpAll(registerAllFallbackValues);

  /// Stub [mockRepo.getEntity] to return a default template for
  /// [kTestTemplateId]. Call this in tests that need the template to exist.
  void stubTemplateExists() {
    final template = makeTestTemplate();
    when(
      () => mockRepo.getEntity(kTestTemplateId),
    ).thenAnswer((_) async => template);
  }

  /// Stub the full version-creation chain so that [updateTemplate] with a
  /// model change (which triggers [createVersion]) succeeds.
  void stubVersionCreationChain() {
    final activeVersion = makeTestTemplateVersion();
    final head = makeTestTemplateHead();
    when(
      () => mockRepo.getActiveTemplateVersion(kTestTemplateId),
    ).thenAnswer((_) async => activeVersion);
    when(
      () => mockRepo.getTemplateHead(kTestTemplateId),
    ).thenAnswer((_) async => head);
    when(
      () => mockRepo.getEntity(head.versionId),
    ).thenAnswer((_) async => activeVersion);
    when(
      () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
    ).thenAnswer((_) async => 2);
    when(
      () => mockRepo.getEntitiesByAgentId(
        kTestTemplateId,
        type: AgentEntityTypes.agentTemplateVersion,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <AgentDomainEntity>[activeVersion]);
  }

  group('createTemplate', () {
    test('creates template, version, and head entities', () async {
      final result = await service.createTemplate(
        displayName: 'Laura',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Be helpful.',
        authoredBy: 'user',
        templateId: 'tpl-fixed',
      );

      expect(result.displayName, 'Laura');
      expect(result.kind, AgentTemplateKind.taskAgent);
      expect(result.id, 'tpl-fixed');

      // Should have upserted 3 entities (template + version + head).
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('uses provided templateId', () async {
      final result = await service.createTemplate(
        displayName: 'Custom',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Directives.',
        authoredBy: 'admin',
        templateId: 'custom-id',
      );

      expect(result.id, 'custom-id');
      expect(result.agentId, 'custom-id');
    });

    test('generates UUID when no templateId provided', () async {
      final result = await service.createTemplate(
        displayName: 'Auto',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Directives.',
        authoredBy: 'admin',
      );

      expect(result.id, isNotEmpty);
      expect(result.id, isNot('custom-id'));
      expect(result.modelId, 'models/test');
      expect(result.categoryIds, isEmpty);
    });

    test('creates template with category IDs', () async {
      final result = await service.createTemplate(
        displayName: 'WithCats',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Directives.',
        authoredBy: 'admin',
        categoryIds: {'cat-1', 'cat-2'},
      );

      expect(result.categoryIds, containsAll(['cat-1', 'cat-2']));
    });

    test('upserts version with correct initial values', () async {
      await service.createTemplate(
        displayName: 'Check Version',
        kind: AgentTemplateKind.taskAgent,
        modelId: 'models/test',
        directives: 'Test directives.',
        authoredBy: 'tester',
        templateId: 'tpl-ver-check',
      );

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();

      // Second entity should be the version.
      final version = captured[1] as AgentTemplateVersionEntity;
      expect(version.version, 1);
      expect(version.status, AgentTemplateVersionStatus.active);
      expect(version.directives, 'Test directives.');
      expect(version.authoredBy, 'tester');
      expect(version.agentId, 'tpl-ver-check');
    });
  });

  group('updateTemplate', () {
    glados.Glados(
      glados.any.templateUpdateScenario,
      glados.ExploreConfig(numRuns: 220),
    ).test('matches generated update/versioning invariants', (scenario) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final testDate = DateTime(2026, 4, 20, 10, 15);
      var storedTemplate = scenario.initialTemplateEntity;

      when(
        () => generatedRepository.getEntity(_generatedTemplateId),
      ).thenAnswer((_) async => storedTemplate);
      when(
        () => generatedRepository.getActiveTemplateVersion(
          _generatedTemplateId,
        ),
      ).thenAnswer((_) async => scenario.activeVersion);
      when(
        () => generatedRepository.getTemplateHead(_generatedTemplateId),
      ).thenAnswer((_) async => scenario.currentHead);
      when(
        () => generatedRepository.getNextTemplateVersionNumber(
          _generatedTemplateId,
        ),
      ).thenAnswer((_) async => scenario.nextVersionNumber);
      when(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => scenario.versionHistory);
      when(() => generatedSync.upsertEntity(any())).thenAnswer((invocation) {
        final entity =
            invocation.positionalArguments.single as AgentDomainEntity;
        if (entity is AgentTemplateEntity) {
          storedTemplate = entity;
        }
        return Future<void>.value();
      });

      Future<AgentTemplateEntity> updateTemplate() {
        return withClock(Clock.fixed(testDate), () {
          return generatedService.updateTemplate(
            templateId: _generatedTemplateId,
            displayName: scenario.delta.requestedDisplayName,
            modelId: scenario.delta.requestedModelId,
            profileId: scenario.delta.requestedProfileId,
            clearProfileId: scenario.delta.clearProfileId,
          );
        });
      }

      if (!scenario.templateExists) {
        await expectLater(
          updateTemplate,
          throwsA(isA<StateError>()),
          reason: '$scenario',
        );

        verifyNever(() => generatedSync.upsertEntity(any()));
        verifyNever(
          () => generatedRepository.getActiveTemplateVersion(
            _generatedTemplateId,
          ),
        );
        verifyNever(
          () => generatedRepository.getTemplateHead(_generatedTemplateId),
        );
        verifyNever(
          () => generatedRepository.getNextTemplateVersionNumber(
            _generatedTemplateId,
          ),
        );
        return;
      }

      final result = await updateTemplate();
      expect(
        result.displayName,
        scenario.delta.expectedDisplayName,
        reason: '$scenario',
      );
      expect(
        result.modelId,
        scenario.delta.expectedModelId,
        reason: '$scenario',
      );
      expect(
        result.profileId,
        scenario.delta.expectedProfileId,
        reason: '$scenario',
      );
      expect(result.updatedAt, testDate, reason: '$scenario');

      if (scenario.shouldReadActiveVersion) {
        verify(
          () => generatedRepository.getActiveTemplateVersion(
            _generatedTemplateId,
          ),
        ).called(1);
      } else {
        verifyNever(
          () => generatedRepository.getActiveTemplateVersion(
            _generatedTemplateId,
          ),
        );
      }

      final writes = verify(
        () => generatedSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final expectedWriteCount =
          1 +
          (scenario.shouldCreateVersion
              ? scenario.archivedVersionIds.length + 2
              : 0);
      expect(writes, hasLength(expectedWriteCount), reason: '$scenario');

      final updatedTemplate = writes.first as AgentTemplateEntity;
      expect(
        updatedTemplate.displayName,
        scenario.delta.expectedDisplayName,
        reason: '$scenario',
      );
      expect(
        updatedTemplate.modelId,
        scenario.delta.expectedModelId,
        reason: '$scenario',
      );
      expect(
        updatedTemplate.profileId,
        scenario.delta.expectedProfileId,
        reason: '$scenario',
      );
      expect(updatedTemplate.updatedAt, testDate, reason: '$scenario');

      if (!scenario.shouldCreateVersion) {
        verifyNever(
          () => generatedRepository.getTemplateHead(_generatedTemplateId),
        );
        verifyNever(
          () => generatedRepository.getNextTemplateVersionNumber(
            _generatedTemplateId,
          ),
        );
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            _generatedTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        );
        expect(
          writes.whereType<AgentTemplateVersionEntity>(),
          isEmpty,
          reason: '$scenario',
        );
        expect(
          writes.whereType<AgentTemplateHeadEntity>(),
          isEmpty,
          reason: '$scenario',
        );
        return;
      }

      verify(
        () => generatedRepository.getTemplateHead(_generatedTemplateId),
      ).called(1);
      verify(
        () => generatedRepository.getNextTemplateVersionNumber(
          _generatedTemplateId,
        ),
      ).called(1);
      verify(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).called(1);

      final archivedWrites = writes
          .whereType<AgentTemplateVersionEntity>()
          .where(
            (version) => version.status == AgentTemplateVersionStatus.archived,
          )
          .toList();
      expect(
        archivedWrites.map((version) => version.id).toSet(),
        scenario.archivedVersionIds,
        reason: '$scenario',
      );

      final activeVersionWrites = writes
          .whereType<AgentTemplateVersionEntity>()
          .where(
            (version) => version.status == AgentTemplateVersionStatus.active,
          )
          .toList();
      expect(activeVersionWrites, hasLength(1), reason: '$scenario');

      final newVersion = activeVersionWrites.single;
      final activeVersion = scenario.activeVersion!;
      expect(newVersion.agentId, _generatedTemplateId, reason: '$scenario');
      expect(
        newVersion.version,
        scenario.nextVersionNumber,
        reason: '$scenario',
      );
      expect(
        newVersion.directives,
        activeVersion.directives,
        reason: '$scenario',
      );
      expect(
        newVersion.generalDirective,
        activeVersion.generalDirective,
        reason: '$scenario',
      );
      expect(
        newVersion.reportDirective,
        activeVersion.reportDirective,
        reason: '$scenario',
      );
      expect(
        newVersion.authoredBy,
        'system:config_change',
        reason: '$scenario',
      );
      expect(
        newVersion.modelId,
        scenario.delta.expectedModelId,
        reason: '$scenario',
      );
      expect(
        newVersion.profileId,
        scenario.delta.expectedProfileId,
        reason: '$scenario',
      );
      expect(newVersion.createdAt, testDate, reason: '$scenario');

      final headWrites = writes.whereType<AgentTemplateHeadEntity>().toList();
      expect(headWrites, hasLength(1), reason: '$scenario');
      final head = headWrites.single;
      expect(head.agentId, _generatedTemplateId, reason: '$scenario');
      expect(head.versionId, newVersion.id, reason: '$scenario');
      expect(head.updatedAt, testDate, reason: '$scenario');
      final currentHead = scenario.currentHead;
      if (currentHead != null) {
        expect(head.id, currentHead.id, reason: '$scenario');
      } else {
        expect(head.id, isNotEmpty, reason: '$scenario');
      }
    });

    test('updates display name and model ID', () async {
      stubTemplateExists();
      stubVersionCreationChain();

      final result = await service.updateTemplate(
        templateId: kTestTemplateId,
        displayName: 'New Name',
        modelId: 'models/gemini-flash',
      );

      expect(result.displayName, 'New Name');
      expect(result.modelId, 'models/gemini-flash');
      // 1 template upsert + 3 from createVersion (archive, new, head).
      verify(() => mockSync.upsertEntity(any())).called(4);
    });

    test('updates only display name when modelId is null', () async {
      stubTemplateExists();

      final result = await service.updateTemplate(
        templateId: kTestTemplateId,
        displayName: 'Renamed',
      );

      expect(result.displayName, 'Renamed');
      // Model should remain the original from makeTestTemplate.
      expect(result.modelId, 'models/gemini-3-flash-preview');
    });

    test('updates only model ID when displayName is null', () async {
      stubTemplateExists();
      stubVersionCreationChain();

      final result = await service.updateTemplate(
        templateId: kTestTemplateId,
        modelId: 'models/gemini-flash',
      );

      // Name should remain the original from makeTestTemplate.
      expect(result.displayName, 'Test Template');
      expect(result.modelId, 'models/gemini-flash');
    });

    test('throws when template does not exist', () async {
      when(
        () => mockRepo.getEntity('nonexistent'),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.updateTemplate(
          templateId: 'nonexistent',
          displayName: 'New Name',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Template nonexistent not found'),
          ),
        ),
      );

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('persists the updated entity via syncService', () async {
      stubTemplateExists();
      stubVersionCreationChain();

      await service.updateTemplate(
        templateId: kTestTemplateId,
        displayName: 'Updated',
        modelId: 'models/new-model',
      );

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // First upsert is the template itself.
      final persisted = captured.first as AgentTemplateEntity;
      expect(persisted.displayName, 'Updated');
      expect(persisted.modelId, 'models/new-model');
      expect(persisted.id, kTestTemplateId);
      // Remaining 3 are from createVersion (archive, new version, head).
      expect(captured, hasLength(4));
    });

    test('preserves split directive fields on model change version', () async {
      stubTemplateExists();
      final activeVersion = makeTestTemplateVersion(
        generalDirective: 'Be thorough.',
        reportDirective: 'Use bullet points.',
      );
      final head = makeTestTemplateHead();
      when(
        () => mockRepo.getActiveTemplateVersion(kTestTemplateId),
      ).thenAnswer((_) async => activeVersion);
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity(head.versionId),
      ).thenAnswer((_) async => activeVersion);
      when(
        () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[activeVersion]);

      await service.updateTemplate(
        templateId: kTestTemplateId,
        modelId: 'models/new-model',
      );

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // Find the newly created version (not the archived one).
      final newVersion = captured
          .whereType<AgentTemplateVersionEntity>()
          .where(
            (v) => v.status == AgentTemplateVersionStatus.active,
          )
          .first;
      expect(newVersion.generalDirective, 'Be thorough.');
      expect(newVersion.reportDirective, 'Use bullet points.');
    });
  });

  group('createVersion', () {
    test('archives current version and creates new one', () async {
      stubTemplateExists();
      final currentVersion = makeTestTemplateVersion(
        id: 'ver-old',
      );
      final currentHead = makeTestTemplateHead(versionId: 'ver-old');

      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => currentHead);
      when(
        () => mockRepo.getEntity('ver-old'),
      ).thenAnswer((_) async => currentVersion);
      when(
        () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => <AgentDomainEntity>[currentVersion],
      );

      final result = await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'Updated directives.',
        authoredBy: 'admin',
      );

      expect(result.version, 2);
      expect(result.status, AgentTemplateVersionStatus.active);
      expect(result.directives, 'Updated directives.');

      // 3 upserts: archived old version, new version, updated head.
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('archives ALL stale active versions, not just head', () async {
      stubTemplateExists();
      final currentHead = makeTestTemplateHead(versionId: 'ver-3');
      final v1 = makeTestTemplateVersion(
        id: 'ver-1',
        // Stale active status from a previous bug:
        // ignore: avoid_redundant_argument_values
        status: AgentTemplateVersionStatus.active,
      );
      final v2 = makeTestTemplateVersion(
        id: 'ver-2',
        version: 2,
        // Also stale active:
        // ignore: avoid_redundant_argument_values
        status: AgentTemplateVersionStatus.active,
      );
      final v3 = makeTestTemplateVersion(
        id: 'ver-3',
        version: 3,
        // Current head — active:
        // ignore: avoid_redundant_argument_values
        status: AgentTemplateVersionStatus.active,
      );

      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => currentHead);
      when(
        () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
      ).thenAnswer((_) async => 4);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[v3, v2, v1]);

      await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'New directives.',
        authoredBy: 'admin',
      );

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();

      // 5 upserts: 3 archived versions + new version + updated head.
      expect(captured, hasLength(5));

      // All three old versions should be archived.
      final archivedVersions = captured
          .whereType<AgentTemplateVersionEntity>()
          .where(
            (v) => v.status == AgentTemplateVersionStatus.archived,
          )
          .toList();
      expect(archivedVersions, hasLength(3));
      expect(
        archivedVersions.map((v) => v.id).toSet(),
        equals({'ver-1', 'ver-2', 'ver-3'}),
      );
    });

    test('creates first version when no head exists', () async {
      stubTemplateExists();
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
      ).thenAnswer((_) async => 1);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[]);

      final result = await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'First directives.',
        authoredBy: 'user',
      );

      expect(result.version, 1);

      // 2 upserts: new version + new head (no old version to archive).
      verify(() => mockSync.upsertEntity(any())).called(2);
    });

    test('skips archiving when current version entity is not found', () async {
      stubTemplateExists();
      final currentHead = makeTestTemplateHead(versionId: 'ver-gone');

      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => currentHead);
      when(() => mockRepo.getEntity('ver-gone')).thenAnswer((_) async => null);
      when(
        () => mockRepo.getNextTemplateVersionNumber(kTestTemplateId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <AgentDomainEntity>[]);

      final result = await service.createVersion(
        templateId: kTestTemplateId,
        directives: 'New directives.',
        authoredBy: 'user',
      );

      expect(result.version, 2);

      // 2 upserts: new version + updated head (no archive since old not found).
      verify(() => mockSync.upsertEntity(any())).called(2);
    });

    test('throws when template does not exist', () async {
      when(
        () => mockRepo.getEntity('nonexistent'),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.createVersion(
          templateId: 'nonexistent',
          directives: 'Directives.',
          authoredBy: 'user',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Template nonexistent not found'),
          ),
        ),
      );

      verifyNever(() => mockSync.upsertEntity(any()));
    });
  });

  group('getTemplate', () {
    test('returns template when found', () async {
      stubTemplateExists();

      final result = await service.getTemplate(kTestTemplateId);

      expect(result, isNotNull);
      expect(result!.displayName, 'Test Template');
    });

    test('returns null when not found', () async {
      when(
        () => mockRepo.getEntity('nonexistent'),
      ).thenAnswer((_) async => null);

      final result = await service.getTemplate('nonexistent');
      expect(result, isNull);
    });

    test('returns null when entity is not a template type', () async {
      final version = makeTestTemplateVersion(id: 'ver-001');
      when(
        () => mockRepo.getEntity('ver-001'),
      ).thenAnswer((_) async => version);

      final result = await service.getTemplate('ver-001');
      expect(result, isNull);
    });
  });

  group('listTemplates', () {
    test('delegates to repository', () async {
      final templates = [
        makeTestTemplate(id: 'tpl-a', agentId: 'tpl-a'),
        makeTestTemplate(id: 'tpl-b', agentId: 'tpl-b'),
      ];
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => templates);

      final result = await service.listTemplates();

      expect(result.length, 2);
      verify(() => mockRepo.getAllTemplates()).called(1);
    });
  });

  group('getActiveVersion', () {
    test('delegates to repository', () async {
      final version = makeTestTemplateVersion();
      when(
        () => mockRepo.getActiveTemplateVersion(kTestTemplateId),
      ).thenAnswer((_) async => version);

      final result = await service.getActiveVersion(kTestTemplateId);

      expect(result, isNotNull);
      expect(result!.version, 1);
    });

    test('returns null when no active version exists', () async {
      when(
        () => mockRepo.getActiveTemplateVersion(kTestTemplateId),
      ).thenAnswer((_) async => null);

      final result = await service.getActiveVersion(kTestTemplateId);

      expect(result, isNull);
    });
  });

  group('getTemplateForAgent', () {
    test('resolves template via link', () async {
      stubTemplateExists();
      final link = makeTestTemplateAssignmentLink();

      when(
        () => mockRepo.getLinksTo(kTestAgentId, type: 'template_assignment'),
      ).thenAnswer((_) async => [link]);

      final result = await service.getTemplateForAgent(kTestAgentId);

      expect(result, isNotNull);
      expect(result!.id, kTestTemplateId);
    });

    test('returns null when no link exists', () async {
      when(
        () => mockRepo.getLinksTo(kTestAgentId, type: 'template_assignment'),
      ).thenAnswer((_) async => []);

      final result = await service.getTemplateForAgent(kTestAgentId);
      expect(result, isNull);
    });
  });

  group('getAgentsForTemplate', () {
    test('returns agent entities from links', () async {
      final agentA = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final agentB = makeTestIdentity(id: 'agent-b', agentId: 'agent-b');
      final links = [
        makeTestTemplateAssignmentLink(id: 'l1', toId: 'agent-a'),
        makeTestTemplateAssignmentLink(id: 'l2', toId: 'agent-b'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(() => mockRepo.getEntity('agent-a')).thenAnswer((_) async => agentA);
      when(() => mockRepo.getEntity('agent-b')).thenAnswer((_) async => agentB);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result.length, 2);
      expect(result.map((a) => a.id), containsAll(['agent-a', 'agent-b']));
    });

    test('returns empty list when no assignments exist', () async {
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, isEmpty);
    });

    test('skips links pointing to non-agent entities', () async {
      final links = [
        makeTestTemplateAssignmentLink(id: 'l1', toId: 'not-an-agent'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      // Return a template entity instead of an agent.
      when(
        () => mockRepo.getEntity('not-an-agent'),
      ).thenAnswer((_) async => makeTestTemplate(id: 'not-an-agent'));

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, isEmpty);
    });

    test('skips links where entity is null', () async {
      final links = [
        makeTestTemplateAssignmentLink(id: 'l1', toId: 'gone'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(() => mockRepo.getEntity('gone')).thenAnswer((_) async => null);

      final result = await service.getAgentsForTemplate(kTestTemplateId);

      expect(result, isEmpty);
    });
  });

  group('listTemplatesForCategory', () {
    test('filters by categoryId', () async {
      final templates = [
        makeTestTemplate(
          id: 'tpl-a',
          agentId: 'tpl-a',
          categoryIds: {'cat-1', 'cat-2'},
        ),
        makeTestTemplate(
          id: 'tpl-b',
          agentId: 'tpl-b',
          categoryIds: {'cat-3'},
        ),
      ];
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => templates);

      final result = await service.listTemplatesForCategory('cat-1');

      expect(result.length, 1);
      expect(result.first.id, 'tpl-a');
    });

    test('returns empty list when no templates match category', () async {
      final templates = [
        makeTestTemplate(
          id: 'tpl-a',
          agentId: 'tpl-a',
          categoryIds: {'cat-1'},
        ),
      ];
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => templates);

      final result = await service.listTemplatesForCategory('nonexistent-cat');

      expect(result, isEmpty);
    });
  });

  group('deleteTemplate', () {
    glados.Glados(
      glados.any.templateDeleteScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated soft-delete invariants', (scenario) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final testDate = DateTime(2026, 4, 21, 11, 30);
      final links = [
        for (final (index, _) in scenario.assignmentSlots.indexed)
          makeTestTemplateAssignmentLink(
            id: 'generated-delete-link-$index',
            fromId: _generatedTemplateId,
            toId: 'generated-delete-agent-$index',
          ),
      ];

      when(
        () => generatedRepository.getLinksFrom(
          _generatedTemplateId,
          type: AgentLinkTypes.templateAssignment,
        ),
      ).thenAnswer((_) async => links);
      for (final (index, slot) in scenario.assignmentSlots.indexed) {
        when(
          () => generatedRepository.getEntity('generated-delete-agent-$index'),
        ).thenAnswer((_) async => scenario.assignmentEntity(slot, index));
      }
      when(
        () => generatedRepository.getEntity(_generatedTemplateId),
      ).thenAnswer((_) async => scenario.initialTemplateEntity);
      when(
        () => generatedRepository.getTemplateHead(_generatedTemplateId),
      ).thenAnswer((_) async => scenario.currentHead);
      when(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
        ),
      ).thenAnswer((_) async => scenario.versionEntities);
      when(() => generatedSync.upsertEntity(any())).thenAnswer((_) async {});

      Future<void> deleteTemplate() {
        return withClock(Clock.fixed(testDate), () {
          return generatedService.deleteTemplate(_generatedTemplateId);
        });
      }

      if (scenario.blockingAgentCount > 0) {
        await expectLater(
          deleteTemplate,
          throwsA(
            isA<TemplateInUseException>().having(
              (error) => error.activeCount,
              'activeCount',
              scenario.blockingAgentCount,
            ),
          ),
          reason: '$scenario',
        );

        verifyNever(() => generatedSync.upsertEntity(any()));
        verifyNever(
          () => generatedRepository.getTemplateHead(_generatedTemplateId),
        );
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            _generatedTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
          ),
        );
        return;
      }

      await deleteTemplate();

      if (!scenario.templateExists) {
        verifyNever(() => generatedSync.upsertEntity(any()));
        verifyNever(
          () => generatedRepository.getTemplateHead(_generatedTemplateId),
        );
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            _generatedTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
          ),
        );
        return;
      }

      verify(
        () => generatedRepository.getTemplateHead(_generatedTemplateId),
      ).called(1);
      verify(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
        ),
      ).called(1);

      final writes = verify(
        () => generatedSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final expectedWriteCount =
          1 +
          (scenario.currentHead == null ? 0 : 1) +
          scenario.deletedVersionIds.length;
      expect(writes, hasLength(expectedWriteCount), reason: '$scenario');

      final deletedTemplate = writes.first as AgentTemplateEntity;
      expect(deletedTemplate.deletedAt, testDate, reason: '$scenario');
      expect(deletedTemplate.updatedAt, testDate, reason: '$scenario');

      final headWrites = writes.whereType<AgentTemplateHeadEntity>().toList();
      if (scenario.currentHead == null) {
        expect(headWrites, isEmpty, reason: '$scenario');
      } else {
        expect(headWrites, hasLength(1), reason: '$scenario');
        expect(headWrites.single.id, _generatedHeadId, reason: '$scenario');
        expect(headWrites.single.deletedAt, testDate, reason: '$scenario');
        expect(headWrites.single.updatedAt, testDate, reason: '$scenario');
      }

      final versionWrites = writes
          .whereType<AgentTemplateVersionEntity>()
          .toList();
      expect(
        versionWrites.map((version) => version.id).toSet(),
        scenario.deletedVersionIds,
        reason: '$scenario',
      );
      for (final version in versionWrites) {
        expect(version.deletedAt, testDate, reason: '$scenario');
      }
    });

    test('fails when active instances exist', () async {
      final activeAgent = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(
        () => mockRepo.getEntity('agent-a'),
      ).thenAnswer((_) async => activeAgent);

      await expectLater(
        service.deleteTemplate(kTestTemplateId),
        throwsA(isA<TemplateInUseException>()),
      );
    });

    test('succeeds when all instances are destroyed', () async {
      stubTemplateExists();
      final destroyedAgent = makeTestIdentity(
        id: 'agent-a',
        agentId: 'agent-a',
        lifecycle: AgentLifecycle.destroyed,
      );
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(
        () => mockRepo.getEntity('agent-a'),
      ).thenAnswer((_) async => destroyedAgent);
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
        ),
      ).thenAnswer((_) async => []);

      await service.deleteTemplate(kTestTemplateId);

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final deleted = captured.first as AgentTemplateEntity;
      expect(deleted.deletedAt, isNotNull);
    });

    test('soft-deletes template, head, and versions', () async {
      stubTemplateExists();
      final head = makeTestTemplateHead();
      final version = makeTestTemplateVersion();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
        ),
      ).thenAnswer((_) async => [version]);

      await service.deleteTemplate(kTestTemplateId);

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();

      // 3 upserts: template, head, version — all soft-deleted.
      expect(captured.length, 3);

      final deletedTemplate = captured[0] as AgentTemplateEntity;
      expect(deletedTemplate.deletedAt, isNotNull);

      final deletedHead = captured[1] as AgentTemplateHeadEntity;
      expect(deletedHead.deletedAt, isNotNull);

      final deletedVersion = captured[2] as AgentTemplateVersionEntity;
      expect(deletedVersion.deletedAt, isNotNull);
    });

    test('no-op when template does not exist', () async {
      when(
        () => mockRepo.getLinksFrom(
          'missing',
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);
      when(() => mockRepo.getEntity('missing')).thenAnswer((_) async => null);

      await service.deleteTemplate('missing');

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('fails with mix of active and destroyed instances', () async {
      final activeAgent = makeTestIdentity(id: 'agent-a', agentId: 'agent-a');
      final destroyedAgent = makeTestIdentity(
        id: 'agent-b',
        agentId: 'agent-b',
        lifecycle: AgentLifecycle.destroyed,
      );
      final links = [
        makeTestTemplateAssignmentLink(toId: 'agent-a'),
        makeTestTemplateAssignmentLink(id: 'l2', toId: 'agent-b'),
      ];
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      when(
        () => mockRepo.getEntity('agent-a'),
      ).thenAnswer((_) async => activeAgent);
      when(
        () => mockRepo.getEntity('agent-b'),
      ).thenAnswer((_) async => destroyedAgent);

      await expectLater(
        service.deleteTemplate(kTestTemplateId),
        throwsA(
          isA<TemplateInUseException>().having(
            (e) => e.activeCount,
            'activeCount',
            equals(1),
          ),
        ),
      );
    });
  });

  group('rollbackToVersion', () {
    glados.Glados(
      glados.any.templateRollbackScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated rollback invariants', (scenario) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final testDate = DateTime(2026, 4, 22, 12, 45);

      when(
        () => generatedRepository.getTemplateHead(_generatedTemplateId),
      ).thenAnswer((_) async => scenario.currentHead);
      when(
        () => generatedRepository.getEntity(scenario.requestedVersionId),
      ).thenAnswer((_) async => scenario.targetEntity);
      when(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => scenario.historyEntities);
      when(() => generatedSync.upsertEntity(any())).thenAnswer((_) async {});

      Future<void> rollbackToVersion() {
        return withClock(Clock.fixed(testDate), () {
          return generatedService.rollbackToVersion(
            templateId: _generatedTemplateId,
            versionId: scenario.requestedVersionId,
          );
        });
      }

      if (scenario.headSlot == _GeneratedTemplateHeadSlot.missing) {
        await expectLater(
          rollbackToVersion,
          throwsA(isA<StateError>()),
          reason: '$scenario',
        );

        verifyNever(
          () => generatedRepository.getEntity(scenario.requestedVersionId),
        );
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            _generatedTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        );
        verifyNever(() => generatedSync.upsertEntity(any()));
        return;
      }

      if (!scenario.targetIsValid) {
        await expectLater(
          rollbackToVersion,
          throwsA(isA<StateError>()),
          reason: '$scenario',
        );

        verify(
          () => generatedRepository.getEntity(scenario.requestedVersionId),
        ).called(1);
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            _generatedTemplateId,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        );
        verifyNever(() => generatedSync.upsertEntity(any()));
        return;
      }

      await rollbackToVersion();

      verify(
        () => generatedRepository.getEntity(scenario.requestedVersionId),
      ).called(1);
      verify(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).called(1);

      final writes = verify(
        () => generatedSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(
        writes,
        hasLength(scenario.expectedArchivedWrites.length + 2),
        reason: '$scenario',
      );

      final archivedWrites = writes
          .take(scenario.expectedArchivedWrites.length)
          .cast<AgentTemplateVersionEntity>()
          .toList();
      expect(
        archivedWrites.map((version) => version.id).toList(),
        scenario.expectedArchivedWrites.map((version) => version.id).toList(),
        reason: '$scenario',
      );
      for (final archived in archivedWrites) {
        expect(
          archived.status,
          AgentTemplateVersionStatus.archived,
          reason: '$scenario',
        );
      }

      final reactivatedTarget =
          writes[writes.length - 2] as AgentTemplateVersionEntity;
      expect(
        reactivatedTarget.id,
        scenario.requestedVersionId,
        reason: '$scenario',
      );
      expect(
        reactivatedTarget.status,
        AgentTemplateVersionStatus.active,
        reason: '$scenario',
      );
      expect(
        reactivatedTarget.directives,
        scenario.validTargetVersion.directives,
        reason: '$scenario',
      );

      final updatedHead = writes.last as AgentTemplateHeadEntity;
      expect(updatedHead.id, _generatedHeadId, reason: '$scenario');
      expect(
        updatedHead.versionId,
        scenario.requestedVersionId,
        reason: '$scenario',
      );
      expect(updatedHead.updatedAt, testDate, reason: '$scenario');
    });

    test('archives current, reactivates target, updates head', () async {
      final currentVersion = makeTestTemplateVersion(
        id: 'ver-old',
        // ignore: avoid_redundant_argument_values
        status: AgentTemplateVersionStatus.active,
      );
      final head = makeTestTemplateHead(versionId: 'ver-old');
      final targetVersion = makeTestTemplateVersion(
        id: 'ver-new',
        // ignore: avoid_redundant_argument_values
        agentId: kTestTemplateId,
        status: AgentTemplateVersionStatus.archived,
      );
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity('ver-new'),
      ).thenAnswer((_) async => targetVersion);
      when(
        () => mockRepo.getEntity('ver-old'),
      ).thenAnswer((_) async => currentVersion);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => <AgentDomainEntity>[currentVersion, targetVersion],
      );

      await service.rollbackToVersion(
        templateId: kTestTemplateId,
        versionId: 'ver-new',
      );

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();

      // 3 upserts: archive current (only non-archived), reactivate target,
      // update head.
      expect(captured.length, 3);

      final archivedCurrent = captured[0] as AgentTemplateVersionEntity;
      expect(archivedCurrent.id, 'ver-old');
      expect(archivedCurrent.status, AgentTemplateVersionStatus.archived);

      final reactivatedTarget = captured[1] as AgentTemplateVersionEntity;
      expect(reactivatedTarget.id, 'ver-new');
      expect(reactivatedTarget.status, AgentTemplateVersionStatus.active);

      final updatedHead = captured[2] as AgentTemplateHeadEntity;
      expect(updatedHead.versionId, 'ver-new');
    });

    test('throws when no head exists', () async {
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'ver-new',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when version does not exist', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity('nonexistent'),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'nonexistent',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No version nonexistent found for template'),
          ),
        ),
      );
    });

    test('throws when version belongs to different template', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      final wrongTemplateVersion = makeTestTemplateVersion(
        id: 'ver-other',
        agentId: 'other-template-id',
      );
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity('ver-other'),
      ).thenAnswer((_) async => wrongTemplateVersion);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'ver-other',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No version ver-other found for template'),
          ),
        ),
      );
    });

    test('throws when entity is not a version type', () async {
      final head = makeTestTemplateHead(versionId: 'ver-old');
      final nonVersion = makeTestTemplate(id: 'not-a-version');
      when(
        () => mockRepo.getTemplateHead(kTestTemplateId),
      ).thenAnswer((_) async => head);
      when(
        () => mockRepo.getEntity('not-a-version'),
      ).thenAnswer((_) async => nonVersion);

      await expectLater(
        service.rollbackToVersion(
          templateId: kTestTemplateId,
          versionId: 'not-a-version',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('seedDefaults', () {
    glados.Glados(
      glados.any.seedDefaultsScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated default seeding invariants', (scenario) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final testDate = DateTime(2026, 4, 23, 9);

      when(generatedRepository.getAllTemplates).thenAnswer(
        (_) async => const <AgentTemplateEntity>[],
      );
      when(
        () => generatedSync.upsertEntity(any()),
      ).thenAnswer((_) async {});

      for (final (index, definition) in _defaultTemplateDefinitions.indexed) {
        final slot = scenario.slots[index];
        when(
          () => generatedRepository.getEntity(definition.id),
        ).thenAnswer((_) async => definition.existingEntity(slot));
      }

      await withClock(Clock.fixed(testDate), generatedService.seedDefaults);

      if (scenario.allPresent) {
        verifyNever(() => generatedSync.upsertEntity(any()));
        verifyNever(generatedRepository.getAllTemplates);
        return;
      }

      verify(generatedRepository.getAllTemplates).called(1);
      final writes = verify(
        () => generatedSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(
        writes,
        hasLength(scenario.templatesToCreate.length * 3),
        reason: '$scenario',
      );

      for (final (index, definition) in scenario.templatesToCreate.indexed) {
        final offset = index * 3;
        final template = writes[offset] as AgentTemplateEntity;
        final version = writes[offset + 1] as AgentTemplateVersionEntity;
        final head = writes[offset + 2] as AgentTemplateHeadEntity;

        expect(template.id, definition.id, reason: '$scenario');
        expect(template.agentId, definition.id, reason: '$scenario');
        expect(
          template.displayName,
          definition.displayName,
          reason: '$scenario',
        );
        expect(template.kind, definition.kind, reason: '$scenario');
        expect(
          template.modelId,
          kDefaultAgentTemplateModelId,
          reason: '$scenario',
        );
        expect(template.createdAt, testDate, reason: '$scenario');
        expect(template.updatedAt, testDate, reason: '$scenario');

        expect(version.agentId, definition.id, reason: '$scenario');
        expect(version.version, 1, reason: '$scenario');
        expect(
          version.status,
          AgentTemplateVersionStatus.active,
          reason: '$scenario',
        );
        expect(version.directives, isNotEmpty, reason: '$scenario');
        expect(version.generalDirective, definition.generalDirective);
        expect(version.reportDirective, definition.reportDirective);
        expect(version.authoredBy, 'system', reason: '$scenario');
        expect(
          version.modelId,
          kDefaultAgentTemplateModelId,
          reason: '$scenario',
        );
        expect(version.profileId, isNull, reason: '$scenario');
        expect(version.createdAt, testDate, reason: '$scenario');

        expect(head.agentId, definition.id, reason: '$scenario');
        expect(head.versionId, version.id, reason: '$scenario');
        expect(head.updatedAt, testDate, reason: '$scenario');
      }
    });

    test('creates all default templates when none are seeded', () async {
      when(
        () => mockRepo.getEntity(lauraTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(tomTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(projectTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(improverTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(metaImproverTemplateId),
      ).thenAnswer((_) async => null);
      // seedDirectiveFields calls listTemplates after creating defaults.
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => []);

      await service.seedDefaults();

      // 5 templates * 3 entities each = 15 upserts.
      verify(() => mockSync.upsertEntity(any())).called(15);
    });

    test('skips creation when all already seeded', () async {
      final laura = makeTestTemplate(
        id: lauraTemplateId,
        agentId: lauraTemplateId,
      );
      final tom = makeTestTemplate(
        id: tomTemplateId,
        agentId: tomTemplateId,
      );
      final projectTemplate = makeTestTemplate(
        id: projectTemplateId,
        agentId: projectTemplateId,
        kind: AgentTemplateKind.projectAgent,
      );
      final improver = makeTestTemplate(
        id: improverTemplateId,
        agentId: improverTemplateId,
      );
      final metaImprover = makeTestTemplate(
        id: metaImproverTemplateId,
        agentId: metaImproverTemplateId,
      );
      when(
        () => mockRepo.getEntity(lauraTemplateId),
      ).thenAnswer((_) async => laura);
      when(
        () => mockRepo.getEntity(tomTemplateId),
      ).thenAnswer((_) async => tom);
      when(
        () => mockRepo.getEntity(projectTemplateId),
      ).thenAnswer((_) async => projectTemplate);
      when(
        () => mockRepo.getEntity(improverTemplateId),
      ).thenAnswer((_) async => improver);
      when(
        () => mockRepo.getEntity(metaImproverTemplateId),
      ).thenAnswer((_) async => metaImprover);

      await service.seedDefaults();

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('seeds only missing templates when some already exist', () async {
      final laura = makeTestTemplate(
        id: lauraTemplateId,
        agentId: lauraTemplateId,
      );
      final improver = makeTestTemplate(
        id: improverTemplateId,
        agentId: improverTemplateId,
      );
      final projectTemplate = makeTestTemplate(
        id: projectTemplateId,
        agentId: projectTemplateId,
        kind: AgentTemplateKind.projectAgent,
      );
      final metaImprover = makeTestTemplate(
        id: metaImproverTemplateId,
        agentId: metaImproverTemplateId,
      );
      when(
        () => mockRepo.getEntity(lauraTemplateId),
      ).thenAnswer((_) async => laura);
      when(
        () => mockRepo.getEntity(tomTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(projectTemplateId),
      ).thenAnswer((_) async => projectTemplate);
      when(
        () => mockRepo.getEntity(improverTemplateId),
      ).thenAnswer((_) async => improver);
      when(
        () => mockRepo.getEntity(metaImproverTemplateId),
      ).thenAnswer((_) async => metaImprover);
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => []);

      await service.seedDefaults();

      // Only Tom: 3 entities (template + version + head).
      verify(() => mockSync.upsertEntity(any())).called(3);
    });

    test('seeds only Laura and Improver when Tom already exists', () async {
      final tom = makeTestTemplate(
        id: tomTemplateId,
        agentId: tomTemplateId,
      );
      final projectTemplate = makeTestTemplate(
        id: projectTemplateId,
        agentId: projectTemplateId,
        kind: AgentTemplateKind.projectAgent,
      );
      final metaImprover = makeTestTemplate(
        id: metaImproverTemplateId,
        agentId: metaImproverTemplateId,
      );
      when(
        () => mockRepo.getEntity(lauraTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(tomTemplateId),
      ).thenAnswer((_) async => tom);
      when(
        () => mockRepo.getEntity(projectTemplateId),
      ).thenAnswer((_) async => projectTemplate);
      when(
        () => mockRepo.getEntity(improverTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(metaImproverTemplateId),
      ).thenAnswer((_) async => metaImprover);
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => []);

      await service.seedDefaults();

      // Laura + Improver: 2 * 3 entities = 6 upserts.
      verify(() => mockSync.upsertEntity(any())).called(6);
    });

    test('seeds missing default project template', () async {
      final laura = makeTestTemplate(
        id: lauraTemplateId,
        agentId: lauraTemplateId,
      );
      final tom = makeTestTemplate(
        id: tomTemplateId,
        agentId: tomTemplateId,
      );
      final improver = makeTestTemplate(
        id: improverTemplateId,
        agentId: improverTemplateId,
      );
      final metaImprover = makeTestTemplate(
        id: metaImproverTemplateId,
        agentId: metaImproverTemplateId,
      );

      when(
        () => mockRepo.getEntity(lauraTemplateId),
      ).thenAnswer((_) async => laura);
      when(
        () => mockRepo.getEntity(tomTemplateId),
      ).thenAnswer((_) async => tom);
      when(
        () => mockRepo.getEntity(projectTemplateId),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepo.getEntity(improverTemplateId),
      ).thenAnswer((_) async => improver);
      when(
        () => mockRepo.getEntity(metaImproverTemplateId),
      ).thenAnswer((_) async => metaImprover);
      when(() => mockRepo.getAllTemplates()).thenAnswer((_) async => []);

      await service.seedDefaults();

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final template = captured.first as AgentTemplateEntity;

      expect(template.id, projectTemplateId);
      expect(template.kind, AgentTemplateKind.projectAgent);
      expect(template.displayName, 'Project Analyst');
      expect(captured, hasLength(3));
    });
  });

  group('seedDirectiveFields', () {
    glados.Glados(
      glados.any.seedDirectiveFieldsScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated directive field migration invariants', (
      scenario,
    ) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final templates = scenario.templateEntities;

      when(generatedRepository.getAllTemplates).thenAnswer(
        (_) async => templates,
      );
      when(
        () => generatedSync.upsertEntity(any()),
      ).thenAnswer((_) async {});
      for (final (index, template) in templates.indexed) {
        when(
          () => generatedRepository.getActiveTemplateVersion(template.id),
        ).thenAnswer((_) async {
          return scenario.templates[index].activeVersion(index);
        });
      }

      await generatedService.seedDirectiveFields();

      verify(generatedRepository.getAllTemplates).called(1);
      for (final template in templates) {
        verify(
          () => generatedRepository.getActiveTemplateVersion(template.id),
        ).called(1);
      }

      final expectedWrites = scenario.expectedWrites;
      if (expectedWrites.isEmpty) {
        verifyNever(() => generatedSync.upsertEntity(any()));
        return;
      }

      final writes = verify(
        () => generatedSync.upsertEntity(captureAny()),
      ).captured.cast<AgentTemplateVersionEntity>();
      expect(writes, hasLength(expectedWrites.length), reason: '$scenario');

      for (final (index, expected) in expectedWrites.indexed) {
        final actual = writes[index];
        expect(actual.id, expected.id, reason: '$scenario');
        expect(actual.agentId, expected.agentId, reason: '$scenario');
        expect(actual.directives, expected.directives, reason: '$scenario');
        expect(
          actual.generalDirective,
          expected.generalDirective,
          reason: '$scenario',
        );
        expect(
          actual.reportDirective,
          expected.reportDirective,
          reason: '$scenario',
        );
        expect(actual.status, expected.status, reason: '$scenario');
      }
    });

    test('seeds empty directive fields for task agent template', () async {
      final template = makeTestTemplate(
        id: 'tpl-task',
        agentId: 'tpl-task',
      );
      final version = makeTestTemplateVersion(
        id: 'v1',
        agentId: 'tpl-task',
        directives: 'Legacy directives',
      );

      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => [template]);
      when(
        () => mockRepo.getActiveTemplateVersion('tpl-task'),
      ).thenAnswer((_) async => version);

      await service.seedDirectiveFields();

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(captured, hasLength(1));
      final seeded = captured.first as AgentTemplateVersionEntity;
      expect(seeded.generalDirective, isNotEmpty);
      expect(seeded.reportDirective, isNotEmpty);
      // Legacy field is preserved unchanged.
      expect(seeded.directives, 'Legacy directives');
    });

    test('seeds empty directive fields for improver template', () async {
      final template = makeTestTemplate(
        id: 'tpl-imp',
        agentId: 'tpl-imp',
        kind: AgentTemplateKind.templateImprover,
      );
      final version = makeTestTemplateVersion(
        id: 'v1',
        agentId: 'tpl-imp',
        directives: 'Old improver directives',
      );

      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => [template]);
      when(
        () => mockRepo.getActiveTemplateVersion('tpl-imp'),
      ).thenAnswer((_) async => version);

      await service.seedDirectiveFields();

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(captured, hasLength(1));
      final seeded = captured.first as AgentTemplateVersionEntity;
      expect(seeded.generalDirective, isNotEmpty);
      // Template improver has empty report directive.
      expect(seeded.reportDirective, isEmpty);
    });

    test('seeds empty directive fields for project agent template', () async {
      final template = makeTestTemplate(
        id: 'tpl-project',
        agentId: 'tpl-project',
        kind: AgentTemplateKind.projectAgent,
      );
      final version = makeTestTemplateVersion(
        id: 'v-project',
        agentId: 'tpl-project',
        directives: 'Old project directives',
      );

      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => [template]);
      when(
        () => mockRepo.getActiveTemplateVersion('tpl-project'),
      ).thenAnswer((_) async => version);

      await service.seedDirectiveFields();

      final captured = verify(
        () => mockSync.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(captured, hasLength(1));
      final seeded = captured.first as AgentTemplateVersionEntity;
      expect(seeded.generalDirective, isNotEmpty);
      expect(seeded.reportDirective, isNotEmpty);
    });

    test(
      'skips versions that already have directive fields populated',
      () async {
        final template = makeTestTemplate(
          id: 'tpl-seeded',
          agentId: 'tpl-seeded',
        );
        final version = makeTestTemplateVersion(
          id: 'v1',
          agentId: 'tpl-seeded',
          generalDirective: 'Already set',
          reportDirective: 'Already set',
        );

        when(
          () => mockRepo.getAllTemplates(),
        ).thenAnswer((_) async => [template]);
        when(
          () => mockRepo.getActiveTemplateVersion('tpl-seeded'),
        ).thenAnswer((_) async => version);

        await service.seedDirectiveFields();

        verifyNever(() => mockSync.upsertEntity(any()));
      },
    );

    test('skips templates without active version', () async {
      final template = makeTestTemplate(
        id: 'tpl-no-ver',
        agentId: 'tpl-no-ver',
      );

      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => [template]);
      when(
        () => mockRepo.getActiveTemplateVersion('tpl-no-ver'),
      ).thenAnswer((_) async => null);

      await service.seedDirectiveFields();

      verifyNever(() => mockSync.upsertEntity(any()));
    });

    test('seeds multiple templates in a single pass', () async {
      final taskTemplate = makeTestTemplate(
        id: 'tpl-task',
        agentId: 'tpl-task',
      );
      final improverTemplate = makeTestTemplate(
        id: 'tpl-imp',
        agentId: 'tpl-imp',
        kind: AgentTemplateKind.templateImprover,
      );
      final taskVersion = makeTestTemplateVersion(
        id: 'v-task',
        agentId: 'tpl-task',
      );
      final improverVersion = makeTestTemplateVersion(
        id: 'v-imp',
        agentId: 'tpl-imp',
      );

      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => [taskTemplate, improverTemplate]);
      when(
        () => mockRepo.getActiveTemplateVersion('tpl-task'),
      ).thenAnswer((_) async => taskVersion);
      when(
        () => mockRepo.getActiveTemplateVersion('tpl-imp'),
      ).thenAnswer((_) async => improverVersion);

      await service.seedDirectiveFields();

      verify(() => mockSync.upsertEntity(any())).called(2);
    });
  });

  group('getVersionHistory', () {
    test('returns versions sorted by version number descending', () async {
      final v1 = makeTestTemplateVersion(id: 'v1');
      final v3 = makeTestTemplateVersion(id: 'v3', version: 3);
      final v2 = makeTestTemplateVersion(id: 'v2', version: 2);

      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
          limit: 100,
        ),
      ).thenAnswer((_) async => [v1, v3, v2]);

      final result = await service.getVersionHistory(kTestTemplateId);

      expect(result, hasLength(3));
      expect(result[0].version, 3);
      expect(result[1].version, 2);
      expect(result[2].version, 1);
    });

    test('returns empty list when no versions exist', () async {
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
          limit: 100,
        ),
      ).thenAnswer((_) async => []);

      final result = await service.getVersionHistory(kTestTemplateId);

      expect(result, isEmpty);
    });

    test('filters out non-version entity types', () async {
      final v1 = makeTestTemplateVersion(id: 'v1');
      final report = makeTestReport(id: 'r1');

      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: 'agentTemplateVersion',
          limit: 100,
        ),
      ).thenAnswer((_) async => [v1, report]);

      final result = await service.getVersionHistory(kTestTemplateId);

      expect(result, hasLength(1));
      expect(result[0].id, 'v1');
    });
  });

  group('computeMetrics', () {
    void stubAgentsForTemplate(List<AgentIdentityEntity> agents) {
      final links = agents
          .map(
            (a) => makeTestTemplateAssignmentLink(
              id: 'link-${a.id}',
              toId: a.id,
            ),
          )
          .toList();
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => links);
      for (final agent in agents) {
        when(() => mockRepo.getEntity(agent.id)).thenAnswer((_) async => agent);
      }
    }

    void stubAggregateMetrics({
      int successCount = 0,
      int failureCount = 0,
      int? durationSumMs,
      int durationCount = 0,
      DateTime? firstWakeAt,
      DateTime? lastWakeAt,
      int totalWakes = 0,
    }) {
      when(
        () => mockRepo.aggregateWakeRunMetrics(kTestTemplateId),
      ).thenAnswer(
        (_) async => AggregateWakeRunMetricsByTemplateIdResult(
          successCount: successCount,
          failureCount: failureCount,
          durationSumMs: durationSumMs,
          durationCount: durationCount,
          firstWakeAt: firstWakeAt,
          lastWakeAt: lastWakeAt,
        ),
      );
      when(
        () => mockRepo.countWakeRunsForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => totalWakes);
    }

    test('returns zeroed metrics when no runs exist', () async {
      stubAggregateMetrics();
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      expect(metrics.templateId, kTestTemplateId);
      expect(metrics.totalWakes, 0);
      expect(metrics.successCount, 0);
      expect(metrics.failureCount, 0);
      expect(metrics.successRate, 0.0);
      expect(metrics.averageDuration, isNull);
      expect(metrics.firstWakeAt, isNull);
      expect(metrics.lastWakeAt, isNull);
      expect(metrics.activeInstanceCount, 0);
    });

    test('computes counts and success rate from mixed statuses', () async {
      stubAggregateMetrics(
        successCount: 2,
        failureCount: 1,
        totalWakes: 4,
      );
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      expect(metrics.totalWakes, 4);
      expect(metrics.successCount, 2);
      expect(metrics.failureCount, 1);
      // 2 successes / 3 terminal (2 completed + 1 failed) — running excluded.
      expect(metrics.successRate, closeTo(2 / 3, 0.001));
    });

    test(
      'computes average duration from completed runs with timestamps',
      () async {
        // Two runs: 10s and 20s → average 15s = 15000ms total / 2
        stubAggregateMetrics(
          successCount: 3,
          totalWakes: 3,
          durationSumMs: 30000,
          durationCount: 2,
        );
        stubAgentsForTemplate([]);

        final metrics = await service.computeMetrics(kTestTemplateId);

        // Average of 10s and 20s = 15s.
        expect(metrics.averageDuration, const Duration(seconds: 15));
      },
    );

    test(
      'averageDuration is zero when durationSumMs is null but count > 0',
      () async {
        // Edge case: durationCount > 0 but durationSumMs is null (SQL NULL).
        // The ?? 0 fallback should produce Duration.zero, not crash.
        stubAggregateMetrics(
          successCount: 2,
          totalWakes: 2,
          // durationSumMs intentionally left null
          durationCount: 2,
        );
        stubAgentsForTemplate([]);

        final metrics = await service.computeMetrics(kTestTemplateId);

        expect(metrics.averageDuration, Duration.zero);
      },
    );

    test(
      'averageDuration is null when durationCount is zero with non-null sum',
      () async {
        // durationSumMs is non-null but durationCount is 0 → should skip average.
        stubAggregateMetrics(
          successCount: 1,
          totalWakes: 1,
          durationSumMs: 5000,
        );
        stubAgentsForTemplate([]);

        final metrics = await service.computeMetrics(kTestTemplateId);

        expect(metrics.averageDuration, isNull);
      },
    );

    test('firstWakeAt and lastWakeAt from SQL aggregation', () async {
      stubAggregateMetrics(
        successCount: 2,
        totalWakes: 2,
        firstWakeAt: DateTime(2024, 3, 10),
        lastWakeAt: DateTime(2024, 3, 20),
      );
      stubAgentsForTemplate([]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      expect(metrics.firstWakeAt, DateTime(2024, 3, 10));
      expect(metrics.lastWakeAt, DateTime(2024, 3, 20));
    });

    test('activeInstanceCount counts only active agents', () async {
      stubAggregateMetrics();
      stubAgentsForTemplate([
        makeTestIdentity(id: 'a1', agentId: 'a1'),
        makeTestIdentity(
          id: 'a2',
          agentId: 'a2',
          lifecycle: AgentLifecycle.destroyed,
        ),
        makeTestIdentity(
          id: 'a3',
          agentId: 'a3',
          lifecycle: AgentLifecycle.dormant,
        ),
        makeTestIdentity(id: 'a4', agentId: 'a4'),
      ]);

      final metrics = await service.computeMetrics(kTestTemplateId);

      // Only a1 and a4 are active; a2 is destroyed, a3 is dormant.
      expect(metrics.activeInstanceCount, 2);
    });
  });

  // ── Evolution data-fetching methods ──────────────────────────────────────

  group('getRecentInstanceReports', () {
    test('delegates to repository with default limit', () async {
      final reports = [makeTestReport(id: 'r1'), makeTestReport(id: 'r2')];
      when(
        () => mockRepo.getRecentReportsByTemplate(kTestTemplateId),
      ).thenAnswer((_) async => reports);

      final result = await service.getRecentInstanceReports(kTestTemplateId);

      expect(result, hasLength(2));
      verify(
        () => mockRepo.getRecentReportsByTemplate(kTestTemplateId),
      ).called(1);
    });

    test('passes custom limit to repository', () async {
      when(
        () => mockRepo.getRecentReportsByTemplate(kTestTemplateId, limit: 5),
      ).thenAnswer((_) async => []);

      await service.getRecentInstanceReports(kTestTemplateId, limit: 5);

      verify(
        () => mockRepo.getRecentReportsByTemplate(kTestTemplateId, limit: 5),
      ).called(1);
    });
  });

  group('getRecentInstanceObservations', () {
    test('delegates to repository with default limit', () async {
      final obs = [
        makeTestMessage(id: 'o1', kind: AgentMessageKind.observation),
      ];
      when(
        () => mockRepo.getRecentObservationsByTemplate(
          kTestTemplateId,
        ),
      ).thenAnswer((_) async => obs);

      final result = await service.getRecentInstanceObservations(
        kTestTemplateId,
      );

      expect(result, hasLength(1));
    });
  });

  group('getRecentEvolutionNotes', () {
    test('delegates to repository', () async {
      final notes = [
        makeTestEvolutionNote(id: 'n1'),
        makeTestEvolutionNote(id: 'n2', kind: EvolutionNoteKind.decision),
      ];
      when(
        () => mockRepo.getEvolutionNotes(kTestTemplateId),
      ).thenAnswer((_) async => notes);

      final result = await service.getRecentEvolutionNotes(kTestTemplateId);

      expect(result, hasLength(2));
      expect(result[0].id, 'n1');
      expect(result[1].kind, EvolutionNoteKind.decision);
    });
  });

  group('getEvolutionSessions', () {
    test('delegates to repository', () async {
      final sessions = [
        makeTestEvolutionSession(id: 's1'),
        makeTestEvolutionSession(
          id: 's2',
          status: EvolutionSessionStatus.completed,
        ),
      ];
      when(
        () => mockRepo.getEvolutionSessions(kTestTemplateId),
      ).thenAnswer((_) async => sessions);

      final result = await service.getEvolutionSessions(kTestTemplateId);

      expect(result, hasLength(2));
      expect(result[1].status, EvolutionSessionStatus.completed);
    });
  });

  group('countChangesSince', () {
    test('delegates to repository', () async {
      final since = DateTime(2026, 2, 20);
      when(
        () => mockRepo.countChangedSinceForTemplate(kTestTemplateId, since),
      ).thenAnswer((_) async => 42);

      final count = await service.countChangesSince(kTestTemplateId, since);

      expect(count, 42);
    });

    test('returns 0 for null since', () async {
      when(
        () => mockRepo.countChangedSinceForTemplate(kTestTemplateId, null),
      ).thenAnswer((_) async => 0);

      final count = await service.countChangesSince(kTestTemplateId, null);

      expect(count, 0);
    });
  });

  group('gatherEvolutionData', () {
    void stubGatherDependencies({
      List<AgentMessageEntity>? observations,
      List<EvolutionSessionEntity>? sessions,
    }) {
      final defaultObs = observations ?? <AgentMessageEntity>[];
      final defaultSessions = sessions ?? <EvolutionSessionEntity>[];

      when(
        () => mockRepo.aggregateWakeRunMetrics(kTestTemplateId),
      ).thenAnswer(
        (_) async => AggregateWakeRunMetricsByTemplateIdResult(
          successCount: 0,
          failureCount: 0,
          durationCount: 0,
        ),
      );
      when(
        () => mockRepo.countWakeRunsForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => 0);
      when(
        () => mockRepo.getLinksFrom(
          kTestTemplateId,
          type: 'template_assignment',
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getEntitiesByAgentId(
          kTestTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [makeTestTemplateVersion()]);
      when(
        () => mockRepo.getRecentReportsByTemplate(kTestTemplateId),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getRecentObservationsByTemplate(kTestTemplateId),
      ).thenAnswer((_) async => defaultObs);
      when(
        () => mockRepo.getEvolutionNotes(kTestTemplateId, limit: 30),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepo.getEvolutionSessions(kTestTemplateId),
      ).thenAnswer((_) async => defaultSessions);
      when(
        () => mockRepo.countChangedSinceForTemplate(
          kTestTemplateId,
          any(),
        ),
      ).thenAnswer((_) async => 0);
    }

    glados.Glados(
      glados.any.gatherEvolutionScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated bundle assembly invariants', (scenario) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final firstWakeAt = DateTime(2026, 3);
      final lastWakeAt = DateTime(2026, 3, 7);
      final assignmentLinks = [
        for (final (index, _) in scenario.agentSlots.indexed)
          makeTestTemplateAssignmentLink(
            id: 'generated-gather-agent-link-$index',
            fromId: _generatedTemplateId,
            toId: 'generated-gather-agent-link-$index',
          ),
      ];

      when(
        () => generatedRepository.aggregateWakeRunMetrics(
          _generatedTemplateId,
        ),
      ).thenAnswer(
        (_) async => AggregateWakeRunMetricsByTemplateIdResult(
          successCount: 4,
          failureCount: 2,
          durationSumMs: 18000,
          durationCount: 3,
          firstWakeAt: firstWakeAt,
          lastWakeAt: lastWakeAt,
        ),
      );
      when(
        () => generatedRepository.countWakeRunsForTemplate(
          _generatedTemplateId,
        ),
      ).thenAnswer((_) async => 12);
      when(
        () => generatedRepository.getLinksFrom(
          _generatedTemplateId,
          type: AgentLinkTypes.templateAssignment,
        ),
      ).thenAnswer((_) async => assignmentLinks);
      for (final (index, slot) in scenario.agentSlots.indexed) {
        when(
          () => generatedRepository.getEntity(
            'generated-gather-agent-link-$index',
          ),
        ).thenAnswer((_) async => slot.entity(index));
      }
      when(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: 5,
        ),
      ).thenAnswer((_) async => scenario.versionEntities);
      when(
        () => generatedRepository.getRecentReportsByTemplate(
          _generatedTemplateId,
        ),
      ).thenAnswer((_) async => scenario.reports);
      when(
        () => generatedRepository.getRecentObservationsByTemplate(
          _generatedTemplateId,
        ),
      ).thenAnswer((_) async => scenario.observations);
      when(
        () => generatedRepository.getEvolutionNotes(
          _generatedTemplateId,
          limit: 30,
        ),
      ).thenAnswer((_) async => scenario.notes);
      when(
        () => generatedRepository.getEvolutionSessions(_generatedTemplateId),
      ).thenAnswer((_) async => scenario.sessions);
      for (final slot in _GeneratedGatherPayloadSlot.values) {
        final contentEntryId = slot.contentEntryId;
        if (contentEntryId != null) {
          when(
            () => generatedRepository.getEntity(contentEntryId),
          ).thenAnswer((_) async => slot.lookupEntity);
        }
      }
      when(
        () => generatedRepository.countChangedSinceForTemplate(
          _generatedTemplateId,
          scenario.expectedSince,
        ),
      ).thenAnswer((_) async => scenario.changesSinceLastSession);

      final bundle = await generatedService.gatherEvolutionData(
        _generatedTemplateId,
      );

      expect(bundle.metrics.templateId, _generatedTemplateId);
      expect(bundle.metrics.totalWakes, 12);
      expect(bundle.metrics.successCount, 4);
      expect(bundle.metrics.failureCount, 2);
      expect(bundle.metrics.successRate, 4 / 6);
      expect(
        bundle.metrics.averageDuration,
        const Duration(milliseconds: 6000),
      );
      expect(bundle.metrics.firstWakeAt, firstWakeAt);
      expect(bundle.metrics.lastWakeAt, lastWakeAt);
      expect(
        bundle.metrics.activeInstanceCount,
        scenario.expectedActiveAgentCount,
        reason: '$scenario',
      );
      expect(
        bundle.recentVersions.map((version) => version.id).toList(),
        scenario.expectedRecentVersions.map((version) => version.id).toList(),
        reason: '$scenario',
      );
      expect(
        bundle.instanceReports.map((report) => report.id).toList(),
        scenario.reports.map((report) => report.id).toList(),
        reason: '$scenario',
      );
      expect(
        bundle.instanceObservations
            .map((observation) => observation.id)
            .toList(),
        scenario.observations.map((observation) => observation.id).toList(),
        reason: '$scenario',
      );
      expect(
        bundle.pastNotes.map((note) => note.id).toList(),
        scenario.notes.map((note) => note.id).toList(),
        reason: '$scenario',
      );
      expect(
        bundle.sessions.map((session) => session.id).toList(),
        scenario.sessions.map((session) => session.id).toList(),
        reason: '$scenario',
      );
      expect(
        bundle.observationPayloads.keys.toSet(),
        scenario.expectedPayloads.keys.toSet(),
        reason: '$scenario',
      );
      for (final entry in scenario.expectedPayloads.entries) {
        expect(
          bundle.observationPayloads[entry.key],
          entry.value,
          reason: '$scenario',
        );
      }
      expect(
        bundle.changesSinceLastSession,
        scenario.changesSinceLastSession,
        reason: '$scenario',
      );

      verify(
        () => generatedRepository.countChangedSinceForTemplate(
          _generatedTemplateId,
          scenario.expectedSince,
        ),
      ).called(1);
      verify(
        () => generatedRepository.getEntitiesByAgentId(
          _generatedTemplateId,
          type: AgentEntityTypes.agentTemplateVersion,
          limit: 5,
        ),
      ).called(1);
      for (final slot in _GeneratedGatherPayloadSlot.values) {
        final contentEntryId = slot.contentEntryId;
        if (contentEntryId == null) {
          continue;
        }
        final lookupCount = scenario.payloadLookupCounts[contentEntryId] ?? 0;
        if (lookupCount == 0) {
          verifyNever(() => generatedRepository.getEntity(contentEntryId));
        } else {
          verify(
            () => generatedRepository.getEntity(contentEntryId),
          ).called(lookupCount);
        }
      }
    });

    test('returns bundle with all fields populated', () async {
      final report = makeTestReport();
      final note = makeTestEvolutionNote();
      final session = makeTestEvolutionSession(
        createdAt: DateTime(2024, 3, 10),
      );

      stubGatherDependencies(sessions: [session]);
      // Override specific stubs for this test.
      when(
        () => mockRepo.getRecentReportsByTemplate(kTestTemplateId),
      ).thenAnswer((_) async => [report]);
      when(
        () => mockRepo.getEvolutionNotes(kTestTemplateId, limit: 30),
      ).thenAnswer((_) async => [note]);
      when(
        () => mockRepo.countChangedSinceForTemplate(
          kTestTemplateId,
          session.createdAt,
        ),
      ).thenAnswer((_) async => 7);

      final bundle = await service.gatherEvolutionData(kTestTemplateId);

      expect(bundle.instanceReports, hasLength(1));
      expect(bundle.pastNotes, hasLength(1));
      expect(bundle.sessions, hasLength(1));
      expect(bundle.recentVersions, hasLength(1));
      expect(bundle.changesSinceLastSession, 7);
    });

    test('uses null since when no sessions exist', () async {
      stubGatherDependencies();

      await service.gatherEvolutionData(kTestTemplateId);

      verify(
        () => mockRepo.countChangedSinceForTemplate(kTestTemplateId, null),
      ).called(1);
    });

    test('uses first session createdAt as since date', () async {
      final session = makeTestEvolutionSession(
        // ignore: avoid_redundant_argument_values
        createdAt: DateTime(2024, 6, 1),
      );
      stubGatherDependencies(sessions: [session]);

      await service.gatherEvolutionData(kTestTemplateId);

      verify(
        () => mockRepo.countChangedSinceForTemplate(
          kTestTemplateId,
          // ignore: avoid_redundant_argument_values
          DateTime(2024, 6, 1),
        ),
      ).called(1);
    });

    test(
      'resolves observation payloads for observations with contentEntryId',
      () async {
        final obs = makeTestMessage(
          id: 'obs-1',
          kind: AgentMessageKind.observation,
          contentEntryId: 'payload-abc',
        );
        final payload = makeTestMessagePayload(id: 'payload-abc');

        stubGatherDependencies(observations: [obs]);
        when(
          () => mockRepo.getEntity('payload-abc'),
        ).thenAnswer((_) async => payload);

        final bundle = await service.gatherEvolutionData(kTestTemplateId);

        expect(bundle.observationPayloads, hasLength(1));
        expect(bundle.observationPayloads['payload-abc'], isNotNull);
      },
    );

    test('skips observations without contentEntryId', () async {
      final obs = makeTestMessage(
        id: 'obs-no-payload',
        kind: AgentMessageKind.observation,
      );

      stubGatherDependencies(observations: [obs]);

      final bundle = await service.gatherEvolutionData(kTestTemplateId);

      expect(bundle.observationPayloads, isEmpty);
      verifyNever(() => mockRepo.getEntity('obs-no-payload'));
    });
  });

  group('EvolutionDataBundle', () {
    test('nextSessionNumber returns 1 when no sessions', () {
      final bundle = makeTestEvolutionDataBundle();
      expect(bundle.nextSessionNumber, 1);
    });

    test('nextSessionNumber returns max + 1', () {
      final bundle = makeTestEvolutionDataBundle(
        sessions: [
          makeTestEvolutionSession(id: 's1', sessionNumber: 3),
          makeTestEvolutionSession(id: 's2', sessionNumber: 7),
          makeTestEvolutionSession(id: 's3', sessionNumber: 5),
        ],
      );
      expect(bundle.nextSessionNumber, 8);
    });

    test('nextSessionNumber handles single session', () {
      final bundle = makeTestEvolutionDataBundle(
        sessions: [
          // ignore: avoid_redundant_argument_values
          makeTestEvolutionSession(id: 's1', sessionNumber: 1),
        ],
      );
      expect(bundle.nextSessionNumber, 2);
    });
  });

  group('profileInUse', () {
    const profileId = 'profile-abc';

    void stubNoTemplates() {
      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => <AgentTemplateEntity>[]);
      when(
        () => mockRepo.getAllAgentIdentities(),
      ).thenAnswer((_) async => <AgentIdentityEntity>[]);
    }

    glados.Glados(
      glados.any.profileInUseScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated profile reference invariants', (scenario) async {
      final generatedRepository = MockAgentRepository();
      final generatedSync = MockAgentSyncService();
      final generatedService = AgentTemplateService(
        repository: generatedRepository,
        syncService: generatedSync,
      );
      final templates = scenario.templateEntities;

      when(generatedRepository.getAllTemplates).thenAnswer(
        (_) async => templates,
      );
      for (final (index, template) in templates.indexed) {
        when(
          () => generatedRepository.getEntitiesByAgentId(
            template.id,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: 1000000,
          ),
        ).thenAnswer(
          (_) async => scenario.templates[index].versionEntities(index),
        );
      }
      when(generatedRepository.getAllAgentIdentities).thenAnswer(
        (_) async => scenario.agentEntities,
      );

      final result = await generatedService.profileInUse(
        _generatedTargetProfileId,
      );

      expect(result, scenario.expectedResult, reason: '$scenario');
      verify(generatedRepository.getAllTemplates).called(1);

      if (scenario.templateReferencesTarget) {
        for (final template in templates) {
          verifyNever(
            () => generatedRepository.getEntitiesByAgentId(
              template.id,
              type: AgentEntityTypes.agentTemplateVersion,
              limit: 1000000,
            ),
          );
        }
        verifyNever(generatedRepository.getAllAgentIdentities);
        return;
      }

      for (final template in templates) {
        verify(
          () => generatedRepository.getEntitiesByAgentId(
            template.id,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: 1000000,
          ),
        ).called(1);
      }

      if (scenario.versionReferencesTarget) {
        verifyNever(generatedRepository.getAllAgentIdentities);
      } else {
        verify(generatedRepository.getAllAgentIdentities).called(1);
      }
    });

    test('returns true when a template references the profile', () async {
      when(() => mockRepo.getAllTemplates()).thenAnswer(
        (_) async => [makeTestTemplate(profileId: profileId)],
      );

      final result = await service.profileInUse(profileId);

      expect(result, isTrue);
    });

    test(
      'returns true when a template version references the profile',
      () async {
        final template = makeTestTemplate();
        when(
          () => mockRepo.getAllTemplates(),
        ).thenAnswer((_) async => [template]);
        when(
          () => mockRepo.getAllAgentIdentities(),
        ).thenAnswer((_) async => <AgentIdentityEntity>[]);

        // Template itself doesn't reference the profile, but a version does.
        final version = makeTestTemplateVersion(profileId: profileId);
        when(
          () => mockRepo.getEntitiesByAgentId(
            template.id,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [version]);

        final result = await service.profileInUse(profileId);

        expect(result, isTrue);
      },
    );

    test('returns true when an agent config references the profile', () async {
      when(
        () => mockRepo.getAllTemplates(),
      ).thenAnswer((_) async => <AgentTemplateEntity>[]);

      final agent = makeTestIdentity(
        config: const AgentConfig(profileId: profileId),
      );
      when(
        () => mockRepo.getAllAgentIdentities(),
      ).thenAnswer((_) async => [agent]);

      final result = await service.profileInUse(profileId);

      expect(result, isTrue);
    });

    test('returns false when profile is not referenced anywhere', () async {
      stubNoTemplates();

      final result = await service.profileInUse(profileId);

      expect(result, isFalse);
    });

    test(
      'returns false when templates and agents use a different profile',
      () async {
        final template = makeTestTemplate(profileId: 'other-profile');
        when(
          () => mockRepo.getAllTemplates(),
        ).thenAnswer((_) async => [template]);
        when(
          () => mockRepo.getAllAgentIdentities(),
        ).thenAnswer((_) async => <AgentIdentityEntity>[]);
        // Stub version history lookup for the template.
        when(
          () => mockRepo.getEntitiesByAgentId(
            template.id,
            type: AgentEntityTypes.agentTemplateVersion,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => <AgentDomainEntity>[]);

        final result = await service.profileInUse(profileId);

        expect(result, isFalse);
      },
    );
  });
}
