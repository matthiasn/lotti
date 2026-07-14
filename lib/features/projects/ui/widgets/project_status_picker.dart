import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Opens the adaptive project-status picker.
///
/// The same Wolt route renders as a bottom sheet on compact widths and a dialog
/// on larger widths. A `null` result means the flow was dismissed or the
/// already-selected status was chosen.
Future<ProjectStatus?> showProjectStatusPickerModal({
  required BuildContext context,
  required ProjectStatus currentStatus,
}) {
  return ModalUtils.showSinglePageModal<ProjectStatus>(
    context: context,
    title: context.messages.projectStatusChangeTitle,
    padding: EdgeInsets.zero,
    builder: (modalContext) => ProjectStatusModalContent(
      currentStatus: currentStatus,
    ),
  );
}

/// Shared full-width option list for choosing a project status.
class ProjectStatusModalContent extends StatelessWidget {
  const ProjectStatusModalContent({
    required this.currentStatus,
    super.key,
  });

  final ProjectStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final kind in allProjectStatusKinds)
            Builder(
              builder: (context) {
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

                return DesignSystemSelectionRow(
                  key: ValueKey('project-status-${kind.name}'),
                  title: label,
                  type: DesignSystemSelectionRowType.singleSelect,
                  selected: isSelected,
                  leading: Icon(
                    icon,
                    color: color,
                    size: tokens.spacing.step6,
                  ),
                  onTap: () => Navigator.of(context).pop(
                    isSelected ? null : buildProjectStatus(kind, clock.now()),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A tappable row showing the current status and opening the shared picker.
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
    final tokens = context.designTokens;
    final (label, color, icon) = projectStatusAttributes(
      context,
      currentStatus,
    );

    return DesignSystemSelectionRow(
      title: label,
      type: DesignSystemSelectionRowType.navigation,
      leading: Icon(
        icon,
        color: color,
        size: tokens.spacing.step6,
      ),
      onTap: () => _showStatusPicker(context),
    );
  }

  Future<void> _showStatusPicker(BuildContext context) async {
    final selected = await showProjectStatusPickerModal(
      context: context,
      currentStatus: currentStatus,
    );
    if (selected != null) {
      onStatusChanged(selected);
    }
  }
}
