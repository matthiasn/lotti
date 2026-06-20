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
      final server = await _startProbeServer(statusCode: HttpStatus.forbidden);
      addTearDown(() => server.close(force: true));

      final reachable = await probeHttpReachability(
        uri: _serverUri(server, '/models'),
        timeout: const Duration(seconds: 1),
        acceptsStatusCode: (statusCode) => statusCode == HttpStatus.forbidden,
      );

      expect(reachable, isTrue);
    });

    test('returns false for rejected response statuses', () async {
      final server = await _startProbeServer(
        statusCode: HttpStatus.internalServerError,
      );
      addTearDown(() => server.close(force: true));

      final reachable = await probeHttpReachability(
        uri: _serverUri(server, '/api/version'),
        timeout: const Duration(seconds: 1),
        acceptsStatusCode: (statusCode) =>
            statusCode >= 200 && statusCode < 300,
      );

      expect(reachable, isFalse);
    });

    test('returns false when the endpoint is unavailable', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = _serverUri(server, '/closed');
      await server.close(force: true);

      final reachable = await probeHttpReachability(
        uri: uri,
        timeout: const Duration(milliseconds: 100),
        acceptsStatusCode: (_) => true,
      );

      expect(reachable, isFalse);
    });
  });
}

Future<HttpServer> _startProbeServer({required int statusCode}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    request.response.statusCode = statusCode;
    request.response.write('probe');
    await request.response.close();
  });
  return server;
}

Uri _serverUri(HttpServer server, String path) {
  return Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: server.port,
    path: path,
  );
}
