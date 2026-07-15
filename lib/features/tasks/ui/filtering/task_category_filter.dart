import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// Category branch shown on the journal filter overview.
///
/// The row summarizes the active category selection and navigates within the
/// owning Wolt route. It deliberately does not open another modal.
class TaskCategoryFilterOverviewRow extends ConsumerWidget {
  const TaskCategoryFilterOverviewRow({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final categories = getIt<EntitiesCacheService>().sortedCategories;
    final namesById = {
      for (final category in categories) category.id: category.name,
    };
    final selectedLabels = [
      for (final id in state.selectedCategoryIds)
        if (id.isEmpty)
          context.messages.taskCategoryUnassignedLabel
        else
          ?namesById[id],
    ];
    final summary = switch (selectedLabels) {
      [] => context.messages.taskCategoryAllLabel,
      [final only] => only,
      [final first, final second] => '$first, $second',
      [final first, final second, ...final rest] =>
        '$first, $second +${rest.length}',
    };
    final tokens = context.designTokens;

    return DesignSystemGroupedList(
      padding: EdgeInsets.zero,
      filled: false,
      children: [
        DesignSystemSelectionRow(
          title: stripTrailingColon(context.messages.taskCategoryLabel),
          subtitle: summary,
          leading: Icon(
            Icons.folder_outlined,
            size: tokens.spacing.step6,
            color: tokens.colors.text.mediumEmphasis,
          ),
          type: DesignSystemSelectionRowType.navigation,
          onTap: onPressed,
        ),
      ],
    );
  }
}

/// Searchable category selection page embedded in the journal filter route.
///
/// Category changes keep the journal's established immediate-apply behavior,
/// while the page itself is prebuilt with the overview so navigation never
/// waits on data or opens a nested route.
class TaskCategoryFilter extends ConsumerStatefulWidget {
  const TaskCategoryFilter({super.key});

  @override
  ConsumerState<TaskCategoryFilter> createState() => _TaskCategoryFilterState();
}

class _TaskCategoryFilterState extends ConsumerState<TaskCategoryFilter> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final categories = getIt<EntitiesCacheService>().sortedCategories;
    final showTasks = ref.watch(journalPageScopeProvider);
    final state = ref.watch(journalPageControllerProvider(showTasks));
    final controller = ref.read(
      journalPageControllerProvider(showTasks).notifier,
    );
    final tokens = context.designTokens;
    final query = _query.trim().toLowerCase();
    final visibleCategories = query.isEmpty
        ? categories
        : categories
              .where((category) => category.name.toLowerCase().contains(query))
              .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemSearch(
          hintText: context.messages.categorySearchPlaceholder,
          semanticsLabel: context.messages.categorySearchPlaceholder,
          onChanged: (value) => setState(() => _query = value),
          onClear: () => setState(() => _query = ''),
        ),
        SizedBox(height: tokens.spacing.step5),
        if (query.isEmpty) ...[
          DesignSystemSelectionRow(
            title: context.messages.taskCategoryAllLabel,
            type: DesignSystemSelectionRowType.singleSelect,
            selected: state.selectedCategoryIds.isEmpty,
            onTap: controller.selectedAllCategories,
          ),
          DesignSystemSelectionRow(
            title: context.messages.taskCategoryUnassignedLabel,
            type: DesignSystemSelectionRowType.multiSelect,
            selected: state.selectedCategoryIds.contains(''),
            onTap: () => controller.toggleSelectedCategoryIds(''),
          ),
        ],
        for (final category in visibleCategories)
          DesignSystemSelectionRow(
            title: category.name,
            leading: _CategoryDot(color: colorFromCssHex(category.color)),
            type: DesignSystemSelectionRowType.multiSelect,
            selected: state.selectedCategoryIds.contains(category.id),
            onTap: () => controller.toggleSelectedCategoryIds(category.id),
          ),
        if (visibleCategories.isEmpty)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
              child: Text(
                context.messages.filterSelectionNoMatches,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        SizedBox(height: tokens.spacing.step12),
      ],
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = context.designTokens.spacing.step3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
