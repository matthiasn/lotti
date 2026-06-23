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
      );
      expect(rig.bones.clear, throwsUnsupportedError);
      expect(rig.drawOrder.clear, throwsUnsupportedError);
      expect(rig.topoOrder.clear, throwsUnsupportedError);
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
  });
}
