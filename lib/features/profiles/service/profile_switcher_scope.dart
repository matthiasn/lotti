import 'package:flutter/widgets.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';

/// Exposes the [ProfileSwitcher] to the widget tree. Mounted ABOVE the
/// ProviderScope, so it survives generation rebuilds and can be reached
/// from any generation's widgets.
class ProfileSwitcherScope extends InheritedWidget {
  const ProfileSwitcherScope({
    required this.switcher,
    required super.child,
    super.key,
  });

  final ProfileSwitcher switcher;

  static ProfileSwitcher of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ProfileSwitcherScope>();
    assert(scope != null, 'No ProfileSwitcherScope found in context');
    return scope!.switcher;
  }

  /// Like [of], but null when no scope is mounted — for surfaces that also
  /// build in bare test harnesses without profile plumbing.
  static ProfileSwitcher? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ProfileSwitcherScope>()
        ?.switcher;
  }

  @override
  bool updateShouldNotify(ProfileSwitcherScope oldWidget) =>
      switcher != oldWidget.switcher;
}
