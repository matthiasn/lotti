import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:material_ui/material_ui.dart';

/// Lets [child] animate only while it is actually on screen: its tab is the
/// visible one, the app is in the foreground, and it intersects its
/// enclosing scroll viewport.
///
/// For pages that build their content eagerly and keep it resident — the
/// Goals list, the goal detail page's nudge banners — where a below-the-fold
/// child with a running ticker (a companion's idle animation, a repeating
/// headline) would otherwise burn frame work the user cannot see. The
/// verdict gates a [TickerMode] around [child]; TickerMode composes with its
/// ancestors by AND, so enabling it here never overrides the app shell's
/// inactive-tab muting.
///
/// Visibility is rechecked on scroll, app-lifecycle transitions, rebuilds
/// and once per drawn frame — not on a timer: while nothing draws, nothing
/// runs. [onVisibilityChanged] reports each transition, for callers that
/// measure exposure on top of the gate.
class OnScreenTickerMode extends StatefulWidget {
  const OnScreenTickerMode({
    required this.child,
    this.onVisibilityChanged,
    super.key,
  });

  final Widget child;

  /// Called on every hidden↔visible transition, never repeated for the
  /// same verdict. Not called on disposal: a caller that must close an open
  /// episode does so in its own `dispose`.
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<OnScreenTickerMode> createState() => _OnScreenTickerModeState();
}

class _OnScreenTickerModeState extends State<OnScreenTickerMode>
    with WidgetsBindingObserver {
  ScrollPosition? _position;

  /// Starts false — the first layout-safe visibility sample is the
  /// post-frame recheck, so an off-screen child never animates even for its
  /// first frame.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armFrameRecheck();
  }

  /// One cheap rect check per DRAWN frame: a local reveal animation (a card
  /// expanding above, a section unfolding) moves the child across the
  /// viewport boundary with no scroll event and no rebuild of this widget,
  /// so scroll/lifecycle/update hooks alone leave the gate stale. Re-arming
  /// a post-frame callback does not itself schedule frames — while nothing
  /// animates, nothing runs.
  void _armFrameRecheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recheck();
      _armFrameRecheck();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding or locking the device leaves both TickerMode and the
    // viewport check true; leaving `resumed` counts as hidden.
    _recheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_recheck);
      _position = position?..addListener(_recheck);
    }
    // Dependency changes are delivered during build. A sliver viewport may
    // still be resolving directional padding at that point, so querying its
    // reveal offset synchronously can trip Flutter's resolvedPadding assert.
    // The post-frame check below is the first layout-safe visibility sample.
    _recheckAfterFrame();
  }

  @override
  void didUpdateWidget(OnScreenTickerMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A sibling inserted or removed above this one moves it across the
    // viewport boundary with no scroll event — the rebuild that reflowed
    // the list is the signal.
    _recheckAfterFrame();
  }

  /// On the FIRST build the render box has no layout yet (and after a
  /// rebuild the new layout isn't in yet), so visibility is confirmed once
  /// the frame is out.
  void _recheckAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recheck();
    });
  }

  /// The app shell keeps inactive tabs mounted (IndexedStack) with their
  /// tickers disabled — TickerMode is the "is this tab on screen" signal —
  /// and eager scrollable hosts keep off-screen children mounted too, so
  /// the enclosing viewport must actually show the child.
  void _recheck() {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final appForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    final visible =
        appForeground && TickerMode.valuesOf(context).enabled && _inViewport();
    if (visible == _visible) return;
    setState(() => _visible = visible);
    widget.onVisibilityChanged?.call(visible);
  }

  bool _inViewport() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = _position;
    if (viewport == null ||
        position == null ||
        !position.hasPixels ||
        !position.hasViewportDimension) {
      // No scrollable ancestor (the shell dock): mounted on a visible tab
      // means on screen.
      return true;
    }
    final leadingEdge = viewport.getOffsetToReveal(box, 0).offset;
    return leadingEdge < position.pixels + position.viewportDimension &&
        leadingEdge + box.size.height > position.pixels;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _position?.removeListener(_recheck);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: _visible, child: widget.child);
}
