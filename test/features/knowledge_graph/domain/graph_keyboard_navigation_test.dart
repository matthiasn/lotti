import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/knowledge_graph/domain/graph_keyboard_navigation.dart';

void main() {
  const positions = <String, Offset>{
    'focus': Offset.zero,
    'right-near': Offset(40, 4),
    'right-off-axis': Offset(15, 40),
    'left': Offset(-20, 0),
    'down': Offset(0, 30),
  };

  test('prefers the visually aligned candidate in an arrow direction', () {
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'focus',
        direction: const Offset(1, 0),
      ),
      'right-near',
    );
  });

  test('excludes nodes behind the requested direction', () {
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'focus',
        direction: const Offset(-1, 0),
      ),
      'left',
    );
  });

  test('returns null for missing origins and zero directions', () {
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'missing',
        direction: const Offset(1, 0),
      ),
      isNull,
    );
    expect(
      nearestGraphNodeInDirection(
        positions: positions,
        fromId: 'focus',
        direction: Offset.zero,
      ),
      isNull,
    );
  });

  group('properties', () {
    final point = glados.any.combine2(
      glados.any.intInRange(-100, 101),
      glados.any.intInRange(-100, 101),
      (int x, int y) => Offset(x.toDouble(), y.toDouble()),
    );

    glados.Glados2(
      glados.any.listWithLengthInRange(1, 12, point),
      glados.any.choose(const [
        Offset(1, 0),
        Offset(-1, 0),
        Offset(0, 1),
        Offset(0, -1),
        Offset(3, 4),
      ]),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'the target lies strictly ahead, and exists whenever anything does',
      (points, direction) {
        final positions = {
          for (final (i, p) in points.indexed) 'node-$i': p,
        };
        double ahead(Offset p) {
          final delta = p - points.first;
          return delta.dx * direction.dx + delta.dy * direction.dy;
        }

        final result = nearestGraphNodeInDirection(
          positions: positions,
          fromId: 'node-0',
          direction: direction,
        );

        final anyAhead = points.skip(1).any((p) => ahead(p) > 0);
        expect(result != null, anyAhead);
        if (result != null) {
          expect(result, isNot('node-0'));
          expect(ahead(positions[result]!), greaterThan(0));
        }
      },
      tags: 'glados',
    );
  });
}
