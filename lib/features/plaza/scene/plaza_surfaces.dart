import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/banner_widget.dart';
import 'package:lotti/features/plaza/ui/billboard_widget.dart';
import 'package:lotti/features/plaza/ui/block_marker_widget.dart';
import 'package:lotti/features/plaza/ui/jumbotron_widget.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/features/plaza/ui/ticker_widget.dart';
import 'package:vector_math/vector_math.dart' show Matrix4, Vector3;

/// The plaza's mid-tier widget surfaces that are not facades: billboards,
/// ticker bands and the week markers on the road.
///
/// Budget (spec): billboards ≤ 6, captured on an interval that tightens
/// near the plaza so the glow breathes; tickers captured at 20 Hz within
/// range and at a crawl beyond it; block markers captured once at build.
class PlazaSurfaces {
  PlazaSurfaces({
    required this.scene,
    required this.world,
    required this.markerAnchors,
    required this.billboards,
    required this.pxPerMeter,
    Map<String, Node> bannerAnchors = const {},
    Node? jumbotronAnchor,
    Map<int, Node> weekSignAnchors = const {},
    List<(Node, double, double, int)> skylineScreens = const [],
    List<(Node, double, double, String)> fillerSigns = const [],
  }) {
    _attachMarkers();
    _attachWeekSigns(weekSignAnchors);
    _attachSkylineScreens(skylineScreens);
    _attachFillerSigns(fillerSigns);
    _attachBillboards();
    _attachTickers();
    _attachBanners(bannerAnchors);
    _attachJumbotron(jumbotronAnchor);
  }

  final Scene scene;
  final PlazaWorld world;
  final Map<int, Node> markerAnchors;
  final List<PlazaBillboard> billboards;
  final double pxPerMeter;

  final List<WidgetComponent> _markers = [];
  final List<WidgetComponent> _banners = [];
  WidgetComponent? _jumbotron;
  final List<(Vector3, WidgetComponent, Node)> _billboardSurfaces = [];
  final List<(Vector3, WidgetComponent, Node)> _tickerSurfaces = [];

  /// Beyond this distance the plaza's animated surfaces are hidden: far
  /// enough that the map shot still sees the pylons lit.
  static const plazaRangeFloor = 180.0;
  late final double plazaRange = _plazaRangeFor(world);

  static double _plazaRangeFor(PlazaWorld world) {
    final plaza = world.plaza;
    if (plaza == null) return plazaRangeFloor;
    final dx = plaza.overview.x - plaza.centerX;
    final dz = plaza.overview.z - plaza.centerZ;
    final ground = math.sqrt(dx * dx + dz * dz);
    final reach = math.sqrt(
      ground * ground + plaza.overview.y * plaza.overview.y,
    );
    return math.max(plazaRangeFloor, reach + 60);
  }

  static const nearInterval = Duration(milliseconds: 100);
  static const tickerInterval = Duration(milliseconds: 50);
  static const farInterval = Duration(seconds: 3);

  static const markerWidth = 20.0;
  static const markerHeight = 6.5;
  static const jumbotronInterval = Duration(seconds: 1);

  static const signWidth = 5.0;
  static const signHeight = 1.4;

  void _attachWeekSigns(Map<int, Node> anchors) {
    for (final entry in anchors.entries) {
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: BlockMarkerWidget(
          label: world.weekLabel(entry.key),
          heightMeters: signHeight,
          pxPerMeter: pxPerMeter,
        ),
        size: Size(signWidth * pxPerMeter, signHeight * pxPerMeter),
        geometry: ccwQuad(signWidth, signHeight),
        update: WidgetUpdatePolicy.manual,
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      entry.value.addComponent(component);
      _markers.add(component);
    }
  }

  /// Big screens on the skyline: the anomalies again, at a slow capture
  /// rate — they are far, and repetition is the Times Square idiom.
  void _attachSkylineScreens(List<(Node, double, double, int)> screens) {
    for (final (anchor, w, h, rank) in screens) {
      if (rank >= world.anomalies.length) continue;
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: BillboardWidget(
          attention: world.anomalies[rank],
          widthMeters: w,
          heightMeters: h,
          pxPerMeter: pxPerMeter * 0.35,
          pulseSeconds: 4,
        ),
        size: Size(w * pxPerMeter * 0.35, h * pxPerMeter * 0.35),
        geometry: ccwQuad(w, h),
        update: const WidgetUpdatePolicy.interval(farInterval),
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      anchor.addComponent(component);
      _banners.add(component);
    }
  }

  /// Neon category signs on the filler blocks, captured once.
  void _attachFillerSigns(List<(Node, double, double, String)> signs) {
    final byId = {for (final t in world.tasks) t.id: t};
    for (final (anchor, w, h, taskId) in signs) {
      final task = byId[taskId];
      if (task == null) continue;
      final label = world.categoryLabels.isEmpty
          ? 'open late'
          : world.categoryLabelOf(task);
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: BannerWidget(
          label: label,
          color: PlazaStyle.neon(PlazaStyle.categoryBright(task)),
          widthMeters: w,
          heightMeters: h,
          pxPerMeter: pxPerMeter * 0.6,
        ),
        size: Size(w * pxPerMeter * 0.6, h * pxPerMeter * 0.6),
        geometry: ccwQuad(w, h),
        update: WidgetUpdatePolicy.manual,
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      anchor.addComponent(component);
      _banners.add(component);
    }
  }

  void _attachBanners(Map<String, Node> anchors) {
    final byId = {for (final t in world.tasks) t.id: t};
    for (final banner in world.banners) {
      final anchor = anchors[banner.taskId];
      final task = byId[banner.taskId];
      if (anchor == null || task == null) continue;
      final label = world.categoryLabels.isEmpty
          ? PlazaStyle.chip(world.attentionOf(task)).label
          : world.categoryLabelOf(task);
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: BannerWidget(
          label: label,
          color: PlazaStyle.neon(PlazaStyle.categoryBright(task)),
          widthMeters: banner.width,
          heightMeters: banner.height,
          pxPerMeter: pxPerMeter,
        ),
        size: Size(banner.width * pxPerMeter, banner.height * pxPerMeter),
        geometry: ccwQuad(banner.width, banner.height),
        update: WidgetUpdatePolicy.manual,
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      anchor.addComponent(component);
      _banners.add(component);
    }
  }

  void _attachJumbotron(Node? anchor) {
    final slot = world.jumbotron;
    if (anchor == null || slot == null) return;
    final surface = OpaqueSurface();
    final component = WidgetComponent(
      child: JumbotronWidget(
        projectLabel: world.projectLabel,
        taskCount: world.liveTaskCount,
        attentionCount: world.anomalies.length,
        headlines: world.anomalies,
        covers: [
          for (final a in world.billboards)
            if (a.task.coverImageUrl != null) a.task.coverImageUrl!,
        ],
        widthMeters: slot.width,
        pxPerMeter: pxPerMeter * 0.5,
      ),
      size: Size(slot.width * pxPerMeter * 0.5, slot.height * pxPerMeter * 0.5),
      geometry: ccwQuad(slot.width, slot.height),
      update: const WidgetUpdatePolicy.interval(jumbotronInterval),
      input: WidgetInput.manual,
      material: surface.material,
      bind: surface.bind,
    );
    anchor.addComponent(component);
    _jumbotron = component;
  }

  void _attachMarkers() {
    for (final entry in markerAnchors.entries) {
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: BlockMarkerWidget(
          label: world.weekLabel(entry.key),
          heightMeters: markerHeight,
          pxPerMeter: pxPerMeter,
        ),
        size: Size(markerWidth * pxPerMeter, markerHeight * pxPerMeter),
        geometry: ccwQuad(markerWidth, markerHeight),
        update: WidgetUpdatePolicy.manual,
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      entry.value.addComponent(component);
      _markers.add(component);
    }
  }

  void _attachBillboards() {
    for (final billboard in billboards) {
      final slot = billboard.slot;
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: BillboardWidget(
          attention: billboard.attention,
          widthMeters: slot.width,
          heightMeters: slot.height,
          pxPerMeter: pxPerMeter,
          pulseSeconds: slot.pulseSeconds,
        ),
        size: Size(slot.width * pxPerMeter, slot.height * pxPerMeter),
        geometry: ccwQuad(slot.width, slot.height),
        update: const WidgetUpdatePolicy.interval(nearInterval),
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      billboard.anchor.addComponent(component);
      _billboardSurfaces.add((billboard.center, component, billboard.anchor));
    }
  }

  void _attachTickers() {
    for (final slot in world.tickers) {
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(slot.x, slot.bottom + slot.height / 2, slot.z),
        )..rotateY(slot.facingRadians),
      );
      final isGantry = identical(slot, world.gantry);
      final surface = OpaqueSurface();
      final component = WidgetComponent(
        child: TickerWidget(
          text: isGantry ? world.countsText : world.tickerText,
          heightMeters: slot.height,
          pxPerMeter: pxPerMeter,
          speedMetersPerSecond: slot.speedMetersPerSecond,
        ),
        size: Size(slot.width * pxPerMeter, slot.height * pxPerMeter),
        geometry: ccwQuad(slot.width, slot.height),
        update: const WidgetUpdatePolicy.interval(tickerInterval),
        input: WidgetInput.manual,
        material: surface.material,
        bind: surface.bind,
      );
      anchor.addComponent(component);
      scene.add(anchor);
      _tickerSurfaces.add((
        Vector3(slot.x, slot.bottom, slot.z),
        component,
        anchor,
      ));
    }
  }

  /// Keeps asking for the one-off marker captures until they land, and
  /// hides the plaza's animated surfaces when they are out of range (a
  /// hidden surface is not captured).
  void update(Vector3 eye) {
    for (final once in [..._markers, ..._banners]) {
      final controller = once.controller;
      if (controller.texture == null) controller.requestCapture();
    }
    for (final (center, _, node) in _billboardSurfaces) {
      node.visible = (center - eye).length <= plazaRange;
    }
    for (final (origin, _, node) in _tickerSurfaces) {
      node.visible = (origin - eye).length <= plazaRange;
    }
  }

  /// Total captures across these surfaces, for the debug overlay.
  int get captures {
    var n = 0;
    for (final m in _markers) {
      n += m.controller.captureCount;
    }
    for (final (_, c, _) in _billboardSurfaces) {
      n += c.controller.captureCount;
    }
    for (final (_, c, _) in _tickerSurfaces) {
      n += c.controller.captureCount;
    }
    for (final b in _banners) {
      n += b.controller.captureCount;
    }
    return n + (_jumbotron?.controller.captureCount ?? 0);
  }

  /// The pose in front of a billboard, for the tour and for taps on it.
  static CameraPose facingPose(BillboardSlot slot, {double distance = 14}) =>
      CameraPose(
        x: slot.x + math.sin(slot.facingRadians) * distance,
        y: eyeHeight,
        z: slot.z + math.cos(slot.facingRadians) * distance,
        yaw: slot.facingRadians + math.pi,
        pitch: math.atan2(slot.centerY - eyeHeight, distance),
      );
}
