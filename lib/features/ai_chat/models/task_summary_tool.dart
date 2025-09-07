import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_summary_tool.freezed.dart';
part 'task_summary_tool.g.dart';

/// Ensures DateTime values are parsed/written as UTC ISO 8601 strings (with Z).
class UtcDateTimeConverter implements JsonConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromJson(String json) {
    // Require explicit UTC with trailing 'Z' to avoid timezone ambiguity
    if (!json.endsWith('Z')) {
      throw const FormatException(
        'Date must be ISO 8601 UTC with trailing Z (e.g., 2025-08-26T00:00:00.000Z)',
      );
    }
    final dt = DateTime.parse(json);
    if (!dt.isUtc) {
      throw const FormatException(
        'Parsed date is not UTC. Provide UTC with trailing Z',
      );
    }
    return dt;
  }

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

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
                'format': 'date-time',
                'description':
                    'Start timestamp in ISO 8601 UTC format, e.g. 2025-08-26T00:00:00.000Z',
              },
              'end_date': {
                'type': 'string',
                'format': 'date-time',
                'description':
                    'End timestamp in ISO 8601 UTC format, e.g. 2025-08-26T23:59:59.999Z',
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
    @UtcDateTimeConverter()
    @JsonKey(name: 'start_date')
    required DateTime startDate,
    @UtcDateTimeConverter()
    @JsonKey(name: 'end_date')
    required DateTime endDate,
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
