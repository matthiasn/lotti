import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:lotti/services/linux_location_portal.dart'
    show PortalAccuracy, PortalLocation, PortalLocationException;

const _geoclueDestination = 'org.freedesktop.GeoClue2';
final _managerPath = DBusObjectPath('/org/freedesktop/GeoClue2/Manager');
const _managerInterface = 'org.freedesktop.GeoClue2.Manager';
const _clientInterface = 'org.freedesktop.GeoClue2.Client';
const _locationInterface = 'org.freedesktop.GeoClue2.Location';
const _propertiesInterface = 'org.freedesktop.DBus.Properties';

/// Same narrow seam as `PortalDBus` but for the system bus / GeoClue, so
/// [LinuxGeoClueClient] is unit-testable.
abstract class GeoClueDBus {
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    required String interface,
    required String name,
    required Iterable<DBusValue> values,
    DBusSignature? replySignature,
  });

  Stream<DBusSignal> subscribeSignal({
    required String sender,
    required String interface,
    required String name,
    DBusObjectPath? path,
  });

  Future<void> close();
}

class _RealGeoClueDBus implements GeoClueDBus {
  _RealGeoClueDBus();

  // Lazy so just constructing the client does not connect to the
  // system bus. Tests and Linux environments without a system bus
  // can build the type without throwing.
  late final DBusClient _client = DBusClient.system();

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    required String interface,
    required String name,
    required Iterable<DBusValue> values,
    DBusSignature? replySignature,
  }) {
    return _client.callMethod(
      destination: destination,
      path: path,
      interface: interface,
      name: name,
      values: values,
      replySignature: replySignature,
    );
  }

  @override
  Stream<DBusSignal> subscribeSignal({
    required String sender,
    required String interface,
    required String name,
    DBusObjectPath? path,
  }) {
    return DBusSignalStream(
      _client,
      sender: sender,
      interface: interface,
      name: name,
      path: path,
    );
  }

  @override
  Future<void> close() => _client.close();
}

/// Direct GeoClue client used for unsandboxed Linux runs (`flutter run`,
/// developer builds). Mirrors the [PortalLocation] surface so callers don't
/// have to branch on which backend produced the value.
///
/// The portal path is preferred when sandboxed; the portal cannot serve
/// host processes because GeoClue authorization keys off the caller's
/// app-id, which is empty for unsandboxed callers and the Start call is
/// rejected with `Access denied`.
class LinuxGeoClueClient {
  LinuxGeoClueClient({required this.desktopId, GeoClueDBus? bus})
    : _bus = bus ?? _RealGeoClueDBus();

  /// Desktop file basename (without `.desktop`). GeoClue's GNOME agent
  /// resolves this against the host's XDG application directories — for
  /// Lotti the file is shipped via the Flatpak export and additionally
  /// installed by `linux/install_dev_desktop_integration.sh` for dev runs.
  final String desktopId;
  final GeoClueDBus _bus;

  Future<PortalLocation> getLocation({
    Duration timeout = const Duration(seconds: 10),
    PortalAccuracy accuracy = PortalAccuracy.exact,
  }) async {
    DBusObjectPath? clientPath;
    StreamSubscription<DBusSignal>? sub;
    try {
      // CreateClient (not GetClient) so concurrent getLocation() calls from
      // the same process each get their own client. GetClient returns the
      // shared per-peer client, which the per-call DeleteClient in the
      // finally block would tear out from under another in-flight call.
      final createClient = await _bus.callMethod(
        destination: _geoclueDestination,
        path: _managerPath,
        interface: _managerInterface,
        name: 'CreateClient',
        values: const [],
        replySignature: DBusSignature('o'),
      );
      clientPath = createClient.returnValues[0].asObjectPath();
      final clientObject = clientPath;

      await _setProperty(
        clientObject,
        'DesktopId',
        DBusString(desktopId),
      );
      await _setProperty(
        clientObject,
        'RequestedAccuracyLevel',
        DBusUint32(accuracy.value),
      );

      final completer = Completer<PortalLocation>();
      sub = _bus
          .subscribeSignal(
            sender: _geoclueDestination,
            interface: _clientInterface,
            name: 'LocationUpdated',
            path: clientObject,
          )
          .listen(
            (signal) {
              if (completer.isCompleted) return;
              if (signal.values.length < 2) return;
              final newPath = signal.values[1].asObjectPath();
              unawaited(
                _readLocation(newPath).then(
                  (loc) {
                    if (!completer.isCompleted) completer.complete(loc);
                  },
                  onError: (Object e) {
                    if (!completer.isCompleted) completer.completeError(e);
                  },
                ),
              );
            },
            onError: (Object e) {
              if (!completer.isCompleted) completer.completeError(e);
            },
          );

      await _bus.callMethod(
        destination: _geoclueDestination,
        path: clientObject,
        interface: _clientInterface,
        name: 'Start',
        values: const [],
      );

      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'No location received from GeoClue (denied or unavailable)',
          timeout,
        ),
      );
    } finally {
      await sub?.cancel();
      if (clientPath != null) {
        try {
          await _bus.callMethod(
            destination: _geoclueDestination,
            path: clientPath,
            interface: _clientInterface,
            name: 'Stop',
            values: const [],
          );
        } catch (_) {
          /* best effort */
        }
        try {
          await _bus.callMethod(
            destination: _geoclueDestination,
            path: _managerPath,
            interface: _managerInterface,
            name: 'DeleteClient',
            values: [clientPath],
          );
        } catch (_) {
          /* best effort */
        }
      }
    }
  }

  Future<void> close() => _bus.close();

  Future<void> _setProperty(
    DBusObjectPath path,
    String name,
    DBusValue value,
  ) {
    return _bus.callMethod(
      destination: _geoclueDestination,
      path: path,
      interface: _propertiesInterface,
      name: 'Set',
      values: [
        const DBusString(_clientInterface),
        DBusString(name),
        DBusVariant(value),
      ],
    );
  }

  Future<PortalLocation> _readLocation(DBusObjectPath path) async {
    final reply = await _bus.callMethod(
      destination: _geoclueDestination,
      path: path,
      interface: _propertiesInterface,
      name: 'GetAll',
      values: [const DBusString(_locationInterface)],
      replySignature: DBusSignature('a{sv}'),
    );
    final dict = reply.returnValues[0].asStringVariantDict();

    double? readDouble(String key) {
      final v = dict[key];
      if (v == null) return null;
      return v.signature == DBusSignature('d') ? v.asDouble() : null;
    }

    final lat = readDouble('Latitude');
    final lon = readDouble('Longitude');
    if (lat == null || lon == null) {
      throw PortalLocationException('GeoClue location missing coordinates');
    }
    int? micros;
    final ts = dict['Timestamp'];
    if (ts != null && ts.signature == DBusSignature('(tt)')) {
      final parts = ts.asStruct();
      micros = parts[0].asUint64() * 1000000 + parts[1].asUint64();
    }
    return PortalLocation(
      latitude: lat,
      longitude: lon,
      altitude: readDouble('Altitude'),
      accuracy: readDouble('Accuracy'),
      speed: readDouble('Speed'),
      heading: readDouble('Heading'),
      timestampMicros: micros,
    );
  }
}
