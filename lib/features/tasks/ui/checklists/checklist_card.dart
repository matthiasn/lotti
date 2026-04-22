import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// A single checklist card with the new visual design.
///
/// Renders a header (title, progress ring, expand/collapse, menu), filter tabs,
/// a reorderable item list using [ChecklistItemRow], and an add-item text field.
///
/// State managed here:
/// - Expansion (collapsed / expanded)
/// - Filter mode (open-only / all)
/// - Title editing
/// - Whether an item creation is in flight
/// - Local item-ids list (optimistic reorder before persistence)
///
/// The parent is responsible for providing real callbacks that persist changes.
class ChecklistCard extends StatefulWidget {
  const ChecklistCard({
    required this.id,
    required this.taskId,
    required this.title,
    required this.itemIds,
    required this.completionRate,
    required this.onTitleSave,
    required this.onCreateItem,
    required this.onReorder,
    this.completedCount,
    this.totalCount,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
    this.isSortingMode = false,
    this.initiallyExpanded,
    this.reorderIndex,
    this.onExpansionChanged,
    super.key,
  });

  final String id;
  final String taskId;
  final String title;
  final List<String> itemIds;
  final double completionRate;
  final int? completedCount;
  final int? totalCount;

  /// Called when the checklist title is saved.
  final StringCallback onTitleSave;

  /// Called when a new item should be created. Returns the new item's id or
  /// null on failure.
  final Future<String?> Function(String?) onCreateItem;

  /// Called after a within-list reorder to persist the new order.
  final Future<void> Function(List<String>) onReorder;

  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;

  /// When true, the card collapses and shows a drag handle for reordering
  /// checklists within the task.
  final bool isSortingMode;

  /// Override the initial expansion state. Defaults to expanded when
  /// completion rate < 1 or no items.
  final bool? initiallyExpanded;

  /// Index within the parent [ReorderableListView] (used in sorting mode).
  final int? reorderIndex;

  /// Called whenever the expansion state changes so the parent can track it.
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<ChecklistCard> {
  late List<String> _itemIds;
  late bool _isExpanded;
  ChecklistFilter _filter = ChecklistFilter.openOnly;
  bool _isEditingTitle = false;
  bool _isCreatingItem = false;
  final FocusNode _addFocusNode = FocusNode();

  /// Whether the widget has completed its first frame. Animations use
  /// [Duration.zero] until this is `true` so the initial layout snaps
  /// into place without a visible collapse/expand transition.
  bool _hasRendered = false;

  @override
  void initState() {
    super.initState();
    _itemIds = widget.itemIds;
    _isExpanded =
        widget.initiallyExpanded ??
        (widget.completionRate < 1 || widget.itemIds.isEmpty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onExpansionChanged?.call(_isExpanded);
        setState(() => _hasRendered = true);
      }
    });

    _loadFilterPreference();
  }

  @override
  void didUpdateWidget(ChecklistCard old) {
    super.didUpdateWidget(old);
    if (old.itemIds != widget.itemIds) {
      setState(() => _itemIds = widget.itemIds);
    }
    // Restore expansion when exiting sorting mode.
    if (old.isSortingMode && !widget.isSortingMode) {
      if (widget.initiallyExpanded != null) {
        _setExpanded(widget.initiallyExpanded!);
      }
    }
  }

  @override
  void dispose() {
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFilterPreference() async {
    final key = 'checklist_filter_mode_${widget.id}';
    final prefs = makeSharedPrefsService();

    // Try new string-based key first, fall back to legacy bool key.
    final stringValue = await prefs.getString(key);
    if (!mounted) return;

    if (stringValue != null) {
      final parsed = ChecklistFilter.values.where((v) => v.name == stringValue);
      if (parsed.isNotEmpty) {
        setState(() => _filter = parsed.first);
        return;
      }
    }

    // Legacy bool migration: true → openOnly, false → all.
    final boolValue = await prefs.getBool(key);
    if (!mounted || boolValue == null) return;
    final migrated = boolValue ? ChecklistFilter.openOnly : ChecklistFilter.all;
    setState(() => _filter = migrated);
    // Persist as the new string format so future reads use the string path.
    // TODO(cleanup): remove legacy bool migration after a few releases.
    await prefs.setString(key: key, value: migrated.name);
  }

  Future<void> _saveFilterPreference(ChecklistFilter filter) {
    return makeSharedPrefsService().setString(
      key: 'checklist_filter_mode_${widget.id}',
      value: filter.name,
    );
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded == expanded) return;
    setState(() => _isExpanded = expanded);
    widget.onExpansionChanged?.call(expanded);
  }

  void _setFilter(ChecklistFilter filter) {
    setState(() => _filter = filter);
    _saveFilterPreference(filter);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalCount ?? _itemIds.length;
    final completed =
        widget.completedCount ??
        (total == 0 ? 0 : (widget.completionRate * total).round());

    final showBody = _isExpanded && !widget.isSortingMode;
    final animationDuration = _hasRendered
        ? checklistCardCollapseAnimationDuration
        : Duration.zero;
    final chevronDuration = _hasRendered
        ? checklistChevronRotationDuration
        : Duration.zero;

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          if (widget.isSortingMode)
            _SortingHeader(
              title: widget.title,
              completedCount: completed,
              totalCount: total,
              completionRate: widget.completionRate,
              reorderIndex: widget.reorderIndex,
            )
          else
            _Header(
              title: widget.title,
              isExpanded: _isExpanded,
              isEditingTitle: _isEditingTitle,
              completedCount: completed,
              totalCount: total,
              completionRate: widget.completionRate,
              filter: _filter,
              chevronDuration: chevronDuration,
              filterStripDuration: animationDuration,
              onToggleExpand: () => _setExpanded(!_isExpanded),
              onTitleTap: () => setState(() => _isEditingTitle = true),
              onTitleSave: (t) {
                widget.onTitleSave(t);
                setState(() => _isEditingTitle = false);
              },
              onTitleCancel: () => setState(() => _isEditingTitle = false),
              onFilterChanged: _setFilter,
              onDelete: widget.onDelete,
              onExportMarkdown: widget.onExportMarkdown,
              onShareMarkdown: widget.onShareMarkdown,
            ),

          // ── Body (animated) ───────────────────────────────────────────────
          AnimatedCrossFade(
            duration: animationDuration,
            sizeCurve: Curves.easeInOut,
            crossFadeState: showBody
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _Body(
              itemIds: _itemIds,
              checklistId: widget.id,
              taskId: widget.taskId,
              filter: _filter,
              completionRate: widget.completionRate,
              activeTotalCount: total,
              focusNode: _addFocusNode,
              onCreateItem: (title) async {
                if (_isCreatingItem) return;
                setState(() => _isCreatingItem = true);
                String? id;
                try {
                  id = await widget.onCreateItem(title);
                } finally {
                  if (mounted) setState(() => _isCreatingItem = false);
                }
                if (!mounted || id == null) return;
                setState(() => _itemIds = [..._itemIds, id!]);
                // Restore keyboard focus on the add field.
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  _addFocusNode.unfocus();
                  if (context.mounted) {
                    FocusScope.of(context).requestFocus(_addFocusNode);
                  }
                  try {
                    await SystemChannels.textInput.invokeMethod(
                      'TextInput.show',
                    );
                  } catch (_) {}
                });
              },
              onReorder: (oldIndex, newIndex) {
                final ids = [..._itemIds];
                final moved = ids.removeAt(oldIndex);
                final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
                ids.insert(insertAt, moved);
                setState(() => _itemIds = ids);
                widget.onReorder(ids);
              },
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — full header shown in normal (non-sorting) mode.
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.isExpanded,
    required this.isEditingTitle,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    required this.filter,
    required this.chevronDuration,
    required this.filterStripDuration,
    required this.onToggleExpand,
    required this.onTitleTap,
    required this.onTitleSave,
    required this.onTitleCancel,
    required this.onFilterChanged,
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
  });

  final String title;
  final bool isExpanded;
  final bool isEditingTitle;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final ChecklistFilter filter;
  final Duration chevronDuration;
  final Duration filterStripDuration;
  final VoidCallback onToggleExpand;
  final VoidCallback onTitleTap;
  final StringCallback onTitleSave;
  final VoidCallback onTitleCancel;
  final ValueChanged<ChecklistFilter> onFilterChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Single title row — progress ring always visible here.
        GestureDetector(
          onTap: isExpanded ? null : onToggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.step5,
              right: tokens.spacing.step3,
              top: tokens.spacing.step3,
              bottom: tokens.spacing.step3,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing.step8),
              child: Row(
                children: [
                  Expanded(
                    child: isExpanded && !isEditingTitle
                        ? GestureDetector(
                            onTap: onTitleTap,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.text,
                              child: _TitleText(title: title, tokens: tokens),
                            ),
                          )
                        : isExpanded && isEditingTitle
                        ? TitleTextField(
                            initialValue: title,
                            onSave: onTitleSave,
                            resetToInitialValue: true,
                            onCancel: onTitleCancel,
                          )
                        : _TitleText(title: title, tokens: tokens),
                  ),
                  // Progress ring — always visible in header row.
                  _ProgressRow(
                    completedCount: completedCount,
                    totalCount: totalCount,
                    completionRate: completionRate,
                    tokens: tokens,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  // Chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0.0 : -0.25,
                    duration: chevronDuration,
                    child: GestureDetector(
                      onTap: onToggleExpand,
                      child: Icon(
                        Icons.expand_less,
                        size: 24,
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ),
                  // Menu — only shown when at least one action is available.
                  if (onDelete != null ||
                      onExportMarkdown != null ||
                      onShareMarkdown != null) ...[
                    SizedBox(width: tokens.spacing.step3),
                    _HeaderMenu(
                      onDelete: onDelete,
                      onExportMarkdown: onExportMarkdown,
                      onShareMarkdown: onShareMarkdown,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Filter strip — full-width grey background, only when expanded and
        // has items.
        AnimatedCrossFade(
          duration: filterStripDuration,
          sizeCurve: Curves.easeInOut,
          crossFadeState: isExpanded && totalCount > 0
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _FilterStrip(
            filter: filter,
            tokens: tokens,
            onFilterChanged: onFilterChanged,
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sorting mode header — drag handle + title + progress, no chevron/menu.
// ─────────────────────────────────────────────────────────────────────────────

class _SortingHeader extends StatelessWidget {
  const _SortingHeader({
    required this.title,
    required this.completedCount,
    required this.totalCount,
    required this.completionRate,
    this.reorderIndex,
  });

  final String title;
  final int completedCount;
  final int totalCount;
  final double completionRate;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final handle = Padding(
      padding: EdgeInsets.only(right: tokens.spacing.step3),
      child: Icon(
        Icons.drag_indicator,
        size: 28,
        color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.7),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: tokens.spacing.step3,
        horizontal: tokens.spacing.step5,
      ),
      child: Row(
        children: [
          if (reorderIndex != null)
            ReorderableDragStartListener(index: reorderIndex!, child: handle)
          else
            handle,
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
          _ProgressRow(
            completedCount: completedCount,
            totalCount: totalCount,
            completionRate: completionRate,
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring + "N/M done" label
// ─────────────────────────────────────────────────────────────────────────────

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
    if (totalCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildChecklistProgressRing(
          completionRate: completionRate,
          lowEmphasisColor: tokens.colors.text.lowEmphasis,
          semanticsLabel: context.messages.checklistProgressSemantics,
        ),
        SizedBox(width: tokens.spacing.step3),
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

// ─────────────────────────────────────────────────────────────────────────────
// Filter strip — full-width grey background row with Open / All tabs + divider.
// Matches the Widgetbook design exactly.
// ─────────────────────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.filter,
    required this.tokens,
    required this.onFilterChanged,
  });

  final ChecklistFilter filter;
  final DsTokens tokens;
  final ValueChanged<ChecklistFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40,
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha: 0.06,
          ),
          child: Row(
            children: [
              _FilterTab(
                label: context.messages.taskStatusOpen,
                isSelected: filter == ChecklistFilter.openOnly,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.openOnly),
              ),
              _FilterTab(
                label: context.messages.taskStatusDone,
                isSelected: filter == ChecklistFilter.doneOnly,
                tokens: tokens,
                onTap: () => onFilterChanged(ChecklistFilter.doneOnly),
              ),
              _FilterTab(
                label: context.messages.taskStatusAll,
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

class _FilterTab extends StatelessWidget {
  const _FilterTab({
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
    final accentColor = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: SizedBox(
        width: 64,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.24)
                        : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: isSelected
                          ? tokens.colors.text.highEmphasis
                          : tokens.colors.text.lowEmphasis,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 3,
                color: isSelected ? accentColor : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Title text
// ─────────────────────────────────────────────────────────────────────────────

class _TitleText extends StatelessWidget {
  const _TitleText({required this.title, required this.tokens});

  final String title;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
        color: tokens.colors.text.highEmphasis,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header menu — export, share, delete
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderMenu extends StatelessWidget {
  const _HeaderMenu({
    this.onDelete,
    this.onExportMarkdown,
    this.onShareMarkdown,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onShareMarkdown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
        tooltip: context.messages.checklistMoreTooltip,
        icon: const Icon(Icons.more_vert, size: 20),
        position: PopupMenuPosition.under,
        onSelected: (value) async {
          Future<void> deleteAction() async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(context.messages.checklistDelete),
                content: Text(context.messages.checklistItemDeleteWarning),
                actions: [
                  LottiTertiaryButton(
                    label: context.messages.checklistItemDeleteCancel,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  LottiTertiaryButton(
                    label: context.messages.checklistItemDeleteConfirm,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            );
            if (confirmed ?? false) onDelete?.call();
          }

          if (value == 'export') {
            onExportMarkdown?.call();
          } else if (value == 'share') {
            onShareMarkdown?.call();
          } else if (value == 'delete') {
            await deleteAction();
          }
        },
        itemBuilder: (context) => [
          if (onExportMarkdown != null)
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(MdiIcons.exportVariant, size: 18),
                  SizedBox(width: tokens.spacing.step3),
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
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  const Icon(Icons.ios_share, size: 18),
                  SizedBox(width: tokens.spacing.step3),
                  Flexible(
                    child: Text(
                      context.messages.checklistShare,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: tokens.spacing.step3),
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

// ─────────────────────────────────────────────────────────────────────────────
// Body — item list + add field
// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.itemIds,
    required this.checklistId,
    required this.taskId,
    required this.filter,
    required this.completionRate,
    required this.activeTotalCount,
    required this.focusNode,
    required this.onCreateItem,
    required this.onReorder,
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
  final void Function(int oldIndex, int newIndex) onReorder;

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
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: tokens.colors.background.level02,
                child: child,
              ),
              child: child,
            ),
            onReorder: onReorder,
            itemCount: itemIds.length,
            itemBuilder: (context, index) {
              final itemId = itemIds[index];
              return ChecklistItemRow(
                key: ValueKey('row-$checklistId-$itemId'),
                itemId: itemId,
                checklistId: checklistId,
                taskId: taskId,
                index: index,
                hideIfChecked: hideChecked,
                hideIfUnchecked: hideUnchecked,
                showDivider: index < itemIds.length - 1,
              );
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// Add item field — minimal pill-shaped TextField matching the Widgetbook design.
// Manages its own controller; clears on submit and fires the callback.
// ─────────────────────────────────────────────────────────────────────────────

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
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step3,
        right: tokens.spacing.step3,
        bottom: tokens.spacing.step4,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.colors.decorative.level01),
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
            // The outer `Container` already draws the pill border. Silence
            // every state-specific border the app's `InputDecorationTheme`
            // would otherwise overlay — in particular `focusedBorder`, a
            // 2.5 px primary-coloured outline that appeared inside the
            // pill on tap — along with the themed `filled` fill.
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
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

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring helper
// ─────────────────────────────────────────────────────────────────────────────

/// Bright green progress ring used in checklist headers.
Widget buildChecklistProgressRing({
  required double completionRate,
  required Color lowEmphasisColor,
  required String semanticsLabel,
  double size = 20,
  double strokeWidth = 3,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      color: successColor,
      backgroundColor: lowEmphasisColor.withValues(alpha: 0.3),
      value: completionRate,
      strokeWidth: strokeWidth,
      semanticsLabel: semanticsLabel,
    ),
  );
}
