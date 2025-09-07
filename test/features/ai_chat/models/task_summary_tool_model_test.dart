import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('TaskSummaryTool', () {
    test('toolDefinition is function type with required params', () {
      final tool = TaskSummaryTool.toolDefinition;
      expect(tool.type, ChatCompletionToolType.function);
      expect(tool.function.name, TaskSummaryTool.name);
      final params = tool.function.parameters!;
      expect(params, isNotNull);
      expect(
          params['required'], containsAll(<String>['start_date', 'end_date']));
      final limit = (params['properties'] as Map)['limit'] as Map;
      expect(limit['default'], 100);
    });

    test('TaskSummaryRequest JSON uses start_date and end_date', () {
      // Use UTC to avoid timezone-dependent behavior
      final req = TaskSummaryRequest(
        startDate: DateTime.parse('2024-01-01T00:00:00.000Z').toUtc(),
        endDate: DateTime.parse('2024-01-02T00:00:00.000Z').toUtc(),
      );
      final json = req.toJson();
      expect(json['start_date'], isNotNull);
      expect(json['end_date'], isNotNull);
      final back = TaskSummaryRequest.fromJson(json);
      // Round-trip must preserve UTC instants
      expect(back.startDate.toUtc().millisecondsSinceEpoch,
          equals(req.startDate.toUtc().millisecondsSinceEpoch));
      expect(back.endDate.toUtc().millisecondsSinceEpoch,
          equals(req.endDate.toUtc().millisecondsSinceEpoch));
      // Keep existing limit assertion
      expect(back.limit, 100);
    });

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

    test('TaskSummaryRequest rejects non-UTC or missing Z timestamps', () {
      // Missing trailing Z
      final nonUtcJson1 = {
        'start_date': '2024-01-01T00:00:00.000',
        'end_date': '2024-01-02T00:00:00.000',
      };
      expect(
        () => TaskSummaryRequest.fromJson(nonUtcJson1),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('ISO 8601 UTC with trailing Z'),
        )),
      );

      // Local time with timezone offset instead of Z
      final nonUtcJson2 = {
        'start_date': '2024-01-01T00:00:00.000+02:00',
        'end_date': '2024-01-01T23:59:59.999+02:00',
      };
      expect(
        () => TaskSummaryRequest.fromJson(nonUtcJson2),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('trailing Z'),
        )),
      );
    });
  });
}
