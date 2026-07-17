import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Stable keys for the desktop task-view monitor band.
@visibleForTesting
abstract final class DesktopSavedTaskViewBarKeys {
  static const Key root = Key('desktop-saved-task-view-bar');
  static const Key currentView = Key('desktop-saved-task-current-view');
  static const Key allTasks = Key('desktop-saved-task-all-tasks');
  static const Key save = Key('desktop-saved-task-save');
  static Key monitor(String id) => Key('desktop-saved-task-monitor-$id');
}

/// Desktop task-local saved-view switcher and queue monitor.
///
/// The selected view is always the first control and opens the complete
/// saved-views sheet. The remaining controls form a stable watchlist: "All" as
/// the one-tap reset (when it is not already selected), followed by saved views
/// in their persisted order. Every control keeps its intrinsic width instead
/// of stretching across the task pane, while counts lead the watchlist labels
/// so queue magnitude remains scannable.
///
/// Saved order deliberately drives the watchlist instead of MRU order: recent
/// use is not evidence that a queue is important. Users change the order in the
/// sheet's Edit mode. The intrinsic control run scrolls horizontally when a
/// narrow pane or large text scale cannot fit the current view and monitors.
class DesktopSavedTaskViewBar extends ConsumerWidget {
  const DesktopSavedTaskViewBar({super.key});

  static const int maxMonitorButtons = 4;
  static const int maxMonitorButtonsWithSave = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final saved =
        ref.watch(savedTaskFiltersControllerProvider).value ??
        const <SavedTaskFilter>[];
    if (saved.isEmpty) {
      return const SizedBox.shrink(key: DesktopSavedTaskViewBarKeys.root);
    }

    final activeId = ref.watch(currentSavedTaskFilterIdProvider);
    final hasUnsaved = ref.watch(tasksFilterHasUnsavedClausesProvider);
    final counts = ref.watch(savedTaskFilterCountsProvider).value;
    final total = ref.watch(allTasksTotalCountProvider).value;
    final activeFilter = activeId == null
        ? null
        : saved.where((filter) => filter.id == activeId).firstOrNull;
    final allSelected = activeFilter == null && !hasUnsaved;
    final customCount = hasUnsaved
        ? ref.watch(currentTasksFilterCountProvider).value
        : null;

    final currentCount = switch ((activeFilter, hasUnsaved)) {
      (final filter?, _) => counts?[filter.id],
      (null, true) => customCount,
      (null, false) => total,
    };
    final current = _CurrentView(
      name:
          activeFilter?.name ??
          (hasUnsaved
              ? context.messages.tasksSavedFiltersCustom
              : context.messages.tasksSavedFiltersAllTasks),
      count: currentCount,
      categoryColor: activeFilter == null
          ? null
          : savedFilterCategoryColor(activeFilter),
      categoryName: activeFilter == null
          ? null
          : savedFilterCategoryName(activeFilter),
    );

    final monitorCandidates = <_Monitor>[
      if (!allSelected)
        _Monitor(
          key: DesktopSavedTaskViewBarKeys.allTasks,
          name: context.messages.tasksSavedFiltersAllShort,
          semanticsName: context.messages.tasksSavedFiltersAllTasks,
          count: total,
          onTap: () => _applyAll(ref),
        ),
      for (final filter in saved)
        if (filter.id != activeFilter?.id)
          _Monitor(
            key: DesktopSavedTaskViewBarKeys.monitor(filter.id),
            name: filter.name,
            semanticsName: filter.name,
            count: counts?[filter.id],
            categoryColor: savedFilterCategoryColor(filter),
            categoryName: savedFilterCategoryName(filter),
            onTap: () => _applySaved(ref, filter),
          ),
    ];

    final gap = SizedBox(width: tokens.spacing.step2);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step2,
      ),
      child: Semantics(
        container: true,
        label: context.messages.tasksSavedFiltersGroupSemantics,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final monitorLimit = _monitorLimitForWidth(
              tokens: tokens,
              available: constraints.maxWidth,
              hasUnsaved: hasUnsaved,
            );
            final monitors = monitorCandidates
                .take(monitorLimit)
                .toList(growable: false);
            return SingleChildScrollView(
              key: DesktopSavedTaskViewBarKeys.root,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: tokens.spacing.step13 + tokens.spacing.step9,
                    ),
                    child: _CurrentViewButton(current: current),
                  ),
                  for (final monitor in monitors) ...[
                    gap,
                    _MonitorButton(monitor: monitor),
                  ],
                  if (hasUnsaved) ...[
                    gap,
                    _SaveFilterButton(
                      onTap: () => promptSaveCurrentTaskFilter(context, ref),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _monitorLimitForWidth({
    required DsTokens tokens,
    required double available,
    required bool hasUnsaved,
  }) {
    final wideThreshold = tokens.spacing.step13 * 3;
    final mediumThreshold = tokens.spacing.step13 * 2;
    final widthLimit = available >= wideThreshold
        ? maxMonitorButtons
        : available >= mediumThreshold
        ? maxMonitorButtonsWithSave
        : 1;
    return hasUnsaved && widthLimit > maxMonitorButtonsWithSave
        ? maxMonitorButtonsWithSave
        : widthLimit;
  }

  Future<void> _applySaved(WidgetRef ref, SavedTaskFilter filter) async {
    await SavedTaskFilterActivator(
      ref.read(journalPageControllerProvider(true).notifier),
    ).activate(filter);
    ref.read(savedTaskFilterMruProvider.notifier).touch(filter.id);
  }

  Future<void> _applyAll(WidgetRef ref) {
    return SavedTaskFilterActivator(
      ref.read(journalPageControllerProvider(true).notifier),
    ).clearToDefault();
  }
}

class _CurrentView {
  const _CurrentView({
    required this.name,
    required this.count,
    this.categoryColor,
    this.categoryName,
  });

  final String name;
  final int? count;
  final Color? categoryColor;
  final String? categoryName;
}

class _CurrentViewButton extends StatelessWidget {
  const _CurrentViewButton({required this.current});

  final _CurrentView current;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final countClause = current.count == null
        ? null
        : messages.tasksSavedFiltersTaskCount(current.count!);
    final semanticsLabel = [
      messages.tasksSavedFiltersSheetTitle,
      ?current.categoryName,
      current.name,
      ?countClause,
    ].join(', ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactName =
            constraints.hasBoundedWidth &&
            constraints.maxWidth < tokens.spacing.step13 + tokens.spacing.step9;
        return Tooltip(
          message: current.name,
          child: Semantics(
            button: true,
            selected: true,
            label: semanticsLabel,
            onTap: () => showSavedTaskFiltersSheet(context),
            child: ExcludeSemantics(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: DesktopSavedTaskViewBarKeys.currentView,
                  borderRadius: radius,
                  onTap: () => showSavedTaskFiltersSheet(context),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minTarget),
                    child: Align(
                      widthFactor: 1,
                      child: DsPill(
                        variant: DsPillVariant.filled,
                        bordered: true,
                        selected: true,
                        leading: _CategoryDot(color: current.categoryColor),
                        labelWidget: _TaskViewLabel(
                          label: current.name,
                          selected: true,
                          preferTrailingSegment: compactName,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SavedFilterCountText(
                              count: current.count,
                              selected: true,
                              minWidth: tokens.spacing.step6,
                              prominent: true,
                            ),
                            SizedBox(width: tokens.spacing.step2),
                            Icon(
                              Icons.unfold_more_rounded,
                              size: tokens.spacing.step4,
                              color: tokens.colors.text.highEmphasis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Monitor {
  const _Monitor({
    required this.key,
    required this.name,
    required this.semanticsName,
    required this.count,
    required this.onTap,
    this.categoryColor,
    this.categoryName,
  });

  final Key key;
  final String name;
  final String semanticsName;
  final int? count;
  final VoidCallback onTap;
  final Color? categoryColor;
  final String? categoryName;
}

class _MonitorButton extends StatelessWidget {
  const _MonitorButton({required this.monitor});

  final _Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final countClause = monitor.count == null
        ? null
        : messages.tasksSavedFiltersTaskCount(monitor.count!);
    final semanticsLabel = [
      ?monitor.categoryName,
      monitor.semanticsName,
      ?countClause,
    ].join(', ');
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surface.enabled,
        borderRadius: radius,
        border: Border.all(color: tokens.colors.decorative.level02),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SavedFilterCountText(
              count: monitor.count,
              minWidth: tokens.spacing.step5,
              prominent: true,
            ),
            SizedBox(width: tokens.spacing.step2),
            if (monitor.categoryColor != null) ...[
              _CategoryDot(color: monitor.categoryColor),
              SizedBox(width: tokens.spacing.step2),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tokens.spacing.step12),
              child: _TaskViewLabel(
                label: monitor.name,
                preferTrailingSegment: true,
              ),
            ),
          ],
        ),
      ),
    );

    return Tooltip(
      message: monitor.semanticsName,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        onTap: monitor.onTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: monitor.key,
              borderRadius: radius,
              onTap: monitor.onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minTarget),
                child: Center(child: tile),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (color == null) {
      return Icon(
        Icons.filter_alt_outlined,
        size: tokens.spacing.step4,
        color: tokens.colors.text.mediumEmphasis,
      );
    }
    return Container(
      width: tokens.spacing.step3,
      height: tokens.spacing.step3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: tokens.colors.background.level01),
      ),
    );
  }
}

/// Preserves the meaningful trailing segment of names such as
/// "Lotti · Blocked" or "Lotti: Blocked" in a compact monitor. The status or
/// view segment is the scan target, while the category dot carries category
/// context when available. Tooltips and semantics retain the complete name.
class _TaskViewLabel extends StatelessWidget {
  const _TaskViewLabel({
    required this.label,
    this.selected = false,
    this.preferTrailingSegment = false,
  });

  final String label;
  final bool selected;
  final bool preferTrailingSegment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontWeight: selected ? FontWeight.w700 : null,
      height: 1,
    );
    final middleDot = label.lastIndexOf('·');
    final colon = label.lastIndexOf(':');
    final separator = middleDot > colon ? middleDot : colon;
    final visibleLabel =
        preferTrailingSegment && separator > 0 && separator < label.length - 1
        ? label.substring(separator + 1).trimLeft()
        : label;
    return Text(
      visibleLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _SaveFilterButton extends StatelessWidget {
  const _SaveFilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = context.messages.tasksSavedFiltersSaveButtonLabel;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final accent = tokens.colors.interactive.enabled;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: DesktopSavedTaskViewBarKeys.save,
              borderRadius: radius,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minTarget),
                child: Center(
                  child: DsPill(
                    variant: DsPillVariant.tinted,
                    color: accent,
                    label: label,
                    leading: Icon(
                      Icons.add_rounded,
                      size: tokens.spacing.step4,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
