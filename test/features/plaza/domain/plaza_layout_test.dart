import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

import '../plaza_fixtures.dart';

double _norm(double a) => ((a % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);

void main() {
  final layout = StreetLayout(projectSeed: 1337);
  final tasks = syntheticPlazaTasks();
  final plan = layout.plan(tasks);
  final plaza = frontierPlazaFor(plan)!;
  final last = plan.last!;

  group('frontierPlazaFor', () {
    test('opens past the end of the newest segment, along its heading', () {
      final along =
          (plaza.centerX - last.endX) * math.sin(last.headingRadians) +
          (plaza.centerZ - last.endZ) * math.cos(last.headingRadians);
      final lateral =
          (plaza.centerX - last.endX) * math.cos(last.headingRadians) -
          (plaza.centerZ - last.endZ) * math.sin(last.headingRadians);
      expect(along, closeTo(plazaSetback + plazaDepth / 2, 1e-9));
      // The synthetic street folds, so the plaza steps off the row's axis
      // to the district's outside.
      expect(plaza.lateralOffset.abs(), plazaFoldClearance);
      expect(lateral, closeTo(plaza.lateralOffset, 1e-9));
      expect(plaza.width, plazaWidth);
      expect(plaza.depth, plazaDepth);
    });

    test(
      'home stands in the plaza at eye height looking back down the street',
      () {
        expect(plaza.home.y, eyeHeight);
        expect(
          _norm(plaza.home.yaw),
          closeTo(_norm(last.headingRadians + math.pi), 1e-9),
        );
        final along =
            (plaza.home.x - last.endX) * math.sin(last.headingRadians) +
            (plaza.home.z - last.endZ) * math.cos(last.headingRadians);
        expect(along, closeTo(73, 1e-9));
      },
    );

    test(
      'overview is a map shot: high behind the district, toward the plaza',
      () {
        final o = plaza.overview;
        final again = overviewPoseFor(plan);
        expect(o.x, again.x);
        expect(o.y, again.y);
        expect(o.z, again.z);
        expect(o.y, greaterThan(100));
        expect(o.pitch, closeTo(-math.atan2(0.72, 0.5), 1e-9)); // ~55° down
        expect(_norm(o.yaw), closeTo(_norm(last.headingRadians), 1e-9));
        // Behind the district relative to the plaza: farther from home than
        // any building is.
        final farthest = plan.placements.values
            .map(
              (p) => math.sqrt(
                math.pow(p.x - plaza.home.x, 2) +
                    math.pow(p.z - plaza.home.z, 2),
              ),
            )
            .reduce(math.max);
        final dx = o.x - plaza.home.x;
        final dz = o.z - plaza.home.z;
        expect(math.sqrt(dx * dx + dz * dz), greaterThan(farthest * 0.5));
      },
    );

    test('from home no pylon panel hides another, and the masthead clears '
        'the rear pair', () {
      // Project every panel's four corners from the home eye into yaw and
      // pitch (a 60 degree vertical field of view at a 3:2 frame), then
      // check the angular boxes: no two panels overlap, and the jumbotron
      // screen overlaps none.
      final home = plaza.home;
      (double, double) angles(double x, double y, double z) {
        final dx = x - home.x;
        final dz = z - home.z;
        final yaw = math.atan2(dx, dz) - home.yaw;
        final wrapped = (yaw + math.pi) % (2 * math.pi) - math.pi;
        final ground = math.sqrt(dx * dx + dz * dz);
        return (wrapped, math.atan2(y - home.y, ground) - home.pitch);
      }

      (double, double, double, double) box(BillboardSlot s) {
        final sinF = math.sin(s.facingRadians);
        final cosF = math.cos(s.facingRadians);
        var minYaw = double.infinity;
        var maxYaw = -double.infinity;
        var minPitch = double.infinity;
        var maxPitch = -double.infinity;
        for (final u in [-s.width / 2, s.width / 2]) {
          for (final y in [s.bottom, s.bottom + s.height]) {
            final (yaw, pitch) = angles(
              s.x + cosF * u,
              y,
              s.z - sinF * u,
            );
            minYaw = math.min(minYaw, yaw);
            maxYaw = math.max(maxYaw, yaw);
            minPitch = math.min(minPitch, pitch);
            maxPitch = math.max(maxPitch, pitch);
          }
        }
        return (minYaw, maxYaw, minPitch, maxPitch);
      }

      bool overlaps(
        (double, double, double, double) a,
        (double, double, double, double) b,
      ) => a.$1 < b.$2 && b.$1 < a.$2 && a.$3 < b.$4 && b.$3 < a.$4;

      const halfV = 30 * math.pi / 180;
      final halfH = math.atan(1.5 * math.tan(halfV));
      final panels = [
        for (final p in plaza.pylons) (p.rank, box(p)),
        (99, box(jumbotronSlotFor(plan)!)),
      ];
      for (final (rank, b) in panels) {
        expect(b.$1, greaterThan(-halfH), reason: 'panel $rank left edge');
        expect(b.$2, lessThan(halfH), reason: 'panel $rank right edge');
        // Two degrees of margin at the top: the HUD chrome sits there.
        expect(
          b.$4,
          lessThan(halfV - 2 * math.pi / 180),
          reason: 'panel $rank top edge',
        );
      }
      for (var i = 0; i < panels.length; i++) {
        for (var j = i + 1; j < panels.length; j++) {
          expect(
            overlaps(panels[i].$2, panels[j].$2),
            isFalse,
            reason: 'panels ${panels[i].$1} and ${panels[j].$1} overlap',
          );
        }
      }
    });

    test('four pylons in rank order, each facing the plaza focal point', () {
      expect(plaza.pylons.map((p) => p.rank), [0, 1, 2, 3]);
      for (final pylon in plaza.pylons) {
        expect(pylon.onPylon, isTrue);
        // The focal point (0, 52) in the (shifted) plaza frame.
        final fx =
            last.endX +
            math.sin(last.headingRadians) * 52 +
            math.cos(last.headingRadians) * plaza.lateralOffset;
        final fz =
            last.endZ +
            math.cos(last.headingRadians) * 52 -
            math.sin(last.headingRadians) * plaza.lateralOffset;
        final toFocus = math.atan2(fx - pylon.x, fz - pylon.z);
        expect(_norm(pylon.facingRadians), closeTo(_norm(toFocus), 1e-9));
        expect(pylon.centerY, pylon.bottom + pylon.height / 2);
      }
    });

    test('an empty street has no plaza', () {
      expect(frontierPlazaFor(layout.plan([])), isNull);
    });

    test('a straight street keeps its plaza on the axis', () {
      final straight = layout.plan([
        for (var i = 0; i < 3; i++)
          PlazaTask(
            id: 's$i',
            createdAt: DateTime.utc(2026, 3, 2).add(Duration(days: 7 * i)),
            title: 'Task $i',
            state: PlazaTaskState.open,
            progress: 0,
            checklistItems: 0,
            linkedTaskIds: const [],
            categoryColor: 0,
          ),
      ]);
      expect(frontierPlazaFor(straight)!.lateralOffset, 0);
    });

    test('appending a task to the newest week does not move the plaza', () {
      final newest = tasks
          .map((t) => t.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final grown = [
        ...tasks,
        PlazaTask(
          id: 'late',
          createdAt: newest.add(const Duration(hours: 1)),
          title: 'late',
          state: PlazaTaskState.open,
          progress: 0,
          checklistItems: 0,
          linkedTaskIds: const [],
          categoryColor: 0,
        ),
      ];
      final again = frontierPlazaFor(layout.plan(grown, epoch: plan.epoch))!;
      expect(again.home.x, closeTo(plaza.home.x, 1e-9));
      expect(again.home.z, closeTo(plaza.home.z, 1e-9));
    });
  });

  group('mounts', () {
    test('the newest building on each side carries a screen and a ticker', () {
      final mounts = plazaMounts(plan);
      expect(mounts.map((m) => m.side).toSet(), PlotSide.values.toSet());
      for (final m in mounts) {
        final sameSide = plan.placements.values.where((p) => p.side == m.side);
        // Farthest along the last segment's heading.
        double along(PlotPlacement p) =>
            (p.x - last.startX) * math.sin(last.headingRadians) +
            (p.z - last.startZ) * math.cos(last.headingRadians);
        expect(along(m), sameSide.map(along).reduce(math.max));
      }
      final slots = mountedSlotsFor(plan);
      expect(slots.screens.map((s) => s.rank), [4, 5]);
      expect(slots.tickers, hasLength(2));
      for (final s in slots.screens) {
        expect(s.onPylon, isFalse);
        expect(
          _norm(s.facingRadians),
          closeTo(_norm(last.headingRadians), 1e-9),
        );
      }
    });

    test('a roofline ticker sits just above the facade', () {
      final hero = plan.placements.values.first;
      final ticker = rooflineTickerFor(hero, fast: true);
      expect(ticker.bottom, hero.height + 0.2);
      expect(ticker.width, hero.width);
      expect(
        _norm(ticker.facingRadians),
        closeTo(_norm(hero.facingRadians), 1e-9),
      );
    });
  });

  group('taskPoseFor', () {
    test('stands on the road facing the facade, tilted to its centre', () {
      final p = plan.placements.values.first;
      final pose = taskPoseFor(p);
      final facadeX = p.x + math.sin(p.facingRadians) * p.depth / 2;
      final facadeZ = p.z + math.cos(p.facingRadians) * p.depth / 2;
      final d = math.sqrt(
        math.pow(pose.x - facadeX, 2) + math.pow(pose.z - facadeZ, 2),
      );
      expect(d, greaterThanOrEqualTo(16));
      expect(_norm(pose.yaw), closeTo(_norm(p.facingRadians + math.pi), 1e-9));
      expect(pose.y, eyeHeight);
      expect(
        pose.pitch,
        closeTo(
          math.min(
            math.atan2((p.height + roofSignageHeight) / 2 - eyeHeight, d),
            maxTaskPitch,
          ),
          1e-9,
        ),
      );
    });

    test('never pitches past the cap: a landmark keeps its street', () {
      const tall = PlotPlacement(
        taskId: 'x',
        bucketIndex: 0,
        side: PlotSide.left,
        x: 0,
        z: 0,
        facingRadians: 0,
        width: 6,
        depth: 6,
        height: 32,
      );
      expect(taskPoseFor(tall).pitch, closeTo(maxTaskPitch, 1e-9));
      expect(
        math.atan2((32 + roofSignageHeight) / 2 - eyeHeight, maxTaskStandOff),
        greaterThan(maxTaskPitch),
      );
    });

    test('backs off for wide and tall facades', () {
      PlotPlacement place(double width, double height) => PlotPlacement(
        taskId: 'x',
        bucketIndex: 0,
        side: PlotSide.left,
        x: 0,
        z: 0,
        facingRadians: 0,
        width: width,
        depth: 6,
        height: height,
      );
      expect(taskPoseFor(place(4, 4)).z, closeTo(3 + 16, 1e-9));
      expect(taskPoseFor(place(15, 4)).z, closeTo(3 + 15 * 1.2, 1e-9));
      expect(
        taskPoseFor(place(4, 16)).z,
        closeTo(3 + (16 + roofSignageHeight + 3) * 0.9, 1e-9),
      );
      // A landmark is framed by pitching up, never from the next row.
      expect(taskPoseFor(place(4, 32)).z, closeTo(3 + maxTaskStandOff, 1e-9));
    });
  });

  group('beaconsFor', () {
    final now = syntheticNow(tasks);
    final anomalyList = anomalies(attentionForAll(tasks, now));
    final beacons = beaconsFor(
      plan,
      plaza,
      anomalyList,
      projectLabel: 'Test',
      weekLabel: (b) => weekLabelFor(plan.epoch, b),
    );

    test('home first, then blocks newest-first, corners, then attention', () {
      expect(beacons.first.kind, BeaconKind.home);
      expect(beacons.first.pose, plaza.home);
      final blocks = beacons.where((b) => b.kind == BeaconKind.block).toList();
      expect(blocks.length, plan.segments.where((s) => !s.isGap).length);
      final indices = blocks
          .map((b) => int.parse(b.id.split('-').last))
          .toList();
      expect(indices, [...indices]..sort((a, b) => b.compareTo(a)));
      final corners = beacons.where((b) => b.kind == BeaconKind.corner);
      expect(corners.length, plan.segments.where((s) => s.isConnector).length);
      final attention = beacons
          .where((b) => b.kind == BeaconKind.attention)
          .toList();
      expect(attention.map((b) => b.taskId), anomalyList.map((a) => a.task.id));
      expect(attention.every((b) => b.visibleRange == 450), isTrue);
      expect(blocks.every((b) => b.visibleRange == 320), isTrue);
    });

    test('a block beacon stands at the block start looking down it', () {
      final block = beacons.firstWhere((b) => b.kind == BeaconKind.block);
      final index = int.parse(block.id.split('-').last);
      final segment = plan.segments.firstWhere(
        (s) => s.bucketIndex == index && !s.isConnector,
      );
      expect(
        block.pose.x,
        closeTo(
          segment.startX + math.sin(segment.headingRadians) * blockBeaconInset,
          1e-9,
        ),
      );
      expect(block.pose.yaw, segment.headingRadians);
      expect(block.markerY, 1.6);
      expect(block.label, endsWith('— block'));
    });

    test('an attention beacon marks the task pose', () {
      final att = beacons.firstWhere((b) => b.kind == BeaconKind.attention);
      final pose = taskPoseFor(plan.placements[att.taskId]!);
      expect(att.pose.x, pose.x);
      expect(att.markerX, pose.x);
      expect(att.markerZ, pose.z);
    });

    test('ids are unique', () {
      expect(beacons.map((b) => b.id).toSet().length, beacons.length);
    });
  });

  test('weekLabelFor', () {
    expect(weekLabelFor(DateTime.utc(2026, 6, 8), 0), 'W1 · Jun 8');
    expect(weekLabelFor(DateTime.utc(2026, 6, 8), 5), 'W6 · Jul 13');
  });

  test('CameraPose distance and toString', () {
    const a = CameraPose(x: 0, y: 0, z: 0, yaw: 0);
    const b = CameraPose(x: 3, y: 4, z: 0, yaw: 1, pitch: 0.5);
    expect(a.distanceTo(b), 5);
    expect(b.toString(), contains('yaw 1.00'));
  });

  group('roofBillboardsFor', () {
    final now = syntheticNow(tasks);
    final anomalyList = anomalies(attentionForAll(tasks, now));
    final roofs = roofBillboardsFor(plan, anomalyList);

    test('one panel per anomaly up to the cap, most urgent first', () {
      expect(roofs.length, math.min(12, anomalyList.length));
      expect(roofs.map((s) => s.rank), List.generate(roofs.length, (i) => i));
      expect(roofs.every((s) => s.mount == BillboardMount.roof), isTrue);
      expect(roofBillboardsFor(plan, anomalyList, cap: 2), hasLength(2));
    });

    test('sits above its own building, facing the street', () {
      for (final (i, slot) in roofs.indexed) {
        final p = plan.placements[anomalyList[i].task.id]!;
        expect(slot.bottom, p.height + 0.5);
        expect(slot.width, closeTo(p.width * 0.95, 1e-9));
        expect(slot.facingRadians, p.facingRadians);
        final dx = slot.x - p.x;
        final dz = slot.z - p.z;
        expect(
          dx * math.sin(p.facingRadians) + dz * math.cos(p.facingRadians),
          closeTo(p.depth / 2 - 0.4, 1e-9),
        );
      }
    });

    test('size and agitation follow the score', () {
      final scores = roofs.map((s) => anomalyList[s.rank].score).toList();
      for (var i = 1; i < roofs.length; i++) {
        if (scores[i] < scores[i - 1]) {
          expect(roofs[i].height, lessThanOrEqualTo(roofs[i - 1].height));
          expect(
            roofs[i].pulseSeconds,
            greaterThanOrEqualTo(roofs[i - 1].pulseSeconds),
          );
        }
      }
      for (final s in roofs) {
        expect(s.height, inInclusiveRange(3, 6));
        expect(s.pulseSeconds, inInclusiveRange(1.2, 3));
      }
    });
  });

  group('street furniture', () {
    test("banners hang on the tall buildings' row-facing end walls", () {
      final banners = bannersFor(plan);
      final tall = plan.placements.values.where((p) => p.height >= 12);
      expect(
        banners.map((b) => b.taskId).toSet(),
        tall.map((p) => p.taskId).toSet(),
      );
      for (final b in banners) {
        final p = plan.placements[b.taskId]!;
        final segment = plan.segments.firstWhere(
          (s) => s.bucketIndex == p.bucketIndex && !s.isConnector,
        );
        expect(b.facingRadians, segment.headingRadians);
        expect(b.height, closeTo(p.height * 0.7, 1e-9));
        expect(b.bottom + b.height, lessThan(p.height));
        expect(b.centerY, closeTo(b.bottom + b.height / 2, 1e-9));
        expect(b.width, lessThanOrEqualTo(1.8));
      }
      expect(bannersFor(plan, minHeight: 1000), isEmpty);
    });

    test(
      'lamp posts stand on the pavement in the gaps, never in front of a facade',
      () {
        final posts = lampPostsFor(plan, roadWidth: 18);
        expect(posts, isNotEmpty);
        for (final segment in plan.segments.where((s) => !s.isGap)) {
          final sinH = math.sin(segment.headingRadians);
          final cosH = math.cos(segment.headingRadians);
          double along(double x, double z) =>
              (x - segment.startX) * sinH + (z - segment.startZ) * cosH;
          double lateral(double x, double z) =>
              (x - segment.startX) * cosH - (z - segment.startZ) * sinH;
          final inBlock = posts.where((p) {
            final a = along(p.$1, p.$2);
            return a >= 0 &&
                a <= segment.length &&
                lateral(p.$1, p.$2).abs() < 9;
          });
          // The block-head post stands on the left kerb only: the right
          // kerb is where roof billboards and pylons show from the block
          // pose, and a post across a headline is worse than a dark kerb.
          final heads = inBlock.where(
            (p) => (along(p.$1, p.$2) - blockHeadAlong).abs() < 1e-9,
          );
          expect(heads, hasLength(1), reason: 'bucket ${segment.bucketIndex}');
          expect(lateral(heads.single.$1, heads.single.$2), lessThan(0));
          for (final (x, z) in inBlock) {
            expect(lateral(x, z).abs(), closeTo(9 - 1.6, 1e-9));
            final side = lateral(x, z) < 0 ? PlotSide.left : PlotSide.right;
            for (final plot in plan.placements.values.where(
              (q) => q.bucketIndex == segment.bucketIndex && q.side == side,
            )) {
              final pa = along(plot.x, plot.z);
              expect(
                (along(x, z) - pa).abs(),
                greaterThanOrEqualTo(plot.width / 2 - 1e-9),
                reason: 'a lamp stands in front of ${plot.taskId}',
              );
            }
          }
        }
      },
    );

    test(
      'week signs hang at each block head on the left kerb, facing in',
      () {
        final signs = weekSignsFor(plan, roadWidth: 18);
        final built = plan.segments.where((s) => !s.isGap).toList();
        expect(signs.length, built.length);
        for (final (i, sign) in signs.indexed) {
          final segment = built[i];
          expect(sign.$1, segment.bucketIndex);
          expect(
            _norm(sign.$4),
            closeTo(_norm(segment.headingRadians + math.pi), 1e-9),
          );
          final dx = sign.$2 - segment.startX;
          final dz = sign.$3 - segment.startZ;
          final along =
              dx * math.sin(segment.headingRadians) +
              dz * math.cos(segment.headingRadians);
          expect(along, closeTo(blockHeadAlong, 1e-9));
          // Left kerb: the road's right-hand normal points the other way.
          final lateral =
              dx * math.cos(segment.headingRadians) -
              dz * math.sin(segment.headingRadians);
          expect(lateral, closeTo(-(9 - kerbFixtureInset), 1e-9));
        }
      },
    );

    test('a tall landmark stands off no farther than the street allows', () {
      final tall = plan.placements.values.reduce(
        (a, b) => a.height >= b.height ? a : b,
      );
      final short = plan.placements.values.reduce(
        (a, b) => a.height <= b.height ? a : b,
      );
      // Unclamped, the landmark would want more than the street is wide.
      expect((tall.height + roofSignageHeight + 3) * 0.9, greaterThan(26));
      expect(taskStandOffFor(tall), maxTaskStandOff);
      expect(taskStandOffFor(short), lessThan(taskStandOffFor(tall)));
      final pose = taskPoseFor(tall);
      final dx = pose.x - tall.x;
      final dz = pose.z - tall.z;
      expect(
        math.sqrt(dx * dx + dz * dz),
        closeTo(taskStandOffFor(tall) + tall.depth / 2, 1e-9),
      );
    });

    test('the gantry spans the street mouth facing home', () {
      final g = gantryTickerFor(plan, roadWidth: 18)!;
      expect(g.width, 22);
      expect(g.facingRadians, last.headingRadians);
      final along =
          (g.x - last.endX) * math.sin(last.headingRadians) +
          (g.z - last.endZ) * math.cos(last.headingRadians);
      expect(along, closeTo(3, 1e-9));
      expect(g.bottom, greaterThan(9));
      expect(gantryTickerFor(layout.plan([]), roadWidth: 18), isNull);
    });

    test('the jumbotron stands beside the mouth, outside, facing home', () {
      final j = jumbotronSlotFor(plan)!;
      expect(j.mount, BillboardMount.jumbotron);
      // In the plaza's frame: just past the street end, clear of the
      // plaza's edge on the district's outside (the side the plaza was
      // shifted toward).
      final offset = plaza.lateralOffset;
      final sinH = math.sin(last.headingRadians);
      final cosH = math.cos(last.headingRadians);
      final along = (j.x - last.endX) * sinH + (j.z - last.endZ) * cosH;
      final lateral =
          (j.x - last.endX) * cosH - (j.z - last.endZ) * sinH - offset;
      expect(along, closeTo(jumbotronAlong, 1e-9));
      expect(
        lateral,
        closeTo(
          offset.sign * (plazaWidth / 2 + jumbotronLateralClearance),
          1e-9,
        ),
      );
      expect(offset, isNot(0));
      // Turned to face home, and high enough to clear the near pylons.
      expect(
        _norm(j.facingRadians),
        closeTo(
          _norm(math.atan2(plaza.home.x - j.x, plaza.home.z - j.z)),
          1e-9,
        ),
      );
      expect(j.bottom, jumbotronBottom);
      expect(
        j.bottom,
        greaterThan(
          plaza.pylons.map((p) => p.bottom + p.height).reduce(math.max),
        ),
      );
      expect(j.width, 30);
      expect(jumbotronSlotFor(layout.plan([])), isNull);
    });

    test('on a straight street the jumbotron takes the left side', () {
      final straight = layout.plan([
        for (var i = 0; i < 3; i++)
          PlazaTask(
            id: 's$i',
            createdAt: DateTime.utc(2026, 3, 2).add(Duration(days: 7 * i)),
            title: 'Task $i',
            state: PlazaTaskState.open,
            progress: 0,
            checklistItems: 0,
            linkedTaskIds: const [],
            categoryColor: 0,
          ),
      ]);
      final j = jumbotronSlotFor(straight)!;
      final end = straight.last!;
      final lateral =
          (j.x - end.endX) * math.cos(end.headingRadians) -
          (j.z - end.endZ) * math.sin(end.headingRadians);
      expect(
        lateral,
        closeTo(-(plazaWidth / 2 + jumbotronLateralClearance), 1e-9),
      );
    });

    test('spires go on the two tallest buildings, tallest first', () {
      final spires = spiresFor(plan);
      expect(spires, hasLength(2));
      expect(spires[0].height, greaterThanOrEqualTo(spires[1].height));
      final tallest = plan.placements.values
          .map((p) => p.height)
          .reduce(math.max);
      expect(spires[0].height, tallest);
    });
  });
}
