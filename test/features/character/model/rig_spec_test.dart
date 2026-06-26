import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

void main() {
  group('RigSpec', () {
    test('topoOrder visits every parent before its children', () {
      // Deliberately list children before parents to prove ordering.
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'hand', parent: 'lower', pivotX: 0, pivotY: 0, z: 2),
          Bone(id: 'lower', parent: 'upper', pivotX: 0, pivotY: 0, z: 1),
          Bone(id: 'upper', parent: null, pivotX: 0, pivotY: 0, z: 0),
        ],
      );
      final order = rig.topoOrder.map((b) => b.id).toList();
      expect(order.indexOf('upper'), lessThan(order.indexOf('lower')));
      expect(order.indexOf('lower'), lessThan(order.indexOf('hand')));
    });

    test('drawOrder sorts by ascending z', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'front', parent: null, pivotX: 0, pivotY: 0, z: 9),
          Bone(id: 'back', parent: 'front', pivotX: 0, pivotY: 0, z: 1),
        ],
      );
      expect(rig.drawOrder.map((b) => b.id).toList(), ['back', 'front']);
    });

    test('bone() looks up by id', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
        ],
      );
      expect(rig.bone('a')?.id, 'a');
      expect(rig.bone('nope'), isNull);
    });

    test('throws when a bone references a missing parent', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: 'ghost', pivotX: 0, pivotY: 0, z: 0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('throws on a duplicate bone id instead of silently dropping one', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'dup', parent: null, pivotX: 0, pivotY: 0, z: 0),
            Bone(id: 'dup', parent: null, pivotX: 1, pivotY: 1, z: 1),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate bone id'),
          ),
        ),
      );
    });

    test('exposes unmodifiable bone collections', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
        ],
        ribbons: [
          LimbRibbonSpec(
            id: 'ribbon',
            jointBoneIds: const ['a', 'a'],
            halfWidths: const [4, 3],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ],
        meshes: [
          SkinnedMeshSpec(
            id: 'mesh',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            z: 0,
            color: 0xFFFFFFFF,
          ),
        ],
      );
      expect(rig.bones.clear, throwsUnsupportedError);
      expect(rig.drawOrder.clear, throwsUnsupportedError);
      expect(rig.topoOrder.clear, throwsUnsupportedError);
      expect(rig.ribbons.clear, throwsUnsupportedError);
      expect(rig.ribbonDrawOrder.clear, throwsUnsupportedError);
      expect(rig.meshes.clear, throwsUnsupportedError);
      expect(rig.meshDrawOrder.clear, throwsUnsupportedError);
      expect(rig.ribbonHiddenBoneIds.clear, throwsUnsupportedError);
      expect(rig.hiddenDrawableBoneIds.clear, throwsUnsupportedError);
    });

    test('throws on a parent cycle instead of overflowing the stack', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: 'b', pivotX: 0, pivotY: 0, z: 0),
            Bone(id: 'b', parent: 'a', pivotX: 0, pivotY: 0, z: 1),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('cycle'),
          ),
        ),
      );
    });

    test('sorts ribbons and exposes hidden bone ids', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'upper', parent: null, pivotX: 0, pivotY: 0, z: 0),
          Bone(id: 'lower', parent: 'upper', pivotX: 0, pivotY: 10, z: 1),
          Bone(id: 'hand', parent: 'lower', pivotX: 0, pivotY: 10, z: 2),
        ],
        ribbons: [
          LimbRibbonSpec(
            id: 'front',
            jointBoneIds: const ['upper', 'lower', 'hand'],
            hiddenBoneIds: const ['upper', 'lower'],
            halfWidths: const [8, 6, 4],
            z: 8,
            color: 0xFFFFFFFF,
          ),
          LimbRibbonSpec(
            id: 'back',
            jointBoneIds: const ['upper', 'lower', 'hand'],
            halfWidths: const [8, 6, 4],
            z: 4,
            color: 0xFFFFFFFF,
          ),
        ],
      );

      expect(rig.ribbonDrawOrder.map((r) => r.id), ['back', 'front']);
      expect(rig.ribbonHiddenBoneIds, {'upper', 'lower'});
    });

    test('sorts skinned meshes and exposes hidden drawable ids', () {
      final rig = RigSpec(
        name: 'r',
        bones: const [
          Bone(id: 'root', parent: null, pivotX: 0, pivotY: 0, z: 0),
          Bone(id: 'child', parent: 'root', pivotX: 0, pivotY: 10, z: 1),
        ],
        meshes: [
          SkinnedMeshSpec(
            id: 'front',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'child', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            hiddenBoneIds: const ['child'],
            z: 8,
            color: 0xFFFFFFFF,
          ),
          SkinnedMeshSpec(
            id: 'back',
            vertices: const [
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'child', x: 1, y: 0, weight: 1),
              ]),
              SkinnedMeshVertex([
                MeshInfluence(boneId: 'root', x: 0, y: 1, weight: 1),
              ]),
            ],
            boundary: const [0, 1, 2],
            z: 4,
            color: 0xFFFFFFFF,
          ),
        ],
      );

      expect(rig.meshDrawOrder.map((m) => m.id), ['back', 'front']);
      expect(rig.hiddenDrawableBoneIds, {'child'});
    });

    test('throws when a ribbon references a missing bone', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          ribbons: [
            LimbRibbonSpec(
              id: 'bad',
              jointBoneIds: const ['a', 'missing'],
              halfWidths: const [5, 4],
              z: 0,
              color: 0xFFFFFFFF,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing bone'),
          ),
        ),
      );
    });

    test('throws when a skinned mesh references a missing bone', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          meshes: [
            SkinnedMeshSpec(
              id: 'bad',
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'missing', x: 1, y: 0, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
              z: 0,
              color: 0xFFFFFFFF,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('missing bone'),
          ),
        ),
      );
    });

    test('throws when skinned mesh vertex weights do not sum to one', () {
      expect(
        () => RigSpec(
          name: 'r',
          bones: const [
            Bone(id: 'a', parent: null, pivotX: 0, pivotY: 0, z: 0),
          ],
          meshes: [
            SkinnedMeshSpec(
              id: 'bad',
              vertices: const [
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 0, weight: 0.5),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 1, y: 0, weight: 1),
                ]),
                SkinnedMeshVertex([
                  MeshInfluence(boneId: 'a', x: 0, y: 1, weight: 1),
                ]),
              ],
              boundary: const [0, 1, 2],
              z: 0,
              color: 0xFFFFFFFF,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('sum to 1'),
          ),
        ),
      );
    });
  });
}
