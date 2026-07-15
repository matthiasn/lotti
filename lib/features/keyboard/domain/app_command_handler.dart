import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';

typedef AppCommandCallback =
    FutureOr<void> Function(
      AppCommandInvocation invocation,
    );

/// Runtime context supplied to an executing command handler.
@immutable
class AppCommandInvocation {
  const AppCommandInvocation({
    required this.id,
    required this.context,
    required this.snapshot,
  });

  final AppCommandId id;
  final BuildContext context;
  final AppCommandContextSnapshot snapshot;
}

/// A lifecycle-owned command callback and its current enabled state.
@immutable
class AppCommandHandler {
  const AppCommandHandler({
    required this.invoke,
    this.isEnabled,
  });

  final AppCommandCallback invoke;
  final bool Function()? isEnabled;

  bool get enabled => isEnabled?.call() ?? true;
}

/// A stable view of the command scopes that were active at invocation time.
///
/// The palette uses this after its search field takes focus. Availability is
/// still checked at execution, so a disposed page cannot receive a stale
/// command.
abstract interface class AppCommandContextSnapshot {
  bool isAvailable(AppCommandId id);

  Future<bool> invoke(AppCommandId id);
}
