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

  test('places a required label larger than the viewport without throwing', () {
    const viewport = Rect.fromLTWH(20, 30, 80, 40);
    const candidate = GraphLabelCandidate(
      id: 'oversized',
      center: Offset(60, 50),
      nodeRadius: 12,
      labelSize: Size(160, 90),
      priority: 100,
      required: true,
    );

    final result = solveGraphLabelLayout(
      candidates: const [candidate],
      viewport: viewport,
      nodeObstacles: const {},
    );

    expect(result['oversized']!.rect.topLeft, viewport.topLeft);
    expect(result['oversized']!.rect.size, candidate.labelSize);
  });

  group('required labels vs reserved chrome', () {
    test(
      'a required label crowded out of every anchor still keeps off the '
      'reserved chrome',
      () {
        // Regression: the fallback for a required label clamped it into the
        // viewport while ignoring reservedRects, which printed focus/neighbour
        // callouts underneath the floating toolbar.
        //
        // The node sits inside a deep toolbar strip, so its vertical anchors
        // land ON the toolbar (in-viewport, hence never clamped) and its
        // horizontal/diagonal anchors fall outside the viewport — every anchor
        // fails, which is what drives the required-label fallback.
        const viewport = Rect.fromLTWH(0, 0, 400, 300);
        const toolbar = Rect.fromLTWH(0, 0, 400, 140);
        const candidate = GraphLabelCandidate(
          id: 'focus',
          center: Offset(200, 70),
          nodeRadius: 20,
          labelSize: Size(220, 28),
          priority: 1000,
          required: true,
        );

        final result = solveGraphLabelLayout(
          candidates: const [candidate],
          viewport: viewport,
          nodeObstacles: const {},
          reservedRects: const [toolbar],
        );

        final placement = result['focus'];
        expect(placement, isNotNull, reason: 'required label must be placed');
        expect(
          placement!.rect.overlaps(toolbar),
          isFalse,
          reason: 'label overlaps the reserved toolbar strip',
        );
        expect(viewport.contains(placement.rect.topLeft), isTrue);
        expect(
          viewport.containsRect(placement.rect),
          isTrue,
          reason: 'label escaped the viewport',
        );
      },
    );

    test(
      'a crowded required label takes the least-obstructed anchor instead of '
      'the first one',
      () {
        // Every anchor collides with something, so the fallback runs. A heavy
        // obstacle covers the whole lower half (where the default "bottom"
        // anchor lives); a thin one clips only the top anchors. The label must
        // land in the lightly-obstructed band, not squarely on the heavy
        // blocker just because "bottom" is tried first.
        const viewport = Rect.fromLTWH(0, 0, 400, 400);
        const heavy = Rect.fromLTWH(0, 185, 400, 215);
        const light = Rect.fromLTWH(0, 170, 400, 15);
        const candidate = GraphLabelCandidate(
          id: 'crowded',
          center: Offset(200, 200),
          nodeRadius: 20,
          labelSize: Size(100, 20),
          priority: 500,
          required: true,
        );

        final result = solveGraphLabelLayout(
          candidates: const [candidate],
          viewport: viewport,
          nodeObstacles: const {'heavy': heavy, 'light': light},
        );

        final placement = result['crowded'];
        expect(placement, isNotNull);
        expect(
          placement!.rect.overlaps(heavy),
          isFalse,
          reason: 'label was placed on the heavy obstacle',
        );
      },
    );

    test('reserved rects still never displace a non-required label', () {
      // Optional labels are dropped rather than relocated — culling keeps the
      // canvas readable when space runs out.
      const viewport = Rect.fromLTWH(0, 0, 200, 200);
      const candidate = GraphLabelCandidate(
        id: 'optional',
        center: Offset(100, 20),
        nodeRadius: 10,
        labelSize: Size(180, 30),
        priority: 100,
      );

      final result = solveGraphLabelLayout(
        candidates: const [candidate],
        viewport: viewport,
        nodeObstacles: const {},
        reservedRects: const [Rect.fromLTWH(0, 0, 200, 200)],
      );

      expect(result, isEmpty);
    });
  });
}

extension on Rect {
  bool containsRect(Rect other) =>
      other.left >= left &&
      other.top >= top &&
      other.right <= right &&
      other.bottom <= bottom;
}
