import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart';
import 'package:lotti/features/design_system/components/headers/design_system_header.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/settings_breadcrumb_trail.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_scope.dart';
import 'package:lotti/features/settings/ui/pages/settings_column_stack.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Duration of the auto-scroll that keeps the newly-added column
/// visible when the stack grows past the viewport. Short enough to
/// feel responsive, long enough that the eye can follow.
const Duration _settingsStackScrollDuration = Duration(milliseconds: 220);

/// Minimum width applied to every navigation column in the settings
/// multi-column stack. Non-last columns render at exactly this width;
/// the last column expands past it to fill the remaining viewport
/// when space allows. 360 px is the smallest width at which every
/// settings list item (icon + two lines of text + chevron + optional
/// trailing badge) still fits without wrapping.
const double settingsColumnMinWidth = 360;

/// Root page for the Settings tab.
///
/// On mobile (< 960 px) it falls back to the single-page [SettingsPage]
/// with push navigation.
///
/// On desktop it renders:
///
/// * A top bar ([_SettingsTopBar]) with a settings cog, the current
///   leaf title, and a breadcrumb trail reflecting the active route.
/// * A horizontally scrollable stack of navigation columns —
///   [SettingsColumnStackView] — so drilling from "Sync" into
///   "Backfill sync" adds a new column on the right without collapsing
///   the previously-visible Sync sub-menu. Every non-last column is
///   sized to [settingsColumnMinWidth]; the last column expands to
///   fill the remaining viewport. When the stack no longer fits, the
///   row becomes horizontally scrollable with each column pinned at
///   the minimum width.
class SettingsRootPage extends ConsumerWidget {
  const SettingsRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopLayout(context)) {
      return const SettingsPage();
    }

    final tokens = context.designTokens;

    return ColoredBox(
      // Match the DesignSystemHeader + task-list page surface so the
      // settings tab no longer reads as a darker shade than the rest
      // of the app. Previously the settings page surface inherited
      // the scaffold's default canvas, which rendered visibly darker
      // than `tokens.colors.background.level01`.
      color: tokens.colors.background.level01,
      child: ValueListenableBuilder<DesktopSettingsRoute?>(
        valueListenable: getIt<NavService>().desktopSelectedSettingsRoute,
        builder: (context, route, _) {
          final columns = resolveSettingsColumnStack(route);
          final trail = resolveSettingsBreadcrumbTrail(context, route);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsTopBar(trail: trail),
              Expanded(
                child: SettingsColumnStackView(columns: columns),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Settings top bar: settings cog + leaf title + breadcrumb trail.
/// Mirrors the `topbar-breadcrumb` Figma reference — icon is the
/// leading slot, the bold heading is the trail's last label, and the
/// breadcrumb trail (with the leaf marked selected) fills the
/// remaining row space.
class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({required this.trail});

  final List<SettingsBreadcrumbEntry> trail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // `resolveSettingsBreadcrumbTrail` always yields at least the root
    // crumb — the leaf label is the last entry in the trail.
    assert(trail.isNotEmpty, 'Trail always contains the root crumb.');
    final leafLabel = trail.last.label;

    return DesignSystemHeader(
      title: leafLabel,
      leading: Icon(
        Icons.settings_rounded,
        size: 24,
        color: tokens.colors.text.highEmphasis,
      ),
      breadcrumbs: trail.length <= 1
          ? null
          : DesignSystemBreadcrumbs(
              items: [
                for (var i = 0; i < trail.length; i++)
                  DesignSystemBreadcrumbItem(
                    label: trail[i].label,
                    selected: i == trail.length - 1,
                    showChevron: i < trail.length - 1,
                    onPressed: i < trail.length - 1
                        ? () => context.beamToNamed(trail[i].path)
                        : null,
                  ),
              ],
            ),
    );
  }
}

/// Lays out [columns] horizontally: every non-last column is sized to
/// [settingsColumnMinWidth], the last column expands via [Expanded]
/// when the row fits the viewport, and the row becomes a horizontal
/// scroll view with all columns at the minimum width when it doesn't.
/// A freshly-added column auto-scrolls into view on drill-down.
///
/// Exposed so that layout tests can exercise the row/scroll behaviour
/// against stub children without pulling in every real settings page
/// and its Riverpod dependencies.
@visibleForTesting
class SettingsColumnStackView extends StatefulWidget {
  const SettingsColumnStackView({
    required this.columns,
    super.key,
  });

  final List<SettingsColumn> columns;

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

        // Every column — including the last — is pinned at the fixed
        // `settingsColumnMinWidth`. Earlier iterations let the last
        // column `Expanded` to fill remaining viewport space; on a 4K
        // screen that stretched the settings list across the whole
        // display. Keeping them all at the same narrow width feels
        // deliberate regardless of viewport size, and horizontal
        // scrolling absorbs any overflow.
        final children = <Widget>[];
        for (var i = 0; i < columnsCount; i++) {
          if (i > 0) {
            children.add(
              Container(width: dividerWidth, color: dividerColor),
            );
          }
          final column = widget.columns[i];
          // Defer child instantiation to render time — see the
          // `childBuilder` doc on [SettingsColumn] for why. Each
          // column's child is wrapped in a `SettingsColumnScope` so
          // any [SliverBoxAdapterPage] descendant can detect it and
          // suppress its own per-page header — the top bar above the
          // stack already names the leaf.
          final columnChild = SettingsColumnScope(child: column.childBuilder());
          children.add(
            KeyedSubtree(
              key: column.key,
              child: SizedBox(
                width: settingsColumnMinWidth,
                child: columnChild,
              ),
            ),
          );
        }

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );

        // Every column is fixed-width, so the row fits the viewport
        // only when the sum of those widths (plus dividers) is
        // narrower than `constraints.maxWidth`. Either way we wrap in
        // a scroll view — the view is a no-op when the row already
        // fits, and lets the row scroll horizontally when it doesn't.
        final totalDividers = (columnsCount - 1).toDouble();
        final stackWidth =
            columnsCount * settingsColumnMinWidth +
            totalDividers * dividerWidth;
        final fits = stackWidth <= constraints.maxWidth;
        if (fits) {
          // Align the left edge of the row to the viewport's left
          // edge so the row hugs the navigation sidebar on wide
          // viewports instead of centring itself.
          return Align(
            alignment: Alignment.centerLeft,
            child: row,
          );
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
