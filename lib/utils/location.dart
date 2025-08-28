import 'dart:io';

import 'package:dart_geohash/dart_geohash.dart';
import 'package:geoclue/geoclue.dart';
import 'package:location/location.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/ip_geolocation_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

class LocationConstants {
  const LocationConstants._();

  static const Duration locationTimeout = Duration(seconds: 10);
  static const String appDesktopId = 'com.matthiasnehlsen.lotti';
}

class DeviceLocation {
  DeviceLocation() {
    location = Location();
    init();
  }

  late Location location;

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
    final recordLocation =
        await getIt<JournalDb>().getConfigFlag(recordLocationFlag);

    if (!recordLocation || Platform.isWindows) {
      return null;
    }

    if (Platform.isLinux) {
      // Try native Linux geolocation first, fallback to IP if it fails
      try {
        final location = await getCurrentGeoLocationLinux();
        if (location != null) {
          return location;
        }
      } catch (e) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'LOCATION_SERVICE',
          subDomain: 'linux_native_fallback',
        );
      }
      
      // Fallback to IP-based geolocation for Linux (including Flatpak)
      return IpGeolocationService.getLocationFromIp();
    }

    final now = DateTime.now();

    final permissionStatus = await _requestPermission();

    if (permissionStatus == PermissionStatus.denied ||
        permissionStatus == PermissionStatus.deniedForever) {
      // Try IP-based geolocation as fallback when permissions denied
      return IpGeolocationService.getLocationFromIp();
    }

    try {
      final locationData = await location.getLocation();
      final longitude = locationData.longitude;
      final latitude = locationData.latitude;
      if (longitude != null && latitude != null) {
        return Geolocation(
          createdAt: now,
          timezone: now.timeZoneName,
          utcOffset: now.timeZoneOffset.inMinutes,
          latitude: latitude,
          longitude: longitude,
          altitude: locationData.altitude,
          speed: locationData.speed,
          accuracy: locationData.accuracy,
          heading: locationData.heading,
          headingAccuracy: locationData.headingAccuracy,
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
      
      // Fallback to IP-based geolocation on any error
      return IpGeolocationService.getLocationFromIp();
    }
    
    // Final fallback to IP-based geolocation if native returns null
    return IpGeolocationService.getLocationFromIp();
  }

  Future<Geolocation?> getCurrentGeoLocationLinux() async {
    final now = DateTime.now();

    if (Platform.isLinux) {
      try {
        final manager = GeoClueManager();
        await manager.connect();
        final client = await manager.getClient();
        await client.setDesktopId(LocationConstants.appDesktopId);
        await client.setRequestedAccuracyLevel(GeoClueAccuracyLevel.exact);
        await client.start();

        final locationData = await client.locationUpdated
            .timeout(
              LocationConstants.locationTimeout,
              onTimeout: (_) => manager.close(),
            )
            .first;

        await client.stop();

        final longitude = locationData.longitude;
        final latitude = locationData.latitude;

        return Geolocation(
          createdAt: now,
          timezone: now.timeZoneName,
          utcOffset: now.timeZoneOffset.inMinutes,
          latitude: latitude,
          longitude: longitude,
          altitude: locationData.altitude,
          speed: locationData.speed,
          accuracy: locationData.accuracy,
          heading: locationData.heading,
          geohashString: getGeoHash(
            latitude: latitude,
            longitude: longitude,
          ),
        );
      } catch (e) {
        getIt<LoggingService>().captureException(
          e,
          domain: 'LOCATION_SERVICE',
          subDomain: 'getCurrentGeoLocationLinux',
        );
        
        // Rethrow to let the caller handle fallback
        rethrow;
      }
    }

    return null;
  }
}

String getGeoHash({
  required double latitude,
  required double longitude,
}) {
  return GeoHasher().encode(
    longitude,
    latitude,
  );
}
