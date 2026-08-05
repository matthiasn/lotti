import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_label_layout.dart';

void main() {
  test('label memory replaces and clears the remembered layout', () {
    final memory = GraphLabelLayoutMemory();
    const placement = GraphLabelPlacement(
      id: 'node',
      rect: Rect.fromLTWH(0, 0, 20, 10),
      anchor: GraphLabelAnchor.bottom,
      nodeCenter: Offset.zero,
    );

    memory.remember(const {'node': placement});
    expect(memory.placements['node'], same(placement));
    memory.clear();
    expect(memory.placements, isEmpty);
  });

  test('places priority labels without collisions or reserved overlap', () {
    const candidates = [
      GraphLabelCandidate(
        id: 'focus',
        center: Offset(100, 100),
        nodeRadius: 20,
        labelSize: Size(80, 28),
        priority: 100,
        required: true,
      ),
      GraphLabelCandidate(
        id: 'near',
        center: Offset(140, 100),
        nodeRadius: 16,
        labelSize: Size(76, 28),
        priority: 50,
      ),
      GraphLabelCandidate(
        id: 'low',
        center: Offset(115, 135),
        nodeRadius: 12,
        labelSize: Size(90, 28),
        priority: 10,
      ),
    ];
    final obstacles = <String, Rect>{
      'focus': const Rect.fromLTWH(80, 80, 40, 40),
      'near': const Rect.fromLTWH(124, 84, 32, 32),
      'low': const Rect.fromLTWH(103, 123, 24, 24),
    };
    const reserved = Rect.fromLTWH(0, 0, 70, 70);

    final result = solveGraphLabelLayout(
      candidates: candidates,
      viewport: const Rect.fromLTWH(0, 0, 260, 220),
      nodeObstacles: obstacles,
      reservedRects: const [reserved],
    );

    expect(result, contains('focus'));
    expect(result.values.any((item) => item.rect.overlaps(reserved)), isFalse);
    final rects = result.values.map((item) => item.rect).toList();
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }
  });

  test('keeps a previous valid anchor sticky', () {
    const candidate = GraphLabelCandidate(
      id: 'node',
      center: Offset(100, 100),
      nodeRadius: 12,
      labelSize: Size(60, 24),
      priority: 10,
    );
    const previous = GraphLabelPlacement(
      id: 'node',
      rect: Rect.fromLTWH(112, 88, 60, 24),
      anchor: GraphLabelAnchor.right,
      nodeCenter: Offset(100, 100),
    );

    final result = solveGraphLabelLayout(
      candidates: const [candidate],
      viewport: const Rect.fromLTWH(0, 0, 240, 200),
      nodeObstacles: {
        'node': const Rect.fromLTWH(88, 88, 24, 24),
      },
      previous: const {'node': previous},
    );

    expect(result['node']!.anchor, GraphLabelAnchor.right);
  });

  test('always returns a clamped placement for a required label', () {
    const candidate = GraphLabelCandidate(
      id: 'focus',
      center: Offset(12, 12),
      nodeRadius: 20,
      labelSize: Size(100, 30),
      priority: 100,
      required: true,
    );
    final result = solveGraphLabelLayout(
      candidates: const [candidate],
      viewport: const Rect.fromLTWH(0, 0, 120, 80),
      nodeObstacles: {
        'focus': const Rect.fromLTWH(-8, -8, 40, 40),
      },
    );

    expect(
      const Rect.fromLTWH(0, 0, 120, 80).contains(result['focus']!.rect.center),
      isTrue,
    );
  });
}
