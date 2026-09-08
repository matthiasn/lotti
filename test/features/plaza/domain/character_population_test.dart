import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

import '../plaza_fixtures.dart';

CharacterCompanion _conversationActor({
  String id = 'left',
  double side = -1.3,
  double delay = 0,
  double heading = 0,
  double phase = 0,
}) {
  final loop = CharacterLoop(
    x: 0,
    z: 0,
    heading: heading,
    radius: 5,
    halfStraight: 100,
  );
  return CharacterCompanion(
    id: id,
    region: 'test',
    gait: CharacterGait(loop: loop.translated(side), scale: 1, phase: phase),
    partnerLoop: loop.translated(-side),
    responseDelay: delay,
  );
}

List<({double start, double firstClosed, double lastClosed, double end})>
_blinkEvents(CharacterCompanion actor) {
  final events =
      <({double start, double firstClosed, double lastClosed, double end})>[];
  double? start;
  var firstClosed = 0.0;
  var lastClosed = 0.0;
  for (var millis = 0; millis <= 35000; millis++) {
    final t = millis / 1000;
    final closure = actor.blinkAt(t);
    if (closure > 0 && start == null) {
      start = t;
      firstClosed = 0;
      lastClosed = 0;
    }
    if (closure == 1) {
      if (firstClosed == 0) firstClosed = t;
      lastClosed = t;
    }
    if (closure == 0 && start != null) {
      events.add((
        start: start,
        firstClosed: firstClosed,
        lastClosed: lastClosed,
        end: t,
      ));
      start = null;
    }
  }
  return events;
}

void main() {
  List<CharacterCompanion> population(PlazaWorld world) =>
      CharacterPopulation.forWorld(
        plan: world.plan,
        plaza: world.plaza,
        solids: world.solids,
        roadWidth: world.layout.roadWidth,
      );

  for (final folded in [false, true]) {
    test(
      'walkers inhabit every district of the ${folded ? 'folded' : 'demo'} world',
      () {
        final tasks = folded
            ? syntheticPlazaTasks()
            : plazaTasksFromDemoWorld(now: manualDemoNow);
        PlazaWorld world(List<PlazaTask> tasks) => PlazaWorld(
          tasks: tasks,
          now: manualDemoNow,
          projectLabel: 'Project Waddle',
          layout: StreetLayout(projectSeed: 1337, roadWidth: 25),
        );
        final district = world(tasks);
        final cast = population(district);
        if (!folded) {
          expect(cast, hasLength(78));
        }
        expect(cast.where((c) => c.region == 'plaza'), hasLength(12));
        expect(cast.any((c) => c.partnerLoop != null), isTrue);
        expect(cast.any((c) => c.partnerLoop == null), isTrue);
        expect(cast.map((c) => c.build).toSet(), CharacterBuild.values.toSet());
        for (final segment in district.plan.segments.where(
          (s) => s.length >= 30,
        )) {
          final region = 'street-${segment.bucketIndex}-${segment.isConnector}';
          expect(
            cast.where((c) => c.region == region),
            isNotEmpty,
            reason: region,
          );
        }
        // Check the denser cast through a complete lap of its longest route,
        // including companions within the same group and neighbouring groups.
        final lap = cast
            .map((c) => c.gait.loop.length / c.gait.loop.pace)
            .reduce(math.max);
        var closestSquared = double.infinity;
        var closestPair = '';
        for (var sample = 0; sample < 600; sample++) {
          final poses = [
            for (final actor in cast) actor.positionAt(sample / 600 * lap),
          ];
          for (var i = 0; i < poses.length; i++) {
            for (var j = i + 1; j < poses.length; j++) {
              final dx = poses[i].x - poses[j].x;
              final dz = poses[i].z - poses[j].z;
              final squared = dx * dx + dz * dz;
              if (squared < closestSquared) {
                closestSquared = squared;
                closestPair = '${cast[i].id} / ${cast[j].id} at sample $sample';
              }
            }
          }
        }
        expect(closestSquared, greaterThan(2.2 * 2.2), reason: closestPair);
        final reordered = population(world(tasks.reversed.toList()));
        expect(reordered.map((c) => c.id), cast.map((c) => c.id));
        for (var i = 0; i < cast.length; i++) {
          expect(reordered[i].positionAt(43).x, cast[i].positionAt(43).x);
          expect(reordered[i].positionAt(43).z, cast[i].positionAt(43).z);
          expect(reordered[i].build, cast[i].build);
        }
        for (final actor in cast) {
          for (var sample = 0; sample < 150; sample++) {
            final pose = actor.positionAt(
              sample / 150 * actor.gait.loop.length / actor.gait.loop.pace,
            );
            for (final solid in district.solids) {
              if (solid.bottom >= CharacterLoop.height || solid.top <= 0) {
                continue;
              }
              expect(
                solid.footprint.contains(
                  pose.x,
                  pose.z,
                  clearance: CharacterLoop.clearance,
                ),
                isFalse,
                reason: actor.id,
              );
            }
            if (actor.region != 'plaza') {
              final segment = district.plan.segments.singleWhere(
                (s) =>
                    actor.region == 'street-${s.bucketIndex}-${s.isConnector}',
              );
              final (x, z) = worldToFrame(
                segment.startX,
                segment.startZ,
                segment.headingRadians,
                pose.x,
                pose.z,
              );
              expect(
                x.abs() + CharacterLoop.clearance,
                lessThan(district.layout.roadWidth / 2 - 3 - 0.175),
              );
              expect(
                z,
                inInclusiveRange(
                  CharacterLoop.clearance,
                  segment.length - CharacterLoop.clearance,
                ),
              );
              expect(actor.gait.loop.ground, CharacterPopulation.streetGround);
            }
          }
        }
      },
    );
  }

  test('independent crowds cannot collide at folded street junctions', () {
    final plan = StreetPlan(
      epoch: DateTime.utc(2026),
      segments: const [
        RoadSegment(
          bucketIndex: 3,
          startX: 0,
          startZ: 120,
          headingRadians: 0,
          length: 40,
          isGap: false,
        ),
        RoadSegment(
          bucketIndex: 3,
          startX: 0,
          startZ: 160,
          headingRadians: -math.pi / 2,
          length: 44,
          isGap: false,
          isConnector: true,
        ),
      ],
      placements: const {},
    );
    final cast = CharacterPopulation.forWorld(
      plan: plan,
      plaza: null,
      solids: const [],
      roadWidth: 25,
    );
    expect(cast.map((c) => c.region).toSet(), hasLength(2));
    for (var frame = 0; frame < 10000; frame++) {
      final poses = [for (final actor in cast) actor.positionAt(frame / 10)];
      for (var i = 0; i < poses.length; i++) {
        for (var j = i + 1; j < poses.length; j++) {
          final a = poses[i];
          final b = poses[j];
          expect(
            math.pow(a.x - b.x, 2) + math.pow(a.z - b.z, 2),
            greaterThan(2.2 * 2.2),
            reason: '${cast[i].id} meets ${cast[j].id} at ${frame / 10}s',
          );
        }
      }
    }
  });

  test('empty, narrow and obstructed roads do not spawn unsafe walkers', () {
    final plan = StreetPlan(
      epoch: DateTime.utc(2026),
      segments: const [
        RoadSegment(
          bucketIndex: 0,
          startX: 0,
          startZ: 0,
          headingRadians: 0,
          length: 40,
          isGap: false,
        ),
      ],
      placements: const {},
    );
    expect(
      CharacterPopulation.forWorld(
        plan: plan,
        plaza: null,
        solids: const [],
        roadWidth: 12,
      ),
      isEmpty,
    );
    const blocked = Solid(
      footprint: Footprint(
        x: 0,
        z: 20,
        facingRadians: 0,
        width: 25,
        depth: 40,
      ),
      top: 3,
    );
    expect(
      CharacterPopulation.forWorld(
        plan: plan,
        plaza: null,
        solids: [blocked],
        roadWidth: 25,
      ),
      isEmpty,
    );
    expect(
      CharacterPopulation.forWorld(
        plan: StreetPlan(
          epoch: DateTime.utc(2026),
          segments: const [],
          placements: const {},
        ),
        plaza: null,
        solids: const [],
        roadWidth: 25,
      ),
      isEmpty,
    );
  });

  test(
    'partners keep formation and independent footsteps through full laps',
    () {
      final world = PlazaWorld(
        tasks: plazaTasksFromDemoWorld(now: manualDemoNow),
        now: manualDemoNow,
        projectLabel: 'Project Waddle',
        layout: StreetLayout(projectSeed: 1337, roadWidth: 25),
      );
      final cast = population(world);
      for (final actor in cast.where((c) => c.partnerLoop != null)) {
        for (var frame = 0; frame < 240; frame++) {
          final t = frame / 240 * actor.gait.loop.length / actor.gait.loop.pace;
          final a = actor.positionAt(t);
          final b = actor.partnerLoop!.at(t, phase: actor.gait.phase);
          expect(
            math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.z - b.z, 2)),
            closeTo(CharacterPopulation.pairSeparation, 1e-9),
          );
          final next = actor.positionAt(t + 0.001);
          expect(
            math.sqrt(math.pow(a.x - next.x, 2) + math.pow(a.z - next.z, 2)),
            closeTo(actor.gait.loop.pace * 0.001, 1e-6),
          );
        }
      }
      final a = cast.first;
      final b = cast[1];
      expect(a.gait.phase, b.gait.phase);
      expect(a.gait.at(5).cycle, isNot(b.gait.at(5).cycle));
    },
  );

  test(
    'conversation is occasional, inward, smoothly held and answered later',
    () {
      final left = _conversationActor();
      final right = _conversationActor(id: 'right', side: 1.3, delay: 0.55);
      expect(left.attentionAt(0.5).yaw, closeTo(0.48, 1e-9));
      expect(right.attentionAt(0.4).yaw, 0);
      expect(right.attentionAt(1.05).yaw, closeTo(-0.48, 1e-9));
      expect(left.attentionAt(5).yaw, 0);
      var glancing = 0;
      for (var frame = 0; frame < 900; frame++) {
        final t = frame / 100;
        final pose = left.attentionAt(t);
        if (pose.yaw > 0.01) glancing++;
        expect(pose.yaw, inInclusiveRange(0, 0.48));
        expect(
          (left.attentionAt(t + 0.001).yaw - pose.yaw).abs(),
          lessThan(0.004),
        );
      }
      expect(glancing / 900, inInclusiveRange(0.12, 0.25));
      final solo = CharacterCompanion(
        id: 'solo',
        region: 'test',
        gait: left.gait,
      );
      expect(solo.attentionAt(0.4), (yaw: 0.0, nod: 0.0, eyeYaw: 0.0));
    },
  );

  test('eyes acquire attention before the head and lead its return', () {
    final actor = _conversationActor();
    final lead = actor.attentionAt(0.06);
    expect(lead.eyeYaw, greaterThan(0.1));
    expect(lead.yaw, 0);
    final held = actor.attentionAt(0.6);
    expect(held.yaw, closeTo(0.48, 1e-9));
    expect(held.yaw + held.eyeYaw, closeTo(0.58, 1e-9));
    expect(actor.attentionAt(1).eyeYaw, closeTo(held.eyeYaw, 1e-9));
    final returning = actor.attentionAt(1.37);
    expect(returning.yaw, closeTo(held.yaw, 1e-9));
    expect(returning.eyeYaw, lessThan(-0.05));
    expect(actor.attentionAt(2), (yaw: 0.0, nod: 0.0, eyeYaw: 0.0));
  });

  test('head and eyes face partners in either street direction', () {
    for (final heading in [0.0, math.pi]) {
      for (final phase in [0.0, 0.5]) {
        for (final side in [-1.3, 1.3]) {
          final actor = _conversationActor(
            heading: heading,
            phase: phase,
            side: side,
          );
          final sign = -side.sign * (phase == 0 ? 1 : -1);
          final pose = actor.attentionAt(0.6);
          expect(pose.yaw * sign, closeTo(0.48, 1e-9));
          expect((pose.yaw + pose.eyeYaw) * sign, closeTo(0.58, 1e-9));
        }
      }
    }
    const loop = CharacterLoop(
      x: 0,
      z: 0,
      heading: 0,
      radius: 5,
      halfStraight: 3,
    );
    final capDistance = 2 * loop.halfStraight + math.pi / 2 * loop.radius;
    final turning = CharacterCompanion(
      id: 'turning',
      region: 'test',
      gait: CharacterGait(
        loop: loop,
        scale: 1,
        phase: (capDistance - 0.6 * loop.pace) / loop.length,
      ),
      partnerLoop: loop.translated(2.6),
    );
    expect(turning.attentionAt(0.6), (yaw: 0.0, nod: 0.0, eyeYaw: 0.0));
  });

  test(
    'blinks vary independently and close fully before a slower reopening',
    () {
      final left = _conversationActor();
      final right = _conversationActor(id: 'right', side: 1.3, delay: 0.55);
      final leftEvents = _blinkEvents(left);
      final rightEvents = _blinkEvents(right);
      expect(leftEvents.length, inInclusiveRange(5, 7));
      expect(rightEvents.length, inInclusiveRange(5, 7));
      expect(
        leftEvents.map((e) => e.start),
        isNot(rightEvents.map((e) => e.start)),
      );
      for (final events in [leftEvents, rightEvents]) {
        final gaps = <int>{};
        for (var i = 1; i < events.length; i++) {
          final gap = events[i].start - events[i - 1].start;
          expect(gap, inInclusiveRange(3.1, 8.1));
          gaps.add((gap * 100).round());
        }
        expect(gaps.length, greaterThan(1));
        for (final event in events) {
          expect(event.end - event.start, inInclusiveRange(0.195, 0.245));
          expect(
            event.lastClosed - event.firstClosed,
            inInclusiveRange(0.033, 0.045),
          );
          final closing = event.firstClosed - event.start;
          final opening = event.end - event.lastClosed;
          expect(closing, greaterThan(0.05));
          expect(opening, greaterThan(1.8 * closing));
        }
      }
    },
  );

  test('blink transitions ease into their open and closed holds', () {
    final actor = _conversationActor();
    final events = _blinkEvents(actor);
    expect(events.length, greaterThanOrEqualTo(5));
    expect(actor.blinkAt(0), 0);
    for (final event in events) {
      expect(actor.blinkAt(event.start), lessThan(0.0001));
      expect(actor.blinkAt(event.firstClosed - 0.001), greaterThan(0.9999));
      expect(actor.blinkAt(event.lastClosed + 0.001), greaterThan(0.9999));
      expect(actor.blinkAt(event.end - 0.001), lessThan(0.0001));
    }
    var previous = 0.0;
    for (var millis = 0; millis <= 35000; millis++) {
      final closure = actor.blinkAt(millis / 1000);
      expect(closure, inInclusiveRange(0, 1));
      expect((closure - previous).abs(), lessThan(0.04));
      previous = closure;
    }
  });

  glados.Glados(glados.any.int, glados.ExploreConfig(numRuns: 80)).test(
    'expression sampling is independent of frame order and stays bounded',
    (value) {
      final actor = _conversationActor();
      final t = (value % 1000000) / 97;
      final attention = actor.attentionAt(t);
      final blink = actor.blinkAt(t);
      actor
        ..attentionAt(t + 100)
        ..blinkAt(t - 100);
      expect(actor.attentionAt(t), attention);
      expect(actor.blinkAt(t), blink);
      expect(attention.yaw.abs(), lessThanOrEqualTo(0.48));
      expect(attention.eyeYaw.abs(), lessThanOrEqualTo(0.18));
      expect(attention.nod, inInclusiveRange(0, 0.045));
      expect(blink, inInclusiveRange(0, 1));
    },
    tags: ['glados'],
  );
}
