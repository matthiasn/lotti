import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/project_data.dart';

import 'project_test_generators.dart';

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

    glados.Glados(
      glados.any.generatedProjectData,
      glados.ExploreConfig(numRuns: 140),
    ).test('round-trips generated project data through JSON', (scenario) {
      final data = scenario.data;

      final restored = ProjectData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );

      expect(restored, equals(data), reason: '$scenario');
      expect(restored.statusHistory, data.statusHistory, reason: '$scenario');
      expect(restored.coverArtCropX, data.coverArtCropX, reason: '$scenario');
    }, tags: 'glados');
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

    test('label returns human-readable labels', () {
      expect(
        ProjectStatus.open(
          id: 'ps-1',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Open',
      );
      expect(
        ProjectStatus.active(
          id: 'ps-2',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Active',
      );
      expect(
        ProjectStatus.onHold(
          id: 'ps-3',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'blocked',
        ).label,
        'On Hold',
      );
      expect(
        ProjectStatus.completed(
          id: 'ps-4',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Completed',
      );
      expect(
        ProjectStatus.archived(
          id: 'ps-5',
          createdAt: testDate,
          utcOffset: 0,
        ).label,
        'Archived',
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

    glados.Glados(
      glados.any.generatedProjectStatus,
      glados.ExploreConfig(numRuns: 140),
    ).test('round-trips generated status variants and exposes labels', (
      scenario,
    ) {
      final status = scenario.status;

      final restored = ProjectStatus.fromJson(
        jsonDecode(jsonEncode(status.toJson())) as Map<String, dynamic>,
      );

      expect(restored, equals(status), reason: '$scenario');
      expect(status.toDbString, scenario.expectedDbString, reason: '$scenario');
      expect(status.label, scenario.expectedLabel, reason: '$scenario');
    }, tags: 'glados');
  });
}

class _GeneratedProjectStatus {
  const _GeneratedProjectStatus({
    required this.kind,
    required this.idSlot,
    required this.dateSlot,
    required this.utcOffset,
    required this.timezoneSlot,
    required this.reasonSlot,
  });

  final GeneratedProjectStatusKind kind;
  final int idSlot;
  final int dateSlot;
  final int utcOffset;
  final int timezoneSlot;
  final int reasonSlot;

  ProjectStatus get status {
    final common = (
      id: 'project-status-$idSlot',
      createdAt: projectEntityDate(dateSlot),
      utcOffset: utcOffset,
      timezone: optionalProjectText(timezoneSlot, 'Timezone'),
    );

    return switch (kind) {
      GeneratedProjectStatusKind.open => ProjectStatus.open(
        id: common.id,
        createdAt: common.createdAt,
        utcOffset: common.utcOffset,
        timezone: common.timezone,
      ),
      GeneratedProjectStatusKind.active => ProjectStatus.active(
        id: common.id,
        createdAt: common.createdAt,
        utcOffset: common.utcOffset,
        timezone: common.timezone,
      ),
      GeneratedProjectStatusKind.onHold => ProjectStatus.onHold(
        id: common.id,
        createdAt: common.createdAt,
        utcOffset: common.utcOffset,
        reason: optionalProjectText(reasonSlot, 'Reason') ?? '',
        timezone: common.timezone,
      ),
      GeneratedProjectStatusKind.completed => ProjectStatus.completed(
        id: common.id,
        createdAt: common.createdAt,
        utcOffset: common.utcOffset,
        timezone: common.timezone,
      ),
      GeneratedProjectStatusKind.archived => ProjectStatus.archived(
        id: common.id,
        createdAt: common.createdAt,
        utcOffset: common.utcOffset,
        timezone: common.timezone,
      ),
    };
  }

  String get expectedDbString => switch (kind) {
    GeneratedProjectStatusKind.open => 'OPEN',
    GeneratedProjectStatusKind.active => 'ACTIVE',
    GeneratedProjectStatusKind.onHold => 'ON HOLD',
    GeneratedProjectStatusKind.completed => 'COMPLETED',
    GeneratedProjectStatusKind.archived => 'ARCHIVED',
  };

  String get expectedLabel => switch (kind) {
    GeneratedProjectStatusKind.open => 'Open',
    GeneratedProjectStatusKind.active => 'Active',
    GeneratedProjectStatusKind.onHold => 'On Hold',
    GeneratedProjectStatusKind.completed => 'Completed',
    GeneratedProjectStatusKind.archived => 'Archived',
  };

  @override
  String toString() {
    return '_GeneratedProjectStatus('
        'kind: $kind, '
        'idSlot: $idSlot, '
        'dateSlot: $dateSlot, '
        'utcOffset: $utcOffset, '
        'timezoneSlot: $timezoneSlot, '
        'reasonSlot: $reasonSlot)';
  }
}

class _GeneratedProjectData {
  const _GeneratedProjectData({
    required this.title,
    required this.status,
    required this.dateFromSlot,
    required this.dateToSlot,
    required this.statusHistory,
    required this.targetDateSlot,
    required this.profileIdSlot,
    required this.coverArtIdSlot,
    required this.coverArtCropSlot,
  });

  final String title;
  final _GeneratedProjectStatus status;
  final int dateFromSlot;
  final int dateToSlot;
  final List<_GeneratedProjectStatus> statusHistory;
  final int targetDateSlot;
  final int profileIdSlot;
  final int coverArtIdSlot;
  final int coverArtCropSlot;

  ProjectData get data => ProjectData(
    title: title,
    status: status.status,
    dateFrom: projectEntityDate(dateFromSlot),
    dateTo: projectEntityDate(dateToSlot),
    statusHistory: statusHistory.map((generated) => generated.status).toList(),
    targetDate: targetDateSlot.isEven
        ? null
        : projectEntityDate(targetDateSlot),
    profileId: optionalProjectText(profileIdSlot, 'profile'),
    coverArtId: optionalProjectText(coverArtIdSlot, 'cover'),
    coverArtCropX: coverArtCropSlot / 100,
  );

  @override
  String toString() {
    return '_GeneratedProjectData('
        'title: "$title", '
        'status: $status, '
        'dateFromSlot: $dateFromSlot, '
        'dateToSlot: $dateToSlot, '
        'statusHistory: $statusHistory, '
        'targetDateSlot: $targetDateSlot, '
        'profileIdSlot: $profileIdSlot, '
        'coverArtIdSlot: $coverArtIdSlot, '
        'coverArtCropSlot: $coverArtCropSlot)';
  }
}

extension _AnyProjectData on glados.Any {
  glados.Generator<String> get _projectText =>
      glados.AnyUtils(this).choose(const [
        '',
        'Project',
        'Project with spaces',
        'Project "quoted"',
        r'Project \ slash',
      ]);

  glados.Generator<GeneratedProjectStatusKind> get _projectStatusKind =>
      glados.AnyUtils(this).choose(GeneratedProjectStatusKind.values);

  glados.Generator<_GeneratedProjectStatus> get generatedProjectStatus =>
      glados.CombinableAny(this).combine6(
        _projectStatusKind,
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(-720, 841),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        (
          GeneratedProjectStatusKind kind,
          int idSlot,
          int dateSlot,
          int utcOffset,
          int timezoneSlot,
          int reasonSlot,
        ) => _GeneratedProjectStatus(
          kind: kind,
          idSlot: idSlot,
          dateSlot: dateSlot,
          utcOffset: utcOffset,
          timezoneSlot: timezoneSlot,
          reasonSlot: reasonSlot,
        ),
      );

  glados.Generator<_GeneratedProjectData> get generatedProjectData =>
      glados.CombinableAny(this).combine9(
        _projectText,
        generatedProjectStatus,
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 240),
        glados.ListAnys(this).listWithLengthInRange(
          0,
          5,
          generatedProjectStatus,
        ),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 100),
        (
          String title,
          _GeneratedProjectStatus status,
          int dateFromSlot,
          int dateToSlot,
          List<_GeneratedProjectStatus> statusHistory,
          int targetDateSlot,
          int profileIdSlot,
          int coverArtIdSlot,
          int coverArtCropSlot,
        ) => _GeneratedProjectData(
          title: title,
          status: status,
          dateFromSlot: dateFromSlot,
          dateToSlot: dateToSlot,
          statusHistory: statusHistory,
          targetDateSlot: targetDateSlot,
          profileIdSlot: profileIdSlot,
          coverArtIdSlot: coverArtIdSlot,
          coverArtCropSlot: coverArtCropSlot,
        ),
      );
}
