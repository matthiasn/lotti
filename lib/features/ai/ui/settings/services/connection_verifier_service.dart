import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

/// Sealed result of a single connection probe. The connect form's
/// status strip dispatches on this to render the loading / verified /
/// failed surfaces. [ConnectionCheckIdle] is the resting state before
/// any probe has run for the current API-key+baseUrl combination.
sealed class ConnectionCheckState {
  const ConnectionCheckState();
}

class ConnectionCheckIdle extends ConnectionCheckState {
  const ConnectionCheckIdle();
}

class ConnectionCheckChecking extends ConnectionCheckState {
  const ConnectionCheckChecking();
}

class ConnectionCheckVerified extends ConnectionCheckState {
  const ConnectionCheckVerified({
    required this.modelCount,
    required this.latency,
  });

  final int modelCount;
  final Duration latency;
}

/// Provider returned a non-2xx HTTP response. The status code + body
/// snippet land in the strip's error subtitle so the user can act
/// (rotate the key, fix the typo, retry).
class ConnectionCheckFailedHttp extends ConnectionCheckState {
  const ConnectionCheckFailedHttp({
    required this.status,
    required this.message,
  });

  final int status;
  final String message;
}

/// Discriminator on [ConnectionCheckFailedNetwork] so the UI layer
/// can pick a localized detail string. Cases:
///
/// - [network]: raw exception message from `dart:io` / `package:http`
///   (DNS, connection refused, TLS handshake, …). The `message` field
///   on [ConnectionCheckFailedNetwork] carries the underlying error
///   text — these strings come from the platform / SDK and aren't
///   localized by Lotti.
/// - [timeout]: probe didn't return within the configured timeout.
///   UI renders a localized "Request timed out" line; `message` is
///   ignored.
/// - [invalidBaseUrl]: the user-entered base URL parses but lacks a
///   scheme/host needed by `http.Client`. UI renders a localized hint
///   that explains the expected `https://host` shape.
/// - [badResponseShape]: provider returned 2xx but the JSON wasn't a
///   `Map` or `List`. `message` carries the runtime type so the UI
///   can interpolate it.
enum ConnectionFailureCode {
  network,
  timeout,
  invalidBaseUrl,
  badResponseShape,
}

/// Probe failed before the provider returned an HTTP response —
/// timeout, DNS, no route to host, etc. The [code] discriminator lets
/// the UI layer map the failure to a localized detail string;
/// `message` carries either a raw platform exception (for
/// [ConnectionFailureCode.network]) or the runtime type for
/// [ConnectionFailureCode.badResponseShape].
class ConnectionCheckFailedNetwork extends ConnectionCheckState {
  const ConnectionCheckFailedNetwork({
    required this.message,
    this.code = ConnectionFailureCode.network,
  });

  final String message;
  final ConnectionFailureCode code;
}

/// Per-provider HTTP probe. Implementations hit the canonical
/// "list models" endpoint for their provider type with the supplied
/// credentials and return either the model count or a failure state.
/// Kept as a one-method abstract class (rather than a typedef) so test
/// fakes can extend it as named classes for clearer stack traces.
@visibleForTesting
// ignore: one_member_abstracts
abstract class ConnectionProbe {
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  });
}

/// Default registry: maps `InferenceProviderType` → `ConnectionProbe`.
/// Tests can override this via [connectionProbeRegistryProvider] with
/// fake probes that return canned states.
///
/// Gemini in this app is configured against its OpenAI-compatible
/// endpoint (`/v1beta/openai`), so the OpenAI-compat probe (Bearer
/// auth on `<baseUrl>/models`) is the right shape — building a custom
/// `?key=...` query against the same base would resolve to
/// `/v1beta/openai/v1/models?key=...` which Gemini answers with 400.
/// A native-API Gemini probe (using `?key=` on the v1beta/models
/// endpoint at the host root) is intentionally NOT shipped — every
/// Gemini provider in this app talks OpenAI-compat, so a second probe
/// shape would be dead code.
const Map<InferenceProviderType, ConnectionProbe> _defaultConnectionProbes =
    <InferenceProviderType, ConnectionProbe>{
      InferenceProviderType.gemini: _OpenAiCompatibleProbe(),
      InferenceProviderType.openAi: _OpenAiCompatibleProbe(),
      InferenceProviderType.genericOpenAi: _OpenAiCompatibleProbe(),
      InferenceProviderType.openRouter: _OpenAiCompatibleProbe(),
      InferenceProviderType.nebiusAiStudio: _OpenAiCompatibleProbe(),
      InferenceProviderType.melious: _OpenAiCompatibleProbe(),
      InferenceProviderType.mistral: _OpenAiCompatibleProbe(),
      InferenceProviderType.alibaba: _OpenAiCompatibleProbe(),
      InferenceProviderType.omlx: _OpenAiCompatibleProbe(),
      InferenceProviderType.anthropic: _AnthropicProbe(),
      InferenceProviderType.ollama: _OllamaProbe(),
    };

/// Probe-per-provider lookup table. Override in tests to substitute
/// fake probes (returns canned states) without monkeypatching network
/// IO. Production callers leave this alone.
final Provider<Map<InferenceProviderType, ConnectionProbe>>
connectionProbeRegistryProvider =
    Provider.autoDispose<Map<InferenceProviderType, ConnectionProbe>>(
      connectionProbeRegistry,
      name: 'connectionProbeRegistryProvider',
    );
Map<InferenceProviderType, ConnectionProbe> connectionProbeRegistry(Ref ref) {
  return _defaultConnectionProbes;
}

/// HTTP client factory used by the verifier. A factory (not a single
/// shared client) so each probe gets its own short-lived client that
/// can be `.close()`d in a `finally` without leaking connections to
/// concurrent probes. Tests override this with a `MockClient`-backed
/// factory to assert calls without touching the network.
final Provider<http.Client Function()> connectionVerifierClientProvider =
    Provider.autoDispose<http.Client Function()>(
      connectionVerifierClient,
      name: 'connectionVerifierClientProvider',
    );
http.Client Function() connectionVerifierClient(Ref ref) {
  return http.Client.new;
}

/// Per-probe timeout. Surfaced as a separate provider so retry-style
/// tests can shorten it without instantiating the controller directly.
final Provider<Duration> connectionVerifierTimeoutProvider =
    Provider.autoDispose<Duration>(
      connectionVerifierTimeout,
      name: 'connectionVerifierTimeoutProvider',
    );
Duration connectionVerifierTimeout(Ref ref) {
  return const Duration(seconds: 8);
}

/// Family-keyed Riverpod notifier driving the connection-check strip.
/// One controller instance per `InferenceProviderType` so tab swaps
/// don't carry stale verification state between provider types.
final NotifierProviderFamily<
  ConnectionVerifierController,
  ConnectionCheckState,
  InferenceProviderType
>
connectionVerifierControllerProvider = NotifierProvider.autoDispose
    .family<
      ConnectionVerifierController,
      ConnectionCheckState,
      InferenceProviderType
    >(
      ConnectionVerifierController.new,
      name: 'connectionVerifierControllerProvider',
    );

class ConnectionVerifierController extends Notifier<ConnectionCheckState> {
  ConnectionVerifierController(this.providerType);

  final InferenceProviderType providerType;

  /// In-flight probe identifier — guards against a fast Re-test tap
  /// race where an older probe's response would otherwise overwrite a
  /// newer probe's verified state.
  int _generation = 0;

  @override
  ConnectionCheckState build() {
    return const ConnectionCheckIdle();
  }

  /// Fires a probe against [baseUrl] using [apiKey]. Empty key or no
  /// probe registered for [providerType] short-circuit to idle so
  /// callers don't have to gate the call themselves.
  Future<void> verify({
    required String baseUrl,
    required String apiKey,
  }) async {
    final probes = ref.read(connectionProbeRegistryProvider);
    final probe = probes[providerType];
    if (probe == null) {
      // Provider type with no registered probe (Whisper, Voxtral) —
      // surface as idle rather than firing an HTTP call we can't form.
      state = const ConnectionCheckIdle();
      return;
    }
    // `trim()` so whitespace-only keys are treated the same as empty
    // — the form's hint says "paste your API key" and a stray space
    // pasted from the clipboard shouldn't trigger a probe that will
    // 401 anyway. Ollama is the lone exception: it accepts no key.
    // The trimmed value is also what gets forwarded to the probe, so
    // a pasted key with a trailing newline doesn't get sent over the
    // wire with the whitespace intact (which would fail auth even
    // though the underlying credential is valid).
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty &&
        !ProviderConfig.noApiKeyRequired.contains(providerType)) {
      state = const ConnectionCheckIdle();
      return;
    }
    // Resolve a blank base URL to the provider's documented default
    // (`https://api.openai.com/v1`, etc.) so users on the official
    // endpoint don't have to retype it just to run the verifier. The
    // form itself defaults the field on save via `ProviderConfig`;
    // mirror that here so the live probe stays consistent with what
    // the save path will eventually persist.
    final trimmedBase = baseUrl.trim();
    final effectiveBase = trimmedBase.isEmpty
        ? ProviderConfig.getDefaultBaseUrl(providerType)
        : trimmedBase;
    final Uri parsedBase;
    try {
      parsedBase = Uri.parse(effectiveBase);
    } on FormatException {
      // Same root cause as the scheme/host guard below — the URL is
      // malformed. Route it through the localized `invalidBaseUrl`
      // hint instead of leaking the raw Dart `FormatException`
      // message ("Invalid argument(s): …") to the user.
      state = const ConnectionCheckFailedNetwork(
        message: '',
        code: ConnectionFailureCode.invalidBaseUrl,
      );
      return;
    }
    // Reject URIs that parsed but lack the structure `http.Client`
    // needs — empty / non-http(s) schemes and missing hosts both
    // trigger `ArgumentError` ("Unsupported scheme …") inside
    // `dart:io`'s HTTP client. That's an `Error`, not an `Exception`,
    // so it would bypass the catch arm below and pin the strip in
    // the `Checking` state forever. Reject upstream with an explicit
    // network-failure message instead.
    final scheme = parsedBase.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || parsedBase.host.isEmpty) {
      state = const ConnectionCheckFailedNetwork(
        message: '',
        code: ConnectionFailureCode.invalidBaseUrl,
      );
      return;
    }

    final myGen = ++_generation;
    state = const ConnectionCheckChecking();
    final clientFactory = ref.read(connectionVerifierClientProvider);
    final timeout = ref.read(connectionVerifierTimeoutProvider);
    final client = clientFactory();
    try {
      final result = await probe.probe(
        baseUri: parsedBase,
        apiKey: normalizedKey,
        timeout: timeout,
        client: client,
      );
      // Drop the result if a newer probe started while we were awaiting,
      // or if the provider (auto-dispose) has been disposed in the meantime
      // — e.g. the user navigated away from the connect form while a probe
      // was in flight. Touching `state` on a disposed Ref throws.
      if (myGen != _generation || !ref.mounted) return;
      state = result;
    } on Exception catch (e) {
      if (myGen != _generation || !ref.mounted) return;
      state = ConnectionCheckFailedNetwork(message: e.toString());
    } finally {
      client.close();
    }
  }

  /// Returns the controller to its untested resting state. Called
  /// after the form is saved (the FTUE flow takes over) or when the
  /// user changes the provider type / clears the key.
  void reset() {
    _generation++;
    state = const ConnectionCheckIdle();
  }

  /// Bump the generation guard without touching `state`. Lets the
  /// caller invalidate any in-flight probe (its post-await write will
  /// be dropped because `myGen != _generation`) while leaving the
  /// visible strip alone — useful when the user types another
  /// character mid-probe and we want the next debounced probe to
  /// supersede the in-flight one without a Checking → previous-result
  /// flicker.
  void invalidate() {
    _generation++;
  }
}

// ---------------------------------------------------------------------------
// Per-provider probes.
// ---------------------------------------------------------------------------

/// Shared helper: runs [request] under [timeout], maps the response
/// to a `ConnectionCheckState`. Body parsing is delegated to
/// [parseModels] which returns the model count from a successful
/// payload (throws on malformed JSON, which surfaces as a network
/// failure).
Future<ConnectionCheckState> _runProbe({
  required Future<http.Response> Function() request,
  required int Function(Map<String, dynamic> body) parseModels,
  required Duration timeout,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    final response = await request().timeout(timeout);
    stopwatch.stop();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final count = parseModels(decoded);
          return ConnectionCheckVerified(
            modelCount: count,
            latency: stopwatch.elapsed,
          );
        }
        // List-only payload — Ollama's `/api/tags` returns
        // {"models": [...]} but some forks return a top-level list.
        if (decoded is List) {
          return ConnectionCheckVerified(
            modelCount: decoded.length,
            latency: stopwatch.elapsed,
          );
        }
        return ConnectionCheckFailedNetwork(
          message: '${decoded.runtimeType}',
          code: ConnectionFailureCode.badResponseShape,
        );
      } on FormatException catch (e) {
        return ConnectionCheckFailedNetwork(message: e.message);
      }
    }
    return ConnectionCheckFailedHttp(
      status: response.statusCode,
      message: _extractErrorMessage(response.body),
    );
  } on TimeoutException {
    return const ConnectionCheckFailedNetwork(
      message: '',
      code: ConnectionFailureCode.timeout,
    );
  } on Exception catch (e) {
    // Network-style failures (SocketException, HandshakeException, etc.)
    // — surface the message but don't swallow programmer errors.
    return ConnectionCheckFailedNetwork(message: e.toString());
  }
}

/// Best-effort extraction of the provider's error message from a
/// non-2xx body. Falls back to a snippet of the raw body when the
/// payload isn't JSON or doesn't carry a recognised error field.
String _extractErrorMessage(String body) {
  if (body.isEmpty) return '';
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final err = decoded['error'];
      if (err is Map<String, dynamic>) {
        final msg = err['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      } else if (err is String && err.isNotEmpty) {
        return err;
      }
      final msg = decoded['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
  } catch (_) {
    // Not JSON; fall through to raw snippet.
  }
  return body.length > 160 ? '${body.substring(0, 160)}…' : body;
}

class _OpenAiCompatibleProbe implements ConnectionProbe {
  const _OpenAiCompatibleProbe();

  @override
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  }) {
    final uri = baseUri.replace(
      path: '${baseUri.path.replaceAll(RegExp(r'/+$'), '')}/models',
    );
    return _runProbe(
      request: () => client.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ),
      parseModels: (body) {
        final data = body['data'];
        return data is List ? data.length : 0;
      },
      timeout: timeout,
    );
  }
}

class _AnthropicProbe implements ConnectionProbe {
  const _AnthropicProbe();

  @override
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  }) {
    final uri = baseUri.replace(
      path: '${baseUri.path.replaceAll(RegExp(r'/+$'), '')}/v1/models',
    );
    return _runProbe(
      request: () => client.get(
        uri,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
      ),
      parseModels: (body) {
        final data = body['data'];
        return data is List ? data.length : 0;
      },
      timeout: timeout,
    );
  }
}

class _OllamaProbe implements ConnectionProbe {
  const _OllamaProbe();

  @override
  Future<ConnectionCheckState> probe({
    required Uri baseUri,
    required String apiKey,
    required Duration timeout,
    required http.Client client,
  }) {
    final uri = baseUri.replace(
      path: '${baseUri.path.replaceAll(RegExp(r'/+$'), '')}/api/tags',
    );
    return _runProbe(
      request: () => client.get(uri),
      parseModels: (body) {
        final models = body['models'];
        return models is List ? models.length : 0;
      },
      timeout: timeout,
    );
  }
}
