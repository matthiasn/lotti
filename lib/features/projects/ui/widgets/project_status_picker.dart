import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// A tappable widget that shows the current project status and opens a
/// bottom sheet to choose from all five status variants.
class ProjectStatusPicker extends StatelessWidget {
  const ProjectStatusPicker({
    required this.currentStatus,
    required this.onStatusChanged,
    super.key,
  });

  final ProjectStatus currentStatus;
  final ValueChanged<ProjectStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = projectStatusAttributes(
      context,
      currentStatus,
    );

    return InkWell(
      onTap: () => _showStatusSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
          color: color.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusSheet(BuildContext context) {
    final messages = context.messages;

    ModalUtils.showBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    messages.projectStatusChangeTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                ...allProjectStatusKinds.map((kind) {
                  final representative = buildProjectStatus(
                    kind,
                    DateTime(2000),
                  );
                  final (label, color, icon) = projectStatusAttributes(
                    context,
                    representative,
                  );
                  final isSelected =
                      representative.runtimeType == currentStatus.runtimeType;

                  return ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: color)
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (!isSelected) {
                        onStatusChanged(buildProjectStatus(kind, clock.now()));
                      }
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
