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
import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockDemoModeGateway gateway;

  setUp(() {
    gateway = MockDemoModeGateway();
    // Nothing left to download unless a test says otherwise: no prompt.
    when(gateway.demoMediaBytesAwaitingChoice).thenAnswer((_) async => 0);
  });

  Widget host({
    required WidgetBuilder builder,
    List<Override> overrides = const [],
    Locale? locale,
  }) {
    return ProviderScope(
      overrides: withServiceOverrides(overrides),
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
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
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
      verify(
        () => gateway.enterDemo(
          locale: const Locale('de'),
          // ignore: avoid_redundant_argument_values
          downloadMedia: false,
        ),
      ).called(1);

      entered.complete();
      await tester.pump();
    });

    testWidgets('a failed entry removes the progress route instead of '
        'stranding the user on it, and surfaces an error toast', (
      tester,
    ) async {
      when(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
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
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
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

  group('launchDemoEnter photo prompt', () {
    const bytes = 26544434;

    Future<void> tapGo(WidgetTester tester) async {
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
    }

    setUp(() {
      when(
        gateway.demoMediaBytesAwaitingChoice,
      ).thenAnswer((_) async => bytes);
      when(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
      ).thenAnswer((_) async {});
    });

    testWidgets('asks with the download size before entering anything', (
      tester,
    ) async {
      await tapGo(tester);

      expect(find.text('Download the demo photos?'), findsOneWidget);
      expect(find.textContaining('a 26.6 MB download'), findsOneWidget);
      expect(find.text('Download (26.6 MB)'), findsOneWidget);
      expect(find.byType(DemoEnteringProgressPage), findsNothing);
      verifyNever(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
      );
    });

    testWidgets('choosing to download enters with the photos', (tester) async {
      await tapGo(tester);
      await tester.tap(find.text('Download (26.6 MB)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: true,
        ),
      ).called(1);
    });

    testWidgets('continuing without photos enters without them', (
      tester,
    ) async {
      await tapGo(tester);
      await tester.tap(find.text('Continue without photos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          // ignore: avoid_redundant_argument_values
          downloadMedia: false,
        ),
      ).called(1);
    });

    testWidgets('dismissing the prompt enters nothing', (tester) async {
      await tapGo(tester);
      Navigator.of(
        tester.element(find.text('Download the demo photos?')),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Download the demo photos?'), findsNothing);
      expect(find.byType(DemoEnteringProgressPage), findsNothing);
      verifyNever(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
      );
    });

    testWidgets('with nothing left to download it enters without asking', (
      tester,
    ) async {
      when(gateway.demoMediaBytesAwaitingChoice).thenAnswer((_) async => 0);

      await tapGo(tester);

      expect(find.text('Download the demo photos?'), findsNothing);
      verify(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          // ignore: avoid_redundant_argument_values
          downloadMedia: false,
        ),
      ).called(1);
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
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(button(demoActive: false, journalEmpty: true));
      await tester.pumpAndSettle();

      expect(find.text('Try the demo'), findsOneWidget);
      await tester.tap(find.text('Try the demo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      verify(
        () => gateway.enterDemo(
          locale: any(named: 'locale'),
          downloadMedia: any(named: 'downloadMedia'),
        ),
      ).called(1);
    });
  });
}
