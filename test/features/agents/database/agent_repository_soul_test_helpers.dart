import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';

enum GeneratedSoulSlot { target, other }

enum GeneratedSoulTemplateSlot { target, other }

const String hGeneratedSoulTargetId = 'generated-soul-target';
const String hGeneratedSoulOtherId = 'generated-soul-other';
const String hGeneratedSoulTargetTemplateId = 'generated-soul-template-target';
const String hGeneratedSoulOtherTemplateId = 'generated-soul-template-other';

class GeneratedSoulDocumentSpec {
  const GeneratedSoulDocumentSpec({
    required this.slot,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedSoulSlot slot;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String get id => switch (slot) {
    GeneratedSoulSlot.target => hGeneratedSoulTargetId,
    GeneratedSoulSlot.other => hGeneratedSoulOtherId,
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
    return 'GeneratedSoulDocumentSpec('
        'slot: $slot, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedSoulVersionSpec {
  const GeneratedSoulVersionSpec({
    required this.slot,
    required this.version,
    required this.status,
    required this.deleted,
    required this.createdMinuteOffset,
    required this.seed,
  });

  final GeneratedSoulSlot slot;
  final int version;
  final SoulDocumentVersionStatus status;
  final bool deleted;
  final int createdMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-soul-version-$index-$seed';

  String get soulId => switch (slot) {
    GeneratedSoulSlot.target => hGeneratedSoulTargetId,
    GeneratedSoulSlot.other => hGeneratedSoulOtherId,
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
    return 'GeneratedSoulVersionSpec('
        'slot: $slot, version: $version, status: $status, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset, '
        'seed: $seed)';
  }
}

class GeneratedSoulHeadSpec {
  const GeneratedSoulHeadSpec({
    required this.slot,
    required this.pointsToExisting,
    required this.versionOrdinal,
    required this.deleted,
    required this.updatedMinuteOffset,
    required this.seed,
  });

  final GeneratedSoulSlot slot;
  final bool pointsToExisting;
  final int versionOrdinal;
  final bool deleted;
  final int updatedMinuteOffset;
  final int seed;

  String idAt(int index) => 'generated-soul-head-$index-$seed';

  String get soulId => switch (slot) {
    GeneratedSoulSlot.target => hGeneratedSoulTargetId,
    GeneratedSoulSlot.other => hGeneratedSoulOtherId,
  };

  DateTime updatedAt(int index) {
    return DateTime(2026, 5, 13).add(
      Duration(minutes: updatedMinuteOffset, seconds: index),
    );
  }

  DateTime? deletedAt(int index) {
    return deleted ? updatedAt(index).add(const Duration(minutes: 1)) : null;
  }

  String versionIdFor(GeneratedSoulResolutionScenario scenario) {
    final indexes = scenario.targetVersionIndexes.toList();
    if (!pointsToExisting || indexes.isEmpty) {
      return 'generated-missing-soul-version-$seed';
    }

    final versionIndex = indexes[versionOrdinal % indexes.length];
    return scenario.versions[versionIndex].idAt(versionIndex);
  }

  @override
  String toString() {
    return 'GeneratedSoulHeadSpec('
        'slot: $slot, pointsToExisting: $pointsToExisting, '
        'versionOrdinal: $versionOrdinal, deleted: $deleted, '
        'updatedMinuteOffset: $updatedMinuteOffset, seed: $seed)';
  }
}

class GeneratedSoulAssignmentSpec {
  const GeneratedSoulAssignmentSpec({
    required this.templateSlot,
    required this.soulSlot,
    required this.deleted,
    required this.createdMinuteOffset,
  });

  final GeneratedSoulTemplateSlot templateSlot;
  final GeneratedSoulSlot soulSlot;
  final bool deleted;
  final int createdMinuteOffset;

  String get id =>
      'generated-soul-assignment-'
      '${templateSlot.name}-${soulSlot.name}';

  String get templateId => switch (templateSlot) {
    GeneratedSoulTemplateSlot.target => hGeneratedSoulTargetTemplateId,
    GeneratedSoulTemplateSlot.other => hGeneratedSoulOtherTemplateId,
  };

  String get soulId => switch (soulSlot) {
    GeneratedSoulSlot.target => hGeneratedSoulTargetId,
    GeneratedSoulSlot.other => hGeneratedSoulOtherId,
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
    return 'GeneratedSoulAssignmentSpec('
        'templateSlot: $templateSlot, soulSlot: $soulSlot, '
        'deleted: $deleted, createdMinuteOffset: $createdMinuteOffset)';
  }
}

class GeneratedSoulResolutionScenario {
  const GeneratedSoulResolutionScenario({
    required this.documents,
    required this.versions,
    required this.heads,
    required this.assignments,
    required this.versionLimit,
  });

  final List<GeneratedSoulDocumentSpec> documents;
  final List<GeneratedSoulVersionSpec> versions;
  final List<GeneratedSoulHeadSpec> heads;
  final List<GeneratedSoulAssignmentSpec> assignments;
  final int versionLimit;

  Iterable<int> get targetVersionIndexes sync* {
    for (var index = 0; index < versions.length; index++) {
      if (versions[index].slot == GeneratedSoulSlot.target) {
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
            if (heads[index].slot == GeneratedSoulSlot.target &&
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
        <GeneratedSoulSlot, GeneratedSoulDocumentSpec>{};
    for (final document in documents) {
      finalDocumentsBySlot[document.slot] = document;
    }
    return {
      for (final document in finalDocumentsBySlot.values)
        if (!document.deleted) document.id,
    };
  }

  String? get expectedTargetSoulDisplayName {
    GeneratedSoulDocumentSpec? target;
    for (final document in documents) {
      if (document.slot == GeneratedSoulSlot.target) {
        target = document;
      }
    }
    return target == null || target.deleted ? null : target.displayName;
  }

  GeneratedSoulAssignmentSpec? get expectedTargetTemplateAssignment {
    final activeByTemplate =
        <GeneratedSoulTemplateSlot, GeneratedSoulAssignmentSpec>{};
    for (final assignment in assignments) {
      if (assignment.deleted) {
        if (activeByTemplate[assignment.templateSlot]?.id == assignment.id) {
          activeByTemplate.remove(assignment.templateSlot);
        }
      } else {
        activeByTemplate[assignment.templateSlot] = assignment;
      }
    }
    return activeByTemplate[GeneratedSoulTemplateSlot.target];
  }

  Set<String> get expectedTargetSoulAssignmentIds {
    final activeByTemplate =
        <GeneratedSoulTemplateSlot, GeneratedSoulAssignmentSpec>{};
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
        if (assignment.soulSlot == GeneratedSoulSlot.target) assignment.id,
    };
  }

  @override
  String toString() {
    return 'GeneratedSoulResolutionScenario('
        'versionLimit: $versionLimit, documents: $documents, '
        'versions: $versions, heads: $heads, assignments: $assignments)';
  }
}

extension AnyGeneratedSoulResolutionScenario on glados.Any {
  glados.Generator<GeneratedSoulSlot> get soulSlot =>
      glados.AnyUtils(this).choose(GeneratedSoulSlot.values);

  glados.Generator<GeneratedSoulTemplateSlot> get soulTemplateSlot =>
      glados.AnyUtils(this).choose(GeneratedSoulTemplateSlot.values);

  glados.Generator<SoulDocumentVersionStatus> get soulVersionStatus =>
      glados.AnyUtils(this).choose(SoulDocumentVersionStatus.values);

  glados.Generator<GeneratedSoulDocumentSpec> get soulDocumentSpec =>
      glados.CombinableAny(this).combine4(
        soulSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedSoulSlot slot,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => GeneratedSoulDocumentSpec(
          slot: slot,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedSoulVersionSpec> get soulVersionSpec =>
      glados.CombinableAny(this).combine6(
        soulSlot,
        glados.IntAnys(this).intInRange(1, 8),
        soulVersionStatus,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedSoulSlot slot,
          int version,
          SoulDocumentVersionStatus status,
          bool deleted,
          int createdMinuteOffset,
          int seed,
        ) => GeneratedSoulVersionSpec(
          slot: slot,
          version: version,
          status: status,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedSoulHeadSpec> get soulHeadSpec =>
      glados.CombinableAny(this).combine6(
        soulSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 8),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          GeneratedSoulSlot slot,
          bool pointsToExisting,
          int versionOrdinal,
          bool deleted,
          int updatedMinuteOffset,
          int seed,
        ) => GeneratedSoulHeadSpec(
          slot: slot,
          pointsToExisting: pointsToExisting,
          versionOrdinal: versionOrdinal,
          deleted: deleted,
          updatedMinuteOffset: updatedMinuteOffset,
          seed: seed,
        ),
      );

  glados.Generator<GeneratedSoulAssignmentSpec> get soulAssignmentSpec =>
      glados.CombinableAny(this).combine4(
        soulTemplateSlot,
        soulSlot,
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(-4, 4),
        (
          GeneratedSoulTemplateSlot templateSlot,
          GeneratedSoulSlot soulSlot,
          bool deleted,
          int createdMinuteOffset,
        ) => GeneratedSoulAssignmentSpec(
          templateSlot: templateSlot,
          soulSlot: soulSlot,
          deleted: deleted,
          createdMinuteOffset: createdMinuteOffset,
        ),
      );

  glados.Generator<GeneratedSoulResolutionScenario>
  get soulResolutionScenario => glados.CombinableAny(this).combine5(
    glados.ListAnys(this).listWithLengthInRange(0, 6, soulDocumentSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 8, soulVersionSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 5, soulHeadSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 6, soulAssignmentSpec),
    glados.IntAnys(this).intInRange(1, 4),
    (
      List<GeneratedSoulDocumentSpec> documents,
      List<GeneratedSoulVersionSpec> versions,
      List<GeneratedSoulHeadSpec> heads,
      List<GeneratedSoulAssignmentSpec> assignments,
      int versionLimit,
    ) => GeneratedSoulResolutionScenario(
      documents: documents,
      versions: versions,
      heads: heads,
      assignments: assignments,
      versionLimit: versionLimit,
    ),
  );
}
