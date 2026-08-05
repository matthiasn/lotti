import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/app_bootstrap.dart';
import 'package:lotti/app_root.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    hide aiConfigRepositoryProvider;
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/repository/profile_registry.dart';
import 'package:lotti/features/profiles/service/profile_switch_chrome.dart';
import 'package:lotti/features/profiles/service/profile_switcher.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

import 'mocks/mocks.dart';

void main() {
  group('LottiAppRoot', () {
    late Directory realRoot;
    late ProfileRegistry registry;

    setUp(() async {
      await getIt.reset();
      realRoot = Directory.systemTemp.createTempSync('lotti_app_root_');
      registry = ProfileRegistry(realRoot: realRoot);
    });

    tearDown(() async {
      await getIt.reset();
      if (realRoot.existsSync()) {
        await realRoot.delete(recursive: true);
      }
    });

    void registerBridgeSingletons(Profile profile) {
      getIt
        ..registerSingleton<ProfileContext>(
          ProfileContext.forProfile(
            profile: profile,
            root: registry.rootFor(profile),
          ),
        )
        ..registerSingleton<Maintenance>(MockMaintenance())
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<SyncDatabase>(MockSyncDatabase())
        ..registerSingleton<LoggingService>(MockLoggingService())
        ..registerSingleton<OutboxService>(MockOutboxService())
        ..registerSingleton<AiConfigRepository>(MockAiConfigRepository());
      // The real world advertises sync, so its provider bridge resolves a
      // MatrixService; guest worlds never construct one.
      if (profile.type != ProfileType.guest) {
        getIt.registerSingleton<MatrixService>(MockMatrixService());
      }
    }

    testWidgets(
      'a switch shows the splash, then rebuilds a fresh generation',
      (tester) async {
        late Profile guest1;
        late Profile guest2;
        // Registry work is real file IO — it must run outside the
        // FakeAsync test zone.
        await tester.runAsync(() async {
          guest1 = await registry.createGuestProfile(name: 'Demo 1');
          guest2 = await registry.createGuestProfile(name: 'Demo 2');
          await registry.setActiveProfile(guest1.id);
        });
        registerBridgeSingletons(guest1);

        var generationBuilds = 0;
        late BuildContext appContext;
        final bootstrapGate = Completer<void>();
        final bootstrapEntered = Completer<void>();
        await tester.pumpWidget(
          LottiAppRoot(
            registry: registry,
            lifecycleHolder: AppLifecycleHolder(),
            appBuilder: (context) {
              appContext = context;
              generationBuilds++;
              return const Text(
                'generation-alive',
                textDirection: TextDirection.ltr,
              );
            },
            teardownOverride: () async {},
            // Parks the switch after the splash is up, so the splash state
            // is deterministically observable.
            bootstrapOverride: () {
              bootstrapEntered.complete();
              return bootstrapGate.future;
            },
          ),
        );

        expect(find.text('generation-alive'), findsOneWidget);
        final buildsBeforeSwitch = generationBuilds;

        final switcher = ProfileSwitcherScope.of(appContext);
        late Future<void> pending;
        await tester.runAsync(() async {
          pending = switcher.switchTo(guest2.id);
          // Registry IO and the splash setState land, the frame settle
          // passes, and the switch parks on the bootstrap gate — a
          // deterministic signal, no wall-clock sleep. Frames keep being
          // produced so the frame settle can pass.
          while (!bootstrapEntered.isCompleted) {
            await tester.pump(const Duration(milliseconds: 16));
            await Future<void>.delayed(Duration.zero);
          }
        });
        await tester.pump();

        // While switching, the whole tree is the splash.
        expect(find.byType(ProfileSwitchSplash), findsOneWidget);
        expect(find.text('generation-alive'), findsNothing);

        bootstrapGate.complete();
        await tester.runAsync(() => pending);
        await tester.pump();

        // A NEW generation was built (fresh ProviderScope key), not a
        // resumed old one.
        expect(find.text('generation-alive'), findsOneWidget);
        expect(generationBuilds, greaterThan(buildsBeforeSwitch));
        final reloaded = await tester.runAsync(() => registry.load());
        expect(reloaded!.activeProfileId, guest2.id);
      },
    );

    // The white-flash regression: every frame between the last themed frame
    // of the outgoing generation and the first themed frame of the incoming
    // one must stay on the carried-over background. A `MaterialApp` or
    // `Scaffold` anywhere in the switch chrome silently reintroduces
    // Flutter's default LIGHT theme, which is what users saw strobe.
    for (final direction in const [
      (label: 'entering the demo', toGuest: true),
      (label: 'leaving the demo', toGuest: false),
    ]) {
      testWidgets(
        'no frame paints the default light background while ${direction.label}',
        (tester) async {
          addTearDown(ProfileSwitchChrome.instance.reset);
          late Profile guest;
          await tester.runAsync(() async {
            guest = await registry.createGuestProfile(name: 'Demo');
            await registry.setActiveProfile(
              direction.toGuest ? Profile.realProfileId : guest.id,
            );
          });
          final state = await tester.runAsync(() => registry.load());
          final from = state!.profileById(
            direction.toGuest ? Profile.realProfileId : guest.id,
          )!;
          final to = direction.toGuest ? guest.id : Profile.realProfileId;
          registerBridgeSingletons(from);

          late BuildContext appContext;
          final bootstrapGate = Completer<void>();
          final bootstrapEntered = Completer<void>();
          await tester.pumpWidget(
            LottiAppRoot(
              registry: registry,
              lifecycleHolder: AppLifecycleHolder(),
              // Stands in for MyBeamerApp: a themed generation that
              // publishes its resolved chrome exactly as the real app does.
              appBuilder: (context) {
                appContext = context;
                ProfileSwitchChrome.instance.capture(DesignSystemTheme.dark());
                return ColoredBox(
                  color: DesignSystemTheme.dark().scaffoldBackgroundColor,
                  child: const SizedBox.expand(),
                );
              },
              teardownOverride: () async {},
              bootstrapOverride: () {
                bootstrapEntered.complete();
                return bootstrapGate.future;
              },
            ),
          );

          final dark = DesignSystemTheme.dark().scaffoldBackgroundColor;
          final painted = <Color>{};
          void sample() {
            final boxes = tester.widgetList<ColoredBox>(
              find.byType(ColoredBox),
            );
            painted.addAll(boxes.map((box) => box.color));
            // No frame may mount chrome that carries a default theme.
            expect(find.byType(MaterialApp), findsNothing);
            expect(find.byType(Scaffold), findsNothing);
          }

          sample();
          final switcher = ProfileSwitcherScope.of(appContext);
          late Future<void> pending;
          await tester.runAsync(() async {
            pending = switcher.switchTo(to);
            while (!bootstrapEntered.isCompleted) {
              await tester.pump(const Duration(milliseconds: 16));
              await Future<void>.delayed(Duration.zero);
              sample();
            }
          });
          await tester.pump();
          // Mid-switch: the splash is up and painting the dark background
          // it carried over — not merely absent of white.
          expect(find.byType(ProfileSwitchSplash), findsOneWidget);
          expect(
            tester
                .widget<ColoredBox>(
                  find.descendant(
                    of: find.byType(ProfileSwitchSplash),
                    matching: find.byType(ColoredBox),
                  ),
                )
                .color,
            dark,
          );
          sample();

          bootstrapGate.complete();
          await tester.runAsync(() => pending);
          await tester.pump();
          sample();

          expect(painted, {dark});
          expect(
            painted,
            isNot(contains(ThemeData.light().scaffoldBackgroundColor)),
          );
          expect(painted, isNot(contains(const ColorScheme.light().surface)));
        },
      );
    }
  });

  group('ProfileSwitchSplash', () {
    tearDown(ProfileSwitchChrome.instance.reset);

    testWidgets('paints the carried-over background, with no app chrome', (
      tester,
    ) async {
      ProfileSwitchChrome.instance.capture(DesignSystemTheme.dark());

      await tester.pumpWidget(const ProfileSwitchSplash());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Deliberately provider- and localization-free: nothing from the old
      // generation may be needed to render it. And deliberately WITHOUT
      // MaterialApp/Scaffold — either would fall back to Flutter's default
      // light theme and paint the switch white.
      expect(find.byType(Scaffold), findsNothing);
      expect(find.byType(MaterialApp), findsNothing);
      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
        DesignSystemTheme.dark().scaffoldBackgroundColor,
      );
    });

    testWidgets('follows a light host into the light background', (
      tester,
    ) async {
      ProfileSwitchChrome.instance.capture(DesignSystemTheme.light());

      await tester.pumpWidget(const ProfileSwitchSplash());

      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
        DesignSystemTheme.light().scaffoldBackgroundColor,
      );
    });

    testWidgets('falls back to the design-system dark background on a cold '
        'boot, where no generation has published a theme yet', (tester) async {
      expect(ProfileSwitchChrome.instance.hasCapture, isFalse);

      await tester.pumpWidget(const ProfileSwitchSplash());

      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
        DesignSystemTheme.dark().scaffoldBackgroundColor,
      );
      // Never Flutter's default light scaffold — that is the white flash.
      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox)).color,
        isNot(ThemeData.light().scaffoldBackgroundColor),
      );
    });
  });

  group('ProfileSwitchChrome', () {
    tearDown(ProfileSwitchChrome.instance.reset);

    test('capture records the resolved background and brightness', () {
      final chrome = ProfileSwitchChrome.instance
        ..capture(
          DesignSystemTheme.light(),
        );

      expect(chrome.hasCapture, isTrue);
      expect(
        chrome.background,
        DesignSystemTheme.light().scaffoldBackgroundColor,
      );
      expect(chrome.brightness, Brightness.light);
      expect(chrome.tokens, dsTokensLight);

      chrome.capture(DesignSystemTheme.dark());
      expect(chrome.brightness, Brightness.dark);
      expect(chrome.tokens, dsTokensDark);
    });

    test('reset returns it to the cold-boot fallback', () {
      final chrome = ProfileSwitchChrome.instance
        ..capture(DesignSystemTheme.light())
        ..reset();

      expect(chrome.hasCapture, isFalse);
      expect(chrome.background, dsTokensDark.colors.background.level01);
      expect(chrome.brightness, Brightness.dark);
    });
  });

  group('ProfileSwitcherScope', () {
    ProfileSwitcher buildSwitcher(Directory root) => ProfileSwitcher(
      registry: ProfileRegistry(realRoot: root),
      lifecycleHolder: AppLifecycleHolder(),
      onSwitchStarted: () async {},
      onSwitchCompleted: () {},
      settleFrame: () async {},
      teardownOverride: () async {},
      bootstrapOverride: () async {},
    );

    testWidgets('of() resolves the switcher from above the scope', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('lotti_scope_');
      addTearDown(() => root.deleteSync(recursive: true));
      final switcher = buildSwitcher(root);
      late ProfileSwitcher resolved;

      await tester.pumpWidget(
        ProfileSwitcherScope(
          switcher: switcher,
          child: Builder(
            builder: (context) {
              resolved = ProfileSwitcherScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(identical(resolved, switcher), isTrue);
    });

    testWidgets('updateShouldNotify fires only on a new switcher instance', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync('lotti_scope_');
      addTearDown(() => root.deleteSync(recursive: true));
      final switcherA = buildSwitcher(root);
      final switcherB = buildSwitcher(root);

      final scopeA = ProfileSwitcherScope(
        switcher: switcherA,
        child: const SizedBox.shrink(),
      );
      final scopeSameSwitcher = ProfileSwitcherScope(
        switcher: switcherA,
        child: const SizedBox.shrink(),
      );
      final scopeB = ProfileSwitcherScope(
        switcher: switcherB,
        child: const SizedBox.shrink(),
      );

      expect(scopeSameSwitcher.updateShouldNotify(scopeA), isFalse);
      expect(scopeB.updateShouldNotify(scopeA), isTrue);
    });
  });
}
