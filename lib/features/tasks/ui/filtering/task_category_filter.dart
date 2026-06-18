import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

/// Category filter section for the logbook filter sheet.
///
/// Renders selectable design-system choice pills for favorite and
/// currently-selected categories (each prefixed with its color dot) plus
/// "unassigned" and "all" options; the trailing `...` chip expands the list to
/// show every category. Toggling a chip updates the active journal page
/// controller's `selectedCategoryIds`.
class TaskCategoryFilter extends ConsumerStatefulWidget {
  const TaskCategoryFilter({super.key});

  @override
  ConsumerState<TaskCategoryFilter> createState() => _TaskCategoryFilterState();
}

class _TaskCategoryFilterState extends ConsumerState<TaskCategoryFilter> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final categories = getIt<EntitiesCacheService>().sortedCategories;

    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );

    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final textStyle = tokens.typography.styles.body.bodyMedium;

    final filteredCategories = _showAll
        ? categories
        : categories.where((category) {
            final isSelected = state.selectedCategoryIds.contains(category.id);
            return (category.favorite ?? false) || isSelected;
          }).toList();

    // Show at least the unassigned filter even when no categories exist
    // This improves onboarding experience

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: tokens.spacing.step4),
        Text(
          stripTrailingColon(context.messages.taskCategoryLabel),
          style: tokens.typography.styles.others.caption.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            ...filteredCategories.map((category) {
              final isSelected = state.selectedCategoryIds.contains(
                category.id,
              );
              return DesignSystemFilterChoicePill(
                label: category.name,
                selected: isSelected,
                palette: palette,
                textStyle: textStyle,
                leading: _CategoryDot(color: colorFromCssHex(category.color)),
                onTap: () => controller.toggleSelectedCategoryIds(category.id),
              );
            }),
            DesignSystemFilterChoicePill(
              label: context.messages.taskCategoryUnassignedLabel,
              selected: state.selectedCategoryIds.contains(''),
              palette: palette,
              textStyle: textStyle,
              onTap: () => controller.toggleSelectedCategoryIds(''),
            ),
            DesignSystemFilterChoicePill(
              label: context.messages.taskCategoryAllLabel,
              selected: state.selectedCategoryIds.isEmpty,
              palette: palette,
              textStyle: textStyle,
              onTap: controller.selectedAllCategories,
            ),
            if (!_showAll)
              DesignSystemFilterChoicePill(
                label: '...',
                selected: false,
                palette: palette,
                textStyle: textStyle,
                onTap: () => setState(() {
                  _showAll = !_showAll;
                }),
              ),
          ],
        ),
      ],
    );
  }
}

/// Small filled circle showing a category's color, used as the leading element
/// of a category filter pill.
class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
