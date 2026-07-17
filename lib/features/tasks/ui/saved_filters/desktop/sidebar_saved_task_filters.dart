import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Stable keys for the desktop sidebar's saved-filter secondary navigation.
@visibleForTesting
abstract final class SidebarSavedTaskFiltersKeys {
  static const Key root = Key('sidebar-saved-task-filters');
  static const Key manage = Key('sidebar-saved-task-filters-manage');
  static const Key allTasks = Key('sidebar-saved-task-filters-all');
  static const Key showMore = Key('sidebar-saved-task-filters-show-more');
  static const Key showLess = Key('sidebar-saved-task-filters-show-less');
  static Key filter(String id) => Key('sidebar-saved-task-filter-$id');
}

/// Compact saved-filter navigation rendered beneath the active Tasks row.
///
/// The first five saved filters are visible by default in their persisted,
/// user-controlled order. More expands every remaining filter in place and
/// Show fewer restores the compact state. There is deliberately no pinning
/// model or upper limit: the sidebar itself scrolls, so users decide how much
/// vertical space their expanded filter list consumes.
class SidebarSavedTaskFilters extends ConsumerStatefulWidget {
  const SidebarSavedTaskFilters({super.key});

  static const int initialVisibleFilterCount = 5;

  @override
  ConsumerState<SidebarSavedTaskFilters> createState() =>
      _SidebarSavedTaskFiltersState();
}

class _SidebarSavedTaskFiltersState
    extends ConsumerState<SidebarSavedTaskFilters> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final saved =
        ref.watch(savedTaskFiltersControllerProvider).value ??
        const <SavedTaskFilter>[];
    if (saved.isEmpty) {
      return const SizedBox.shrink(key: SidebarSavedTaskFiltersKeys.root);
    }

    final activeId = ref.watch(currentSavedTaskFilterIdProvider);
    final hasUnsaved = ref.watch(tasksFilterHasUnsavedClausesProvider);
    final counts = ref.watch(savedTaskFilterCountsProvider).value;
    final total = ref.watch(allTasksTotalCountProvider).value;
    final allSelected = activeId == null && !hasUnsaved;
    final visible = _showAll
        ? saved
        : saved.take(SidebarSavedTaskFilters.initialVisibleFilterCount);
    final hiddenCount = saved.length - visible.length;

    return Padding(
      key: SidebarSavedTaskFiltersKeys.root,
      padding: EdgeInsetsDirectional.only(start: tokens.spacing.step5),
      child: Semantics(
        container: true,
        label: messages.tasksSavedFiltersGroupSemantics,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              onManage: () => showSavedTaskFiltersSheet(context),
            ),
            SizedBox(height: tokens.spacing.step1),
            _FilterRow(
              key: SidebarSavedTaskFiltersKeys.allTasks,
              label: messages.tasksSavedFiltersAllTasks,
              semanticsLabel: _semanticsLabel(
                messages.tasksSavedFiltersAllTasks,
                total,
              ),
              count: total,
              selected: allSelected,
              leading: const _AllTasksIcon(),
              onTap: () => unawaited(_applyAll()),
            ),
            for (final filter in visible)
              _FilterRow(
                key: SidebarSavedTaskFiltersKeys.filter(filter.id),
                label: filter.name,
                semanticsLabel: _semanticsLabel(
                  filter.name,
                  counts?[filter.id],
                  categoryName: savedFilterCategoryName(filter),
                ),
                count: counts?[filter.id],
                selected: filter.id == activeId,
                leading: _CategoryMarker(
                  color: savedFilterCategoryColor(filter),
                ),
                onTap: () => unawaited(_applySaved(filter)),
              ),
            if (hiddenCount > 0)
              _DisclosureRow(
                key: SidebarSavedTaskFiltersKeys.showMore,
                label: messages.tasksSavedFiltersShowMore(hiddenCount),
                icon: Icons.expand_more_rounded,
                onTap: () => setState(() => _showAll = true),
              )
            else if (_showAll &&
                saved.length >
                    SidebarSavedTaskFilters.initialVisibleFilterCount)
              _DisclosureRow(
                key: SidebarSavedTaskFiltersKeys.showLess,
                label: messages.tasksSavedFiltersShowLess,
                icon: Icons.expand_less_rounded,
                onTap: () => setState(() => _showAll = false),
              ),
          ],
        ),
      ),
    );
  }

  String _semanticsLabel(
    String name,
    int? count, {
    String? categoryName,
  }) {
    return [
      ?categoryName,
      name,
      if (count != null) context.messages.tasksSavedFiltersTaskCount(count),
    ].join(', ');
  }

  Future<void> _applySaved(SavedTaskFilter filter) async {
    final mru = ref.read(savedTaskFilterMruProvider.notifier);
    await SavedTaskFilterActivator(
      ref.read(journalPageControllerProvider(true).notifier),
    ).activate(filter);
    mru.touch(filter.id);
  }

  Future<void> _applyAll() {
    return SavedTaskFilterActivator(
      ref.read(journalPageControllerProvider(true).notifier),
    ).clearToDefault();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final actionRadius = BorderRadius.circular(tokens.radii.s);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.spacing.step4,
        end: tokens.spacing.step1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              messages.tasksSavedFiltersSheetTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
                fontWeight: tokens.typography.weight.semiBold,
              ),
            ),
          ),
          Tooltip(
            message: messages.tasksSavedFiltersManageTooltip,
            child: Semantics(
              button: true,
              label: messages.tasksSavedFiltersManageTooltip,
              child: ExcludeSemantics(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: actionRadius,
                  child: InkWell(
                    key: SidebarSavedTaskFiltersKeys.manage,
                    onTap: onManage,
                    borderRadius: actionRadius,
                    hoverColor: tokens.colors.surface.hover,
                    focusColor: tokens.colors.surface.focusPressed,
                    child: Padding(
                      padding: EdgeInsets.all(tokens.spacing.step2),
                      child: Icon(
                        Icons.tune_rounded,
                        size: tokens.spacing.step4,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.semanticsLabel,
    required this.count,
    required this.selected,
    required this.leading,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semanticsLabel;
  final int? count;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final rowRadius = BorderRadius.circular(tokens.radii.s);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: selected ? tokens.colors.surface.active : Colors.transparent,
            borderRadius: rowRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: rowRadius,
              hoverColor: tokens.colors.surface.hover,
              focusColor: tokens.colors.surface.focusPressed,
              child: Stack(
                children: [
                  if (selected)
                    PositionedDirectional(
                      start: 0,
                      top: tokens.spacing.step2,
                      bottom: tokens.spacing.step2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.colors.interactive.enabled,
                          borderRadius: BorderRadius.circular(tokens.radii.xs),
                        ),
                        child: SizedBox(width: tokens.spacing.step1),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: tokens.spacing.step4,
                      top: tokens.spacing.step2,
                      end: tokens.spacing.step3,
                      bottom: tokens.spacing.step2,
                    ),
                    child: Row(
                      children: [
                        leading,
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(
                          child: Tooltip(
                            message: label,
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: tokens.colors.text.highEmphasis,
                                    fontWeight: selected
                                        ? tokens.typography.weight.semiBold
                                        : null,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step2),
                        SavedFilterCountText(
                          count: count,
                          selected: selected,
                          minWidth: tokens.spacing.step6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllTasksIcon extends StatelessWidget {
  const _AllTasksIcon();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Icon(
      Icons.inbox_outlined,
      size: tokens.spacing.step4,
      color: tokens.colors.text.mediumEmphasis,
    );
  }
}

class _CategoryMarker extends StatelessWidget {
  const _CategoryMarker({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox.square(
      dimension: tokens.spacing.step4,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? tokens.colors.decorative.level02,
          ),
          child: SizedBox.square(dimension: tokens.spacing.step2),
        ),
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.s);

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            hoverColor: tokens.colors.surface.hover,
            focusColor: tokens.colors.surface.focusPressed,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.spacing.step4,
                top: tokens.spacing.step2,
                end: tokens.spacing.step3,
                bottom: tokens.spacing.step2,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: tokens.spacing.step4,
                    color: tokens.colors.interactive.enabled,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.interactive.enabled,
                        fontWeight: tokens.typography.weight.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
