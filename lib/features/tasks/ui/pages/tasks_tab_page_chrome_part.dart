part of 'tasks_tab_page.dart';

/// End-aligned floating location that sits [bottomMargin] above the content
/// edge instead of the framework's fixed [kFloatingActionButtonMargin].
///
/// Never closer to the edge than the system's own bottom inset allows — a
/// tighter margin is a visual alignment, not a licence to sit under the home
/// indicator.
@immutable
/// Floats the tasks page's FAB level with its action bar: the standard
/// end-float position lifted by the bar's bottom margin, never below the
/// content's bottom edge.
class _ActionBarAlignedFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  const _ActionBarAlignedFabLocation({required this.bottomMargin});

  final double bottomMargin;

  // Value equality, not identity: `build` constructs a fresh instance every
  // time, and `Scaffold.didUpdateWidget` reads a changed location as a move —
  // restarting the FAB transition (and its setState) on every rebuild of a
  // page that rebuilds on every journal query result.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ActionBarAlignedFabLocation &&
          other.bottomMargin == bottomMargin;

  @override
  int get hashCode => bottomMargin.hashCode;

  @override
  double getOffsetY(
    ScaffoldPrelayoutGeometry scaffoldGeometry,
    double adjustment,
  ) {
    final standard = super.getOffsetY(scaffoldGeometry, adjustment);
    final lowest =
        scaffoldGeometry.contentBottom -
        scaffoldGeometry.floatingActionButtonSize.height -
        scaffoldGeometry.minViewPadding.bottom;
    return math.min(
      standard + (kFloatingActionButtonMargin - bottomMargin),
      lowest,
    );
  }
}

/// Compact list-density toggle riding the trailing end of the tasks list's
/// first section-header line ("P2 Medium · 5 tasks"), so switching between
/// full cards and title-only rows costs the header no row of its own.
///
/// The glyph stays at the dense [IconSizes.m] tier, but the hit area keeps
/// the full [TapTargets.minimum] floor — a glyph-only control has no label
/// to borrow interaction area from. The section header compensates by
/// tightening its own vertical padding while it hosts a trailing control
/// (see `TaskBrowseListItem.sectionHeaderTrailing`), so the line's overall
/// height barely moves.
class _TaskListDensityToggle extends ConsumerWidget {
  const _TaskListDensityToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final compact = ref.watch(taskListDensityControllerProvider);
    return IconButton(
      key: const Key('tasks_list_density_toggle'),
      tooltip: compact
          ? context.messages.tasksListExpandedModeTooltip
          : context.messages.tasksListCompactModeTooltip,
      onPressed: ref.read(taskListDensityControllerProvider.notifier).toggle,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: TapTargets.minimum,
        minHeight: TapTargets.minimum,
      ),
      style: compact
          ? IconButton.styleFrom(
              backgroundColor: DesignSystemListPalette.activatedFill(tokens),
            )
          : null,
      icon: Icon(
        LottiIcons.viewRows,
        size: IconSizes.m,
        color: compact
            ? tokens.colors.interactive.enabled
            : tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
