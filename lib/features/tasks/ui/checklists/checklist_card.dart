import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_row.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/app_prefs_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

part 'checklist_card_components.dart';
part 'checklist_card_body.dart';

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

    // Legacy bool migration: true → openOnly, false → all. Rewrites
    // as the new string form below on first read.
    final boolValue = await prefs.getBool(key);
    if (!mounted || boolValue == null) return;
    final migrated = boolValue ? ChecklistFilter.openOnly : ChecklistFilter.all;
    setState(() => _filter = migrated);
    // Persist as the new string format so future reads use the string path.
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
    final completed = resolveCompletedCount(
      completedCount: widget.completedCount,
      completionRate: widget.completionRate,
      total: total,
    );

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

/// Resolves the completed-item count shown on the card header: an explicit
/// [completedCount] wins; otherwise it is derived by rounding
/// `completionRate * total` (zero when the checklist is empty).
@visibleForTesting
int resolveCompletedCount({
  required int? completedCount,
  required double completionRate,
  required int total,
}) => completedCount ?? (total == 0 ? 0 : (completionRate * total).round());
