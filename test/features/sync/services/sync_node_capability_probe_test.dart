import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/services/sync_node_capability_probe.dart';

void main() {
  final now = DateTime.utc(2026, 3, 15, 12);

  group('makeDefaultSyncNodeCapabilityProbe', () {
    test('claims ollamaLlm when the Ollama probe succeeds', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            true,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
      );

      final profile = await probe(hostId: 'h1', now: now);

      expect(profile.capabilities, contains(NodeCapability.ollamaLlm));
    });

    test('does NOT claim ollamaLlm when the Ollama probe fails', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
      );

      final profile = await probe(hostId: 'h1', now: now);

      expect(profile.capabilities, isNot(contains(NodeCapability.ollamaLlm)));
    });

    test('claims omlxLlm when the oMLX probe succeeds', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            true,
      );

      final profile = await probe(hostId: 'h1', now: now);

      expect(profile.capabilities, contains(NodeCapability.omlxLlm));
    });

    test('does NOT claim omlxLlm when the oMLX probe fails', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
      );

      final profile = await probe(hostId: 'h1', now: now);

      expect(profile.capabilities, isNot(contains(NodeCapability.omlxLlm)));
    });

    test(
      'claims mlxAudio iff running on macOS',
      () async {
        final probe = makeDefaultSyncNodeCapabilityProbe(
          ollamaProbe:
              ({Duration timeout = const Duration(seconds: 1)}) async => false,
          omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
              false,
        );

        final profile = await probe(hostId: 'h1', now: now);

        if (Platform.isMacOS) {
          expect(profile.capabilities, contains(NodeCapability.mlxAudio));
        } else {
          expect(
            profile.capabilities,
            isNot(contains(NodeCapability.mlxAudio)),
          );
        }
      },
    );

    test(
      'never claims voxtral or whisper from auto-detection',
      () async {
        // These require local binaries the app does not manage. Auto-claim
        // would surface broken pin choices in PR4's UI — the user must opt in
        // explicitly.
        final probe = makeDefaultSyncNodeCapabilityProbe(
          ollamaProbe:
              ({Duration timeout = const Duration(seconds: 1)}) async => true,
          omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
              true,
        );

        final profile = await probe(hostId: 'h1', now: now);

        expect(profile.capabilities, isNot(contains(NodeCapability.voxtral)));
        expect(profile.capabilities, isNot(contains(NodeCapability.whisper)));
      },
    );

    test(
      'returns capabilities in a stable enum-defined order',
      () async {
        // Avoid platform-dependent assertions: probe twice with the same
        // mocked dependencies and assert determinism.
        final probe = makeDefaultSyncNodeCapabilityProbe(
          ollamaProbe:
              ({Duration timeout = const Duration(seconds: 1)}) async => true,
          omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
              true,
        );

        final first = await probe(hostId: 'h1', now: now);
        final second = await probe(hostId: 'h1', now: now);

        expect(second.capabilities, first.capabilities);
      },
    );

    test('platform field reflects Platform.operatingSystem', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
      );

      final profile = await probe(hostId: 'h1', now: now);

      expect(profile.platform, Platform.operatingSystem);
    });

    test('keeps user-supplied displayName over the probe default', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
      );

      final profile = await probe(
        hostId: 'h1',
        now: now,
        displayName: 'My Studio Mac',
      );

      expect(profile.displayName, 'My Studio Mac');
    });

    test('forwards a supplied appVersion onto the profile', () async {
      final probe = makeDefaultSyncNodeCapabilityProbe(
        ollamaProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
        omlxProbe: ({Duration timeout = const Duration(seconds: 1)}) async =>
            false,
      );

      final withVersion = await probe(
        hostId: 'h1',
        now: now,
        appVersion: '1.2.3+45',
      );
      expect(withVersion.appVersion, '1.2.3+45');

      // Omitting it keeps the field null rather than inventing a default.
      final withoutVersion = await probe(hostId: 'h1', now: now);
      expect(withoutVersion.appVersion, isNull);
    });

    test(
      'default probe path returns a profile from real reachability probes',
      () async {
        final profile = await defaultSyncNodeCapabilityProbe(
          hostId: 'h-default',
          now: now,
          displayName: 'Default Probe Host',
          appVersion: '2.0.0+1',
        );

        expect(profile.hostId, 'h-default');
        expect(profile.displayName, 'Default Probe Host');
        expect(profile.appVersion, '2.0.0+1');
        expect(profile.platform, Platform.operatingSystem);
      },
    );
  });

  group('probeHttpReachability', () {
    test('returns true for accepted response statuses', () async {
      final uri = Uri.parse('http://127.0.0.1:8003/models');
      final client = _FakeProbeHttpClient(
        responseStatusCode: HttpStatus.forbidden,
      );

      final reachable = await _runWithFakeHttpClient(
        client: client,
        probe: () => probeHttpReachability(
          uri: uri,
          timeout: const Duration(seconds: 1),
          acceptsStatusCode: (statusCode) => statusCode == HttpStatus.forbidden,
        ),
      );

      expect(reachable, isTrue);
      expect(client.requestedUris, [uri]);
      expect(client.connectionTimeout, const Duration(seconds: 1));
      expect(client.closeForceValues, [true]);
    });

    test('returns false for rejected response statuses', () async {
      final uri = Uri.parse('http://127.0.0.1:11434/api/version');
      final client = _FakeProbeHttpClient(
        responseStatusCode: HttpStatus.internalServerError,
      );

      final reachable = await _runWithFakeHttpClient(
        client: client,
        probe: () => probeHttpReachability(
          uri: uri,
          timeout: const Duration(seconds: 1),
          acceptsStatusCode: (statusCode) =>
              statusCode >= 200 && statusCode < 300,
        ),
      );

      expect(reachable, isFalse);
      expect(client.requestedUris, [uri]);
      expect(client.closeForceValues, [true]);
    });

    test('returns false when the endpoint is unavailable', () async {
      final uri = Uri.parse('http://127.0.0.1:11434/api/version');
      final client = _FakeProbeHttpClient(
        exception: const SocketException('connection refused'),
      );

      final reachable = await _runWithFakeHttpClient(
        client: client,
        probe: () => probeHttpReachability(
          uri: uri,
          timeout: const Duration(milliseconds: 100),
          acceptsStatusCode: (_) => true,
        ),
      );

      expect(reachable, isFalse);
      expect(client.requestedUris, [uri]);
      expect(client.closeForceValues, [true]);
    });
  });
}

Future<bool> _runWithFakeHttpClient({
  required _FakeProbeHttpClient client,
  required Future<bool> Function() probe,
}) {
  return HttpOverrides.runZoned(
    probe,
    createHttpClient: (_) => client,
  );
}

class _FakeProbeHttpClient implements HttpClient {
  _FakeProbeHttpClient({this.responseStatusCode, this.exception});

  final int? responseStatusCode;
  final Exception? exception;
  final requestedUris = <Uri>[];
  final closeForceValues = <bool>[];

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUris.add(url);
    final exception = this.exception;
    if (exception != null) throw exception;

    return _FakeProbeHttpClientRequest(responseStatusCode!);
  }

  @override
  void close({bool force = false}) {
    closeForceValues.add(force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProbeHttpClientRequest implements HttpClientRequest {
  _FakeProbeHttpClientRequest(this.statusCode);

  final int statusCode;

  @override
  Future<HttpClientResponse> close() async {
    return _FakeProbeHttpClientResponse(statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProbeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeProbeHttpClientResponse(this.statusCode);

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
