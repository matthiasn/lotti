import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';

part 'wall_textures_wall_ink_part.dart';
part 'wall_textures_painters.dart';

/// Window-grid textures for the side and back walls, one per lantern
/// state, tiled across every wall: the cheapest way to turn a cuboid into
/// a building at night. Painted once with the Flutter canvas and uploaded
/// as repeating textures; walls pick a tile offset from the task id so no
/// two facades share the same lit windows.
class WallTextures {
  WallTextures._(this._byState, this.mode);

  final Map<(LanternState, int), Texture2D> _byState;

  /// The hour these were painted for. A scene must not be handed a set
  /// from the other sky.
  final PlazaSkyMode mode;

  /// How many window-tile families there are: the same lit ratio in
  /// three occupancies (mixed flats, a residential stack with dark floors
  /// and one lit edge to edge, a cool office curtain wall), so adjacent walls
  /// do not share one wallpaper. The office family has larger glass panes
  /// and metal mullions; all families share the same atlas dimensions.
  static const tileFamilies = 3;

  /// One tile is [floors] storeys tall and [bays] windows wide, in world
  /// metres [tileHeight] × [tileWidth].
  static const floors = 4;
  static const bays = 10;
  static const tileWidth = 12.0;
  static const tileHeight = 12.0;

  /// One storey of the window tile, metres: walls stack whole storeys.
  static const double storeyHeight = tileHeight / floors;
  // Keep the authored coordinate space: both metre-sized shapes and fine
  // pixel details scale together when rasterized into the smaller texture.
  static const _px = 96;
  static const _textureScale = 0.5;

  /// One paving tile covers this many metres of plaza: a 2 × 2 grid of
  /// slabs with a joint between.
  static const pavingMeters = 4.0;

  /// The shopfront strip: six trades and one vacant unit in one
  /// [shopfrontWidth] × [shopfrontHeight] metre parade, painted once per
  /// lantern state and parade order so a building's ground floor says
  /// what its task is doing and no two neighbours show the same run (see
  /// [shopfront]).
  static const shopfrontWidth = 33.0;
  static const shopfrontHeight = 4.0;

  /// How many parade orders there are; `_windowedWall` picks one per wall.
  static const paradeVariants = 3;

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

  /// Paints and uploads the fifteen window tiles, fifteen shopfront strips,
  /// the light-pool falloff, the asphalt grain and the plaza paving, in
  /// [mode]'s inks.
  ///
  /// The set belongs to one hour: switching skies loads a second set rather
  /// than repainting this one, so the world on screen keeps its textures
  /// until the new ones are on the GPU.
  static Future<WallTextures> load({
    PlazaCopy? copy,
    PlazaSkyMode mode = PlazaSkyMode.night,
  }) async {
    final map = <(LanternState, int), Texture2D>{};
    final shops = <(LanternState, int), Texture2D>{};
    final ink = WallInk.of(mode);
    for (final state in LanternState.values) {
      for (var f = 0; f < tileFamilies; f++) {
        map[(state, f)] = await _upload(
          paintWindows(state, family: f, ink: ink),
        );
      }
      for (var v = 0; v < paradeVariants; v++) {
        shops[(state, v)] = await _upload(
          paintShopfront(state, variant: v, copy: copy, ink: ink),
        );
      }
    }
    final textures = WallTextures._(map, mode)
      ..pool = await _upload(paintPool())
      ..shadow = await _upload(paintShadow())
      ..grain = await _upload(paintGrain())
      ..paving = await _upload(paintPaving())
      .._shopfronts = shops;
    return textures;
  }

  /// The window tile for [state] in tile [family].
  Texture2D window(LanternState state, int family) =>
      _byState[(state, family)]!;

  /// A radial falloff: hot core, long feathered skirt. White; the material
  /// colour tints it.
  late final Texture2D pool;

  /// Asphalt grain: a near-black noise tile with faint lighter grit.
  late final Texture2D grain;

  /// The contact-shadow mask; see [paintShadow].
  late final Texture2D shadow;

  /// Plaza paving: slab joints and a little wear, blended over the slab.
  late final Texture2D paving;

  late Map<(LanternState, int), Texture2D> _shopfronts;

  /// The ground floor for [state] in parade order [variant]: the parade
  /// dressed for what the task is doing. In progress trades (lit signs,
  /// lit glass, people inside); overdue trades late, flooded amber, every
  /// sign reading OPEN LATE; open (not started) is papered over and
  /// fitting out, OPENING SOON on the fascia; blocked is shuttered behind
  /// alarm tape with BLOCKED on every sign; off is shuttered for the
  /// night, CLOSED, with a security light over each door.
  Texture2D shopfront(LanternState state, int variant) =>
      _shopfronts[(state, variant)]!;

  static const _warmLight = ui.Color(0xFFFFE2B8);

  /// A fixed dark for what the sky never reaches: the shade inside a lit
  /// interior, and the dark stripe on a painted canvas awning.
  static const _shade = ui.Color(0xFF0B0A14);

  /// The alarm colours match the lanterns.
  static const _alarm = ui.Color(0xFFE4655F);
  static const _amber = ui.Color(0xFFFBA336);

  static const _fasciaM = 0.75;
  static const _glassTopM = 0.85;
  static const _baseM = 0.4;
  static const _pilasterM = 0.25;
  static const _jambM = 0.12;
  static const _doorM = 1.0;

  /// Paints the shopfront strip for [state] in parade order [variant];
  /// public so the dressing can be checked pixel by pixel without a GPU.
  @visibleForTesting
  static ui.Image paintShopfront(
    LanternState state, {
    int variant = 0,
    PlazaCopy? copy,
    WallInk ink = WallInk.night,
  }) {
    const w = shopfrontWidth * _px;
    const h = shopfrontHeight * _px;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..scale(_textureScale)
      ..drawRect(
        const ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = ink.wall,
      );
    final rng = math.Random(31337 + state.index * 7 + variant);
    final dressing = _Dressing.forState(state);
    var left = 0.0;
    for (final shop in _parades[variant % _parades.length]) {
      _paintShop(
        canvas,
        rng,
        shop,
        left,
        _m(shop.width),
        dressing,
        copy ?? PlazaCopy.english,
        ink,
      );
      left += _m(shop.width);
    }
    return recorder.endRecording().toImageSync(
      (w * _textureScale).round(),
      (h * _textureScale).round(),
    );
  }

  static const _spines = [
    ui.Color(0xFFE84C6A),
    ui.Color(0xFF4CC2E8),
    ui.Color(0xFFF2C94C),
    ui.Color(0xFF7ED957),
    ui.Color(0xFFF08A3C),
    ui.Color(0xFFB884F2),
  ];

  /// Restrained, staggered stone joints; transparent slab centres preserve
  /// the ground's shared material instead of making a checkerboard of lights.
  @visibleForTesting
  static ui.Image paintPaving() {
    const size = 256;
    const course = size / 4;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final colors = dsTokensDark.colors;
    final joint = ui.Paint()
      ..color = colors.background.level01.withValues(
        alpha: SurfaceAlphas.muted,
      );
    final edge = ui.Paint()
      ..color = colors.text.highEmphasis.withValues(
        alpha: SurfaceAlphas.tint,
      );
    // Texture-space dimensions describe mortar, not widget layout spacing.
    for (var row = 0; row < 4; row++) {
      final y = row * course;
      canvas
        ..drawRect(ui.Rect.fromLTWH(0, y, size.toDouble(), 2), joint)
        ..drawRect(ui.Rect.fromLTWH(0, y + 2, size.toDouble(), 1), edge);
      final x = row.isEven ? 0.0 : size / 2;
      canvas
        ..drawRect(ui.Rect.fromLTWH(x, y, 2, course), joint)
        ..drawRect(ui.Rect.fromLTWH(x + 2, y + 2, 1, course - 2), edge);
    }
    return recorder.endRecording().toImageSync(size, size);
  }

  /// The radial falloff every ground light — and, in daylight, every
  /// contact shadow — is drawn with. White; the material colour tints it.
  /// Public so its shape can be checked without a GPU.
  @visibleForTesting
  static ui.Image paintPool() {
    const size = 256;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawCircle(
      const ui.Offset(size / 2, size / 2),
      size / 2,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          const ui.Offset(size / 2, size / 2),
          size / 2,
          // A hot core and a short skirt: the ground goes dark again
          // within the radius, so pools read as light on paving rather
          // than a wash.
          const [
            ui.Color(0xFFFFFFFF),
            ui.Color(0x99FFFFFF),
            ui.Color(0x33FFFFFF),
            ui.Color(0x0DFFFFFF),
            ui.Color(0x00FFFFFF),
          ],
          const [0, 0.12, 0.38, 0.65, 1],
        ),
    );
    return recorder.endRecording().toImageSync(size, size);
  }

  /// The mask a contact shadow is drawn with: opaque across the middle,
  /// feathered at the rim.
  ///
  /// Deliberately not the light pool's falloff. A pool is a hot core with a
  /// long thin skirt, which is right for light — the ground is brightest
  /// under the lamp — but wrong for shade: multiplied into a dark colour,
  /// that skirt darkens the paving by a percent or two and the shadow reads
  /// as a stain. Shade is flat in the middle and soft only at its edge.
  /// Public so its shape can be checked without a GPU.
  @visibleForTesting
  static ui.Image paintShadow() {
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
            ui.Color(0xFFFFFFFF),
            ui.Color(0x8CFFFFFF),
            ui.Color(0x00FFFFFF),
          ],
          const [0, 0.55, 0.82, 1],
        ),
    );
    return recorder.endRecording().toImageSync(size, size);
  }

  /// Asphalt grain: a transparent tile of dark grit with the odd light
  /// fleck, blended over whichever road colour the hour supplies. Public so
  /// it can be checked without a GPU.
  @visibleForTesting
  static ui.Image paintGrain() {
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
              ? ui.Color.fromARGB(5 + rng.nextInt(8), 255, 240, 220)
              : ui.Color.fromARGB(40 + rng.nextInt(60), 0, 0, 0),
      );
    }
    return recorder.endRecording().toImageSync(size, size);
  }

  /// Paints the window tile for [state] in tile [family]; public so the
  /// occupancy contract can be checked without a GPU.
  @visibleForTesting
  static ui.Image paintWindows(
    LanternState state, {
    int family = 0,
    WallInk ink = WallInk.night,
  }) {
    const w = bays * _px;
    const h = floors * _px;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..scale(_textureScale)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = family == 2 ? ink.officeWall : ink.wall,
      );
    final rng = math.Random(state.index * 7919 + 17 + family * 101);
    final tint = _tints[state]!;
    final lit = litRatio(state);
    // Family 1: a residential stack, one floor dark and one lit edge to
    // edge, the rest as rolled. Family 2: an office grid, mostly the cool
    // tint, fewer blinds.
    final darkFloor = family == 1 ? rng.nextInt(floors) : -1;
    var litFloor = family == 1 ? rng.nextInt(floors) : -1;
    if (family == 1 && litFloor == darkFloor) {
      litFloor = (litFloor + 1) % floors;
    }
    final coolShare = family == 2 ? 0.8 : 0.3;
    final blindShare = family == 2 ? 0.15 : 0.4;
    for (var floor = 0; floor < floors; floor++) {
      for (var bay = 0; bay < bays; bay++) {
        // Residential punched windows contrast with floor-to-ceiling office
        // glazing. This changes the architecture without another atlas or draw.
        final office = family == 2;
        final x = bay * _px + _px * (office ? 0.08 : 0.27);
        final y = floor * _px + _px * (office ? 0.14 : 0.3);
        final rect = ui.Rect.fromLTWH(
          x,
          y,
          _px * (office ? 0.84 : 0.46),
          _px * (office ? 0.78 : 0.5),
        );
        final roll = rng.nextDouble() < lit;
        final on = floor != darkFloor && (floor == litFloor || roll);
        // Two tints per state: most windows warm, a few the cooler one,
        // and a sill-to-lintel gradient so the pane has depth. By day the
        // tint gives way to the sky the glass mirrors, and occupancy shows
        // as the room behind the reflection.
        final cool = rng.nextDouble() < coolShare;
        final base = cool ? _coolTint : tint;
        final (paneTop, paneBottom) = ink.pane(
          tint: base,
          on: on,
          roll: rng.nextDouble(),
        );
        // Reveal: the wall's thickness around the pane — a hole at night,
        // a band of shade by day; then the pane; then mullion and transom.
        final mullion = ui.Paint()..color = ink.mullion;
        canvas
          ..drawRect(rect.inflate(_px * 0.03), ui.Paint()..color = ink.reveal)
          ..drawRect(
            rect,
            ui.Paint()
              ..shader = ui.Gradient.linear(
                rect.topCenter,
                rect.bottomCenter,
                [paneTop, paneBottom],
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
        if (on && rng.nextDouble() < blindShare) {
          // A blind pulled part-way: breaks the grid's regularity.
          canvas.drawRect(
            ui.Rect.fromLTWH(
              rect.left,
              rect.top,
              rect.width,
              rect.height * (0.25 + rng.nextDouble() * 0.35),
            ),
            ui.Paint()..color = ink.blind,
          );
        }
        if (office) {
          // Narrow metal caps catch the city light between the dark glazing.
          canvas.drawRect(
            ui.Rect.fromLTWH(
              bay * _px.toDouble(),
              floor * _px.toDouble(),
              _px * 0.025,
              _px.toDouble(),
            ),
            ui.Paint()..color = ink.mullion,
          );
        }
      }
      // Floor slab: an edge over a band, the relief of a storey.
      canvas
        ..drawRect(
          ui.Rect.fromLTWH(0, floor * _px.toDouble(), w.toDouble(), 6),
          ui.Paint()..color = ink.frame,
        )
        ..drawRect(
          ui.Rect.fromLTWH(0, floor * _px.toDouble() + 6, w.toDouble(), 3),
          ui.Paint()..color = ink.slabEdge,
        );
    }
    return recorder.endRecording().toImageSync(
      (w * _textureScale).round(),
      (h * _textureScale).round(),
    );
  }
}
