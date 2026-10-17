import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide isMobile;
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_providers.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_store.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/secure_storage.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/test_get_it.dart';
import '../../../mocks/mocks.dart';

class _MemoryStore extends SyncSubscriptionStore {
  _MemoryStore(this.record) : super(MockSecureStorage());

  final SyncSubscriptionRecord? record;

  @override
  Future<SyncSubscriptionRecord?> load() async => record;
}

const _record = SyncSubscriptionRecord(
  entitlement: SyncEntitlement(id: 'ent-1', authSecret: 'auth'),
  claimSecret: 'claim',
);
final _portal = Uri.parse('https://customer-portal.paddle.com/cpl_1');

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(FakeLaunchOptions());
  });

  test('a build without LOTTI_SYNC_API_URL offers no subscription', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(syncSubscriptionBaseUrlProvider), isNull);
    expect(container.read(syncSubscriptionAvailableProvider), isFalse);
    expect(container.read(syncSubscriptionApiProvider), isNull);
  });

  group('syncServiceBaseUrl', () {
    final cases = <(String, bool), String?>{
      ('https://api.example.com', true): 'https://api.example.com/',
      ('https://api.example.com/sync', true): 'https://api.example.com/sync/',
      ('https://api.example.com/sync/', true): 'https://api.example.com/sync/',
      ('http://api.example.com', true): null,
      ('https://', true): null,
      ('', true): null,
      ('not a url at all', true): null,
      // Store builds switch web checkout off whatever the URL says.
      ('https://api.example.com', false): null,
    };
    for (final MapEntry(key: (raw, allowed), value: expected)
        in cases.entries) {
      test('"$raw" (allowed: $allowed) → $expected', () {
        expect(
          syncServiceBaseUrl(raw, allowed: allowed)?.toString(),
          expected,
        );
      });
    }
  });

  test('the store reads the shared keystore', () async {
    final storage = MockSecureStorage();
    when(
      () => storage.read(key: syncSubscriptionKey),
    ).thenAnswer((_) async => null);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<SecureStorage>(storage);
      },
    );
    addTearDown(tearDownTestGetIt);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(syncSubscriptionStoreProvider).load(), isNull);
    verify(() => storage.read(key: syncSubscriptionKey)).called(1);
  });

  test('a configured URL yields a client rooted at it', () {
    final container = ProviderContainer(
      overrides: [
        syncSubscriptionBaseUrlProvider.overrideWithValue(
          Uri.parse('https://api.example.com/'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(syncSubscriptionAvailableProvider), isTrue);
    expect(
      container.read(syncSubscriptionApiProvider)!.baseUrl,
      Uri.parse('https://api.example.com/'),
    );
  });

  group('checkout launcher', () {
    late MockUrlLauncher platform;
    late UrlLauncherPlatform original;
    late bool wasMobile;

    setUp(() {
      original = UrlLauncherPlatform.instance;
      platform = MockUrlLauncher();
      UrlLauncherPlatform.instance = platform;
      wasMobile = isMobile;
      when(
        () => platform.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);
    });

    tearDown(() {
      UrlLauncherPlatform.instance = original;
      isMobile = wasMobile;
    });

    for (final (mobile, mode) in [
      (true, PreferredLaunchMode.inAppBrowserView),
      (false, PreferredLaunchMode.externalApplication),
    ]) {
      test('uses ${mode.name} when mobile is $mobile', () async {
        isMobile = mobile;
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          await container.read(syncCheckoutLauncherProvider)(_portal),
          isTrue,
        );

        final options =
            verify(
                  () => platform.launchUrl(_portal.toString(), captureAny()),
                ).captured.single
                as LaunchOptions;
        expect(options.mode, mode);
      });
    }
  });

  group('portal opener', () {
    late MockSyncSubscriptionApi api;
    late List<Uri> launched;

    setUp(() {
      api = MockSyncSubscriptionApi();
      launched = [];
      when(() => api.portalUrl(any())).thenAnswer((_) async => _portal);
    });

    ProviderContainer containerWith({
      SyncSubscriptionApi? withApi,
      SyncSubscriptionRecord? record,
    }) {
      final container = ProviderContainer(
        overrides: [
          syncSubscriptionApiProvider.overrideWithValue(withApi),
          syncSubscriptionStoreProvider.overrideWithValue(_MemoryStore(record)),
          syncCheckoutLauncherProvider.overrideWithValue((url) async {
            launched.add(url);
            return true;
          }),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('opens the portal of the stored entitlement', () async {
      final container = containerWith(withApi: api, record: _record);

      expect(
        await container.read(openSyncSubscriptionPortalProvider)(),
        isTrue,
      );
      expect(launched, [_portal]);
      expect(
        await container.read(syncSubscriptionRecordProvider.future),
        isNotNull,
      );
    });

    test('does nothing without a service or a subscription', () async {
      expect(
        await containerWith(
          record: _record,
        ).read(openSyncSubscriptionPortalProvider)(),
        isFalse,
      );
      expect(
        await containerWith(
          withApi: api,
        ).read(openSyncSubscriptionPortalProvider)(),
        isFalse,
      );
      expect(launched, isEmpty);
    });

    test('a service failure is reported, not thrown', () async {
      when(() => api.portalUrl(any())).thenThrow(
        const SyncSubscriptionException(SyncSubscriptionFailureKind.notFound),
      );
      final container = containerWith(withApi: api, record: _record);

      expect(
        await container.read(openSyncSubscriptionPortalProvider)(),
        isFalse,
      );
      expect(launched, isEmpty);
    });
  });
}
