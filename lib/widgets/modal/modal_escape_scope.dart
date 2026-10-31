import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes Escape close the enclosing modal route exactly when a tap on its
/// barrier would, whatever inside the modal holds focus.
///
/// Flutter binds Escape to `DismissIntent` at the app root, and every
/// `ModalRoute` answers that intent — but the lookup starts at the focused
/// widget and stops at the first `DismissIntent` handler it meets, enabled or
/// not. A `Scaffold` registers one for its drawer that stays disabled while
/// no drawer is open. So in any modal whose content has a scaffold — every
/// Wolt sheet (Wolt's own and `LegacyMaterialBridge.modalSurface`), and
/// routes that host a settings page — a focused text field or a Tab-focused
/// button made Escape do nothing.
///
/// This scope catches the Escape key itself on its way up from the focused
/// widget, before the root shortcut turns it into a `DismissIntent`, so it
/// works from anywhere inside the route, scaffold or not. It dismisses the
/// way the barrier does — `Navigator.maybePop`, so the result is the same
/// `null` a barrier tap returns and a `PopScope` inside the modal still gets
/// its say. On a route that is not barrier-dismissible, or not on top, it
/// stands aside and Escape carries on as before. An Escape binding nearer
/// the focus (a multi-page modal's "back one page") still wins.
///
/// `ModalUtils.showWoltModal` installs it on every Wolt sheet; put it around
/// the content of any other modal route that hosts a `Scaffold`.
class ModalEscapeScope extends StatelessWidget {
  const ModalEscapeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.escape): _ModalEscapeIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        _ModalEscapeIntent: _DismissEnclosingRouteAction(context),
      },
      child: child,
    ),
  );
}

class _ModalEscapeIntent extends Intent {
  const _ModalEscapeIntent();
}

class _DismissEnclosingRouteAction extends Action<_ModalEscapeIntent> {
  _DismissEnclosingRouteAction(this.context);

  final BuildContext context;

  @override
  bool isEnabled(_ModalEscapeIntent intent) {
    final route = ModalRoute.of(context);
    return route != null && route.isCurrent && route.barrierDismissible;
  }

  @override
  Object? invoke(_ModalEscapeIntent intent) => Navigator.of(context).maybePop();
}
