import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/conversions.dart';

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
        'rpiType': 'totally_unknown',
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
  });
}
