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
    this.face,
  }) : bones = List<Bone>.unmodifiable(bones),
       _byId = _buildById(bones),
       _drawOrder = List<Bone>.unmodifiable(_sortedByZ(bones)) {
    _topoOrder = List<Bone>.unmodifiable(_computeTopoOrder(this.bones, _byId));
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
  final FaceRig? face;

  final Map<String, Bone> _byId;
  final List<Bone> _drawOrder;
  late final List<Bone> _topoOrder;

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
}
