import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;
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

        return Padding(
          // Inset each row so its hover/selection highlight is a rounded,
          // contained shape rather than a sharp edge-to-edge band. Matches the
          // shared EntityPickerSheet rows (inset step3, radii.l) so the status
          // / priority / label pickers read as one consistent family.
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step1,
          ),
          child: Semantics(
            button: true,
            selected: isSelected,
            label: label,
            child: InkWell(
              onTap: () => Navigator.pop(context, status),
              borderRadius: BorderRadius.circular(tokens.radii.l),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step4,
                ),
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
          ),
        );
      }).toList(),
    );
  }
}
