import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/location.dart';

class IpGeolocationService {
  static const String _ipApiUrl = 'https://ipapi.co/json/';
  static const String _ipApiFallbackUrl = 'https://ip-api.com/json';
  static const Duration _timeout = Duration(seconds: 5);
  static const double _ipLocationAccuracy =
      50000; // ~50km accuracy for IP geolocation

  static Future<Geolocation?> getLocationFromIp(
      {http.Client? httpClient}) async {
    final client = httpClient ?? http.Client();
    try {
      final response = await client.get(
        Uri.parse(_ipApiUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        final latitude = data['latitude'] as double?;
        final longitude = data['longitude'] as double?;

        if (latitude != null && longitude != null) {
          final now = DateTime.now();

          return Geolocation(
            createdAt: now,
            latitude: latitude,
            longitude: longitude,
            geohashString: getGeoHash(
              latitude: latitude,
              longitude: longitude,
            ),
            timezone: data['timezone'] as String? ?? now.timeZoneName,
            utcOffset: data['utc_offset'] != null
                ? _parseUtcOffset(data['utc_offset'] as String)
                : now.timeZoneOffset.inMinutes,
            accuracy: _ipLocationAccuracy,
          );
        }
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'IP_GEOLOCATION',
        subDomain: 'getLocationFromIp',
      );
    }

    return _getLocationFromIpApiFallback(httpClient: client);
  }

  static int _parseUtcOffset(String offset) {
    // Parse offset format like "+0200" or "-0430"
    try {
      if (offset.isEmpty) return 0;

      final sign = offset.startsWith('-') ? -1 : 1;
      final cleanOffset = offset.replaceAll(RegExp('[+-]'), '');

      if (cleanOffset.length >= 4) {
        final hours = int.parse(cleanOffset.substring(0, 2));
        final minutes = int.parse(cleanOffset.substring(2, 4));
        return sign * (hours * 60 + minutes);
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'IP_GEOLOCATION',
        subDomain: '_parseUtcOffset',
      );
    }

    return DateTime.now().timeZoneOffset.inMinutes;
  }

  // Alternative fallback using ip-api.com
  static Future<Geolocation?> _getLocationFromIpApiFallback(
      {required http.Client httpClient}) async {
    try {
      final response = await httpClient.get(
        Uri.parse(_ipApiFallbackUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          final latitude = (data['lat'] as num?)?.toDouble();
          final longitude = (data['lon'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            final now = DateTime.now();

            return Geolocation(
              createdAt: now,
              latitude: latitude,
              longitude: longitude,
              geohashString: getGeoHash(
                latitude: latitude,
                longitude: longitude,
              ),
              timezone: data['timezone'] as String? ?? now.timeZoneName,
              utcOffset: now.timeZoneOffset.inMinutes,
              accuracy: _ipLocationAccuracy,
            );
          }
        }
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'IP_GEOLOCATION',
        subDomain: '_getLocationFromIpApiFallback',
      );
    }

    return null;
  }
}
