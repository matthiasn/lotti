import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/billboard_widget.dart';
import 'package:lotti/features/plaza/ui/block_marker_widget.dart';
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
  }) {
    _attachMarkers();
    _attachBillboards();
    _attachTickers();
  }

  final Scene scene;
  final PlazaWorld world;
  final Map<int, Node> markerAnchors;
  final List<PlazaBillboard> billboards;
  final double pxPerMeter;

  final List<WidgetComponent> _markers = [];
  final List<(Vector3, WidgetComponent, Node)> _billboardSurfaces = [];
  final List<(Vector3, WidgetComponent, Node)> _tickerSurfaces = [];

  /// Beyond this distance the plaza's animated surfaces crawl.
  static const plazaRange = 180.0;
  static const nearInterval = Duration(milliseconds: 100);
  static const tickerInterval = Duration(milliseconds: 50);
  static const farInterval = Duration(seconds: 3);

  static const markerWidth = 20.0;
  static const markerHeight = 6.5;

  void _attachMarkers() {
    for (final entry in markerAnchors.entries) {
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
      );
      entry.value.addComponent(component);
      _markers.add(component);
    }
  }

  void _attachBillboards() {
    for (final billboard in billboards) {
      final slot = billboard.slot;
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
      final component = WidgetComponent(
        child: TickerWidget(
          text: world.tickerText,
          heightMeters: slot.height,
          pxPerMeter: pxPerMeter,
          speedMetersPerSecond: slot.speedMetersPerSecond,
        ),
        size: Size(slot.width * pxPerMeter, slot.height * pxPerMeter),
        geometry: ccwQuad(slot.width, slot.height),
        update: const WidgetUpdatePolicy.interval(tickerInterval),
        input: WidgetInput.manual,
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
    for (final marker in _markers) {
      final controller = marker.controller;
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
    return n;
  }

  /// The pose in front of a billboard, for the tour and for taps on it.
  static CameraPose facingPose(BillboardSlot slot) => CameraPose(
    x: slot.x + math.sin(slot.facingRadians) * 14,
    y: eyeHeight,
    z: slot.z + math.cos(slot.facingRadians) * 14,
    yaw: slot.facingRadians + math.pi,
    pitch: math.atan2(slot.centerY - eyeHeight, 14),
  );
}
