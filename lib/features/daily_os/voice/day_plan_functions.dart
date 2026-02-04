import 'package:openai_dart/openai_dart.dart';

/// Function definitions for voice-based day planning operations.
///
/// These tools allow an LLM to manipulate a user's day plan based on
/// natural language voice commands.
class DayPlanFunctions {
  static const String addTimeBlock = 'add_time_block';
  static const String resizeTimeBlock = 'resize_time_block';
  static const String moveTimeBlock = 'move_time_block';
  static const String deleteTimeBlock = 'delete_time_block';
  static const String linkTaskToDay = 'link_task_to_day';

  /// Get all available function definitions for day plan operations.
  static List<ChatCompletionTool> getTools() {
    return [
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: addTimeBlock,
          description:
              'Add a new time block to the day plan. Use when the user wants '
              'to schedule time for a category (e.g., "Add 2 hours of work at 9 AM").',
          parameters: {
            'type': 'object',
            'properties': {
              'categoryName': {
                'type': 'string',
                'description':
                    'Name of the category for this block (e.g., "Work", "Exercise"). '
                        'Match against available categories case-insensitively.',
              },
              'startTime': {
                'type': 'string',
                'description':
                    'Start time in 24-hour HH:mm format (e.g., "09:00", "14:30").',
              },
              'endTime': {
                'type': 'string',
                'description':
                    'End time in 24-hour HH:mm format (e.g., "11:00", "16:00").',
              },
              'note': {
                'type': 'string',
                'description':
                    'Optional note for the block (e.g., "Team standup", "Gym session").',
              },
            },
            'required': ['categoryName', 'startTime', 'endTime'],
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: resizeTimeBlock,
          description:
              'Resize an existing time block by changing its start and/or end time. '
              'Use when the user wants to make a block shorter or longer '
              '(e.g., "Shrink the meeting to one hour", "Extend work until 6 PM").',
          parameters: {
            'type': 'object',
            'properties': {
              'blockId': {
                'type': 'string',
                'description':
                    'ID of the block to resize. Get this from the Current Day Plan context.',
              },
              'newStartTime': {
                'type': 'string',
                'description':
                    'New start time in 24-hour HH:mm format. Omit to keep current start.',
              },
              'newEndTime': {
                'type': 'string',
                'description':
                    'New end time in 24-hour HH:mm format. Omit to keep current end.',
              },
            },
            'required': ['blockId'],
            // Note: At least one of newStartTime or newEndTime should be provided.
            // This is validated in the handler since JSON Schema anyOf is complex.
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: moveTimeBlock,
          description:
              'Move an existing time block to a new start time, preserving its duration. '
              'Use when the user wants to reschedule a block '
              '(e.g., "Move the exercise block to 7 AM", "Push the meeting to 3 PM").',
          parameters: {
            'type': 'object',
            'properties': {
              'blockId': {
                'type': 'string',
                'description':
                    'ID of the block to move. Get this from the Current Day Plan context.',
              },
              'newStartTime': {
                'type': 'string',
                'description': 'New start time in 24-hour HH:mm format. '
                    "The block's duration will be preserved (end time shifts accordingly).",
              },
            },
            'required': ['blockId', 'newStartTime'],
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: deleteTimeBlock,
          description: 'Delete an existing time block from the day plan. '
              'Use when the user wants to remove a scheduled block '
              '(e.g., "Remove the meeting", "Delete the exercise block").',
          parameters: {
            'type': 'object',
            'properties': {
              'blockId': {
                'type': 'string',
                'description':
                    'ID of the block to delete. Get this from the Current Day Plan context.',
              },
            },
            'required': ['blockId'],
          },
        ),
      ),
      const ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: linkTaskToDay,
          description: "Pin a task to today's plan for a specific category. "
              'Use when the user wants to commit to working on a task today '
              '(e.g., "Pin the API task", "Add the report task to today").',
          parameters: {
            'type': 'object',
            'properties': {
              'taskTitle': {
                'type': 'string',
                'description':
                    'Title or partial title of the task to search for. '
                        'Will match against open tasks using fuzzy search.',
              },
              'categoryName': {
                'type': 'string',
                'description':
                    'Optional category to pin the task to. If omitted, '
                        "uses the task's existing category or a default.",
              },
            },
            'required': ['taskTitle'],
          },
        ),
      ),
    ];
  }
}

/// Parses time strings defensively, handling various formats.
///
/// Supports:
/// - HH:mm format (e.g., "09:00", "14:30")
/// - H:mm format (e.g., "9:00")
/// - Plain hour (e.g., "9" -> 09:00)
///
/// Returns null if the time string cannot be parsed.
DateTime? parseTimeForDate(String timeStr, DateTime date) {
  final trimmed = timeStr.trim();

  // Try HH:mm or H:mm format first
  final hhmmMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
  if (hhmmMatch != null) {
    final hour = int.parse(hhmmMatch.group(1)!);
    final minute = int.parse(hhmmMatch.group(2)!);
    if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  }

  // Try plain hour (e.g., "9" -> 09:00)
  final hourOnly = int.tryParse(trimmed);
  if (hourOnly != null && hourOnly >= 0 && hourOnly < 24) {
    return DateTime(date.year, date.month, date.day, hourOnly);
  }

  return null;
}
