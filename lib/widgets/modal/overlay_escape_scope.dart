import 'package:flutter/widgets.dart';

/// Gives a hand-rolled overlay — a scrim drawn in a `Stack` rather than a
/// pushed route — the keyboard half of the modal contract: while [active],
/// Escape calls [onDismiss], the same callback a tap on the scrim makes.
///
/// A route gets this from Flutter for free; an overlay that lives inside the
/// page does not, because nothing holds focus inside it and the page behind
/// the scrim answers Escape (or ignores it) instead. So on becoming active
/// this takes focus — the page under the scrim is inert anyway — and on
/// becoming inactive it hands focus back to whatever held it before, unless
/// focus has moved on in the meantime.
///
/// Wrap the whole overlay, scrim and panel together, so a control inside the
/// panel that takes focus by Tab still reaches this. Prefer a real route
/// (`showDialog`, `ModalUtils.showWoltModal`) for new modals; this is for the
/// overlays that must stay in the page, such as the mobile navigation drawer.
class OverlayEscapeScope extends StatefulWidget {
  const OverlayEscapeScope({
    required this.active,
    required this.onDismiss,
    required this.child,
    super.key,
  });

  /// Whether the overlay is showing. Escape does nothing while false.
  final bool active;

  /// What a tap on the overlay's scrim does.
  final VoidCallback onDismiss;

  final Widget child;

  @override
  State<OverlayEscapeScope> createState() => _OverlayEscapeScopeState();
}

class _OverlayEscapeScopeState extends State<OverlayEscapeScope> {
  // Out of Tab traversal: the scope is mounted while inactive too, and must
  // not be an invisible stop in the page. requestFocus still reaches it.
  final FocusNode _node = FocusNode(
    debugLabel: 'OverlayEscapeScope',
    skipTraversal: true,
  );
  FocusNode? _restoreTo;

  @override
  void initState() {
    super.initState();
    if (widget.active) _claimFocus();
  }

  @override
  void didUpdateWidget(covariant OverlayEscapeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _claimFocus();
    if (oldWidget.active && !widget.active) _releaseFocus();
  }

  /// Notes who holds focus now — before a host that excludes the covered page
  /// from focus in this same build takes it away — and takes it after the
  /// frame, once the overlay is laid out.
  void _claimFocus() {
    final current = FocusManager.instance.primaryFocus;
    if (current != _node) _restoreTo = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _node.requestFocus();
    });
  }

  /// After the frame, so a page the host stops excluding in this same build
  /// can take focus again.
  void _releaseFocus() {
    final restoreTo = _restoreTo;
    _restoreTo = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.active || !_node.hasPrimaryFocus) return;
      if (restoreTo != null && restoreTo.context != null) {
        restoreTo.requestFocus();
      } else {
        _node.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      if (widget.active)
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            widget.onDismiss();
            return null;
          },
        ),
    },
    child: Focus(focusNode: _node, child: widget.child),
  );
}
