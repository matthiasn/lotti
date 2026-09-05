import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/scenery.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/domain/street_network.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';

/// Everything the scene and the HUD need about one project, derived once
/// from the task list and the clock: the street plan, the plaza, the
/// attention verdicts, the beacons, the billboards. Pure Dart, so it can
/// be built and tested without a GPU.
class PlazaWorld {
  PlazaWorld({
    required this.tasks,
    required this.now,
    required this.projectLabel,
    required this.layout,
    this.categoryLabels = const {},
  }) {
    plan = layout.plan(tasks);
    plaza = frontierPlazaFor(plan);
    final verdicts = attentionForAll(tasks, now);
    attention = {for (final a in verdicts) a.task.id: a};
    anomalies = anomalyList(verdicts);
    billboards = billboardCandidates(verdicts);
    beacons = beaconsFor(
      plan,
      plaza,
      anomalies,
      projectLabel: projectLabel,
      weekLabel: weekLabel,
    );
    roofBillboards = roofBillboardsFor(plan, anomalies);
    banners = bannersFor(plan);
    lampPosts = lampPostsFor(plan, roadWidth: layout.roadWidth);
    gantry = gantryTickerFor(plan, roadWidth: layout.roadWidth);
    jumbotron = jumbotronSlotFor(plan);
    spires = spiresFor(plan);
    weekSigns = weekSignsFor(plan, roadWidth: layout.roadWidth);
    final mounted = mountedSlotsFor(plan);
    mountedScreens = [for (final panel in mounted) panel.screen];
    // A band on a building speaks for that building; the gantry counts
    // the district; the hero rooflines carry the headlines.
    tickerTexts = Map.unmodifiable({
      for (final panel in mounted) panel.ticker: _ownTickerText(panel.taskId),
      ?gantry: countsText,
      for (final (i, hero) in heroes.indexed)
        rooflineTickerFor(plan.placements[hero.task.id]!, fast: i.isEven):
            tickerText,
    });
    tickers = List.unmodifiable(tickerTexts.keys);
    scenery = sceneryFor(
      plan,
      plaza: plaza,
      jumbotron: jumbotron,
      roadWidth: layout.roadWidth,
      plotDepth: layout.plotDepth,
    );
    solids = List.unmodifiable([
      for (final p in plan.placements.values) plotSolidFor(p),
      for (final p in spires) plotSpireSolidFor(p),
      ...scenery.solids,
      ...pylonSolidsFor(
        builtBillboards.map((b) => b.slot).where((s) => s.onPylon),
      ),
      for (final panel in roofBillboards) signSolidFor(panel),
      if (gantry case final gantry?) ...gantrySolidsFor(gantry),
      ...lampPostSolidsFor(lampPosts),
    ]);
    collider = WalkCollider([
      for (final solid in solids)
        if (solid.atWalkHeight) solid.footprint,
    ]);
    network = StreetNetwork.of(plan, plaza);
  }

  final List<PlazaTask> tasks;
  final DateTime now;
  final String projectLabel;
  final StreetLayout layout;

  /// Category names keyed by colour hex, for the side panel.
  final Map<String, String> categoryLabels;

  /// What each ticker band scrolls, in band order: the mounted bands, the
  /// gantry, the hero rooflines.
  late final Map<TickerSlot, String> tickerTexts;

  /// The bands, in the order of [tickerTexts].
  late final List<TickerSlot> tickers;

  /// What separates the items on a band.
  static const _separator = '   ·   ';

  /// A building's own band: its state word with the glyph, then the
  /// reason or the due date — short, so a narrow band never cuts a word
  /// nobody can finish.
  String _ownTickerText(String taskId) {
    final a = attention[taskId];
    if (a == null) return countsText;
    final parts = <String>[
      '${a.lantern.glyph} ${a.lantern.word}',
      if (a.reason.isNotEmpty)
        a.reason
      else if (a.task.due != null)
        'due ${shortDate(a.task.due!)}',
    ];
    return parts.join(_separator);
  }

  late final StreetPlan plan;
  late final FrontierPlaza? plaza;
  late final Map<String, TaskAttention> attention;
  late final List<TaskAttention> anomalies;
  late final List<TaskAttention> billboards;
  late final List<Beacon> beacons;

  /// The seeded dressing: fillers, hero towers, the jumbotron tower, the
  /// skyline ring.
  late final Scenery scenery;

  /// Every solid the scene builds, with its height: the plots with their
  /// roof kit, the spires, the scenery boxes, the built pylons' posts and
  /// signs, the roof panels, the gantry's legs and beam, the lamp posts —
  /// all of it, so the scene has nothing solid the collider and the flight
  /// planner do not know.
  late final List<Solid> solids;

  /// Keeps the walker out of every solid that reaches down to eye level.
  late final WalkCollider collider;

  /// The way a flight follows between two stops on the ground: the street,
  /// the plaza's mouth and its axis to home. Null without a street.
  late final StreetNetwork? network;
  late final List<BillboardSlot> mountedScreens;

  /// Panels above the anomalous buildings themselves, most urgent first.
  late final List<BillboardSlot> roofBillboards;

  /// Vertical neon banners on the tall buildings' end walls.
  late final List<BannerSlot> banners;

  /// Lamp post positions along the kerbs.
  late final List<(double, double)> lampPosts;

  /// The ticker gantry over the street mouth.
  late final TickerSlot? gantry;

  /// The giant screen behind the plaza.
  late final BillboardSlot? jumbotron;

  /// The two tallest buildings, which carry spires.
  late final List<PlotPlacement> spires;

  /// Eye-level week signs at each block head: (bucket, x, z, facing).
  late final List<(int, double, double, double)> weekSigns;

  /// Slots and attention travel together through the scene layers.
  late final List<BillboardAssignment> roofPanels = [
    for (final slot in roofBillboards)
      (slot: slot, attention: anomalies[slot.rank]),
  ];

  /// The two tallest buildings that carry no roof billboard take the
  /// roofline tickers, so a ticker never covers a billboard.
  late final List<TaskAttention> heroes = _heroes();

  List<TaskAttention> _heroes() {
    final roofed = {for (final s in roofBillboards) anomalies[s.rank].task.id};
    final candidates =
        plan.placements.values
            .where(
              (p) =>
                  !roofed.contains(p.taskId) && attention.containsKey(p.taskId),
            )
            .toList()
          ..sort(tallestFirst);
    return List.unmodifiable([
      for (final p in candidates.take(2)) attention[p.taskId]!,
    ]);
  }

  /// The billboard slots in rank order: four pylons, then the mounted
  /// screens.
  List<BillboardSlot> get billboardSlots => [
    ...?plaza?.pylons,
    ...mountedScreens,
  ];

  /// Only populated slots, with their assigned task; unused mounts stay empty.
  late final List<BillboardAssignment> builtBillboards = [
    for (final (i, slot) in billboardSlots.take(billboards.length).indexed)
      (slot: slot, attention: billboards[i]),
  ];

  TaskAttention attentionOf(PlazaTask task) => attention[task.id]!;

  /// `W3 · Jun 22`
  String weekLabel(int bucketIndex) => weekLabelFor(plan.epoch, bucketIndex);

  /// `W3` for the week the task was created in.
  String weekOf(PlazaTask task) {
    final placement = plan.placements[task.id];
    return placement == null ? '' : 'W${placement.bucketIndex + 1}';
  }

  String categoryLabelOf(PlazaTask task) =>
      categoryLabels[task.categoryColor.toRadixString(16)] ?? 'task';

  int get builtWeeks => plan.segments.where((s) => !s.isGap).length;

  int get liveTaskCount => tasks.where((t) => !t.deleted).length;

  /// The project and its attention count: how every district band opens.
  List<String> get _opening => [
    projectLabel,
    '${anomalies.length} need attention',
  ];

  /// The progress counts every district band carries.
  List<String> get _progress {
    final inProgress = tasks
        .where((t) => t.state == PlazaTaskState.inProgress)
        .length;
    final done = tasks.where((t) => t.state == PlazaTaskState.done).length;
    return ['$inProgress in progress', '$done of $liveTaskCount done'];
  }

  /// The gantry's line: the project's numbers, no headlines (those are on
  /// the pylons and the mounted screens already).
  String get countsText =>
      [..._opening, ..._progress, 'W$builtWeeks'].join(_separator);

  /// The scrolling headline: project, attention count, the top three
  /// reasons, progress counts.
  String get tickerText => [
    ..._opening,
    for (final a in anomalies.take(3)) '${a.task.title} — ${a.reason}',
    ..._progress,
  ].join(_separator);

  /// The morning walk's stops, or null for a street with no plaza.
  List<WalkStop>? get walkStops {
    final p = plaza;
    if (p == null) return null;
    return morningWalkStops(plan, p, anomalies, projectLabel: projectLabel);
  }
}

/// [anomalies] under a name that does not shadow the field.
List<TaskAttention> anomalyList(List<TaskAttention> all) => anomalies(all);

/// A physical panel paired with the attention verdict it presents.
typedef BillboardAssignment = ({BillboardSlot slot, TaskAttention attention});
