import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Opens the shared calendar to set, change, or clear a task's due date.
///
/// Dismissal leaves the task unchanged. Done always confirms the selected date,
/// including today's date when the task did not previously have a due date.
Future<void> showDueDatePicker({
  required BuildContext context,
  required DateTime? initialDate,
  required Future<void> Function(DateTime? newDate) onDueDateChanged,
}) async {
  final now = DateTime.now();
  final result = await showDesignSystemDatePicker(
    context: context,
    title: context.messages.taskDueDateLabel,
    initialDate: initialDate ?? now,
    firstDate: DateTime(1900),
    lastDate: DateTime(2100),
    allowClear: initialDate != null,
  );

  if (result == null) return;
  if (result.cleared) {
    await onDueDateChanged(null);
    return;
  }
  if (initialDate != null && _sameDate(initialDate, result.date!)) return;
  await onDueDateChanged(result.date);
}

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
