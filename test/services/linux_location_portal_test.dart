import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/linux_location_portal.dart';

class _RecordedCall {
  _RecordedCall(this.path, this.interface, this.name, this.values);
  final DBusObjectPath path;
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

class _FakePortalDBus implements PortalDBus {
  _FakePortalDBus({
    required this.sessionPath,
    required this.requestPath,
  });

  final DBusObjectPath sessionPath;
  final DBusObjectPath requestPath;

  final List<_RecordedCall> calls = <_RecordedCall>[];
  final Map<_SignalKey, StreamController<DBusSignal>> _controllers = {};

  bool createSessionThrows = false;
  bool startThrows = false;
  bool closed = false;
  Exception? sessionCloseError;

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    required String interface,
    required String name,
    required Iterable<DBusValue> values,
    DBusSignature? replySignature,
  }) async {
    final valueList = values.toList();
    calls.add(_RecordedCall(path, interface, name, valueList));

    if (interface == 'org.freedesktop.portal.Location' &&
        name == 'CreateSession') {
      _expectPortalPath(path, 'CreateSession');
      if (createSessionThrows) {
        throw DBusServiceUnknownException(
          DBusMethodErrorResponse(
            'org.freedesktop.DBus.Error.ServiceUnknown',
            [const DBusString('not running')],
          ),
        );
      }
      return DBusMethodSuccessResponse([sessionPath]);
    }
    if (interface == 'org.freedesktop.portal.Location' && name == 'Start') {
      _expectPortalPath(path, 'Start');
      if (startThrows) {
        throw StateError('Start failed');
      }
      return DBusMethodSuccessResponse([requestPath]);
    }
    if (interface == 'org.freedesktop.portal.Session' && name == 'Close') {
      if (sessionCloseError != null) {
        throw sessionCloseError!;
      }
      return DBusMethodSuccessResponse([]);
    }
    throw StateError('Unexpected call $interface.$name');
  }

  // Per the portal spec, both CreateSession and Start live on the portal
  // frontend object — never on the session path. Asserting here pins down
  // the mistake the previous fake silently allowed.
  void _expectPortalPath(DBusObjectPath actual, String name) {
    final expected = DBusObjectPath('/org/freedesktop/portal/desktop');
    if (actual != expected) {
      throw StateError(
        '$name must be called on $expected, got $actual',
      );
    }
  }

  @override
  Stream<DBusSignal> subscribeSignal({
    required String sender,
    required String interface,
    required String name,
    DBusObjectPath? path,
  }) {
    final key = _SignalKey(interface, name, path);
    final ctrl = _controllers.putIfAbsent(
      key,
      StreamController<DBusSignal>.broadcast,
    );
    return ctrl.stream;
  }

  void emitLocation(Map<String, DBusValue> data, {DBusObjectPath? session}) {
    final ctrl =
        _controllers[const _SignalKey(
          'org.freedesktop.portal.Location',
          'LocationUpdated',
          null,
        )];
    if (ctrl == null) {
      throw StateError('LocationUpdated not subscribed yet');
    }
    ctrl.add(
      DBusSignal(
        sender: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
        interface: 'org.freedesktop.portal.Location',
        name: 'LocationUpdated',
        values: [
          session ?? sessionPath,
          DBusDict.stringVariant(data),
        ],
      ),
    );
  }

  void emitLocationError(Object error) {
    final ctrl =
        _controllers[const _SignalKey(
          'org.freedesktop.portal.Location',
          'LocationUpdated',
          null,
        )];
    if (ctrl == null) {
      throw StateError('LocationUpdated not subscribed yet');
    }
    ctrl.addError(error);
  }

  void emitResponseError(Object error) {
    final ctrl =
        _controllers[_SignalKey(
          'org.freedesktop.portal.Request',
          'Response',
          requestPath,
        )];
    if (ctrl == null) {
      throw StateError('Response not subscribed yet');
    }
    ctrl.addError(error);
  }

  void emitResponse(int response) {
    final ctrl =
        _controllers[_SignalKey(
          'org.freedesktop.portal.Request',
          'Response',
          requestPath,
        )];
    if (ctrl == null) {
      throw StateError('Response not subscribed yet');
    }
    ctrl.add(
      DBusSignal(
        sender: 'org.freedesktop.portal.Desktop',
        path: requestPath,
        interface: 'org.freedesktop.portal.Request',
        name: 'Response',
        values: [
          DBusUint32(response),
          DBusDict.stringVariant(const {}),
        ],
      ),
    );
  }

  bool wasCalled(String interface, String name) => calls.any(
    (_RecordedCall c) => c.interface == interface && c.name == name,
  );

  @override
  Future<void> close() async {
    closed = true;
    for (final ctrl in _controllers.values) {
      await ctrl.close();
    }
  }
}

void main() {
  group('XdgLocationPortal.getLocation', () {
    late _FakePortalDBus fake;
    late XdgLocationPortal portal;
    var tokenCounter = 0;

    setUp(() {
      tokenCounter = 0;
      fake = _FakePortalDBus(
        sessionPath: DBusObjectPath(
          '/org/freedesktop/portal/desktop/session/x',
        ),
        requestPath: DBusObjectPath(
          '/org/freedesktop/portal/desktop/request/x',
        ),
      );
      portal = XdgLocationPortal(
        bus: fake,
        tokenFactory: () => 'tok${++tokenCounter}',
      );
    });

    test('returns location when LocationUpdated arrives after Start', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );

      await Future<void>.delayed(Duration.zero);
      fake.emitLocation({
        'Latitude': const DBusDouble(48.8566),
        'Longitude': const DBusDouble(2.3522),
        'Altitude': const DBusDouble(35),
        'Accuracy': const DBusDouble(20),
        'Speed': const DBusDouble(0),
        'Heading': const DBusDouble(180),
        'Timestamp': DBusStruct(
          [const DBusUint64(1700000000), const DBusUint64(500000)],
        ),
      });

      final loc = await future;
      expect(loc.latitude, 48.8566);
      expect(loc.longitude, 2.3522);
      expect(loc.altitude, 35);
      expect(loc.accuracy, 20);
      expect(loc.speed, 0);
      expect(loc.heading, 180);
      expect(loc.timestampMicros, 1700000000 * 1000000 + 500000);
      expect(fake.wasCalled('org.freedesktop.portal.Session', 'Close'), isTrue);
    });

    test('passes accuracy and threshold options to CreateSession', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
        accuracy: PortalAccuracy.city,
        distanceThreshold: 25,
        timeThreshold: 30,
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitLocation({
        'Latitude': const DBusDouble(0),
        'Longitude': const DBusDouble(0),
      });
      await future;

      final create = fake.calls.firstWhere(
        (_RecordedCall c) => c.name == 'CreateSession',
      );
      final dict = create.values[0] as DBusDict;
      final native = dict.children.map(
        (k, v) => MapEntry(k.asString(), v.asVariant()),
      );
      expect(native['accuracy'], const DBusUint32(2));
      expect(native['distance-threshold'], const DBusUint32(25));
      expect(native['time-threshold'], const DBusUint32(30));
      expect(native['session_handle_token'], const DBusString('tok1'));
    });

    test('ignores LocationUpdated for other sessions', () async {
      final future = portal.getLocation(
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);

      fake.emitLocation(
        {
          'Latitude': const DBusDouble(1),
          'Longitude': const DBusDouble(2),
        },
        session: DBusObjectPath('/some/other/session'),
      );

      await expectLater(future, throwsA(isA<TimeoutException>()));
    });

    test('fails fast when user denies (Response = 1)', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitResponse(1);

      await expectLater(
        future,
        throwsA(
          isA<PortalLocationException>().having(
            (e) => e.message,
            'message',
            contains('User denied'),
          ),
        ),
      );
      expect(fake.wasCalled('org.freedesktop.portal.Session', 'Close'), isTrue);
    });

    test('fails when portal returns error response', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitResponse(2);

      await expectLater(
        future,
        throwsA(
          isA<PortalLocationException>().having(
            (e) => e.message,
            'message',
            contains('response=2'),
          ),
        ),
      );
    });

    test('Response = 0 keeps waiting for LocationUpdated', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake
        ..emitResponse(0)
        ..emitLocation({
          'Latitude': const DBusDouble(10),
          'Longitude': const DBusDouble(20),
        });

      final loc = await future;
      expect(loc.latitude, 10);
      expect(loc.longitude, 20);
    });

    test('times out when no signal arrives', () async {
      final future = portal.getLocation(
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(future, throwsA(isA<TimeoutException>()));
      expect(fake.wasCalled('org.freedesktop.portal.Session', 'Close'), isTrue);
    });

    test('throws when LocationUpdated lacks coordinates', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitLocation({
        'Accuracy': const DBusDouble(50),
      });

      await expectLater(future, throwsA(isA<PortalLocationException>()));
    });

    test('does not call Session.Close if CreateSession fails', () async {
      fake.createSessionThrows = true;

      await expectLater(
        portal.getLocation(timeout: const Duration(seconds: 5)),
        throwsA(isA<DBusServiceUnknownException>()),
      );
      expect(
        fake.wasCalled('org.freedesktop.portal.Session', 'Close'),
        isFalse,
      );
    });

    test('still completes if Session.Close throws', () async {
      fake.sessionCloseError = Exception('boom');
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitLocation({
        'Latitude': const DBusDouble(1),
        'Longitude': const DBusDouble(2),
      });

      final loc = await future;
      expect(loc.latitude, 1);
    });

    test('close() forwards to the bus', () async {
      await portal.close();
      expect(fake.closed, isTrue);
    });

    test('propagates LocationUpdated stream errors', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitLocationError(StateError('stream blew up'));

      await expectLater(future, throwsA(isA<StateError>()));
    });

    test('propagates Response stream errors', () async {
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitResponseError(StateError('response stream blew up'));

      await expectLater(future, throwsA(isA<StateError>()));
    });
  });

  group('XdgLocationPortal default token factory', () {
    test('generates distinct UUID-shaped tokens per call', () async {
      final fake = _FakePortalDBus(
        sessionPath: DBusObjectPath('/x/session'),
        requestPath: DBusObjectPath('/x/request'),
      );
      // No tokenFactory override — exercises the production default.
      final portal = XdgLocationPortal(bus: fake);
      final future = portal.getLocation(
        timeout: const Duration(seconds: 5),
      );
      await Future<void>.delayed(Duration.zero);
      fake.emitLocation({
        'Latitude': const DBusDouble(0),
        'Longitude': const DBusDouble(0),
      });
      await future;

      final create =
          fake.calls.firstWhere((c) => c.name == 'CreateSession').values[0]
              as DBusDict;
      final start =
          fake.calls.firstWhere((c) => c.name == 'Start').values[2] as DBusDict;
      final sessionToken = create
          .children[const DBusString(
            'session_handle_token',
          )]!
          .asVariant()
          .asString();
      final requestToken = start
          .children[const DBusString(
            'handle_token',
          )]!
          .asVariant()
          .asString();

      // UUID v4 with dashes replaced by underscores → 36-char string with 4
      // underscores in the canonical positions.
      expect(sessionToken, hasLength(36));
      expect('_'.allMatches(sessionToken).length, 4);
      expect(requestToken, hasLength(36));
      expect(requestToken, isNot(sessionToken));
    });
  });

  group('PortalLocationException', () {
    test('toString() includes the message', () {
      final ex = PortalLocationException('denied');
      expect(ex.toString(), 'PortalLocationException: denied');
    });
  });
}
