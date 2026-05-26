import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/l10n/app_localizations.dart';

import 'widget_test_utils.dart';

class WidgetTestBench extends StatelessWidget {
  const WidgetTestBench({
    required this.child,
    this.overrides = const [],
    this.theme,
    this.mediaQueryData,
    this.surfaceConstraints,
    super.key,
  });

  final Widget child;
  final List<Override> overrides;
  final ThemeData? theme;
  final MediaQueryData? mediaQueryData;

  /// Override the inner ConstrainedBox that wraps [child]. Defaults to
  /// `BoxConstraints(minHeight: 800, minWidth: 800)` so most widget tests
  /// render at a comfortable desktop size. Pass a tight width (e.g.
  /// `BoxConstraints.tightFor(width: 360)`) when testing responsive
  /// behaviour at narrow widths — typical use-case is reproducing a
  /// modal overflow at the actual width WoltModalSheet uses on desktop.
  final BoxConstraints? surfaceConstraints;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = mediaQueryData ?? phoneMediaQueryData;
    final constraints =
        surfaceConstraints ??
        const BoxConstraints(minHeight: 800, minWidth: 800);

    return ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: mediaQuery,
        child: MaterialApp(
          theme: resolveTestTheme(theme),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConstrainedBox(
              constraints: constraints,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class DarkWidgetTestBench extends StatelessWidget {
  const DarkWidgetTestBench({
    required this.child,
    this.mediaQueryData,
    super.key,
  });

  final Widget child;
  final MediaQueryData? mediaQueryData;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = mediaQueryData ?? phoneMediaQueryData;

    return ProviderScope(
      child: MediaQuery(
        data: mediaQuery,
        child: MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 800,
                minWidth: 800,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class RiverpodWidgetTestBench extends StatelessWidget {
  const RiverpodWidgetTestBench({
    required this.child,
    this.overrides = const [],
    this.mediaQueryData,
    super.key,
  });

  final Widget child;
  final List<Override> overrides;
  final MediaQueryData? mediaQueryData;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = mediaQueryData ?? phoneMediaQueryData;

    return ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: mediaQuery,
        child: MaterialApp(
          theme: resolveTestTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 800,
                minWidth: 800,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class DarkRiverpodWidgetTestBench extends StatelessWidget {
  const DarkRiverpodWidgetTestBench({
    required this.child,
    this.overrides = const [],
    this.mediaQueryData,
    super.key,
  });

  final Widget child;
  final List<Override> overrides;
  final MediaQueryData? mediaQueryData;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = mediaQueryData ?? phoneMediaQueryData;

    return ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: mediaQuery,
        child: MaterialApp(
          theme: resolveTestTheme(ThemeData.dark()),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 800,
                minWidth: 800,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
