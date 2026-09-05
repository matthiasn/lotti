import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/demo/ui/demo_entry_launcher.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockDemoModeGateway gateway;

  setUp(() {
    gateway = MockDemoModeGateway();
  });

  Widget host({
    required WidgetBuilder builder,
    List<Override> overrides = const [],
    Locale? locale,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: Builder(builder: builder)),
      ),
    );
  }

  group('launchDemoEnter', () {
    testWidgets('shows the blocking progress route and enters with the '
        'ambient locale', (tester) async {
      final entered = Completer<void>();
      when(
        () => gateway.enterDemo(locale: any(named: 'locale')),
      ).thenAnswer((_) => entered.future);

      await tester.pumpWidget(
        host(
          locale: const Locale('de'),
          builder: (context) => TextButton(
            onPressed: () =>
                unawaited(launchDemoEnter(context, gateway: gateway)),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DemoEnteringProgressPage), findsOneWidget);
      expect(find.text('Demo-Welt wird eingerichtet…'), findsOneWidget);
      verify(() => gateway.enterDemo(locale: const Locale('de'))).called(1);

      entered.complete();
      await tester.pump();
    });

    testWidgets('a failed entry removes the progress route instead of '
        'stranding the user on it, and surfaces an error toast', (
      tester,
    ) async {
      when(
        () => gateway.enterDemo(locale: any(named: 'locale')),
      ).thenAnswer((_) async => throw StateError('seed boom'));

      await tester.pumpWidget(
        host(
          builder: (context) => TextButton(
            onPressed: () =>
                unawaited(launchDemoEnter(context, gateway: gateway)),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DemoEnteringProgressPage), findsNothing);
      expect(find.text('go'), findsOneWidget, reason: 'host page restored');
      expect(
        find.text("Couldn't open the demo world — try again."),
        findsOneWidget,
        reason: 'the failed tap must not stay silent',
      );
    });

    testWidgets('a failure AFTER the progress route is fully installed '
        'removes exactly that route and logs the failure', (tester) async {
      final logger = MockDomainLogger();
      getIt.registerSingleton<DomainLogger>(logger);
      addTearDown(getIt.reset);
      final entered = Completer<void>();
      when(
        () => gateway.enterDemo(locale: any(named: 'locale')),
      ).thenAnswer((_) => entered.future);

      await tester.pumpWidget(
        host(
          builder: (context) => TextButton(
            onPressed: () =>
                unawaited(launchDemoEnter(context, gateway: gateway)),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DemoEnteringProgressPage), findsOneWidget);

      // The seed fails while the user is looking at the progress page.
      entered.completeError(StateError('seed boom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(DemoEnteringProgressPage),
        findsNothing,
        reason: 'the user must not be stranded on the progress page',
      );
      expect(find.text('go'), findsOneWidget);
      expect(
        find.text("Couldn't open the demo world — try again."),
        findsWidgets,
      );
      verify(
        () => logger.error(
          LogDomain.general,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'demoEntryLauncher',
        ),
      ).called(1);
    });

    testWidgets('without a gateway or ProfileSwitcherScope it is a no-op', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          builder: (context) => TextButton(
            onPressed: () => unawaited(launchDemoEnter(context)),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(DemoEnteringProgressPage), findsNothing);
    });
  });

  group('launchDemoReset', () {
    testWidgets('delegates to resetDemo under the same progress route', (
      tester,
    ) async {
      final reset = Completer<void>();
      when(
        () => gateway.resetDemo(locale: any(named: 'locale')),
      ).thenAnswer((_) => reset.future);

      await tester.pumpWidget(
        host(
          builder: (context) => TextButton(
            onPressed: () =>
                unawaited(launchDemoReset(context, gateway: gateway)),
            child: const Text('reset'),
          ),
        ),
      );
      await tester.tap(find.text('reset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DemoEnteringProgressPage), findsOneWidget);
      verify(() => gateway.resetDemo(locale: const Locale('en'))).called(1);
      reset.complete();
      await tester.pump();
    });
  });

  group('DemoTryButton', () {
    Widget button({required bool demoActive, required bool journalEmpty}) {
      return host(
        overrides: [
          demoModeActiveProvider.overrideWithValue(demoActive),
          demoJournalEmptyProvider.overrideWith((ref) async => journalEmpty),
        ],
        builder: (context) => DemoTryButton(gateway: gateway),
      );
    }

    testWidgets('hidden while the demo world is active', (tester) async {
      await tester.pumpWidget(button(demoActive: true, journalEmpty: true));
      await tester.pumpAndSettle();
      expect(find.text('Try the demo'), findsNothing);
    });

    testWidgets('hidden when the journal has entries — a filter miss must '
        'not advertise the demo', (tester) async {
      await tester.pumpWidget(button(demoActive: false, journalEmpty: false));
      await tester.pumpAndSettle();
      expect(find.text('Try the demo'), findsNothing);
    });

    testWidgets('visible on a truly empty journal; tapping enters the demo', (
      tester,
    ) async {
      when(
        () => gateway.enterDemo(locale: any(named: 'locale')),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(button(demoActive: false, journalEmpty: true));
      await tester.pumpAndSettle();

      expect(find.text('Try the demo'), findsOneWidget);
      await tester.tap(find.text('Try the demo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => gateway.enterDemo(locale: any(named: 'locale'))).called(1);
    });
  });
}
