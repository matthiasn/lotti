import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/utils/date_utils_extension.dart';

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
    final now = DateTime.now();
    final today = now.ymd;
    final tzName = now.timeZoneName;

    // Local date helpers
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final todayDate = dateOnly(now);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    // Week definition: default Monday–Sunday if locale not available here
    const firstDayOfWeek = DateTime.monday; // 1
    final delta = (todayDate.weekday - firstDayOfWeek + 7) % 7;
    final weekStart = todayDate.subtract(Duration(days: delta));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = lastWeekStart.add(const Duration(days: 6));

    // Month boundaries
    final thisMonthStart = DateTime(todayDate.year, todayDate.month);
    final thisMonthEnd = DateTime(todayDate.year, todayDate.month + 1, 0);
    final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));
    final lastMonthStart = DateTime(lastMonthEnd.year, lastMonthEnd.month);

    // Recently = last 14 local days inclusive
    final recentlyStart = todayDate.subtract(const Duration(days: 13));

    String j(DateTime d) => d.ymd;

    return '''
You are an AI assistant helping users explore and understand their tasks.
Use the get_task_summaries tool to fetch data for specific local date ranges.

Today (local) is $today in timezone "$tzName".

Argument contract for tool calls:
- Provide BOTH parameters: start_date and end_date.
- Format: date-only strings YYYY-MM-DD (no time, no timezone).
- App treats them as local dates and converts to UTC internally.

Error handling and retry behavior:
- The tool may return an error JSON, e.g. {"error": "..."}.
- If an error occurs (missing fields, invalid format, end < start), correct inputs and try again.

Definitions (user local time):
- "today" = [${j(todayDate)}, ${j(todayDate)}]
- "yesterday" = [${j(yesterdayDate)}, ${j(yesterdayDate)}]
- "this week" = current calendar week (default Monday–Sunday): [${j(weekStart)}, ${j(weekEnd)}]
- "last week" = previous calendar week: [${j(lastWeekStart)}, ${j(lastWeekEnd)}]
- "this month" = [${j(thisMonthStart)}, ${j(thisMonthEnd)}]
- "last month" = [${j(lastMonthStart)}, ${j(lastMonthEnd)}]
- "recently" or "lately" = last 14 local days inclusive: [${j(recentlyStart)}, ${j(todayDate)}]

Send concrete date-only JSON like:
{"start_date":"${j(yesterdayDate)}","end_date":"${j(yesterdayDate)}","limit":100}

Be concise but helpful. When showing task summaries, organize them by date and status for clarity.''';
  }
}
