import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/scenery.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
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
    mountedScreens = mounted.screens;
    tickers = [
      ...mounted.tickers,
      ?gantry,
      for (final (i, hero) in heroes.indexed)
        rooflineTickerFor(plan.placements[hero.task.id]!, fast: i.isEven),
    ];
    // A band on a building speaks for that building; the gantry counts
    // the district; the hero rooflines carry the headlines.
    final mountTasks = plazaMounts(plan);
    tickerTexts = {
      for (final (i, slot) in mounted.tickers.indexed)
        slot: _ownTickerText(mountTasks[i].taskId),
      ?gantry: countsText,
      for (final hero in heroes)
        tickers[tickers.length - heroes.length + heroes.indexOf(hero)]:
            tickerText,
    };
    scenery = sceneryFor(
      plan,
      plaza: plaza,
      jumbotron: jumbotron,
      roadWidth: layout.roadWidth,
      plotDepth: layout.plotDepth,
    );
    solids = List.unmodifiable([
      for (final p in plan.placements.values) p.footprint,
      for (final box in scenery.boxes) box.footprint,
      ...pylonFootprintsFor(builtBillboardSlots.where((s) => s.onPylon)),
      if (gantry case final gantry?) ...gantryLegFootprintsFor(gantry),
      ...lampPostFootprintsFor(lampPosts),
    ]);
    collider = WalkCollider(solids);
  }

  final List<PlazaTask> tasks;
  final DateTime now;
  final String projectLabel;
  final StreetLayout layout;

  /// Category names keyed by colour hex, for the side panel.
  final Map<String, String> categoryLabels;

  /// What each ticker band scrolls.
  late final Map<TickerSlot, String> tickerTexts;

  /// A building's own band: its state word with the glyph, then the
  /// reason or the due date — short, so a narrow band never cuts a word
  /// nobody can finish.
  String _ownTickerText(String taskId) {
    final a = attention[taskId];
    if (a == null) return countsText;
    final parts = <String>[
      '${_glyph(a.lantern)} ${_stateWord(a.lantern)}',
      if (a.reason.isNotEmpty)
        a.reason
      else if (a.task.due != null)
        'due ${shortDate(a.task.due!)}',
    ];
    return parts.join('   ·   ');
  }

  static String _glyph(LanternState state) => switch (state) {
    LanternState.blocked => '✕',
    LanternState.overdue => '!',
    LanternState.inProgress => '▶',
    LanternState.open => '○',
    LanternState.off => '✓',
  };

  static String _stateWord(LanternState state) => switch (state) {
    LanternState.blocked => 'blocked',
    LanternState.overdue => 'overdue',
    LanternState.inProgress => 'in progress',
    LanternState.open => 'open',
    LanternState.off => 'done',
  };

  late final StreetPlan plan;
  late final FrontierPlaza? plaza;
  late final Map<String, TaskAttention> attention;
  late final List<TaskAttention> anomalies;
  late final List<TaskAttention> billboards;
  late final List<Beacon> beacons;

  /// The seeded dressing: fillers, hero towers, the jumbotron tower, the
  /// skyline ring.
  late final Scenery scenery;

  /// Every rectangle on the ground the walker is kept out of: the plots,
  /// the scenery boxes, the built pylons' footings, the gantry legs and
  /// the lamp posts — all of it, so the scene has nothing solid the
  /// collider does not know.
  late final List<Footprint> solids;

  late final WalkCollider collider;
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
  late final List<TickerSlot> tickers;

  /// Attention verdict for each roof billboard, in slot order.
  List<TaskAttention> get roofBillboardTasks => [
    for (final slot in roofBillboards) anomalies[slot.rank],
  ];

  /// The two tallest buildings that carry no roof billboard take the
  /// roofline tickers, so a ticker never covers a billboard.
  List<TaskAttention> get heroes {
    final roofed = {for (final s in roofBillboards) anomalies[s.rank].task.id};
    final candidates =
        plan.placements.values
            .where(
              (p) =>
                  !roofed.contains(p.taskId) && attention.containsKey(p.taskId),
            )
            .toList()
          ..sort((a, b) {
            final byHeight = b.height.compareTo(a.height);
            return byHeight != 0 ? byHeight : a.taskId.compareTo(b.taskId);
          });
    return [for (final p in candidates.take(2)) attention[p.taskId]!];
  }

  /// The billboard slots in rank order: four pylons, then the mounted
  /// screens.
  List<BillboardSlot> get billboardSlots => [
    ...?plaza?.pylons,
    ...mountedScreens,
  ];

  /// The slots that get a billboard: one per candidate, in rank order.
  /// The rest stay empty and are not built.
  List<BillboardSlot> get builtBillboardSlots =>
      billboardSlots.take(billboards.length).toList();

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

  /// The gantry's line: the project's numbers, no headlines (those are on
  /// the pylons and the mounted screens already).
  String get countsText {
    final inProgress = tasks
        .where((t) => t.state == PlazaTaskState.inProgress)
        .length;
    final done = tasks.where((t) => t.state == PlazaTaskState.done).length;
    return [
      projectLabel,
      '${anomalies.length} need attention',
      '$inProgress in progress',
      '$done of $liveTaskCount done',
      'W$builtWeeks',
    ].join('   ·   ');
  }

  /// The scrolling headline: project, attention count, the top three
  /// reasons, progress counts.
  String get tickerText {
    final inProgress = tasks
        .where((t) => t.state == PlazaTaskState.inProgress)
        .length;
    final done = tasks.where((t) => t.state == PlazaTaskState.done).length;
    return [
      projectLabel,
      '${anomalies.length} need attention',
      for (final a in anomalies.take(3)) '${a.task.title} — ${a.reason}',
      '$inProgress in progress',
      '$done of $liveTaskCount done',
    ].join('   ·   ');
  }

  /// The morning walk's stops, or null for a street with no plaza.
  List<WalkStop>? get walkStops {
    final p = plaza;
    if (p == null) return null;
    return morningWalkStops(plan, p, anomalies, projectLabel: projectLabel);
  }
}

/// [anomalies] under a name that does not shadow the field.
List<TaskAttention> anomalyList(List<TaskAttention> all) => anomalies(all);
