import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Glides a chat thread toward its end at a steady [speed]: content that
/// lands below is read into view instead of jumped to.
///
/// The end is read on every frame, so a reply that keeps growing while the
/// glide runs is followed to its new end — unless [followGrowth] is off.
/// The glide eases in over
/// [_rampIn] and brakes evenly into the end over [_settle] instead of
/// stopping dead.
///
/// It is an ordinary scroll activity, so whatever the reader does — a
/// touch (hold), a drag, a wheel, a jump — replaces it on the spot. Unlike
/// `animateTo`'s activity it does not ignore pointers, so a card stays
/// tappable through a long glide.
class ChatGlideScrollActivity extends ScrollActivity {
  ChatGlideScrollActivity(
    ScrollPositionWithSingleContext position, {
    required this.speed,
    this.followGrowth = true,
  }) : super(position) {
    _ticker = position.context.vsync.createTicker(_tick)..start();
  }

  /// Logical pixels a second at full pace.
  final double speed;

  /// Whether growth at the end is followed. When off — a host that keeps
  /// replies where they start — the end is still read live until it is laid
  /// out (within the cache extent; before that it is the list's estimate),
  /// and held from then on, so an answer growing under the glide is not.
  final bool followGrowth;
  double? _heldEnd;

  /// Where the glide is heading now. Never beyond the list's end.
  double get destination {
    final end = _position.maxScrollExtent;
    final held = _heldEnd;
    return held == null ? end : math.min(held, end);
  }

  /// The position this glide drives — read from the delegate, which the
  /// scrollable swaps when it replaces its position (a device pixel ratio
  /// change, say), never from the one it was created with.
  ScrollPositionWithSingleContext get _position =>
      delegate as ScrollPositionWithSingleContext;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _velocity = 0;

  /// The time it takes to reach full pace from rest.
  static const _rampIn = 0.3;

  /// The time it takes to brake from full pace to rest at the end.
  static const _settle = 0.25;

  /// Whether this glide is still the position's activity.
  bool get isActive => !_disposed;
  bool _disposed = false;

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!followGrowth &&
        _heldEnd == null &&
        _position.extentAfter <= RenderAbstractViewport.defaultCacheExtent) {
      _heldEnd = _position.maxScrollExtent;
    }
    final end = destination;
    final remaining = end - _position.pixels;
    if (remaining < 0.5) {
      if (remaining > 0) delegate.setPixels(end);
      // Idle when in range; brought back first when the end moved above the
      // position (a viewport that grew under the glide).
      delegate.goBallistic(0);
      return;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    // Even braking: the speed from which a constant deceleration of
    // `speed / _settle` comes to rest exactly at the end.
    _velocity = math.min(
      speed * math.min(1, seconds / _rampIn),
      math.sqrt(2 * speed / _settle * remaining),
    );
    delegate.setPixels(_position.pixels + math.min(remaining, _velocity * dt));
  }

  @override
  bool get shouldIgnorePointer => false;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _velocity;

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    super.dispose();
  }
}
