import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_generator.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

double _norm(double a) => ((a % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);

void main() {
  final layout = StreetLayout(projectSeed: 1337);
  final tasks = generatePlazaTasks(preset: PlazaPreset.medium);
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
      expect(lateral, closeTo(0, 1e-9));
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
        expect(along, closeTo(56, 1e-9));
      },
    );

    test('overview is high, farther back, pitched down the street', () {
      expect(plaza.overview.y, 140);
      expect(plaza.overview.pitch, lessThan(0));
      expect(plaza.overview.distanceTo(plaza.home), greaterThan(140));
      expect(_norm(plaza.overview.yaw), closeTo(_norm(plaza.home.yaw), 1e-9));
    });

    test('four pylons in rank order, each facing the plaza focal point', () {
      expect(plaza.pylons.map((p) => p.rank), [0, 1, 2, 3]);
      for (final pylon in plaza.pylons) {
        expect(pylon.onPylon, isTrue);
        // The focal point (0, 48) in the plaza frame.
        final fx = last.endX + math.sin(last.headingRadians) * 48;
        final fz = last.endZ + math.cos(last.headingRadians) * 48;
        final toFocus = math.atan2(fx - pylon.x, fz - pylon.z);
        expect(_norm(pylon.facingRadians), closeTo(_norm(toFocus), 1e-9));
        expect(pylon.centerY, pylon.bottom + pylon.height / 2);
      }
    });

    test('an empty street has no plaza', () {
      expect(frontierPlazaFor(layout.plan([])), isNull);
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
      expect(d, greaterThanOrEqualTo(13));
      expect(_norm(pose.yaw), closeTo(_norm(p.facingRadians + math.pi), 1e-9));
      expect(pose.y, eyeHeight);
      expect(
        pose.pitch,
        closeTo(math.atan2(p.height / 2 - eyeHeight, d), 1e-9),
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
      expect(taskPoseFor(place(4, 4)).z, closeTo(3 + 13, 1e-9));
      expect(taskPoseFor(place(15, 4)).z, closeTo(3 + 16.5, 1e-9));
      expect(
        taskPoseFor(place(4, 14)).z,
        closeTo(3 + (14 - eyeHeight) * 1.9, 1e-9),
      );
    });
  });

  group('beaconsFor', () {
    final now = plazaNowFor(tasks);
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
      expect(attention.every((b) => b.visibleRange == 400), isTrue);
      expect(blocks.every((b) => b.visibleRange == 140), isTrue);
    });

    test('a block beacon stands mid-segment looking along the road', () {
      final block = beacons.firstWhere((b) => b.kind == BeaconKind.block);
      final index = int.parse(block.id.split('-').last);
      final segment = plan.segments.firstWhere(
        (s) => s.bucketIndex == index && !s.isConnector,
      );
      expect(
        block.pose.x,
        closeTo(
          segment.startX +
              math.sin(segment.headingRadians) * segment.length / 2,
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
}
