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
  static const bays = 6;
  static const tileWidth = 12.0;
  static const tileHeight = 12.0;
  static const _px = 32;

  /// Lit-window ratio per state: busy buildings glow, finished ones sleep.
  static double litRatio(LanternState state) => switch (state) {
    LanternState.inProgress => 0.62,
    LanternState.blocked => 0.5,
    LanternState.overdue => 0.5,
    LanternState.open => 0.36,
    LanternState.off => 0.07,
  };

  static const _tints = <LanternState, ui.Color>{
    LanternState.inProgress: ui.Color(0xFF9BD8FF),
    LanternState.blocked: ui.Color(0xFFFFB0A0),
    LanternState.overdue: ui.Color(0xFFFFD08A),
    LanternState.open: ui.Color(0xFFFFE2B0),
    LanternState.off: ui.Color(0xFF6E7080),
  };

  /// Paints and uploads the five tiles.
  static Future<WallTextures> load() async {
    final map = <LanternState, Texture2D>{};
    for (final state in LanternState.values) {
      map[state] = await Texture2D.fromImage(_paint(state));
    }
    return WallTextures._(map);
  }

  Texture2D operator [](LanternState state) => _byState[state]!;

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
        final x = bay * _px + _px * 0.22;
        final y = floor * _px + _px * 0.28;
        final rect = ui.Rect.fromLTWH(x, y, _px * 0.56, _px * 0.5);
        final on = rng.nextDouble() < lit;
        final glow = on
            ? 0.55 + rng.nextDouble() * 0.45
            : 0.06 + rng.nextDouble() * 0.06;
        canvas.drawRect(
          rect,
          ui.Paint()..color = tint.withValues(alpha: glow),
        );
        if (on && rng.nextDouble() < 0.5) {
          // A curtain or a shape inside: breaks the grid's regularity.
          canvas.drawRect(
            ui.Rect.fromLTWH(
              x,
              y + rect.height * 0.55,
              rect.width,
              rect.height * 0.45,
            ),
            ui.Paint()..color = const ui.Color(0x8C0B0A14),
          );
        }
      }
      // Floor slab line.
      canvas.drawRect(
        ui.Rect.fromLTWH(0, floor * _px.toDouble(), w.toDouble(), 2),
        ui.Paint()..color = const ui.Color(0xFF07060D),
      );
    }
    return recorder.endRecording().toImageSync(w, h);
  }
}
