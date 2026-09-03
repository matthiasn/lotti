import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
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
    collider = WalkCollider(plan.placements.values);
    final mounted = mountedSlotsFor(plan);
    mountedScreens = mounted.screens;
    tickers = [
      ...mounted.tickers,
      for (final (i, hero) in heroes.indexed)
        rooflineTickerFor(plan.placements[hero.task.id]!, fast: i.isEven),
    ];
  }

  final List<PlazaTask> tasks;
  final DateTime now;
  final String projectLabel;
  final StreetLayout layout;

  /// Category names keyed by colour hex, for the side panel.
  final Map<String, String> categoryLabels;

  late final StreetPlan plan;
  late final FrontierPlaza? plaza;
  late final Map<String, TaskAttention> attention;
  late final List<TaskAttention> anomalies;
  late final List<TaskAttention> billboards;
  late final List<Beacon> beacons;
  late final WalkCollider collider;
  late final List<BillboardSlot> mountedScreens;
  late final List<TickerSlot> tickers;

  /// The two most urgent billboard tasks with cover art carry roofline
  /// tickers.
  List<TaskAttention> get heroes => billboards
      .where(
        (a) =>
            a.task.coverImageUrl != null &&
            plan.placements.containsKey(a.task.id),
      )
      .take(2)
      .toList();

  /// The billboard slots in rank order: four pylons, then the mounted
  /// screens.
  List<BillboardSlot> get billboardSlots => [
    ...?plaza?.pylons,
    ...mountedScreens,
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
