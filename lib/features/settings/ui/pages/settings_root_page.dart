import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_stack.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

/// Duration of the auto-scroll that keeps the newly-added column
/// visible when the stack grows past the viewport. Short enough to
/// feel responsive, long enough that the eye can follow.
const Duration _settingsStackScrollDuration = Duration(milliseconds: 220);

/// Root page for the Settings tab.
///
/// On mobile (< 960 px) it falls back to the single-page [SettingsPage]
/// with push navigation.
///
/// On desktop it renders a horizontally scrollable stack of navigation
/// columns — one per meaningful level of the route tree — so that
/// drilling from "Sync" into "Backfill sync" adds a new column on the
/// right without collapsing the previously-visible Sync sub-menu. The
/// column widths are fixed (non-draggable) at
/// `paneWidthControllerProvider.listPaneWidth`; the rightmost column
/// expands to fill remaining viewport space when the stack fits, and
/// the row scrolls horizontally otherwise.
class SettingsRootPage extends ConsumerWidget {
  const SettingsRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint(
      'SettingsRootPage w=${MediaQuery.sizeOf(context).width} '
      'route=${getIt<NavService>().desktopSelectedSettingsRoute.value?.path}',
    );
    if (!isDesktopLayout(context)) {
      return const SettingsPage();
    }

    // Opt-in desktop A2 tree-nav layout (plan §6). Keeps the legacy
    // column-stack as default until the flag goes default-on.
    final enableV2 =
        ref.watch(configFlagProvider(enableSettingsTreeFlag)).value ?? false;
    if (enableV2) {
      return const SettingsV2Page();
    }

    // `listPaneWidth` is a cross-feature token shared with tasks,
    // projects, and dashboards via `paneWidthControllerProvider`.
    // Settings has no divider of its own to adjust it; resizing the
    // pane in those other tabs will silently change the column width
    // here too, which is the intended "one global list-pane width"
    // behaviour.
    final listPaneWidth = ref.watch(
      paneWidthControllerProvider.select((state) => state.listPaneWidth),
    );

    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: getIt<NavService>().desktopSelectedSettingsRoute,
      builder: (context, route, _) {
        final columns = resolveSettingsColumnStack(route);
        return SettingsColumnStackView(
          columns: columns,
          columnWidth: listPaneWidth,
        );
      },
    );
  }
}

/// Lays out [columns] horizontally with fixed widths for every
/// non-leaf column. When the viewport is wide enough the final
/// column fills the remaining space; otherwise the row becomes a
/// horizontal scroll view and the freshly-added column auto-scrolls
/// into view.
///
/// Exposed so that layout tests can exercise the row/scroll behaviour
/// against stub children without pulling in every real settings page
/// and its Riverpod dependencies.
@visibleForTesting
class SettingsColumnStackView extends StatefulWidget {
  const SettingsColumnStackView({
    required this.columns,
    required this.columnWidth,
    super.key,
  });

  final List<SettingsColumn> columns;
  final double columnWidth;

  @override
  State<SettingsColumnStackView> createState() =>
      _SettingsColumnStackViewState();
}

class _SettingsColumnStackViewState extends State<SettingsColumnStackView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // First mount on an already-deep route (e.g. window-restore to
    // `/settings/sync/backfill` when the stack overflows the viewport)
    // wouldn't otherwise scroll: `didUpdateWidget` only fires on
    // updates. Jump — not animate — because the user is landing on
    // this route, not actively drilling into it.
    _scrollTrailingColumnIntoView(animate: false);
  }

  @override
  void didUpdateWidget(covariant SettingsColumnStackView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll when the user drills deeper *or* swaps the trailing
    // column for a different path at the same depth (e.g. navigating
    // from `/settings/labels/abc` to `/settings/labels/xyz`). Pure
    // collapses — length shrinks — are never scrolled: the user is
    // navigating back and the already-visible columns are the ones
    // they want to see.
    final drilledDeeper = widget.columns.length > oldWidget.columns.length;
    final lateralSwap =
        !drilledDeeper &&
        widget.columns.length == oldWidget.columns.length &&
        widget.columns.isNotEmpty &&
        widget.columns.last.key != oldWidget.columns.last.key;
    if (!drilledDeeper && !lateralSwap) return;

    _scrollTrailingColumnIntoView();
  }

  void _scrollTrailingColumnIntoView({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;
      // Avoid re-triggering once we're already pinned to the right
      // edge — otherwise rapid rebuilds can queue back-to-back
      // animations toward the same target.
      if ((position.pixels - position.maxScrollExtent).abs() < 0.5) return;
      if (animate) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: _settingsStackScrollDuration,
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dividerColor = tokens.colors.decorative.level01;

    return LayoutBuilder(
      builder: (context, constraints) {
        const dividerWidth = 1.0;
        final columnsCount = widget.columns.length;
        assert(
          columnsCount >= 1,
          'resolveSettingsColumnStack always yields at least the root column',
        );
        final totalDividers = (columnsCount - 1).toDouble();
        final totalFixedWidth =
            columnsCount * widget.columnWidth + totalDividers * dividerWidth;
        final fits = totalFixedWidth <= constraints.maxWidth;

        final children = <Widget>[];
        for (var i = 0; i < columnsCount; i++) {
          if (i > 0) {
            children.add(
              Container(width: dividerWidth, color: dividerColor),
            );
          }
          final column = widget.columns[i];
          final isLast = i == columnsCount - 1;
          children.add(
            KeyedSubtree(
              key: column.key,
              child: isLast && fits
                  ? Expanded(child: column.child)
                  : SizedBox(width: widget.columnWidth, child: column.child),
            ),
          );
        }

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );

        if (fits) {
          return row;
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // Pin the row to the viewport height — without this the
            // horizontal SingleChildScrollView imposes unbounded
            // vertical constraints and each column would collapse to
            // its intrinsic height. Individual pages are internally
            // scrollable, so capping at the viewport is correct.
            height: constraints.maxHeight,
            child: row,
          ),
        );
      },
    );
  }
}
