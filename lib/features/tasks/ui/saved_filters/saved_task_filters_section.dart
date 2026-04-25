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
  static const Key header = Key('saved-filters-section-header');
  static const Key emptyState = Key('saved-filters-empty-state');
  static const Key list = Key('saved-filters-list');
  static const Key addButton = Key('saved-filters-add-button');
}

/// Renders the "Saved filters" subtree under the Tasks destination.
///
/// Composition:
/// - [SavedTaskFiltersSectionKeys.header] — overline label + add affordance
/// - either [SavedTaskFiltersSectionKeys.emptyState] (dashed pill) or
///   [SavedTaskFiltersSectionKeys.list] (reorderable rows)
class SavedTaskFiltersSection extends ConsumerWidget {
  const SavedTaskFiltersSection({
    required this.activeId,
    required this.onActivate,
    required this.onAddPressed,
    this.canAdd = false,
    this.counts,
    super.key,
  });

  /// id of the saved filter whose state currently matches the live filter,
  /// or null if no saved filter matches.
  final String? activeId;

  /// Called when the user taps a saved-filter row body. Receives the
  /// activated filter so the caller can apply it to the live page state.
  final ValueChanged<SavedTaskFilter> onActivate;

  /// Called when the `+` add affordance in the section header is tapped.
  /// Typically opens the Tasks Filter modal at the save-name popup.
  final VoidCallback onAddPressed;

  /// Whether the add affordance is enabled. Pass `true` only when there is
  /// an active filter that doesn't match any existing saved filter.
  final bool canAdd;

  /// Optional live counts keyed by saved-filter id. Missing ids are rendered
  /// without a count.
  final Map<String, int>? counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final asyncList = ref.watch(savedTaskFiltersControllerProvider);
    final list = asyncList.value ?? const <SavedTaskFilter>[];

    return Column(
      key: SavedTaskFiltersSectionKeys.root,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionHeader(
          title: messages.tasksSavedFiltersSectionTitle,
          tooltip: messages.tasksSavedFiltersAddTooltip,
          enabled: canAdd,
          onPressed: onAddPressed,
          tokens: tokens,
        ),
        if (list.isEmpty)
          Padding(
            key: SavedTaskFiltersSectionKeys.emptyState,
            padding: const EdgeInsetsDirectional.only(
              start: 30,
              end: 8,
              top: 4,
              bottom: 4,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: tokens.colors.surface.enabled,
                borderRadius: BorderRadius.circular(tokens.radii.m),
                border: Border.all(
                  color: tokens.colors.decorative.level01,
                ),
              ),
              child: Text(
                messages.tasksSavedFiltersEmpty,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                  height: 1.4,
                ),
              ),
            ),
          )
        else
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    required this.tokens,
  });

  final String title;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: SavedTaskFiltersSectionKeys.header,
      padding: const EdgeInsetsDirectional.only(
        start: 30,
        end: 12,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: tokens.typography.styles.others.overline.copyWith(
                color: tokens.colors.text.lowEmphasis,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
          Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 18,
              height: 18,
              child: Material(
                key: SavedTaskFiltersSectionKeys.addButton,
                color: enabled
                    ? tokens.colors.surface.selected
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(tokens.radii.s),
                child: InkWell(
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                  onTap: enabled ? onPressed : null,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 12,
                      color: enabled
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.lowEmphasis
                              .withValues(alpha: 0.5),
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
        return SavedTaskFilterRow(
          key: ValueKey(view.id),
          view: view,
          active: view.id == activeId,
          count: counts?[view.id],
          onActivate: () => onActivate(view),
          onRename: (name) => onRename(view.id, name),
          onDelete: () => onDelete(view.id),
          dragHandle: ReorderableDragStartListener(
            index: index,
            child: const Icon(
              Icons.drag_indicator,
              size: 14,
            ),
          ),
        );
      },
    );
  }
}
