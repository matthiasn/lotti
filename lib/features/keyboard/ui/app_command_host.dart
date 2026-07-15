import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_scope.dart';
import 'package:lotti/features/keyboard/ui/keyboard_focus_region.dart';

/// Root of Lotti's in-application desktop command system.
class AppCommandHost extends StatefulWidget {
  const AppCommandHost({
    required this.handlers,
    required this.child,
    this.onActivity,
    this.onError,
    this.platform,
    this.focusRegionController,
    super.key,
  });

  final Map<AppCommandId, AppCommandHandler> handlers;
  final Widget child;
  final VoidCallback? onActivity;
  final AppCommandErrorHandler? onError;
  final TargetPlatform? platform;
  final KeyboardFocusRegionController? focusRegionController;

  @override
  State<AppCommandHost> createState() => _AppCommandHostState();
}

class _AppCommandHostState extends State<AppCommandHost> {
  late AppCommandController _commandController;
  late KeyboardFocusRegionController _focusRegionController;
  late bool _ownsFocusRegionController;

  @override
  void initState() {
    super.initState();
    _createControllers();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  void _createControllers() {
    _commandController = AppCommandController(onError: widget.onError);
    _ownsFocusRegionController = widget.focusRegionController == null;
    _focusRegionController =
        widget.focusRegionController ?? KeyboardFocusRegionController();
  }

  @override
  void didUpdateWidget(covariant AppCommandHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onError != widget.onError) {
      _commandController.dispose();
      _commandController = AppCommandController(onError: widget.onError);
    }
    if (oldWidget.focusRegionController != widget.focusRegionController) {
      if (_ownsFocusRegionController) _focusRegionController.dispose();
      _ownsFocusRegionController = widget.focusRegionController == null;
      _focusRegionController =
          widget.focusRegionController ?? KeyboardFocusRegionController();
    }
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      widget.onActivity?.call();
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _commandController.dispose();
    if (_ownsFocusRegionController) _focusRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handlers = <AppCommandId, AppCommandHandler>{
      ...widget.handlers,
      AppCommandId.nextFocusRegion: AppCommandHandler(
        invoke: (_) => _focusRegionController.focusNext(),
      ),
      AppCommandId.previousFocusRegion: AppCommandHandler(
        invoke: (_) => _focusRegionController.focusNext(reverse: true),
      ),
    };
    final platform = widget.platform ?? defaultTargetPlatform;
    final shortcutBindings = AppCommandCatalog.bindingsFor(
      platform: platform,
      commandIds: handlers.keys,
    );
    final shortcuts = <ShortcutActivator, Intent>{
      for (final entry in shortcutBindings.entries)
        entry.key as ShortcutActivator: AppCommandIntent(entry.value),
    };

    return AppCommandControllerProvider(
      controller: _commandController,
      platform: platform,
      child: KeyboardFocusRegionRegistry(
        controller: _focusRegionController,
        child: Actions(
          actions: <Type, Action<Intent>>{
            AppCommandIntent: _AppCommandAction(_commandController),
          },
          child: Shortcuts(
            shortcuts: shortcuts,
            child: AppCommandScope(
              debugLabel: 'app-global',
              handlers: handlers,
              registerShortcuts: false,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppCommandAction extends ContextAction<AppCommandIntent> {
  _AppCommandAction(this.controller);

  final AppCommandController controller;

  @override
  bool isEnabled(AppCommandIntent intent, [BuildContext? context]) =>
      context != null && controller.isAvailable(context, intent.id);

  @override
  Object? invoke(AppCommandIntent intent, [BuildContext? context]) {
    if (context != null) {
      unawaited(controller.invoke(context, intent.id));
    }
    return null;
  }
}
