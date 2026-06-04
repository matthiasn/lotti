import 'package:lotti/features/ai/model/ai_input.dart';

/// Renders the **current task state** as a compact markdown block for the
/// agent prompt's volatile tail — replacing the indented-JSON header whose
/// per-checklist-item objects spent ~9 lines (plus `null` noise) on a title,
/// a checkbox and an id.
///
/// State, not log: with compaction on (ADR 0017/0020), the task log is event
/// material rendered separately; this block carries only the mutable facts the
/// agent's tools need — status/priority, time, due date, labels, and the
/// checklist with the item ids the checklist tools take. `logEntries` on
/// [task] is ignored.
///
/// Pure function of its inputs; line rules are deterministic:
/// - `Estimate`/`Time spent` are omitted while they carry no information
///   (`00:00`), as is the whole line when both do;
/// - `Due`, `Language`, `Labels` and the suppressed-label line are omitted
///   when empty;
/// - a checklist item renders as `- [ ] title (id: …)` with `, due …`,
///   `, checked by …` (when completed) and `, archived` tags as applicable.
String renderTaskStateMarkdown(
  AiInputTaskObject task, {
  List<Map<String, String>> labels = const [],
  List<String> suppressedLabelIds = const [],
}) {
  final buffer = StringBuffer()
    ..writeln('- Title: ${task.title}')
    ..writeln('- Status: ${task.status} · Priority: ${task.priority}');

  final hasEstimate = task.estimatedDuration != '00:00';
  final hasTimeSpent = task.timeSpent != '00:00';
  if (hasEstimate || hasTimeSpent) {
    final parts = [
      if (hasEstimate) 'Estimate: ${task.estimatedDuration}',
      if (hasTimeSpent) 'Time spent: ${task.timeSpent}',
    ];
    buffer.writeln('- ${parts.join(' · ')}');
  }

  buffer.write('- Created: ${task.creationDate.toIso8601String()}');
  final dueDate = task.dueDate;
  if (dueDate != null) {
    buffer.write(' · Due: ${dueDate.toIso8601String()}');
  }
  buffer.writeln();

  final languageCode = task.languageCode;
  if (languageCode != null && languageCode.isNotEmpty) {
    buffer.writeln('- Language: $languageCode');
  }

  final labelNames = [
    for (final label in labels)
      if ((label['name'] ?? '').isNotEmpty) label['name']!,
  ];
  if (labelNames.isNotEmpty) {
    buffer.writeln('- Labels: ${labelNames.join(', ')}');
  }
  if (suppressedLabelIds.isNotEmpty) {
    buffer.writeln(
      '- AI-suppressed label ids: ${suppressedLabelIds.join(', ')}',
    );
  }

  if (task.actionItems.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('### Checklist');
    for (final item in task.actionItems) {
      buffer.writeln(_renderActionItem(item));
    }
  }

  return buffer.toString().trimRight();
}

String _renderActionItem(AiActionItem item) {
  final checkbox = item.completed ? '[x]' : '[ ]';
  final tags = [
    if (item.id != null) 'id: ${item.id}',
    if (item.deadline != null) 'due ${item.deadline!.toIso8601String()}',
    if (item.completed && item.checkedBy != null)
      'checked by ${item.checkedBy}',
    if (item.isArchived) 'archived',
  ];
  final suffix = tags.isEmpty ? '' : ' (${tags.join(', ')})';
  return '- $checkbox ${item.title}$suffix';
}
