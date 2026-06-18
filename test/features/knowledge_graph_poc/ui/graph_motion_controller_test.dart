import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_motion_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GraphMotionController controller() {
    final controller = GraphMotionController(vsync: const TestVSync());
    addTearDown(() {
      controller
        ..settle()
        ..dispose();
    });
    return controller;
  }

  void kickFocus(
    GraphMotionController motion, {
    required Offset direction,
    required double distance,
    required double velocity,
    double dampingScale = 1,
  }) {
    motion.kick(
      'focus',
      direction: direction,
      distance: distance,
      velocity: velocity,
      dampingScale: dampingScale,
    );
  }

  void elapseFrame(GraphMotionController motion) {
    motion.elapseForTest(const Duration(milliseconds: 16));
  }

  test('kick offsets a node and damps it back to rest', () {
    final motion = controller();
    kickFocus(
      motion,
      direction: const Offset(1, 0),
      distance: 12,
      velocity: 80,
    );

    expect(motion.hasActiveMotion, isTrue);
    expect(motion.activeNodeCount, 1);
    expect(motion.offsetFor('focus').dx, greaterThan(0));

    for (var i = 0; i < 180; i++) {
      motion.elapseForTest(const Duration(milliseconds: 16));
    }

    expect(motion.hasActiveMotion, isFalse);
    expect(motion.offsetFor('focus'), Offset.zero);
  });

  test('reduceMotion clears active offsets and ignores new kicks', () {
    final motion = controller();
    expect(motion.reduceMotion, isFalse);

    kickFocus(
      motion,
      direction: const Offset(0, 1),
      distance: 10,
      velocity: 60,
    );

    expect(motion.hasActiveMotion, isTrue);

    motion.reduceMotion = true;

    expect(motion.reduceMotion, isTrue);
    expect(motion.hasActiveMotion, isFalse);
    expect(motion.offsetFor('focus'), Offset.zero);

    kickFocus(
      motion,
      direction: const Offset(1, 0),
      distance: 10,
      velocity: 60,
    );

    expect(motion.hasActiveMotion, isFalse);
    expect(motion.offsetFor('focus'), Offset.zero);
  });

  test('large impulses are clamped to bounded visual displacement', () {
    final motion = controller();
    kickFocus(
      motion,
      direction: const Offset(1, 1),
      distance: 500,
      velocity: 5000,
    );

    expect(motion.offsetFor('focus').distance, lessThanOrEqualTo(44));
  });

  testWidgets('ticker-driven frames advance active motion', (tester) async {
    final motion = GraphMotionController(vsync: tester);
    try {
      kickFocus(
        motion,
        direction: const Offset(1, 0),
        distance: 10,
        velocity: 80,
      );
      final initialOffset = motion.offsetFor('focus').dx;

      await tester.pump();
      expect(motion.offsetFor('focus').dx, initialOffset);

      await tester.pump(const Duration(milliseconds: 16));
      expect(motion.offsetFor('focus').dx, isNot(initialOffset));
    } finally {
      motion
        ..settle()
        ..dispose();
    }
  });

  test('invalid kicks are ignored', () {
    final motion = controller();
    kickFocus(
      motion,
      direction: const Offset(1, 0),
      distance: 0,
      velocity: 20,
    );
    kickFocus(
      motion,
      direction: const Offset(1, 0),
      distance: 8,
      velocity: -1,
    );

    expect(motion.hasActiveMotion, isFalse);
    expect(motion.offsetFor('focus'), Offset.zero);
  });

  test('zero direction still produces a deterministic nudge', () {
    final motion = controller();
    kickFocus(
      motion,
      direction: Offset.zero,
      distance: 8,
      velocity: 0,
    );

    expect(motion.offsetFor('focus').distance, closeTo(8, 0.0001));
  });

  test('displayPosition applies the active node offset', () {
    final motion = controller();
    kickFocus(
      motion,
      direction: const Offset(1, 0),
      distance: 8,
      velocity: 0,
    );

    expect(
      motion.displayPosition('focus', const Offset(10, 6)),
      const Offset(18, 6),
    );
    expect(
      motion.displayPosition('other', const Offset(10, 6)),
      const Offset(10, 6),
    );
  });

  test('lower damping keeps a kicked node moving longer', () {
    final normal = controller();
    final emphatic = controller();
    kickFocus(
      normal,
      direction: const Offset(1, 0),
      distance: 12,
      velocity: 100,
    );
    kickFocus(
      emphatic,
      direction: const Offset(1, 0),
      distance: 12,
      velocity: 100,
      dampingScale: 0.45,
    );

    for (var i = 0; i < 45; i++) {
      elapseFrame(normal);
      elapseFrame(emphatic);
    }

    expect(
      emphatic.offsetFor('focus').distance,
      greaterThan(normal.offsetFor('focus').distance),
    );
  });

  test('edge springs pull linked nodes inside the force island', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(100, 0),
          'c': Offset(200, 0),
        },
        edges: const [
          GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
          GraphEdge(fromId: 'b', toId: 'c', kind: GraphEdgeKind.association),
        ],
        activeIds: const ['a', 'b', 'c'],
      )
      ..kick(
        'a',
        direction: const Offset(-1, 0),
        distance: 12,
        velocity: 0,
      );

    elapseFrame(motion);

    expect(motion.offsetFor('a').dx, lessThan(0));
    expect(
      motion.offsetFor('b').dx,
      lessThan(0),
      reason: 'the stretched a-b edge should tug b toward a',
    );
  });

  test('edge-activated bodies survive their first pruning pass', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(100, 0),
        },
        edges: const [
          GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        ],
        activeIds: const ['a', 'b'],
      )
      ..kick(
        'a',
        direction: const Offset(-1, 0),
        distance: 0.02,
        velocity: 0,
      );

    elapseFrame(motion);

    expect(
      motion.offsetFor('b').dx,
      lessThan(0),
      reason: 'a tiny edge force should still accumulate on the new body',
    );
    expect(motion.activeNodeCount, 1);
  });

  test('edge springs fall back to rest direction when nodes overlap', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(10, 0),
        },
        edges: const [
          GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        ],
        activeIds: const ['a', 'b'],
      )
      ..kick(
        'a',
        direction: const Offset(1, 0),
        distance: 10,
        velocity: 0,
      );

    elapseFrame(motion);

    expect(
      motion.offsetFor('b').dx,
      greaterThan(0),
      reason: 'overlapping edge endpoints should still resolve direction',
    );
  });

  test('force island prunes moving nodes outside the active set', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(100, 0),
        },
        edges: const [
          GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        ],
        activeIds: const ['a', 'b'],
      )
      ..kick(
        'a',
        direction: const Offset(1, 0),
        distance: 12,
        velocity: 80,
      );

    expect(motion.hasActiveMotion, isTrue);
    expect(motion.isAnimating, isTrue);

    motion.configureForceIsland(
      restPositions: const {
        'a': Offset.zero,
        'b': Offset(100, 0),
      },
      edges: const [
        GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
      ],
      activeIds: const ['b'],
    );

    expect(motion.hasActiveMotion, isFalse);
    expect(motion.isAnimating, isFalse);
    expect(motion.offsetFor('a'), Offset.zero);
  });

  test('nearby moving bodies separate inside the force island', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(100, 0),
        },
        edges: const [],
        activeIds: const ['a', 'b'],
      )
      ..kick(
        'a',
        direction: const Offset(1, 0),
        distance: 44,
        velocity: 0,
      )
      ..kick(
        'b',
        direction: const Offset(-1, 0),
        distance: 44,
        velocity: 0,
      );

    final before =
        motion.displayPosition('b', const Offset(100, 0)).dx -
        motion.displayPosition('a', Offset.zero).dx;

    elapseFrame(motion);

    final after =
        motion.displayPosition('b', const Offset(100, 0)).dx -
        motion.displayPosition('a', Offset.zero).dx;
    expect(after, greaterThan(before));
  });

  test('moving bodies separate from resting active nodes', () {
    final withStaticCollider = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(50, 0),
        },
        edges: const [],
        activeIds: const ['a', 'b'],
      )
      ..kick(
        'a',
        direction: const Offset(1, 0),
        distance: 44,
        velocity: 0,
      );
    final withoutStaticCollider = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset(50, 0),
        },
        edges: const [],
        activeIds: const ['a'],
      )
      ..kick(
        'a',
        direction: const Offset(1, 0),
        distance: 44,
        velocity: 0,
      );

    elapseFrame(withStaticCollider);
    elapseFrame(withoutStaticCollider);

    expect(
      withStaticCollider.offsetFor('a').dx,
      lessThan(withoutStaticCollider.offsetFor('a').dx),
      reason: 'the resting active node should repel the moving body',
    );
    expect(withStaticCollider.offsetFor('b'), Offset.zero);
  });

  test('overlapping moving bodies separate with a deterministic fallback', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'a': Offset.zero,
          'b': Offset.zero,
        },
        edges: const [],
        activeIds: const ['a', 'b'],
      )
      ..kick(
        'a',
        direction: const Offset(1, 0),
        distance: 10,
        velocity: 0,
      )
      ..kick(
        'b',
        direction: const Offset(1, 0),
        distance: 10,
        velocity: 0,
      );

    elapseFrame(motion);

    expect(
      (motion.displayPosition('b', Offset.zero) -
              motion.displayPosition('a', Offset.zero))
          .distance,
      greaterThan(0),
    );
  });

  test('force island ignores kicks outside its active node set', () {
    final motion = controller()
      ..configureForceIsland(
        restPositions: const {
          'inside': Offset.zero,
          'outside': Offset(100, 0),
        },
        edges: const [
          GraphEdge(
            fromId: 'inside',
            toId: 'outside',
            kind: GraphEdgeKind.association,
          ),
        ],
        activeIds: const ['inside'],
      )
      ..kick(
        'outside',
        direction: const Offset(1, 0),
        distance: 12,
        velocity: 80,
      );

    expect(motion.hasActiveMotion, isFalse);
    expect(motion.offsetFor('outside'), Offset.zero);
  });
}
