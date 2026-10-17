import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_api.dart';
import 'package:lotti/features/sync/subscription/sync_subscription_store.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/platform.dart';
import 'package:url_launcher/url_launcher.dart';

/// Base URL of the Lotti Sync service, set per build:
/// `--dart-define=LOTTI_SYNC_API_URL=https://api.example.com/`.
const String _apiUrl = String.fromEnvironment('LOTTI_SYNC_API_URL');

/// Builds distributed through an app store that requires its own billing
/// (Google Play, TestFlight) pass `--dart-define=LOTTI_WEB_CHECKOUT=false`;
/// Flathub, AppImage and the GitHub APK keep the default.
const bool _webCheckoutAllowed = bool.fromEnvironment(
  'LOTTI_WEB_CHECKOUT',
  defaultValue: true,
);

/// The service base URL for [raw], or null when the build offers no web
/// checkout. Only an `https://` URL counts, so a typo in a build define
/// cannot send the entitlement secret in clear.
Uri? syncServiceBaseUrl(String raw, {required bool allowed}) {
  if (!allowed) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  // A trailing slash makes `resolve` append rather than replace the path.
  return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
}

final syncSubscriptionBaseUrlProvider = Provider<Uri?>(
  (ref) => syncServiceBaseUrl(_apiUrl, allowed: _webCheckoutAllowed),
  name: 'syncSubscriptionBaseUrlProvider',
);

/// Whether the subscribe entry is shown at all.
final syncSubscriptionAvailableProvider = Provider<bool>(
  (ref) => ref.watch(syncSubscriptionBaseUrlProvider) != null,
  name: 'syncSubscriptionAvailableProvider',
);

final syncSubscriptionApiProvider = Provider<SyncSubscriptionApi?>((ref) {
  final baseUrl = ref.watch(syncSubscriptionBaseUrlProvider);
  if (baseUrl == null) return null;
  final api = SyncSubscriptionApi(baseUrl: baseUrl);
  ref.onDispose(api.close);
  return api;
}, name: 'syncSubscriptionApiProvider');

final syncSubscriptionStoreProvider = Provider<SyncSubscriptionStore>(
  (ref) => SyncSubscriptionStore(ref.watch(secureStorageProvider)),
  name: 'syncSubscriptionStoreProvider',
);

/// Opens a checkout or portal page. A browser tab inside the app on mobile
/// (Custom Tabs / SFSafariViewController), the system browser on desktop —
/// never an embedded WebView: PayPal and 3-D Secure hand-offs break in one,
/// and a real browser shows the user the address they are paying on.
typedef SyncCheckoutLauncher = Future<bool> Function(Uri url);

final syncCheckoutLauncherProvider = Provider<SyncCheckoutLauncher>(
  (ref) =>
      (url) => launchUrl(
        url,
        mode: isMobile
            ? LaunchMode.inAppBrowserView
            : LaunchMode.externalApplication,
      ),
  name: 'syncCheckoutLauncherProvider',
);

/// Whether this install has a subscription to manage.
final FutureProvider<SyncSubscriptionRecord?> syncSubscriptionRecordProvider =
    FutureProvider.autoDispose<SyncSubscriptionRecord?>(
      (ref) => ref.watch(syncSubscriptionStoreProvider).load(),
      name: 'syncSubscriptionRecordProvider',
    );

/// Opens Paddle's customer portal for this install's subscription, where it
/// is cancelled or its payment method changed. Returns whether it opened.
final openSyncSubscriptionPortalProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final api = ref.read(syncSubscriptionApiProvider);
    final record = await ref.read(syncSubscriptionStoreProvider).load();
    if (api == null || record == null) return false;
    try {
      final url = await api.portalUrl(record.entitlement);
      return await ref.read(syncCheckoutLauncherProvider)(url);
    } on SyncSubscriptionException {
      return false;
    }
  },
  name: 'openSyncSubscriptionPortalProvider',
);
