import 'dart:async';
import 'dart:io';

import 'package:location/location.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/linux_geoclue_client.dart';
import 'package:lotti/services/linux_location_portal.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/platform.dart';

/// Abstracts both Linux backends (portal under Flatpak, direct GeoClue under
/// `flutter run`) so callers and tests speak a single API.
abstract class LinuxLocationBackend {
  Future<PortalLocation> getLocation({required Duration timeout});
  Future<void> close();
}

class _PortalBackend implements LinuxLocationBackend {
  _PortalBackend(this._portal);
  final XdgLocationPortal _portal;
  @override
  Future<PortalLocation> getLocation({required Duration timeout}) =>
      _portal.getLocation(timeout: timeout);
  @override
  Future<void> close() => _portal.close();
}

class _GeoClueBackend implements LinuxLocationBackend {
  _GeoClueBackend(this._client);
  final LinuxGeoClueClient _client;
  @override
  Future<PortalLocation> getLocation({required Duration timeout}) =>
      _client.getLocation(timeout: timeout);
  @override
  Future<void> close() => _client.close();
}

/// Builds the Linux backend used by [DeviceLocation]. Defaults to the portal
/// when running inside a Flatpak sandbox (xdg-desktop-portal mediates GeoClue
/// and the app appears under GNOME Settings → Location → Permitted Apps), and
/// to direct GeoClue otherwise (the portal rejects unsandboxed callers with
/// `Access denied`).
typedef LinuxLocationBackendFactory = LinuxLocationBackend Function();

LinuxLocationBackend _defaultLinuxBackend() {
  final inFlatpak = File('/.flatpak-info').existsSync();
  if (inFlatpak) {
    return _PortalBackend(XdgLocationPortal());
  }
  return _GeoClueBackend(
    LinuxGeoClueClient(desktopId: LocationConstants.appDesktopId),
  );
}

class LocationConstants {
  const LocationConstants._();

  static const Duration locationTimeout = Duration(seconds: 10);
  static const String appDesktopId = 'com.matthiasn.lotti';
}

class DeviceLocation {
  DeviceLocation({
    Location? locationService,
    IpGeolocationProvider? ipGeolocationProvider,
    LinuxLocationBackendFactory? linuxBackendFactory,
  }) {
    location = locationService ?? Location();
    _ipGeolocationProvider =
        ipGeolocationProvider ?? defaultIpGeolocationProvider;
    _linuxBackendFactory = linuxBackendFactory ?? _defaultLinuxBackend;
    init();
  }

  late Location location;
  late IpGeolocationProvider _ipGeolocationProvider;
  late LinuxLocationBackendFactory _linuxBackendFactory;

  Future<void> init() async {
    bool serviceEnabled;

    if (isWindows || isTestEnv) {
      return;
    }

    try {
      serviceEnabled = await location.serviceEnabled();
    } catch (e) {
      // Location services not available (e.g., in flatpak environment)
      // This is expected, we'll use IP-based fallback
      getIt<LoggingService>().captureException(
        e,
        domain: 'LOCATION_SERVICE',
        subDomain: 'initialization',
      );
      return;
    }
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }
  }

  Future<PermissionStatus> _requestPermission() async {
    var permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
    }
    return permissionStatus;
  }

  Future<Geolocation?> getCurrentGeoLocation() async {
    final recordLocation = await getIt<JournalDb>().getConfigFlag(
      recordLocationFlag,
    );

    if (!recordLocation || Platform.isWindows) {
      return null;
    }

    // Try native geolocation first
    Geolocation? nativeLocation;

    if (Platform.isLinux) {
      try {
        nativeLocation = await getCurrentGeoLocationLinux();
      } catch (e) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'LOCATION_SERVICE',
          subDomain: 'linux_native_fallback',
        );
      }
    } else {
      final permissionStatus = await _requestPermission();

      if (permissionStatus != PermissionStatus.denied &&
          permissionStatus != PermissionStatus.deniedForever) {
        try {
          final now = DateTime.now();
          final locationData = await location.getLocation();
          final longitude = locationData.longitude;
          final latitude = locationData.latitude;

          if (longitude != null && latitude != null) {
            nativeLocation = Geolocation(
              createdAt: now,
              timezone: now.timeZoneName,
              utcOffset: now.timeZoneOffset.inMinutes,
              latitude: latitude,
              longitude: longitude,
              altitude: locationData.altitude,
              speed: locationData.speed,
              accuracy: locationData.accuracy,
              heading: locationData.heading,
              speedAccuracy: locationData.speedAccuracy,
              geohashString: getGeoHash(
                latitude: latitude,
                longitude: longitude,
              ),
            );
          }
        } catch (e) {
          getIt<LoggingService>().captureException(
            e,
            domain: 'LOCATION_SERVICE',
            subDomain: 'native_location_fallback',
          );
        }
      }
    }

    // Return native location if successful, otherwise fallback to IP geolocation
    return nativeLocation ?? await _ipGeolocationProvider();
  }

  Future<Geolocation?> getCurrentGeoLocationLinux() async {
    if (!Platform.isLinux) return null;

    final now = DateTime.now();
    final backend = _linuxBackendFactory();
    try {
      final locationData = await backend.getLocation(
        timeout: LocationConstants.locationTimeout,
      );
      return Geolocation(
        createdAt: now,
        timezone: now.timeZoneName,
        utcOffset: now.timeZoneOffset.inMinutes,
        latitude: locationData.latitude,
        longitude: locationData.longitude,
        altitude: locationData.altitude,
        speed: locationData.speed,
        accuracy: locationData.accuracy,
        heading: locationData.heading,
        geohashString: getGeoHash(
          latitude: locationData.latitude,
          longitude: locationData.longitude,
        ),
      );
    } finally {
      await backend.close();
    }
  }
}
