import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';

typedef AppCommandErrorHandler =
    void Function(
      AppCommandId id,
      Object error,
      StackTrace stackTrace,
    );

/// Resolves and invokes commands against focused, captured, or last-active
/// command scopes.
class AppCommandController extends ChangeNotifier {
  AppCommandController({this.onError});

  final AppCommandErrorHandler? onError;
  final Set<AppCommandId> _inFlight = {};
  AppCommandScopeNode? _lastActiveScope;
  bool _notificationScheduled = false;

  void rememberActiveScope(AppCommandScopeNode node) {
    if (!node.mounted || identical(_lastActiveScope, node)) return;
    _lastActiveScope = node;
    _notifySafely();
  }

  void scopeChanged() {
    if (_lastActiveScope case final node? when !node.mounted) {
      _lastActiveScope = null;
    }
    _notifySafely();
  }

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (hasListeners) notifyListeners();
    });
  }

  AppCommandContextSnapshot capture(BuildContext context) {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedNode = focusedContext == null
        ? null
        : AppCommandScopeMarker.maybeOf(focusedContext);
    final lastActiveScope = _lastActiveScope?.mounted ?? false
        ? _lastActiveScope
        : null;
    final contextualNode =
        focusedNode ??
        lastActiveScope ??
        AppCommandScopeMarker.maybeOf(context);
    return _AppCommandContextSnapshot(this, contextualNode);
  }

  bool isAvailable(BuildContext context, AppCommandId id) =>
      capture(context).isAvailable(id);

  Future<bool> invoke(BuildContext context, AppCommandId id) =>
      capture(context).invoke(id);

  Future<bool> _invokeFromNode(
    AppCommandScopeNode? node,
    AppCommandId id,
  ) async {
    final owner = node?.ownerFor(id);
    final handler = owner?.handlerFor(id);
    final ownerContext = owner?.ownerContext;
    if (handler == null || ownerContext == null) return false;

    final definitionAllowsRepeat = AppCommandCatalog.definition(id).allowRepeat;
    if (!definitionAllowsRepeat && !_inFlight.add(id)) return false;

    final snapshot = _AppCommandContextSnapshot(this, node);
    try {
      await Future<void>.sync(
        () => handler.invoke(
          AppCommandInvocation(
            id: id,
            context: ownerContext,
            snapshot: snapshot,
          ),
        ),
      );
      return true;
    } on Object catch (error, stackTrace) {
      onError?.call(id, error, stackTrace);
      return false;
    } finally {
      if (!definitionAllowsRepeat) _inFlight.remove(id);
    }
  }
}

class _AppCommandContextSnapshot implements AppCommandContextSnapshot {
  const _AppCommandContextSnapshot(this._controller, this._node);

  final AppCommandController _controller;
  final AppCommandScopeNode? _node;

  @override
  bool isAvailable(AppCommandId id) => _node?.handlerFor(id) != null;

  @override
  Future<bool> invoke(AppCommandId id) =>
      _controller._invokeFromNode(_node, id);
}

class AppCommandControllerProvider
    extends InheritedNotifier<AppCommandController> {
  const AppCommandControllerProvider({
    required AppCommandController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppCommandController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppCommandControllerProvider>()!
      .notifier!;

  static AppCommandController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppCommandControllerProvider>()
      ?.notifier;

  /// Reads the dispatcher without subscribing the caller to availability
  /// changes. Command scopes use this for lifecycle registration so their own
  /// `scopeChanged` notification cannot recursively trigger dependencies.
  static AppCommandController? maybeRead(BuildContext context) => context
      .getInheritedWidgetOfExactType<AppCommandControllerProvider>()
      ?.notifier;
}
