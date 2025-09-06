import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_summary_tool.freezed.dart';
part 'task_summary_tool.g.dart';

/// Tool definition for retrieving task summaries
class TaskSummaryTool {
  static const String name = 'get_task_summaries';

  static ChatCompletionTool get toolDefinition => const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: name,
          description: 'Retrieve task summaries for a specified date range',
          parameters: {
            'type': 'object',
            'properties': {
              'start_date': {
                'type': 'string',
                'description': 'Start date in YYYY-MM-DD format',
              },
              'end_date': {
                'type': 'string',
                'description': 'End date in YYYY-MM-DD format',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of summaries to return',
                'default': 100,
              },
            },
            'required': ['start_date', 'end_date'],
          },
        ),
      );
}

@freezed
class TaskSummaryRequest with _$TaskSummaryRequest {
  const factory TaskSummaryRequest({
    @JsonKey(name: 'start_date') required DateTime startDate,
    @JsonKey(name: 'end_date') required DateTime endDate,
    @Default(100) int limit,
  }) = _TaskSummaryRequest;

  factory TaskSummaryRequest.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryRequestFromJson(json);
}

@freezed
class TaskSummaryResult with _$TaskSummaryResult {
  const factory TaskSummaryResult({
    required String taskId,
    required String taskTitle,
    required String summary,
    required DateTime taskDate,
    required String status,
    Map<String, dynamic>? metadata,
  }) = _TaskSummaryResult;

  factory TaskSummaryResult.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryResultFromJson(json);
}
