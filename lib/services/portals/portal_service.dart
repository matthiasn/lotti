import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Constants for XDG Desktop Portal communication
class PortalConstants {
  const PortalConstants._();

  static const String portalBusName = 'org.freedesktop.portal.Desktop';
  static const String portalPath = '/org/freedesktop/portal/desktop';
  static const Duration responseTimeout = Duration(seconds: 30);

  // Flatpak environment indicators
  static const String flatpakIdEnvVar = 'FLATPAK_ID';
  static const String flatpakDestEnvVar = 'FLATPAK_DEST';
  static const String containerEnvVar = 'container';
  static const String flatpakContainerValue = 'flatpak';

  // Flatpak filesystem paths
  static const String flatpakAppPath = '/app';
  static const String flatpakHostPath = '/var/run/host';

  // Service names for logging
  static const String screenshotServiceName = 'ScreenshotPortalService';

  // Domain names for logging
  static const String portalServiceDomain = 'PortalService';
  static const String initializationSubdomain = 'initialization';
  static const String availabilitySubdomain = 'isAvailable';

  // Error messages
  static const String notInitializedError = 'Portal service not initialized';
  static const String dbusUnavailableError =
      'D-Bus client not available outside Flatpak environment';
}

abstract class PortalService {
  late DBusClient _client;
  bool _initialized = false;

  // Cache for Flatpak detection result
  static bool? _isRunningInFlatpakCache;

  Future<void> initialize() async {
    if (_initialized) return;

    // Only initialize D-Bus client if we should use portals
    if (!shouldUsePortal) {
      _initialized = true;
      return;
    }

    try {
      _client = DBusClient.session();
      _initialized = true;
    } catch (e) {
      // Guard against LoggingService not being registered
      if (getIt.isRegistered<LoggingService>()) {
        getIt<LoggingService>().captureException(
          e,
          domain: PortalConstants.portalServiceDomain,
          subDomain: PortalConstants.initializationSubdomain,
        );
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_initialized) {
      // Only close D-Bus client if it was actually created
      if (shouldUsePortal) {
        await _client.close();
      }
      _initialized = false;
    }
  }

  DBusClient get client {
    if (!_initialized) {
      throw StateError(PortalConstants.notInitializedError);
    }
    if (!shouldUsePortal) {
      throw StateError(PortalConstants.dbusUnavailableError);
    }
    return _client;
  }

  bool get isInitialized => _initialized;

  /// Checks if we're running in a Flatpak environment
  ///
  /// This method checks multiple indicators to reliably detect Flatpak:
  /// 1. FLATPAK_ID environment variable (most reliable but can be empty)
  /// 2. FLATPAK_DEST environment variable (set in build environment)
  /// 3. container=flatpak environment variable
  /// 4. Presence of Flatpak-specific filesystem paths (/app and /var/run/host)
  ///
  /// The result is cached after the first check for performance.
  static bool get isRunningInFlatpak {
    // Return cached result if available
    if (_isRunningInFlatpakCache != null) {
      return _isRunningInFlatpakCache!;
    }

    if (!Platform.isLinux) {
      _isRunningInFlatpakCache = false;
      return false;
    }

    // Check multiple indicators of Flatpak environment
    final flatpakId = Platform.environment[PortalConstants.flatpakIdEnvVar];
    final flatpakDest = Platform.environment[PortalConstants.flatpakDestEnvVar];
    final containerValue =
        Platform.environment[PortalConstants.containerEnvVar];

    // FLATPAK_ID is the most reliable but might be empty
    if (flatpakId != null && flatpakId.isNotEmpty) {
      _isRunningInFlatpakCache = true;
      return true;
    }

    // FLATPAK_DEST is set when running in Flatpak
    if (flatpakDest != null && flatpakDest.isNotEmpty) {
      _isRunningInFlatpakCache = true;
      return true;
    }

    // Check if container environment variable indicates flatpak
    if (containerValue == PortalConstants.flatpakContainerValue) {
      _isRunningInFlatpakCache = true;
      return true;
    }

    // Check for Flatpak-specific paths
    try {
      if (Directory(PortalConstants.flatpakAppPath).existsSync() &&
          Directory(PortalConstants.flatpakHostPath).existsSync()) {
        _isRunningInFlatpakCache = true;
        return true;
      }
    } catch (_) {
      // Ignore filesystem access errors
    }

    _isRunningInFlatpakCache = false;
    return false;
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

  // Counter for ensuring unique tokens
  static int _tokenCounter = 0;

  /// Creates handle token for portal requests
  /// Combines timestamp with a counter to ensure uniqueness even when
  /// called rapidly in succession
  static String createHandleToken(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final counter = _tokenCounter++;
    return '${prefix}_${timestamp}_$counter';
  }

  /// Common method to check if a portal interface is available
  ///
  /// Returns true if the interface is available, false otherwise.
  /// Handles special cases for different portal services.
  static Future<bool> isInterfaceAvailable(
    String interfaceName,
    PortalService service,
    String serviceName,
  ) async {
    if (!shouldUsePortal) {
      // Handle non-Flatpak environments
      switch (serviceName) {
        case PortalConstants.screenshotServiceName:
          return false; // Screenshots require portal
        default:
          return false;
      }
    }

    try {
      await service.initialize();
      final object = service.createPortalObject();
      final introspection = await object.introspect().timeout(
        PortalConstants.responseTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Portal introspection timed out after ${PortalConstants.responseTimeout.inSeconds} seconds',
          );
        },
      );
      return introspection.interfaces.any(
        (interface) => interface.name == interfaceName,
      );
    } catch (e) {
      if (getIt.isRegistered<LoggingService>()) {
        getIt<LoggingService>().captureException(
          e,
          domain: serviceName,
          subDomain: PortalConstants.availabilitySubdomain,
        );
      }
      return false;
    }
  }
}
