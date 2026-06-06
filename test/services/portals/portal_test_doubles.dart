import 'package:dbus/dbus.dart';
import 'package:mocktail/mocktail.dart';

/// Shared DBus test doubles for the portal service tests — previously
/// duplicated inline in `portal_service_test.dart` and
/// `screenshot_portal_service_test.dart`.
class MockDBusClient extends Mock implements DBusClient {}

class MockDBusRemoteObject extends Mock implements DBusRemoteObject {}

class MockDBusIntrospectNode extends Mock implements DBusIntrospectNode {}

class MockDBusIntrospectInterface extends Mock
    implements DBusIntrospectInterface {}

class MockDBusSignal extends Mock implements DBusSignal {}

class FakeDBusObjectPath extends Fake implements DBusObjectPath {
  FakeDBusObjectPath(this.value);

  @override
  final String value;

  @override
  String toString() => value;
}

class FakeDBusSignature extends Fake implements DBusSignature {}
