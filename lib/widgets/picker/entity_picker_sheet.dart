import 'dart:async';
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

/// Idle time after the last keystroke before an asynchronous picker resolves
/// the query it was given (see [EntityPickerSheet.onQueryResolve]).
///
/// Long enough that a burst of typing costs one lookup instead of one per
/// character, short enough that a deliberate pause still reads as instant.
/// Pickers that filter a list they already hold never wait at all.
const Duration entityPickerSearchDebounce = Duration(milliseconds: 220);

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
    this.onQueryResolve,
    this.searchDebounce = entityPickerSearchDebounce,
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
  ///
  /// May return a future. When it does, the create flow holds its exclusivity
  /// lock until that future completes — a pick usually kicks off a write of
  /// its own (linking, in the task picker), and releasing the lock the moment
  /// the callback *returned* would re-enable every row while that write was
  /// still in flight.
  final FutureOr<void> Function(String id)? onPick;

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

  /// Loads whatever [entriesBuilder] and [shouldShowCreate] need before they
  /// can answer for a query — a full-text lookup, in the task picker.
  ///
  /// Supplied, the sheet stops recomputing on every keystroke. It waits
  /// [searchDebounce] after the last one, runs this, and only then advances
  /// the query the rows, the create row, the empty state and Enter are all
  /// derived from. Those move together, in one frame, describing one query.
  ///
  /// Without it every keystroke rebuilt immediately against results that had
  /// not caught up yet, so a query mid-flight rendered as "nothing found" with
  /// no create row — a false dead end that then re-populated a frame later,
  /// resizing the sheet twice per character.
  ///
  /// Null (the default) keeps the picker synchronous: pickers filtering a list
  /// they already hold apply each keystroke at once.
  final Future<void> Function(String query)? onQueryResolve;

  /// Idle time after the last keystroke before [onQueryResolve] runs. Ignored
  /// without it.
  final Duration searchDebounce;

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

  /// The settled query — the single thing every visible part of the sheet is
  /// derived from: which rows exist, whether the create row is offered, the
  /// label it carries, the empty state, and what Enter acts on.
  ///
  /// With [EntityPickerSheet.onQueryResolve] set it only ever advances to a
  /// query that hook has finished resolving, which is what keeps those parts
  /// in agreement instead of showing one query's rows beside another's
  /// verdict on whether anything matched.
  String _query = '';

  /// What is actually in the field right now. Runs ahead of [_query] while a
  /// keystroke is inside the debounce window or its resolve is still out.
  String _typedQuery = '';

  Timer? _debounce;

  /// Guards out-of-order resolves: a slow lookup for a query the user has
  /// already moved on from must not commit over a newer one that landed first.
  int _resolveGeneration = 0;

  /// A create is in flight. Guards [_create] against re-entry.
  bool _creating = false;

  bool get _multi => widget.mode == PickerMode.multi;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Makes [value] the settled query at once, abandoning any pending debounce
  /// and stranding any resolve still in flight.
  void _applyImmediately(String value) {
    _debounce?.cancel();
    _debounce = null;
    _resolveGeneration++;
    setState(() => _query = value);
  }

  void _onSearchChanged(String value) {
    _typedQuery = value;

    // Nothing to wait for when the picker filters a list it already holds, and
    // an emptied field is not a search: the unfiltered list should snap back
    // rather than linger on the query that was just deleted.
    if (widget.onQueryResolve == null || value.trim().isEmpty) {
      _applyImmediately(value);
      return;
    }

    // Deliberately no setState: holding the last settled answer on screen
    // while the next one loads is the whole point.
    _debounce?.cancel();

    // Supersede any resolve already in flight, here rather than when the next
    // one starts. Waiting for the timer left the older lookup holding the
    // current generation for the whole debounce window, so it committed — and
    // the sheet showed rows and a create row for "al" while the field already
    // read "alp", which is the stale-query mismatch this all exists to stop.
    _resolveGeneration++;

    _debounce = Timer(
      widget.searchDebounce,
      () => unawaited(_resolveAndCommit(value)),
    );
  }

  /// Resolves [value] through [EntityPickerSheet.onQueryResolve], then commits
  /// it as the settled query.
  ///
  /// Commits even when the hook throws. The feature owns reporting its own
  /// failure; what the sheet must not do is leave the list pinned to a query
  /// the user has left because an index happened to be unavailable.
  Future<void> _resolveAndCommit(String value) async {
    final generation = ++_resolveGeneration;
    try {
      await widget.onQueryResolve!(value);
    } catch (_) {
      // Deliberately swallowed — see above.
    }
    if (!mounted || generation != _resolveGeneration) return;
    setState(() => _query = value);
  }

  /// The rows and create-row verdict for the settled query.
  ///
  /// Shared by `build` and [_onSubmitted] so Enter can never act on a
  /// different answer than the one on screen.
  ({List<PickerItem> items, bool showCreate}) _resolveEntries() {
    final query = _query.trim();
    return (
      items: widget.entriesBuilder(query),
      showCreate:
          widget.createFromQuery != null &&
          (widget.shouldShowCreate?.call(query) ?? false),
    );
  }

  Future<void> _onSubmitted() async {
    // The same exclusivity the rows have. The field stays enabled during a
    // create — the query is still worth editing — so without this a user could
    // change it and press Enter, picking an existing item while the create's
    // own link was still in flight, and land two links or an orphaned new task.
    if (_creating) return;

    // Enter acts on what was typed, not on whatever the debounce has caught up
    // with, so flush first. Afterwards the sheet must be settled on *exactly*
    // the submitted query — both what is on screen and what is in the field —
    // or this Enter has been overtaken and acting on it would commit an entity
    // the user did not choose. The two halves catch different races:
    //   • `_query != submitted`: the field was emptied mid-flush, which strands
    //     the commit. Both fields move to '', so comparing them to each other
    //     would find them equal and apply the first row of the unfiltered list.
    //   • `_typedQuery != submitted`: the user kept typing, so they have moved
    //     past the query they submitted even though it settled.
    final submitted = _typedQuery;
    if (submitted != _query) {
      _debounce?.cancel();
      await _resolveAndCommit(submitted);
      if (!mounted ||
          _creating ||
          _query != submitted ||
          _typedQuery != submitted) {
        return;
      }
    }

    final resolved = _resolveEntries();
    if (resolved.showCreate) {
      unawaited(_create());
    } else if (!_multi && resolved.items.isNotEmpty) {
      // Single mode: Enter applies the first match, the standard search-box
      // behaviour.
      await widget.onPick?.call(resolved.items.first.id);
    }
    // Multi mode: Enter is intentionally a no-op — there is no single "submit"
    // target; selection is toggled per row and committed via the Apply footer.
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
      await _onCreated(newId);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _onCreated(String newId) async {
    if (_multi) {
      final notifier = widget.stagedNotifier!;
      notifier.value = {...notifier.value, newId};
      // Clear the search so the stale create row for the same query cannot
      // reappear (and re-create a duplicate); the new id is already staged.
      // Clearing the controller does not notify `onChanged`, so the settled
      // query has to be reset here too — otherwise the create row survives
      // its own query being wiped.
      _typedQuery = '';
      _searchController.clear();
      _applyImmediately('');
    } else {
      // Awaited, so the lock outlives whatever the pick starts.
      await widget.onPick?.call(newId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final resolved = _resolveEntries();
    final entries = resolved.items;
    final showCreate = resolved.showCreate;
    final showEmptyState = entries.isEmpty && !showCreate;

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
              onChanged: _onSearchChanged,
              onSubmitted: (_) => unawaited(_onSubmitted()),
              onClear: () => _onSearchChanged(''),
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
