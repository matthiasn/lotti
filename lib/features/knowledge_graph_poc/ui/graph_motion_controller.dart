/// Lightweight node motion for the knowledge-graph view.
///
/// The graph layout remains the authoritative rest position. This controller
/// only carries short-lived offsets and velocities for nodes that were recently
/// touched, walked to, or nudged by a pan gesture.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';

class GraphMotionController extends ChangeNotifier {
  GraphMotionController({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  final _bodies = <String, _MotionBody>{};
  final _forceEdges = <_ForceEdge>[];
  Map<String, Offset> _restPositions = const {};
  Set<String> _activeIds = const {};

  Duration? _lastElapsed;
  bool _reduceMotion = false;

  static const double _anchorSpring = 48;
  static const double _edgeSpring = 24;
  static const double _separationSpring = 18;
  static const double _damping = 10.5;
  static const double _maxOffset = 44;
  static const double _maxVelocity = 360;
  static const double _restDistance = 0.12;
  static const double _restVelocity = 1.1;

  bool get reduceMotion => _reduceMotion;

  set reduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    if (value) {
      settle();
    }
  }

  bool get isAnimating => _ticker.isActive;

  bool get hasActiveMotion => _bodies.isNotEmpty;

  int get activeNodeCount => _bodies.length;

  Offset offsetFor(String id) => _bodies[id]?.offset ?? Offset.zero;

  Offset displayPosition(String id, Offset restPosition) =>
      restPosition + offsetFor(id);

  void configureForceIsland({
    required Map<String, Offset> restPositions,
    required Iterable<GraphEdge> edges,
    required Iterable<String> activeIds,
  }) {
    _restPositions = restPositions;
    _activeIds = {
      for (final id in activeIds)
        if (restPositions.containsKey(id)) id,
    };

    _forceEdges
      ..clear()
      ..addAll(
        edges
            .where(
              (edge) =>
                  _activeIds.contains(edge.fromId) &&
                  _activeIds.contains(edge.toId),
            )
            .map((edge) {
              final from = restPositions[edge.fromId]!;
              final to = restPositions[edge.toId]!;
              return _ForceEdge(
                edge.fromId,
                edge.toId,
                math.max((to - from).distance, 1),
              );
            }),
      );

    _bodies.removeWhere(
      (id, _) => !_activeIds.contains(id) || !restPositions.containsKey(id),
    );
    if (_bodies.isEmpty && _ticker.isActive) {
      _lastElapsed = null;
      _ticker.stop();
    }
  }

  void kick(
    String id, {
    required Offset direction,
    required double distance,
    required double velocity,
    double dampingScale = 1,
  }) {
    if (_reduceMotion || !_canMove(id) || distance <= 0 || velocity < 0) {
      return;
    }

    final unit = _unit(direction, fallbackSeed: id);
    final body = _bodies.putIfAbsent(id, _MotionBody.new);
    final boundedDampingScale = dampingScale.clamp(0.35, 1).toDouble();
    body
      ..offset = body.offset + unit * distance
      ..velocity = body.velocity + unit * velocity
      ..dampingScale = math.min(body.dampingScale, boundedDampingScale);
    _clamp(body);
    _start();
    notifyListeners();
  }

  void settle() {
    if (_bodies.isEmpty && !_ticker.isActive) return;
    _bodies.clear();
    _lastElapsed = null;
    if (_ticker.isActive) _ticker.stop();
    notifyListeners();
  }

  @visibleForTesting
  void elapseForTest(Duration delta) {
    _step(_seconds(delta));
  }

  void _start() {
    if (_ticker.isActive) return;
    _lastElapsed = null;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final previous = _lastElapsed;
    _lastElapsed = elapsed;
    if (previous == null) return;
    _step(_seconds(elapsed - previous));
  }

  void _step(double dt) {
    if (_bodies.isEmpty) {
      if (_ticker.isActive) _ticker.stop();
      _lastElapsed = null;
      return;
    }

    final initiallyMovingIds = _bodies.keys.toSet();
    final forces = <String, Offset>{
      for (final id in initiallyMovingIds) id: Offset.zero,
    };
    _applyEdgeForces(forces);
    _applySeparationForces(forces);

    final expired = <String>[];
    _bodies.forEach((id, body) {
      final acceleration =
          (forces[id] ?? Offset.zero) -
          body.offset * _anchorSpring -
          body.velocity * (_damping * body.dampingScale);
      body
        ..velocity += acceleration * dt
        ..offset += body.velocity * dt;
      _clamp(body);

      final almostHome =
          initiallyMovingIds.contains(id) &&
          body.offset.distanceSquared < _restDistance * _restDistance &&
          body.velocity.distanceSquared < _restVelocity * _restVelocity;
      if (almostHome) expired.add(id);
    });

    expired.forEach(_bodies.remove);
    if (_bodies.isEmpty) {
      _lastElapsed = null;
      if (_ticker.isActive) _ticker.stop();
    }
    notifyListeners();
  }

  void _applyEdgeForces(Map<String, Offset> forces) {
    if (_forceEdges.isEmpty) return;

    for (final edge in _forceEdges) {
      final fromMoving = _bodies.containsKey(edge.fromId);
      final toMoving = _bodies.containsKey(edge.toId);
      if (!fromMoving && !toMoving) continue;

      final fromBody = _bodyFor(edge.fromId, forces);
      final toBody = _bodyFor(edge.toId, forces);
      final fromRest = _restPositions[edge.fromId];
      final toRest = _restPositions[edge.toId];
      if (fromBody == null ||
          toBody == null ||
          fromRest == null ||
          toRest == null) {
        continue;
      }

      final from = fromRest + fromBody.offset;
      final to = toRest + toBody.offset;
      final raw = to - from;
      final distance = raw.distance;
      final direction = distance > 0.001
          ? raw / distance
          : _unit(
              toRest - fromRest,
              fallbackSeed: '${edge.fromId}:${edge.toId}',
            );
      final stretch = distance - edge.restLength;
      final force = direction * (stretch * _edgeSpring);
      forces[edge.fromId] = (forces[edge.fromId] ?? Offset.zero) + force;
      forces[edge.toId] = (forces[edge.toId] ?? Offset.zero) - force;
    }
  }

  void _applySeparationForces(Map<String, Offset> forces) {
    final ids = (_activeIds.isEmpty ? _bodies.keys : _activeIds).toList(
      growable: false,
    );
    for (var i = 0; i < ids.length; i++) {
      final aId = ids[i];
      final aRest = _restPositions[aId];
      final aBody = _bodies[aId];
      if (aRest == null) continue;

      for (var j = i + 1; j < ids.length; j++) {
        final bId = ids[j];
        final bRest = _restPositions[bId];
        final bBody = _bodies[bId];
        if (bRest == null || (aBody == null && bBody == null)) continue;

        final aOffset = aBody?.offset ?? Offset.zero;
        final bOffset = bBody?.offset ?? Offset.zero;
        final restRaw = bRest - aRest;
        final restDistance = math.max(restRaw.distance, 1);
        final threshold = restDistance * 0.82;
        final raw = bRest + bOffset - (aRest + aOffset);
        final distance = raw.distance;
        if (distance >= threshold) continue;

        final direction = distance > 0.001
            ? raw / distance
            : _unit(restRaw, fallbackSeed: '$aId:$bId');
        final force = direction * ((threshold - distance) * _separationSpring);
        if (aBody != null) {
          forces[aId] = (forces[aId] ?? Offset.zero) - force;
        }
        if (bBody != null) {
          forces[bId] = (forces[bId] ?? Offset.zero) + force;
        }
      }
    }
  }

  _MotionBody? _bodyFor(String id, Map<String, Offset> forces) {
    if (!_canMove(id)) return null;
    forces.putIfAbsent(id, () => Offset.zero);
    return _bodies.putIfAbsent(id, _MotionBody.new);
  }

  double _seconds(Duration delta) {
    final seconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
    return seconds.clamp(0, 1 / 30).toDouble();
  }

  bool _canMove(String id) => _activeIds.isEmpty || _activeIds.contains(id);

  Offset _unit(Offset direction, {required String fallbackSeed}) {
    final distance = direction.distance;
    if (distance > 0.001) return direction / distance;

    final angle = (fallbackSeed.hashCode & 0xFFFF) / 0xFFFF * math.pi * 2;
    return Offset(math.cos(angle), math.sin(angle));
  }

  void _clamp(_MotionBody body) {
    final distance = body.offset.distance;
    if (distance > _maxOffset) {
      body.offset = body.offset / distance * _maxOffset;
    }
    final velocity = body.velocity.distance;
    if (velocity > _maxVelocity) {
      body.velocity = body.velocity / velocity * _maxVelocity;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _MotionBody {
  Offset offset = Offset.zero;
  Offset velocity = Offset.zero;
  double dampingScale = 1;
}

class _ForceEdge {
  const _ForceEdge(this.fromId, this.toId, this.restLength);

  final String fromId;
  final String toId;
  final double restLength;
}
