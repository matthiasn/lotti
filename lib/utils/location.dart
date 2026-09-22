import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/linux_geoclue_client.dart';
import 'package:lotti/services/linux_location_portal.dart';
import 'package:lotti/services/native_location.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/geohash.dart';
import 'package:lotti/utils/platform.dart';

/// Abstracts both Linux backends (portal under Flatpak, direct GeoClue under
/// `flutter run`) so callers and tests speak a single API.
abstract class LinuxLocationBackend {
  Future<PortalLocation> getLocation({required Duration timeout});
  Future<void> close();
}

@visibleForTesting
class PortalBackend implements LinuxLocationBackend {
  PortalBackend(this._portal);
  final XdgLocationPortal _portal;
  @override
  Future<PortalLocation> getLocation({required Duration timeout}) =>
      _portal.getLocation(timeout: timeout);
  @override
  Future<void> close() => _portal.close();
}

@visibleForTesting
class GeoClueBackend implements LinuxLocationBackend {
  GeoClueBackend(this._client);
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

bool _defaultIsInFlatpak() => File('/.flatpak-info').existsSync();

@visibleForTesting
LinuxLocationBackend defaultLinuxBackend({bool Function()? isInFlatpak}) {
  final detect = isInFlatpak ?? _defaultIsInFlatpak;
  if (detect()) {
    return PortalBackend(XdgLocationPortal());
  }
  return GeoClueBackend(
    LinuxGeoClueClient(desktopId: LocationConstants.appDesktopId),
  );
}

LinuxLocationBackend _defaultLinuxBackendFactory() => defaultLinuxBackend();

class LocationConstants {
  const LocationConstants._();

  static const Duration locationTimeout = Duration(seconds: 10);
  static const String appDesktopId = 'com.matthiasn.lotti';
}

/// Picks the native source for the running platform: the app's own AOSP
/// `LocationManager` channel on Android, CoreLocation on iOS and macOS, and
/// none elsewhere (Linux has its own backends; Windows records no location).
NativeLocationSource? defaultNativeLocationSource() {
  if (isAndroid) return AndroidLocationSource();
  if (isIOS || isMacOS) return AppleLocationSource();
  return null;
}

class DeviceLocation {
  DeviceLocation({
    NativeLocationSource? nativeLocationSource,
    IpGeolocationProvider? ipGeolocationProvider,
    LinuxLocationBackendFactory? linuxBackendFactory,
  }) : _nativeLocationSource =
           nativeLocationSource ?? defaultNativeLocationSource(),
       _ipGeolocationProvider =
           ipGeolocationProvider ?? defaultIpGeolocationProvider,
       _linuxBackendFactory =
           linuxBackendFactory ?? _defaultLinuxBackendFactory;

  final NativeLocationSource? _nativeLocationSource;
  final IpGeolocationProvider _ipGeolocationProvider;
  final LinuxLocationBackendFactory _linuxBackendFactory;

  /// Reads the device's position for a new entry, if location recording is
  /// on.
  ///
  /// The native source asks for permission the first time; a refusal,
  /// disabled location services or a failed fix all fall back to IP
  /// geolocation. Nothing prompts the user to switch location services on:
  /// Android's in-app prompt for that is part of Google Play Services, and
  /// Apple platforms have no such API.
  Future<Geolocation?> getCurrentGeoLocation() async {
    final recordLocation = await getIt<JournalDb>().getConfigFlag(
      recordLocationFlag,
    );

    if (!recordLocation || isWindows) {
      return null;
    }

    // Try native geolocation first
    Geolocation? nativeLocation;

    if (isLinux) {
      try {
        nativeLocation = await getCurrentGeoLocationLinux();
      } catch (e) {
        getIt<DomainLogger>().error(
          LogDomain.location,
          e,
          subDomain: 'linux_native_fallback',
        );
      }
    } else {
      final source = _nativeLocationSource;
      if (source != null) {
        try {
          final fix = await source.currentLocation(
            timeout: LocationConstants.locationTimeout,
          );
          if (fix != null) nativeLocation = _geolocationFrom(fix);
        } catch (e) {
          getIt<DomainLogger>().error(
            LogDomain.location,
            e,
            subDomain: 'native_location_fallback',
          );
        }
      }
    }

    // Return native location if successful, otherwise fallback to IP geolocation
    return nativeLocation ?? await _ipGeolocationProvider();
  }

  Geolocation _geolocationFrom(NativeLocationFix fix) {
    final now = DateTime.now();
    return Geolocation(
      createdAt: now,
      timezone: now.timeZoneName,
      utcOffset: now.timeZoneOffset.inMinutes,
      latitude: fix.latitude,
      longitude: fix.longitude,
      altitude: fix.altitude,
      speed: fix.speed,
      accuracy: fix.accuracy,
      heading: fix.heading,
      speedAccuracy: fix.speedAccuracy,
      geohashString: getGeoHash(
        latitude: fix.latitude,
        longitude: fix.longitude,
      ),
    );
  }

  Future<Geolocation?> getCurrentGeoLocationLinux() async {
    if (!isLinux) return null;

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
      // Best-effort: a thrown close() must not erase a successful native
      // location, mirroring how Session.Close is treated inside the portal
      // and GeoClue clients.
      try {
        await backend.close();
      } catch (e) {
        getIt<DomainLogger>().error(
          LogDomain.location,
          e,
          subDomain: 'linux_backend_close',
        );
      }
    }
  }
}
