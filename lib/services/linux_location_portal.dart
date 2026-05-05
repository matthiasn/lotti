import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:uuid/uuid.dart';

const _portalDestination = 'org.freedesktop.portal.Desktop';
final _portalPath = DBusObjectPath('/org/freedesktop/portal/desktop');
const _locationInterface = 'org.freedesktop.portal.Location';
const _sessionInterface = 'org.freedesktop.portal.Session';
const _requestInterface = 'org.freedesktop.portal.Request';

const _responseSuccess = 0;
const _responseCancelled = 1;

/// Accuracy level passed to `org.freedesktop.portal.Location.CreateSession`.
/// Values match the portal spec.
enum PortalAccuracy {
  none(0),
  country(1),
  city(2),
  neighborhood(3),
  street(4),
  exact(5)
  ;

  const PortalAccuracy(this.value);
  final int value;
}

class PortalLocation {
  PortalLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.timestampMicros,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? timestampMicros;
}

class PortalLocationException implements Exception {
  PortalLocationException(this.message);
  final String message;

  @override
  String toString() => 'PortalLocationException: $message';
}

/// Narrow seam over [DBusClient] so [XdgLocationPortal] can be unit-tested
/// without a real session bus.
abstract class PortalDBus {
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

class _RealPortalDBus implements PortalDBus {
  _RealPortalDBus();

  // Lazy so just constructing the portal does not connect to the
  // session bus. Tests and Linux environments without a session bus
  // can build the type without throwing.
  late final DBusClient _client = DBusClient.session();

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

/// Single-shot location reader backed by `org.freedesktop.portal.Location`.
///
/// Flow per the portal spec:
///   1. `CreateSession` — returns a session object path.
///   2. Subscribe to `LocationUpdated` filtered on that session path.
///   3. `Start` — returns a request object path; subscribe to its `Response`
///      so we can fail fast on user denial / portal error.
///   4. Wait for the first `LocationUpdated`, then `Session.Close`.
class XdgLocationPortal {
  XdgLocationPortal({PortalDBus? bus, String Function()? tokenFactory})
    : _bus = bus ?? _RealPortalDBus(),
      _tokenFactory = tokenFactory ?? _defaultTokenFactory;

  final PortalDBus _bus;
  final String Function() _tokenFactory;

  static String _defaultTokenFactory() =>
      const Uuid().v4().replaceAll('-', '_');

  Future<PortalLocation> getLocation({
    Duration timeout = const Duration(seconds: 10),
    PortalAccuracy accuracy = PortalAccuracy.exact,
    int distanceThreshold = 0,
    int timeThreshold = 0,
  }) async {
    final sessionToken = _tokenFactory();
    final requestToken = _tokenFactory();

    DBusObjectPath? sessionHandle;
    StreamSubscription<DBusSignal>? locationSub;
    StreamSubscription<DBusSignal>? responseSub;

    try {
      final createReply = await _bus.callMethod(
        destination: _portalDestination,
        path: _portalPath,
        interface: _locationInterface,
        name: 'CreateSession',
        values: [
          DBusDict.stringVariant({
            'session_handle_token': DBusString(sessionToken),
            'accuracy': DBusUint32(accuracy.value),
            if (distanceThreshold > 0)
              'distance-threshold': DBusUint32(distanceThreshold),
            if (timeThreshold > 0) 'time-threshold': DBusUint32(timeThreshold),
          }),
        ],
        replySignature: DBusSignature('o'),
      );
      sessionHandle = createReply.returnValues[0].asObjectPath();
      final sessionPath = sessionHandle;

      final completer = Completer<PortalLocation>();

      locationSub = _bus
          .subscribeSignal(
            sender: _portalDestination,
            interface: _locationInterface,
            name: 'LocationUpdated',
          )
          .listen(
            (signal) {
              if (completer.isCompleted) return;
              if (signal.values.length < 2) return;
              final eventSession = signal.values[0].asObjectPath();
              if (eventSession != sessionPath) return;
              try {
                final dict = signal.values[1].asStringVariantDict();
                completer.complete(_decodeLocation(dict));
              } catch (e) {
                completer.completeError(e);
              }
            },
            onError: (Object e) {
              if (!completer.isCompleted) completer.completeError(e);
            },
          );

      // Per the portal spec, Location.Start is invoked on the portal frontend
      // object; the session handle returned by CreateSession is passed as the
      // first argument, not used as the call path.
      final startReply = await _bus.callMethod(
        destination: _portalDestination,
        path: _portalPath,
        interface: _locationInterface,
        name: 'Start',
        values: [
          sessionHandle,
          const DBusString(''), // parent_window — none for headless callers
          DBusDict.stringVariant({
            'handle_token': DBusString(requestToken),
          }),
        ],
        replySignature: DBusSignature('o'),
      );
      final requestPath = startReply.returnValues[0].asObjectPath();

      responseSub = _bus
          .subscribeSignal(
            sender: _portalDestination,
            interface: _requestInterface,
            name: 'Response',
            path: requestPath,
          )
          .listen(
            (signal) {
              if (completer.isCompleted) return;
              if (signal.values.isEmpty) return;
              final response = signal.values[0].asUint32();
              if (response == _responseSuccess) {
                // Success means the session is live; LocationUpdated will follow.
                return;
              }
              completer.completeError(
                PortalLocationException(
                  response == _responseCancelled
                      ? 'User denied location access'
                      : 'Portal Start failed (response=$response)',
                ),
              );
            },
            onError: (Object e) {
              if (!completer.isCompleted) completer.completeError(e);
            },
          );

      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'No location received from xdg-desktop-portal',
          timeout,
        ),
      );
    } finally {
      await locationSub?.cancel();
      await responseSub?.cancel();
      if (sessionHandle != null) {
        try {
          await _bus.callMethod(
            destination: _portalDestination,
            path: sessionHandle,
            interface: _sessionInterface,
            name: 'Close',
            values: const [],
          );
        } catch (_) {
          // Best effort — the portal may have already torn it down.
        }
      }
    }
  }

  Future<void> close() => _bus.close();

  PortalLocation _decodeLocation(Map<String, DBusValue> dict) {
    double? readDouble(String key) {
      final value = dict[key];
      if (value == null) return null;
      return value.signature == DBusSignature('d') ? value.asDouble() : null;
    }

    final lat = readDouble('Latitude');
    final lon = readDouble('Longitude');
    if (lat == null || lon == null) {
      throw PortalLocationException('LocationUpdated missing coordinates');
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
