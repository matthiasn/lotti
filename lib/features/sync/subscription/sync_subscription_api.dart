import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Why a call to the Lotti Sync service failed, in the terms the subscribe
/// screen needs to name a remedy.
enum SyncSubscriptionFailureKind {
  /// No connection, a timeout, or a TLS failure.
  offline,

  /// 401: the stored entitlement credentials are no longer accepted.
  unauthorized,

  /// 402: no paid subscription for this entitlement yet.
  paymentPending,

  /// 404: the session, or the subscription the call needs, does not exist.
  notFound,

  /// 409: the claim secret does not match, or the claim is already spent.
  conflict,

  /// 422: the request was well-formed but refused, e.g. the subscription
  /// no longer grants access.
  refused,

  /// 429, with [SyncSubscriptionException.retryAfter].
  rateLimited,

  /// 5xx, including 503 when paid sync is switched off on the server.
  server,

  /// A response that does not look like the service's.
  invalidResponse,
}

class SyncSubscriptionException implements Exception {
  const SyncSubscriptionException(this.kind, {this.retryAfter});

  final SyncSubscriptionFailureKind kind;
  final Duration? retryAfter;

  @override
  String toString() => 'SyncSubscriptionException(${kind.name})';
}

/// The anonymous identity a subscription is attributed to. Created once per
/// install and kept in the keystore; there is no account, no email.
class SyncEntitlement {
  const SyncEntitlement({required this.id, required this.authSecret});

  final String id;
  final String authSecret;
}

/// Plans the app can ask for; which price each is lives on the server.
enum SyncSubscriptionPlan { monthly, annual }

class SyncCheckoutSession {
  const SyncCheckoutSession({required this.id, required this.checkoutUrl});

  final String id;
  final Uri checkoutUrl;
}

enum SyncCheckoutState { pending, paid, expired }

/// A delivered paid bundle. [bundle] and [rotationChallenge] are null when
/// the account was already set up and its bootstrap credential destroyed.
class SyncPaidBundle {
  const SyncPaidBundle({
    required this.bundleId,
    required this.bundle,
    required this.rotationChallenge,
  });

  final String bundleId;
  final String? bundle;
  final String? rotationChallenge;
}

/// HTTP client for the app-facing routes of the provisioning service.
///
/// Talks to one configured base URL and follows no redirects, so neither the
/// entitlement secret nor the claim secret can be sent anywhere else.
class SyncSubscriptionApi {
  SyncSubscriptionApi({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const timeout = Duration(seconds: 15);

  final Uri baseUrl;
  final http.Client _http;

  Future<SyncEntitlement> createEntitlement() async {
    final json = await _post('client/subscriptions/entitlements');
    return SyncEntitlement(
      id: _string(json, 'entitlement_id'),
      authSecret: _string(json, 'auth_secret'),
    );
  }

  Future<SyncCheckoutSession> createCheckoutSession(
    SyncEntitlement entitlement, {
    required SyncSubscriptionPlan plan,
    required String claimSecret,
  }) async {
    final json = await _post(
      'client/web-checkout/sessions',
      entitlement: entitlement,
      body: {
        'entitlement_id': entitlement.id,
        'plan': plan.name,
        'claim_secret': claimSecret,
      },
    );
    final url = Uri.tryParse(_string(json, 'checkout_url'));
    if (url == null || url.scheme != 'https') {
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.invalidResponse,
      );
    }
    return SyncCheckoutSession(
      id: _string(json, 'session_id'),
      checkoutUrl: url,
    );
  }

  Future<SyncCheckoutState> checkoutState(String sessionId) async {
    final json = await _post(
      'client/web-checkout/session-status',
      body: {'session_id': sessionId},
    );
    final state = _string(json, 'state');
    return SyncCheckoutState.values.firstWhere(
      (value) => value.name == state,
      orElse: () => throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.invalidResponse,
      ),
    );
  }

  Future<SyncPaidBundle> claim(
    SyncEntitlement entitlement, {
    required String claimSecret,
  }) async {
    final json = await _post(
      'client/web-checkout/claims',
      entitlement: entitlement,
      body: {'entitlement_id': entitlement.id, 'claim_secret': claimSecret},
    );
    return SyncPaidBundle(
      bundleId: _string(json, 'bundle_id'),
      bundle: json['bundle'] as String?,
      rotationChallenge: json['rotation_challenge'] as String?,
    );
  }

  Future<void> confirmRotation(
    SyncEntitlement entitlement, {
    required String claimSecret,
    required String bundleId,
  }) async {
    await _post(
      'client/subscriptions/bundle-claims/confirm-rotation',
      entitlement: entitlement,
      body: {
        'entitlement_id': entitlement.id,
        'claim_secret': claimSecret,
        'bundle_id': bundleId,
      },
    );
  }

  Future<Uri> portalUrl(SyncEntitlement entitlement) async {
    final json = await _post(
      'client/web-checkout/portal-sessions',
      entitlement: entitlement,
      body: {'entitlement_id': entitlement.id},
    );
    final url = Uri.tryParse(_string(json, 'url'));
    if (url == null || url.scheme != 'https') {
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.invalidResponse,
      );
    }
    return url;
  }

  void close() => _http.close();

  Future<Map<String, dynamic>> _post(
    String path, {
    SyncEntitlement? entitlement,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request('POST', baseUrl.resolve('api/v1/$path'))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json';
    if (entitlement != null) {
      request.headers['Authorization'] = 'Bearer ${entitlement.authSecret}';
    }
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.offline,
      );
    } on SocketException {
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.offline,
      );
    } on http.ClientException {
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.offline,
      );
    } on HandshakeException {
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.offline,
      );
    }

    final status = response.statusCode;
    if (status == 204) return const {};
    if (status >= 200 && status < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // Falls through to invalidResponse.
      }
      throw const SyncSubscriptionException(
        SyncSubscriptionFailureKind.invalidResponse,
      );
    }
    throw SyncSubscriptionException(
      switch (status) {
        401 => SyncSubscriptionFailureKind.unauthorized,
        402 => SyncSubscriptionFailureKind.paymentPending,
        404 => SyncSubscriptionFailureKind.notFound,
        409 => SyncSubscriptionFailureKind.conflict,
        422 => SyncSubscriptionFailureKind.refused,
        429 => SyncSubscriptionFailureKind.rateLimited,
        >= 500 => SyncSubscriptionFailureKind.server,
        _ => SyncSubscriptionFailureKind.invalidResponse,
      },
      retryAfter: status == 429 ? _retryAfter(response) : null,
    );
  }

  static Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw const SyncSubscriptionException(
      SyncSubscriptionFailureKind.invalidResponse,
    );
  }
}
