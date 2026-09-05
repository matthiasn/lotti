import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// Bakes stationary opaque surfaces into spatially bounded meshes. Interactive
/// anchors and visibility groups remain in the graph, and blended surfaces
/// retain their individual depth ordering. Call once after attaching textures.
class PlazaStaticMeshes {
  PlazaStaticMeshes({
    required this.cellSize,
    this.read = _read,
    this.upload = _upload,
  });

  final double cellSize;
  final MeshData Function(Geometry) read;
  final Geometry Function(MeshData) upload;

  static MeshData _read(Geometry geometry) => geometry.extractMeshData();
  static Geometry _upload(MeshData data) => MeshGeometry.fromMeshData(data);

  /// Returns the number of original meshes and their replacement batches.
  /// [preserve] protects whole subtrees that can move, toggle or accept picks.
  /// [preserveMaterials] keeps materials updated by a later capture or effect.
  ({int meshes, int batches}) bake(
    Node root, {
    required Set<Node> preserve,
    Set<Material> preserveMaterials = const {},
    Iterable<Node> localGroups = const [],
  }) {
    final groups = <Object, _Batch>{};
    final originals = <Node>[];
    final rootInverse = Matrix4.inverted(root.globalTransform);
    void visit(Node node) {
      if (preserve.contains(node) ||
          (!node.visible && node != root) ||
          !node.frustumCulled) {
        return;
      }
      final mesh = node.mesh;
      // Components may generate/replace their own meshes after a capture.
      final staticMesh = node.getComponents<Component>().every(
        (c) => c is MeshComponent,
      );
      if (staticMesh && mesh != null && mesh.primitives.length == 1) {
        final primitive = mesh.primitives.single;
        final material = primitive.material;
        if (!preserveMaterials.contains(material) &&
            material.runtimeType == UnlitMaterial &&
            material is UnlitMaterial &&
            material.isOpaque() &&
            material.lodFade == 1 &&
            node.highlightColor == null &&
            primitive.geometry is UnskinnedGeometry &&
            primitive.geometry is! BillboardGeometry) {
          final snapshot = read(primitive.geometry);
          if (snapshot.triangleCount == 0 ||
              snapshot.customAttributes.isNotEmpty) {
            return;
          }
          final transform = rootInverse * node.globalTransform;
          final at = transform.getTranslation();
          final uv = material.baseColorTextureTransform;
          final key = (
            (at.x / cellSize).floor(),
            (at.z / cellSize).floor(),
            material.baseColorTexture,
            material.depthBias,
            material.doubleSided,
            material.baseColorTextureTexCoord,
            uv.offset.x,
            uv.offset.y,
            uv.scale.x,
            uv.scale.y,
            uv.rotation,
            node.raycastable,
            node.layers,
            node.lightChannelMask,
            node.castsShadows,
          );
          final batch = groups.putIfAbsent(
            key,
            () => _Batch(material, node),
          );
          batch.parts.add(
            tintAndPlace(snapshot, transform, material),
          );
          batch.nodes.add(node);
          originals.add(node);
        }
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
    // Upload this group before mutating its source graph. A failed upload
    // leaves this group intact; earlier local groups remain renderable.
    final replacements = <(_Batch, Node)>[];
    for (final batch in groups.values) {
      if (batch.nodes.length < 2) continue;
      final data = MeshData.merge(batch.parts);
      final source = batch.source;
      replacements.add((
        batch,
        Node(mesh: Mesh(upload(data), batch.material))
          ..raycastable = source.raycastable
          ..layers = source.layers
          ..lightChannelMask = source.lightChannelMask
          ..castsShadows = source.castsShadows
          ..shadowStatic = true,
      ));
    }
    var merged = 0;
    for (final (batch, replacement) in replacements) {
      root.add(replacement);
      for (final node in batch.nodes) {
        node.mesh = null;
        merged++;
      }
    }
    // Remove abandoned static branches bottom-up. Explicit anchors and
    // component hosts remain available for later visibility/capture updates.
    for (final node in originals) {
      var empty = node;
      while (empty != root &&
          !preserve.contains(empty) &&
          empty.children.isEmpty &&
          empty.getComponents<Component>().isEmpty) {
        final parent = empty.parent;
        if (parent == null) break;
        parent.remove(empty);
        empty = parent;
      }
    }
    var batchCount = replacements.length;
    for (final group in localGroups) {
      final local = bake(
        group,
        preserve: {...preserve}..remove(group),
        preserveMaterials: preserveMaterials,
      );
      merged += local.meshes;
      batchCount += local.batches;
    }
    return (meshes: merged, batches: batchCount);
  }

  /// Carries geometry, UVs and effective linear HDR tint into root space.
  /// Uniform attribute streams let boxes and quads share one opaque mesh.
  static MeshData tintAndPlace(
    MeshData data,
    Matrix4 transform,
    UnlitMaterial material,
  ) {
    final placed = data.transformed(transform);
    final colors = Float32List(data.vertexCount * 4);
    final tint = material.baseColorFactor;
    for (var i = 0; i < colors.length; i++) {
      final vertex = data.colors?[i] ?? 1;
      colors[i] = (1 + (vertex - 1) * material.vertexColorWeight) * tint[i % 4];
    }
    return MeshData(
      positions: placed.positions,
      vertexCount: placed.vertexCount,
      normals: placed.normals ?? Float32List(data.vertexCount * 3),
      texCoords: placed.texCoords ?? Float32List(data.vertexCount * 2),
      texCoords1: placed.texCoords1 ?? Float32List(data.vertexCount * 2),
      colors: colors,
      indices: placed.indices,
    );
  }
}

class _Batch {
  _Batch(UnlitMaterial original, this.source)
    : material = UnlitMaterial(colorTexture: original.baseColorTexture)
        ..depthBias = original.depthBias
        ..doubleSided = original.doubleSided
        ..baseColorTextureTexCoord = original.baseColorTextureTexCoord
        ..baseColorTextureTransform = original.baseColorTextureTransform;

  final UnlitMaterial material;
  final Node source;
  final List<Node> nodes = [];
  final List<MeshData> parts = [];
}
