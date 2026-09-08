import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/scene/plaza_characters.dart';
import 'package:vector_math/vector_math.dart';

/// Reads the shipped penguin's hierarchy and bind matrices without GPU
/// uploads. Empty geometry stands in for its base vertex buffers; skeletons,
/// morph deltas, materials and transforms retain the asset's actual structure.
Node loadPenguinWithoutGpu() {
  final bytes = File(PlazaCharacters.asset).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final jsonLength = data.getUint32(12, Endian.little);
  final doc =
      jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength)))
          as Map<String, dynamic>;
  final binary = 28 + jsonLength;
  final accessors = (doc['accessors'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final views = (doc['bufferViews'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  Float32List floats(int index, int components) {
    final accessor = accessors[index];
    final view = views[accessor['bufferView'] as int];
    final offset = binary + (view['byteOffset'] as int);
    return Float32List.fromList([
      for (var i = 0; i < (accessor['count'] as int) * components; i++)
        data.getFloat32(offset + i * 4, Endian.little),
    ]);
  }

  final specs = (doc['nodes'] as List<dynamic>).cast<Map<String, dynamic>>();
  final nodes = [for (final spec in specs) Node(name: spec['name'] as String)];
  for (final (i, spec) in specs.indexed) {
    final translation = spec['translation'] as List<dynamic>?;
    if (translation != null) {
      nodes[i].position = Vector3.array(
        translation.cast<num>().map((v) => v.toDouble()).toList(),
      );
    }
    for (final child in (spec['children'] as List<dynamic>?) ?? <dynamic>[]) {
      nodes[i].add(nodes[child as int]);
    }
  }
  final skinSpec =
      (doc['skins'] as List<dynamic>).single as Map<String, dynamic>;
  final accessor =
      (doc['accessors'] as List<dynamic>)[skinSpec['inverseBindMatrices']
              as int]
          as Map<String, dynamic>;
  final view =
      (doc['bufferViews'] as List<dynamic>)[accessor['bufferView'] as int]
          as Map<String, dynamic>;
  final offset = binary + (view['byteOffset'] as int);
  final skin = Skin()
    ..joints.addAll(
      (skinSpec['joints'] as List<dynamic>).map((i) => nodes[i as int]),
    );
  for (var i = 0; i < skin.joints.length; i++) {
    skin.inverseBindMatrices.add(
      Matrix4.fromList([
        for (var j = 0; j < 16; j++)
          data.getFloat32(offset + (i * 16 + j) * 4, Endian.little),
      ]),
    );
  }
  for (final (i, spec) in specs.indexed) {
    if (spec['mesh'] == null) continue;
    final mesh =
        (doc['meshes'] as List<dynamic>)[spec['mesh'] as int]
            as Map<String, dynamic>;
    final primitive =
        (mesh['primitives'] as List<dynamic>).single as Map<String, dynamic>;
    final targets = (primitive['targets'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    final Geometry geometry;
    if (targets == null) {
      geometry = UnskinnedGeometry();
    } else {
      geometry = MorphedUnskinnedGeometry(
        MorphTargetData(
          vertexCount:
              accessors[targets.first['POSITION'] as int]['count'] as int,
          targetCount: targets.length,
          positionDeltas: Float32List.fromList([
            for (final target in targets)
              ...floats(target['POSITION'] as int, 3),
          ]),
          normalDeltas: Float32List.fromList([
            for (final target in targets) ...floats(target['NORMAL'] as int, 3),
          ]),
          targetNames:
              ((mesh['extras'] as Map<String, dynamic>)['targetNames']
                      as List<dynamic>)
                  .cast<String>(),
        ),
      );
    }
    nodes[i]
      ..mesh = Mesh(
        geometry,
        PhysicallyBasedMaterial()..metallicFactor = 0,
      )
      ..skin = skin;
  }
  return nodes.first;
}

/// Counts requested captures and lets a test finish them without a GPU host.
class FakeWidgetTextureController extends WidgetTextureController {
  int requests = 0;
  int landed = 0;
  Duration duration = Duration.zero;

  @override
  void requestCapture() => requests++;

  @override
  int get captureCount => landed;

  @override
  Duration get lastCaptureDuration => duration;
}
