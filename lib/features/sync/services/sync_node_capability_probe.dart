import 'dart:async';
import 'dart:io';

import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';

/// Resolves the local node's capabilities for `SyncNodeProfileBroadcaster`.
///
/// Implementations should be cheap and idempotent — the broadcaster invokes
/// the probe on every diff cycle. Heavy work (HTTP pokes, native FFI checks)
/// belongs behind caching inside the implementation, not in the broadcaster.
///
/// The probe returns the *detected* portion of a node profile (platform,
/// hardware, capability set). The broadcaster combines this with persistent
/// user-supplied fields (the display name) before writing the published
/// snapshot, so a probe implementation does not need to know what the user
/// chose as a display name — it can leave [SyncNodeProfile.displayName] as a
/// generated default.
typedef SyncNodeCapabilityProbe =
    Future<SyncNodeProfile> Function({
      required String hostId,
      required DateTime now,
      String? displayName,
      String? appVersion,
    });

/// Probe used to determine whether an Ollama server is reachable on this
/// host. Returns true when a request to `http://127.0.0.1:11434/api/version`
/// completes with a 2xx response inside [timeout]; false on any failure
/// (DNS, refused, timeout, non-2xx). Pure function so the broadcaster's tests
/// can stub it without spinning up real HTTP.
typedef OllamaReachabilityProbe = Future<bool> Function({Duration timeout});

/// Probe used to determine whether an oMLX OpenAI-compatible server is
/// reachable on this host. A 2xx response means model listing is open; 401/403
/// also count as reachable because the app provider config can supply the
/// local API key during real inference.
typedef OmlxReachabilityProbe = Future<bool> Function({Duration timeout});

Future<bool> _defaultOllamaProbe({
  Duration timeout = const Duration(milliseconds: 300),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:11434/api/version'))
        .timeout(timeout);
    final response = await request.close().timeout(timeout);
    await response.drain<void>().timeout(timeout);
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    // Refused, DNS failure, timeout, parse error — all "Ollama not here".
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<bool> _defaultOmlxProbe({
  Duration timeout = const Duration(milliseconds: 300),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final baseUrl = ProviderConfig.defaultBaseUrls[InferenceProviderType.omlx]!;
    final request = await client
        .getUrl(Uri.parse('$baseUrl/models'))
        .timeout(timeout);
    final response = await request.close().timeout(timeout);
    await response.drain<void>().timeout(timeout);
    return (response.statusCode >= 200 && response.statusCode < 300) ||
        response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden;
  } catch (_) {
    // Refused, DNS failure, timeout, parse error — all "oMLX not here".
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Default probe: reports the host platform and detects the local
/// inference capabilities this app actually integrates with:
///
/// - **`mlxAudio`** — claimed on macOS only. The MLX channel
///   (`lib/features/ai/util/mlx_audio_channel.dart`) is macOS-only; on any
///   other platform the runtime cannot run MLX models, so advertising the
///   capability would mis-route pin choices in the UI.
/// - **`ollamaLlm`** — claimed when a short HTTP probe to
///   `127.0.0.1:11434/api/version` succeeds. Uses a tight 300ms timeout so
///   startup never stalls; a missed Ollama server is recoverable — the next
///   startup re-probes.
/// - **`omlxLlm`** — claimed when the local oMLX OpenAI-compatible server
///   responds at the configured default `/models` endpoint. Auth failures still
///   count as reachable; actual inference uses the saved provider API key.
///
/// Voxtral and Whisper are deliberately **not** auto-advertised: they require
/// installed local binaries that the app doesn't manage, so the user must
/// opt in via the sync-node settings UI (PR4). False-positives there would
/// surface broken pin choices.
SyncNodeCapabilityProbe makeDefaultSyncNodeCapabilityProbe({
  OllamaReachabilityProbe ollamaProbe = _defaultOllamaProbe,
  OmlxReachabilityProbe omlxProbe = _defaultOmlxProbe,
}) {
  return ({
    required String hostId,
    required DateTime now,
    String? displayName,
    String? appVersion,
  }) async {
    final capabilities = <NodeCapability>[
      if (Platform.isMacOS) NodeCapability.mlxAudio,
      if (await omlxProbe(timeout: const Duration(milliseconds: 300)))
        NodeCapability.omlxLlm,
      if (await ollamaProbe(timeout: const Duration(milliseconds: 300)))
        NodeCapability.ollamaLlm,
    ];

    return SyncNodeProfile(
      hostId: hostId,
      displayName: displayName ?? _defaultDisplayName(),
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      appVersion: appVersion,
      capabilities: capabilities,
      updatedAt: now,
    );
  };
}

/// Convenience entry that uses the real local reachability probes. The call site in
/// `get_it.dart` uses this; tests should call [makeDefaultSyncNodeCapabilityProbe]
/// with stub probes instead.
Future<SyncNodeProfile> defaultSyncNodeCapabilityProbe({
  required String hostId,
  required DateTime now,
  String? displayName,
  String? appVersion,
}) {
  return makeDefaultSyncNodeCapabilityProbe()(
    hostId: hostId,
    now: now,
    displayName: displayName,
    appVersion: appVersion,
  );
}

String _defaultDisplayName() {
  final host = Platform.localHostname;
  if (host.isNotEmpty) return host;
  return 'Lotti on ${Platform.operatingSystem}';
}
