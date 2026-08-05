import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/support_links.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

/// Pins the Manual override so the tests do not depend on a `SettingsDb`
/// registration; `null` is the shipped *Follow system* default.
class _FixedManualLanguageController extends ManualLanguageController {
  _FixedManualLanguageController(this._override);

  final ManualLanguage? _override;

  @override
  ManualLanguage? build() => _override;
}

void main() {
  setUpAll(() => registerFallbackValue(FakeLaunchOptions()));

  late MockUrlLauncher launcher;

  setUp(() {
    final original = UrlLauncherPlatform.instance;
    launcher = MockUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);
    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);
  });

  /// The last URL handed to the platform launcher.
  String launchedUrl() {
    final captured = verify(
      () => launcher.launchUrl(captureAny(), any()),
    ).captured;
    return captured.single as String;
  }

  Future<void> pumpRow(
    WidgetTester tester, {
    ManualLanguage? manualOverride,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ContactSupportRow(),
        theme: DesignSystemTheme.dark(),
        locale: locale,
        overrides: [
          manualLanguageControllerProvider.overrideWith(
            () => _FixedManualLanguageController(manualOverride),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  group('ContactSupportRow destinations', () {
    testWidgets('the mail icon opens a mail draft to the project', (
      tester,
    ) async {
      await pumpRow(tester);

      await tester.tap(find.byKey(contactSupportEmailKey));
      await tester.pump();

      expect(
        launchedUrl(),
        'mailto:$lottiContactEmail?subject=Lotti%20feedback',
      );
    });

    testWidgets('the mail subject comes from the active locale', (
      tester,
    ) async {
      await pumpRow(tester, locale: const Locale('de'));

      await tester.tap(find.byKey(contactSupportEmailKey));
      await tester.pump();

      // Not merely "some subject": a hardcoded English subject would still
      // pass a test that only checked for a `subject=` parameter.
      expect(launchedUrl(), contains('subject=Lotti-Feedback'));
    });

    testWidgets('the GitHub mark opens the repository', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.byKey(contactSupportGithubKey));
      await tester.pump();

      expect(launchedUrl(), lottiGithubUrl);
    });

    testWidgets('the Discord mark opens the community invite', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.byKey(contactSupportDiscordKey));
      await tester.pump();

      expect(launchedUrl(), lottiDiscordInviteUrl);
    });

    testWidgets('every destination opens outside the app', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.byKey(contactSupportGithubKey));
      await tester.pump();

      // In-app web views would strand the user inside a logbook that has no
      // browser chrome to get back out of.
      final options =
          verify(() => launcher.launchUrl(any(), captureAny())).captured.single
              as LaunchOptions;
      expect(options.mode, PreferredLaunchMode.externalApplication);
    });
  });

  group('ContactSupportRow manual link', () {
    testWidgets('follows the system locale when no override is stored', (
      tester,
    ) async {
      // Driven off a *non*-default platform locale on purpose. The test host
      // reports English, which is also the fallback, so asserting the base URL
      // here would pass just as happily against a resolver that ignored the
      // system locale entirely.
      tester.platformDispatcher.localeTestValue = const Locale('it');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await pumpRow(tester);

      await tester.tap(find.byKey(contactSupportManualKey));
      await tester.pump();

      expect(launchedUrl(), '${lottiManualBaseUrl}it/');
    });

    testWidgets('falls back to English for a locale the Manual lacks', (
      tester,
    ) async {
      // Japanese is not a published Manual language; English is the default
      // route and carries no locale segment.
      tester.platformDispatcher.localeTestValue = const Locale('ja');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await pumpRow(tester);

      await tester.tap(find.byKey(contactSupportManualKey));
      await tester.pump();

      expect(launchedUrl(), lottiManualBaseUrl);
    });

    testWidgets('lets a stored override win over the system locale', (
      tester,
    ) async {
      // The two inputs disagree — without this the override tests below could
      // not tell "read the override" from "read the locale".
      tester.platformDispatcher.localeTestValue = const Locale('it');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await pumpRow(tester, manualOverride: ManualLanguage.french);

      await tester.tap(find.byKey(contactSupportManualKey));
      await tester.pump();

      expect(launchedUrl(), '${lottiManualBaseUrl}fr/');
    });

    testWidgets('honours a stored language override', (tester) async {
      await pumpRow(tester, manualOverride: ManualLanguage.french);

      await tester.tap(find.byKey(contactSupportManualKey));
      await tester.pump();

      expect(launchedUrl(), '${lottiManualBaseUrl}fr/');
    });

    testWidgets('resolves the same URL the Settings row would', (tester) async {
      await pumpRow(tester, manualOverride: ManualLanguage.german);

      await tester.tap(find.byKey(contactSupportManualKey));
      await tester.pump();

      // Both surfaces go through `openManualForCurrentLocale`; this is the
      // assertion that fails if one of them grows its own resolution.
      expect(
        launchedUrl(),
        manualUriFor(
          systemLocale: const Locale('en'),
          override: ManualLanguage.german,
        ).toString(),
      );
    });
  });

  group('ContactSupportRow failure handling', () {
    testWidgets('survives a platform with no handler for the scheme', (
      tester,
    ) async {
      when(
        () => launcher.launchUrl(any(), any()),
      ).thenThrow(PlatformException(code: 'NO_HANDLER'));

      await pumpRow(tester);
      await tester.tap(find.byKey(contactSupportEmailKey));
      await tester.pump();

      // A desktop with no mail client configured is the common case. The row
      // fires launches without awaiting them, so an uncaught rejection here
      // would surface as an unhandled async error rather than a quiet no-op.
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a launcher that declines without throwing', (
      tester,
    ) async {
      final logger = MockDomainLogger();
      getIt.registerSingleton<DomainLogger>(logger);
      addTearDown(() => getIt.unregister<DomainLogger>());
      when(
        () => launcher.launchUrl(any(), any()),
      ).thenAnswer((_) async => false);

      await pumpRow(tester);
      await tester.tap(find.byKey(contactSupportDiscordKey));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // A `false` return is the launcher declining rather than failing, and
      // is just as invisible to the user as a throw — so it has to leave the
      // same trace behind, not be swallowed as if it had worked.
      verify(
        () => logger.error(
          LogDomain.navigation,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'ContactSupportRow',
          message: any(named: 'message'),
        ),
      ).called(1);
    });

    testWidgets('reports nothing when the launch succeeds', (tester) async {
      final logger = MockDomainLogger();
      getIt.registerSingleton<DomainLogger>(logger);
      addTearDown(() => getIt.unregister<DomainLogger>());

      await pumpRow(tester);
      await tester.tap(find.byKey(contactSupportGithubKey));
      await tester.pump();

      verifyNever(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      );
    });

    testWidgets('stays quiet when no logger is registered', (tester) async {
      // The row renders in surfaces that come up before service registration
      // in tests and screenshot harnesses; reaching for an absent
      // `DomainLogger` would turn a dead link into a crash.
      expect(getIt.isRegistered<DomainLogger>(), isFalse);
      when(
        () => launcher.launchUrl(any(), any()),
      ).thenThrow(PlatformException(code: 'NO_HANDLER'));

      await pumpRow(tester);
      await tester.tap(find.byKey(contactSupportManualKey));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('ContactSupportRow presentation', () {
    testWidgets('uses the localized contact label for the mail action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, locale: const Locale('de'));

      expect(find.text('Kontaktiere uns'), findsNothing);
      expect(find.bySemanticsLabel('Kontaktiere uns'), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(contactSupportEmailKey),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'Kontaktiere uns');
      handle.dispose();
    });

    testWidgets('renders both brand marks from their bundled assets', (
      tester,
    ) async {
      await pumpRow(tester);
      await tester.pumpAndSettle();

      final assets = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((svg) => (svg.bytesLoader as SvgAssetLoader).assetName)
          .toList();
      expect(assets, containsAll([githubIconAsset, discordIconAsset]));
    });

    testWidgets('tints the brand marks to match the font glyph beside them', (
      tester,
    ) async {
      await pumpRow(tester);
      await tester.pumpAndSettle();

      // The marks are monochrome files; without the icon-theme tint they
      // would paint solid black on a dark rail.
      //
      // Anchored on the Manual glyph specifically so this remains independent
      // of icon order while still proving font glyphs and brand marks inherit
      // the same row theme.
      final manualTheme = IconTheme.of(
        tester.element(
          find
              .descendant(
                of: find.byKey(contactSupportManualKey),
                matching: find.byType(Icon),
              )
              .first,
        ),
      );
      final github = tester.widget<SvgPicture>(
        find
            .descendant(
              of: find.byKey(contactSupportGithubKey),
              matching: find.byType(SvgPicture),
            )
            .first,
      );
      expect(
        github.colorFilter,
        ColorFilter.mode(manualTheme.color!, BlendMode.srcIn),
      );
      expect(github.width, manualTheme.size);
    });
  });
}
