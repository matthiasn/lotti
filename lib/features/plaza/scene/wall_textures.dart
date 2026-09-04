import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';

/// Window-grid textures for the side and back walls, one per lantern
/// state, tiled across every wall: the cheapest way to turn a cuboid into
/// a building at night. Painted once with the Flutter canvas and uploaded
/// as repeating textures; walls pick a tile offset from the task id so no
/// two facades share the same lit windows.
class WallTextures {
  WallTextures._(this._byState);

  final Map<LanternState, Texture2D> _byState;

  /// One tile is [floors] storeys tall and [bays] windows wide, in world
  /// metres [tileHeight] × [tileWidth].
  static const floors = 4;
  static const bays = 10;
  static const tileWidth = 12.0;
  static const tileHeight = 12.0;
  static const _px = 96;

  /// One paving tile covers this many metres of plaza: a 2 × 2 grid of
  /// slabs with a joint between.
  static const pavingMeters = 4.0;

  /// Lit-window ratio per state: busy buildings glow, finished ones sleep.
  static double litRatio(LanternState state) => switch (state) {
    LanternState.inProgress => 0.62,
    LanternState.blocked => 0.5,
    LanternState.overdue => 0.5,
    LanternState.open => 0.36,
    LanternState.off => 0.2,
  };

  static const _coolTint = ui.Color(0xFF8FB8FF);

  static const _tints = <LanternState, ui.Color>{
    LanternState.inProgress: ui.Color(0xFF9BD8FF),
    LanternState.blocked: ui.Color(0xFFFFB0A0),
    LanternState.overdue: ui.Color(0xFFFFD08A),
    LanternState.open: ui.Color(0xFFFFE2B0),
    LanternState.off: ui.Color(0xFF6E7080),
  };

  /// Paints and uploads the five tiles, the light-pool falloff and the
  /// asphalt grain.
  static Future<WallTextures> load() async {
    final map = <LanternState, Texture2D>{};
    for (final state in LanternState.values) {
      map[state] = await Texture2D.fromImage(_paint(state));
    }
    final textures = WallTextures._(map)
      ..pool = await Texture2D.fromImage(_paintPool())
      ..grain = await Texture2D.fromImage(_paintGrain())
      ..paving = await Texture2D.fromImage(_paintPaving());
    return textures;
  }

  Texture2D operator [](LanternState state) => _byState[state]!;

  /// A radial falloff: hot core, long feathered skirt. White; the material
  /// colour tints it.
  late final Texture2D pool;

  /// Asphalt grain: a near-black noise tile with faint lighter grit.
  late final Texture2D grain;

  /// Plaza paving: slab joints and a little wear, blended over the slab.
  late final Texture2D paving;

  static ui.Image _paintPaving() {
    const size = 256;
    const half = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..color = const ui.Color(0x00000000),
      );
    final rng = math.Random(9001);
    // Four slabs, each a faintly different shade, so the grid is not flat.
    for (final (x, y) in [(0.0, 0.0), (half, 0.0), (0.0, half), (half, half)]) {
      canvas.drawRect(
        ui.Rect.fromLTWH(x, y, half, half),
        ui.Paint()
          ..color = ui.Color.fromARGB(10 + rng.nextInt(16), 255, 255, 255),
      );
    }
    // Joints: a dark line with a lit edge, the way wet paving catches light.
    final joint = ui.Paint()..color = const ui.Color(0x66000000);
    final edge = ui.Paint()..color = const ui.Color(0x14FFFFFF);
    for (final at in [0.0, half]) {
      canvas
        ..drawRect(ui.Rect.fromLTWH(at, 0, 3, size.toDouble()), joint)
        ..drawRect(ui.Rect.fromLTWH(at + 3, 0, 1.5, size.toDouble()), edge)
        ..drawRect(ui.Rect.fromLTWH(0, at, size.toDouble(), 3), joint)
        ..drawRect(ui.Rect.fromLTWH(0, at + 3, size.toDouble(), 1.5), edge);
    }
    for (var i = 0; i < 300; i++) {
      canvas.drawRect(
        ui.Rect.fromLTWH(
          rng.nextDouble() * size,
          rng.nextDouble() * size,
          1.5,
          1,
        ),
        ui.Paint()..color = ui.Color.fromARGB(20 + rng.nextInt(40), 0, 0, 0),
      );
    }
    return recorder.endRecording().toImageSync(size, size);
  }

  static ui.Image _paintPool() {
    const size = 256;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawCircle(
      const ui.Offset(size / 2, size / 2),
      size / 2,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(size / 2, size / 2),
          size / 2,
          const [
            ui.Color(0xFFFFFFFF),
            ui.Color(0xB3FFFFFF),
            ui.Color(0x4DFFFFFF),
            ui.Color(0x14FFFFFF),
            ui.Color(0x00FFFFFF),
          ],
          const [0, 0.18, 0.45, 0.75, 1],
        ),
    );
    return recorder.endRecording().toImageSync(size, size);
  }

  static ui.Image _paintGrain() {
    const size = 128;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..color = const ui.Color(0x00000000),
      );
    // Mostly dark grit with the odd faint fleck: asphalt, not snow.
    final rng = math.Random(4242);
    for (var i = 0; i < 2200; i++) {
      final light = rng.nextDouble() < 0.12;
      canvas.drawRect(
        ui.Rect.fromLTWH(
          rng.nextDouble() * size,
          rng.nextDouble() * size,
          1 + rng.nextDouble() * 1.5,
          1,
        ),
        ui.Paint()
          ..color = light
              ? ui.Color.fromARGB(10 + rng.nextInt(14), 255, 240, 220)
              : ui.Color.fromARGB(50 + rng.nextInt(80), 0, 0, 0),
      );
    }
    return recorder.endRecording().toImageSync(size, size);
  }

  static ui.Image _paint(LanternState state) {
    const w = bays * _px;
    const h = floors * _px;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF0B0A14),
      );
    final rng = math.Random(state.index * 7919 + 17);
    final tint = _tints[state]!;
    final lit = litRatio(state);
    for (var floor = 0; floor < floors; floor++) {
      for (var bay = 0; bay < bays; bay++) {
        final x = bay * _px + _px * 0.2;
        final y = floor * _px + _px * 0.24;
        final rect = ui.Rect.fromLTWH(x, y, _px * 0.6, _px * 0.56);
        final on = rng.nextDouble() < lit;
        // Two tints per state: most windows warm, a few the cooler one,
        // and a sill-to-lintel gradient so the pane has depth.
        final cool = rng.nextDouble() < 0.3;
        final base = cool ? _coolTint : tint;
        final glow = on
            ? 0.5 + rng.nextDouble() * 0.5
            : 0.14 + rng.nextDouble() * 0.1;
        // Reveal: a dark frame around the pane; then the pane with a
        // sill-to-lintel gradient; then mullion and transom.
        final mullion = ui.Paint()..color = const ui.Color(0xFF07060D);
        canvas
          ..drawRect(
            rect.inflate(_px * 0.03),
            ui.Paint()..color = const ui.Color(0xFF050409),
          )
          ..drawRect(
            rect,
            ui.Paint()
              ..shader = ui.Gradient.linear(
                rect.topCenter,
                rect.bottomCenter,
                [
                  base.withValues(alpha: glow),
                  base.withValues(alpha: glow * 0.55),
                ],
              ),
          )
          ..drawRect(
            ui.Rect.fromLTWH(rect.center.dx - 1.5, rect.top, 3, rect.height),
            mullion,
          )
          ..drawRect(
            ui.Rect.fromLTWH(
              rect.left,
              rect.top + rect.height * 0.32,
              rect.width,
              2.5,
            ),
            mullion,
          );
        if (on && rng.nextDouble() < 0.4) {
          // A blind pulled part-way: breaks the grid's regularity.
          canvas.drawRect(
            ui.Rect.fromLTWH(
              rect.left,
              rect.top,
              rect.width,
              rect.height * (0.25 + rng.nextDouble() * 0.35),
            ),
            ui.Paint()..color = const ui.Color(0xB30B0A14),
          );
        }
      }
      // Floor slab: a lit edge over a dark band, the relief of a storey.
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(0, floor * _px.toDouble(), w.toDouble(), 6),
          ui.Paint()..color = const ui.Color(0xFF07060D),
        )
        ..drawRect(
          ui.Rect.fromLTWH(0, floor * _px.toDouble() + 6, w.toDouble(), 3),
          ui.Paint()..color = const ui.Color(0xFF1C1A2A),
        );
    }
    return recorder.endRecording().toImageSync(w, h);
  }
}
