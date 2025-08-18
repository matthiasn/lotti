import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class PortalConstants {
  const PortalConstants._();
  
  static const String portalBusName = 'org.freedesktop.portal.Desktop';
  static const String portalPath = '/org/freedesktop/portal/desktop';
  static const Duration responseTimeout = Duration(seconds: 30);
}

abstract class PortalService {
  late DBusClient _client;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _client = DBusClient.session();
      _initialized = true;
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'PortalService',
        subDomain: 'initialization',
      );
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _client.close();
      _initialized = false;
    }
  }

  DBusClient get client {
    if (!_initialized) {
      throw StateError('Portal service not initialized');
    }
    return _client;
  }

  bool get isInitialized => _initialized;

  /// Checks if we're running in a Flatpak environment
  static bool get isRunningInFlatpak {
    return Platform.isLinux && 
           (Platform.environment['FLATPAK_ID'] != null && 
            Platform.environment['FLATPAK_ID']!.isNotEmpty);
  }

  /// Checks if portal is available and should be used
  static bool get shouldUsePortal => isRunningInFlatpak;

  /// Creates a remote DBus object for portal communication
  DBusRemoteObject createPortalObject() {
    return DBusRemoteObject(
      client,
      name: PortalConstants.portalBusName,
      path: DBusObjectPath(PortalConstants.portalPath),
    );
  }

  /// Creates handle token for portal requests
  static String createHandleToken(String prefix) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Common method to check if a portal interface is available
  static Future<bool> isInterfaceAvailable(
    String interfaceName,
    PortalService service,
    String serviceName,
  ) async {
    if (!shouldUsePortal && serviceName == 'ScreenshotPortalService') {
      return false;
    }
    if (!shouldUsePortal && serviceName == 'AudioPortalService') {
      return true; // Not in Flatpak, assume available
    }

    try {
      await service.initialize();
      final object = service.createPortalObject();
      final introspection = await object.introspect();
      return introspection.interfaces.any(
        (interface) => interface.name == interfaceName,
      );
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: serviceName,
        subDomain: 'isAvailable',
      );
      return false;
    }
  }
}
