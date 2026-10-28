import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// How far a horizontal swipe must travel, in logical pixels, before it
/// moves the dock one banner: the width of a fingertip, so a tap that drifts
/// or a vertical scroll that wobbles never pages.
const nudgeBannerDockSwipeDistance = 48.0;

/// The quiet a stream of scroll signals needs before the next one starts a
/// new swipe. A trackpad reports one two-finger swipe — momentum included —
/// as a burst of signals milliseconds apart, so without this one flick would
/// page through every banner in the dock.
const nudgeBannerDockSwipeGap = Duration(milliseconds: 250);

/// Pages the banner dock with a horizontal swipe, one banner per gesture:
/// towards the left for the next banner, towards the right for the previous
/// one, the way content follows the fingers on every platform.
///
/// Two routes reach it, because desktops deliver the same physical gesture
/// differently:
///
/// - **A drag** — a finger on a touch screen, or two fingers on a trackpad
///   where the platform reports them as a pan (macOS, Windows, and Linux
///   under recent GTK). A mouse drag is excluded: pressing on the dock is a
///   tap, and dragging with a mouse is how text gets selected, not how a
///   carousel is paged.
/// - **Horizontal scroll signals** — a trackpad that reports a two-finger
///   swipe as scrolling, and a tilt wheel. Only a signal whose horizontal
///   part dominates is claimed, through the pointer-signal resolver, so the
///   page behind the dock still scrolls vertically under it.
///
/// [enabled] is false with fewer than two banners, where there is nothing to
/// page to and the gestures must reach the page untouched.
class NudgeBannerDockSwipe extends StatefulWidget {
  const NudgeBannerDockSwipe({
    required this.enabled,
    required this.onNext,
    required this.onPrevious,
    required this.child,
    super.key,
  });

  final bool enabled;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Widget child;

  @override
  State<NudgeBannerDockSwipe> createState() => _NudgeBannerDockSwipeState();
}

class _NudgeBannerDockSwipeState extends State<NudgeBannerDockSwipe> {
  double _dragTravel = 0;

  /// Horizontal scroll accumulated in the current burst of signals.
  double _scrollTravel = 0;

  /// When the last scroll signal arrived, from the event's own timestamp, so
  /// the gap is measured on the input clock rather than a timer.
  Duration? _lastScrollAt;

  /// Whether the current burst has already paged — the rest of it is the
  /// same gesture's momentum.
  bool _scrollPaged = false;

  void _page(double travel) {
    if (travel < 0) {
      widget.onNext();
    } else {
      widget.onPrevious();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final travel = _dragTravel;
    _dragTravel = 0;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() >= kMinFlingVelocity) {
      _page(velocity);
    } else if (travel.abs() >= nudgeBannerDockSwipeDistance) {
      _page(travel);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta;
    if (delta.dx.abs() <= delta.dy.abs()) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (resolved) => _onHorizontalScroll(resolved as PointerScrollEvent),
    );
  }

  void _onHorizontalScroll(PointerScrollEvent event) {
    final last = _lastScrollAt;
    _lastScrollAt = event.timeStamp;
    if (last == null || event.timeStamp - last >= nudgeBannerDockSwipeGap) {
      _scrollTravel = 0;
      _scrollPaged = false;
    }
    if (_scrollPaged) return;
    // Scrolling right moves the content left: the same direction as a
    // leftward swipe, so the sign flips against a drag's.
    _scrollTravel -= event.scrollDelta.dx;
    if (_scrollTravel.abs() >= nudgeBannerDockSwipeDistance) {
      _scrollPaged = true;
      _page(_scrollTravel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    // The same two wrappers whether or not paging is on, with the handlers
    // nulled when it is off: swapping the widget types around [child] would
    // remount the dock's tenant — and its exposure metering — the moment a
    // second banner arrived.
    //
    // Translucent: the gutter between the card and its dots is part of the
    // carousel too, and a swipe that starts there must still page.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: enabled ? _onPointerSignal : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        },
        // Counted from where the finger landed, not from where the drag was
        // recognised: the slop is part of the swipe, and without it a short
        // flick both reads as shorter than it was and falls under the fling
        // floor.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: enabled ? (_) => _dragTravel = 0 : null,
        onHorizontalDragUpdate: enabled
            ? (details) => _dragTravel += details.primaryDelta ?? 0
            : null,
        onHorizontalDragEnd: enabled ? _onDragEnd : null,
        child: widget.child,
      ),
    );
  }
}
