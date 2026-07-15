import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';

/// Contributes lifecycle-safe command handlers for a focused UI subtree.
class AppCommandScope extends StatefulWidget {
  const AppCommandScope({
    required this.handlers,
    required this.child,
    this.debugLabel,
    this.registerShortcuts = true,
    super.key,
  });

  final Map<AppCommandId, AppCommandHandler> handlers;
  final Widget child;
  final String? debugLabel;

  /// The root host already installs its global shortcuts, so its scope only
  /// contributes handlers. Feature scopes keep the default `true`.
  final bool registerShortcuts;

  @override
  State<AppCommandScope> createState() => _AppCommandScopeState();
}

class _AppCommandScopeState extends State<AppCommandScope> {
  late final AppCommandScopeNode _node = AppCommandScopeNode(
    debugLabel: widget.debugLabel,
  );
  AppCommandController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppCommandControllerProvider.maybeRead(context);
    final parent = AppCommandScopeMarker.maybeOf(context);
    if (_controller != controller) {
      final previousController = _controller;
      _node.detach();
      _controller = controller;
      previousController?.scopeChanged();
    }
    if (controller == null) return;
    _node.update(
      parent: parent,
      ownerContext: context,
      handlers: widget.handlers,
    );
    controller.scopeChanged();
  }

  @override
  void didUpdateWidget(covariant AppCommandScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;
    _node.update(
      parent: _node.parent,
      ownerContext: context,
      handlers: widget.handlers,
    );
    _controller?.scopeChanged();
  }

  @override
  void dispose() {
    _node.dispose();
    _controller?.scopeChanged();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return widget.child;
    final platform = AppCommandControllerProvider.maybeReadPlatform(context)!;
    final shortcuts = <ShortcutActivator, Intent>{};
    if (widget.registerShortcuts) {
      final bindings = AppCommandCatalog.bindingsFor(
        platform: platform,
        commandIds: widget.handlers.keys,
      );
      for (final entry in bindings.entries) {
        shortcuts[entry.key as ShortcutActivator] = AppCommandIntent(
          entry.value,
        );
      }
    }

    var child = widget.child;
    if (shortcuts.isNotEmpty) {
      child = Shortcuts(shortcuts: shortcuts, child: child);
    }
    child = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused) return;
        final primaryContext = FocusManager.instance.primaryFocus?.context;
        final closestScope = primaryContext == null
            ? null
            : AppCommandScopeMarker.maybeOf(primaryContext);
        if (identical(closestScope, _node)) {
          _controller?.rememberActiveScope(_node);
        }
      },
      child: child,
    );
    return AppCommandScopeMarker(node: _node, child: child);
  }
}

/// Mutable lifecycle node kept behind the immutable inherited marker.
class AppCommandScopeNode {
  AppCommandScopeNode({this.debugLabel});

  final String? debugLabel;
  AppCommandScopeNode? parent;
  BuildContext? _ownerContext;
  Map<AppCommandId, AppCommandHandler> _handlers = const {};
  bool _mounted = true;

  bool get mounted => _mounted && (_ownerContext?.mounted ?? false);
  BuildContext? get ownerContext => mounted ? _ownerContext : null;

  void update({
    required AppCommandScopeNode? parent,
    required BuildContext ownerContext,
    required Map<AppCommandId, AppCommandHandler> handlers,
  }) {
    this.parent = parent;
    _ownerContext = ownerContext;
    _handlers = Map<AppCommandId, AppCommandHandler>.unmodifiable(handlers);
  }

  AppCommandHandler? handlerFor(AppCommandId id) {
    if (!mounted) return null;
    final handler = _handlers[id];
    if (handler != null && handler.enabled) return handler;
    return parent?.handlerFor(id);
  }

  AppCommandScopeNode? ownerFor(AppCommandId id) {
    if (!mounted) return null;
    final handler = _handlers[id];
    if (handler != null && handler.enabled) return this;
    return parent?.ownerFor(id);
  }

  void dispose() {
    _mounted = false;
    detach();
  }

  void detach() {
    _handlers = const {};
    _ownerContext = null;
    parent = null;
  }
}

class AppCommandScopeMarker extends InheritedWidget {
  const AppCommandScopeMarker({
    required this.node,
    required super.child,
    super.key,
  });

  final AppCommandScopeNode node;

  static AppCommandScopeNode? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppCommandScopeMarker>()?.node;

  @override
  bool updateShouldNotify(AppCommandScopeMarker oldWidget) =>
      node != oldWidget.node;
}
