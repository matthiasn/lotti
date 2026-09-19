import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    test(
      'a required label escapes OVERLAPPING reserved rects instead of '
      'bouncing between them',
      () {
        // Regression: the push considered one reserved rect at a time and
        // took the locally shortest move, so with rects that overlap — which
        // the legend and minimap do, both inflated by the padding that
        // separates them — a label could be pushed off one and straight onto
        // the other, and the two traded it back and forth until the pass
        // budget ran out, leaving it under a control.
        const viewport = Rect.fromLTWH(0, 0, 400, 400);
        // An L of two overlapping rects in the bottom-left, mirroring the
        // legend sitting above an overlapping minimap.
        const legend = Rect.fromLTWH(0, 250, 240, 90);
        const minimap = Rect.fromLTWH(0, 300, 200, 100);
        const candidate = GraphLabelCandidate(
          id: 'focus',
          center: Offset(110, 300),
          nodeRadius: 16,
          labelSize: Size(150, 26),
          priority: 1000,
          required: true,
        );

        final result = solveGraphLabelLayout(
          candidates: const [candidate],
          viewport: viewport,
          nodeObstacles: const {},
          reservedRects: const [legend, minimap],
        );

        final placement = result['focus'];
        expect(placement, isNotNull);
        expect(
          placement!.rect.overlaps(legend),
          isFalse,
          reason: 'label left sitting on the legend',
        );
        expect(
          placement.rect.overlaps(minimap),
          isFalse,
          reason: 'label left sitting on the minimap',
        );
        expect(viewport.containsRect(placement.rect), isTrue);
      },
    );

    test(
      'a required label that cannot clear the chrome sits in the gap with '
      'the least overlap',
      () {
        // Two full-width strips leave a 10px band — narrower than the 28px
        // label — so no escape clears every reserved rect. The fallback must
        // still pick the in-viewport option overlapping the chrome least
        // (18px of height), not leave it centred on the toolbar.
        const viewport = Rect.fromLTWH(0, 0, 400, 300);
        const toolbar = Rect.fromLTWH(0, 0, 400, 140);
        const footer = Rect.fromLTWH(0, 150, 400, 150);
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
          reservedRects: const [toolbar, footer],
        );

        final rect = result['focus']!.rect;
        double overlap(Rect chrome) {
          final i = rect.intersect(chrome);
          return i.width <= 0 || i.height <= 0 ? 0 : i.width * i.height;
        }

        expect(viewport.containsRect(rect), isTrue);
        expect(overlap(toolbar) + overlap(footer), 220 * 18);
        expect(rect.top, anyOf(122, 140));
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

  group('properties', () {
    const viewport = Rect.fromLTWH(0, 0, 400, 300);
    const toolbar = Rect.fromLTWH(0, 0, 400, 36);
    const minimap = Rect.fromLTWH(300, 220, 100, 80);

    // Nodes anywhere in (and slightly beyond) the viewport, with label sizes
    // from a short word to a long title.
    final node = glados.any.combine5(
      glados.any.intInRange(-20, 420),
      glados.any.intInRange(-20, 320),
      glados.any.intInRange(0, 4),
      glados.any.intInRange(20, 160),
      glados.any.intInRange(0, 5),
      (int x, int y, int priority, int width, int flags) =>
          (x: x, y: y, priority: priority, width: width, required: flags == 0),
    );

    glados.Glados3(
      glados.any.listWithLengthInRange(0, 14, node),
      glados.any.choose([
        const <Rect>[],
        const [toolbar],
        const [toolbar, minimap],
      ]),
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'clean placements stay clear; required labels always land; order-free',
      (nodes, reserved, seed) {
        final candidates = [
          for (final (i, n) in nodes.indexed)
            GraphLabelCandidate(
              id: 'node-$i',
              center: Offset(n.x.toDouble(), n.y.toDouble()),
              nodeRadius: 8,
              labelSize: Size(n.width.toDouble(), 14),
              priority: n.priority,
              required: n.required,
            ),
        ];
        final obstacles = {
          for (final c in candidates)
            c.id: Rect.fromCircle(center: c.center, radius: c.nodeRadius),
        };

        Map<String, GraphLabelPlacement> solve(List<GraphLabelCandidate> cs) =>
            solveGraphLabelLayout(
              candidates: cs,
              viewport: viewport,
              nodeObstacles: obstacles,
              reservedRects: reserved,
            );

        final result = solve(candidates);

        for (final c in candidates.where((c) => c.required)) {
          expect(result.keys, contains(c.id));
        }

        final clean = [
          for (final c in candidates)
            if (!c.required && result[c.id] != null) result[c.id]!,
        ];
        for (final placement in clean) {
          expect(viewport.containsRect(placement.rect), isTrue);
          expect(reserved.any(placement.rect.overlaps), isFalse);
          for (final MapEntry(:key, :value) in obstacles.entries) {
            if (key == placement.id) continue;
            expect(value.overlaps(placement.rect), isFalse, reason: key);
          }
          for (final other in clean) {
            if (other.id == placement.id) continue;
            expect(other.rect.overlaps(placement.rect), isFalse);
          }
        }

        final shuffled = solve([...candidates]..shuffle(Random(seed)));
        expect(shuffled.keys.toSet(), result.keys.toSet());
        for (final id in result.keys) {
          expect(shuffled[id]!.rect, result[id]!.rect);
          expect(shuffled[id]!.anchor, result[id]!.anchor);
        }
      },
      tags: 'glados',
    );
  });
}

extension on Rect {
  bool containsRect(Rect other) =>
      other.left >= left &&
      other.top >= top &&
      other.right <= right &&
      other.bottom <= bottom;
}
