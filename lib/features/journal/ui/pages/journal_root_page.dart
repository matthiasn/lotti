import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// How long the detail pane cross-fades when the selected entry changes.
///
/// [MotionDurations.short4] (200ms): row-by-row skimming is the split view's
/// core job, and a longer fade taxes every step of it. `TasksRootPage` uses
/// the same duration so switching rows feels identical in both split views.
const Duration journalDetailSwitchDuration = MotionDurations.short4;

/// Responsive entry point for the logbook.
///
/// Below `isDesktopLayout` it shows the full-width [InfiniteJournalPage] and
/// lets `JournalLocation` push [EntryDetailsPage] as its own route — the
/// unchanged mobile behaviour. On desktop it renders the same list beside a
/// resizable detail pane driven by `NavService.desktopSelectedEntryId`, so
/// tapping a row swaps the right pane instead of navigating away.
///
/// The pane width comes from `paneWidthControllerProvider.journalListPaneWidth`,
/// which is separate from the tasks/projects list width.
class JournalRootPage extends ConsumerWidget {
  const JournalRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopLayout(context)) {
      return const InfiniteJournalPage();
    }

    final paneWidths = ref.watch(paneWidthControllerProvider);

    return DecoratedBox(
      decoration: BoxDecoration(color: dsPageSurface(context)),
      child: _AutoSelectNewestEntry(
        child: ListDetailFocusTraversal(
          debugLabel: 'journal-split',
          listPane: SizedBox(
            width: paneWidths.journalListPaneWidth,
            child: const InfiniteJournalPage(),
          ),
          divider: ResizableDivider(
            onDrag: (delta) => ref
                .read(paneWidthControllerProvider.notifier)
                .updateJournalListPaneWidth(delta),
          ),
          // One unified canvas across both panes — the empty state and the
          // details sit on the same surface as the list column, so the pane
          // never flips identity on select/deselect.
          detailPane: ColoredBox(
            color: dsPageSurface(context),
            child: ValueListenableBuilder<String?>(
              valueListenable: getIt<NavService>().desktopSelectedEntryId,
              builder: (context, selectedEntryId, _) {
                final child = selectedEntryId != null
                    ? EntryDetailsPage(
                        key: ValueKey(selectedEntryId),
                        itemId: selectedEntryId,
                        // The list pane provides both the way back and the create
                        // FAB, so the detail pane renders neither.
                        showBackButton: false,
                        showFloatingActionButton: false,
                      )
                    // Reachable only when the feed itself is empty (or holds
                    // only tasks/events): the list pane already carries the
                    // "logbook is empty" message and the create CTA, so this
                    // pane defers with a quiet forward-pointing hint instead
                    // of echoing the same title at equal weight.
                    : Padding(
                        key: const ValueKey<String>(
                          'journal-root-empty-detail',
                        ),
                        // The list pane's zero-state centers in the viewport
                        // BELOW its header band; this pane has no header, so
                        // an equivalent top offset keeps both empty blocks on
                        // one optical horizon across the split.
                        padding: EdgeInsets.only(
                          top:
                              context.designTokens.spacing.step11 +
                              context.designTokens.spacing.step6,
                        ),
                        child: DesignSystemEmptyState(
                          icon: Icons.menu_book_outlined,
                          hint: context.messages.logbookNewEntriesHint,
                        ),
                      );

                return AnimatedSwitcher(
                  duration: journalDetailSwitchDuration,
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ...previousChildren.map(
                          (child) => ExcludeFocus(child: child),
                        ),
                        ?currentChild,
                      ],
                    );
                  },
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-visual side-effect widget for the desktop split: when nothing is
/// selected and the feed has loaded, selects the newest selectable entry so
/// the pane opens on "read the latest entry" (0 taps) instead of a dead
/// "select an entry" prompt. The empty state remains for a genuinely empty
/// list.
///
/// Tasks and events are skipped — they open in their own tabs, so
/// auto-selecting one would fill the pane with a row the list refuses to
/// highlight.
class _AutoSelectNewestEntry extends ConsumerStatefulWidget {
  const _AutoSelectNewestEntry({required this.child});

  final Widget child;

  @override
  ConsumerState<_AutoSelectNewestEntry> createState() =>
      _AutoSelectNewestEntryState();
}

class _AutoSelectNewestEntryState
    extends ConsumerState<_AutoSelectNewestEntry> {
  PagingController<int, JournalEntity>? _pagingController;

  /// A post-frame selection callback is already queued. Paging
  /// attach/load/complete can each notify before `JournalLocation` writes the
  /// selection back, so without this guard several callbacks would beam to the
  /// same entry in one frame.
  bool _selectionCallbackPending = false;

  @override
  void initState() {
    super.initState();
    // Re-fill when the selection is cleared (e.g. a bare /journal beam).
    getIt<NavService>().desktopSelectedEntryId.addListener(_maybeSelect);
  }

  @override
  void dispose() {
    _pagingController?.removeListener(_maybeSelect);
    if (getIt.isRegistered<NavService>()) {
      getIt<NavService>().desktopSelectedEntryId.removeListener(_maybeSelect);
    }
    super.dispose();
  }

  void _attach(PagingController<int, JournalEntity>? controller) {
    if (identical(controller, _pagingController)) return;
    _pagingController?.removeListener(_maybeSelect);
    _pagingController = controller?..addListener(_maybeSelect);
    _maybeSelect();
  }

  void _maybeSelect() {
    // Coalesce: collapse a burst of paging notifications into a single
    // post-frame pass so we never beam the same entry twice before the route
    // updates.
    if (_selectionCallbackPending) return;
    _selectionCallbackPending = true;
    // Post-frame: the paging controller notifies during build/layout, and the
    // route must not be mutated while widgets that listen to the selection are
    // being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionCallbackPending = false;
      if (!mounted || !getIt.isRegistered<NavService>()) return;
      final navService = getIt<NavService>();
      if (navService.desktopSelectedEntryId.value != null) return;
      final items = _pagingController?.items;
      if (items == null) return;
      for (final item in items) {
        if (item is Task || item is JournalEvent) continue;
        // Beam to the entry rather than writing the selection notifier
        // directly, so the URL stays the single source of truth: `JournalLocation`
        // then derives the selection from `/journal/<id>`, and any later
        // rebuild re-runs `buildPages` with the same route instead of writing
        // null over an off-URL selection and snapping back to the empty state.
        // Skip when the route already targets this entry (a rebuild before the
        // notifier caught up) so we don't re-beam an already-current path.
        final path = '/journal/${item.meta.id}';
        if (navService.currentPath != path) {
          beamToNamed(path);
        }
        return;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _attach(
      ref.watch(
        journalPageControllerProvider(false).select(
          (state) => state.pagingController,
        ),
      ),
    );
    return widget.child;
  }
}
