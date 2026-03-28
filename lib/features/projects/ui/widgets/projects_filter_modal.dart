import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/model/projects_filter_sheet_state.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';

Future<void> showProjectsFilterModal({
  required BuildContext context,
  required ProjectsFilter initialFilter,
  required List<CategoryDefinition> categories,
  required ValueChanged<ProjectsFilter> onApplied,
  required DesignSystemFilterPresentation presentation,
}) {
  return showDesignSystemFilterModal(
    context: context,
    initialState: buildProjectsFilterSheetState(
      context,
      filter: initialFilter,
      categories: categories,
      showDragHandle: presentation == DesignSystemFilterPresentation.mobile,
    ),
    onApplied: (sheetState) {
      onApplied(
        projectsFilterFromSheetState(
          sheetState,
          baseFilter: initialFilter,
        ),
      );
    },
    presentation: presentation,
    onFieldPressed: (sheetContext, draftState, section) async {
      switch (section) {
        case DesignSystemTaskFilterSection.status:
          return showDesignSystemTaskFilterFieldSelectionModal(
            context: sheetContext,
            draftState: draftState,
            section: section,
            presentation: presentation,
            appearanceResolver: (optionId) {
              final kind = projectStatusKindFromFilterId(optionId);
              final status = buildProjectStatus(kind, DateTime(2000));
              final (_, color, icon) = projectStatusAttributes(
                sheetContext,
                status,
              );
              return DesignSystemFilterSelectionOptionAppearance(
                icon: icon,
                foregroundColor: color,
              );
            },
          );
        case DesignSystemTaskFilterSection.category:
          return showDesignSystemTaskFilterFieldSelectionModal(
            context: sheetContext,
            draftState: draftState,
            section: section,
            presentation: presentation,
          );
        case DesignSystemTaskFilterSection.label:
          return null;
      }
    },
  );
}
