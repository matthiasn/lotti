import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/runtime/stage_effects.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';

const _lights = [
  StageLightSample(
    color: Color(0xFFFFA01E),
    targetX: 0.3,
    intensity: 0.8,
  ),
  StageLightSample(
    color: Color(0xFFFF2E8C),
    targetX: 0.5,
    intensity: 0.8,
  ),
  StageLightSample(
    color: Color(0xFFB026FF),
    targetX: 0.7,
    intensity: 0.8,
  ),
];

void main() {
  group('StageEffectScheduler', () {
    const scheduler = StageEffectScheduler();
    const cue = StageEffectCue(
      kind: StageEffectKind.coldSparks,
      startSeconds: 10,
      durationSeconds: 2,
      origin: Offset(0.4, 0.7),
      directionRadians: -math.pi / 2,
      intensity: 0.8,
      lane: 2,
    );

    test('is deterministic for identical inputs', () {
      final a = scheduler.sample(
        positionSeconds: 10.5,
        beat: 0.4,
        cues: const [cue],
        lights: _lights,
      );
      final b = scheduler.sample(
        positionSeconds: 10.5,
        beat: 0.4,
        cues: const [cue],
        lights: _lights,
      );
      expect(a, equals(b));
    });

    test('ignores cues outside their active window', () {
      expect(
        scheduler.sample(
          positionSeconds: 9.99,
          beat: 1,
          cues: const [cue],
          lights: _lights,
        ),
        isEmpty,
      );
      expect(
        scheduler.sample(
          positionSeconds: 12,
          beat: 1,
          cues: const [cue],
          lights: _lights,
        ),
        isEmpty,
      );
    });

    test('reports normalized progress inside the active window', () {
      final sample = scheduler
          .sample(
            positionSeconds: 11,
            beat: 0,
            cues: const [cue],
            lights: _lights,
          )
          .single;
      expect(sample.progress, closeTo(0.5, 1e-9));
      expect(sample.origin.dx, inInclusiveRange(0, 1));
      expect(sample.origin.dy, inInclusiveRange(0, 1));
    });

    test('uses the cue lane to pull a stage-light gel into the palette', () {
      final sample = scheduler
          .sample(
            positionSeconds: 10.1,
            beat: 0,
            cues: const [cue],
            lights: _lights,
          )
          .single;
      expect(sample.palette, contains(_lights[2].color));
      expect(sample.palette, isNotEmpty);
    });

    test('reduced motion suppresses transient samples', () {
      expect(
        scheduler.sample(
          positionSeconds: 10.5,
          beat: 1,
          cues: const [cue],
          lights: _lights,
          reducedMotion: true,
        ),
        isEmpty,
      );
    });

    test('caps concurrent bursts by intensity', () {
      const capped = StageEffectScheduler(maxConcurrentBursts: 2);
      final samples = capped.sample(
        positionSeconds: 1,
        beat: 0,
        cues: const [
          StageEffectCue(
            kind: StageEffectKind.embers,
            startSeconds: 0,
            durationSeconds: 2,
            origin: Offset(0.2, 0.7),
            directionRadians: -math.pi / 2,
            intensity: 0.2,
          ),
          StageEffectCue(
            kind: StageEffectKind.confetti,
            startSeconds: 0,
            durationSeconds: 2,
            origin: Offset(0.3, 0.7),
            directionRadians: -math.pi / 2,
            intensity: 0.9,
          ),
          StageEffectCue(
            kind: StageEffectKind.bubbles,
            startSeconds: 0,
            durationSeconds: 2,
            origin: Offset(0.4, 0.7),
            directionRadians: -math.pi / 2,
            intensity: 0.7,
          ),
        ],
        lights: _lights,
      );
      expect(samples, hasLength(2));
      expect(samples.map((s) => s.kind), [
        StageEffectKind.confetti,
        StageEffectKind.bubbles,
      ]);
    });
  });

  group('StageEffectCueBuilder', () {
    const builder = StageEffectCueBuilder();
    const sections = [
      StageEffectSection(
        startSeconds: 0,
        endSeconds: 8,
        label: 'verse',
        energetic: true,
      ),
      StageEffectSection(
        startSeconds: 8,
        endSeconds: 16,
        label: 'chorus',
        energetic: true,
      ),
      StageEffectSection(
        startSeconds: 16,
        endSeconds: 24,
        label: 'bridge',
        energetic: false,
      ),
    ];
    final beats = [for (var i = 0; i < 28; i++) i * 0.5];
    final downbeats = [for (var i = 0; i < beats.length; i += 4) i];

    test('builds section-hit confetti for hero sections', () {
      final cues = builder.build(
        beatTimesSec: beats,
        downbeatIndices: downbeats,
        sections: sections,
        trackDurationSeconds: 24,
      );
      expect(cues.where((c) => c.kind == StageEffectKind.confetti), isNotEmpty);
    });

    test('builds bubble cues for calm bridge-like sections', () {
      final cues = builder.build(
        beatTimesSec: beats,
        downbeatIndices: downbeats,
        sections: sections,
        trackDurationSeconds: 24,
      );
      expect(cues.where((c) => c.kind == StageEffectKind.bubbles), isNotEmpty);
    });

    test('keeps cues sorted and within the track duration', () {
      final cues = builder.build(
        beatTimesSec: beats,
        downbeatIndices: downbeats,
        sections: sections,
        trackDurationSeconds: 18,
      );
      for (var i = 1; i < cues.length; i++) {
        expect(
          cues[i].startSeconds,
          greaterThanOrEqualTo(cues[i - 1].startSeconds),
        );
      }
      expect(cues.every((c) => c.startSeconds < 18), isTrue);
    });
  });
}
