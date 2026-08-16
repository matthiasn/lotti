import 'package:flutter/widgets.dart';

/// Keeps any number of scrollables moving as one.
///
/// Each participating scroll view takes a controller from [attach] and every
/// offset change on one member is mirrored onto the others (clamped to their
/// own extents, so a shorter member pins to its edge instead of overscrolling).
/// Members are expected to share an anchor — the goal detail page's day
/// tracks all use `reverse: true`, so offset 0 is "today at the trailing
/// edge" for every track regardless of its total extent, and mirrored
/// offsets line the same date up across cards.
class LinkedScrollGroup {
  final List<ScrollController> _controllers = [];
  final Map<ScrollController, VoidCallback> _listeners = {};
  double _offset = 0;
  bool _syncing = false;

  /// Creates a controller whose position joins the group, opening at the
  /// group's current shared offset.
  ScrollController attach() {
    final controller = ScrollController(initialScrollOffset: _offset);
    void onScroll() {
      if (_syncing || !controller.hasClients) return;
      _offset = controller.offset;
      _syncing = true;
      try {
        for (final other in _controllers) {
          if (identical(other, controller) || !other.hasClients) continue;
          final target = _offset.clamp(
            other.position.minScrollExtent,
            other.position.maxScrollExtent,
          );
          // A hundredth of a pixel of slack, so mirrored jumps cannot
          // ping-pong on floating-point residue.
          if ((other.offset - target).abs() > 0.01) {
            other.jumpTo(target);
          }
        }
      } finally {
        _syncing = false;
      }
    }

    controller.addListener(onScroll);
    _controllers.add(controller);
    _listeners[controller] = onScroll;
    return controller;
  }

  /// Removes and disposes a controller created by [attach].
  void detach(ScrollController controller) {
    final listener = _listeners.remove(controller);
    if (listener != null) controller.removeListener(listener);
    _controllers.remove(controller);
    controller.dispose();
  }

  /// Disposes every remaining member.
  void dispose() {
    List.of(_controllers).forEach(detach);
  }
}
