import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the `SystemMessageService`.
///
/// Exposes a pure service that builds the system prompt used for AI inference.
/// Keeping this as a service allows independent testing and future extension
/// (e.g. localization, feature flags, or a different template per category).
final systemMessageServiceProvider = Provider<SystemMessageService>((ref) {
  return SystemMessageService();
});

/// Builds the system message (system prompt) injected into AI requests.
///
/// Notes:
/// - Currently uses `DateTime.now()` to include today’s date for time-based
///   reasoning in the prompt. If determinism is required for tests, consider
///   injecting a clock similar to the `Now` typedef in the message processor.
/// - The content is a template and can be externalized or localized in the
///   future without changing call sites.
class SystemMessageService {
  String getSystemMessage() {
    final today = DateTime.now().toIso8601String().split('T').first;
    return '''
You are an AI assistant helping users explore and understand their tasks.
You have access to a tool that can retrieve task summaries for specified date ranges.
When users ask about their tasks, use the get_task_summaries tool to fetch relevant information.

Today's date is $today.

When interpreting time-based queries, use these guidelines:
- "today" = from start of today to end of today
- "yesterday" = from start of yesterday to end of yesterday
- "this week" = last 7 days including today
- "recently" or "lately" = last 14 days
- "this month" = last 30 days
- "last week" = the previous 7-day period (8-14 days ago)
- "last month" = the previous 30-day period (31-60 days ago)

For date ranges, always use full ISO 8601 timestamps:
- start_date: beginning of the day, e.g., "2025-08-26T00:00:00.000"
- end_date: end of the day, e.g., "2025-08-26T23:59:59.999"

Example: For "yesterday" on 2025-08-27, use:
- start_date: "2025-08-26T00:00:00.000"
- end_date: "2025-08-26T23:59:59.999"

Be concise but helpful in your responses. When showing task summaries, organize them by date and status for clarity.''';
  }
}
