import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_shared_widgets.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Key attached to the in-modal search input so tests (and semantics probes)
/// can locate it without depending on its position in the widget tree.
const Key checklistFullListModalSearchFieldKey = Key(
  'checklistFullListModalSearchField',
);

/// Key attached to the in-modal add-item input.
const Key checklistFullListModalAddFieldKey = Key(
  'checklistFullListModalAddField',
);

/// Full-list modal bottom sheet for checklists longer than
/// [maxVisibleChecklistItems].
///
/// Opened from `ChecklistCard._Body` when the user taps the "View all"
/// button. Renders the checklist title, the progress counter, a search
/// input that narrows items by title, the same Open/Done/All filter strip
/// used by the inline card body, the full reorderable item list (when no
/// search filter is active), and an add-item field pinned above the
/// keyboard.
///
/// State responsibilities:
/// - **Item ids** are derived live from [checklistControllerProvider] so
///   external sync, deletes, or sibling additions reflect immediately while
///   the sheet is open.
/// - **Filter** is held locally and forwarded to the parent card via
///   [onFilterChanged] so the inline card stays in sync.
/// - **Create / reorder** delegate to parent-supplied callbacks; the parent
///   is the single owner of the in-flight create lock so the inline card
///   and the modal cannot double-submit.
class ChecklistFullListModal extends ConsumerStatefulWidget {
  const ChecklistFullListModal({
    required this.checklistId,
    required this.taskId,
    required this.title,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.initialFilter,
    required this.onCreateItem,
    required this.onReorder,
    required this.onFilterChanged,
    super.key,
  });

  final String checklistId;
  final String taskId;
  final String title;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final ChecklistFilter initialFilter;

  /// Called when a new item is submitted from the add-item field. The parent
  /// owns the in-flight guard and persistence; the modal only forwards the
  /// trimmed title.
  final Future<String?> Function(String?) onCreateItem;

  /// Called after a within-list reorder to persist the new order. The list
  /// passed here is the full absolute order (modal does not allow reorder
  /// while a search filter is active).
  final Future<void> Function(List<String>) onReorder;

  /// Called whenever the user changes the filter tab so the parent card
  /// stays in sync with the modal selection.
  final ValueChanged<ChecklistFilter> onFilterChanged;

  /// Opens this modal as a scroll-controlled bottom sheet so it can grow up
  /// to the safe-area height for long lists. The sheet dismisses on the
  /// standard bottom-sheet drag-down / barrier tap.
  static Future<void> show({
    required BuildContext context,
    required String checklistId,
    required String taskId,
    required String title,
    required int completedCount,
    required int totalCount,
    required double completionRate,
    required ChecklistFilter initialFilter,
    required Future<String?> Function(String?) onCreateItem,
    required Future<void> Function(List<String>) onReorder,
    required ValueChanged<ChecklistFilter> onFilterChanged,
  }) {
    final tokens = context.designTokens;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokens.colors.background.level01,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.l),
        ),
      ),
      builder: (context) => ChecklistFullListModal(
        checklistId: checklistId,
        taskId: taskId,
        title: title,
        completedCount: completedCount,
        totalCount: totalCount,
        completionRate: completionRate,
        initialFilter: initialFilter,
        onCreateItem: onCreateItem,
        onReorder: onReorder,
        onFilterChanged: onFilterChanged,
      ),
    );
  }

  @override
  ConsumerState<ChecklistFullListModal> createState() =>
      _ChecklistFullListModalState();
}

class _ChecklistFullListModalState
    extends ConsumerState<ChecklistFullListModal> {
  late ChecklistFilter _filter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FocusNode _addFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  /// Reads the current authoritative item-id list from the checklist
  /// controller. The modal never caches this list — every build derives it
  /// fresh so external mutations (sync, delete, cross-checklist drops) are
  /// reflected without the modal having to listen for them itself.
  List<String> _readItemIds() {
    return ref
            .watch(
              checklistControllerProvider((
                id: widget.checklistId,
                taskId: widget.taskId,
              )),
            )
            .value
            ?.data
            .linkedChecklistItems ??
        const <String>[];
  }

  /// Returns the items that should currently render. When the search query
  /// is empty, this is every item in order with no per-item provider reads.
  ///
  /// When a search is active, item titles are read via `ref.watch` so that
  /// (a) `autoDispose` providers for items that are not currently rendered
  /// stay alive long enough to deliver their first `AsyncData`, and (b) the
  /// modal rebuilds if a watched title changes mid-search. The watch cost
  /// is bounded by the open-modal lifetime — when the search query goes
  /// back to empty, the next build won't call watch and the subscriptions
  /// release.
  List<({int absoluteIndex, String itemId})> _computeVisibleItems(
    List<String> itemIds,
  ) {
    if (_searchQuery.isEmpty) {
      return [
        for (var i = 0; i < itemIds.length; i++)
          (absoluteIndex: i, itemId: itemIds[i]),
      ];
    }
    final results = <({int absoluteIndex, String itemId})>[];
    for (var i = 0; i < itemIds.length; i++) {
      final id = itemIds[i];
      final item = ref
          .watch(
            checklistItemControllerProvider((id: id, taskId: widget.taskId)),
          )
          .value;
      final title = item?.data.title.toLowerCase() ?? '';
      if (title.contains(_searchQuery)) {
        results.add((absoluteIndex: i, itemId: id));
      }
    }
    return results;
  }

  Future<bool> _handleSubmit(String value) async {
    final newId = await widget.onCreateItem(value);
    if (newId == null) return false;
    if (mounted && context.mounted) {
      scheduleChecklistAddFieldFocus(context, _addFocusNode);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final mediaQuery = MediaQuery.of(context);
    final keyboardPadding = mediaQuery.viewInsets.bottom;
    final itemIds = _readItemIds();
    final visible = _computeVisibleItems(itemIds);
    final searchActive = _searchQuery.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardPadding),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DragHandle(tokens: tokens),
            _TitleRow(
              title: widget.title,
              completedCount: widget.completedCount,
              totalCount: widget.totalCount,
              completionRate: widget.completionRate,
              tokens: tokens,
            ),
            SizedBox(height: tokens.spacing.step3),
            _SearchField(
              controller: _searchController,
              tokens: tokens,
            ),
            SizedBox(height: tokens.spacing.step3),
            ChecklistFilterStrip(
              filter: _filter,
              onFilterChanged: (next) {
                setState(() => _filter = next);
                widget.onFilterChanged(next);
              },
            ),
            Flexible(
              child: _ItemList(
                checklistId: widget.checklistId,
                taskId: widget.taskId,
                visible: visible,
                filter: _filter,
                tokens: tokens,
                searchActive: searchActive,
                itemIds: itemIds,
                onReorder: (newIds) => widget.onReorder(newIds),
              ),
            ),
            ChecklistAddItemField(
              key: checklistFullListModalAddFieldKey,
              focusNode: _addFocusNode,
              onSubmitted: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the visible rows. When [searchActive] is true the list is a
/// non-reorderable [ListView] — partial views can't safely accept reorder
/// because absolute and visible indices diverge. When [searchActive] is
/// false the list is a [ReorderableListView] and visible indices match
/// absolute indices 1:1, so the row's [ReorderableDragStartListener] works
/// without translation.
class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.checklistId,
    required this.taskId,
    required this.visible,
    required this.filter,
    required this.tokens,
    required this.searchActive,
    required this.itemIds,
    required this.onReorder,
  });

  final String checklistId;
  final String taskId;
  final List<({int absoluteIndex, String itemId})> visible;
  final ChecklistFilter filter;
  final DsTokens tokens;
  final bool searchActive;
  final List<String> itemIds;
  final Future<void> Function(List<String>) onReorder;

  ChecklistItemRow _row(int idx) {
    final entry = visible[idx];
    return ChecklistItemRow(
      key: ValueKey('modal-row-$checklistId-${entry.itemId}'),
      itemId: entry.itemId,
      checklistId: checklistId,
      taskId: taskId,
      // Pass the visible position so ReorderableDragStartListener inside
      // the row matches the position of this child in its list. Without
      // this, dragging a row in a search-empty list would still work
      // because absolute == visible, but we keep the contract explicit.
      index: idx,
      hideIfChecked: filter == ChecklistFilter.openOnly,
      hideIfUnchecked: filter == ChecklistFilter.doneOnly,
      showDivider: idx < visible.length - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (searchActive) {
      return ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: visible.length,
        itemBuilder: (context, idx) => _row(idx),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          color: tokens.colors.background.level02,
          child: child,
        ),
        child: child,
      ),
      onReorder: (oldIndex, newIndex) {
        // Visible == absolute when search is empty, so we can mutate the
        // list in place without any index translation.
        final ids = [...itemIds];
        final moved = ids.removeAt(oldIndex);
        final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
        ids.insert(insertAt, moved);
        onReorder(ids);
      },
      itemCount: visible.length,
      itemBuilder: (context, idx) => _row(idx),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.tokens});

  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Container(
        width: tokens.spacing.step8,
        height: tokens.spacing.step2,
        decoration: BoxDecoration(
          color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(tokens.radii.xs / 2),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.tokens,
  });

  final String title;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (totalCount > 0) ...[
            buildChecklistProgressRing(
              completionRate: completionRate,
              lowEmphasisColor: tokens.colors.text.lowEmphasis,
              semanticsLabel: context.messages.checklistProgressSemantics,
            ),
            SizedBox(width: tokens.spacing.step3),
            Text(
              context.messages.checklistCompletedShort(
                completedCount,
                totalCount,
              ),
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.tokens,
  });

  final TextEditingController controller;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Container(
        constraints: BoxConstraints(minHeight: tokens.spacing.step8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: tokens.spacing.step5,
              color: tokens.colors.text.lowEmphasis,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: TextField(
                key: checklistFullListModalSearchFieldKey,
                controller: controller,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
                decoration: InputDecoration(
                  hintText: context.messages.checklistViewAllSearchHint,
                  hintStyle: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
