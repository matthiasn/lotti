// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';

void main() {
  group('TaskSummaryTool', () {
    test('toolDefinition has required params', () {
      final tool = TaskSummaryTool.toolDefinition;
      expect(tool.name, TaskSummaryTool.name);
      final params = tool.parameters;
      expect(
        params['required'],
        containsAll(<String>['start_date', 'end_date']),
      );
      final limit = (params['properties'] as Map)['limit'] as Map;
      expect(limit['default'], 100);
    });

    test(
      'TaskSummaryRequest JSON uses start_date and end_date (date-only)',
      () {
        final req = TaskSummaryRequest(
          startDate: '2024-01-01',
          endDate: '2024-01-02',
        );
        final json = req.toJson();
        expect(json['start_date'], '2024-01-01');
        expect(json['end_date'], '2024-01-02');
        final back = TaskSummaryRequest.fromJson(json);
        expect(back.startDate, '2024-01-01');
        expect(back.endDate, '2024-01-02');
        expect(back.limit, 100);
      },
    );

    glados.Glados(
      glados.any.generatedTaskSummaryRequest,
      glados.ExploreConfig(numRuns: 160),
    ).test('round-trips generated requests with snake-case JSON keys', (
      scenario,
    ) {
      final request = scenario.request;

      final json = request.toJson();
      final back = TaskSummaryRequest.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );

      expect(json['start_date'], request.startDate, reason: '$scenario');
      expect(json['end_date'], request.endDate, reason: '$scenario');
      expect(json, isNot(contains('startDate')), reason: '$scenario');
      expect(json, isNot(contains('endDate')), reason: '$scenario');
      expect(back, equals(request), reason: '$scenario');
    }, tags: 'glados');

    glados.Glados(
      glados.any.generatedTaskSummaryDateRange,
      glados.ExploreConfig(numRuns: 120),
    ).test('preserves the default limit for generated date ranges', (
      scenario,
    ) {
      final json = <String, dynamic>{
        'start_date': scenario.startDate,
        'end_date': scenario.endDate,
      };

      final back = TaskSummaryRequest.fromJson(json);

      expect(back.startDate, scenario.startDate, reason: '$scenario');
      expect(back.endDate, scenario.endDate, reason: '$scenario');
      expect(back.limit, 100, reason: '$scenario');
    }, tags: 'glados');

    test('TaskSummaryResult JSON roundtrip', () {
      final res = TaskSummaryResult(
        taskId: 't1',
        taskTitle: 'Task',
        summary: 'S',
        taskDate: DateTime(2024),
        status: 'completed',
        metadata: const {'m': 'v'},
      );
      final json = res.toJson();
      final back = TaskSummaryResult.fromJson(json);
      expect(back.taskId, 't1');
      expect(back.metadata?['m'], 'v');
    });
  });
}

class _GeneratedTaskSummaryDateRange {
  const _GeneratedTaskSummaryDateRange({
    required this.startSlot,
    required this.endSlot,
  });

  final int startSlot;
  final int endSlot;

  String get startDate => _dateOnly(startSlot);

  String get endDate => _dateOnly(endSlot);

  @override
  String toString() {
    return '_GeneratedTaskSummaryDateRange('
        'startSlot: $startSlot, '
        'endSlot: $endSlot, '
        'startDate: "$startDate", '
        'endDate: "$endDate")';
  }
}

class _GeneratedTaskSummaryRequest {
  const _GeneratedTaskSummaryRequest({
    required this.dateRange,
    required this.limit,
  });

  final _GeneratedTaskSummaryDateRange dateRange;
  final int limit;

  TaskSummaryRequest get request => TaskSummaryRequest(
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
    limit: limit,
  );

  @override
  String toString() {
    return '_GeneratedTaskSummaryRequest('
        'dateRange: $dateRange, '
        'limit: $limit)';
  }
}

extension _AnyTaskSummaryTool on glados.Any {
  glados.Generator<_GeneratedTaskSummaryDateRange>
  get generatedTaskSummaryDateRange => glados.CombinableAny(this).combine2(
    glados.IntAnys(this).intInRange(0, 720),
    glados.IntAnys(this).intInRange(0, 720),
    (
      int startSlot,
      int endSlot,
    ) => _GeneratedTaskSummaryDateRange(
      startSlot: startSlot,
      endSlot: endSlot,
    ),
  );

  glados.Generator<_GeneratedTaskSummaryRequest>
  get generatedTaskSummaryRequest => glados.CombinableAny(this).combine2(
    generatedTaskSummaryDateRange,
    glados.IntAnys(this).intInRange(0, 500),
    (
      _GeneratedTaskSummaryDateRange dateRange,
      int limit,
    ) => _GeneratedTaskSummaryRequest(
      dateRange: dateRange,
      limit: limit,
    ),
  );
}

String _dateOnly(int slot) {
  final date = _dateTime(slot);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _dateTime(int slot) {
  return DateTime.utc(
    2024 + (slot % 4),
    (slot % 12) + 1,
    (slot % 28) + 1,
    slot % 24,
    slot % 60,
  );
}
