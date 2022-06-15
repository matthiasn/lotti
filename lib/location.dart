import 'dart:io';

import 'package:dart_geohash/dart_geohash.dart';
import 'package:geoclue/geoclue.dart';
import 'package:location/location.dart';
import 'package:lotti/classes/geolocation.dart';

class DeviceLocation {
  DeviceLocation() {
    location = Location();
    init();
  }

  late Location location;

  Future<void> init() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    if (Platform.isWindows) {
      return;
    }

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
  }

  static String getGeoHash({
    required double latitude,
    required double longitude,
  }) {
    return GeoHasher().encode(longitude, latitude);
  }

  Future<Geolocation?> getCurrentGeoLocation() async {
    final now = DateTime.now();

    if (Platform.isWindows) {
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
}
