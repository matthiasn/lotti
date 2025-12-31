import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/l10n/app_localizations.dart';

import 'widget_test_utils.dart';

class WidgetTestBench extends StatelessWidget {
  const WidgetTestBench({
    required this.child,
    this.mediaQueryData,
    super.key,
  });

  final Widget child;
  final MediaQueryData? mediaQueryData;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = mediaQueryData ?? phoneMediaQueryData;

    return MediaQuery(
      data: mediaQuery,
      child: MaterialApp(
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

    return MediaQuery(
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
    return ProviderScope(
      overrides: overrides,
      child: WidgetTestBench(
        mediaQueryData: mediaQueryData,
        child: child,
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
    return ProviderScope(
      overrides: overrides,
      child: DarkWidgetTestBench(
        mediaQueryData: mediaQueryData,
        child: child,
      ),
    );
  }
}
