import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  group('JournalEntity.project', () {
    late ProjectEntry projectEntry;

    setUp(() {
      projectEntry = ProjectEntry(
        meta: Metadata(
          id: 'project-001',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          categoryId: 'cat-engineering',
        ),
        data: ProjectData(
          title: 'Device Synchronization',
          status: ProjectStatus.active(
            id: 'status-1',
            createdAt: testDate,
            utcOffset: 60,
          ),
          dateFrom: testDate,
          dateTo: testDate,
          targetDate: DateTime(2024, 6, 30),
        ),
      );
    });

    test('round-trip JSON serialization preserves all fields', () {
      final json = jsonDecode(jsonEncode(projectEntry)) as Map<String, dynamic>;
      final restored = JournalEntity.fromJson(json);

      expect(restored, isA<ProjectEntry>());
      final restoredProject = restored as ProjectEntry;
      expect(restoredProject.meta.id, 'project-001');
      expect(restoredProject.data.title, 'Device Synchronization');
      expect(restoredProject.data.status, isA<ProjectActive>());
      expect(restoredProject.data.targetDate, DateTime(2024, 6, 30));
    });

    test('toDbEntity produces correct type and category', () {
      final dbEntity = toDbEntity(projectEntry);

      expect(dbEntity.id, 'project-001');
      expect(dbEntity.type, 'Project');
      expect(dbEntity.category, 'cat-engineering');
      expect(dbEntity.deleted, false);
    });

    test('fromDbEntity round-trips correctly', () {
      final dbEntity = toDbEntity(projectEntry);
      final restored = fromDbEntity(dbEntity);

      expect(restored, isA<ProjectEntry>());
      final restoredProject = restored as ProjectEntry;
      expect(restoredProject.meta.id, 'project-001');
      expect(restoredProject.data.title, 'Device Synchronization');
    });

    test('id and categoryId extension accessors work', () {
      final entity = projectEntry as JournalEntity;
      expect(entity.id, 'project-001');
      expect(entity.categoryId, 'cat-engineering');
      expect(entity.isDeleted, false);
    });

    test('affectedIds includes project notification token', () {
      final entity = projectEntry as JournalEntity;
      expect(entity.affectedIds, contains('project-001'));
      expect(entity.affectedIds, contains('PROJECT'));
    });

    glados.Glados(
      glados.any.generatedProjectEntry,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'round-trips generated project entries through JSON and DB rows',
      (
        scenario,
      ) {
        final projectEntry = scenario.projectEntry;

        final jsonRestored = JournalEntity.fromJson(
          jsonDecode(jsonEncode(projectEntry.toJson())) as Map<String, dynamic>,
        );
        final dbEntity = toDbEntity(projectEntry);
        final dbRestored = fromDbEntity(dbEntity);

        expect(jsonRestored, equals(projectEntry), reason: '$scenario');
        expect(dbRestored, equals(projectEntry), reason: '$scenario');
        expect(dbEntity.id, projectEntry.meta.id, reason: '$scenario');
        expect(dbEntity.type, 'Project', reason: '$scenario');
        expect(
          dbEntity.category,
          projectEntry.meta.categoryId ?? '',
          reason: '$scenario',
        );
        expect(
          dbEntity.deleted,
          projectEntry.meta.deletedAt != null,
          reason: '$scenario',
        );
        expect(projectEntry.affectedIds, contains(projectEntry.meta.id));
        expect(projectEntry.affectedIds, contains('PROJECT'));
      },
      tags: 'glados',
    );
  });

  group('EntryLink.project', () {
    test('round-trip JSON serialization', () {
      final link = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      final json = jsonDecode(jsonEncode(link)) as Map<String, dynamic>;
      final restored = EntryLink.fromJson(json);

      expect(restored, isA<ProjectLink>());
      final restoredLink = restored as ProjectLink;
      expect(restoredLink.id, 'link-001');
      expect(restoredLink.fromId, 'project-001');
      expect(restoredLink.toId, 'task-001');
    });

    test('linkedDbEntity produces correct type', () {
      final link = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      final dbLink = linkedDbEntity(link);
      expect(dbLink.type, 'ProjectLink');
      expect(dbLink.fromId, 'project-001');
      expect(dbLink.toId, 'task-001');
    });

    test('entryLinkFromLinkedDbEntry round-trips ProjectLink', () {
      final link = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      final dbLink = linkedDbEntity(link);
      final restored = entryLinkFromLinkedDbEntry(dbLink);

      expect(restored, isA<ProjectLink>());
      expect(restored.id, 'link-001');
    });

    test('fallbackUnion deserializes unknown link types as BasicLink', () {
      // Simulates an older app version encountering a ProjectLink
      // by testing that the fallback works for truly unknown types
      final json = <String, dynamic>{
        'runtimeType': 'totally_unknown',
        'id': 'link-999',
        'fromId': 'a',
        'toId': 'b',
        'createdAt': testDate.toIso8601String(),
        'updatedAt': testDate.toIso8601String(),
        'vectorClock': null,
      };

      // The @Freezed(fallbackUnion: 'basic') ensures unknown types
      // deserialize as BasicLink
      final restored = EntryLink.fromJson(json);
      expect(restored, isA<BasicLink>());
    });

    glados.Glados(
      glados.any.generatedProjectLink,
      glados.ExploreConfig(numRuns: 140),
    ).test('round-trips generated project links through DB rows', (scenario) {
      final link = scenario.link;

      final dbLink = linkedDbEntity(link);
      final restored = entryLinkFromLinkedDbEntry(dbLink);

      expect(restored, equals(link), reason: '$scenario');
      expect(restored, isA<ProjectLink>(), reason: '$scenario');
      expect(dbLink.type, 'ProjectLink', reason: '$scenario');
      expect(dbLink.fromId, link.fromId, reason: '$scenario');
      expect(dbLink.toId, link.toId, reason: '$scenario');
      expect(dbLink.hidden, link.hidden ?? false, reason: '$scenario');
    }, tags: 'glados');
  });
}

enum _GeneratedProjectStatusKind { open, active, onHold, completed, archived }

class _GeneratedProjectEntry {
  const _GeneratedProjectEntry({
    required this.idSlot,
    required this.dateSlot,
    required this.categorySlot,
    required this.deletedAtSlot,
    required this.privateSlot,
    required this.starredSlot,
    required this.title,
    required this.statusKind,
    required this.targetDateSlot,
  });

  final int idSlot;
  final int dateSlot;
  final int categorySlot;
  final int deletedAtSlot;
  final int privateSlot;
  final int starredSlot;
  final String title;
  final _GeneratedProjectStatusKind statusKind;
  final int targetDateSlot;

  ProjectEntry get projectEntry {
    final date = _projectEntityDate(dateSlot);
    return ProjectEntry(
      meta: Metadata(
        id: 'project-$idSlot',
        createdAt: date,
        updatedAt: _projectEntityDate(dateSlot + 1),
        dateFrom: date,
        dateTo: _projectEntityDate(dateSlot + 2),
        categoryId: _optionalProjectText(categorySlot, 'category'),
        vectorClock: _vectorClock(idSlot),
        deletedAt: deletedAtSlot.isEven
            ? null
            : _projectEntityDate(deletedAtSlot),
        private: _optionalBool(privateSlot),
        starred: _optionalBool(starredSlot),
      ),
      data: ProjectData(
        title: title,
        status: _projectStatus(statusKind, idSlot, dateSlot),
        dateFrom: date,
        dateTo: _projectEntityDate(dateSlot + 2),
        targetDate: targetDateSlot.isEven
            ? null
            : _projectEntityDate(targetDateSlot),
      ),
    );
  }

  @override
  String toString() {
    return '_GeneratedProjectEntry('
        'idSlot: $idSlot, '
        'dateSlot: $dateSlot, '
        'categorySlot: $categorySlot, '
        'deletedAtSlot: $deletedAtSlot, '
        'privateSlot: $privateSlot, '
        'starredSlot: $starredSlot, '
        'title: "$title", '
        'statusKind: $statusKind, '
        'targetDateSlot: $targetDateSlot)';
  }
}

class _GeneratedProjectLink {
  const _GeneratedProjectLink({
    required this.idSlot,
    required this.fromSlot,
    required this.toSlot,
    required this.dateSlot,
    required this.vectorClockSlot,
    required this.hiddenSlot,
    required this.collapsedSlot,
  });

  final int idSlot;
  final int fromSlot;
  final int toSlot;
  final int dateSlot;
  final int vectorClockSlot;
  final int hiddenSlot;
  final int collapsedSlot;

  ProjectLink get link =>
      EntryLink.project(
            id: 'project-link-$idSlot',
            fromId: 'project-$fromSlot',
            toId: 'task-$toSlot',
            createdAt: _projectEntityDate(dateSlot),
            updatedAt: _projectEntityDate(dateSlot + 1),
            vectorClock: _vectorClock(vectorClockSlot),
            hidden: _optionalBool(hiddenSlot),
            collapsed: _optionalBool(collapsedSlot),
          )
          as ProjectLink;

  @override
  String toString() {
    return '_GeneratedProjectLink('
        'idSlot: $idSlot, '
        'fromSlot: $fromSlot, '
        'toSlot: $toSlot, '
        'dateSlot: $dateSlot, '
        'vectorClockSlot: $vectorClockSlot, '
        'hiddenSlot: $hiddenSlot, '
        'collapsedSlot: $collapsedSlot)';
  }
}

extension _AnyProjectEntity on glados.Any {
  glados.Generator<String> get _projectEntityText =>
      glados.AnyUtils(this).choose(const [
        '',
        'Project',
        'Project with spaces',
        'Project "quoted"',
        r'Project \ slash',
      ]);

  glados.Generator<_GeneratedProjectStatusKind> get _projectStatusKind =>
      glados.AnyUtils(this).choose(_GeneratedProjectStatusKind.values);

  glados.Generator<_GeneratedProjectEntry> get generatedProjectEntry =>
      glados.CombinableAny(this).combine9(
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        _projectEntityText,
        _projectStatusKind,
        glados.IntAnys(this).intInRange(0, 240),
        (
          int idSlot,
          int dateSlot,
          int categorySlot,
          int deletedAtSlot,
          int privateSlot,
          int starredSlot,
          String title,
          _GeneratedProjectStatusKind statusKind,
          int targetDateSlot,
        ) => _GeneratedProjectEntry(
          idSlot: idSlot,
          dateSlot: dateSlot,
          categorySlot: categorySlot,
          deletedAtSlot: deletedAtSlot,
          privateSlot: privateSlot,
          starredSlot: starredSlot,
          title: title,
          statusKind: statusKind,
          targetDateSlot: targetDateSlot,
        ),
      );

  glados.Generator<_GeneratedProjectLink> get generatedProjectLink =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        (
          int idSlot,
          int fromSlot,
          int toSlot,
          int dateSlot,
          int vectorClockSlot,
          int hiddenSlot,
          int collapsedSlot,
        ) => _GeneratedProjectLink(
          idSlot: idSlot,
          fromSlot: fromSlot,
          toSlot: toSlot,
          dateSlot: dateSlot,
          vectorClockSlot: vectorClockSlot,
          hiddenSlot: hiddenSlot,
          collapsedSlot: collapsedSlot,
        ),
      );
}

ProjectStatus _projectStatus(
  _GeneratedProjectStatusKind kind,
  int idSlot,
  int dateSlot,
) {
  final id = 'status-$idSlot';
  final date = _projectEntityDate(dateSlot);
  return switch (kind) {
    _GeneratedProjectStatusKind.open => ProjectStatus.open(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
    _GeneratedProjectStatusKind.active => ProjectStatus.active(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
    _GeneratedProjectStatusKind.onHold => ProjectStatus.onHold(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
      reason: 'reason-$idSlot',
    ),
    _GeneratedProjectStatusKind.completed => ProjectStatus.completed(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
    _GeneratedProjectStatusKind.archived => ProjectStatus.archived(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
  };
}

DateTime _projectEntityDate(int slot) {
  return DateTime.utc(
    2024 + (slot % 4),
    (slot % 12) + 1,
    (slot % 28) + 1,
    slot % 24,
    slot % 60,
  );
}

String? _optionalProjectText(int slot, String prefix) {
  return switch (slot % 4) {
    0 => null,
    1 => '$prefix-$slot',
    2 => '$prefix "$slot"',
    _ => '$prefix \\ $slot',
  };
}

VectorClock? _vectorClock(int slot) {
  if (slot % 4 == 0) {
    return null;
  }

  return VectorClock({
    'host-${slot % 3}': slot + 1,
    'shared': slot % 7,
  });
}

bool? _optionalBool(int slot) {
  return switch (slot % 3) {
    0 => null,
    1 => true,
    _ => false,
  };
}
