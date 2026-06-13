part of 'panel_registry.dart';

// --- Step 8 builders --------------------------------------------------------
//
// Categories / Labels / Dashboards each carry a list ↔ detail/create swap
// driven by URL `pathParameters`. The legacy desktop column-stack used to
// route those URLs to a fresh detail column; under V2 the panel slot itself
// owns the dispatch via [DetailIdDispatch] so the same content area swaps
// in place when a row is tapped (`/settings/<branch>/<id>`) or the create
// CTA is hit (`/settings/<branch>/create`).
Widget _categoriesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'categoryId',
  list: (_) => const CategoriesListBody(),
  create: (_, _) => const CategoryDetailsPage(),
  detail: (_, id) => CategoryDetailsPage(
    key: ValueKey('settings-v2-category-$id'),
    categoryId: id,
  ),
);
Widget _labelsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'labelId',
  list: (_) => const LabelsListBody(),
  create: (_, route) => LabelDetailsPage(
    initialName: route?.queryParameters['name'],
  ),
  detail: (_, id) => LabelDetailsPage(
    key: ValueKey('settings-v2-label-$id'),
    labelId: id,
  ),
);
Widget _habitsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'habitId',
  list: (_) => const HabitsBody(),
  create: (_, _) => CreateHabitPage(),
  detail: (_, id) => EditHabitPage(
    key: ValueKey('settings-v2-habit-$id'),
    habitId: id,
  ),
);
Widget _dashboardsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'dashboardId',
  list: (_) => const DashboardsBody(),
  create: (_, _) => CreateDashboardPage(),
  detail: (_, id) => EditDashboardPage(
    key: ValueKey('settings-v2-dashboard-$id'),
    dashboardId: id,
  ),
);
Widget _measurablesPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'measurableId',
  list: (_) => const MeasurablesBody(),
  create: (_, _) => CreateMeasurablePage(),
  detail: (_, id) => EditMeasurablePage(
    key: ValueKey('settings-v2-measurable-$id'),
    measurableId: id,
  ),
);
// Conflicts follow the list ↔ detail dispatch pattern shared with the
// other dynamic-list panels. Without this, a row tap on desktop would
// only update the URL — the detail pane would keep rendering the list
// because the V2 surface picks its child from the registered panel,
// not from the main Beamer location stack. There's no create flow, so
// the `create` slot just falls through to the list.
Widget _syncConflictsPanel(BuildContext context) => DetailIdDispatch(
  idParamKey: 'conflictId',
  list: (_) => const ConflictsBody(),
  create: (_, _) => const ConflictsBody(),
  detail: (_, id) => ConflictDetailRoute(
    key: ValueKey('settings-v2-conflict-$id'),
    conflictId: id,
  ),
);

/// Generic list ↔ detail/create dispatcher for V2 panel bodies.
///
/// Listens to [NavService.desktopSelectedSettingsRoute] directly via
/// a [ValueListenableBuilder] (no Riverpod adapter — the underlying
/// `ValueNotifier` already emits on every Beamer-driven route change,
/// and stock Flutter rebuild semantics avoid any "did the provider
/// observe the update" doubt). Chooses between three builders:
///
/// - **create** — when the URL ends with `/create`. Receives the full
///   route so create flows can read query parameters
///   (e.g. labels prefilling the new label's name).
/// - **detail** — when [idParamKey] is present in `pathParameters` and
///   not the literal `'create'` (which Beamer hands back as a path
///   parameter on the matching route definition).
/// - **list** — fallback for the bare branch URL.
///
/// The dispatcher is intentionally local to the registry: keeping it
/// here means the categories / labels / dashboards features stay
/// agnostic of V2 routing, and the registry stays the single place
/// to wire a new list-detail pair. The optional [listenable] hook
/// lets tests drive the dispatch with their own ValueNotifier without
/// having to register a `NavService` in `get_it`.
class DetailIdDispatch extends StatelessWidget {
  const DetailIdDispatch({
    required this.idParamKey,
    required this.list,
    required this.create,
    required this.detail,
    this.listenable,
    super.key,
  });

  final String idParamKey;
  final Widget Function(BuildContext context) list;
  final Widget Function(BuildContext context, DesktopSettingsRoute? route)
  create;
  final Widget Function(BuildContext context, String id) detail;

  /// Test-only override for the route source. Production callers leave
  /// this `null` so the dispatcher reads from `getIt<NavService>()`.
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  Widget build(BuildContext context) {
    final source =
        listenable ?? getIt<NavService>().desktopSelectedSettingsRoute;
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: source,
      builder: (context, route, _) {
        final params = route?.pathParameters ?? const <String, String>{};
        final path = route?.path ?? '';

        final Widget child;
        final String modeKey;
        if (path.endsWith('/create')) {
          child = create(context, route);
          modeKey = 'create';
        } else {
          final id = params[idParamKey];
          if (id != null && id.isNotEmpty && id != 'create') {
            child = detail(context, id);
            // Key includes the id so swapping between two detail rows
            // (e.g. tapping a different category) cross-fades instead
            // of reusing the previous detail's element.
            modeKey = 'detail:$id';
          } else {
            child = list(context);
            modeKey = 'list';
          }
        }

        return AnimatedSwitcher(
          duration: kSettingsPanelSwapDuration,
          // Default layout uses `StackFit.loose`, which collapses
          // Scaffold-based children to their minimum size and hides
          // their FloatingActionButton — the "+" in the agents tab is
          // the canonical case, but this is a property of every
          // dispatcher consumer (categories, labels, dashboards,
          // measurables, agents). Force `StackFit.expand` so children
          // fill the panel slot — Scaffolds get bounded constraints
          // and lay out their FAB the same way they would unwrapped.
          // The previous children list still cross-fades correctly
          // because `AnimatedSwitcher` paints them above us during
          // the swap.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(key: ValueKey(modeKey), child: child),
        );
      },
    );
  }
}
