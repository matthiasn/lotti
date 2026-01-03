import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/features/tasks/ui/checklists/progress_indicator.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

enum ChecklistFilter { openOnly, all }

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
  late AnimationController _chevronController;
  late Animation<double> _chevronRotation;

  @override
  void initState() {
    super.initState();
    _itemIds = widget.itemIds;
    _isExpanded = widget.initiallyExpanded ??
        (widget.completionRate < 1 || widget.itemIds.isEmpty);

    // Chevron rotation: 0.0 = pointing down (expanded), -0.25 = pointing right (collapsed)
    _chevronController = AnimationController(
      duration: checklistChevronRotationDuration,
      vsync: this,
      value: _isExpanded ? 0.0 : -0.25,
    );
    _chevronRotation = _chevronController;

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
    _chevronController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded == expanded) return;
    setState(() {
      _isExpanded = expanded;
    });
    if (expanded) {
      _chevronController.animateTo(0);
    } else {
      _chevronController.animateTo(-0.25);
    }
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
          _ChecklistCardHeader(
            title: widget.title,
            isExpanded: _isExpanded,
            isSortingMode: widget.isSortingMode,
            isEditingTitle: _isEditingTitle,
            completedCount: completed,
            totalCount: total,
            completionRate: widget.completionRate,
            filter: _filter,
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
            chevronRotation: _chevronRotation,
          ),

          // BODY (animated visibility)
          AnimatedCrossFade(
            duration: checklistCardCollapseAnimationDuration,
            sizeCurve: Curves.easeInOut,
            crossFadeState:
                showBody ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: _ChecklistCardBody(
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

/// Header for a checklist card.
///
/// Layout varies based on state:
/// - **Expanded**: Title row with chevron/menu, then progress/filters row
/// - **Collapsed**: Single row with title, progress, chevron, menu
/// - **Sorting**: Single row with drag handle, title, progress
class _ChecklistCardHeader extends StatelessWidget {
  const _ChecklistCardHeader({
    required this.title,
    required this.isExpanded,
    required this.isSortingMode,
    required this.isEditingTitle,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.filter,
    required this.onToggleExpand,
    required this.onTitleTap,
    required this.onTitleSave,
    required this.onTitleCancel,
    required this.onFilterChanged,
    required this.chevronRotation,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
  });

  final String title;
  final bool isExpanded;
  final bool isSortingMode;
  final bool isEditingTitle;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final ChecklistFilter filter;
  final VoidCallback onToggleExpand;
  final VoidCallback onTitleTap;
  final StringCallback onTitleSave;
  final VoidCallback onTitleCancel;
  final ValueChanged<ChecklistFilter> onFilterChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;
  final Animation<double> chevronRotation;

  @override
  Widget build(BuildContext context) {
    if (isSortingMode) {
      return _buildSortingModeHeader(context);
    }

    if (isExpanded) {
      return _buildExpandedHeader(context);
    }

    return _buildCollapsedHeader(context);
  }

  /// Sorting mode: `DragHandle` `Title` `Progress`
  Widget _buildSortingModeHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Large drag handle for sorting
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.drag_indicator,
              size: 28,
              color: context.colorScheme.outline.withValues(alpha: 0.7),
            ),
          ),
          // Title
          Expanded(
            child: Text(
              title,
              style: context.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Progress (always visible in collapsed/sorting)
          _buildProgressIndicator(context, alwaysShow: true),
        ],
      ),
    );
  }

  /// Collapsed: `Title` `Progress` `Chevron` `Menu`
  Widget _buildCollapsedHeader(BuildContext context) {
    return InkWell(
      onTap: onToggleExpand,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Title
            Expanded(
              child: Text(
                title,
                style: context.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Progress (always visible in collapsed)
            _buildProgressIndicator(context, alwaysShow: true),
            // Chevron
            _buildChevron(context),
            // Menu
            _buildMenu(context),
          ],
        ),
      ),
    );
  }

  /// Expanded: Two rows
  /// Row 1: `Title (editable)` `Chevron` `Menu`
  /// Row 2: `Progress` `Filters`
  Widget _buildExpandedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Title, Chevron, Menu
          Row(
            children: [
              Expanded(child: _buildTitleWidget(context)),
              _buildChevron(context),
              _buildMenu(context),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Progress, Filters
          Row(
            children: [
              // Progress (hide when total = 0 in expanded mode)
              _buildProgressIndicator(context, alwaysShow: false),
              const Spacer(),
              // Filter tabs
              _FilterTabs(
                filter: filter,
                onFilterChanged: onFilterChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleWidget(BuildContext context) {
    return AnimatedCrossFade(
      duration: checklistCrossFadeDuration,
      crossFadeState:
          isEditingTitle ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: TitleTextField(
        initialValue: title,
        onSave: onTitleSave,
        resetToInitialValue: true,
        onCancel: onTitleCancel,
      ),
      secondChild: GestureDetector(
        onTap: onTitleTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: Text(
            title,
            style: context.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildChevron(BuildContext context) {
    return InkWell(
      onTap: onToggleExpand,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: RotationTransition(
          turns: chevronRotation,
          child: Icon(
            Icons.expand_more,
            size: 22,
            color: context.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context,
      {required bool alwaysShow}) {
    // In expanded mode, hide when total = 0
    // In collapsed/sorting mode, always show
    if (!alwaysShow && totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChecklistProgressIndicator(completionRate: completionRate),
        const SizedBox(width: 6),
        Text(
          context.messages.checklistCompletedShort(completedCount, totalCount),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: context.colorScheme.surfaceContainerHighest,
          elevation: 8,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'More',
        position: PopupMenuPosition.under,
        icon: const Icon(Icons.more_vert_rounded, size: 18),
        onSelected: (value) async {
          Future<void> deleteAction() async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(context.messages.checklistDelete),
                  content: Text(context.messages.checklistItemDeleteWarning),
                  actions: [
                    LottiTertiaryButton(
                      label: context.messages.checklistItemDeleteCancel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    LottiTertiaryButton(
                      label: context.messages.checklistItemDeleteConfirm,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
              },
            );
            if (result ?? false) {
              onDelete?.call();
            }
          }

          final actions = <String, Future<void> Function()>{
            'export': () async => onExportMarkdown?.call(),
            'share': () async => onShareMarkdown?.call(),
            'delete': deleteAction,
          };
          await actions[value]?.call();
        },
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          if (onExportMarkdown != null)
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(MdiIcons.exportVariant, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.messages.checklistExportAsMarkdown,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          if (onShareMarkdown != null)
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.ios_share, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Share',
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.messages.checklistDelete,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter tabs with underline indicator for selected state.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.filter,
    required this.onFilterChanged,
  });

  final ChecklistFilter filter;
  final ValueChanged<ChecklistFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterTab(
          label: context.messages.taskStatusOpen,
          isSelected: filter == ChecklistFilter.openOnly,
          onTap: () => onFilterChanged(ChecklistFilter.openOnly),
        ),
        const SizedBox(width: 16),
        _FilterTab(
          label: context.messages.taskStatusAll,
          isSelected: filter == ChecklistFilter.all,
          onTap: () => onFilterChanged(ChecklistFilter.all),
        ),
      ],
    );
  }
}

/// A single filter tab with text and underline when selected.
class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? context.colorScheme.onSurface
        : context.colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        // Use IntrinsicWidth to ensure underline matches text width exactly
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              // Underline indicator - stretches to match text width
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: isSelected ? 2 : 0,
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Body of a checklist card containing items list and add input.
class _ChecklistCardBody extends StatelessWidget {
  const _ChecklistCardBody({
    required this.itemIds,
    required this.checklistId,
    required this.taskId,
    required this.filter,
    required this.completionRate,
    required this.focusNode,
    required this.isCreatingItem,
    required this.onCreateItem,
    required this.onReorder,
  });

  final List<String> itemIds;
  final String checklistId;
  final String taskId;
  final ChecklistFilter filter;
  final double completionRate;
  final FocusNode focusNode;
  final bool isCreatingItem;
  final Future<void> Function(String?) onCreateItem;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final hideChecked = filter == ChecklistFilter.openOnly;
    final allDone = hideChecked && completionRate == 1 && itemIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Items list
        if (itemIds.isEmpty)
          _buildEmptyState(context)
        else if (allDone)
          _buildAllDoneState(context)
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false, // We use custom drag handles
            proxyDecorator: (child, index, animation) =>
                buildDragDecorator(context, child),
            onReorder: onReorder,
            children: List.generate(
              itemIds.length,
              (int index) {
                final itemId = itemIds.elementAt(index);
                return ChecklistItemWrapper(
                  itemId,
                  taskId: taskId,
                  checklistId: checklistId,
                  hideIfChecked: hideChecked,
                  index: index,
                  key: ValueKey('checklist-item-$checklistId-$itemId'),
                );
              },
            ),
          ),

        // Add input at BOTTOM
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: FocusTraversalGroup(
            child: FocusScope(
              child: TitleTextField(
                key: ValueKey('add-input-$checklistId'),
                focusNode: focusNode,
                onSave: onCreateItem,
                clearOnSave: true,
                keepFocusOnSave: true,
                autofocus: itemIds.isEmpty,
                semanticsLabel: 'Add item to checklist',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: Text(
          'No items yet',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildAllDoneState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        context.messages.checklistAllDone,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.outline,
        ),
      ),
    );
  }
}
