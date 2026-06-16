import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_summary_tool.freezed.dart';
part 'task_summary_tool.g.dart';

/// The `get_task_summaries` function-calling tool exposed to the model.
///
/// [toolDefinition] is the OpenAI-format schema advertised to the provider;
/// when the model emits a matching tool call, `ChatMessageProcessor` decodes the
/// arguments into a [TaskSummaryRequest] and dispatches to `TaskSummaryRepository`.
/// The schema requires both dates as local `YYYY-MM-DD` strings (no time/tz).
class TaskSummaryTool {
  static const String name = 'get_task_summaries';

  static ChatCompletionTool get toolDefinition => const ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: name,
      description:
          'Retrieve task summaries for a specified date range (local dates only)',
      parameters: {
        'type': 'object',
        'properties': {
          'start_date': {
            'type': 'string',
            'format': 'date',
            'description':
                'Start date in local time, YYYY-MM-DD (no time or timezone).',
          },
          'end_date': {
            'type': 'string',
            'format': 'date',
            'description':
                'End date in local time, YYYY-MM-DD (no time or timezone).',
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

/// Decoded arguments of a `get_task_summaries` tool call. [startDate]/[endDate]
/// are local `YYYY-MM-DD` strings; [limit] is capped to 100 by the repository.
@freezed
abstract class TaskSummaryRequest with _$TaskSummaryRequest {
  const factory TaskSummaryRequest({
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @Default(100) int limit,
  }) = _TaskSummaryRequest;

  factory TaskSummaryRequest.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryRequestFromJson(json);
}

/// One task summary returned to the model as tool output: identity, AI
/// [summary] (or a fallback string when none exists), [taskDate], and [status].
@freezed
abstract class TaskSummaryResult with _$TaskSummaryResult {
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
