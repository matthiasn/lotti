import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Stable test keys for the saved-filters section.
@visibleForTesting
class SavedTaskFiltersSectionKeys {
  const SavedTaskFiltersSectionKeys._();

  static const Key root = Key('saved-filters-section');
  static const Key header = Key('saved-filters-header');
  static const Key list = Key('saved-filters-list');
  static const Key moreButton = Key('saved-filters-more-button');
}

/// Renders the saved-filters subtree under the Tasks destination.
///
/// The section is rendered as a [SavedTaskFiltersSectionKeys.list] when at
/// least one filter is persisted, or a `SizedBox.shrink` otherwise. New filters
/// are saved via the Save button in the Tasks Filter modal, not from the
/// sidebar. The desktop rail deliberately shows only a small working set: the
/// sidebar is navigation first while collapsed, but the "more" row expands to
/// every saved filter so it never advertises hidden items the user cannot
/// reveal.
const int kDesktopSavedTaskFiltersCollapsedLimit = 4;

class SavedTaskFiltersSection extends ConsumerStatefulWidget {
  const SavedTaskFiltersSection({
    required this.activeId,
    required this.onActivate,
    this.counts,
    this.onDeleted,
    super.key,
  });

  /// id of the saved filter whose state currently matches the live filter,
  /// or null if no saved filter matches.
  final String? activeId;

  /// Called when the user taps a saved-filter row body. Receives the
  /// activated filter so the caller can apply it to the live page state.
  final ValueChanged<SavedTaskFilter> onActivate;

  /// Optional live counts keyed by saved-filter id. Missing ids are rendered
  /// without a count.
  final Map<String, int>? counts;

  /// Fired after a saved filter is deleted. The caller typically uses this to
  /// show a transient confirmation toast — the section itself only handles
  /// the controller mutation.
  final VoidCallback? onDeleted;

  @override
  ConsumerState<SavedTaskFiltersSection> createState() =>
      _SavedTaskFiltersSectionState();
}

class _SavedTaskFiltersSectionState
    extends ConsumerState<SavedTaskFiltersSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final asyncList = ref.watch(savedTaskFiltersControllerProvider);
    // Treat loading and error states as "no data yet" so the section header
    // renders without flashing the empty state. Once data resolves, the body
    // switches between empty state and list.
    final list = asyncList.value;

    // Hide the section entirely while the data is loading or when there are
    // no saved filters — the user reaches the save flow through the Tasks
    // Filter modal, so an empty placeholder in the sidebar adds noise
    // without value.
    if (list == null || list.isEmpty) {
      return const SizedBox.shrink(key: SavedTaskFiltersSectionKeys.root);
    }
    final visibleItems = _visibleItems(list);

    return Column(
      key: SavedTaskFiltersSectionKeys.root,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          key: SavedTaskFiltersSectionKeys.header,
          padding: EdgeInsetsDirectional.only(
            start: tokens.spacing.step5,
            end: tokens.spacing.step3,
            bottom: tokens.spacing.step2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.messages.tasksSavedFiltersSheetTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${list.length}',
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _ReorderableList(
          key: SavedTaskFiltersSectionKeys.list,
          items: visibleItems,
          activeId: widget.activeId,
          counts: widget.counts,
          onActivate: widget.onActivate,
          onRename: (id, name) async {
            await ref
                .read(savedTaskFiltersControllerProvider.notifier)
                .rename(id, name);
          },
          onDelete: (id) async {
            await ref
                .read(savedTaskFiltersControllerProvider.notifier)
                .delete(id);
            widget.onDeleted?.call();
          },
          onReorder: (dragId, targetId) async {
            await ref
                .read(savedTaskFiltersControllerProvider.notifier)
                .reorder(dragId, targetId);
          },
        ),
        if (list.length > kDesktopSavedTaskFiltersCollapsedLimit)
          _SavedFiltersMoreButton(
            hiddenCount: list.length - visibleItems.length,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }

  List<SavedTaskFilter> _visibleItems(List<SavedTaskFilter> list) {
    if (list.length <= kDesktopSavedTaskFiltersCollapsedLimit) {
      return list;
    }

    if (_expanded) return list;

    const limit = kDesktopSavedTaskFiltersCollapsedLimit;
    final visible = list.take(limit).toList();
    final activeId = widget.activeId;
    if (activeId == null || visible.any((item) => item.id == activeId)) {
      return visible;
    }

    SavedTaskFilter? active;
    for (final item in list) {
      if (item.id == activeId) {
        active = item;
        break;
      }
    }
    if (active == null) return visible;
    return [
      ...visible.take(limit - 1),
      active,
    ];
  }
}

class _SavedFiltersMoreButton extends StatelessWidget {
  const _SavedFiltersMoreButton({
    required this.hiddenCount,
    required this.expanded,
    required this.onTap,
  });

  final int hiddenCount;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = expanded
        ? [
            context.messages.tasksSavedFiltersShowLess,
            if (hiddenCount > 0)
              context.messages.tasksSavedFiltersShowMore(hiddenCount),
          ].join(' · ')
        : context.messages.tasksSavedFiltersShowMore(hiddenCount);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.spacing.step2,
        top: tokens.spacing.step1,
      ),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: InkWell(
            key: SavedTaskFiltersSectionKeys.moreButton,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step3,
              ),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                        fontWeight: FontWeight.w600,
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

class _ReorderableList extends StatelessWidget {
  const _ReorderableList({
    required this.items,
    required this.activeId,
    required this.counts,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
    required this.onReorder,
    super.key,
  });

  final List<SavedTaskFilter> items;
  final String? activeId;
  final Map<String, int>? counts;
  final ValueChanged<SavedTaskFilter> onActivate;
  final void Function(String id, String name) onRename;
  final ValueChanged<String> onDelete;
  final void Function(String dragId, String targetId) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) {
        var adjusted = newIndex;
        if (newIndex > oldIndex) adjusted = newIndex - 1;
        if (adjusted == oldIndex) return;
        final dragId = items[oldIndex].id;
        final targetId = items[adjusted].id;
        onReorder(dragId, targetId);
      },
      proxyDecorator: (child, index, animation) => Material(
        type: MaterialType.transparency,
        child: child,
      ),
      itemBuilder: (context, index) {
        final view = items[index];
        // step2 (4px) breathing room between rows; the last row also gets it
        // so the section has a small trailing gap before whatever follows in
        // the sidebar column.
        final tokens = context.designTokens;
        return Padding(
          key: ValueKey(view.id),
          padding: EdgeInsetsDirectional.only(bottom: tokens.spacing.step2),
          child: SavedTaskFilterRow(
            view: view,
            active: view.id == activeId,
            count: counts?[view.id],
            onActivate: () => onActivate(view),
            onRename: (name) => onRename(view.id, name),
            onDelete: () => onDelete(view.id),
            dragHandle: Semantics(
              button: true,
              label: context.messages.tasksSavedFilterDragHandleSemantics,
              child: ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_indicator,
                  size: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
