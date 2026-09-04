import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/surface_captures.dart';
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
/// Budget (spec): billboards ≤ 6, still faces captured once (and again
/// when a cover lands), their bloom breathing in the scene; tickers at
/// [tickerInterval] within the plaza's range and not at all beyond it; the
/// jumbotron at [jumbotronInterval]; the skyline screens, block markers,
/// banners and signs captured once at build.
///
/// Every capture is manual, requested from [update] on the harness clock
/// through [SurfaceCaptures]: an interval policy would make flutter_scene
/// pump an engine frame on every vsync, whatever the harness paints. Each
/// cadence owns the clock its widgets read ([tickerClock],
/// [jumbotronClock]), advanced only when that cadence asks for
/// a capture, so between captures nothing in them runs.
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
    _attachLabels(markerAnchors, markerWidth, markerHeight);
    _attachLabels(weekSignAnchors, signWidth, signHeight);
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

  final SurfaceCaptures _captures = SurfaceCaptures();
  final CaptureCadence _tickers = CaptureCadence(tickerInterval);
  final CaptureCadence _jumbotron = CaptureCadence(jumbotronInterval);

  /// Elapsed harness seconds as of the tickers' last capture request: the
  /// clock the bands scroll by.
  ValueListenable<double> get tickerClock => _tickers.clock;

  /// Elapsed harness seconds as of the jumbotron's last capture request:
  /// the clock it turns its slides by.
  ValueListenable<double> get jumbotronClock => _jumbotron.clock;

  /// The plaza's animated surfaces, hidden beyond [plazaRange]: where each
  /// stands and the node that hides it.
  final List<(Vector3, Node)> _ranged = [];

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

  static const tickerInterval = 0.05;

  static const markerWidth = 16.0;
  static const markerHeight = 5.2;
  static const jumbotronInterval = 1.0;

  static const signWidth = 5.0;
  static const signHeight = 1.4;

  /// Hangs a capture-once [component] on [anchor].
  void _once(Node anchor, WidgetComponent component) {
    anchor.addComponent(component);
    _captures.once(component.controller);
  }

  /// Week labels on the road ([markerWidth] × [markerHeight]) and the week
  /// signs ([signWidth] × [signHeight]): a [BlockMarkerWidget] per bucket.
  void _attachLabels(Map<int, Node> anchors, double width, double height) {
    for (final MapEntry(key: bucket, value: anchor) in anchors.entries) {
      _once(
        anchor,
        hostedSurface(
          child: BlockMarkerWidget(
            label: world.weekLabel(bucket),
            heightMeters: height,
            pxPerMeter: pxPerMeter,
          ),
          width: width,
          height: height,
          pxPerMeter: pxPerMeter,
        ),
      );
    }
  }

  /// Big screens on the skyline: the anomalies again, captured once —
  /// they are far, and repetition is the Times Square idiom.
  void _attachSkylineScreens(List<(Node, double, double, int)> screens) {
    for (final (anchor, w, h, rank) in screens) {
      if (rank >= world.anomalies.length) continue;
      late final WidgetComponent component;
      component = hostedSurface(
        child: BillboardWidget(
          attention: world.anomalies[rank],
          widthMeters: w,
          heightMeters: h,
          pxPerMeter: pxPerMeter * 0.35,
          onCoverChanged: () => _captures.invalidate(component.controller),
        ),
        width: w,
        height: h,
        pxPerMeter: pxPerMeter,
        scale: 0.35,
      );
      anchor.addComponent(component);
      _captures.once(component.controller);
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
      _once(
        anchor,
        hostedSurface(
          child: BannerWidget(
            label: label,
            color: PlazaStyle.neon(PlazaStyle.categoryBright(task)),
            widthMeters: w,
            heightMeters: h,
            pxPerMeter: pxPerMeter * 0.6,
          ),
          width: w,
          height: h,
          pxPerMeter: pxPerMeter,
          scale: 0.6,
        ),
      );
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
      _once(
        anchor,
        hostedSurface(
          child: BannerWidget(
            label: label,
            color: PlazaStyle.neon(PlazaStyle.categoryBright(task)),
            widthMeters: banner.width,
            heightMeters: banner.height,
            pxPerMeter: pxPerMeter,
          ),
          width: banner.width,
          height: banner.height,
          pxPerMeter: pxPerMeter,
        ),
      );
    }
  }

  /// While true the jumbotron holds its project card: the tour's
  /// jumbotron stop sets it so the masthead is what the capture shows.
  final pinJumbotron = ValueNotifier<bool>(false);

  void _attachJumbotron(Node? anchor) {
    final slot = world.jumbotron;
    if (anchor == null || slot == null) return;
    final component = hostedSurface(
      child: JumbotronWidget(
        projectLabel: world.projectLabel,
        taskCount: world.liveTaskCount,
        attentionCount: world.anomalies.length,
        headlines: world.anomalies,
        pinProjectCard: pinJumbotron,
        covers: [
          for (final a in world.billboards)
            if (a.task.coverImageUrl != null) a.task.coverImageUrl!,
        ],
        widthMeters: slot.width,
        pxPerMeter: pxPerMeter * 0.5,
        clock: _jumbotron.clock,
      ),
      width: slot.width,
      height: slot.height,
      pxPerMeter: pxPerMeter,
      scale: 0.5,
    );
    anchor.addComponent(component);
    _captures.timed(
      _jumbotron,
      TimedSurface.facing(
        controller: component.controller,
        node: anchor,
        center: Vector3(slot.x, slot.centerY, slot.z),
        facingRadians: slot.facingRadians,
      ),
    );
  }

  void _attachBillboards() {
    for (final billboard in billboards) {
      final slot = billboard.slot;
      late final WidgetComponent component;
      component = hostedSurface(
        child: BillboardWidget(
          attention: billboard.attention,
          widthMeters: slot.width,
          heightMeters: slot.height,
          pxPerMeter: pxPerMeter,
          // A roof panel sits over its own facade, which carries the
          // title: the panel leads with the reason instead.
          reasonFirst: slot.mount == BillboardMount.roof,
          onCoverChanged: () => _captures.invalidate(component.controller),
        ),
        width: slot.width,
        height: slot.height,
        pxPerMeter: pxPerMeter,
      );
      billboard.anchor.addComponent(component);
      _ranged.add((billboard.center, billboard.anchor));
      // A still face: captured once, and once more when its cover lands.
      // The breathing is the glow quad's, in [update].
      _captures.once(component.controller);
    }
  }

  void _attachTickers() {
    for (final slot in world.tickers) {
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(slot.x, slot.bottom + slot.height / 2, slot.z),
        )..rotateY(slot.facingRadians),
      );
      final component = hostedSurface(
        child: TickerWidget(
          text: world.tickerTexts[slot] ?? world.tickerText,
          heightMeters: slot.height,
          pxPerMeter: pxPerMeter,
          speedMetersPerSecond: slot.speedMetersPerSecond,
          clock: _tickers.clock,
        ),
        width: slot.width,
        height: slot.height,
        pxPerMeter: pxPerMeter,
      );
      anchor.addComponent(component);
      // Housing: a dark track behind the band with a thin teal rim and
      // end caps, so the ticker is a fixture on the wall and not a strip
      // of type floating in front of it.
      final rim = UnlitMaterial()
        ..baseColorFactor = linearColor(PlazaStyle.teal, alpha: 0.8);
      final track = UnlitMaterial()
        ..baseColorFactor = linearColor(const Color(0xFF0B0D14));
      anchor.add(
        Node(
          localTransform: Matrix4.translation(Vector3(0, 0, -0.22)),
          mesh: Mesh(
            CuboidGeometry(Vector3(slot.width + 0.6, slot.height + 0.5, 0.4)),
            track,
          ),
        ),
      );
      const cap = 0.1;
      for (final (dx, dy, sw, sh) in [
        (0.0, slot.height / 2 + 0.2, slot.width + 0.6, cap),
        (0.0, -slot.height / 2 - 0.2, slot.width + 0.6, cap),
        (-slot.width / 2 - 0.25, 0.0, cap * 2, slot.height + 0.5),
        (slot.width / 2 + 0.25, 0.0, cap * 2, slot.height + 0.5),
      ]) {
        anchor.add(
          Node(
            localTransform: Matrix4.translation(Vector3(dx, dy, -0.02)),
            mesh: Mesh(CuboidGeometry(Vector3(sw, sh, 0.1)), rim),
          ),
        );
      }
      scene.add(anchor);
      // The band's centre, where the anchor stands: what the range and the
      // view culling measure against.
      final center = Vector3(slot.x, slot.bottom + slot.height / 2, slot.z);
      _ranged.add((center, anchor));
      _captures.timed(
        _tickers,
        TimedSurface.facing(
          controller: component.controller,
          node: anchor,
          center: center,
          facingRadians: slot.facingRadians,
        ),
      );
    }
  }

  /// Once per painted frame, at [seconds] on the harness clock: keeps
  /// asking for the one-off captures until they land, hides the plaza's
  /// animated surfaces beyond [plazaRange], and asks every timed surface
  /// in view for a capture once its interval is up, advancing that
  /// cadence's clock first so its widgets rebuild in the same frame.
  /// [forward] is the camera's view direction: with it a surface behind
  /// the eye or facing away from it is not captured; without it nothing is
  /// culled.
  void update(
    Vector3 eye,
    double seconds, {
    Vector3? forward,
    double glowFade = 1,
  }) {
    _captures.requestPending();
    for (final (center, node) in _ranged) {
      node.visible = eye.distanceTo(center) <= plazaRange;
    }
    // An anomaly's bloom breathes on its slot's pulse; every bloom fades
    // with the camera's height like a pool. One material write per
    // billboard, and only when the alpha moved.
    for (final billboard in billboards) {
      final pulse = billboard.attention.anomalous
          ? billboard.slot.glowAt(seconds)
          : 1.0;
      billboard.currentGlow = PlazaBillboard.glowAlpha * glowFade * pulse;
    }
    _captures
      ..requestDue(_tickers, eye, seconds, forward: forward)
      ..requestDue(_jumbotron, eye, seconds, forward: forward);
  }

  /// Total captures across these surfaces, for the debug overlay.
  int get captures => _captures.captures;

  /// The pose in front of a billboard, for the tour and for taps on it.
  static CameraPose facingPose(BillboardSlot slot, {double? distance}) {
    final d = distance ?? math.max(minFacingDistance, slot.width * 1.25);
    return CameraPose(
      x: slot.x + math.sin(slot.facingRadians) * d,
      y: eyeHeight,
      z: slot.z + math.cos(slot.facingRadians) * d,
      yaw: slot.facingRadians + math.pi,
      pitch: math.min(math.atan2(slot.centerY - eyeHeight, d), maxFacingPitch),
    );
  }

  /// The stand-off scales with the panel so its posts and the paving stay
  /// in frame, and the pitch is capped so verticals stay near vertical.
  static const minFacingDistance = 14.0;
  static const double maxFacingPitch = 12 * math.pi / 180;
}
