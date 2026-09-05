import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// An sRGB [Color] as the linear RGBA the unlit material expects.
Vector4 linearColor(Color color, {double? alpha}) {
  double lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return Vector4(lin(color.r), lin(color.g), lin(color.b), alpha ?? color.a);
}

/// A quad for a [WidgetComponent], wound counter-clockwise.
///
/// flutter_scene 0.23 flipped the engine's front-face convention to CCW and
/// regenerated its primitives, but `WidgetComponent`'s built-in quad still
/// winds CW (byte-identical to 0.20), so the default surface is back-face
/// culled and widget textures never show. Same vertex data as upstream's
/// quad, triangles reversed. Drop when the upstream quad is fixed.
Geometry ccwQuad(double width, double height) {
  final hw = width / 2;
  final hh = height / 2;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
    indices: [3, 1, 0, 2, 1, 3],
  );
}

/// A [ccwQuad] wound the other way: the same vertices and texture
/// coordinates facing -Z, so the picture on it is the front's seen from
/// behind, mirrored — the back of a translucent lightbox.
Geometry backQuad(double width, double height) {
  final hw = width / 2;
  final hh = height / 2;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
    indices: [0, 1, 3, 3, 1, 2],
  );
}

/// A [ccwQuad] whose two ends, each [fade] of its width, darken to black
/// through the vertex colour the unlit material multiplies in: a ticker
/// band's type fades into its housing instead of being sliced mid-glyph.
Geometry fadedQuad(double width, double height, {required double fade}) {
  final hw = width / 2;
  final hh = height / 2;
  // Columns from +X to -X, the way [ccwQuad] orders its vertices, each
  // with a bottom and a top vertex.
  final xs = [hw, hw - width * fade, -hw + width * fade, -hw];
  final us = [0.0, fade, 1 - fade, 1.0];
  final positions = <double>[];
  final texCoords = <double>[];
  final colors = <double>[];
  for (var c = 0; c < xs.length; c++) {
    final lit = c == 1 || c == 2 ? 1.0 : 0.0;
    for (final (y, v) in [(-hh, 1.0), (hh, 0.0)]) {
      positions.addAll([xs[c], y, 0]);
      texCoords.addAll([us[c], v]);
      colors.addAll([lit, lit, lit, 1]);
    }
  }
  final indices = <int>[];
  for (var c = 0; c + 1 < xs.length; c++) {
    final bottomA = 2 * c;
    final topA = bottomA + 1;
    final bottomB = bottomA + 2;
    final topB = bottomB + 1;
    indices.addAll([topA, bottomB, bottomA, topB, bottomB, topA]);
  }
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList(positions),
    texCoords: Float32List.fromList(texCoords),
    colors: Float32List.fromList(colors),
    indices: indices,
  );
}

/// A CCW quad whose texture coordinates repeat [uRepeat] × [vRepeat] times
/// (textures sample with wrap-around), offset by [uOffset] so tiled walls
/// do not all show the same windows.
Geometry tiledQuad(
  double width,
  double height, {
  required double uRepeat,
  required double vRepeat,
  double uOffset = 0,
  double vOffset = 0,
}) {
  final hw = width / 2;
  final hh = height / 2;
  final u0 = uOffset;
  final u1 = uOffset + uRepeat;
  final v0 = vOffset;
  final v1 = vOffset + vRepeat;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([u0, v1, u1, v1, u1, v0, u0, v0]),
    indices: [3, 1, 0, 2, 1, 3],
  );
}

/// A box whose faces carry their own tint in the vertex colour — the top
/// full, the front and back a little down, the sides further, the bottom
/// darkest — so an unlit box keeps its silhouette from every camera
/// height instead of collapsing to one flat patch. The material's base
/// colour multiplies the tint. Wound counter-clockwise, like the engine's
/// own primitives.
Geometry shadedCuboid(
  Vector3 size, {
  double top = 1.0,
  double front = 0.86,
  double side = 0.7,
  double bottom = 0.5,
}) {
  final x = size.x / 2;
  final y = size.y / 2;
  final z = size.z / 2;
  // Each face: four corners counter-clockwise seen from outside, its tint.
  final faces = <(List<List<double>>, double)>[
    (
      [
        [-x, -y, z],
        [x, -y, z],
        [x, y, z],
        [-x, y, z],
      ],
      front,
    ),
    (
      [
        [x, -y, -z],
        [-x, -y, -z],
        [-x, y, -z],
        [x, y, -z],
      ],
      front,
    ),
    (
      [
        [x, -y, z],
        [x, -y, -z],
        [x, y, -z],
        [x, y, z],
      ],
      side,
    ),
    (
      [
        [-x, -y, -z],
        [-x, -y, z],
        [-x, y, z],
        [-x, y, -z],
      ],
      side,
    ),
    (
      [
        [-x, y, z],
        [x, y, z],
        [x, y, -z],
        [-x, y, -z],
      ],
      top,
    ),
    (
      [
        [-x, -y, -z],
        [x, -y, -z],
        [x, -y, z],
        [-x, -y, z],
      ],
      bottom,
    ),
  ];
  final positions = Float32List(24 * 3);
  final colors = Float32List(24 * 4);
  final indices = <int>[];
  var v = 0;
  for (final (corners, tint) in faces) {
    final base = v;
    for (final c in corners) {
      positions[v * 3] = c[0];
      positions[v * 3 + 1] = c[1];
      positions[v * 3 + 2] = c[2];
      colors[v * 4] = tint;
      colors[v * 4 + 1] = tint;
      colors[v * 4 + 2] = tint;
      colors[v * 4 + 3] = 1;
      v++;
    }
    indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
  }
  return MeshGeometry.fromArrays(
    positions: positions,
    colors: colors,
    indices: indices,
  );
}

/// An emitter's colour pushed above display white by [boost], so the HDR
/// bloom pass picks it up: neon, chase heads, lit rooflines.
Vector4 emissiveColor(Color color, double boost, {double? alpha}) {
  final c = linearColor(color, alpha: alpha);
  return Vector4(c.x * boost, c.y * boost, c.z * boost, c.w);
}
