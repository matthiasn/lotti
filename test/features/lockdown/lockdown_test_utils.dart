import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';

/// A [LockdownController] stand-in for tests of lockdown *consumers*.
///
/// The real controller mirrors every change into the GetIt-registered
/// entities cache; consumers only care about the state, so this one starts
/// from [initial] and lets a test flip it through [current] without any
/// GetIt registration.
class TestLockdownController extends LockdownController {
  TestLockdownController([this.initial = LockdownState.inactive]);

  final LockdownState initial;

  @override
  LockdownState build() => initial;

  /// The live state; assigning replaces it directly, bypassing the cache
  /// mirror.
  LockdownState get current => state;
  set current(LockdownState next) => state = next;
}

/// Override that pins the lockdown provider to a [TestLockdownController]
/// locked to [categoryIds] (inactive when empty).
Override lockdownOverride([Set<String> categoryIds = const {}]) =>
    lockdownControllerProvider.overrideWith(
      () => TestLockdownController(LockdownState(categoryIds: categoryIds)),
    );
