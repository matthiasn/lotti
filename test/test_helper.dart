import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/lotti_logger.dart';

class WidgetTestBench extends StatelessWidget {
  const WidgetTestBench({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}

class RiverpodWidgetTestBench extends StatelessWidget {
  const RiverpodWidgetTestBench({
    required this.child,
    this.overrides = const [],
    super.key,
  });

  final Widget child;
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: WidgetTestBench(
        child: child,
      ),
    );
  }
}

/// Sets up test environment with fast logging
void setupTestEnvironment() {
  // Register only LottiLogger for tests
  if (!getIt.isRegistered<LottiLogger>()) {
    getIt.registerSingleton<LottiLogger>(LottiLogger());
  }
}

/// Cleans up test environment by resetting the service locator.
Future<void> teardownTestEnvironment() async {
  await getIt.reset();
}
