import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';

void main() {
  group('ProjectData', () {
    final testDate = DateTime(2024, 3, 15, 10, 30);

    test('round-trip JSON serialization preserves all fields', () {
      final status = ProjectStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 60,
        timezone: 'Europe/Berlin',
      );

      final data = ProjectData(
        title: 'Device Synchronization',
        status: status,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [
          ProjectStatus.open(
            id: 'status-0',
            createdAt: DateTime(2024, 3),
            utcOffset: 60,
          ),
          status,
        ],
        targetDate: DateTime(2024, 6, 30),
        profileId: 'profile-123',
        coverArtId: 'image-abc',
        coverArtCropX: 0.3,
      );

      final json = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      final restored = ProjectData.fromJson(json);

      expect(restored.title, 'Device Synchronization');
      expect(restored.status, isA<ProjectActive>());
      expect(restored.dateFrom, testDate);
      expect(restored.dateTo, testDate);
      expect(restored.statusHistory, hasLength(2));
      expect(restored.targetDate, DateTime(2024, 6, 30));
      expect(restored.profileId, 'profile-123');
      expect(restored.coverArtId, 'image-abc');
      expect(restored.coverArtCropX, 0.3);
    });

    test('defaults are applied correctly', () {
      final data = ProjectData(
        title: 'Minimal',
        status: ProjectStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
      );

      expect(data.statusHistory, isEmpty);
      expect(data.targetDate, isNull);
      expect(data.profileId, isNull);
      expect(data.coverArtId, isNull);
      expect(data.coverArtCropX, 0.5);
    });

    test('copyWith updates fields correctly', () {
      final data = ProjectData(
        title: 'Original',
        status: ProjectStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
      );

      final updated = data.copyWith(
        title: 'Updated Title',
        targetDate: DateTime(2025),
      );

      expect(updated.title, 'Updated Title');
      expect(updated.targetDate, DateTime(2025));
      expect(updated.dateFrom, testDate);
    });
  });

  group('ProjectStatus', () {
    final testDate = DateTime(2024, 3, 15, 10, 30);

    test('all variants serialize and deserialize', () {
      final variants = <ProjectStatus>[
        ProjectStatus.open(
          id: 'ps-1',
          createdAt: testDate,
          utcOffset: 60,
        ),
        ProjectStatus.active(
          id: 'ps-2',
          createdAt: testDate,
          utcOffset: 60,
        ),
        ProjectStatus.onHold(
          id: 'ps-3',
          createdAt: testDate,
          utcOffset: 60,
          reason: 'Waiting for dependency',
        ),
        ProjectStatus.completed(
          id: 'ps-4',
          createdAt: testDate,
          utcOffset: 60,
        ),
        ProjectStatus.archived(
          id: 'ps-5',
          createdAt: testDate,
          utcOffset: 60,
        ),
      ];

      for (final variant in variants) {
        final json = jsonDecode(jsonEncode(variant)) as Map<String, dynamic>;
        final restored = ProjectStatus.fromJson(json);
        expect(restored, variant);
      }
    });

    test('toDbString returns correct strings', () {
      expect(
        ProjectStatus.open(
          id: 'ps-1',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'OPEN',
      );
      expect(
        ProjectStatus.active(
          id: 'ps-2',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'ACTIVE',
      );
      expect(
        ProjectStatus.onHold(
          id: 'ps-3',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'blocked',
        ).toDbString,
        'ON HOLD',
      );
      expect(
        ProjectStatus.completed(
          id: 'ps-4',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'COMPLETED',
      );
      expect(
        ProjectStatus.archived(
          id: 'ps-5',
          createdAt: testDate,
          utcOffset: 0,
        ).toDbString,
        'ARCHIVED',
      );
    });

    test('onHold preserves reason field', () {
      final status = ProjectStatus.onHold(
        id: 'ps-1',
        createdAt: testDate,
        utcOffset: 60,
        reason: 'Waiting for legal review',
      );

      final json = jsonDecode(jsonEncode(status)) as Map<String, dynamic>;
      final restored = ProjectStatus.fromJson(json);

      expect(restored, isA<ProjectOnHold>());
      expect((restored as ProjectOnHold).reason, 'Waiting for legal review');
    });
  });
}
