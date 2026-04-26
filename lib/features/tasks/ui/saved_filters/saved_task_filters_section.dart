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
  static const Key emptyState = Key('saved-filters-empty-state');
  static const Key list = Key('saved-filters-list');
}

/// Renders the saved-filters subtree under the Tasks destination.
///
/// The section is rendered as a [SavedTaskFiltersSectionKeys.list] when at
/// least one filter is persisted, or a `SizedBox.shrink` otherwise. There is
/// no header — new filters are saved via the Save button in the Tasks Filter
/// modal, not from the sidebar.
class SavedTaskFiltersSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Column(
      key: SavedTaskFiltersSectionKeys.root,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small step1 (2px) breathing room above the first row, in lieu of
        // the previous "Saved filters" overline header — the rows live
        // immediately under the Tasks destination and need no extra label.
        SizedBox(height: tokens.spacing.step1),
        _ReorderableList(
          key: SavedTaskFiltersSectionKeys.list,
          items: list,
          activeId: activeId,
          counts: counts,
          onActivate: onActivate,
          onRename: (id, name) async {
            await ref
                .read(savedTaskFiltersControllerProvider.notifier)
                .rename(id, name);
          },
          onDelete: (id) async {
            await ref
                .read(savedTaskFiltersControllerProvider.notifier)
                .delete(id);
            onDeleted?.call();
          },
          onReorder: (dragId, targetId) async {
            await ref
                .read(savedTaskFiltersControllerProvider.notifier)
                .reorder(dragId, targetId);
          },
        ),
      ],
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
      onReorder: (oldIndex, newIndex) {
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
