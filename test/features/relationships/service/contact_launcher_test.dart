import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../mocks/mocks.dart';

ContactChannel _channel(ContactChannelType type, String value) =>
    ContactChannel(type: type, value: value);

void main() {
  final canLaunchCalls = <Uri>[];
  final launchCalls = <Uri>[];

  setUp(() {
    canLaunchCalls.clear();
    launchCalls.clear();
  });

  /// A launcher whose two platform calls are recorded and scripted, so both
  /// the URI handed to `url_launcher` and the answer coming back are under
  /// test control.
  UrlLauncherContactLauncher launcher({
    bool canLaunch = true,
    bool launched = true,
    bool throwOnCanLaunch = false,
    bool throwOnLaunch = false,
    MockDomainLogger? logger,
  }) => UrlLauncherContactLauncher(
    logger: logger ?? MockDomainLogger(),
    canLaunchUrl: (uri) async {
      canLaunchCalls.add(uri);
      if (throwOnCanLaunch) throw Exception('no handler');
      return canLaunch;
    },
    launchUrl: (uri) async {
      launchCalls.add(uri);
      if (throwOnLaunch) throw Exception('no handler');
      return launched;
    },
  );

  group('canLaunch', () {
    test('asks the platform about the URI the channel maps to', () async {
      await launcher().canLaunch(
        _channel(ContactChannelType.mobile, '+1 (555) 010-9999'),
        ContactAction.call,
      );

      expect(canLaunchCalls.single.toString(), 'tel:+15550109999');
    });

    test('reports true when the platform has a handler', () async {
      expect(
        await launcher().canLaunch(
          _channel(ContactChannelType.mobile, '+15550109999'),
          ContactAction.call,
        ),
        isTrue,
      );
    });

    test(
      'reports false when nothing on the device handles the scheme',
      () async {
        expect(
          await launcher(canLaunch: false).canLaunch(
            _channel(ContactChannelType.email, 'anna@example.com'),
            ContactAction.email,
          ),
          isFalse,
        );
      },
    );

    test('reports false without asking the platform when the pair produces '
        'no URI', () async {
      expect(
        await launcher().canLaunch(
          _channel(ContactChannelType.messaging, '@anna'),
          ContactAction.message,
        ),
        isFalse,
      );
      expect(
        canLaunchCalls,
        isEmpty,
        reason: 'a handle with no scheme must not reach url_launcher at all',
      );
    });

    test('reports false when the platform throws', () async {
      expect(
        await launcher(throwOnCanLaunch: true).canLaunch(
          _channel(ContactChannelType.mobile, '+15550109999'),
          ContactAction.call,
        ),
        isFalse,
      );
    });
  });

  group('launch', () {
    test('opens the URI the channel maps to', () async {
      await launcher().launch(
        _channel(ContactChannelType.mobile, '+15550109999'),
        ContactAction.message,
      );

      expect(launchCalls.single.toString(), 'sms:+15550109999');
    });

    test('opens a mail composer for an email channel', () async {
      await launcher().launch(
        _channel(ContactChannelType.email, 'anna@example.com'),
        ContactAction.email,
      );

      expect(launchCalls.single.toString(), 'mailto:anna@example.com');
    });

    test('reports whether the platform accepted the launch', () async {
      expect(
        await launcher(launched: false).launch(
          _channel(ContactChannelType.mobile, '+15550109999'),
          ContactAction.call,
        ),
        isFalse,
      );
    });

    test('does not launch an action the channel does not offer', () async {
      expect(
        await launcher().launch(
          _channel(ContactChannelType.phone, '+493090182'),
          ContactAction.message,
        ),
        isFalse,
      );
      expect(
        launchCalls,
        isEmpty,
        reason: 'a landline must never reach a message composer',
      );
    });

    test('reports false rather than throwing when no handler exists', () async {
      expect(
        await launcher(throwOnLaunch: true).launch(
          _channel(ContactChannelType.email, 'anna@example.com'),
          ContactAction.email,
        ),
        isFalse,
      );
    });
  });

  group('failure reporting', () {
    test('reports the scheme but never the number or address', () async {
      final logger = MockDomainLogger();

      await launcher(throwOnLaunch: true, logger: logger).launch(
        _channel(ContactChannelType.mobile, '+15550109999'),
        ContactAction.call,
      );

      final message =
          verify(
                () => logger.error(
                  LogDomain.navigation,
                  any<Object>(),
                  message: captureAny(named: 'message'),
                  stackTrace: any(named: 'stackTrace'),
                  subDomain: any(named: 'subDomain'),
                ),
              ).captured.single
              as String;

      expect(message, contains('tel:'));
      expect(
        message,
        isNot(contains('5550109999')),
        reason:
            'a contact channel in a log file is the same leak as a '
            'contact channel in AI context (ADR 0041 §5)',
      );
    });
  });

  group('contactLauncherProvider', () {
    test('provides the url_launcher-backed implementation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(contactLauncherProvider),
        isA<UrlLauncherContactLauncher>(),
      );
    });
  });

  group('production defaults', () {
    test('resolves its logger from getIt, and survives getIt not having '
        'one', () async {
      // No logger injected and none registered: a missing logger must not be
      // the reason a quick action fails.
      final bare = UrlLauncherContactLauncher(
        canLaunchUrl: (_) async => true,
        launchUrl: (_) async => throw Exception('no handler'),
      );

      expect(
        await bare.launch(
          _channel(ContactChannelType.mobile, '+15550109999'),
          ContactAction.call,
        ),
        isFalse,
      );
    });

    test('defaults to launching in an external application', () async {
      final platform = _RecordingUrlLauncherPlatform();
      UrlLauncherPlatform.instance = platform;

      // Only canLaunchUrl is injected, so the real default launch path runs.
      final real = UrlLauncherContactLauncher(
        logger: MockDomainLogger(),
        canLaunchUrl: (_) async => true,
      );

      final launched = await real.launch(
        _channel(ContactChannelType.mobile, '+15550109999'),
        ContactAction.call,
      );

      expect(launched, isTrue);
      expect(platform.launchedUrl, 'tel:+15550109999');
      expect(
        platform.launchedOptions!.mode,
        PreferredLaunchMode.externalApplication,
        reason:
            'a dialer must open as its own app, never inside an in-app '
            'web view',
      );
    });
  });
}

/// Captures what the real `launchUrl` hands to the platform.
class _RecordingUrlLauncherPlatform extends UrlLauncherPlatform {
  String? launchedUrl;
  LaunchOptions? launchedOptions;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchedOptions = options;
    return true;
  }

  @override
  LinkDelegate? get linkDelegate => null;
}
