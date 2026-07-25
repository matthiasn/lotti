import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
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
    this.subtitleEmphasis,
    this.semanticLabel,
    this.enabled = true,
    this.rowKey,
  });

  final String id;
  final Widget leading;
  final String title;
  final String? subtitle;
  final List<Widget> badges;

  /// Overrides the row's subtitle ink; see [DesignSystemListItem.subtitleEmphasis].
  final Color? subtitleEmphasis;

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
    this.createSemanticsLabel,
    this.reserveFooterInset = true,
    this.titleMaxLines = 1,
    this.topInset = true,
    this.rowSize = DesignSystemListItemSize.medium,
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

  /// Builds the create row's spoken name from the current query. Without it
  /// the row announces only the query, indistinguishable from an existing
  /// result — see [_PickerCreateRow.semanticsLabel].
  final String Function(String query)? createSemanticsLabel;

  /// Multi mode: reserve bottom space for the glass Apply footer. Embedded
  /// callers that supply their own action bar pass `false`.
  final bool reserveFooterInset;

  /// Title line cap for rows. Pickers listing long-form titles (tasks) raise
  /// this so a title never truncates mid-word on the row whose tap commits.
  final int titleMaxLines;

  /// Whether to inset the search field from the top. False when the sheet is
  /// embedded below other modal content that already supplies that gap.
  final bool topInset;

  /// Row density. Pickers listing the same entity a surrounding surface also
  /// lists should match that surface, so one entity has one rank throughout.
  final DesignSystemListItemSize rowSize;

  @override
  ConsumerState<EntityPickerSheet> createState() => _EntityPickerSheetState();
}

class _EntityPickerSheetState extends ConsumerState<EntityPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  /// A create is in flight. Guards [_create] against re-entry.
  bool _creating = false;

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
    // Serialized: the row stays mounted and hit-testable across the await, so
    // a double tap (or a repeated Enter on a slow write) otherwise starts a
    // second create for the same query and persists a duplicate entity —
    // which, depending on completion order, may then be linked twice or not
    // at all. One in-flight create per sheet.
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final newId = await widget.createFromQuery!(_query.trim());
      if (!mounted || newId == null) {
        return;
      }
      _onCreated(newId);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _onCreated(String newId) {
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

    // Cap at maxHeight for long lists (which then scroll internally via the
    // shrink-wrapped ListView below) without forcing short lists to claim
    // that full height — a fixed `Expanded` list here previously left a large
    // blank surface under a 2-3 row result set (design-review-panel finding).
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // Own top inset: every caller passes padding: EdgeInsets.zero to
            // the modal to get the row indent right, which also zeroes the
            // vertical inset and welds this field to the header divider.
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              widget.topInset ? tokens.spacing.step5 : 0,
              tokens.spacing.step5,
              tokens.spacing.step5,
            ),
            child: DesignSystemSearch(
              // Match the tasks/projects tab search (the small variant), whose
              // radii.l corner also lines up with the selection pills below.
              size: DesignSystemSearchSize.small,
              // Wide windows only: on a phone this would raise the keyboard
              // over the very results the field filters, and the list is the
              // point of the sheet.
              autofocus: MediaQuery.sizeOf(context).width >= kDesktopBreakpoint,
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
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step6,
                vertical: tokens.spacing.step6,
              ),
              child: Text(
                widget.emptyMessage,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            )
          else
            Flexible(
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
      shrinkWrap: true,
      padding: EdgeInsets.only(
        // Single-select lists still need a closing gap: without it the last
        // row sits flush against the sheet edge and reads as clipped.
        bottom: (_multi && widget.reserveFooterInset)
            ? DesignSystemGlassActionFooter.reservedHeightFor(context)
            : tokens.spacing.step5,
      ),
      children: [
        for (final entry in entries) _row(entry, staged),
        if (showCreate)
          _PickerCreateRow(
            query: _query.trim(),
            // Null while a create is in flight so the row reads as
            // unavailable rather than silently swallowing a second tap.
            onTap: _creating ? null : _create,
            rowKey: widget.createRowKey,
            semanticsLabel: widget.createSemanticsLabel?.call(_query.trim()),
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
      titleMaxLines: widget.titleMaxLines,
      rowSize: widget.rowSize,
      // Creation is exclusive: while a create is in flight every other row is
      // inert. Left tappable, picking an existing result would commit and pop
      // while the create was still pending, and the create's own completion
      // would then commit a second link and a second confirmation for a task
      // the user had already moved on from.
      onTap: (!item.enabled || _creating)
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

  /// Null disables the button. Use it when there is nothing to apply, so the
  /// loudest mark on the sheet stops promising a write it would not make.
  required VoidCallback? onTap,
  Key? buttonKey,
}) {
  return DesignSystemGlassActionFooter(
    child: DesignSystemButton(
      key: buttonKey,
      label: label,
      size: DesignSystemButtonSize.large,
      fullWidth: true,
      onPressed: onTap,
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
    required this.titleMaxLines,
    required this.rowSize,
  });

  final PickerItem item;
  final bool multi;
  final bool selected;
  final VoidCallback? onTap;
  final int titleMaxLines;
  final DesignSystemListItemSize rowSize;

  @override
  Widget build(BuildContext context) {
    final badges = item.badges.isEmpty
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: item.badges);
    return DesignSystemSelectionRow(
      key: item.rowKey,
      title: item.title,
      titleMaxLines: titleMaxLines,
      size: rowSize,
      subtitle: item.subtitle,
      subtitleEmphasis: item.subtitleEmphasis,
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
    this.semanticsLabel,
  });

  final String query;
  final VoidCallback? onTap;
  final Key? rowKey;

  /// Spoken name for the row. Without it a screen reader announces only the
  /// raw query — "Write the guide, button" — identical to how it announces an
  /// existing result, while the plus glyph that visually distinguishes the two
  /// is decorative and carries no semantics. Callers pass a phrasing that
  /// states the row *creates*.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final row = DesignSystemSelectionRow(
      key: rowKey,
      title: query,
      leading: const Icon(Icons.add_circle_outline),
      type: DesignSystemSelectionRowType.action,
      onTap: onTap,
    );
    final label = semanticsLabel;
    if (label == null) return row;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(child: row),
    );
  }
}
