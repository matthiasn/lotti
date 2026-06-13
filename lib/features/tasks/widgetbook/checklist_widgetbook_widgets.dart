import 'package:flutter/material.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class Header extends StatelessWidget {
  const Header({
    required this.title,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.isExpanded,
    required this.tokens,
    required this.onToggleExpand,
    super.key,
  });

  final String title;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final bool isExpanded;
  final DsTokens tokens;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isExpanded ? null : onToggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _ProgressRow(
                completedCount: completedCount,
                totalCount: totalCount,
                completionRate: completionRate,
                tokens: tokens,
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.0 : -0.25,
                duration: checklistChevronRotationDuration,
                child: GestureDetector(
                  onTap: onToggleExpand,
                  child: Icon(
                    Icons.expand_more,
                    size: 24,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {},
                child: Icon(
                  Icons.more_vert,
                  size: 24,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.tokens,
  });

  final int completedCount;
  final int totalCount;
  final double completionRate;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: successColor,
            backgroundColor: tokens.colors.text.lowEmphasis.withValues(
              alpha: 0.3,
            ),
            value: completionRate,
            strokeWidth: 3,
            semanticsLabel: 'Checklist progress',
          ),
        ),
        const SizedBox(width: 4),
        Text(
          context.messages.checklistCompletedShort(completedCount, totalCount),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter tabs
// ---------------------------------------------------------------------------

const _tabAccentColor = Color.fromRGBO(94, 212, 184, 1);

class FilterTabs extends StatelessWidget {
  const FilterTabs({
    required this.filter,
    required this.tokens,
    required this.onFilterChanged,
    super.key,
  });

  final ChecklistFilter filter;
  final DsTokens tokens;
  final ValueChanged<ChecklistFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Full-width grey background behind tabs row
        Container(
          height: 40,
          color: Colors.white.withValues(alpha: 0.06),
          child: Row(
            children: [
              _TabChip(
                label: messages.taskStatusOpen,
                isSelected: filter == ChecklistFilter.openOnly,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.openOnly),
              ),
              _TabChip(
                label: messages.taskStatusAll,
                isSelected: filter == ChecklistFilter.all,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.all),
              ),
              const Spacer(),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: tokens.colors.decorative.level01,
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final DsTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? _tabAccentColor.withValues(alpha: 0.24)
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: isSelected
                        ? tokens.colors.text.highEmphasis
                        : tokens.colors.text.lowEmphasis,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            Container(
              width: 64,
              height: 3,
              color: isSelected ? _tabAccentColor : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items (Column, not scrollable — no scroll fight)
// ---------------------------------------------------------------------------

class ItemsColumn extends StatelessWidget {
  const ItemsColumn({
    required this.items,
    required this.tokens,
    required this.onToggle,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onReorder,
    super.key,
  });

  final List<ChecklistItemData> items;
  final DsTokens tokens;
  final void Function(int index) onToggle;
  final void Function(int index, String newTitle) onEdit;
  final void Function(int index) onArchive;
  final void Function(int index) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Center(
          child: Text(
            context.messages.checklistAllDone,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            color: tokens.colors.background.level02,
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        return _DismissibleRow(
          key: ValueKey(items[index].id ?? 'item-$index'),
          item: items[index],
          index: index,
          tokens: tokens,
          onToggle: () => onToggle(index),
          onEdit: (title) => onEdit(index, title),
          onArchive: () => onArchive(index),
          onDelete: () => onDelete(index),
          showDivider: index < items.length - 1,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dismissible row: swipe right = archive, swipe left = delete
// ---------------------------------------------------------------------------

class _DismissibleRow extends StatefulWidget {
  const _DismissibleRow({
    required this.item,
    required this.index,
    required this.tokens,
    required this.onToggle,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    this.showDivider = false,
    super.key,
  });

  final ChecklistItemData item;
  final int index;
  final DsTokens tokens;
  final VoidCallback onToggle;
  final ValueChanged<String> onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool showDivider;

  @override
  State<_DismissibleRow> createState() => _DismissibleRowState();
}

class _DismissibleRowState extends State<_DismissibleRow> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final item = widget.item;
    final isStrikethrough = item.isChecked || item.isArchived;

    return Dismissible(
      key: ValueKey(item.id ?? 'item-${widget.index}'),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.25,
        DismissDirection.startToEnd: 0.25,
      },
      // Swipe right → archive (don't dismiss, just toggle state)
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          widget.onArchive();
          return false;
        }
        // Swipe left → delete
        return true;
      },
      onDismissed: (_) => widget.onDelete(),
      background: ColoredBox(
        color: Colors.amber.shade700,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(
              item.isArchived ? Icons.unarchive : Icons.archive,
              color: Colors.white,
            ),
          ),
        ),
      ),
      secondaryBackground: const ColoredBox(
        color: Colors.red,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  // Drag handle — enables reorder on long press
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 24,
                      color: tokens.colors.text.lowEmphasis.withValues(
                        alpha: 0.32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Checkbox
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: item.isChecked,
                      onChanged: (_) => widget.onToggle(),
                      activeColor: tokens.colors.interactive.enabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(
                        color: tokens.colors.text.lowEmphasis,
                        width: 1.5,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Title — editable or display
                  Expanded(
                    child: _isEditing
                        ? _InlineEditField(
                            initialValue: item.title,
                            tokens: tokens,
                            onSave: (title) {
                              widget.onEdit(title);
                              setState(() => _isEditing = false);
                            },
                            onCancel: () => setState(() => _isEditing = false),
                          )
                        : Text(
                            item.title,
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: isStrikethrough
                                      ? tokens.colors.text.lowEmphasis
                                      : tokens.colors.text.highEmphasis,
                                  decoration: isStrikethrough
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                            maxLines: 4,
                            overflow: TextOverflow.fade,
                          ),
                  ),
                  // Edit icon — tappable
                  if (!_isEditing)
                    GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      child: Icon(
                        Icons.mode_edit_outlined,
                        size: 20,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.showDivider)
            Divider(
              height: 1,
              thickness: 1,
              color: tokens.colors.decorative.level01,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inline edit text field
// ---------------------------------------------------------------------------

class _InlineEditField extends StatefulWidget {
  const _InlineEditField({
    required this.initialValue,
    required this.tokens,
    required this.onSave,
    required this.onCancel,
  });

  final String initialValue;
  final DsTokens tokens;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<_InlineEditField> createState() => _InlineEditFieldState();
}

class _InlineEditFieldState extends State<_InlineEditField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focus = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: widget.tokens.typography.styles.body.bodySmall.copyWith(
        color: widget.tokens.colors.text.highEmphasis,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) {
          widget.onSave(value);
        } else {
          widget.onCancel();
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Add item field
// ---------------------------------------------------------------------------

class AddItemField extends StatelessWidget {
  const AddItemField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.tokens,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final DsTokens tokens;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}
