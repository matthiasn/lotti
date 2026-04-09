import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/utils.dart';

/// Modal body for selecting a task status.
///
/// Renders all statuses as a vertical list of tappable rows — icon, label,
/// and a trailing checkmark on the currently-selected row.  The design
/// adapts to small screens (bottom sheet) and large screens (centred dialog)
/// via `ModalUtils.showSinglePageModal` / `ModalUtils.modalTypeBuilder` at
/// the call site.
///
/// Tapping a row calls [Navigator.pop] with the selected status string so the
/// caller can handle the state update.
///
/// The [labelResolver] parameter can be injected in tests to avoid a
/// full-localisation context.
class TaskStatusModalContent extends StatelessWidget {
  const TaskStatusModalContent({
    required this.task,
    this.labelResolver,
    super.key,
  });

  final Task task;

  /// Resolves the display label for a status string.
  /// Falls back to [taskLabelFromStatusString] when not provided.
  final String Function(String status, BuildContext context)? labelResolver;

  @override
  Widget build(BuildContext context) {
    final currentStatus = task.data.status.toDbString;
    final resolveLabel = labelResolver ?? taskLabelFromStatusString;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: allTaskStatuses.map((status) {
        final isSelected = status == currentStatus;
        final statusColor = taskColorFromStatusString(
          status,
          brightness: brightness,
        );
        final icon = taskIconFromStatusString(status);
        final label = resolveLabel(status, context);

        return Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: InkWell(
            onTap: () => Navigator.pop(context, status),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: statusColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
