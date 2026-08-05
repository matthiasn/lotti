import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switch_chrome.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/get_it.dart';

/// Root widget above the ProviderScope. Deliberately Riverpod-free: on a
/// profile switch the entire scope below is discarded via a new generation
/// key, so every provider — including the getIt bridge overrides — rebinds
/// against the freshly registered service generation.
class LottiAppRoot extends StatefulWidget {
  const LottiAppRoot({
    required this.registry,
    required this.lifecycleHolder,
    super.key,
    @visibleForTesting this.appBuilder,
    @visibleForTesting this.teardownOverride,
    @visibleForTesting this.bootstrapOverride,
  });

  final ProfileRegistry registry;
  final AppLifecycleHolder lifecycleHolder;

  /// Test seam: replaces MyBeamerApp so widget tests can exercise the
  /// generation/splash machinery without booting the whole app shell.
  final WidgetBuilder? appBuilder;

  /// Test seams forwarded to the internally owned [ProfileSwitcher].
  final Future<void> Function()? teardownOverride;
  final Future<void> Function()? bootstrapOverride;

  @override
  State<LottiAppRoot> createState() => LottiAppRootState();
}

class LottiAppRootState extends State<LottiAppRoot> {
  int _generation = 0;
  bool _switching = false;
  late final ProfileSwitcher _switcher;

  @override
  void initState() {
    super.initState();
    _switcher = ProfileSwitcher(
      registry: widget.registry,
      lifecycleHolder: widget.lifecycleHolder,
      onSwitchStarted: () async {
        setState(() => _switching = true);
      },
      onSwitchCompleted: () {
        setState(() {
          _generation++;
          _switching = false;
        });
      },
      teardownOverride: widget.teardownOverride,
      bootstrapOverride: widget.bootstrapOverride,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_switching) {
      return const ProfileSwitchSplash();
    }
    return ProfileSwitcherScope(
      switcher: _switcher,
      child: ProviderScope(
        key: ValueKey('profile-gen-$_generation'),
        overrides: buildProviderOverrides(getIt<ProfileContext>()),
        child: widget.appBuilder != null
            ? Builder(builder: widget.appBuilder!)
            : const MyBeamerApp(),
      ),
    );
  }
}

/// Minimal full-screen splash shown while a profile switch tears down one
/// service generation and bootstraps the next.
///
/// Deliberately free of localization, providers AND of `MaterialApp` /
/// `Scaffold` — nothing from the old generation may be alive while it is on
/// screen, and either of those would silently pull in Flutter's default
/// LIGHT theme and paint the switch white. A `ColoredBox` under a
/// `Directionality` can only paint the colour it is given, which is the one
/// [ProfileSwitchChrome] carried across from the outgoing generation.
class ProfileSwitchSplash extends StatelessWidget {
  const ProfileSwitchSplash({this.chrome, super.key});

  /// Test seam; production reads the process-wide capture.
  final ProfileSwitchChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final resolved = chrome ?? ProfileSwitchChrome.instance;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: resolved.background,
        child: Center(
          child: CircularProgressIndicator(
            color: resolved.tokens.colors.interactive.enabled,
          ),
        ),
      ),
    );
  }
}

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
