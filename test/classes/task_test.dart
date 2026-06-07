import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:glados/glados.dart' show AnyUtils, ExploreConfig, Glados, any;
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/colors.dart';

void main() {
  group('TaskData', () {
    late DateTime testDate;
    late TaskStatus testStatus;

    setUp(() {
      testDate = DateTime(2024);
      testStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      );
    });

    test('creates TaskData with language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'de',
      );

      expect(taskData.languageCode, equals('de'));
      expect(taskData.title, equals('Test Task'));
      expect(taskData.status, equals(testStatus));
    });

    test('creates TaskData without language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
      );

      expect(taskData.languageCode, isNull);
      expect(taskData.title, equals('Test Task'));
    });

    TaskData makeTask({String? languageCode}) => TaskData(
      status: testStatus,
      dateFrom: testDate,
      dateTo: testDate,
      statusHistory: [],
      title: 'Test Task',
      languageCode: languageCode,
    );

    // The copyWith languageCode contract, parameterized over (initial code,
    // copyWith arguments, expected code after the copy).
    for (final (description, initial, copy, expectedCode) in [
      (
        'copyWith() preserves the language code',
        'es',
        (TaskData d) => d.copyWith(),
        'es',
      ),
      (
        'copyWith(title: ...) leaves the language code untouched',
        'fr',
        (TaskData d) => d.copyWith(title: 'Updated Task'),
        'fr',
      ),
      (
        'copyWith(languageCode: ...) updates the language code',
        'en',
        (TaskData d) => d.copyWith(languageCode: 'de'),
        'de',
      ),
      (
        'copyWith(languageCode: null) clears the language code',
        'en',
        (TaskData d) => d.copyWith(languageCode: null),
        null,
      ),
    ]) {
      test(description, () {
        final copied = copy(makeTask(languageCode: initial));
        expect(copied.languageCode, expectedCode);
        // Untouched fields survive every copy.
        expect(copied.status, testStatus);
        expect(copied.dateFrom, testDate);
      });
    }

    test('equality with language code', () {
      expect(makeTask(languageCode: 'fr'), makeTask(languageCode: 'fr'));
      expect(
        makeTask(languageCode: 'fr'),
        isNot(makeTask(languageCode: 'de')),
      );
    });
  });

  group('Task entity', () {
    late DateTime testDate;
    late Metadata testMetadata;
    late TaskStatus testStatus;

    setUp(() {
      testDate = DateTime(2024);
      testMetadata = Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      testStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      );
    });

    test('creates Task with language code in data', () {
      final task = Task(
        meta: testMetadata,
        data: TaskData(
          status: testStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Test Task',
          languageCode: 'ja',
        ),
      );

      expect(task.data.languageCode, equals('ja'));
      expect(task.meta.id, equals('task-1'));
    });

    test('copyWith preserves language code in task data', () {
      final task = Task(
        meta: testMetadata,
        data: TaskData(
          status: testStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Test Task',
          languageCode: 'ko',
        ),
      );

      final updatedTask = task.copyWith(
        data: task.data.copyWith(
          title: 'Updated Title',
        ),
      );

      expect(updatedTask.data.languageCode, equals('ko'));
      expect(updatedTask.data.title, equals('Updated Title'));
    });
  });

  group('taskStatusFromString', () {
    // Each branch maps a string to the correct TaskStatus subtype and the
    // toDbString round-trip returns the canonical DB string.
    final cases = <(String, Type, String)>[
      ('DONE', TaskDone, 'DONE'),
      ('GROOMED', TaskGroomed, 'GROOMED'),
      ('IN PROGRESS', TaskInProgress, 'IN PROGRESS'),
      ('BLOCKED', TaskBlocked, 'BLOCKED'),
      ('ON HOLD', TaskOnHold, 'ON HOLD'),
      ('REJECTED', TaskRejected, 'REJECTED'),
      ('OPEN', TaskOpen, 'OPEN'),
      ('anything else', TaskOpen, 'OPEN'),
    ];

    for (final (input, expectedType, expectedDb) in cases) {
      test('parses "$input" → $expectedType, toDbString == "$expectedDb"', () {
        final status = taskStatusFromString(input);
        expect(status.runtimeType, equals(expectedType));
        expect(status.toDbString, equals(expectedDb));
      });
    }

    test('BLOCKED result carries default reason', () {
      final status = taskStatusFromString('BLOCKED') as TaskBlocked;
      expect(status.reason, equals('needs a reason'));
    });

    test('ON HOLD result carries default reason', () {
      final status = taskStatusFromString('ON HOLD') as TaskOnHold;
      expect(status.reason, equals('needs a reason'));
    });
  });

  group('taskStatusFromString / toDbString round-trip (glados)', () {
    final knownInputs = [
      'DONE',
      'GROOMED',
      'IN PROGRESS',
      'BLOCKED',
      'ON HOLD',
      'REJECTED',
      'OPEN',
    ];

    Glados(any.choose(knownInputs), ExploreConfig(numRuns: 50)).test(
      'toDbString is the canonical form for known statuses',
      (input) {
        final status = taskStatusFromString(input);
        // The DB string must equal the input for the canonical set.
        expect(status.toDbString, equals(input));
      },
      tags: 'glados',
    );
  });

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

// ---------------------------------------------------------------------------
// Glados generator helpers for TaskStatus and TaskData.
// ---------------------------------------------------------------------------

enum _GeneratedTaskStatusKind {
  open,
  inProgress,
  groomed,
  blocked,
  onHold,
  done,
  rejected,
}

class _GeneratedTaskStatus {
  const _GeneratedTaskStatus({
    required this.kind,
    required this.idSlot,
    required this.dateSlot,
    required this.utcOffset,
    required this.timezoneSlot,
    required this.reasonSlot,
    required this.hasGeo,
  });

  final _GeneratedTaskStatusKind kind;
  final int idSlot;
  final int dateSlot;
  final int utcOffset;
  final int timezoneSlot;
  final int reasonSlot;
  final bool hasGeo;

  TaskStatus get status {
    final id = 'status-$idSlot';
    final createdAt = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
    );
    final tz = timezoneSlot.isEven ? null : 'Europe/Berlin';
    final geo = hasGeo
        ? Geolocation(
            createdAt: createdAt,
            latitude: (idSlot % 180) - 90.0,
            longitude: (idSlot % 360) - 180.0,
            geohashString: 'u281z',
          )
        : null;
    final reason = 'reason-$reasonSlot';

    return switch (kind) {
      _GeneratedTaskStatusKind.open => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      _GeneratedTaskStatusKind.inProgress => TaskStatus.inProgress(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      _GeneratedTaskStatusKind.groomed => TaskStatus.groomed(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      _GeneratedTaskStatusKind.blocked => TaskStatus.blocked(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        reason: reason,
        timezone: tz,
        geolocation: geo,
      ),
      _GeneratedTaskStatusKind.onHold => TaskStatus.onHold(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        reason: reason,
        timezone: tz,
        geolocation: geo,
      ),
      _GeneratedTaskStatusKind.done => TaskStatus.done(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      _GeneratedTaskStatusKind.rejected => TaskStatus.rejected(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
    };
  }

  @override
  String toString() =>
      '_GeneratedTaskStatus(kind: $kind, idSlot: $idSlot, '
      'dateSlot: $dateSlot, utcOffset: $utcOffset)';
}

class _GeneratedTaskData {
  const _GeneratedTaskData({
    required this.statusKind,
    required this.idSlot,
    required this.dateSlot,
    required this.titleSlot,
    required this.prioritySlot,
    required this.languageSourceSlot,
    required this.optionalsSlot,
  });

  final _GeneratedTaskStatusKind statusKind;
  final int idSlot;
  final int dateSlot;
  final int titleSlot;
  final int prioritySlot;
  final int languageSourceSlot;
  final int optionalsSlot;

  TaskStatus _makeStatus(String id) {
    final createdAt = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
    );
    return switch (statusKind) {
      _GeneratedTaskStatusKind.open => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      _GeneratedTaskStatusKind.inProgress => TaskStatus.inProgress(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      _GeneratedTaskStatusKind.groomed => TaskStatus.groomed(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      _GeneratedTaskStatusKind.blocked => TaskStatus.blocked(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
        reason: 'blocked-$idSlot',
      ),
      _GeneratedTaskStatusKind.onHold => TaskStatus.onHold(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
        reason: 'onhold-$idSlot',
      ),
      _GeneratedTaskStatusKind.done => TaskStatus.done(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      _GeneratedTaskStatusKind.rejected => TaskStatus.rejected(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
    };
  }

  TaskData get data {
    final dateFrom = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
    );
    final status = _makeStatus('status-$idSlot');
    final history = optionalsSlot.isEven ? <TaskStatus>[] : [status];
    final priority =
        TaskPriority.values[prioritySlot % TaskPriority.values.length];
    final langSource = languageSourceSlot.isOdd
        ? ChangeSource.agent
        : ChangeSource.user;
    final langCode = optionalsSlot % 3 == 0 ? null : 'lang-$optionalsSlot';
    final suppressed = optionalsSlot % 4 == 0
        ? null
        : <String>{'lbl-$optionalsSlot'};

    return TaskData(
      status: status,
      dateFrom: dateFrom,
      dateTo: dateFrom,
      statusHistory: history,
      title: 'Title $titleSlot',
      languageCode: langCode,
      languageSource: langSource,
      priority: priority,
      aiSuppressedLabelIds: suppressed,
    );
  }

  @override
  String toString() =>
      '_GeneratedTaskData(statusKind: $statusKind, idSlot: $idSlot, '
      'titleSlot: $titleSlot, prioritySlot: $prioritySlot)';
}

extension _AnyTaskClasses on glados.Any {
  glados.Generator<_GeneratedTaskStatusKind> get _taskStatusKind =>
      glados.AnyUtils(this).choose(_GeneratedTaskStatusKind.values);

  glados.Generator<_GeneratedTaskStatus> get generatedTaskStatus =>
      glados.CombinableAny(this).combine7(
        _taskStatusKind,
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(-720, 720),
        glados.IntAnys(this).intInRange(0, 10),
        glados.IntAnys(this).intInRange(0, 10),
        glados.any.bool,
        (kind, idSlot, dateSlot, utcOffset, timezoneSlot, reasonSlot, hasGeo) =>
            _GeneratedTaskStatus(
              kind: kind,
              idSlot: idSlot,
              dateSlot: dateSlot,
              utcOffset: utcOffset,
              timezoneSlot: timezoneSlot,
              reasonSlot: reasonSlot,
              hasGeo: hasGeo,
            ),
      );

  glados.Generator<_GeneratedTaskData> get generatedTaskData =>
      glados.CombinableAny(this).combine7(
        _taskStatusKind,
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 1),
        glados.IntAnys(this).intInRange(0, 15),
        (
          statusKind,
          idSlot,
          dateSlot,
          titleSlot,
          prioritySlot,
          languageSourceSlot,
          optionalsSlot,
        ) => _GeneratedTaskData(
          statusKind: statusKind,
          idSlot: idSlot,
          dateSlot: dateSlot,
          titleSlot: titleSlot,
          prioritySlot: prioritySlot,
          languageSourceSlot: languageSourceSlot,
          optionalsSlot: optionalsSlot,
        ),
      );
}
