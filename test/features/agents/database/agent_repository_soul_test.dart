import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

enum _GeneratedSoulSlot { target, other }

enum _GeneratedSoulTemplateSlot { target, other }

const String _generatedSoulTargetId = 'generated-soul-target';
const String _generatedSoulOtherId = 'generated-soul-other';
const String _generatedSoulTargetTemplateId = 'generated-soul-template-target';
const String _generatedSoulOtherTemplateId = 'generated-soul-template-other';

class _GeneratedSoulDocumentSpec {
  const _GeneratedSoulDocumentSpec({
    required this.slot,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final _GeneratedSoulSlot slot;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String get id => switch (slot) {
    _GeneratedSoulSlot.target => _generatedSoulTargetId,
    _GeneratedSoulSlot.other => _generatedSoulOtherId,
  };

  String get displayName => 'Generated soul ${slot.name} $seed';

  DateTime get createdAt => DateTime(2026, 5, 11);

  DateTime get updatedAt {
    return DateTime(2026, 5, 11).add(
      Duration(minutes: updatedMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? updatedAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return '_GeneratedSoulDocumentSpec('
        'slot: $slot, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class _GeneratedSoulVersionSpec {
  const _GeneratedSoulVersionSpec({
    required this.slot,
    required this.version,
    required this.status,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final _GeneratedSoulSlot slot;
  final int version;
  final SoulDocumentVersionStatus status;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-soul-version-$index-$seed';

  String get soulId => switch (slot) {
    _GeneratedSoulSlot.target => _generatedSoulTargetId,
    _GeneratedSoulSlot.other => _generatedSoulOtherId,
  };

  DateTime createdAt(int index) {
    return DateTime(2026, 5, 12).add(
      Duration(minutes: createdMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? createdAt(index).add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return '_GeneratedSoulVersionSpec('
        'slot: $slot, version: $version, status: $status, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class _GeneratedSoulHeadSpec {
  const _GeneratedSoulHeadSpec({
    required this.slot,
    required this.pointsToExisting,
    required this.versionOrdinal,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final _GeneratedSoulSlot slot;
  final bool pointsToExisting;
  final int versionOrdinal;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-soul-head-$index-$seed';

  String get soulId => switch (slot) {
    _GeneratedSoulSlot.target => _generatedSoulTargetId,
    _GeneratedSoulSlot.other => _generatedSoulOtherId,
  };

  DateTime updatedAt(int index) {
    return DateTime(2026, 5, 13).add(
      Duration(minutes: updatedMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;
  }

  String versionIdFor(_GeneratedSoulResolutionScenario scenario) {
    final indexes = scenario.targetVersionIndexes.toList();
    if (!pointsToExisting || indexes.isEmpty) {
      return 'generated-missing-soul-version-$seed';
    }

    final versionIndex = indexes[versionOrdinal % indexes.length];
    return scenario.versions[versionIndex].idAt(versionIndex);
  }

  @override
  String toString() {
    return '_GeneratedSoulHeadSpec('
        'slot: $slot, pointsToExisting: $pointsToExisting, '
        'versionOrdinal: $versionOrdinal, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class _GeneratedSoulAssignmentSpec {
  const _GeneratedSoulAssignmentSpec({
    required this.templateSlot,
    required this.soulSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final _GeneratedSoulTemplateSlot templateSlot;
  final _GeneratedSoulSlot soulSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-soul-assignment-'
      '${templateSlot.name}-${soulSlot.name}';

  String get templateId => switch (templateSlot) {
    _GeneratedSoulTemplateSlot.target => _generatedSoulTargetTemplateId,
    _GeneratedSoulTemplateSlot.other => _generatedSoulOtherTemplateId,
  };

  String get soulId => switch (soulSlot) {
    _GeneratedSoulSlot.target => _generatedSoulTargetId,
    _GeneratedSoulSlot.other => _generatedSoulOtherId,
  };

  DateTime get createdAt {
    return DateTime(2026, 5, 14).add(
      Duration(minutes: createdMinuteOffset),
    );
  }

  DateTime? get deletedAt {
    return deleted ? createdAt.add(const Duration(minutes: 1)) : null;
  }

  @override
  String toString() {
    return '_GeneratedSoulAssignmentSpec('
        'templateSlot: $templateSlot, soulSlot: $soulSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class _GeneratedSoulResolutionScenario {
  const _GeneratedSoulResolutionScenario({
    required this.documents,
    required this.versions,
    required this.heads,
    required this.assignments,
    required this.versionLimit,
  });

  final List<_GeneratedSoulDocumentSpec> documents;
  final List<_GeneratedSoulVersionSpec> versions;
  final List<_GeneratedSoulHeadSpec> heads;
  final List<_GeneratedSoulAssignmentSpec> assignments;
  final int versionLimit;

  Iterable<int> get targetVersionIndexes sync* {
    for (var index = 0; index < versions.length; index++) {
      if (versions[index].slot == _GeneratedSoulSlot.target) {
        yield index;
      }
    }
  }

  Iterable<int> get nonDeletedTargetVersionIndexes {
    return targetVersionIndexes.where((index) => !versions[index].deleted);
  }

  int? get expectedTargetHeadIndex {
    final indexes =
        [
          for (var index = 0; index < heads.length; index++)
            if (heads[index].slot == _GeneratedSoulSlot.target &&
                !heads[index].deleted)
              index,
        ]..sort(
          (a, b) => heads[b].updatedAt(b).compareTo(heads[a].updatedAt(a)),
        );
    return indexes.isEmpty ? null : indexes.first;
  }

  String? get expectedTargetHeadId {
    final index = expectedTargetHeadIndex;
    return index == null ? null : heads[index].idAt(index);
  }

  String? get expectedTargetHeadVersionId {
    final index = expectedTargetHeadIndex;
    return index == null ? null : heads[index].versionIdFor(this);
  }

  String? get expectedActiveVersionId {
    final versionId = expectedTargetHeadVersionId;
    if (versionId == null) return null;
    for (final index in nonDeletedTargetVersionIndexes) {
      if (versions[index].idAt(index) == versionId) {
        return versionId;
      }
    }
    return null;
  }

  SoulDocumentVersionStatus? get expectedActiveVersionStatus {
    final versionId = expectedActiveVersionId;
    if (versionId == null) return null;
    for (final index in nonDeletedTargetVersionIndexes) {
      if (versions[index].idAt(index) == versionId) {
        return versions[index].status;
      }
    }
    return null;
  }

  List<String> expectedVersionIds({required int limit}) {
    final indexes = nonDeletedTargetVersionIndexes.toList()
      ..sort(
        (a, b) => versions[b].createdAt(b).compareTo(versions[a].createdAt(a)),
      );
    return indexes
        .take(limit)
        .map((index) => versions[index].idAt(index))
        .toList();
  }

  int get expectedNextVersionNumber {
    final versionNumbers = nonDeletedTargetVersionIndexes.map(
      (index) => versions[index].version,
    );
    if (versionNumbers.isEmpty) return 1;
    return versionNumbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  Set<String> get expectedAllSoulDocumentIds {
    final finalDocumentsBySlot =
        <_GeneratedSoulSlot, _GeneratedSoulDocumentSpec>{};
    for (final document in documents) {
      finalDocumentsBySlot[document.slot] = document;
    }
    return {
      for (final document in finalDocumentsBySlot.values)
        if (!document.deleted) document.id,
    };
  }

  String? get expectedTargetSoulDisplayName {
    _GeneratedSoulDocumentSpec? target;
    for (final document in documents) {
      if (document.slot == _GeneratedSoulSlot.target) {
        target = document;
      }
    }
    return target == null || target.deleted ? null : target.displayName;
  }

  _GeneratedSoulAssignmentSpec? get expectedTargetTemplateAssignment {
    final activeByTemplate =
        <_GeneratedSoulTemplateSlot, _GeneratedSoulAssignmentSpec>{};
    for (final assignment in assignments) {
      if (assignment.deleted) {
        if (activeByTemplate[assignment.templateSlot]?.id == assignment.id) {
          activeByTemplate.remove(assignment.templateSlot);
        }
      } else {
        activeByTemplate[assignment.templateSlot] = assignment;
      }
    }
    return activeByTemplate[_GeneratedSoulTemplateSlot.target];
  }

  Set<String> get expectedTargetSoulAssignmentIds {
    final activeByTemplate =
        <_GeneratedSoulTemplateSlot, _GeneratedSoulAssignmentSpec>{};
    for (final assignment in assignments) {
      if (assignment.deleted) {
        if (activeByTemplate[assignment.templateSlot]?.id == assignment.id) {
          activeByTemplate.remove(assignment.templateSlot);
        }
      } else {
        activeByTemplate[assignment.templateSlot] = assignment;
      }
    }
    return {
      for (final assignment in activeByTemplate.values)
        if (assignment.soulSlot == _GeneratedSoulSlot.target) assignment.id,
    };
  }

  @override
  String toString() {
    return '_GeneratedSoulResolutionScenario('
        'versionLimit: $versionLimit, documents: $documents, '
        'versions: $versions, heads: $heads, assignments: $assignments)';
  }
}

extension _AnyGeneratedSoulResolutionScenario on glados.Any {
  glados.Generator<_GeneratedSoulSlot> get soulSlot =>
      glados.AnyUtils(this).choose(_GeneratedSoulSlot.values);

  glados.Generator<_GeneratedSoulTemplateSlot> get soulTemplateSlot =>
      glados.AnyUtils(this).choose(_GeneratedSoulTemplateSlot.values);

  glados.Generator<SoulDocumentVersionStatus> get soulVersionStatus =>
      glados.AnyUtils(this).choose(SoulDocumentVersionStatus.values);

  glados.Generator<_GeneratedSoulDocumentSpec> get soulDocumentSpec =>
      glados.CombinableAny(this).combine4(
        soulSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedSoulSlot slot,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => _GeneratedSoulDocumentSpec(
          slot: slot,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedSoulVersionSpec> get soulVersionSpec =>
      glados.CombinableAny(this).combine6(
        soulSlot,
        glados.IntAnys(this).intInRange(1, 8),
        soulVersionStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedSoulSlot slot,
          int version,
          SoulDocumentVersionStatus status,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => _GeneratedSoulVersionSpec(
          slot: slot,
          version: version,
          status: status,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedSoulHeadSpec> get soulHeadSpec =>
      glados.CombinableAny(this).combine6(
        soulSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 8),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedSoulSlot slot,
          bool pointsToExisting,
          int versionOrdinal,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => _GeneratedSoulHeadSpec(
          slot: slot,
          pointsToExisting: pointsToExisting,
          versionOrdinal: versionOrdinal,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedSoulAssignmentSpec> get soulAssignmentSpec =>
      glados.CombinableAny(this).combine4(
        soulTemplateSlot,
        soulSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        (
          _GeneratedSoulTemplateSlot templateSlot,
          _GeneratedSoulSlot soulSlot,
          bool deleted,
          int createdMinuteOffset,
        ) => _GeneratedSoulAssignmentSpec(
          templateSlot: templateSlot,
          soulSlot: soulSlot,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
        ),
      );

  glados.Generator<_GeneratedSoulResolutionScenario>
  get soulResolutionScenario => glados.CombinableAny(this).combine5(
    glados.ListAnys(this).listWithLengthInRange(0, 6, soulDocumentSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 8, soulVersionSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 5, soulHeadSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 6, soulAssignmentSpec),
    glados.IntAnys(this).intInRange(1, 4),
    (
      List<_GeneratedSoulDocumentSpec> documents,
      List<_GeneratedSoulVersionSpec> versions,
      List<_GeneratedSoulHeadSpec> heads,
      List<_GeneratedSoulAssignmentSpec> assignments,
      int versionLimit,
    ) => _GeneratedSoulResolutionScenario(
      documents: documents,
      versions: versions,
      heads: heads,
      assignments: assignments,
      versionLimit: versionLimit,
    ),
  );
}

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  final testDate = DateTime(2026, 4, 5);
  const soulId = 'soul-001';
  const soulId2 = 'soul-002';

  SoulDocumentEntity makeSoul({
    String id = soulId,
    String displayName = 'Laura',
  }) =>
      AgentDomainEntity.soulDocument(
            id: id,
            agentId: id,
            displayName: displayName,
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as SoulDocumentEntity;

  SoulDocumentVersionEntity makeVersion({
    String id = 'sv-001',
    String agentId = soulId,
    int version = 1,
    SoulDocumentVersionStatus status = SoulDocumentVersionStatus.active,
    String voiceDirective = 'Be warm.',
  }) =>
      AgentDomainEntity.soulDocumentVersion(
            id: id,
            agentId: agentId,
            version: version,
            status: status,
            authoredBy: 'system',
            createdAt: testDate,
            vectorClock: null,
            voiceDirective: voiceDirective,
          )
          as SoulDocumentVersionEntity;

  SoulDocumentHeadEntity makeHead({
    String id = 'sh-001',
    String agentId = soulId,
    String versionId = 'sv-001',
  }) =>
      AgentDomainEntity.soulDocumentHead(
            id: id,
            agentId: agentId,
            versionId: versionId,
            updatedAt: testDate,
            vectorClock: null,
          )
          as SoulDocumentHeadEntity;

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getSoulDocument', () {
    test('returns soul when it exists', () async {
      await repo.upsertEntity(makeSoul());

      final result = await repo.getSoulDocument(soulId);
      expect(result, isNotNull);
      expect(result!.displayName, 'Laura');
    });

    test('returns null when not found', () async {
      final result = await repo.getSoulDocument('nonexistent');
      expect(result, isNull);
    });
  });

  group('getAllSoulDocuments', () {
    test('returns all soul documents', () async {
      await repo.upsertEntity(makeSoul());
      await repo.upsertEntity(makeSoul(id: soulId2, displayName: 'Max'));

      final result = await repo.getAllSoulDocuments();
      expect(result, hasLength(2));
      expect(result.map((s) => s.displayName), containsAll(['Laura', 'Max']));
    });

    test('excludes soft-deleted souls', () async {
      await repo.upsertEntity(makeSoul());
      await repo.upsertEntity(
        makeSoul(id: soulId2, displayName: 'Deleted').copyWith(
          deletedAt: testDate,
        ),
      );

      final result = await repo.getAllSoulDocuments();
      expect(result, hasLength(1));
      expect(result.first.displayName, 'Laura');
    });
  });

  group('getSoulDocumentHead', () {
    test('returns head when it exists', () async {
      await repo.upsertEntity(makeHead());

      final result = await repo.getSoulDocumentHead(soulId);
      expect(result, isNotNull);
      expect(result!.versionId, 'sv-001');
    });

    test('returns null when not found', () async {
      final result = await repo.getSoulDocumentHead('nonexistent');
      expect(result, isNull);
    });
  });

  group('getActiveSoulDocumentVersion', () {
    test('resolves head → version chain', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(makeHead());

      final result = await repo.getActiveSoulDocumentVersion(soulId);
      expect(result, isNotNull);
      expect(result!.voiceDirective, 'Be warm.');
    });

    test('returns null when head missing', () async {
      await repo.upsertEntity(makeVersion());
      // No head inserted.

      final result = await repo.getActiveSoulDocumentVersion(soulId);
      expect(result, isNull);
    });
  });

  group('getSoulDocumentVersions', () {
    test('returns versions newest first', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(
        makeVersion(
          id: 'sv-002',
          version: 2,
          voiceDirective: 'Be terse.',
        ).copyWith(
          createdAt: testDate.add(const Duration(hours: 1)),
        ),
      );

      final result = await repo.getSoulDocumentVersions(soulId);
      expect(result, hasLength(2));
      // Newest first.
      expect(result.first.version, 2);
      expect(result.last.version, 1);
    });

    test('respects limit', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(
        makeVersion(id: 'sv-002', version: 2).copyWith(
          createdAt: testDate.add(const Duration(hours: 1)),
        ),
      );

      final result = await repo.getSoulDocumentVersions(soulId, limit: 1);
      expect(result, hasLength(1));
    });
  });

  group('getNextSoulDocumentVersionNumber', () {
    test('returns 1 when no versions exist', () async {
      final result = await repo.getNextSoulDocumentVersionNumber(soulId);
      expect(result, 1);
    });

    test('returns max + 1', () async {
      await repo.upsertEntity(makeVersion());
      await repo.upsertEntity(makeVersion(id: 'sv-002', version: 2));

      final result = await repo.getNextSoulDocumentVersionNumber(soulId);
      expect(result, 3);
    });
  });

  glados.Glados(
    glados.any.soulResolutionScenario,
    glados.ExploreConfig(numRuns: 80),
  ).test(
    'matches generated soul document resolution semantics',
    (scenario) async {
      final localDb = AgentDatabase(inMemoryDatabase: true, background: false);
      final localRepo = AgentRepository(localDb);

      try {
        for (final document in scenario.documents) {
          await localRepo.upsertEntity(
            AgentDomainEntity.soulDocument(
              id: document.id,
              agentId: document.id,
              displayName: document.displayName,
              createdAt: document.createdAt,
              updatedAt: document.updatedAt,
              vectorClock: null,
              deletedAt: document.deletedAt,
            ),
          );
        }

        for (var index = 0; index < scenario.versions.length; index++) {
          final version = scenario.versions[index];
          await localRepo.upsertEntity(
            AgentDomainEntity.soulDocumentVersion(
              id: version.idAt(index),
              agentId: version.soulId,
              version: version.version,
              status: version.status,
              authoredBy: 'generated',
              createdAt: version.createdAt(index),
              vectorClock: null,
              voiceDirective: 'generated voice $index',
              deletedAt: version.deletedAt(index),
            ),
          );
        }

        for (var index = 0; index < scenario.heads.length; index++) {
          final head = scenario.heads[index];
          await localRepo.upsertEntity(
            AgentDomainEntity.soulDocumentHead(
              id: head.idAt(index),
              agentId: head.soulId,
              versionId: head.versionIdFor(scenario),
              updatedAt: head.updatedAt(index),
              vectorClock: null,
              deletedAt: head.deletedAt(index),
            ),
          );
        }

        for (final assignment in scenario.assignments) {
          await localRepo.upsertLink(
            model.AgentLink.soulAssignment(
              id: assignment.id,
              fromId: assignment.templateId,
              toId: assignment.soulId,
              createdAt: assignment.createdAt,
              updatedAt: assignment.createdAt,
              vectorClock: null,
              deletedAt: assignment.deletedAt,
            ),
          );
        }

        final allSouls = await localRepo.getAllSoulDocuments();
        expect(
          allSouls.map((soul) => soul.id).toSet(),
          scenario.expectedAllSoulDocumentIds,
          reason: '$scenario',
        );

        final targetSoul = await localRepo.getSoulDocument(
          _generatedSoulTargetId,
        );
        expect(
          targetSoul?.displayName,
          scenario.expectedTargetSoulDisplayName,
          reason: '$scenario',
        );

        final head = await localRepo.getSoulDocumentHead(
          _generatedSoulTargetId,
        );
        expect(
          head?.id,
          scenario.expectedTargetHeadId,
          reason: '$scenario',
        );
        expect(
          head?.versionId,
          scenario.expectedTargetHeadVersionId,
          reason: '$scenario',
        );

        final activeVersion = await localRepo.getActiveSoulDocumentVersion(
          _generatedSoulTargetId,
        );
        expect(
          activeVersion?.id,
          scenario.expectedActiveVersionId,
          reason: '$scenario',
        );
        expect(
          activeVersion?.status,
          scenario.expectedActiveVersionStatus,
          reason: '$scenario',
        );

        final versions = await localRepo.getSoulDocumentVersions(
          _generatedSoulTargetId,
          limit: scenario.versionLimit,
        );
        expect(
          versions.map((version) => version.id).toList(),
          scenario.expectedVersionIds(limit: scenario.versionLimit),
          reason: '$scenario',
        );

        final nextVersion = await localRepo.getNextSoulDocumentVersionNumber(
          _generatedSoulTargetId,
        );
        expect(
          nextVersion,
          scenario.expectedNextVersionNumber,
          reason: '$scenario',
        );

        final targetTemplateLinks = await localRepo.getLinksFrom(
          _generatedSoulTargetTemplateId,
          type: AgentLinkTypes.soulAssignment,
        );
        final expectedTemplateAssignment =
            scenario.expectedTargetTemplateAssignment;
        expect(
          targetTemplateLinks.map((link) => link.id).toSet(),
          expectedTemplateAssignment == null
              ? isEmpty
              : {expectedTemplateAssignment.id},
          reason: '$scenario',
        );
        if (expectedTemplateAssignment != null) {
          expect(
            targetTemplateLinks.single.toId,
            expectedTemplateAssignment.soulId,
            reason: '$scenario',
          );
        }

        final targetSoulLinks = await localRepo.getLinksTo(
          _generatedSoulTargetId,
          type: AgentLinkTypes.soulAssignment,
        );
        expect(
          targetSoulLinks.map((link) => link.id).toSet(),
          scenario.expectedTargetSoulAssignmentIds,
          reason: '$scenario',
        );
      } finally {
        await localDb.close();
      }
    },
    tags: 'glados',
  );

  group('soul assignment link queries', () {
    test('getLinksFrom returns soul assignment links', () async {
      final link = model.AgentLink.soulAssignment(
        id: 'link-sa-001',
        fromId: 'tpl-001',
        toId: soulId,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );
      await repo.upsertLink(link);

      final result = await repo.getLinksFrom(
        'tpl-001',
        type: AgentLinkTypes.soulAssignment,
      );
      expect(result, hasLength(1));
      expect(result.first, isA<model.SoulAssignmentLink>());
      expect(result.first.toId, soulId);
    });

    test('getLinksTo returns reverse soul assignment links', () async {
      final link = model.AgentLink.soulAssignment(
        id: 'link-sa-002',
        fromId: 'tpl-001',
        toId: soulId,
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );
      await repo.upsertLink(link);

      final result = await repo.getLinksTo(
        soulId,
        type: AgentLinkTypes.soulAssignment,
      );
      expect(result, hasLength(1));
      expect(result.first.fromId, 'tpl-001');
    });

    test(
      'upsertLink succeeds when an existing soul_assignment row has the '
      'exact same natural key (from_id, to_id, type) but a different id '
      '— the global UNIQUE(from_id,to_id,type) constraint applies to '
      'all rows including soft-deleted ones, so the handoff path must '
      'free the slot before the INSERT',
      () async {
        final original = model.AgentLink.soulAssignment(
          id: 'link-sa-original',
          fromId: 'tpl-001',
          toId: soulId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.upsertLink(original);

        final replacement = model.AgentLink.soulAssignment(
          id: 'link-sa-replacement',
          fromId: 'tpl-001',
          toId: soulId,
          createdAt: testDate.add(const Duration(minutes: 1)),
          updatedAt: testDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );

        // Before the fix this threw SqliteException(2067) because the
        // soft-delete of the original only set deleted_at; the row still
        // occupied the global UNIQUE slot so INSERT of the replacement
        // blew up before the ON CONFLICT(id) upsert could run.
        await repo.upsertLink(replacement);

        final active = await repo.getLinksFrom(
          'tpl-001',
          type: AgentLinkTypes.soulAssignment,
        );
        expect(active, hasLength(1));
        expect(active.first.id, 'link-sa-replacement');
      },
    );

    test(
      'upsertLink succeeds when an existing improver_target row has the '
      'exact same natural key — symmetric to the soul_assignment case',
      () async {
        final original = model.AgentLink.improverTarget(
          id: 'link-it-original',
          fromId: 'tpl-001',
          toId: 'improver-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.upsertLink(original);

        final replacement = model.AgentLink.improverTarget(
          id: 'link-it-replacement',
          fromId: 'tpl-001',
          toId: 'improver-001',
          createdAt: testDate.add(const Duration(minutes: 1)),
          updatedAt: testDate.add(const Duration(minutes: 1)),
          vectorClock: null,
        );

        await repo.upsertLink(replacement);

        final active = await repo.getLinksTo(
          'improver-001',
          type: AgentLinkTypes.improverTarget,
        );
        expect(active, hasLength(1));
        expect(active.first.id, 'link-it-replacement');
      },
    );
  });
}
