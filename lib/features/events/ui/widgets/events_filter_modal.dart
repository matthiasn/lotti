import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the Events filter on top of the shared design-system filter sheet —
/// the same adaptive modal, category page and Clear/Apply footer the Tasks and
/// Projects tabs use, with only the category section populated.
///
/// Hands the applied category selection to [onApplied]; `''` in it stands for
/// events without a category. Dismissing the modal applies nothing.
Future<void> showEventsFilterModal({
  required BuildContext context,
  required Set<String> selectedCategoryIds,
  required List<CategoryDefinition> categories,
  required ValueChanged<Set<String>> onApplied,
}) {
  return showDesignSystemFilterModal(
    context: context,
    initialState: buildEventsFilterSheetState(
      context,
      selectedCategoryIds: selectedCategoryIds,
      categories: categories,
    ),
    onApplied: (sheetState) => onApplied(
      sheetState.categoryField?.selectedIds ?? const <String>{},
    ),
    fieldPageConfigs: {
      DesignSystemTaskFilterSection.category: DesignSystemFilterFieldPageConfig(
        searchHintText: context.messages.categorySearchPlaceholder,
      ),
    },
  );
}

/// Adapts the Events category selection into the filter-sheet model.
///
/// Options mirror the Tasks filter — "Unassigned" first, then each category
/// with its own icon and colour — and the selection is intersected with the
/// options present, so a category deleted since it was picked drops out
/// instead of narrowing the list invisibly.
DesignSystemTaskFilterState buildEventsFilterSheetState(
  BuildContext context, {
  required Set<String> selectedCategoryIds,
  required Iterable<CategoryDefinition> categories,
}) {
  final messages = context.messages;
  final options = [
    DesignSystemTaskFilterOption(
      id: '',
      label: messages.tasksQuickFilterUnassignedLabel,
    ),
    for (final category in categories)
      DesignSystemTaskFilterOption(
        id: category.id,
        label: category.name,
        icon: category.icon?.iconData,
        iconColor: colorFromCssHex(category.color),
      ),
  ];
  final optionIds = options.map((option) => option.id).toSet();

  return DesignSystemTaskFilterState(
    title: messages.eventsFilterTooltip,
    clearAllLabel: messages.clearButton,
    applyLabel: messages.tasksLabelsSheetApply,
    categoryField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(messages.taskCategoryLabel),
      options: options,
      selectedIds: selectedCategoryIds.intersection(optionIds),
    ),
  );
}
