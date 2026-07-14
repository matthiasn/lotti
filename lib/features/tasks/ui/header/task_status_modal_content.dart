import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    final brightness = Theme.of(context).brightness;
    final tokens = context.designTokens;

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

        return DesignSystemSelectionRow(
          key: ValueKey('task-status-$status'),
          title: label,
          type: DesignSystemSelectionRowType.singleSelect,
          selected: isSelected,
          leading: Icon(
            icon,
            color: statusColor,
            size: tokens.spacing.step6,
          ),
          onTap: () => Navigator.pop(context, status),
        );
      }).toList(),
    );
  }
}
