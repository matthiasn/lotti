import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Expanded checklist card content: the filtered item rows followed by the
/// add-item input. Renders an "all done" / "none done" empty-state message
/// instead of the list when the active filter leaves nothing to show, and
/// hands off all drag/drop to per-row `super_drag_and_drop` widgets.
class Body extends StatelessWidget {
  const Body({
    required this.itemIds,
    required this.checklistId,
    required this.taskId,
    required this.filter,
    required this.completionRate,
    required this.activeTotalCount,
    required this.focusNode,
    required this.onCreateItem,
    super.key,
  });

  final List<String> itemIds;
  final String checklistId;
  final String taskId;
  final ChecklistFilter filter;
  final double completionRate;

  /// Number of active (non-archived) items. Used to avoid showing the "none
  /// done" empty state when all items are archived — archived items count as
  /// done at the row level.
  final int activeTotalCount;
  final FocusNode focusNode;
  final Future<void> Function(String?) onCreateItem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hideChecked = filter == ChecklistFilter.openOnly;
    final hideUnchecked = filter == ChecklistFilter.doneOnly;
    final allDone = hideChecked && completionRate == 1.0 && itemIds.isNotEmpty;
    // Only show "none done" when there are active (non-archived) items that
    // are all unchecked. When activeTotalCount is 0 all items are archived,
    // and archived items are shown as "done" by the row filter.
    final noneDone =
        hideUnchecked &&
        activeTotalCount > 0 &&
        completionRate == 0 &&
        itemIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (allDone || noneDone)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: Center(
              child: Text(
                allDone
                    ? context.messages.checklistAllDone
                    : context.messages.checklistNoneDone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          )
        else
          // Plain ListView — all drag/drop is handled by super_drag_and_drop
          // on each row (DropRegion + DragItemWidget + DraggableWidget),
          // routed through the controller's dropChecklistItem which dispatches
          // to _reorderItem (same list) or moveToChecklist (cross list).
          // ReorderableListView would re-animate the list on every data
          // mutation, fighting the OS-native drag image and feeling wobbly.
          _AnimatedChecklistItems(
            itemIds: itemIds,
            checklistId: checklistId,
            taskId: taskId,
            hideChecked: hideChecked,
            hideUnchecked: hideUnchecked,
          ),

        Divider(
          height: 1,
          thickness: 1,
          color: tokens.colors.decorative.level01,
        ),
        SizedBox(height: tokens.spacing.step3),

        // Add item field — clean pill input matching the Widgetbook design.
        _AddItemField(
          key: ValueKey('add-input-$checklistId'),
          focusNode: focusNode,
          onSubmitted: onCreateItem,
        ),
      ],
    );
  }
}

class _AnimatedChecklistItems extends StatefulWidget {
  const _AnimatedChecklistItems({
    required this.itemIds,
    required this.checklistId,
    required this.taskId,
    required this.hideChecked,
    required this.hideUnchecked,
  });

  final List<String> itemIds;
  final String checklistId;
  final String taskId;
  final bool hideChecked;
  final bool hideUnchecked;

  @override
  State<_AnimatedChecklistItems> createState() =>
      _AnimatedChecklistItemsState();
}

class _AnimatedChecklistItemsState extends State<_AnimatedChecklistItems> {
  final Set<String> _knownItemIds = {};
  final Set<String> _newlyInsertedItemIds = {};

  @override
  void initState() {
    super.initState();
    _knownItemIds.addAll(widget.itemIds);
  }

  @override
  void didUpdateWidget(covariant _AnimatedChecklistItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.itemIds.toSet();
    if (oldWidget.checklistId != widget.checklistId ||
        oldWidget.taskId != widget.taskId) {
      _newlyInsertedItemIds.clear();
    } else {
      _newlyInsertedItemIds
        ..clear()
        ..addAll(currentIds.difference(_knownItemIds));
    }
    _knownItemIds
      ..clear()
      ..addAll(currentIds);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      // EdgeInsets.zero — without this BoxScrollView absorbs the ambient
      // MediaQuery.padding (e.g. iPhone notch) as its top padding.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(widget.itemIds.length, (index) {
        final itemId = widget.itemIds[index];
        return SizeFadeEntrance(
          key: ValueKey('row-${widget.checklistId}-$itemId'),
          animate: _newlyInsertedItemIds.contains(itemId),
          child: ChecklistItemRow(
            itemId: itemId,
            checklistId: widget.checklistId,
            taskId: widget.taskId,
            index: index,
            hideIfChecked: widget.hideChecked,
            hideIfUnchecked: widget.hideUnchecked,
            // The leading divider belongs to the entering row, so the line and
            // content reveal on the same animation frame.
            showDivider: index > 0,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add item field — minimal pill-shaped TextField matching the Widgetbook design.
// Manages its own controller; clears on submit and fires the callback.
// ─────────────────────────────────────────────────────────────────────────────

/// Duration of the border-colour cross-fade between the inactive and
/// focused pill states. Fast enough to feel responsive on tap, slow
/// enough that the transition reads as an intentional state change.
const _kAddItemFieldFocusAnimationDuration = Duration(milliseconds: 200);

class _AddItemField extends StatefulWidget {
  const _AddItemField({
    required this.focusNode,
    required this.onSubmitted,
    super.key,
  });

  final FocusNode focusNode;
  final Future<void> Function(String?) onSubmitted;

  @override
  State<_AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends State<_AddItemField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _AddItemField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    widget.onSubmitted(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isFocused = widget.focusNode.hasFocus;
    // `DsColorsInteractive` exposes only `enabled` / `hover` / `pressed`
    // — there is no dedicated focus token, so we reuse `enabled` as the
    // active-affordance colour for the focused pill.
    final borderColor = isFocused
        ? tokens.colors.interactive.enabled
        : tokens.colors.decorative.level01;
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step3,
        right: tokens.spacing.step3,
        bottom: tokens.spacing.step4,
      ),
      child: AnimatedContainer(
        duration: _kAddItemFieldFocusAnimationDuration,
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Border width stays constant at 1 px so the pill never
          // breathes across the focus toggle — only the colour cross-
          // fades from the decorative hairline into the interactive
          // accent when the user taps into the field.
          border: Border.all(color: borderColor),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          decoration: InputDecoration(
            hintText: context.messages.checklistAddItem,
            hintStyle: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
            // The outer `AnimatedContainer` already draws the pill border.
            // Silence every state-specific border the app's
            // `InputDecorationTheme` would otherwise overlay — in
            // particular `focusedBorder`, a 2.5 px primary-coloured
            // outline that appeared inside the pill on tap — along with
            // the themed `fillColor` tint (suppressed via `filled: false`).
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: _submit,
          textInputAction: TextInputAction.done,
        ),
      ),
    );
  }
}
