import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/face.dart';

/// A complete rigged character: a skeleton of [Bone]s plus an optional
/// [FaceRig]. This is the declarative contract between the (offline, possibly
/// AI-assisted) rigging step and the cheap on-device player. In Phase 1 it is
/// hand-authored in Dart; later it deserializes from the JSON rig format.
class RigSpec {
  RigSpec({
    required this.name,
    required List<Bone> bones,
    List<LimbRibbonSpec> ribbons = const [],
    List<SkinnedMeshSpec> meshes = const [],
    this.face,
  }) : bones = List<Bone>.unmodifiable(bones),
       ribbons = List<LimbRibbonSpec>.unmodifiable(ribbons),
       meshes = List<SkinnedMeshSpec>.unmodifiable(meshes),
       _byId = _buildById(bones),
       _drawOrder = List<Bone>.unmodifiable(_sortedByZ(bones)) {
    _topoOrder = List<Bone>.unmodifiable(_computeTopoOrder(this.bones, _byId));
    _validateRibbons(this.ribbons, _byId);
    _validateMeshes(this.meshes, _byId);
    _ribbonDrawOrder = List<LimbRibbonSpec>.unmodifiable(
      _sortedRibbons(this.ribbons),
    );
    _meshDrawOrder = List<SkinnedMeshSpec>.unmodifiable(
      _sortedMeshes(this.meshes),
    );
    _ribbonHiddenBoneIds = Set<String>.unmodifiable(
      this.ribbons.expand((r) => r.hiddenBoneIds),
    );
    _hiddenDrawableBoneIds = Set<String>.unmodifiable({
      ..._ribbonHiddenBoneIds,
      ...this.meshes.expand((m) => m.hiddenBoneIds),
    });
  }

  /// Bones sorted ascending by [Bone.z]. Kept as a typed helper so the sort
  /// closure's arguments infer as [Bone] (the `List.unmodifiable(Iterable)`
  /// context would otherwise collapse a literal to `List<dynamic>`).
  static List<Bone> _sortedByZ(List<Bone> bones) =>
      [...bones]..sort((a, b) => a.z.compareTo(b.z));

  final String name;

  /// The bones of this rig, in author order. Unmodifiable — the cached
  /// [drawOrder]/[topoOrder] and [_byId] lookup assume the set never changes.
  final List<Bone> bones;

  /// Optional soft-deformation ribbons. A ribbon draws one continuous tapered
  /// path through a chain of solved joint bones, then hides the rigid segment
  /// drawables it replaces. This is the cheap "mesh-style" path for arms/legs:
  /// knees and elbows bend through one silhouette instead of folding as separate
  /// cardboard capsules.
  final List<LimbRibbonSpec> ribbons;

  /// Optional weighted polygon meshes. Unlike a ribbon, a skinned mesh is not
  /// restricted to one limb centreline: every vertex can blend between one or
  /// more bones, so broad surfaces such as a jacket, pelvis, or shoulder mass
  /// can squash, lean and bend without splitting into rigid cardboard pieces.
  final List<SkinnedMeshSpec> meshes;

  final FaceRig? face;

  final Map<String, Bone> _byId;
  final List<Bone> _drawOrder;
  late final List<Bone> _topoOrder;
  late final List<LimbRibbonSpec> _ribbonDrawOrder;
  late final List<SkinnedMeshSpec> _meshDrawOrder;
  late final Set<String> _ribbonHiddenBoneIds;
  late final Set<String> _hiddenDrawableBoneIds;

  /// Indexes bones by id, rejecting duplicates up front. A map literal would
  /// silently keep the last duplicate while [_computeTopoOrder] still traversed
  /// the original list, dropping a bone from lookup without any failure.
  static Map<String, Bone> _buildById(List<Bone> bones) {
    final byId = <String, Bone>{};
    for (final bone in bones) {
      if (byId.containsKey(bone.id)) {
        throw ArgumentError('Duplicate bone id "${bone.id}"');
      }
      byId[bone.id] = bone;
    }
    return byId;
  }

  /// Lookup a bone by id.
  Bone? bone(String id) => _byId[id];

  /// Bones sorted by ascending [Bone.z] — the order to paint them in.
  List<Bone> get drawOrder => _drawOrder;

  /// Ribbons sorted by ascending [LimbRibbonSpec.z] — the fill paint order.
  List<LimbRibbonSpec> get ribbonDrawOrder => _ribbonDrawOrder;

  /// Meshes sorted by ascending [SkinnedMeshSpec.z] — the fill paint order.
  List<SkinnedMeshSpec> get meshDrawOrder => _meshDrawOrder;

  /// Bone ids whose rigid drawables are replaced by ribbons.
  Set<String> get ribbonHiddenBoneIds => _ribbonHiddenBoneIds;

  /// Bone ids whose rigid drawables are replaced by any soft surface.
  Set<String> get hiddenDrawableBoneIds => _hiddenDrawableBoneIds;

  /// Bones ordered so every parent precedes its children — the order forward
  /// kinematics must visit them in.
  List<Bone> get topoOrder => _topoOrder;

  static List<Bone> _computeTopoOrder(
    List<Bone> bones,
    Map<String, Bone> byId,
  ) {
    final visited = <String>{};
    final visiting = <String>{};
    final ordered = <Bone>[];

    void visit(Bone b) {
      if (visited.contains(b.id)) return;
      // A bone re-encountered while still on the recursion stack is a parent
      // cycle (a→b→a). Catch it here so a directly-constructed RigSpec (samples,
      // demo) fails with a clear error instead of a stack overflow.
      if (!visiting.add(b.id)) {
        throw ArgumentError('Bone "${b.id}" is part of a parent cycle');
      }
      final parentId = b.parent;
      if (parentId != null) {
        final parent = byId[parentId];
        if (parent == null) {
          throw ArgumentError(
            'Bone "${b.id}" references missing parent "$parentId"',
          );
        }
        visit(parent);
      }
      visiting.remove(b.id);
      visited.add(b.id);
      ordered.add(b);
    }

    bones.forEach(visit);
    return ordered;
  }

  static List<LimbRibbonSpec> _sortedRibbons(List<LimbRibbonSpec> ribbons) =>
      [...ribbons]..sort((a, b) {
        final byZ = a.z.compareTo(b.z);
        return byZ == 0 ? a.id.compareTo(b.id) : byZ;
      });

  static List<SkinnedMeshSpec> _sortedMeshes(List<SkinnedMeshSpec> meshes) =>
      [...meshes]..sort((a, b) {
        final byZ = a.z.compareTo(b.z);
        return byZ == 0 ? a.id.compareTo(b.id) : byZ;
      });

  static void _validateRibbons(
    List<LimbRibbonSpec> ribbons,
    Map<String, Bone> byId,
  ) {
    final ids = <String>{};
    for (final ribbon in ribbons) {
      if (!ids.add(ribbon.id)) {
        throw ArgumentError('Duplicate ribbon id "${ribbon.id}"');
      }
      if (ribbon.jointBoneIds.length < 2) {
        throw ArgumentError('Ribbon "${ribbon.id}" needs at least two joints');
      }
      if (ribbon.jointBoneIds.length != ribbon.halfWidths.length) {
        throw ArgumentError(
          'Ribbon "${ribbon.id}" has ${ribbon.jointBoneIds.length} joints '
          'but ${ribbon.halfWidths.length} half-widths',
        );
      }
      if (ribbon.samplesPerSegment <= 0) {
        throw ArgumentError(
          'Ribbon "${ribbon.id}" samplesPerSegment must be positive',
        );
      }
      for (final width in ribbon.halfWidths) {
        if (width <= 0) {
          throw ArgumentError(
            'Ribbon "${ribbon.id}" half-widths must be positive',
          );
        }
      }
      for (final boneId in [
        ...ribbon.jointBoneIds,
        ...ribbon.hiddenBoneIds,
      ]) {
        if (!byId.containsKey(boneId)) {
          throw ArgumentError(
            'Ribbon "${ribbon.id}" references missing bone "$boneId"',
          );
        }
      }
    }
  }

  static void _validateMeshes(
    List<SkinnedMeshSpec> meshes,
    Map<String, Bone> byId,
  ) {
    final ids = <String>{};
    for (final mesh in meshes) {
      if (!ids.add(mesh.id)) {
        throw ArgumentError('Duplicate mesh id "${mesh.id}"');
      }
      if (mesh.vertices.length < 3) {
        throw ArgumentError('Mesh "${mesh.id}" needs at least three vertices');
      }
      if (mesh.boundary.length < 3) {
        throw ArgumentError('Mesh "${mesh.id}" needs a boundary loop');
      }
      for (final index in mesh.boundary) {
        if (index < 0 || index >= mesh.vertices.length) {
          throw ArgumentError(
            'Mesh "${mesh.id}" boundary index $index is out of range',
          );
        }
      }
      for (final vertex in mesh.vertices) {
        if (vertex.influences.isEmpty) {
          throw ArgumentError('Mesh "${mesh.id}" has an unweighted vertex');
        }
        var weight = 0.0;
        for (final influence in vertex.influences) {
          if (!byId.containsKey(influence.boneId)) {
            throw ArgumentError(
              'Mesh "${mesh.id}" references missing bone "${influence.boneId}"',
            );
          }
          if (influence.weight <= 0) {
            throw ArgumentError('Mesh "${mesh.id}" weights must be positive');
          }
          weight += influence.weight;
        }
        if ((weight - 1).abs() > 0.001) {
          throw ArgumentError(
            'Mesh "${mesh.id}" vertex weights must sum to 1 '
            '(got $weight)',
          );
        }
      }
      for (final boneId in mesh.hiddenBoneIds) {
        if (!byId.containsKey(boneId)) {
          throw ArgumentError(
            'Mesh "${mesh.id}" references missing bone "$boneId"',
          );
        }
      }
    }
  }
}

/// A continuous tapered limb surface drawn through a solved joint chain.
///
/// [jointBoneIds] are sampled at each bone's world origin. For a leg that means
/// `upperLeg` (hip), `lowerLeg` (knee), `foot` (ankle). [hiddenBoneIds] names
/// the rigid segment drawables replaced by the ribbon; terminal parts such as
/// shoes or hands stay visible by leaving them out of [hiddenBoneIds].
class LimbRibbonSpec {
  LimbRibbonSpec({
    required this.id,
    required List<String> jointBoneIds,
    required List<double> halfWidths,
    required this.z,
    required this.color,
    List<String> hiddenBoneIds = const [],
    this.outlineColor,
    this.outlineWidth = 0,
    this.samplesPerSegment = 10,
  }) : jointBoneIds = List<String>.unmodifiable(jointBoneIds),
       hiddenBoneIds = List<String>.unmodifiable(hiddenBoneIds),
       halfWidths = List<double>.unmodifiable(halfWidths);

  final String id;
  final List<String> jointBoneIds;
  final List<String> hiddenBoneIds;
  final List<double> halfWidths;
  final int z;
  final int color;
  final int? outlineColor;
  final double outlineWidth;
  final int samplesPerSegment;
}

/// A broad skinned surface made from weighted vertices.
///
/// Each vertex stores one or more [MeshInfluence]s. At render time every
/// influence transforms its local `(x,y)` by that bone's solved world transform;
/// the weighted sum becomes the final deformed vertex. This is linear blend
/// skinning, but kept deliberately small for 2D vector surfaces.
class SkinnedMeshSpec {
  SkinnedMeshSpec({
    required this.id,
    required List<SkinnedMeshVertex> vertices,
    required List<int> boundary,
    required this.z,
    required this.color,
    List<String> hiddenBoneIds = const [],
    this.outlineColor,
    this.outlineWidth = 0,
  }) : vertices = List<SkinnedMeshVertex>.unmodifiable(vertices),
       boundary = List<int>.unmodifiable(boundary),
       hiddenBoneIds = List<String>.unmodifiable(hiddenBoneIds);

  final String id;
  final List<SkinnedMeshVertex> vertices;
  final List<int> boundary;
  final List<String> hiddenBoneIds;
  final int z;
  final int color;
  final int? outlineColor;
  final double outlineWidth;
}

class SkinnedMeshVertex {
  const SkinnedMeshVertex(this.influences);

  final List<MeshInfluence> influences;
}

class MeshInfluence {
  const MeshInfluence({
    required this.boneId,
    required this.x,
    required this.y,
    required this.weight,
  });

  final String boneId;
  final double x;
  final double y;
  final double weight;
}
