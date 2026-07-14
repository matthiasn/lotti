import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Whether the picker assigns a single entity or edits a set of entities.
enum PickerMode { single, multi }

/// A selectable row. The owning feature (categories, labels, …) supplies the
/// [leading] visual (icon chip, colour dot, …), the [title], an optional
/// [subtitle], and any decorative [badges] (already semantically labelled).
class PickerItem {
  const PickerItem({
    required this.id,
    required this.leading,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.semanticLabel,
    this.enabled = true,
    this.rowKey,
  });

  final String id;
  final Widget leading;
  final String title;
  final String? subtitle;
  final List<Widget> badges;

  /// The full accessible name for the row (title plus any state conveyed only
  /// by [badges]/[subtitle], e.g. "Work, Favorite"). Defaults to [title]. The
  /// row sets this explicitly and excludes the visual children from semantics,
  /// so the announcement is deterministic rather than merge-derived.
  final String? semanticLabel;

  final bool enabled;
  final Key? rowKey;
}

/// The shared, feature-agnostic picker body: a [DesignSystemSearch] field, a
/// scrollable list of rows (built per query by [entriesBuilder]), an appended
/// "create from search" row, and an empty state. Categories and labels both
/// compose this so they look and behave identically.
///
/// This widget renders the BODY only; multi-select callers add the glass Apply
/// footer themselves via [buildPickerApplyFooter] as the modal's sticky action
/// bar (single-select rows apply and pop on tap).
class EntityPickerSheet extends ConsumerStatefulWidget {
  const EntityPickerSheet({
    required this.mode,
    required this.entriesBuilder,
    required this.searchHintText,
    required this.emptyMessage,
    this.stagedNotifier,
    this.selectedId,
    this.onPick,
    this.createFromQuery,
    this.shouldShowCreate,
    this.createRowKey,
    this.reserveFooterInset = true,
    super.key,
  }) : assert(
         mode == PickerMode.single || stagedNotifier != null,
         'Multi mode requires a stagedNotifier.',
       ),
       assert(
         mode == PickerMode.multi || onPick != null,
         'Single mode requires an onPick callback.',
       );

  final PickerMode mode;

  /// Builds the ordered entries to show for the current trimmed search query.
  final List<PickerItem> Function(String query) entriesBuilder;

  final String searchHintText;

  /// Shown (centred) when there are no items and no create row.
  final String emptyMessage;

  /// Multi mode: externally-owned staged selection. Toggling a row mutates it.
  final ValueNotifier<Set<String>>? stagedNotifier;

  /// Single mode: the id whose row shows the trailing check.
  final String? selectedId;

  /// Single mode: invoked with the tapped item id (the caller pops/applies).
  final void Function(String id)? onPick;

  /// Optional create-from-search. Returns the new id (or null if cancelled);
  /// in multi mode it is staged, in single mode it is picked.
  final Future<String?> Function(String query)? createFromQuery;

  /// Whether to append the create row for the current trimmed query.
  final bool Function(String query)? shouldShowCreate;

  final Key? createRowKey;

  /// Multi mode: reserve bottom space for the glass Apply footer. Embedded
  /// callers that supply their own action bar pass `false`.
  final bool reserveFooterInset;

  @override
  ConsumerState<EntityPickerSheet> createState() => _EntityPickerSheetState();
}

class _EntityPickerSheetState extends ConsumerState<EntityPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  bool get _multi => widget.mode == PickerMode.multi;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    final notifier = widget.stagedNotifier!;
    final next = {...notifier.value};
    if (!next.add(id)) {
      next.remove(id);
    }
    notifier.value = next;
  }

  Future<void> _create() async {
    final newId = await widget.createFromQuery!(_query.trim());
    if (!mounted || newId == null) {
      return;
    }
    if (_multi) {
      final notifier = widget.stagedNotifier!;
      notifier.value = {...notifier.value, newId};
      // Clear the search so the stale create row for the same query cannot
      // reappear (and re-create a duplicate); the new id is already staged.
      setState(() {
        _query = '';
        _searchController.clear();
      });
    } else {
      widget.onPick?.call(newId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final query = _query.trim();
    final entries = widget.entriesBuilder(query);
    final items = entries.whereType<PickerItem>().toList();
    final showCreate =
        widget.createFromQuery != null &&
        (widget.shouldShowCreate?.call(query) ?? false);
    final showEmptyState = items.isEmpty && !showCreate;

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = math.min(screenHeight * 0.9, 640).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              0,
              tokens.spacing.step5,
              tokens.spacing.step5,
            ),
            child: DesignSystemSearch(
              // Match the tasks/projects tab search (the small variant), whose
              // radii.l corner also lines up with the selection pills below.
              size: DesignSystemSearchSize.small,
              controller: _searchController,
              hintText: widget.searchHintText,
              semanticsLabel: widget.searchHintText,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (_) {
                if (showCreate) {
                  _create();
                } else if (!_multi && items.isNotEmpty) {
                  // Single mode: Enter applies the first match, the standard
                  // search-box behaviour.
                  widget.onPick?.call(items.first.id);
                }
                // Multi mode: Enter is intentionally a no-op — there is no
                // single "submit" target; selection is toggled per row and
                // committed via the Apply footer.
              },
              onClear: () => setState(() => _query = ''),
            ),
          ),
          if (showEmptyState)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step6,
                    vertical: tokens.spacing.step4,
                  ),
                  child: Text(
                    widget.emptyMessage,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _multi
                  ? ValueListenableBuilder<Set<String>>(
                      valueListenable: widget.stagedNotifier!,
                      builder: (_, staged, _) =>
                          _buildList(tokens, entries, staged, showCreate),
                    )
                  : _buildList(tokens, entries, const {}, showCreate),
            ),
        ],
      ),
    );
  }

  Widget _buildList(
    DsTokens tokens,
    List<PickerItem> entries,
    Set<String> staged,
    bool showCreate,
  ) {
    return ListView(
      padding: EdgeInsets.only(
        bottom: (_multi && widget.reserveFooterInset)
            ? DesignSystemGlassActionFooter.reservedHeight
            : 0,
      ),
      children: [
        for (final entry in entries) _row(entry, staged),
        if (showCreate)
          _PickerCreateRow(
            query: _query.trim(),
            onTap: _create,
            rowKey: widget.createRowKey,
          ),
      ],
    );
  }

  Widget _row(PickerItem item, Set<String> staged) {
    final selected = _multi
        ? staged.contains(item.id)
        : item.id == widget.selectedId;
    return _PickerItemRow(
      item: item,
      multi: _multi,
      selected: selected,
      onTap: !item.enabled
          ? null
          : () => _multi ? _toggle(item.id) : widget.onPick?.call(item.id),
    );
  }
}

/// Shared glass Apply footer used by every multi-select picker so the action
/// bar looks identical across features.
Widget buildPickerApplyFooter({
  required BuildContext context,
  required String label,
  required VoidCallback onTap,
  Key? buttonKey,
}) {
  final tokens = context.designTokens;
  return DesignSystemGlassActionFooter(
    child: DesignSystemFilterActionButton(
      key: buttonKey,
      label: label,
      palette: DesignSystemFilterPalette.fromTokens(tokens),
      highlighted: true,
      textStyle: tokens.typography.styles.subtitle.subtitle1,
      onTap: onTap,
    ),
  );
}

/// A single tappable row. Multi-select rows show the shared checkbox
/// affordance; single-select rows show the shared selected marker.
class _PickerItemRow extends StatelessWidget {
  const _PickerItemRow({
    required this.item,
    required this.multi,
    required this.selected,
    required this.onTap,
  });

  final PickerItem item;
  final bool multi;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badges = item.badges.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: item.badges);
    return DesignSystemSelectionRow(
      key: item.rowKey,
      title: item.title,
      subtitle: item.subtitle,
      leading: item.leading,
      trailing: badges,
      type: multi
          ? DesignSystemSelectionRowType.multiSelect
          : DesignSystemSelectionRowType.singleSelect,
      selected: selected,
      semanticLabel: item.semanticLabel,
      onTap: onTap,
    );
  }
}

/// The "create from search" row, shown when the query has no usable match.
/// Visually distinct from an item row: a plain add glyph, no selection
/// affordance.
class _PickerCreateRow extends StatelessWidget {
  const _PickerCreateRow({
    required this.query,
    required this.onTap,
    this.rowKey,
  });

  final String query;
  final VoidCallback onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    return DesignSystemSelectionRow(
      key: rowKey,
      title: query,
      leading: const Icon(Icons.add_circle_outline),
      type: DesignSystemSelectionRowType.action,
      onTap: onTap,
    );
  }
}
