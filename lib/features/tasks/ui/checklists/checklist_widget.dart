import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_body.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_card_header.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/services/app_prefs_service.dart';

/// Renders a single checklist with header and items.
///
/// The checklist uses a card-based architecture with:
/// - A header that shows title, chevron, progress, filters, and menu
/// - A body that shows items and an add input field
///
/// Supports three modes:
/// - **Expanded**: Shows full header with filters and body with items
/// - **Collapsed**: Shows compact header with inline progress
/// - **Sorting Mode**: Shows drag handle, hides chevron/menu for reordering
class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({
    required this.title,
    required this.itemIds,
    required this.onTitleSave,
    required this.onCreateChecklistItem,
    required this.completionRate,
    required this.id,
    required this.taskId,
    required this.updateItemOrder,
    this.completedCount,
    this.totalCount,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
    this.isSortingMode = false,
    this.onExpansionChanged,
    this.initiallyExpanded,
    this.reorderIndex,
    super.key,
  });

  final String id;
  final String taskId;

  final String title;
  final List<String> itemIds;
  final StringCallback onTitleSave;
  final Future<String?> Function(String?) onCreateChecklistItem;
  final Future<void> Function(List<String> linkedChecklistItems)
      updateItemOrder;
  final double completionRate;
  final int? completedCount;
  final int? totalCount;
  final VoidCallback? onDelete;

  /// Called when the export button is activated (tap/click). Should copy the
  /// checklist as Markdown to the clipboard and provide user feedback.
  final VoidCallback? onExportMarkdown;

  /// Called on long-press (mobile) or secondary-click (desktop) of the export
  /// control to trigger a share sheet with an emoji-based checklist.
  final VoidCallback? onShareMarkdown;

  /// Whether global sorting mode is active. When true, the card collapses
  /// and shows a large drag handle for reordering checklists.
  final bool isSortingMode;

  /// Called when expansion state changes. Used by parent to track states.
  final ValueChanged<bool>? onExpansionChanged;

  /// Override the initial expansion state. If null, defaults to
  /// expanding if completionRate < 1.
  final bool? initiallyExpanded;

  /// Index for reordering in the parent ReorderableListView.
  final int? reorderIndex;

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget>
    with SingleTickerProviderStateMixin {
  late List<String> _itemIds;
  final FocusNode _focusNode = FocusNode();
  bool _isCreatingItem = false;

  // Title editing state
  bool _isEditingTitle = false;

  // Filter state
  ChecklistFilter _filter = ChecklistFilter.openOnly;

  // Expansion state
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _itemIds = widget.itemIds;
    _isExpanded = widget.initiallyExpanded ??
        (widget.completionRate < 1 || widget.itemIds.isEmpty);

    // Load filter preference
    final key = 'checklist_filter_mode_${widget.id}';
    makeSharedPrefsService().getBool(key).then((value) {
      if (!mounted) return;
      if (value != null) {
        setState(() {
          _filter = value ? ChecklistFilter.openOnly : ChecklistFilter.all;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemIds != widget.itemIds) {
      setState(() {
        _itemIds = widget.itemIds;
      });
    }

    // Restore expansion state when exiting sorting mode
    if (oldWidget.isSortingMode && !widget.isSortingMode) {
      // Expansion state should be restored by parent via initiallyExpanded
      if (widget.initiallyExpanded != null) {
        _setExpanded(widget.initiallyExpanded!);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded == expanded) return;
    setState(() {
      _isExpanded = expanded;
    });
    widget.onExpansionChanged?.call(expanded);
  }

  void _toggleExpanded() {
    _setExpanded(!_isExpanded);
  }

  void _setFilter(ChecklistFilter filter) {
    setState(() => _filter = filter);
    makeSharedPrefsService().setBool(
      key: 'checklist_filter_mode_${widget.id}',
      value: filter == ChecklistFilter.openOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalCount ?? _itemIds.length;
    final completed = widget.completedCount ??
        (total == 0 ? 0 : (widget.completionRate * total).round());

    // In sorting mode, always show collapsed
    final showBody = _isExpanded && !widget.isSortingMode;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          ChecklistCardHeader(
            title: widget.title,
            isExpanded: _isExpanded,
            isSortingMode: widget.isSortingMode,
            isEditingTitle: _isEditingTitle,
            completedCount: completed,
            totalCount: total,
            completionRate: widget.completionRate,
            filter: _filter,
            reorderIndex: widget.reorderIndex,
            onToggleExpand: _toggleExpanded,
            onTitleTap: () => setState(() => _isEditingTitle = true),
            onTitleSave: (title) {
              widget.onTitleSave(title);
              setState(() => _isEditingTitle = false);
            },
            onTitleCancel: () => setState(() => _isEditingTitle = false),
            onFilterChanged: _setFilter,
            onDelete: widget.onDelete,
            onExportMarkdown: widget.onExportMarkdown,
            onShareMarkdown: widget.onShareMarkdown,
          ),

          // BODY (animated visibility)
          AnimatedCrossFade(
            duration: checklistCardCollapseAnimationDuration,
            sizeCurve: Curves.easeInOut,
            crossFadeState:
                showBody ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: ChecklistCardBody(
              itemIds: _itemIds,
              checklistId: widget.id,
              taskId: widget.taskId,
              filter: _filter,
              completionRate: widget.completionRate,
              focusNode: _focusNode,
              isCreatingItem: _isCreatingItem,
              onCreateItem: (title) async {
                if (_isCreatingItem) return;
                setState(() => _isCreatingItem = true);
                final id = await widget.onCreateChecklistItem(title);
                setState(() {
                  if (id != null) {
                    _itemIds = [..._itemIds, id];
                  }
                  _isCreatingItem = false;
                });
                // Ensure the add field truly regains keyboard focus after rebuilds
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  _focusNode.unfocus();
                  if (context.mounted) {
                    FocusScope.of(context).requestFocus(_focusNode);
                  }
                  try {
                    await SystemChannels.textInput
                        .invokeMethod('TextInput.show');
                  } catch (_) {}
                  final editable = FocusManager.instance.primaryFocus?.context
                      ?.findAncestorStateOfType<EditableTextState>();
                  editable?.requestKeyboard();
                });
              },
              onReorder: (int oldIndex, int newIndex) {
                final itemIds = [..._itemIds];
                final movedItem = itemIds.removeAt(oldIndex);
                final insertionIndex =
                    newIndex > oldIndex ? newIndex - 1 : newIndex;
                itemIds.insert(insertionIndex, movedItem);
                setState(() {
                  _itemIds = itemIds;
                });
                widget.updateItemOrder(itemIds);
              },
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
