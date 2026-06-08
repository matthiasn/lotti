import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'journal_entities_test_helpers.dart';
import 'project_test_generators.dart';

void main() {
  group('Metadata JSON round-trips — static examples', () {
    final date = DateTime(2024, 3, 15, 10);

    Metadata roundTrip(Metadata m) => Metadata.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
    );

    test('minimal Metadata survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-1',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
      );
      final decoded = roundTrip(m);
      expect(decoded, m, reason: 'minimal Metadata round-trip');
      expect(decoded.id, 'meta-1');
      expect(decoded.categoryId, isNull);
      expect(decoded.labelIds, isNull);
      expect(decoded.flag, isNull);
    });

    test('Metadata with all optional fields survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-2',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(hours: 1)),
        categoryId: 'cat-1',
        labelIds: ['lbl-1', 'lbl-2'],
        utcOffset: 120,
        timezone: 'Europe/Berlin',
        vectorClock: const VectorClock({'node-a': 3, 'node-b': 1}),
        deletedAt: DateTime(2024, 12, 31),
        flag: EntryFlag.followUpNeeded,
        starred: true,
        private: false,
      );
      final decoded = roundTrip(m);
      expect(decoded, m, reason: 'full Metadata round-trip');
      expect(decoded.categoryId, 'cat-1');
      expect(decoded.labelIds, ['lbl-1', 'lbl-2']);
      expect(decoded.vectorClock?.vclock, {'node-a': 3, 'node-b': 1});
      expect(decoded.flag, EntryFlag.followUpNeeded);
      expect(decoded.starred, isTrue);
    });

    test('Metadata with EntryFlag.none survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-3',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
        flag: EntryFlag.none,
      );
      final decoded = roundTrip(m);
      expect(decoded.flag, EntryFlag.none);
    });

    test('Metadata with EntryFlag.import survives JSON round-trip', () {
      final m = Metadata(
        id: 'meta-4',
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date,
        flag: EntryFlag.import,
      );
      final decoded = roundTrip(m);
      expect(decoded.flag, EntryFlag.import);
    });
  });

  group('Metadata Glados round-trips', () {
    glados.Glados(
      glados.any.generatedMetadata,
      glados.ExploreConfig(numRuns: 120),
    ).test('Metadata round-trips through JSON', (scenario) {
      final m = scenario.metadata;
      final decoded = Metadata.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, m, reason: '$scenario');
      expect(decoded.id, m.id, reason: 'id preserved');
      expect(decoded.flag, m.flag, reason: 'flag preserved');
      expect(decoded.labelIds, m.labelIds, reason: 'labelIds preserved');
    }, tags: 'glados');
  });

  final projectTestDate = DateTime(2024, 3, 15, 10, 30);

  group('JournalEntity.project', () {
    late ProjectEntry projectEntry;

    setUp(() {
      projectEntry = ProjectEntry(
        meta: Metadata(
          id: 'project-001',
          createdAt: projectTestDate,
          updatedAt: projectTestDate,
          dateFrom: projectTestDate,
          dateTo: projectTestDate,
          categoryId: 'cat-engineering',
        ),
        data: ProjectData(
          title: 'Device Synchronization',
          status: ProjectStatus.active(
            id: 'status-1',
            createdAt: projectTestDate,
            utcOffset: 60,
          ),
          dateFrom: projectTestDate,
          dateTo: projectTestDate,
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
}
