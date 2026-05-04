import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/linux_geoclue_client.dart';
import 'package:lotti/services/linux_location_portal.dart'
    show PortalAccuracy, PortalLocationException;

@immutable
class _Call {
  const _Call(this.path, this.interface, this.name, this.values);
  final String path;
  final String interface;
  final String name;
  final List<DBusValue> values;
}

@immutable
class _SignalKey {
  const _SignalKey(this.interface, this.name, this.path);
  final String interface;
  final String name;
  final DBusObjectPath? path;

  @override
  bool operator ==(Object other) =>
      other is _SignalKey &&
      other.interface == interface &&
      other.name == name &&
      other.path == path;

  @override
  int get hashCode => Object.hash(interface, name, path);
}

class _FakeGeoClueDBus implements GeoClueDBus {
  _FakeGeoClueDBus({required this.clientPath, required this.locationPath});

  final DBusObjectPath clientPath;
  final DBusObjectPath locationPath;

  final List<_Call> calls = [];
  final Map<_SignalKey, StreamController<DBusSignal>> _controllers = {};
  final Map<String, DBusValue> locationProperties = {
    'Latitude': const DBusDouble(48.8566),
    'Longitude': const DBusDouble(2.3522),
    'Altitude': const DBusDouble(35),
    'Accuracy': const DBusDouble(20),
    'Speed': const DBusDouble(0),
    'Heading': const DBusDouble(180),
    'Timestamp': DBusStruct([
      const DBusUint64(1700000000),
      const DBusUint64(500000),
    ]),
  };

  bool startThrows = false;
  bool closed = false;

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    required String interface,
    required String name,
    required Iterable<DBusValue> values,
    DBusSignature? replySignature,
  }) async {
    final list = values.toList();
    calls.add(_Call(path.value, interface, name, list));

    if (interface == 'org.freedesktop.GeoClue2.Manager' &&
        name == 'GetClient') {
      return DBusMethodSuccessResponse([clientPath]);
    }
    if (interface == 'org.freedesktop.GeoClue2.Manager' &&
        name == 'DeleteClient') {
      return DBusMethodSuccessResponse([]);
    }
    if (interface == 'org.freedesktop.DBus.Properties' && name == 'Set') {
      return DBusMethodSuccessResponse([]);
    }
    if (interface == 'org.freedesktop.GeoClue2.Client' && name == 'Start') {
      if (startThrows) {
        throw DBusAccessDeniedException(
          DBusMethodErrorResponse(
            'org.freedesktop.DBus.Error.AccessDenied',
            [const DBusString('denied')],
          ),
        );
      }
      return DBusMethodSuccessResponse([]);
    }
    if (interface == 'org.freedesktop.GeoClue2.Client' && name == 'Stop') {
      return DBusMethodSuccessResponse([]);
    }
    if (interface == 'org.freedesktop.DBus.Properties' && name == 'GetAll') {
      return DBusMethodSuccessResponse([
        DBusDict.stringVariant(locationProperties),
      ]);
    }
    throw StateError('Unexpected $interface.$name on ${path.value}');
  }

  @override
  Stream<DBusSignal> subscribeSignal({
    required String sender,
    required String interface,
    required String name,
    DBusObjectPath? path,
  }) {
    final ctrl = _controllers.putIfAbsent(
      _SignalKey(interface, name, path),
      StreamController<DBusSignal>.broadcast,
    );
    return ctrl.stream;
  }

  void emitLocationUpdated() {
    final ctrl =
        _controllers[_SignalKey(
          'org.freedesktop.GeoClue2.Client',
          'LocationUpdated',
          clientPath,
        )];
    if (ctrl == null) {
      throw StateError('LocationUpdated not subscribed yet');
    }
    ctrl.add(
      DBusSignal(
        sender: 'org.freedesktop.GeoClue2',
        path: clientPath,
        interface: 'org.freedesktop.GeoClue2.Client',
        name: 'LocationUpdated',
        values: [DBusObjectPath('/'), locationPath],
      ),
    );
  }

  void emitSignalError(Object error) {
    final ctrl =
        _controllers[_SignalKey(
          'org.freedesktop.GeoClue2.Client',
          'LocationUpdated',
          clientPath,
        )];
    if (ctrl == null) {
      throw StateError('LocationUpdated not subscribed yet');
    }
    ctrl.addError(error);
  }

  bool wasCalled(String interface, String name) =>
      calls.any((_Call c) => c.interface == interface && c.name == name);

  @override
  Future<void> close() async {
    closed = true;
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
  }
}

void main() {
  group('LinuxGeoClueClient', () {
    late _FakeGeoClueDBus fake;
    late LinuxGeoClueClient client;

    setUp(() {
      fake = _FakeGeoClueDBus(
        clientPath: DBusObjectPath('/org/freedesktop/GeoClue2/Client/1'),
        locationPath: DBusObjectPath(
          '/org/freedesktop/GeoClue2/Client/1/Location/0',
        ),
      );
      client = LinuxGeoClueClient(
        desktopId: 'com.matthiasn.lotti',
        bus: fake,
      );
    });

    test('returns location after LocationUpdated', () async {
      final future = client.getLocation(timeout: const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      fake.emitLocationUpdated();

      final loc = await future;
      expect(loc.latitude, 48.8566);
      expect(loc.longitude, 2.3522);
      expect(loc.altitude, 35);
      expect(loc.timestampMicros, 1700000000 * 1000000 + 500000);
    });

    test('sets DesktopId and RequestedAccuracyLevel before Start', () async {
      final future = client.getLocation(
        timeout: const Duration(seconds: 5),
        accuracy: PortalAccuracy.city,
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitLocationUpdated();
      await future;

      final sets = fake.calls
          .where(
            (c) =>
                c.interface == 'org.freedesktop.DBus.Properties' &&
                c.name == 'Set',
          )
          .toList();
      expect(sets, hasLength(2));
      expect(
        sets[0].values[1].asString(),
        'DesktopId',
      );
      expect(
        sets[0].values[2].asVariant().asString(),
        'com.matthiasn.lotti',
      );
      expect(sets[1].values[1].asString(), 'RequestedAccuracyLevel');
      expect(sets[1].values[2].asVariant().asUint32(), 2);

      final startIdx = fake.calls.indexWhere((c) => c.name == 'Start');
      expect(startIdx, greaterThan(fake.calls.indexOf(sets[1])));
    });

    test('always tears the client down', () async {
      final future = client.getLocation(timeout: const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      fake.emitLocationUpdated();
      await future;

      expect(
        fake.wasCalled('org.freedesktop.GeoClue2.Client', 'Stop'),
        isTrue,
      );
      expect(
        fake.wasCalled('org.freedesktop.GeoClue2.Manager', 'DeleteClient'),
        isTrue,
      );
    });

    test(
      'propagates Start AccessDenied (silently denied authorization)',
      () async {
        fake.startThrows = true;
        await expectLater(
          client.getLocation(timeout: const Duration(seconds: 5)),
          throwsA(isA<DBusAccessDeniedException>()),
        );
        expect(
          fake.wasCalled('org.freedesktop.GeoClue2.Manager', 'DeleteClient'),
          isTrue,
        );
      },
    );

    test('times out when no LocationUpdated arrives', () async {
      await expectLater(
        client.getLocation(timeout: const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('throws when location is missing coordinates', () async {
      fake.locationProperties
        ..remove('Latitude')
        ..remove('Longitude');
      final future = client.getLocation(timeout: const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      fake.emitLocationUpdated();

      await expectLater(future, throwsA(isA<PortalLocationException>()));
    });

    test('close() forwards to the bus', () async {
      await client.close();
      expect(fake.closed, isTrue);
    });

    test('propagates LocationUpdated stream errors', () async {
      final future = client.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitSignalError(StateError('stream blew up'));

      await expectLater(future, throwsA(isA<StateError>()));
    });
  });
}
