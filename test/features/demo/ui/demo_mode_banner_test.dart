import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/demo/state/demo_mode_gateway.dart';
import 'package:lotti/features/demo/ui/demo_mode_banner.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const childKey = Key('demo-banner-child');

  Widget host({
    List<Override> overrides = const [],
    Widget? child,
    DemoModeGateway? gateway,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47),
        ),
        child: MaterialApp(
          theme: resolveTestTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DemoModeScaffold(
            gateway: gateway,
            child: child ?? const SizedBox.expand(key: childKey),
          ),
        ),
      ),
    );
  }

  group('DemoModeScaffold', () {
    testWidgets('outside demo mode the child passes through unwrapped', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      expect(find.byType(DemoModeBanner), findsNothing);
      expect(find.byKey(childKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(childKey)).dy,
        0,
        reason: 'no banner height reserved',
      );
    });

    testWidgets('in demo mode the banner reserves its height structurally '
        'and absorbs the top safe-area', (tester) async {
      double? childTopPadding;
      await tester.pumpWidget(
        host(
          overrides: [demoModeActiveProvider.overrideWithValue(true)],
          child: Builder(
            key: childKey,
            builder: (context) {
              childTopPadding = MediaQuery.of(context).padding.top;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      expect(find.byType(DemoModeBanner), findsOneWidget);
      expect(
        find.text('Demo world — your journal is untouched'),
        findsOneWidget,
      );
      expect(find.text('Exit'), findsOneWidget);

      final bannerHeight = tester.getSize(find.byType(DemoModeBanner)).height;
      expect(
        bannerHeight,
        greaterThan(47),
        reason: 'banner swallows the 47px status-bar inset plus its content',
      );
      expect(
        tester.getTopLeft(find.byKey(childKey)).dy,
        bannerHeight,
        reason: 'child starts exactly below the banner — never overlaid',
      );
      expect(
        childTopPadding,
        0,
        reason:
            'removeTop: the child must not pad for a status bar the '
            'banner already covers',
      );
    });
  });

  group('copy-failure notice', () {
    setUp(DemoCopyFailureNotices.instance.reset);
    tearDown(DemoCopyFailureNotices.instance.reset);

    testWidgets('a failure reported AFTER the scaffold mounted (the copy '
        'applies post-switch, in this generation) surfaces as an error '
        'toast in the REAL generation', (tester) async {
      await tester.pumpWidget(
        host(
          child: const Scaffold(body: SizedBox.expand(key: childKey)),
        ),
      );
      expect(
        find.byType(DemoModeBanner),
        findsNothing,
        reason: 'the real generation shows no banner — only the toast',
      );

      DemoCopyFailureNotices.instance.report();
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Copying your demo work failed — everything is still in the '
          'demo world, so you can try again.',
        ),
        findsOneWidget,
      );
      expect(
        DemoCopyFailureNotices.instance.consume(),
        isFalse,
        reason: 'the notice is consumed by the toast, never re-shown',
      );
    });

    testWidgets('a failure reported BEFORE the scaffold mounted (the apply '
        'failed while the switch splash was still up) is drained on the '
        'first frame', (tester) async {
      DemoCopyFailureNotices.instance.report();

      await tester.pumpWidget(
        host(
          child: const Scaffold(body: SizedBox.expand(key: childKey)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Copying your demo work failed — everything is still in the '
          'demo world, so you can try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a report that arrives with no mountable toast target stays '
        'PENDING — draining it before the target is checked would swallow '
        'the failure and leave the user with no feedback at all', (
      tester,
    ) async {
      // A sheetContext resolving to a dead element is exactly the state
      // between a generation switch and the new navigator's first frame.
      late BuildContext dead;
      await tester.pumpWidget(
        MaterialApp(
          theme: resolveTestTheme(),
          home: Builder(
            builder: (context) {
              dead = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(dead.mounted, isFalse);

      DemoCopyFailureNotices.instance.report();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: resolveTestTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DemoModeScaffold(
              sheetContext: () => dead,
              child: const Scaffold(body: SizedBox.expand(key: childKey)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        DemoCopyFailureNotices.instance.consume(),
        isTrue,
        reason:
            'the failure must survive an unusable target, so a later '
            'listener or post-frame drain can still surface it',
      );
    });

    testWidgets('unmounting the scaffold detaches its listener — a later '
        'report stays pending instead of reaching a dead context', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          child: const Scaffold(body: SizedBox.expand(key: childKey)),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      DemoCopyFailureNotices.instance.report();
      await tester.pump();

      expect(
        DemoCopyFailureNotices.instance.consume(),
        isTrue,
        reason:
            'no scaffold was mounted, so the notice must survive for the '
            'next generation to drain',
      );
    });
  });

  group('DemoModeBanner exit affordances', () {
    late Directory demoRoot;
    late MockDemoModeGateway gateway;

    setUp(() async {
      final mocks = await setUpTestGetIt();
      demoRoot = Directory.systemTemp.createTempSync('lotti_banner_');
      getIt.registerSingleton<Directory>(demoRoot);
      gateway = MockDemoModeGateway();
      // The exit sheet's default candidate loader reads the active journal.
      when(
        () => mocks.journalDb.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          ids: any(named: 'ids'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mocks.journalDb.linksForEntryIds(any()),
      ).thenAnswer((_) async => []);
      // ... and the active AI config repository for the AI setup section.
      final aiRepo = MockAiConfigRepository();
      when(
        () => aiRepo.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => []);
      getIt.registerSingleton<AiConfigRepository>(aiRepo);
    });

    tearDown(() async {
      await tearDownTestGetIt();
      if (demoRoot.existsSync()) {
        await demoRoot.delete(recursive: true);
      }
    });

    testWidgets('tapping the Exit button opens the exit sheet', (tester) async {
      await tester.pumpWidget(
        host(
          overrides: [demoModeActiveProvider.overrideWithValue(true)],
          gateway: gateway,
        ),
      );

      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(find.text('Leave the demo?'), findsOneWidget);
      expect(
        find.text('Your demo world stays saved — you can come back anytime.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the strip itself opens the exit sheet too', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          overrides: [demoModeActiveProvider.overrideWithValue(true)],
          gateway: gateway,
        ),
      );

      await tester.tap(
        find.text('Demo world — your journal is untouched'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leave the demo?'), findsOneWidget);
    });
  });
}
