import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/colors.dart';
import 'task_test_helpers.dart';

void main() {
  group('TaskStatus JSON round-trips — static examples', () {
    const id = 'status-abc';
    final date = DateTime(2024, 5, 10, 8, 30);
    const offset = 120;
    const tz = 'Europe/Berlin';
    final geo = Geolocation(
      createdAt: DateTime(2024, 5, 10),
      latitude: 48.137154,
      longitude: 11.576124,
      geohashString: 'u281z',
    );

    TaskStatus roundTrip(TaskStatus s) => TaskStatus.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );

    test('TaskStatus.open survives JSON round-trip', () {
      final s = TaskStatus.open(
        id: id,
        createdAt: date,
        utcOffset: offset,
        timezone: tz,
        geolocation: geo,
      );
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'open status round-trip');
      expect(decoded.toDbString, 'OPEN');
    });

    test('TaskStatus.groomed survives JSON round-trip', () {
      final s = TaskStatus.groomed(
        id: id,
        createdAt: date,
        utcOffset: offset,
      );
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'groomed status round-trip');
      expect(decoded.toDbString, 'GROOMED');
    });

    test('TaskStatus.inProgress survives JSON round-trip', () {
      final s = TaskStatus.inProgress(
        id: id,
        createdAt: date,
        utcOffset: offset,
      );
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'inProgress status round-trip');
      expect(decoded.toDbString, 'IN PROGRESS');
    });

    test('TaskStatus.blocked survives JSON round-trip including reason', () {
      final s = TaskStatus.blocked(
        id: id,
        createdAt: date,
        utcOffset: offset,
        reason: 'waiting for design review',
        timezone: tz,
      );
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'blocked status round-trip');
      expect((decoded as TaskBlocked).reason, 'waiting for design review');
    });

    test('TaskStatus.onHold survives JSON round-trip including reason', () {
      final s = TaskStatus.onHold(
        id: id,
        createdAt: date,
        utcOffset: offset,
        reason: 'needs a reason',
      );
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'onHold status round-trip');
      expect((decoded as TaskOnHold).reason, 'needs a reason');
    });

    test('TaskStatus.done survives JSON round-trip', () {
      final s = TaskStatus.done(id: id, createdAt: date, utcOffset: offset);
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'done status round-trip');
    });

    test('TaskStatus.rejected survives JSON round-trip', () {
      final s = TaskStatus.rejected(id: id, createdAt: date, utcOffset: offset);
      final decoded = roundTrip(s);
      expect(decoded, s, reason: 'rejected status round-trip');
    });
  });

  group('TaskData JSON round-trips — static examples', () {
    final date = DateTime(2024, 5, 10, 8, 30);
    final status = TaskStatus.open(
      id: 'status-1',
      createdAt: date,
      utcOffset: 0,
    );

    TaskData roundTrip(TaskData d) => TaskData.fromJson(
      jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
    );

    test('minimal TaskData survives JSON round-trip', () {
      final data = TaskData(
        status: status,
        dateFrom: date,
        dateTo: date,
        statusHistory: [],
        title: 'My task',
      );
      final decoded = roundTrip(data);
      expect(decoded, data, reason: 'minimal TaskData round-trip');
      expect(decoded.title, 'My task');
      expect(decoded.languageCode, isNull);
      expect(
        decoded.languageSource,
        ChangeSource.user,
        reason: '@Default should survive round-trip',
      );
      expect(
        decoded.priority,
        TaskPriority.p2Medium,
        reason: 'default priority survives round-trip',
      );
    });

    test('TaskData with all optional fields survives JSON round-trip', () {
      final status2 = TaskStatus.blocked(
        id: 'status-2',
        createdAt: date,
        utcOffset: 60,
        reason: 'design pending',
      );
      final data = TaskData(
        status: status,
        dateFrom: date,
        dateTo: date.add(const Duration(hours: 2)),
        statusHistory: [status, status2],
        title: 'Full task',
        due: DateTime(2024, 6),
        estimate: const Duration(hours: 3),
        checklistIds: ['cl-1', 'cl-2'],
        languageCode: 'de',
        languageSource: ChangeSource.agent,
        aiSuppressedLabelIds: {'label-a', 'label-b'},
        priority: TaskPriority.p1High,
        coverArtId: 'img-42',
        coverArtCropX: 0.25,
        profileId: 'profile-7',
      );
      final decoded = roundTrip(data);
      expect(decoded, data, reason: 'full TaskData round-trip');
      expect(decoded.languageCode, 'de');
      expect(decoded.languageSource, ChangeSource.agent);
      expect(decoded.priority, TaskPriority.p1High);
      expect(decoded.aiSuppressedLabelIds, {'label-a', 'label-b'});
      expect(decoded.coverArtCropX, 0.25);
      expect(decoded.statusHistory.length, 2);
      expect(decoded.statusHistory[1].toDbString, 'BLOCKED');
    });

    test(
      'TaskData with @JsonKey(unknownEnumValue) fallback for languageSource',
      () {
        // Simulate an unknown languageSource arriving from an older client.
        final raw = <String, dynamic>{
          'status': status.toJson(),
          'dateFrom': date.toIso8601String(),
          'dateTo': date.toIso8601String(),
          'statusHistory': <Map<String, dynamic>>[],
          'title': 'Legacy task',
          'languageSource': 'unknownValue',
        };
        final decoded = TaskData.fromJson(raw);
        expect(
          decoded.languageSource,
          ChangeSource.user,
          reason: 'unknownEnumValue fallback must be ChangeSource.user',
        );
      },
    );

    test('TaskData with all four TaskPriority values round-trips', () {
      for (final priority in TaskPriority.values) {
        final data = TaskData(
          status: status,
          dateFrom: date,
          dateTo: date,
          statusHistory: [],
          title: 'Priority task',
          priority: priority,
        );
        final decoded = roundTrip(data);
        expect(
          decoded.priority,
          priority,
          reason: 'priority $priority must survive round-trip',
        );
      }
    });
  });

  group('TaskData/TaskStatus Glados round-trips', () {
    glados.Glados(
      glados.any.generatedTaskStatus,
      glados.ExploreConfig(numRuns: 120),
    ).test('TaskStatus round-trips through JSON', (scenario) {
      final status = scenario.status;
      final decoded = TaskStatus.fromJson(
        jsonDecode(jsonEncode(status.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, status, reason: '$scenario');
      expect(
        decoded.toDbString,
        status.toDbString,
        reason: 'toDbString consistent after round-trip',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.generatedTaskData,
      glados.ExploreConfig(numRuns: 120),
    ).test('TaskData round-trips through JSON', (scenario) {
      final data = scenario.data;
      final decoded = TaskData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, data, reason: '$scenario');
      expect(
        decoded.title,
        data.title,
        reason: 'title preserved after round-trip',
      );
      expect(
        decoded.priority,
        data.priority,
        reason: 'priority preserved after round-trip',
      );
      expect(
        decoded.languageSource,
        data.languageSource,
        reason: 'languageSource preserved after round-trip',
      );
    }, tags: 'glados');
  });

  group('TaskStatusExtension - colorForBrightness', () {
    final testDate = DateTime(2024);

    group('Light mode colors', () {
      final testCases = <(String, TaskStatus, Color)>[
        (
          'Open',
          TaskStatus.open(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkOrange,
        ),
        (
          'Groomed',
          TaskStatus.groomed(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkGreen,
        ),
        (
          'In Progress',
          TaskStatus.inProgress(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkBlue,
        ),
        (
          'Blocked',
          TaskStatus.blocked(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusDarkRed,
        ),
        (
          'On Hold',
          TaskStatus.onHold(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusDarkRed,
        ),
        (
          'Done',
          TaskStatus.done(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkGreen,
        ),
        (
          'Rejected',
          TaskStatus.rejected(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkRed,
        ),
      ];

      for (final (name, status, expectedColor) in testCases) {
        test('$name status returns correct color in light mode', () {
          expect(
            status.colorForBrightness(Brightness.light),
            equals(expectedColor),
          );
        });
      }
    });

    group('Dark mode colors', () {
      final testCases = <(String, TaskStatus, Color)>[
        (
          'Open',
          TaskStatus.open(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusOrange,
        ),
        (
          'Groomed',
          TaskStatus.groomed(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusLightGreenAccent,
        ),
        (
          'In Progress',
          TaskStatus.inProgress(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusBlue,
        ),
        (
          'Blocked',
          TaskStatus.blocked(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusRed,
        ),
        (
          'On Hold',
          TaskStatus.onHold(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusRed,
        ),
        (
          'Done',
          TaskStatus.done(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusGreen,
        ),
        (
          'Rejected',
          TaskStatus.rejected(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusRed,
        ),
      ];

      for (final (name, status, expectedColor) in testCases) {
        test('$name status returns correct color in dark mode', () {
          expect(
            status.colorForBrightness(Brightness.dark),
            equals(expectedColor),
          );
        });
      }
    });
  });
}
