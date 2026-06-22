import 'package:lotti/features/agents/model/change_set.dart';

/// Builds the [ChangeItem]s for a pending change set from a strategy's
/// accumulated deferred tool calls.
///
/// Each accumulated entry is a `{'toolName': ..., 'args': ...}` map; [humanSummary]
/// renders the user-facing label per item. Shared by the event and project
/// workflows, which accumulate deferred proposals in the same shape and differ
/// only in how they summarize a tool call.
List<ChangeItem> buildDeferredChangeItems(
  List<Map<String, dynamic>> deferredItems,
  String Function(String toolName, Map<String, dynamic> args) humanSummary,
) {
  return deferredItems.map((item) {
    final toolName = item['toolName'] as String? ?? '';
    final args = item['args'] as Map<String, dynamic>? ?? {};
    return ChangeItem(
      toolName: toolName,
      args: args,
      humanSummary: humanSummary(toolName, args),
    );
  }).toList();
}
