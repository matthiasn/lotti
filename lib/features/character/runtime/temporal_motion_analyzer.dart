import 'dart:math' as math;

import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';

/// Frame-by-frame continuity probe for resolved character motion.
///
/// This deliberately lives after [CharacterScene], not in the lower-level clip
/// evaluator: snaps can come from clip channels, contact pinning, head
/// stabilization, autonomic layers, or base transforms. The analyzer measures
/// the resolved world-space bone origins that the renderer actually sees.
class TemporalMotionAnalyzer {
  const TemporalMotionAnalyzer(this.scene);

  final CharacterScene scene;

  TemporalMotionReport analyze({
    required Clip clip,
    required int samples,
    required List<String> boneIds,
    Expression expression = Expression.neutral,
    Affine2D base = Affine2D.identity,
  }) {
    if (samples <= 0) {
      throw ArgumentError.value(samples, 'samples', 'must be positive');
    }
    if (boneIds.isEmpty) {
      throw ArgumentError.value(boneIds, 'boneIds', 'must not be empty');
    }

    final segments = <TemporalMotionSegment>[];
    final accelerations = <TemporalMotionAcceleration>[];
    final previousByBone = <String, TemporalMotionSegment>{};

    var previous = scene.frameAt(
      clip: clip,
      timeSeconds: 0,
      expression: expression,
      base: base,
    );
    for (var frame = 1; frame <= samples; frame++) {
      final timeSeconds = clip.duration * frame / samples;
      final current = scene.frameAt(
        clip: clip,
        timeSeconds: timeSeconds,
        expression: expression,
        base: base,
      );

      for (final boneId in boneIds) {
        final previousTransform = previous.world[boneId];
        final currentTransform = current.world[boneId];
        if (previousTransform == null || currentTransform == null) {
          throw StateError('Bone "$boneId" was not resolved for ${clip.name}.');
        }

        final dx = currentTransform.tx - previousTransform.tx;
        final dy = currentTransform.ty - previousTransform.ty;
        final segment = TemporalMotionSegment(
          boneId: boneId,
          fromFrame: frame - 1,
          toFrame: frame,
          fromPhase: (frame - 1) / samples,
          toPhase: frame / samples,
          dx: dx,
          dy: dy,
          distance: math.sqrt(dx * dx + dy * dy),
        );
        segments.add(segment);

        final previousSegment = previousByBone[boneId];
        if (previousSegment != null) {
          final ax = segment.dx - previousSegment.dx;
          final ay = segment.dy - previousSegment.dy;
          accelerations.add(
            TemporalMotionAcceleration(
              boneId: boneId,
              fromFrame: previousSegment.fromFrame,
              throughFrame: previousSegment.toFrame,
              toFrame: segment.toFrame,
              fromPhase: previousSegment.fromPhase,
              throughPhase: previousSegment.toPhase,
              toPhase: segment.toPhase,
              dx: ax,
              dy: ay,
              magnitude: math.sqrt(ax * ax + ay * ay),
            ),
          );
        }
        previousByBone[boneId] = segment;
      }
      previous = current;
    }

    return TemporalMotionReport(
      clipName: clip.name,
      samples: samples,
      segments: segments,
      accelerations: accelerations,
    );
  }
}

class TemporalMotionReport {
  const TemporalMotionReport({
    required this.clipName,
    required this.samples,
    required this.segments,
    required this.accelerations,
  });

  final String clipName;
  final int samples;
  final List<TemporalMotionSegment> segments;
  final List<TemporalMotionAcceleration> accelerations;

  TemporalMotionSegment get worstDisplacement => _maxBy(
    segments,
    (segment) => segment.distance,
    'segments',
  );

  TemporalMotionAcceleration get worstAcceleration => _maxBy(
    accelerations,
    (acceleration) => acceleration.magnitude,
    'accelerations',
  );

  List<TemporalMotionSegment> topDisplacements(int count) =>
      _topBy(segments, count, (segment) => segment.distance);

  List<TemporalMotionAcceleration> topAccelerations(int count) =>
      _topBy(accelerations, count, (acceleration) => acceleration.magnitude);

  static T _maxBy<T>(
    List<T> values,
    double Function(T value) score,
    String label,
  ) {
    if (values.isEmpty) {
      throw StateError('No temporal motion $label were recorded.');
    }
    var best = values.first;
    var bestScore = score(best);
    for (final value in values.skip(1)) {
      final valueScore = score(value);
      if (valueScore > bestScore) {
        best = value;
        bestScore = valueScore;
      }
    }
    return best;
  }

  static List<T> _topBy<T>(
    List<T> values,
    int count,
    double Function(T value) score,
  ) {
    if (count <= 0) return const [];
    final sorted = [...values]..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.take(count).toList(growable: false);
  }
}

class TemporalMotionSegment {
  const TemporalMotionSegment({
    required this.boneId,
    required this.fromFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.toPhase,
    required this.dx,
    required this.dy,
    required this.distance,
  });

  final String boneId;
  final int fromFrame;
  final int toFrame;
  final double fromPhase;
  final double toPhase;
  final double dx;
  final double dy;
  final double distance;
}

class TemporalMotionAcceleration {
  const TemporalMotionAcceleration({
    required this.boneId,
    required this.fromFrame,
    required this.throughFrame,
    required this.toFrame,
    required this.fromPhase,
    required this.throughPhase,
    required this.toPhase,
    required this.dx,
    required this.dy,
    required this.magnitude,
  });

  final String boneId;
  final int fromFrame;
  final int throughFrame;
  final int toFrame;
  final double fromPhase;
  final double throughPhase;
  final double toPhase;
  final double dx;
  final double dy;
  final double magnitude;
}
