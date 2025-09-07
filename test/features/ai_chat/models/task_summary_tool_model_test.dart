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
      final req = TaskSummaryRequest(
        startDate: DateTime.parse('2024-01-01T00:00:00.000'),
        endDate: DateTime.parse('2024-01-02T00:00:00.000'),
      );
      final json = req.toJson();
      expect(json['start_date'], isNotNull);
      expect(json['end_date'], isNotNull);
      final back = TaskSummaryRequest.fromJson(json);
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
  });
}
