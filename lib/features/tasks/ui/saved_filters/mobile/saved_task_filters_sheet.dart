import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/saved_task_filter.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filter_pill.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet_bar.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_toast.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the saved-filters sheet internals.
@visibleForTesting
abstract final class SavedTaskFiltersSheetKeys {
  static const Key root = Key('saved-filters-sheet');
  static const Key editToggle = Key('saved-filters-sheet-edit-toggle');
  static const Key allRow = Key('saved-filters-sheet-all-row');
  static const Key saveCurrent = Key('saved-filters-sheet-save-current');
  static const Key pinnedEmpty = Key('saved-filters-sheet-pinned-empty');
  static Key row(String id) => Key('saved-filters-sheet-row-$id');
  static Key dragHandle(String id) =>
      Key('saved-filters-sheet-drag-handle-$id');
  static Key rename(String id) => Key('saved-filters-sheet-rename-$id');
  static Key delete(String id) => Key('saved-filters-sheet-delete-$id');
}

/// Opens the saved-filters sheet as a Wolt bottom sheet (mobile) / dialog
/// (desktop) — the complete switcher + manager described in the plan.
///
/// A sliver page, so the sheet's rows live in the modal's own scroll view:
/// one scroll for the whole sheet, never a list scrolling inside it. Saving
/// the current filter is the page's sticky action, on the glass footer every
/// modal's primary action uses.
Future<void> showSavedTaskFiltersSheet(BuildContext context) {
  return ModalUtils.showMultiPageModal<void>(
    context: context,
    pageListBuilder: (modalContext) => [
      ModalUtils.sliverModalSheetPage(
        context: modalContext,
        title: modalContext.messages.tasksSavedFiltersSheetTitle,
        stickyActionBar: const SavedTaskFiltersSaveFooter(),
        slivers: const [SavedTaskFiltersSheet()],
      ),
    ],
  );
}

/// The sheet's sticky footer: *Save current filter…* as the page's one
/// primary action, on the app's standard glass [DesignSystemModalActionBar].
///
/// The compact layout keeps the button at its own width on the trailing
/// edge: saving is an occasional action beside a list the user mostly picks
/// from, so it should not span the sheet like a form's confirm. The padding
/// matches [DesignSystemGlassActionFooter], whose reserved height the rows
/// keep clear.
///
/// Closes the sheet only when a filter was actually saved — a cancelled or
/// blank name leaves the user on the list.
class SavedTaskFiltersSaveFooter extends ConsumerWidget {
  const SavedTaskFiltersSaveFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.designTokens.spacing;
    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.step5,
        vertical: spacing.step4,
      ),
      primary: DesignSystemButton(
        key: SavedTaskFiltersSheetKeys.saveCurrent,
        label: context.messages.tasksSavedFiltersSaveCurrentAs,
        leadingIcon: LottiIcons.add,
        size: DesignSystemButtonSize.large,
        fullWidth: true,
        onPressed: () => _save(context, ref),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final created = await promptSaveCurrentTaskFilter(context, ref);
    if (created != null && context.mounted) {
      await Navigator.of(context).maybePop();
    }
  }
}

/// The vertical, single-select switcher + manager body, as one sliver.
///
/// [SavedTaskFiltersSheetBar] pins to the top of the scroll view; All tasks,
/// the saved filters and the create row scroll beneath it. Pumpable directly
/// in tests inside a `CustomScrollView`; hosted inside
/// [showSavedTaskFiltersSheet] in the app.
///
/// With the list's pinned-only switch on, the rows are the pinned filters
/// only — in Edit mode too, where a drag reorders them among themselves —
/// and an empty pinned set says how to fill it.
class SavedTaskFiltersSheet extends ConsumerStatefulWidget {
  const SavedTaskFiltersSheet({super.key});

  @override
  ConsumerState<SavedTaskFiltersSheet> createState() =>
      _SavedTaskFiltersSheetState();
}

class _SavedTaskFiltersSheetState extends ConsumerState<SavedTaskFiltersSheet> {
  bool _editing = false;
  final GlobalKey _activeRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Pre-scroll the active row into view once laid out (best-effort: the
    // enclosing modal owns the scroll view the sheet's slivers live in).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeRowKey.currentContext;
      // Only scroll when an enclosing Scrollable exists (the hosting modal owns
      // it); a directly-pumped sheet has none and must not throw.
      if (ctx != null && Scrollable.maybeOf(ctx) != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5);
      }
    });
  }

  SavedTaskFilterActivator get _activator => SavedTaskFilterActivator(
    ref.read(journalPageControllerProvider(true).notifier),
  );

  Future<void> _applySaved(SavedTaskFilter saved) async {
    await _activator.activate(saved);
    ref.read(savedTaskFilterMruProvider.notifier).touch(saved.id);
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _applyAll() async {
    await _activator.clearToDefault();
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _rename(SavedTaskFilter saved) async {
    final name = await promptTaskFilterName(context, initialValue: saved.name);
    if (name == null) return;
    // The name modal is an async gap — don't read a disposed ref if the sheet
    // closed while it was open.
    if (!mounted) return;
    await ref
        .read(savedTaskFiltersControllerProvider.notifier)
        .rename(saved.id, name);
  }

  Future<void> _delete(SavedTaskFilter saved) async {
    final messages = context.messages;
    // Capture whether the deleted filter is the live selection *before* the
    // async gap so a background re-match can't flip the answer mid-delete.
    final wasActive = ref.read(currentSavedTaskFilterIdProvider) == saved.id;
    final confirmed = await showConfirmationModal(
      context: context,
      message: messages.tasksSavedFiltersDeleteConfirmMessage(saved.name),
      confirmLabel: messages.tasksSavedFiltersDeleteConfirmAction,
      cancelLabel: messages.tasksSavedFiltersSavePopupCancel,
    );
    if (!confirmed) return;
    // The confirmation modal is an async gap — bail before touching the ref if
    // the sheet unmounted meanwhile.
    if (!mounted) return;
    await ref
        .read(savedTaskFiltersControllerProvider.notifier)
        .delete(saved.id);
    // Safe fallback: deleting the *active* filter would otherwise leave the
    // list showing an orphaned filter shape with no pill selected. Reset the
    // live filter to the default "All" filter so the selection is never
    // undefined. clearToDefault() makes the live shape match no saved filter,
    // so `currentSavedTaskFilterIdProvider` resolves to null ("All" selected).
    if (wasActive) await _activator.clearToDefault();
    if (mounted) showSavedTaskFilterDeletedToast(context);
  }

  /// Moves the row at [oldIndex] of the [shown] rows to [newIndex], its
  /// final position. Indices are into the shown rows, which may be the
  /// pinned subset; the controller places the move by id, so the unpinned
  /// filters keep their places in the full list.
  void _reorder(
    List<SavedTaskFilter> shown,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) return;
    final dragId = shown[oldIndex].id;
    final targetId = shown[newIndex].id;
    unawaited(
      ref
          .read(savedTaskFiltersControllerProvider.notifier)
          .reorder(dragId, targetId),
    );
  }

  static Key _editItemKey(String id) => ValueKey('saved-filter-sheet-item-$id');

  Future<void> _togglePin(SavedTaskFilter saved) =>
      ref.read(savedTaskFiltersControllerProvider.notifier).togglePin(saved.id);

  Future<void> _setPinnedOnly({required bool pinnedOnly}) => ref
      .read(savedTaskFiltersPinnedOnlyProvider.notifier)
      .set(pinnedOnly: pinnedOnly);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    final shown = ref.watch(shownSavedTaskFiltersProvider);
    final pinnedOnly =
        ref.watch(savedTaskFiltersPinnedOnlyProvider).value ?? false;
    final activeId = ref.watch(currentSavedTaskFilterIdProvider);
    final hasUnsaved = ref.watch(tasksFilterHasUnsavedClausesProvider);
    // Stale-while-revalidate: keep the last-known counts during a refresh so
    // the column never flashes back to placeholders on a background sync.
    final counts = ref.watch(savedTaskFilterCountsProvider).value;
    final total = ref.watch(allTasksTotalCountProvider).value;

    final allSelected = activeId == null && !hasUnsaved;
    // The last row must scroll clear of the sticky save footer.
    final pagePadding = EdgeInsetsDirectional.only(
      start: tokens.spacing.step5,
      end: tokens.spacing.step5,
      bottom: DesignSystemGlassActionFooter.reservedHeightFor(context),
    );

    // Rows are keyed by filter id, and these maps let each builder find a
    // row again after the shown list shifts — an unpin in pinned-only mode
    // drops a row — instead of matching by index and rebuilding every row
    // below the gap. The reorderable list gets one too, but there it cannot
    // save the rows: `SliverReorderableList` wraps each item in a global key
    // that includes its index, so a shift rebuilds what follows whatever the
    // callback says. Edit rows carry no pin, so only a delete shifts them.
    final rowIndex = {
      for (final (index, f) in shown.indexed)
        SavedTaskFiltersSheetKeys.row(f.id): index,
    };
    final editItemIndex = {
      for (final (index, f) in shown.indexed) _editItemKey(f.id): index,
    };

    final Widget rows;
    if (_editing) {
      rows = SliverReorderableList(
        itemCount: shown.length,
        findChildIndexCallback: (key) => editItemIndex[key],
        onReorderItem: (oldIndex, newIndex) =>
            _reorder(shown, oldIndex, newIndex),
        proxyDecorator: (child, index, animation) => Material(
          type: MaterialType.transparency,
          child: child,
        ),
        itemBuilder: (context, index) {
          final f = shown[index];
          return KeyedSubtree(
            key: _editItemKey(f.id),
            child: _SavedFilterRow(
              key: SavedTaskFiltersSheetKeys.row(f.id),
              rowKey: f.id == activeId ? _activeRowKey : null,
              filter: f,
              selected: f.id == activeId,
              count: counts?[f.id],
              editing: true,
              reorderIndex: index,
              onRename: () => _rename(f),
              onDelete: () => _delete(f),
            ),
          );
        },
      );
    } else {
      rows = SliverList.builder(
        itemCount: shown.length,
        findChildIndexCallback: (key) => rowIndex[key],
        itemBuilder: (context, index) {
          final f = shown[index];
          return _SavedFilterRow(
            key: SavedTaskFiltersSheetKeys.row(f.id),
            rowKey: f.id == activeId ? _activeRowKey : null,
            filter: f,
            selected: f.id == activeId,
            count: counts?[f.id],
            editing: false,
            onTap: () => _applySaved(f),
            onTogglePin: () => _togglePin(f),
          );
        },
      );
    }

    return SliverMainAxisGroup(
      key: SavedTaskFiltersSheetKeys.root,
      slivers: [
        PinnedHeaderSliver(
          child: SavedTaskFiltersSheetBar(
            pinnedOnly: pinnedOnly,
            onPinnedOnlyChanged: (value) => _setPinnedOnly(pinnedOnly: value),
            editing: _editing,
            onEditToggled: () => setState(() => _editing = !_editing),
            editToggleKey: SavedTaskFiltersSheetKeys.editToggle,
          ),
        ),
        SliverPadding(
          padding: pagePadding.copyWith(top: tokens.spacing.step3),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _AllTasksRow(
                  key: SavedTaskFiltersSheetKeys.allRow,
                  rowKey: allSelected ? _activeRowKey : null,
                  selected: allSelected,
                  total: total,
                  editing: _editing,
                  onTap: _applyAll,
                ),
              ),
              if (_editing && shown.isNotEmpty)
                SliverToBoxAdapter(
                  child: _HelperText(
                    pinnedOnly
                        ? messages.tasksSavedFiltersReorderHelperPinned
                        : messages.tasksSavedFiltersReorderHelper,
                  ),
                ),
              if (pinnedOnly && shown.isEmpty)
                SliverToBoxAdapter(
                  child: _HelperText(
                    messages.tasksSavedFiltersPinnedOnlyEmpty,
                    key: SavedTaskFiltersSheetKeys.pinnedEmpty,
                  ),
                ),
              rows,
            ],
          ),
        ),
      ],
    );
  }
}

/// A quiet caption between All tasks and the saved rows: the reorder hint
/// in Edit mode, or how to fill an empty pinned-only list.
class _HelperText extends StatelessWidget {
  const _HelperText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.spacing.step3,
        tokens.spacing.step2,
        tokens.spacing.step3,
        tokens.spacing.step3,
      ),
      child: Text(
        text,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

/// Leading row indicator. Its meaning depends on [editing]:
///
/// * **Outside Edit mode** it is a single-select **radio**: a filled teal dot
///   when selected, an empty ring otherwise. The resting ring uses
///   `text.mediumEmphasis` (not the near-invisible `lowEmphasis`) so the
///   control is clearly perceivable before it is filled; the selected state
///   keeps the teal `interactive.enabled` fill.
/// * **In Edit mode selection is disabled** (rows surface Rename / Delete, not
///   a tap-to-select), so a radio would be a mixed signal. The indicator
///   degrades to a non-interactive **status dot** — a filled accent dot marks
///   the currently-applied filter; non-active rows show an empty slot of the
///   same footprint so the name column never shifts when Edit toggles.
class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected, this.editing = false});

  final bool selected;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (editing) {
      // Status indicator (not a radio): same step5 footprint as the radio so
      // the name column stays put across the Edit toggle.
      return SizedBox(
        width: tokens.spacing.step5,
        height: tokens.spacing.step5,
        child: selected
            ? Center(
                child: Container(
                  width: tokens.spacing.step4,
                  height: tokens.spacing.step4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.colors.interactive.enabled,
                  ),
                ),
              )
            : null,
      );
    }
    return Icon(
      selected ? LottiIcons.radioSelected : LottiIcons.radioUnselected,
      size: tokens.spacing.step5,
      color: selected
          ? tokens.colors.interactive.enabled
          : tokens.colors.text.mediumEmphasis,
    );
  }
}

/// Shared full-width ≥48dp row scaffold with single-select semantics.
///
/// The active row carries a token-backed `colors.surface.selected` background
/// tint — the same mint the rail's selected pill uses (`DsPill.selected`) — so
/// selection is multi-channel (tinted surface + radio + bold name) and shares
/// the rail's visual vocabulary, instead of leaning on the teal radio alone
/// next to a teal category dot. The tint sits behind a transparent [Material]
/// so the tap ripple still draws on top, clipped to the row's `radii.m`.
///
/// [trailing] sits inside the tint but outside the row's tap target and its
/// merged semantics, so a control placed there (the pin toggle) is its own
/// button to a screen reader and its own hit target to a finger.
class _SheetRowScaffold extends StatelessWidget {
  const _SheetRowScaffold({
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    required this.children,
    this.trailing,
  });

  final bool selected;
  final String semanticsLabel;
  final VoidCallback onTap;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.m);
    final row = Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            hoverColor: tokens.colors.surface.hover,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minTarget),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: Row(children: children),
              ),
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? tokens.colors.surface.selected : null,
        borderRadius: radius,
      ),
      child: trailing == null
          ? row
          : Row(
              children: [
                Expanded(child: row),
                trailing!,
              ],
            ),
    );
  }
}

/// The empty slot a row without a pin keeps where the pin would be, so its
/// count lines up with the counts of the rows that have one.
class _PinSlot extends StatelessWidget {
  const _PinSlot();

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return SizedBox(width: spacing.step8 + spacing.step3);
  }
}

class _AllTasksRow extends StatelessWidget {
  const _AllTasksRow({
    required this.selected,
    required this.total,
    required this.editing,
    required this.onTap,
    this.rowKey,
    super.key,
  });

  final bool selected;
  final int? total;
  final bool editing;
  final VoidCallback onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final name = messages.tasksSavedFiltersAllTasks;
    return KeyedSubtree(
      key: rowKey,
      child: _SheetRowScaffold(
        selected: selected,
        semanticsLabel: total == null
            ? name
            : '$name, ${messages.tasksSavedFiltersTaskCount(total!)}',
        onTap: onTap,
        // All tasks is not a saved filter and cannot be pinned; outside Edit
        // mode it keeps the pin's slot so its count sits in the column.
        trailing: editing ? null : const _PinSlot(),
        children: [
          _SelectionIndicator(selected: selected, editing: editing),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          // "All tasks" is not a saved definition, so it gets no per-row
          // actions in Edit mode — and to avoid mixing a lone count against the
          // action-pairs on every other row, it also drops its count there.
          if (!editing)
            SavedFilterCountText(
              count: total,
              selected: selected,
              minWidth: tokens.spacing.step8,
            ),
        ],
      ),
    );
  }
}

class _SavedFilterRow extends StatelessWidget {
  const _SavedFilterRow({
    required this.filter,
    required this.selected,
    required this.count,
    required this.editing,
    this.onTap,
    this.onTogglePin,
    this.onRename,
    this.onDelete,
    this.reorderIndex,
    this.rowKey,
    super.key,
  });

  final SavedTaskFilter filter;
  final bool selected;
  final int? count;
  final bool editing;
  final VoidCallback? onTap;

  /// Flips [filter]'s pin. Outside Edit mode only: Edit rows spend their
  /// width on the drag handle and the Rename / Delete pair.
  final VoidCallback? onTogglePin;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final int? reorderIndex;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final categoryColor = savedFilterCategoryColor(filter);
    final categoryName = savedFilterCategoryName(filter);
    final countClause = count == null
        ? null
        : messages.tasksSavedFiltersTaskCount(count!);
    final semanticsLabel = [
      ?categoryName,
      filter.name,
      ?countClause,
    ].join(', ');

    final nameWidget = Expanded(
      child: Row(
        children: [
          if (categoryColor != null) ...[
            Container(
              width: tokens.spacing.step3,
              height: tokens.spacing.step3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: categoryColor,
                // A thin background-toned ring so a teal category colour stays
                // a distinct disc against the active row's teal selection tint
                // (`surface.selected`) — matching the rail pill's dot moat.
                border: Border.all(color: tokens.colors.background.level01),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
          Flexible(
            child: Text(
              filter.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    if (editing) {
      // In edit mode the row is not selectable; it surfaces labeled Rename /
      // Delete actions instead of the count column. It keeps the SAME 48dp row
      // height and the same horizontal padding as the normal
      // `_SheetRowScaffold` row, so toggling Edit swaps the count for the action
      // pair without the list rows jumping or shifting the radio / name
      // positions. The ≥48dp action targets define the row height exactly, so
      // (unlike the normal row, whose short content is floated to 48 by its
      // minHeight + vertical padding) no extra vertical padding is added — that
      // would push the row to 56 and make the list jump on toggle.
      return KeyedSubtree(
        key: rowKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: tokens.spacing.step8 + tokens.spacing.step3,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
            child: Row(
              children: [
                _EditDragHandle(
                  filterId: filter.id,
                  index: reorderIndex!,
                  selected: selected,
                ),
                nameWidget,
                _EditAction(
                  buttonKey: SavedTaskFiltersSheetKeys.rename(filter.id),
                  icon: LottiIcons.edit,
                  tooltip: messages.tasksSavedFiltersRenameNamed(filter.name),
                  onTap: onRename!,
                ),
                // Generous gap between the two ≥48dp targets so the destructive
                // Delete is clearly separated from Rename (mis-tap safety) and
                // is not the smallest / tightest-packed element in the row.
                SizedBox(width: tokens.spacing.step5),
                _EditAction(
                  buttonKey: SavedTaskFiltersSheetKeys.delete(filter.id),
                  icon: LottiIcons.delete,
                  tooltip: messages.tasksSavedFiltersDeleteNamed(filter.name),
                  onTap: onDelete!,
                  destructive: true,
                ),
                // Breathing room between the destructive target and the row's
                // right edge, so Delete isn't the edge-most element (on top of
                // the row's own step3 horizontal padding → step5 total inset).
                SizedBox(width: tokens.spacing.step3),
              ],
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: rowKey,
      child: _SheetRowScaffold(
        selected: selected,
        semanticsLabel: semanticsLabel,
        onTap: onTap!,
        trailing: SavedTaskFilterPinToggle(
          filterId: filter.id,
          filterName: filter.name,
          pinned: filter.pinned,
          onToggle: onTogglePin!,
        ),
        children: [
          _SelectionIndicator(selected: selected),
          SizedBox(width: tokens.spacing.step3),
          nameWidget,
          SavedFilterCountText(
            count: count,
            selected: selected,
            minWidth: tokens.spacing.step8,
          ),
        ],
      ),
    );
  }
}

class _EditDragHandle extends StatelessWidget {
  const _EditDragHandle({
    required this.filterId,
    required this.index,
    required this.selected,
  });

  final String filterId;
  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = context.messages.tasksSavedFilterDragHandleSemantics;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: ReorderableDragStartListener(
          key: SavedTaskFiltersSheetKeys.dragHandle(filterId),
          index: index,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minTarget,
              minHeight: minTarget,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LottiIcons.drag,
                  size: tokens.spacing.step5,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                if (selected) ...[
                  SizedBox(width: tokens.spacing.step1),
                  Container(
                    width: tokens.spacing.step3,
                    height: tokens.spacing.step3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.colors.interactive.enabled,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditAction extends StatelessWidget {
  const _EditAction({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minTarget,
              minHeight: minTarget,
            ),
            child: Center(
              child: Icon(
                // Larger than the radio / create-row glyphs (step5) so the
                // Rename / Delete controls carry clear icon weight and the
                // destructive target isn't the smallest element in the row.
                icon,
                size: tokens.spacing.step6,
                color: destructive
                    ? tokens.colors.alert.error.defaultColor
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
