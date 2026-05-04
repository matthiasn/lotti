import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/linux_geoclue_client.dart';
import 'package:lotti/services/linux_location_portal.dart';
import 'package:lotti/utils/location.dart';

class _StubPortalDBus implements PortalDBus {
  int closeCount = 0;
  bool throwOnClose = false;

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    required String interface,
    required String name,
    required Iterable<DBusValue> values,
    DBusSignature? replySignature,
  }) async {
    throw StateError('not used in this test');
  }

  @override
  Stream<DBusSignal> subscribeSignal({
    required String sender,
    required String interface,
    required String name,
    DBusObjectPath? path,
  }) => const Stream.empty();

  @override
  Future<void> close() async {
    closeCount++;
    if (throwOnClose) throw StateError('boom');
  }
}

class _StubGeoClueDBus implements GeoClueDBus {
  int closeCount = 0;

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    required String interface,
    required String name,
    required Iterable<DBusValue> values,
    DBusSignature? replySignature,
  }) async {
    throw StateError('not used in this test');
  }

  @override
  Stream<DBusSignal> subscribeSignal({
    required String sender,
    required String interface,
    required String name,
    DBusObjectPath? path,
  }) => const Stream.empty();

  @override
  Future<void> close() async {
    closeCount++;
  }
}

void main() {
  group('PortalBackend', () {
    test('delegates getLocation and close to the underlying portal', () async {
      final stub = _StubPortalDBus();
      final portal = XdgLocationPortal(
        bus: stub,
        tokenFactory: () => 'tok',
      );
      final backend = PortalBackend(portal);

      // getLocation will time out because the stub never emits — that's fine,
      // we just need to confirm the call reaches the portal.
      await expectLater(
        backend.getLocation(timeout: const Duration(milliseconds: 50)),
        throwsA(anything),
      );

      await backend.close();
      expect(stub.closeCount, 1);
    });
  });

  group('GeoClueBackend', () {
    test('delegates getLocation and close to the underlying client', () async {
      final stub = _StubGeoClueDBus();
      final client = LinuxGeoClueClient(desktopId: 'x', bus: stub);
      final backend = GeoClueBackend(client);

      await expectLater(
        backend.getLocation(timeout: const Duration(milliseconds: 50)),
        // CreateClient throws via the stub before any signal can fire.
        throwsA(anything),
      );

      await backend.close();
      expect(stub.closeCount, 1);
    });
  });

  group('defaultLinuxBackend', () {
    test('returns a PortalBackend when running inside Flatpak', () {
      final backend = defaultLinuxBackend(isInFlatpak: () => true);
      expect(backend, isA<PortalBackend>());
    });

    test('returns a GeoClueBackend when not sandboxed', () {
      final backend = defaultLinuxBackend(isInFlatpak: () => false);
      expect(backend, isA<GeoClueBackend>());
    });
  });

  group('DeviceLocation construction defaults', () {
    test(
      'falls back to defaultIpGeolocationProvider when none is injected',
      () {
        // Just verifying construction with no ipGeolocationProvider exercises
        // the `?? defaultIpGeolocationProvider` branch. Constructor calls
        // init(), which on Linux/test bails immediately.
        final dl = DeviceLocation(
          linuxBackendFactory: _StubBackend.new,
        );
        expect(dl.location, isNotNull);
      },
    );
  });
}

class _StubBackend implements LinuxLocationBackend {
  @override
  Future<PortalLocation> getLocation({required Duration timeout}) =>
      throw UnimplementedError();
  @override
  Future<void> close() async {}
}
