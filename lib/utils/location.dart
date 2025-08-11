import 'dart:io';

import 'package:dart_geohash/dart_geohash.dart';
import 'package:geoclue/geoclue.dart';
import 'package:location/location.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

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
      // Location services not available in flatpak environment
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
    if (Platform.isLinux) {
      return getCurrentGeoLocationLinux();
    }

    final now = DateTime.now();

    final recordLocation =
        await getIt<JournalDb>().getConfigFlag(recordLocationFlag);

    if (!recordLocation || Platform.isWindows) {
      return null;
    }

    final permissionStatus = await _requestPermission();

    if (permissionStatus == PermissionStatus.denied ||
        permissionStatus == PermissionStatus.deniedForever) {
      return null;
    }

    if (Platform.isLinux) {
      final manager = GeoClueManager();
      await manager.connect();
      final client = await manager.getClient();
      await client.setDesktopId('<desktop-id>');
      await client.setRequestedAccuracyLevel(GeoClueAccuracyLevel.exact);
      await client.start();

      final locationData = await client.locationUpdated
          .timeout(
            const Duration(seconds: 10),
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
    }

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
    return null;
  }

  Future<Geolocation?> getCurrentGeoLocationLinux() async {
    final now = DateTime.now();

    if (Platform.isLinux) {
      final manager = GeoClueManager();
      await manager.connect();
      final client = await manager.getClient();
      await client.setDesktopId('<desktop-id>');
      await client.setRequestedAccuracyLevel(GeoClueAccuracyLevel.exact);
      await client.start();

      final locationData = await client.locationUpdated
          .timeout(
            const Duration(seconds: 10),
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
